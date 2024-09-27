const std = @import("std");
const Style = @import("Style.zig");

/// a terminal cell. named pixel to differentiate from sheet cells
const Pixel = @This();

pub const BLANK = Pixel{
    .content = [8]u8{ 32, 0, 0, 0, 0, 0, 0, 0 },
    .content_len = 1,
    .width = 1,
    .style = Style{},
};

content: [8]u8,
content_len: u3,
width: u2,
style: Style,

pub fn dump(self: *const Pixel, writer: anytype) !void {
    try self.style.dump(writer);
    try writer.writeAll(self.content[0..self.content_len]);
}
