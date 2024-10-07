const std = @import("std");
const common = @import("../common.zig");
const Sheet = @import("../sheets/Sheet.zig");
const String = @import("../string/String.zig");
const entities = @import("entities.zig");
const AST = @This();

content: entities.Entity = .{ .value = .{ .blank = {} } },
// child nodes. memory is owned by the parent
children: []AST = &.{},

pub fn deinit(self: *AST, allocator: std.mem.Allocator) void {
    if (self.content == .value) {
        self.content.value.deinit(allocator);
    }
    for (self.children) |*child| {
        child.deinit(allocator);
    }
    allocator.free(self.children);
    self.* = undefined;
}
