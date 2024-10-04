const std = @import("std");
const common = @import("../common.zig");
const Style = @import("../render/Style.zig");
const String = @import("../string/String.zig");
const StringWriter = @import("../string/StringWriter.zig");
const AST = @import("../formula/AST.zig");
const Sheet = @import("Sheet.zig");
const Parser = @import("../formula/Parser.zig");

const Cell = @This();

style: Style,
value: AST.Value,
str: String,
input: StringWriter,
dirty: bool = false,
ast: AST,
referrers: std.ArrayList(common.upos),

pub fn init(allocator: std.mem.Allocator) Cell {
    return .{
        .ast = AST{},
        .referrers = std.ArrayList(common.upos).init(allocator),
        .value = .{ .blank = {} },
        .str = String.init(allocator, "") catch unreachable,
        .input = StringWriter.init(allocator),
        .style = Style{},
    };
}

pub fn deinit(self: *Cell, sht: *const Sheet) void {
    self.referrers.deinit();
    self.str.deinit(sht.allocator);
    self.input.deinit();
    self.ast.deinit(self.referrers.allocator);
}

pub fn removeReferrer(self: *Cell, refer: common.upos) bool {
    return for (self.referrers.items, 0..) |r, i| {
        if (@reduce(.And, r == refer)) {
            _ = self.referrers.swapRemove(i);
            break true;
        }
    } else false;
}
