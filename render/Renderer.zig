const std = @import("std");
const Cursor = @import("../Cursor.zig");
const Pixel = @import("Pixel.zig");
const Style = @import("Style.zig");
const common = @import("../common.zig");
const Str = @import("../utf8.zig").Str;

const Renderer = @This();

writer: std.fs.File.Writer,
allocator: std.mem.Allocator,
cursor: *Cursor,
rows: usize,
cols: usize,
pixels: []Pixel,

pub fn init(
    writer: std.fs.File.Writer,
    allocator: std.mem.Allocator,
    rows: usize,
    cols: usize,
    cursor: *Cursor,
) !Renderer {
    const res = Renderer{
        .writer = writer,
        .rows = rows,
        .cols = cols,
        .allocator = allocator,
        .cursor = cursor,
        .pixels = try allocator.alloc(Pixel, rows * cols),
    };

    for (0..cols) |c| {
        for (0..rows) |r| {
            res.pixels[r * cols + c] = Pixel.BLANK;
        }
    }
    try res.cursor.hide();

    return res;
}

pub fn resize(self: *Renderer, rows: usize, cols: usize) !void {
    self.rows = rows;
    self.cols = cols;

    self.pixels = try self.allocator.realloc(self.pixels, rows * cols);
}

inline fn posToIdx(self: *const Renderer, pos: anytype) usize {
    const upos = switch (@TypeOf(pos)) {
        common.ipos => common.posCast(pos),
        common.upos => pos,
        else => unreachable,
    };
    return @intCast(upos[0] * self.cols + upos[1]);
}

fn getPixel(self: *Renderer, pos: anytype) ?*Pixel {
    return switch (@TypeOf(pos)) {
        common.ipos, common.upos => blk: {
            if (pos[0] < 0 or pos[0] >= self.rows or pos[1] < 0 or pos[1] >= self.cols) return null;
            break :blk &self.pixels[self.posToIdx(pos)];
        },
        else => unreachable,
    };
}

pub fn write(
    self: *Renderer,
    position: common.upos,
    content: Str,
    style: Style,
) common.upos {
    var write_pos: common.upos = position;
    var iter = content.iterator();
    while (iter.next()) |cp| {
        if (write_pos[1] >= self.cols or write_pos[0] >= self.rows) break;
        if (cp.info.display_width > 0) {
            var px = self.getPixel(write_pos) orelse break;
            px.style = style;
            px.content_len = cp.info.len;
            px.width = cp.info.display_width;
            @memcpy(px.content[0..px.content_len], cp.bytes);
            write_pos += common.upos{ 0, px.width };
        }
    }
    return write_pos - position;
}

inline fn placeCursor(position: anytype, writer: anytype) !void {
    try writer.print("\x1B[{};{}H", .{
        position[0] + 1,
        position[1] + 1,
    });
}

pub fn flush(self: *const Renderer) !void {
    var buf = std.io.bufferedWriter(self.writer);
    defer buf.flush() catch {};
    var writer = buf.writer();

    const pos = self.cursor.pos;
    try placeCursor(.{ 0, 0 }, writer);
    defer placeCursor(pos, writer) catch {};

    var i: usize = 0;
    while (i < self.pixels.len) {
        const px = &self.pixels[i];
        if (i % self.cols == 0 and i > 0) {
            _ = try writer.write("\n\r");
        }
        try px.dump(writer);
        px.* = Pixel.BLANK;

        i += @max(1, px.width);
    }
}
