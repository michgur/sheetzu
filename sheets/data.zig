const std = @import("std");
const DisplayString = @import("../DisplayString.zig");
const common = @import("../common.zig");

pub const Formula = struct {
    depa: common.upos,
    depb: common.upos,
};

pub const CellData = union(enum) {
    Numeral: i64,
    String: *const DisplayString,
    Blank: void,
    Formula: Formula,

    pub fn parse(data: *const DisplayString) CellData {
        if (parseNumeral(data)) |n| {
            return .{ .Numeral = n };
        }
        if (parseFormula(data)) |f| {
            return .{ .Formula = f };
        }
        return .{ .String = data };
    }
};

fn parseNumeral(data: *const DisplayString) ?i64 {
    var result: i64 = 0;
    for (data.bytes.items) |b| {
        if (b < '0' or b > '9') return null;
        result *= 10;
        result += b - '0';
    }
    return result;
}

fn parseFormula(data: *const DisplayString) ?Formula {
    const f = data.bytes.items;
    if (f[0] != '=') return null;
    const ac = if (f[1] <= 'Z' and f[1] >= 'A') f[1] - 'A' else return null;
    const bc = if (f[4] <= 'Z' and f[4] >= 'A') f[4] - 'A' else return null;
    if (f[3] != '+') return null;
    const ar = if (f[2] <= '9' and f[2] >= '0') f[2] - '1' else return null;
    const br = if (f[5] <= '9' and f[5] >= '0') f[5] - '1' else return null;
    return Formula{
        .depa = .{ ar, ac },
        .depb = .{ br, bc },
    };
}
