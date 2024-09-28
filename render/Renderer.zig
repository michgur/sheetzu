const std = @import("std");
const Pixel = @import("Pixel.zig");
const Style = @import("Style.zig");
const common = @import("../common.zig");
const DisplayString = @import("../DisplayString.zig");
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

pub fn deinit(self: *Renderer) void {
    self.writer.writeAll("\x1b[?1049l") catch {}; // Disable alternative buffer.
    self.writer.writeAll("\x1b[?47l") catch {}; // Restore screen.
    self.writer.writeAll("\x1b[u") catch {}; // Restore cursor position.
}

pub fn writeStr(
    self: *Renderer,
    position: common.upos,
    str: DisplayString,
    style: Style,
) common.upos {
    var wpos: common.upos = position;
    var iter = str.iterator();
    while (iter.next()) |grapheme| {
        if (grapheme.info.display_width <= 0) continue; // future: zero joiners and other shizz

        var px = self.buf.getPixel(wpos) orelse break;
        px.set(grapheme);
        px.style = style;
        wpos[1] += grapheme.info.display_width;
    }
    return wpos - position;
}

pub fn flush(self: *const Renderer) !void {
    var buffered_writer = std.io.bufferedWriter(self.writer);
    defer buffered_writer.flush() catch {};

    try self.buf.dump(buffered_writer.writer());
}
