const std = @import("std");
const common = @import("../common.zig");
const Sheet = @import("../sheets/Sheet.zig");
const String = @import("../string/String.zig");
const Function = @import("functions.zig").Function;
const Operator = @import("functions.zig").Operator;
const AST = @This();

pub const NAN = std.math.nan(f64);

pub const Value = union(enum) {
    blank: void,
    number: f64,
    string: String,
    ref: common.upos,
    err: []const u8,

    pub fn deinit(self: *Value, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .string => |*s| s.deinit(allocator),
            .err => |e| allocator.free(e),
            else => {},
        }
        self.* = undefined;
    }

    pub fn clone(self: *const Value, allocator: std.mem.Allocator) !Value {
        return switch (self.*) {
            .string => |s| .{ .string = try s.clone(allocator) },
            .err => |e| t: {
                const new_e = try allocator.alloc(u8, e.len);
                @memcpy(new_e, e);
                break :t .{ .err = new_e };
            },
            else => self.*,
        };
    }
};

// op: ?union(enum) {
//     OP: Operator,
//     FN: Function,
// } = null,
// value: Value = .{ .blank = {} },
content: union(enum) {
    value: Value,
    operator: Operator,
    function: Function,
} = .{ .value = .{ .blank = {} } },
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
