const std = @import("std");
const common = @import("../common.zig");
const Sheet = @import("../sheets/Sheet.zig");
const String = @import("../string/String.zig");
const AST = @This();

pub const NAN = std.math.nan(f64);

pub const Value = union(enum) {
    blank: void,
    number: f64,
    string: String,
    ref: common.upos,
    err: []const u8,

    pub fn numeralValue(self: *const Value, sht: *const Sheet) f64 {
        const result = switch (self.*) {
            .number => |f| f,
            .ref => |ref| if (sht.cell(ref)) |c| c.ast.evalNumeral(sht) else NAN,
            .blank, .err => NAN,
            .string => |s| std.fmt.parseFloat(f64, s.bytes) catch NAN,
        };
        return result;
    }

    pub fn deinit(self: *Value, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .string => |*s| s.deinit(allocator),
            .err => |e| allocator.free(e),
            else => {},
        }
        self.* = undefined;
    }

    pub fn tostring(self: *const Value, allocator: std.mem.Allocator) !String {
        return switch (self.*) {
            .string => |s| try s.clone(allocator),
            .number => |n| try String.init(allocator, std.fmt.bufPrint(&temp_buf, "{d}", .{n}) catch "!ERR"),
            .blank => try String.init(allocator, ""),
            .err => |e| try String.init(allocator, e),
            .ref => try String.init(allocator, "!REF"), // not a real possibility, we don't evaluate to refs
        };
    }
    var temp_buf: [1024]u8 = undefined;
};

const Operator = enum { add, sub, mul, div };

op: ?Operator = null,
value: Value = .{ .blank = {} },
// child nodes. memory is owned by the parent
children: []AST = &.{},

pub fn eval(self: *const AST, sht: *const Sheet) Value {
    if (self.op) |op| {
        switch (op) {
            .add => return .{
                .number = self.children[0].evalNumeral(sht) + self.children[1].evalNumeral(sht),
            },
            .sub => return .{
                .number = self.children[0].evalNumeral(sht) - self.children[1].evalNumeral(sht),
            },
            .mul => return .{
                .number = self.children[0].evalNumeral(sht) * self.children[1].evalNumeral(sht),
            },
            .div => return .{
                .number = self.children[0].evalNumeral(sht) / self.children[1].evalNumeral(sht),
            },
        }
    }
    if (self.value == .ref) {
        if (sht.cell(self.value.ref)) |c| return c.value;
        const msg_stack = "!REF";
        const msg = sht.allocator.alloc(u8, msg_stack.len) catch unreachable;
        @memcpy(msg, msg_stack);
        return .{ .err = msg };
    }
    return self.value;
}

pub fn evalNumeral(self: *const AST, sht: *const Sheet) f64 {
    return self.eval(sht).numeralValue(sht);
}

pub fn deinit(self: *AST, allocator: std.mem.Allocator) void {
    self.value.deinit(allocator);
    for (self.children) |*child| {
        child.deinit(allocator);
    }
    allocator.free(self.children);
    self.* = undefined;
}

pub fn allRefs(self: *const AST) []const common.upos {
    const buf: [40]common.upos = undefined;
    var i: usize = 0;
    if (self.value == .ref) {
        buf[0] = self.value.ref;
        i = 1;
    }
    for (self.children) |child| {
        const refs = child.allRefs();
        for (refs) |r| {
            for (buf, 0..i) |b, _| {
                if (@reduce(.And, b == r)) break;
            } else {
                buf[i] = r;
                i += 1;
                if (i >= buf.len) @panic(std.fmt.comptimePrint("Oops, I thought {d} refs would be enough...", .{buf.len}));
            }
        }
    }
    return buf[0..i];
}
