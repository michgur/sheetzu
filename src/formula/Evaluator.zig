//! receives ASTs and computes the results
const std = @import("std");
const common = @import("../common.zig");
const Sheet = @import("../sheets/Sheet.zig");
const String = @import("../string/String.zig");
const Function = @import("functions.zig").Function;
const Operator = @import("functions.zig").Operator;
const AST = @import("AST.zig");
const Evaluator = @This();

arena: std.heap.ArenaAllocator,
/// allocator used for temporary allocations during evaluation
allocator: std.mem.Allocator,
///
sheet: *const Sheet,

pub fn init() Evaluator {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    return Evaluator{
        .arena = arena,
        .allocator = arena.allocator(),
        .sheet = undefined,
    };
}

const NAN = std.math.nan(f64);

fn deref(self: *const Evaluator, ref: common.upos) AST.Value {
    return if (self.sheet.cell(ref)) |c| c.value else AST.Value{ .err = "!REF" };
}

pub fn asNumber(self: *const Evaluator, value: AST.Value) f64 {
    return switch (value) {
        .blank, .err => NAN,
        .number => |f| f,
        .string => |s| std.fmt.parseFloat(f64, s.bytes) catch NAN,
        .ref => |ref| self.asNumber(self.deref(ref)),
    };
}

/// memory is owned by evaluator - you probably want to use asOwnedString
pub fn asString(self: *const Evaluator, value: AST.Value) String {
    const bytes = switch (value) {
        .string => |s| return s,
        .number => |n| std.fmt.allocPrint(self.allocator, "{d}", .{n}) catch "!ERR",
        .blank => "",
        .err => |e| e,
        .ref => "!REF",
    };
    return String.init(self.allocator, bytes) catch @panic("Out of memory");
}

pub fn asOwnedString(self: *const Evaluator, allocator: std.mem.Allocator, value: AST.Value) !String {
    return try self.asString(value).clone(allocator);
}

fn applyOp(self: *const Evaluator, op: Operator, val_a: AST.Value, val_b: AST.Value) AST.Value {
    return switch (op) {
        .add => .{
            .number = self.asNumber(val_a) + self.asNumber(val_b),
        },
        .sub => .{
            .number = self.asNumber(val_a) - self.asNumber(val_b),
        },
        .mul => .{
            .number = self.asNumber(val_a) * self.asNumber(val_b),
        },
        .div => .{
            .number = self.asNumber(val_a) / self.asNumber(val_b),
        },
        .concat => b: {
            const stra = self.asString(val_a);
            const strb = self.asString(val_b);
            const concat = std.fmt.allocPrint(self.allocator, "{s}{s}", .{ stra.bytes, strb.bytes }) catch @panic("Out of memory");
            break :b .{
                .string = String.initOwn(self.allocator, concat) catch @panic("alkhjfaeshf"),
            };
        },
    };
}

fn evalInternal(self: *Evaluator, ast: *const AST) AST.Value {
    if (ast.content == .operator) {
        const val_a = self.evalInternal(&ast.children[0]);
        const val_b = self.evalInternal(&ast.children[1]);
        return self.applyOp(ast.content.operator, val_a, val_b);
    }
    if (ast.content == .function) {
        var args = self.allocator.alloc(AST.Value, ast.children.len) catch @panic("WHAT");
        for (ast.children, 0..) |ch, i| {
            args[i] = self.evalInternal(&ch);
        }
        defer {
            for (args) |*arg| {
                arg.deinit(self.allocator);
            }
            self.allocator.free(args);
        }
        return ast.content.function(self, args);
    }
    if (ast.content == .value and ast.content.value == .ref) return self.deref(ast.content.value.ref);
    return ast.content.value;
}

/// evaluates AST, value is owned by the caller.
/// `allocator` is only used for the final value
pub fn eval(
    self: *Evaluator,
    allocator: std.mem.Allocator,
    ast: *const AST,
) !AST.Value {
    defer _ = self.arena.reset(.retain_capacity);

    self.allocator = self.arena.allocator();
    const result = self.evalInternal(ast);
    return result.clone(allocator);
}

pub fn deinit(self: *Evaluator) void {
    self.arena.deinit();
    self.* = undefined;
}
