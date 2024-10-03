const std = @import("std");
const Pixel = @import("Pixel.zig");
const Style = @import("Style.zig");
const common = @import("../common.zig");
const String = @import("../string/String.zig");

const Screen = @This();

writer: std.fs.File.Writer,
allocator: std.mem.Allocator,
size: common.upos,
pixels: []Pixel,

pub fn init(
    writer: std.fs.File.Writer,
    allocator: std.mem.Allocator,
    size: common.upos,
) !Screen {
    const res = Screen{
        .writer = writer,
        .size = size,
        .allocator = allocator,
        .pixels = try allocator.alloc(Pixel, size[0] * size[1]),
    };
    @memset(res.pixels, Pixel.BLANK);

    try writer.writeAll("\x1b[s"); // Save cursor position.
    try writer.writeAll("\x1b[?47h"); // Save screen.
    try writer.writeAll("\x1b[?1049h"); // Enable alternative buffer.
    try writer.writeAll("\x1b[2J"); // Clear screen
    try writer.writeAll("\x1B[?25l"); // hide cursor
    return res;
}

pub fn deinit(self: *Screen) void {
    self.writer.writeAll("\x1b[?1049l") catch {}; // Disable alternative buffer.
    self.writer.writeAll("\x1b[?47l") catch {}; // Restore screen.
    self.writer.writeAll("\x1b[u") catch {}; // Restore cursor position.

    self.allocator.free(self.pixels);
    self.* = undefined;
}

pub fn flush(self: *const Screen) !void {
    var buffered_writer = std.io.bufferedWriter(self.writer);
    defer buffered_writer.flush() catch {};

    try self.dump(buffered_writer.writer());
}

pub fn resize(self: *Screen, new_size: common.upos) !void {
    self.size = new_size;
    self.pixels = try self.allocator.realloc(self.pixels, new_size[0] * new_size[1]);
}

pub fn getPixel(self: *const Screen, pos: common.upos) ?*Pixel {
    if (pos[0] < 0 or pos[0] >= self.size[0] or pos[1] < 0 or pos[1] >= self.size[1]) return null;
    return &self.pixels[pos[0] * self.size[1] + pos[1]];
}

fn dump(self: *const Screen, writer: anytype) !void {
    try writer.writeAll("\x1B[H"); // place cursor at 0,0
    for (0..self.size[0]) |r| {
        if (r > 0) {
            try writer.writeAll("\r\n");
        }

        var c: usize = 0;
        while (c < self.size[1]) {
            const px = self.getPixel(.{ r, c }) orelse break;
            defer px.* = Pixel.BLANK;

            try px.dump(writer);
            c += @max(1, px.codepoint.display_width);
        }
    }
}
