const std = @import("std");
const DisplayString = @import("../DisplayString.zig");

pub const CellData = union(enum) {
    Numeral: i64,
    String: *const DisplayString,
    Blank: void,

    pub fn parse(data: *const DisplayString) CellData {
        if (parseNumeral(data)) |n| {
            return .{ .Numeral = n };
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
