const std = @import("std");

const Key = @This();

type: Type,
alt: bool = false,
ctrl: bool = false,
shift: bool = false,
paste: bool = false,
bytes: []const u8,

// values are control codes
// https://en.wikipedia.org/wiki/C0_and_C1_control_codes
pub const Type = enum(u8) {
    null = 0,
    a = 1,
    b = 2,
    c = 3,
    d = 4,
    e = 5,
    f = 6,
    g = 7,
    h = 8,
    i = 9,
    j = 10,
    k = 11,
    l = 12,
    m = 13,
    n = 14,
    o = 15,
    p = 16,
    q = 17,
    r = 18,
    t = 19,
    s = 20,
    u = 21,
    v = 22,
    w = 23,
    x = 24,
    y = 25,
    z = 26,
    open_bracket = 27,
    backslash = 28,
    close_bracket = 29,
    caret = 30,
    underscore = 31,
    space = 32,
    question_mark = 127,
    up,
    down,
    right,
    left,
    tab,
    home,
    end,
    pg_up,
    pg_down,
    insert,
    f1,
    f2,
    f3,
    f4,
    f5,
    f6,
    f7,
    f8,
    f9,
    f10,
    f11,
    f12,
    f13,
    f14,
    f15,
    f16,
    f17,
    f18,
    f19,
    f20,
    unknown,
    runes,
};

// const ext_sequences = blk: {
//     const map = std.StaticStringMap(Key).initComptime();
// };

const SeqEntry = std.meta.Tuple(&.{ []const u8, Key });
const sequences = std.StaticStringMap(Key).initComptime([_]SeqEntry{
    // Arrow keys
    .{ "\x1b[A", .{ .type = .up } },
    .{ "\x1b[B", .{ .type = .down } },
    .{ "\x1b[C", .{ .type = .right } },
    .{ "\x1b[D", .{ .type = .left } },
    .{ "\x1b[1;2A", .{ .shift = true, .type = .up } },
    .{ "\x1b[1;2B", .{ .shift = true, .type = .down } },
    .{ "\x1b[1;2C", .{ .shift = true, .type = .right } },
    .{ "\x1b[1;2D", .{ .shift = true, .type = .left } },
    .{ "\x1b[OA", .{ .shift = true, .type = .up } }, // DECCKM
    .{ "\x1b[OB", .{ .shift = true, .type = .down } }, // DECCKM
    .{ "\x1b[OC", .{ .shift = true, .type = .right } }, // DECCKM
    .{ "\x1b[OD", .{ .shift = true, .type = .left } }, // DECCKM
    .{ "\x1b[a", .{ .shift = true, .type = .up } }, // urxvt
    .{ "\x1b[b", .{ .shift = true, .type = .down } }, // urxvt
    .{ "\x1b[c", .{ .shift = true, .type = .right } }, // urxvt
    .{ "\x1b[d", .{ .shift = true, .type = .left } }, // urxvt
    .{ "\x1b[1;3A", .{ .type = .up, .alt = true } },
    .{ "\x1b[1;3B", .{ .type = .down, .alt = true } },
    .{ "\x1b[1;3C", .{ .type = .right, .alt = true } },
    .{ "\x1b[1;3D", .{ .type = .left, .alt = true } },

    .{ "\x1b[1;4A", .{ .shift = true, .type = .up, .alt = true } },
    .{ "\x1b[1;4B", .{ .shift = true, .type = .down, .alt = true } },
    .{ "\x1b[1;4C", .{ .shift = true, .type = .right, .alt = true } },
    .{ "\x1b[1;4D", .{ .shift = true, .type = .left, .alt = true } },

    .{ "\x1b[1;5A", .{ .ctrl = true, .type = .up } },
    .{ "\x1b[1;5B", .{ .ctrl = true, .type = .down } },
    .{ "\x1b[1;5C", .{ .ctrl = true, .type = .right } },
    .{ "\x1b[1;5D", .{ .ctrl = true, .type = .left } },
    .{ "\x1b[Oa", .{ .ctrl = true, .type = .up, .alt = true } }, // urxvt
    .{ "\x1b[Ob", .{ .ctrl = true, .type = .down, .alt = true } }, // urxvt
    .{ "\x1b[Oc", .{ .ctrl = true, .type = .right, .alt = true } }, // urxvt
    .{ "\x1b[Od", .{ .ctrl = true, .type = .left, .alt = true } }, // urxvt
    .{ "\x1b[1;6A", .{ .shift = true, .ctrl = true, .type = .up } },
    .{ "\x1b[1;6B", .{ .shift = true, .ctrl = true, .type = .down } },
    .{ "\x1b[1;6C", .{ .shift = true, .ctrl = true, .type = .right } },
    .{ "\x1b[1;6D", .{ .shift = true, .ctrl = true, .type = .left } },
    .{ "\x1b[1;7A", .{ .ctrl = true, .type = .up, .alt = true } },
    .{ "\x1b[1;7B", .{ .ctrl = true, .type = .down, .alt = true } },
    .{ "\x1b[1;7C", .{ .ctrl = true, .type = .right, .alt = true } },
    .{ "\x1b[1;7D", .{ .ctrl = true, .type = .left, .alt = true } },
    .{ "\x1b[1;8A", .{ .shift = true, .ctrl = true, .type = .up, .alt = true } },
    .{ "\x1b[1;8B", .{ .shift = true, .ctrl = true, .type = .down, .alt = true } },
    .{ "\x1b[1;8C", .{ .shift = true, .ctrl = true, .type = .right, .alt = true } },
    .{ "\x1b[1;8D", .{ .shift = true, .ctrl = true, .type = .left, .alt = true } },

    // Miscellaneous keys
    .{ "\x1b[Z", .{ .shift = true, .type = .tab } },

    .{ "\x1b[2~", .{ .type = .insert } },
    .{ "\x1b[3;2~", .{ .type = .insert, .alt = true } },

    .{ "\x1b[3~", .{ .type = .delete } },
    .{ "\x1b[3;3~", .{ .type = .delete, .alt = true } },

    .{ "\x1b[5~", .{ .type = .pg_up } },
    .{ "\x1b[5;3~", .{ .type = .pg_up, .alt = true } },
    .{ "\x1b[5;5~", .{ .ctrl = true, .type = .pg_up } },
    .{ "\x1b[5^", .{ .ctrl = true, .type = .pg_up } }, // urxvt
    .{ "\x1b[5;7~", .{ .ctrl = true, .type = .pg_up, .alt = true } },

    .{ "\x1b[6~", .{ .type = .pg_down } },
    .{ "\x1b[6;3~", .{ .type = .pg_down, .alt = true } },
    .{ "\x1b[6;5~", .{ .ctrl = true, .type = .pg_down } },
    .{ "\x1b[6^", .{ .ctrl = true, .type = .pg_down } }, // urxvt
    .{ "\x1b[6;7~", .{ .ctrl = true, .type = .pg_down, .alt = true } },

    .{ "\x1b[1~", .{ .type = .home } },
    .{ "\x1b[H", .{ .type = .home } }, // xterm, lxterm
    .{ "\x1b[1;3H", .{ .type = .home, .alt = true } }, // xterm, lxterm
    .{ "\x1b[1;5H", .{ .ctrl = true, .type = .home } }, // xterm, lxterm
    .{ "\x1b[1;7H", .{ .ctrl = true, .type = .home, .alt = true } }, // xterm, lxterm
    .{ "\x1b[1;2H", .{ .shift = true, .type = .home } }, // xterm, lxterm
    .{ "\x1b[1;4H", .{ .shift = true, .type = .home, .alt = true } }, // xterm, lxterm
    .{ "\x1b[1;6H", .{ .shift = true, .ctrl = true, .type = .home } }, // xterm, lxterm
    .{ "\x1b[1;8H", .{ .shift = true, .ctrl = true, .type = .home, .alt = true } }, // xterm, lxterm

    .{ "\x1b[4~", .{ .type = .end } },
    .{ "\x1b[F", .{ .type = .end } }, // xterm, lxterm
    .{ "\x1b[1;3F", .{ .type = .end, .alt = true } }, // xterm, lxterm
    .{ "\x1b[1;5F", .{ .ctrl = true, .type = .end } }, // xterm, lxterm
    .{ "\x1b[1;7F", .{ .ctrl = true, .type = .end, .alt = true } }, // xterm, lxterm
    .{ "\x1b[1;2F", .{ .shift = true, .type = .end } }, // xterm, lxterm
    .{ "\x1b[1;4F", .{ .shift = true, .type = .end, .alt = true } }, // xterm, lxterm
    .{ "\x1b[1;6F", .{ .shift = true, .ctrl = true, .type = .end } }, // xterm, lxterm
    .{ "\x1b[1;8F", .{ .shift = true, .ctrl = true, .type = .end, .alt = true } }, // xterm, lxterm
    .{ "\x1b[7~", .{ .type = .home } }, // urxvt
    .{ "\x1b[7^", .{ .ctrl = true, .type = .home } }, // urxvt
    .{ "\x1b[7$", .{ .shift = true, .type = .home } }, // urxvt
    .{ "\x1b[7@", .{ .shift = true, .ctrl = true, .type = .home } }, // urxvt
    .{ "\x1b[8~", .{ .type = .end } }, // urxvt
    .{ "\x1b[8^", .{ .ctrl = true, .type = .end } }, // urxvt
    .{ "\x1b[8$", .{ .shift = true, .type = .end } }, // urxvt
    .{ "\x1b[8@", .{ .shift = true, .ctrl = true, .type = .end } }, // urxvt

    // Function keys, Linux console
    .{ "\x1b[[A", .{ .type = .f1 } }, // linux console
    .{ "\x1b[[B", .{ .type = .f2 } }, // linux console
    .{ "\x1b[[C", .{ .type = .f3 } }, // linux console
    .{ "\x1b[[D", .{ .type = .f4 } }, // linux console
    .{ "\x1b[[E", .{ .type = .f5 } }, // linux console

    // Function keys, X11
    .{ "\x1b_OP", .{ .type = .f1 } }, // vt100, xterm
    .{ "\x1b_OQ", .{ .type = .f2 } }, // vt100, xterm
    .{ "\x1b_OR", .{ .type = .f3 } }, // vt100, xterm
    .{ "\x1b_OS", .{ .type = .f4 } }, // vt100, xterm
    .{ "\x1b[1;3P", .{ .type = .f1, .alt = true } }, // vt100, xterm
    .{ "\x1b[1;3Q", .{ .type = .f2, .alt = true } }, // vt100, xterm
    .{ "\x1b[1;3R", .{ .type = .f3, .alt = true } }, // vt100, xterm
    .{ "\x1b[1;3S", .{ .type = .f4, .alt = true } }, // vt100, xterm
    .{ "\x1b[11~", .{ .type = .f1 } }, // urxvt
    .{ "\x1b[12~", .{ .type = .f2 } }, // urxvt
    .{ "\x1b[13~", .{ .type = .f3 } }, // urxvt
    .{ "\x1b[14~", .{ .type = .f4 } }, // urxvt
    .{ "\x1b[15~", .{ .type = .f5 } }, // vt100, xterm, also urxvt
    .{ "\x1b[15;3~", .{ .type = .f5, .alt = true } }, // vt100, xterm, also urxvt
    .{ "\x1b[17~", .{ .type = .f6 } }, // vt100, xterm, also urxvt
    .{ "\x1b[18~", .{ .type = .f7 } }, // vt100, xterm, also urxvt
    .{ "\x1b[19~", .{ .type = .f8 } }, // vt100, xterm, also urxvt
    .{ "\x1b[20~", .{ .type = .f9 } }, // vt100, xterm, also urxvt
    .{ "\x1b[21~", .{ .type = .f10 } }, // vt100, xterm, also urxvt
    .{ "\x1b[17;3~", .{ .type = .f6, .alt = true } }, // vt100, xterm
    .{ "\x1b[18;3~", .{ .type = .f7, .alt = true } }, // vt100, xterm
    .{ "\x1b[19;3~", .{ .type = .f8, .alt = true } }, // vt100, xterm
    .{ "\x1b[20;3~", .{ .type = .f9, .alt = true } }, // vt100, xterm
    .{ "\x1b[21;3~", .{ .type = .f10, .alt = true } }, // vt100, xterm
    .{ "\x1b[23~", .{ .type = .f11 } }, // vt100, xterm, also urxvt
    .{ "\x1b[24~", .{ .type = .f12 } }, // vt100, xterm, also urxvt
    .{ "\x1b[23;3~", .{ .type = .f11, .alt = true } }, // vt100, xterm
    .{ "\x1b[24;3~", .{ .type = .f12, .alt = true } }, // vt100, xterm

    .{ "\x1b[1;2P", .{ .type = .f13 } },
    .{ "\x1b[1;2Q", .{ .type = .f14 } },
    .{ "\x1b[25~", .{ .type = .f13 } }, // vt100, xterm, also urxvt
    .{ "\x1b[26~", .{ .type = .f14 } }, // vt100, xterm, also urxvt
    .{ "\x1b[25;3~", .{ .type = .f13, .alt = true } }, // vt100, xterm
    .{ "\x1b[26;3~", .{ .type = .f14, .alt = true } }, // vt100, xterm

    .{ "\x1b[1;2R", .{ .type = .f15 } },
    .{ "\x1b[1;2S", .{ .type = .f16 } },
    .{ "\x1b[28~", .{ .type = .f15 } }, // vt100, xterm, also urxvt
    .{ "\x1b[29~", .{ .type = .f16 } }, // vt100, xterm, also urxvt
    .{ "\x1b[28;3~", .{ .type = .f15, .alt = true } }, // vt100, xterm
    .{ "\x1b[29;3~", .{ .type = .f16, .alt = true } }, // vt100, xterm

    .{ "\x1b[15;2~", .{ .type = .f17 } },
    .{ "\x1b[17;2~", .{ .type = .f18 } },
    .{ "\x1b[18;2~", .{ .type = .f19 } },
    .{ "\x1b[19;2~", .{ .type = .f20 } },

    .{ "\x1b[31~", .{ .type = .f17 } },
    .{ "\x1b[32~", .{ .type = .f18 } },
    .{ "\x1b[33~", .{ .type = .f19 } },
    .{ "\x1b[34~", .{ .type = .f20 } },

    // Powershell sequences.
    .{ "\x1b_OA", .{ .type = .up, .alt = false } },
    .{ "\x1b_OB", .{ .type = .down, .alt = false } },
    .{ "\x1b_OC", .{ .type = .right, .alt = false } },
    .{ "\x1b_OD", .{ .type = .left, .alt = false } },
});
