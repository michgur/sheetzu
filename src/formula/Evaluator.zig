//! receives ASTs and computes the results
const std = @import("std");
const common = @import("../common.zig");
const Sheet = @import("../sheets/Sheet.zig");
const String = @import("../string/String.zig");
const entities = @import("entities.zig");
const AST = @import("AST.zig");
const Evaluator = @This();

// we evaluate using a mixture of
// - constant values     (owned by AST)
// - references          (owned by sheet)
// - intermediate values (owned by evaluator)
// which makes it difficult to know when we own a value and can free it.
// therefore, we use a temporary arena and reset it on every evaluation.
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

pub fn deinit(self: *Evaluator) void {
    self.arena.deinit();
    self.* = undefined;
}

fn resetArena(self: *Evaluator) void {
    _ = self.arena.reset(.retain_capacity);
    self.allocator = self.arena.allocator();
}

fn deref(self: *const Evaluator, ref: common.upos) entities.Value {
    return if (self.sheet.cell(ref)) |c| c.value else entities.Value{ .err = "!REF" };
}

const NAN = std.math.nan(f64);
pub fn asNumber(self: *const Evaluator, value: entities.Value) f64 {
    return switch (value) {
        .blank, .err => NAN,
        .number => |f| f,
        .string => |s| std.fmt.parseFloat(f64, s.bytes) catch NAN,
        .ref => |ref| self.asNumber(self.deref(ref)),
        .range => NAN,
    };
}

/// memory is owned by evaluator - you probably want to use asOwnedString
pub fn asString(self: *const Evaluator, value: entities.Value) String {
    const bytes = switch (value) {
        .string => |s| return s,
        .number => |n| std.fmt.allocPrint(self.allocator, "{d}", .{n}) catch "!ERR",
        .blank => "",
        .err => |e| e,
        .ref => "!REF",
        .range => "!RNG",
    };
    return String.init(self.allocator, bytes) catch @panic("Out of memory");
}

pub fn asOwnedString(self: *Evaluator, allocator: std.mem.Allocator, value: entities.Value) !String {
    defer self.resetArena(); // we may safely reset arena, as the string is being allocated on a different allocator
    return try self.asString(value).clone(allocator);
}

fn applyOp(self: *const Evaluator, op: entities.Operator, val_a: entities.Value, val_b: entities.Value) entities.Value {
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

fn evalInternal(self: *Evaluator, ast: *const AST) entities.Value {
    if (ast.content == .operator) {
        const val_a = self.evalInternal(&ast.children[0]);
        const val_b = self.evalInternal(&ast.children[1]);
        return self.applyOp(ast.content.operator, val_a, val_b);
    }
    if (ast.content == .function) {
        var args = self.allocator.alloc(entities.Value, ast.children.len) catch @panic("WHAT");
        defer self.allocator.free(args);
        for (ast.children, 0..) |ch, i| {
            args[i] = self.evalInternal(&ch);
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
) !entities.Value {
    defer self.resetArena();
    const result = self.evalInternal(ast);
    return result.clone(allocator);
}

pub fn rangeIterator(self: *const Evaluator, range: entities.Range) RangeIterator {
    const end = @min(self.sheet.size -| common.upos{ 1, 1 }, range.end);
    return RangeIterator{ .sheet = self.sheet, .start = range.start, .curr = range.start, .end = end };
}

const RangeIterator = struct {
    sheet: *const Sheet,
    start: common.upos,
    end: common.upos,
    curr: ?common.upos,

    pub inline fn next(self: *RangeIterator) ?entities.Value {
        return if (self.nextRef()) |ref| if (self.sheet.cell(ref)) |cell| cell.value else null else null;
    }

    pub fn nextRef(self: *RangeIterator) ?common.upos {
        defer b: {
            const curr = self.curr orelse break :b;
            if (curr[1] + 1 <= self.end[1]) {
                self.curr.?[1] += 1;
            } else if (curr[0] + 1 <= self.end[0]) {
                self.curr.?[0] += 1;
                self.curr.?[1] = self.start[1];
            } else {
                self.curr = null;
            }
        }

        return self.curr;
    }
};
