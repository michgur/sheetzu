const std = @import("std");
const Pixel = @import("Pixel.zig");
const Style = @import("Style.zig");
const common = @import("../common.zig");
const Str = @import("../utf8.zig").Str;
const PixelBuffer = @import("PixelBuffer.zig");

const Renderer = @This();

writer: std.fs.File.Writer,
buf: *PixelBuffer,

pub fn init(
    writer: std.fs.File.Writer,
    buf: *PixelBuffer,
) !Renderer {
    const res = Renderer{
        .writer = writer,
        .buf = buf,
    };

    try writer.writeAll("\x1b[s"); // Save cursor position.
    try writer.writeAll("\x1b[?47h"); // Save screen.
    try writer.writeAll("\x1b[?1049h"); // Enable alternative buffer.
    try writer.writeAll("\x1b[2J"); // Clear screen
    try writer.writeAll("\x1B[?25l"); // hide cursor
    return res;
}

pub fn writeStr(
    self: *Renderer,
    position: common.upos,
    str: Str,
    style: Style,
) common.upos {
    var wpos: common.upos = position;
    var iter = str.iterator();
    while (iter.next()) |cp| {
        if (cp.info.display_width <= 0) continue;

        var px = self.buf.getPixel(wpos) orelse break;
        px.style = style;
        px.content_len = cp.info.len;
        px.width = cp.info.display_width;
        @memcpy(px.content[0..px.content_len], cp.bytes);
        wpos[1] += px.width;
    }
    return wpos - position;
}

pub fn flush(self: *const Renderer) !void {
    var buffered_writer = std.io.bufferedWriter(self.writer);
    defer buffered_writer.flush() catch {};

    try self.buf.dump(buffered_writer.writer());
}

pub fn deinit(self: *Renderer) void {
    self.writer.writeAll("\x1b[?1049l") catch {}; // Disable alternative buffer.
    self.writer.writeAll("\x1b[?47l") catch {}; // Restore screen.
    self.writer.writeAll("\x1b[u") catch {}; // Restore cursor position.
}
