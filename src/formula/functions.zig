const std = @import("std");
const common = @import("../common.zig");
const AST = @import("AST.zig");
const Sheet = @import("../sheets/Sheet.zig");

pub const Function = *const fn (*const Sheet, []const AST.Value) AST.Value;
const FunctionDecl = std.meta.Tuple(&.{ []const u8, Function });

const NAN = std.math.nan(f64);

fn err(sht: *const Sheet, msg: []const u8) AST.Value {
    const bytes = sht.allocator.alloc(u8, msg.len) catch @panic("Out of memory");
    @memcpy(bytes, msg);
    return AST.Value{ .err = bytes };
}
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
fn len(sht: *const Sheet, args: []const AST.Value) AST.Value {
    if (args.len > 1) return err(sht, "Expected only 1 argument");
    var str = args[0].tostring(sht.allocator) catch @panic("Out of memory");
    defer str.deinit(sht.allocator);
    return .{ .number = @floatFromInt(str.bytes.len) };
}

pub const functions = std.StaticStringMap(Function).initComptime([_]FunctionDecl{
    .{ "SUM", sum },
    .{ "AVG", avg },
    .{ "LEN", len },
});
