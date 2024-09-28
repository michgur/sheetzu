const std = @import("std");
const Pixel = @import("Pixel.zig");
const Style = @import("Style.zig");
const common = @import("../common.zig");

const PixelBuffer = @This();

allocator: std.mem.Allocator,
size: common.upos,
pixels: []Pixel,

pub fn init(
    allocator: std.mem.Allocator,
    size: common.upos,
) !PixelBuffer {
    const res = PixelBuffer{
        .size = size,
        .allocator = allocator,
        .pixels = try allocator.alloc(Pixel, size[0] * size[1]),
    };
    for (res.pixels) |*px| {
        px.* = Pixel.BLANK;
    }

    return res;
}

pub fn resize(self: *PixelBuffer, new_size: common.upos) !void {
    self.size = new_size;
    self.pixels = try self.allocator.realloc(self.pixels, new_size[0] * new_size[1]);
}

pub fn getPixel(self: *const PixelBuffer, pos: common.upos) ?*Pixel {
    if (pos[0] < 0 or pos[0] >= self.size[0] or pos[1] < 0 or pos[1] >= self.size[1]) return null;
    return &self.pixels[pos[0] * self.size[1] + pos[1]];
}

pub fn deinit(self: *PixelBuffer) void {
    self.allocator.free(self.pixels);
    self.* = undefined;
}

pub fn dump(self: *const PixelBuffer, writer: anytype) !void {
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
            c += @max(1, px.grapheme.display_width);
        }
    }
}
