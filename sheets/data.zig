const std = @import("std");
const utf8 = @import("../utf8.zig");

pub const CellData = union(enum) {
    Numeral: i64,
    String: *const utf8.Str,
    Blank: void,

    pub fn parse(data: *const utf8.Str) CellData {
        if (parseNumeral(data)) |n| {
            return .{ .Numeral = n };
        }
        return .{ .String = data };
    }
};

fn parseNumeral(data: *const utf8.Str) ?i64 {
    var result: i64 = 0;
    for (data.bytes.items) |b| {
        if (b < '0' or b > '9') return null;
        result *= 10;
        result += b - '0';
    }
    return result;
}
