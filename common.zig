const std = @import("std");

/// pair of (row, column)
pub const ipos = @Vector(2, isize);
pub const upos = @Vector(2, usize);

pub const Rect = struct {
    top_left: ipos,
    size: upos,
};

pub inline fn posCast(pos: anytype) switch (@TypeOf(pos)) {
    ipos => upos,
    upos => ipos,
    else => |T| @compileError(std.fmt.comptimePrint("Unsupported type for posCast - {n}\n", .{@typeName(T)})),
} {
    return switch (@TypeOf(pos)) {
        ipos => upos{ @intCast(pos[0]), @intCast(pos[1]) },
        upos => ipos{ @intCast(pos[0]), @intCast(pos[1]) },
        else => unreachable,
    };
}

// supports up to 16 digits which should be way more than enough for cell refs
pub fn b26(n: usize) []const u8 {
    if (n == 0) return "A";

    const w = 1 + std.math.log(usize, 26, n);
    std.debug.assert(w <= 16);

    var buf: [16]u8 = undefined;
    var res = buf[16 - w ..];
    var d = n;
    for (0..w) |i| {
        res[w - i - 1] = @intCast('A' + (d % 26));
        d /= 26;
    }
    return res;
}

pub fn b10(n: usize) []const u8 {
    if (n == 0) return "0";

    const w = 1 + std.math.log10(n);
    std.debug.assert(w <= 16);

    var buf: [16]u8 = undefined;
    var res = buf[16 - w ..];
    var d = n;
    for (0..w) |i| {
        res[w - i - 1] = @intCast('0' + (d % 10));
        d /= 10;
    }
    return res;
}

pub const C = @cImport(@cInclude("wcwidth.c"));
