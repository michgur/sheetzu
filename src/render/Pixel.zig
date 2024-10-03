const std = @import("std");
const Style = @import("Style.zig");
const String = @import("../String.zig");
const Codepoint = String.Codepoint;
const CodepointInfo = String.CodepointInfo;

/// a terminal cell. named pixel to differentiate from sheet cells
const Pixel = @This();

pub const BLANK = Pixel{
    .content = [8]u8{ 32, 0, 0, 0, 0, 0, 0, 0 },
    .grapheme = .{
        .len = 1,
        .display_width = 1,
    },
    .style = Style{},
};

content: [8]u8,
grapheme: CodepointInfo,
style: Style,

pub fn dump(self: *const Pixel, writer: anytype) !void {
    try self.style.dump(writer);
    try writer.writeAll(self.content[0..self.grapheme.len]);
}

pub fn set(self: *Pixel, grapheme: Codepoint) void {
    self.grapheme = grapheme.info;
    self.grapheme.len = @min(self.grapheme.len, self.content.len); // future: handle longer grapheme clusters
    @memcpy(self.content[0..grapheme.info.len], grapheme.bytes);
}

pub fn setAscii(self: *Pixel, byte: u8) void {
    self.grapheme = .{
        .display_width = 1,
        .len = 1,
    };
    self.content[0] = byte;
}
