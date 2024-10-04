const std = @import("std");
const common = @import("../common.zig");
const Style = @import("../render/Style.zig");
const String = @import("../string/String.zig");
const StringWriter = @import("../string/StringWriter.zig");
const AST = @import("../formula/AST.zig");
const Sheet = @import("Sheet.zig");

const Cell = @This();

style: Style,
value: AST.Value,
str: String,
input: StringWriter,
dirty: bool = false,
ast: AST,
refers: std.ArrayList(common.upos),

pub fn init(allocator: std.mem.Allocator) Cell {
    return .{
        .ast = AST{},
        .refers = std.ArrayList(common.upos).init(allocator),
        .value = .{ .blank = {} },
        .str = String.init(allocator, "") catch unreachable,
        .input = StringWriter.init(allocator),
        .style = Style{},
    };
}

pub fn tick(self: *Cell, sht: *const Sheet) void {
    self.value = self.ast.eval(sht);
    const str = self.value.tostring(sht.allocator) catch @panic("Failed to convert value to string - am I stupid?");
    self.str.deinit(sht.allocator);
    self.str = str;

    for (self.refers.items) |refer| {
        if (sht.cell(refer)) |r| @constCast(r).tick(sht);
    }
}

pub fn deinit(self: *Cell, sht: *const Sheet) void {
    self.refers.deinit();
    self.str.deinit(sht.allocator);
    self.input.deinit();
    self.ast.deinit(self.refers.allocator);
}

pub fn removeRefer(self: *Cell, refer: common.upos) bool {
    return for (self.refers.items, 0..) |r, i| {
        if (@reduce(.And, r == refer)) {
            _ = self.refers.swapRemove(i);
            break true;
        }
    } else false;
}
