const std = @import("std");
const Position = @import("../common.zig").ipos;
const Style = @import("../render/Style.zig");
const Str = @import("../utf8.zig").Str;
const CellData = @import("data.zig").CellData;

const Cell = @This();

str: Str,
style: Style,
data: CellData,

pub fn init(allocator: std.mem.Allocator) Cell {
    return Cell{
        .str = Str.init(allocator),
        .style = Style{},
        .data = .{ .Blank = {} },
    };
}

pub fn tick(self: *Cell) void {
    self.data = CellData.parse(&self.str);
    switch (self.data) {
        .Numeral => self.style.fg = .green,
        else => self.style.fg = .none,
    }
}
