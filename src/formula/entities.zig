const std = @import("std");
const common = @import("../common.zig");
const String = @import("../string/String.zig");
const Evaluator = @import("Evaluator.zig");

pub const Range = struct {
    start: common.upos,
    end: common.upos,

    pub fn size(self: *const Range) usize {
        return @reduce(.Mul, self.end -| self.start);
    }
};

pub const Entity = union(enum) {
    value: Value,
    operator: Operator,
    function: Function,
    // todo: move ref from Value to this
};

pub const Value = union(enum) {
    blank: void,
    number: f64,
    string: String,
    ref: common.upos,
    range: Range,
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

    pub fn format(
        self: *const Value,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        switch (self.*) {
            .number => |number| try writer.print("{d}", .{number}),
            .string => |string| try writer.print("{s}", .{string.bytes}),
            .ref => |ref| {
                var buf: [32]u8 = undefined;
                const col = common.bb26(ref[1], &buf);
                try writer.print("{s}{d}", .{ col, ref[0] + 1 });
            },
            .range => |range| {
                var buf: [32]u8 = undefined;
                var col = common.bb26(range.start[1], &buf);
                try writer.print("{s}{d}:", .{ col, range.start[0] + 1 });
                col = common.bb26(range.end[1], &buf);
                try writer.print("{s}{d}", .{ col, range.end[0] + 1 });
            },
            else => {},
        }
    }
};

pub const Operator = enum(u8) {
    add = '+',
    sub = '-',
    mul = '*',
    div = '/',
    concat = '&',
};
pub const Function = *const fn (*const Evaluator, []const Value) Value;
