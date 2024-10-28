const std = @import("std");
const common = @import("../common.zig");
const Sheet = @import("../sheets/Sheet.zig");
const String = @import("../string/String.zig");
const entities = @import("entities.zig");
const functions = @import("functions.zig").functions;
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

pub fn clone(self: *const AST, allocator: std.mem.Allocator) !AST {
    const children = try allocator.alloc(AST, self.children.len);
    for (0.., self.children) |i, child| {
        children[i] = try child.clone(allocator);
    }
    const content = switch (self.content) {
        .value => |v| entities.Entity{
            .value = try v.clone(allocator),
        },
        else => self.content,
    };
    return AST{
        .children = children,
        .content = content,
    };
}

pub fn move(self: *AST, offset: common.ipos) void {
    if (self.content == .value) {
        switch (self.content.value) {
            .ref => |ref| self.content.value = .{ .ref = ref + offset },
            .range => |range| {
                self.content.value = .{ .range = entities.Range{
                    .start = range.start + offset,
                    .end = range.end + offset,
                } };
            },
            else => {},
        }
    }
    for (self.children) |*child| {
        child.move(offset);
    }
}

pub fn format(
    self: *const AST,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    switch (self.content) {
        .operator => |op| {
            try self.children[0].format(fmt, options, writer);
            try writer.print("{c}", .{@intFromEnum(op)});
            try self.children[1].format(fmt, options, writer);
        },
        .function => |fun| {
            const func = for (functions.keys(), functions.values()) |k, v| {
                if (v == fun) break k;
            } else "?FN?"; // TODO: a less embarrassing lookup
            try writer.print("{s}(", .{func});
            if (self.children.len > 0) {
                for (self.children[0 .. self.children.len - 1]) |child| {
                    try child.format(fmt, options, writer);
                    try writer.print(", ", .{});
                }
                try self.children[self.children.len - 1].format(fmt, options, writer);
                try writer.print(")", .{});
            }
        },
        .value => |value| {
            try writer.print("{s}", .{value});
        },
    }
}
