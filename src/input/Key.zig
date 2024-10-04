const std = @import("std");

const Key = @This();

codepoint: Codepoint,
bytes: []const u8,

pub const Codepoint = enum(u21) {
    nul = 0x00,
    tab = 0x09,
    escape = 0x1B,
    space = 0x20,
    backspace = 0x7F,
    equal = 0x3D,
    multicodepoint = std.math.maxInt(u21),
    open_square_bracket = 0x5b,
    a = 0x61,
    b = 0x62,
    c = 0x63,
    d = 0x64,
    e = 0x65,
    f = 0x66,
    g = 0x67,
    h = 0x68,
    i = 0x69,
    j = 0x6a,
    k = 0x6b,
    l = 0x6c,
    m = 0x6d,
    n = 0x6e,
    o = 0x6f,
    p = 0x70,
    q = 0x71,
    r = 0x72,
    s = 0x73,
    t = 0x74,
    u = 0x75,
    v = 0x76,
    w = 0x77,
    x = 0x78,
    y = 0x79,
    z = 0x7a,
    csi = 0x9b,
    arrow_up,
    arrow_down,
    arrow_left,
    arrow_right,
    _,
};

const CSI = [_]Codepoint{ .arrow_up, .arrow_down, .arrow_right, .arrow_left };
pub fn fromCSI(value: u8) Codepoint {
    return CSI[value - 'A'];
}
