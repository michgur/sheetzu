const std = @import("std");
const entities = @import("entities.zig");
const Evaluator = @import("Evaluator.zig");

const FunctionDecl = std.meta.Tuple(&.{ []const u8, entities.Function });

const NAN = std.math.nan(f64);

fn err(eval: *const Evaluator, msg: []const u8) entities.Value {
    const bytes = eval.allocator.alloc(u8, msg.len) catch @panic("Out of memory");
    @memcpy(bytes, msg);
    return entities.Value{ .err = bytes };
}
fn sum(eval: *const Evaluator, args: []const entities.Value) entities.Value {
    var s: f64 = 0;
    for (args) |arg| {
        if (arg == .range) {
            var iter = eval.rangeIterator(arg.range);
            while (iter.next()) |val| {
                s += eval.asNumber(val);
            }
        } else s += eval.asNumber(arg);
        if (std.math.isNan(s)) return .{ .number = NAN };
    }
    return .{ .number = s };
}
fn avg(eval: *const Evaluator, args: []const entities.Value) entities.Value {
    var s: f64 = 0;
    var l: f64 = 0;
    for (args) |arg| {
        if (arg == .range) {
            var iter = eval.rangeIterator(arg.range);
            while (iter.next()) |val| {
                s += eval.asNumber(val);
                l += 1;
            }
        } else {
            s += eval.asNumber(arg);
            l += 1;
        }
        if (std.math.isNan(s)) return .{ .number = NAN };
    }
    return .{ .number = s / l };
}
fn len(eval: *const Evaluator, args: []const entities.Value) entities.Value {
    if (args.len > 1) return err(eval, "Expected only 1 argument");
    const str = eval.asString(args[0]);
    return .{ .number = @floatFromInt(str.bytes.len) };
}

pub const functions = std.StaticStringMapWithEql(entities.Function, std.ascii.eqlIgnoreCase).initComptime([_]FunctionDecl{
    .{ "SUM", sum },
    .{ "AVG", avg },
    .{ "LEN", len },
});

pub inline fn get(str: []const u8) ?entities.Function {
    return functions.get(str);
}
