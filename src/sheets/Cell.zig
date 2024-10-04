const std = @import("std");
const common = @import("../common.zig");
const Style = @import("../render/Style.zig");
const String = @import("../string/String.zig");
const StringWriter = @import("../string/StringWriter.zig");
const AST = @import("../formula/AST.zig");

const Cell = @This();

style: Style = .{},
value: AST.Value = .{ .blank = {} },
str: String = .{},
input: std.ArrayListUnmanaged(u8) = .{},
dirty: bool = false,
ast: AST = .{},
referrers: std.ArrayListUnmanaged(common.upos) = .{},

pub fn deinit(self: *Cell, allocator: std.mem.Allocator) void {
    self.referrers.deinit(allocator);
    self.str.deinit(allocator);
    self.input.deinit(allocator);
    self.ast.deinit(allocator);
    self.value.deinit(allocator);
}

pub fn removeReferrer(self: *Cell, referrer: common.upos) bool {
    return for (self.referrers.items, 0..) |r, i| {
        if (@reduce(.And, r == referrer)) {
            _ = self.referrers.swapRemove(i);
            break true;
        }
    } else false;
}
