const std = @import("std");
const common = @import("../common.zig");
const Sheet = @import("../sheets/Sheet.zig");
const String = @import("../string/String.zig");
const Function = @import("functions.zig").Function;
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

const Operator = enum { add, sub, mul, div, concat };

op: ?union(enum) {
    OP: Operator,
    FN: Function,
} = null,
value: Value = .{ .blank = {} },
// child nodes. memory is owned by the parent
children: []AST = &.{},

fn applyOp(sht: *const Sheet, op: Operator, val_a: Value, val_b: Value) Value {
    return switch (op) {
        .add => .{
            .number = val_a.numeralValue(sht) + val_b.numeralValue(sht),
        },
        .sub => .{
            .number = val_a.numeralValue(sht) - val_b.numeralValue(sht),
        },
        .mul => .{
            .number = val_a.numeralValue(sht) * val_b.numeralValue(sht),
        },
        .div => .{
            .number = val_a.numeralValue(sht) / val_b.numeralValue(sht),
        },
        .concat => b: {
            var stra = val_a.tostring(sht.allocator) catch @panic("OUOUO");
            var strb = val_b.tostring(sht.allocator) catch @panic("OUOUO");
            defer stra.deinit(sht.allocator);
            defer strb.deinit(sht.allocator);
            const concat = sht.allocator.alloc(u8, stra.bytes.len + strb.bytes.len) catch @panic("OUEOFEJS");
            @memcpy(concat[0..stra.bytes.len], stra.bytes);
            @memcpy(concat[stra.bytes.len..], strb.bytes);
            break :b .{
                .string = String.initOwn(sht.allocator, concat) catch @panic("alkhjfaeshf"),
            };
        },
    };
}

pub fn eval(self: *const AST, sht: *const Sheet) Value {
    if (self.op) |op| {
        return switch (op) {
            .OP => |o| b: {
                var val_a = self.children[0].eval(sht);
                var val_b = self.children[1].eval(sht);
                defer val_a.deinit(sht.allocator);
                defer val_b.deinit(sht.allocator);
                break :b applyOp(sht, o, val_a, val_b);
            },
            .FN => |f| b: {
                var args = sht.allocator.alloc(Value, self.children.len) catch @panic("WHAT");
                for (self.children, 0..) |ch, i| {
                    args[i] = ch.eval(sht);
                }
                defer {
                    for (args) |*arg| {
                        arg.deinit(sht.allocator);
                    }
                    sht.allocator.free(args);
                }
                break :b f(sht, args);
            },
        };
    }
    if (self.value == .ref) {
        if (sht.cell(self.value.ref)) |c| return c.value.clone(sht.allocator) catch unreachable;
        const msg_stack = "!REF";
        const msg = sht.allocator.alloc(u8, msg_stack.len) catch unreachable;
        @memcpy(msg, msg_stack);
        return .{ .err = msg };
    }
    if (self.value == .string) {
        const res = self.value.string.clone(sht.allocator) catch unreachable;
        return .{ .string = res };
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

pub fn clone(self: *AST, allocator: std.mem.Allocator) !AST {
    var result = AST{
        .op = self.op,
        .value = self.value.clone(allocator),
        .children = try allocator.alloc(AST, self.children.len),
    };
    for (self.children, 0..) |child, i| {
        result.children[i] = try child.clone(allocator);
    }
    return result;
}
