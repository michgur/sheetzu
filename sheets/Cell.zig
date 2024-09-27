const std = @import("std");
const Position = @import("../common.zig").ipos;
const Style = @import("../render/Style.zig");
const Str = @import("../utf8.zig").Str;

const Cell = @This();

data: Str,
style: Style,

pub fn init(allocator: std.mem.Allocator) Cell {
    return Cell{
        .data = Str.init(allocator),
        .style = Style{},
    };
}
