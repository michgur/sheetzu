const std = @import("std");
const common = @import("../common.zig");
const AST = @import("AST.zig");
const Sheet = @import("../sheets/Sheet.zig");

pub const Function = *const fn (*const Sheet, []const AST.Value) AST.Value;
const FunctionDecl = std.meta.Tuple(&.{ []const u8, Function });

const NAN = std.math.nan(f64);

fn sum(sht: *const Sheet, args: []const AST.Value) AST.Value {
    var s: f64 = 0;
    for (args) |arg| {
        s += arg.numeralValue(sht);
        if (std.math.isNan(s)) return .{ .number = NAN };
    }
    return .{ .number = s };
}
fn avg(sht: *const Sheet, args: []const AST.Value) AST.Value {
    var s: f64 = 0;
    for (args) |arg| {
        s += arg.numeralValue(sht);
        if (std.math.isNan(s)) return .{ .number = NAN };
    }
    return .{ .number = s / @as(f64, @floatFromInt(args.len)) };
}

pub const functions = std.StaticStringMap(Function).initComptime([_]FunctionDecl{
    .{ "SUM", sum },
    .{ "AVG", avg },
});
