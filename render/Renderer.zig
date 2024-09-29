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

inline fn isRawString(value: anytype) bool {
    return switch (@typeInfo(@TypeOf(value))) {
        .Pointer => |pt| t: {
            if (pt.child == u8) return true;
            break :t switch (@typeInfo(pt.child)) {
                .Array => |arr| arr.child == u8,
                else => false,
            };
        },
        .Array => |arr| arr.child == u8,
        else => false,
    };
}
inline fn toDisplayString(value: anytype) !DisplayString {
    const T = @TypeOf(value);
    return if (T == DisplayString) value // already a DisplayString
    else if (T == *DisplayString) value.* else if (isRawString(value)) try DisplayString.initBytes(std.heap.page_allocator, value) // raw string
    else @compileError(std.fmt.comptimePrint("Invalid string type {s}", .{@typeName(@TypeOf(value))}));
}

pub const Rect = struct {
    top_left: common.upos,
    size: ?common.upos = null,
    alignment: enum { left, right, center } = .left,
};

pub fn renderUnicode(
    self: *Renderer,
    position: common.upos,
    value: anytype,
    style: ?Style,
) common.upos {
    var str = toDisplayString(value) catch {
        if (isRawString(value)) {
            return self.renderAscii(position, value, style);
        } else unreachable;
    };
    defer if (isRawString(value)) str.deinit();

    var wpos: common.upos = position;
    var iter = str.iterator();
    while (iter.next()) |grapheme| {
        if (grapheme.info.display_width <= 0) continue; // future: zero joiners and other shizz

        var px = self.buf.getPixel(wpos) orelse break;
        px.set(grapheme);
        if (style) |st| px.style = st;
        wpos[1] += grapheme.info.display_width;
    }

    return wpos - position;
}

pub fn renderAscii(
    self: *Renderer,
    position: common.upos,
    str: []const u8,
    style: ?Style,
) common.upos {
    var wpos: common.upos = position;
    for (str) |c| {
        const info = DisplayString.GraphemeInfo.parseSingle(&.{c});
        if (info.display_width <= 0) continue; // future: zero joiners and other shizz

        var px = self.buf.getPixel(wpos) orelse break;
        px.setAscii(c);
        if (style) |st| px.style = st;
        wpos[1] += info.display_width;
    }
    return wpos - position;
}

pub fn flush(self: *const Renderer) !void {
    var buffered_writer = std.io.bufferedWriter(self.writer);
    defer buffered_writer.flush() catch {};

    try self.buf.dump(buffered_writer.writer());
}
