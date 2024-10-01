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

///
/// Convert an integer to its Bijective Base 26 form
/// https://en.wikipedia.org/wiki/Bijective_numeration#The_bijective_base-26_system
/// Writes result onto the end of buf. If buf is too short, only the least significant digits are written
///
pub fn bb26(n: usize, buf: []u8) []const u8 {
    var n1 = n + 1; // 1-based numbering

    const b: *[]u8 = @constCast(&buf);
    var w: usize = 0;
    while (n1 > 0 and w <= buf.len) {
        w += 1;
        const mod = n1 % 26;
        const off = if (mod == 0) 26 else mod;
        b.*[b.len - w] = @intCast(('A' - 1) + off);
        n1 = (n1 - off) / 26;
    }
    return b.*[b.len - w ..];
}

pub fn frombb26(b: []const u8) usize {
    var result: usize = 0;
    for (b) |digit| {
        result *= 26;
        result += digit - 'A' + 1;
    }
    return result - 1;
}

const expectEqualStrings = std.testing.expectEqualStrings;
const expectEqual = std.testing.expectEqual;
test "b26" {
    var buf: [8]u8 = undefined;
    try expectEqualStrings("A", bb26(0, &buf));
    try expectEqualStrings("Z", bb26(25, &buf));
    try expectEqualStrings("AA", bb26(26, &buf));
    try expectEqualStrings("AAA", bb26(702, &buf));
    try expectEqualStrings("AAAAA", bb26(475254, &buf));
    try expectEqualStrings("ABCDE", bb26(494264, &buf));
    try expectEqualStrings("ZZZZZ", bb26(12356629, &buf));
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

pub const C = @cImport(@cInclude("src/wcwidth.c"));
