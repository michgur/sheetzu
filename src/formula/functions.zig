const std = @import("std");
const common = @import("../common.zig");
const AST = @import("AST.zig");
const Sheet = @import("../sheets/Sheet.zig");
const Evaluator = @import("Evaluator.zig");

pub const Operator = enum { add, sub, mul, div, concat };
pub const Function = *const fn (*const Evaluator, []const AST.Value) AST.Value;
const FunctionDecl = std.meta.Tuple(&.{ []const u8, Function });

const NAN = std.math.nan(f64);

fn err(eval: *const Evaluator, msg: []const u8) AST.Value {
    const bytes = eval.allocator.alloc(u8, msg.len) catch @panic("Out of memory");
    @memcpy(bytes, msg);
    return AST.Value{ .err = bytes };
}
fn sum(eval: *const Evaluator, args: []const AST.Value) AST.Value {
    var s: f64 = 0;
    for (args) |arg| {
        s += eval.asNumber(arg);
        if (std.math.isNan(s)) return .{ .number = NAN };
    }
    return .{ .number = s };
}
fn avg(eval: *const Evaluator, args: []const AST.Value) AST.Value {
    var s: f64 = 0;
    for (args) |arg| {
        s += eval.asNumber(arg);
        if (std.math.isNan(s)) return .{ .number = NAN };
    }
    return .{ .number = s / @as(f64, @floatFromInt(args.len)) };
}
fn len(eval: *const Evaluator, args: []const AST.Value) AST.Value {
    if (args.len > 1) return err(eval, "Expected only 1 argument");
    const str = eval.asString(args[0]);
    return .{ .number = @floatFromInt(str.bytes.len) };
}

pub const functions = std.StaticStringMapWithEql(Function, std.ascii.eqlIgnoreCase).initComptime([_]FunctionDecl{
    .{ "SUM", sum },
    .{ "AVG", avg },
    .{ "LEN", len },
});
