const std = @import("std");
const Position = @import("../common.zig").ipos;
const Style = @import("../render/Style.zig");
const DisplayString = @import("../DisplayString.zig");
const CellData = @import("data.zig").CellData;

const Cell = @This();

str: DisplayString,
style: Style,
data: CellData,

pub fn init(allocator: std.mem.Allocator) Cell {
    return Cell{
        .str = DisplayString.init(allocator),
        .style = Style{},
        .data = .{ .Blank = {} },
    };
}

pub fn tick(self: *Cell) void {
    self.data = CellData.parse(&self.str);
    switch (self.data) {
        .Numeral => self.style.fg = .green,
        .Formula => self.style.fg = .red,
        else => self.style.fg = .none,
    }
}
