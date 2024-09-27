const std = @import("std");
const Key = @import("Key.zig");

const SeqMap = std.StaticStringMap(Key);
const SeqTuple = std.meta.Tuple(&.{ []const u8, Key });
inline fn seqTuple(key: Key) SeqTuple {
    return .{ key.bytes, key };
}

pub fn detectSequence(input: []const u8) ?Key {
    for (seq_lengths) |len| {
        if (len > input.len) continue;
        std.debug.print("testing len {d}: {any}\n", .{ len, input[0..len] });
        const prefix = input[0..len];
        if (ext_sequences.get(prefix)) |key| {
            return key;
        }
    }
    // todo: unknown CSI sequences
    return null;
}

const keys = [_]Key{
    // Arrow keys
    .{ .bytes = "\x1b[A", .type = .up },
    .{ .bytes = "\x1b[B", .type = .down },
    .{ .bytes = "\x1b[C", .type = .right },
    .{ .bytes = "\x1b[D", .type = .left },
    .{ .bytes = "\x1b[1;2A", .type = .up, .shift = true },
    .{ .bytes = "\x1b[1;2B", .type = .down, .shift = true },
    .{ .bytes = "\x1b[1;2C", .type = .right, .shift = true },
    .{ .bytes = "\x1b[1;2D", .type = .left, .shift = true },
    .{ .bytes = "\x1b[OA", .type = .up, .shift = true }, // DECCKM
    .{ .bytes = "\x1b[OB", .type = .down, .shift = true }, // DECCKM
    .{ .bytes = "\x1b[OC", .type = .right, .shift = true }, // DECCKM
    .{ .bytes = "\x1b[OD", .type = .left, .shift = true }, // DECCKM
    .{ .bytes = "\x1b[a", .type = .up, .shift = true }, // urxvt
    .{ .bytes = "\x1b[b", .type = .down, .shift = true }, // urxvt
    .{ .bytes = "\x1b[c", .type = .right, .shift = true }, // urxvt
    .{ .bytes = "\x1b[d", .type = .left, .shift = true }, // urxvt
    .{ .bytes = "\x1b[1;3A", .type = .up, .alt = true },
    .{ .bytes = "\x1b[1;3B", .type = .down, .alt = true },
    .{ .bytes = "\x1b[1;3C", .type = .right, .alt = true },
    .{ .bytes = "\x1b[1;3D", .type = .left, .alt = true },

    .{ .bytes = "\x1b[1;4A", .type = .up, .shift = true, .alt = true },
    .{ .bytes = "\x1b[1;4B", .type = .down, .shift = true, .alt = true },
    .{ .bytes = "\x1b[1;4C", .type = .right, .shift = true, .alt = true },
    .{ .bytes = "\x1b[1;4D", .type = .left, .shift = true, .alt = true },

    .{ .bytes = "\x1b[1;5A", .type = .up, .ctrl = true },
    .{ .bytes = "\x1b[1;5B", .type = .down, .ctrl = true },
    .{ .bytes = "\x1b[1;5C", .type = .right, .ctrl = true },
    .{ .bytes = "\x1b[1;5D", .type = .left, .ctrl = true },
    .{ .bytes = "\x1b[Oa", .type = .up, .ctrl = true, .alt = true }, // urxvt
    .{ .bytes = "\x1b[Ob", .type = .down, .ctrl = true, .alt = true }, // urxvt
    .{ .bytes = "\x1b[Oc", .type = .right, .ctrl = true, .alt = true }, // urxvt
    .{ .bytes = "\x1b[Od", .type = .left, .ctrl = true, .alt = true }, // urxvt
    .{ .bytes = "\x1b[1;6A", .type = .up, .ctrl = true, .shift = true },
    .{ .bytes = "\x1b[1;6B", .type = .down, .ctrl = true, .shift = true },
    .{ .bytes = "\x1b[1;6C", .type = .right, .ctrl = true, .shift = true },
    .{ .bytes = "\x1b[1;6D", .type = .left, .ctrl = true, .shift = true },
    .{ .bytes = "\x1b[1;7A", .type = .up, .ctrl = true, .alt = true },
    .{ .bytes = "\x1b[1;7B", .type = .down, .ctrl = true, .alt = true },
    .{ .bytes = "\x1b[1;7C", .type = .right, .ctrl = true, .alt = true },
    .{ .bytes = "\x1b[1;7D", .type = .left, .ctrl = true, .alt = true },
    .{ .bytes = "\x1b[1;8A", .type = .up, .ctrl = true, .shift = true, .alt = true },
    .{ .bytes = "\x1b[1;8B", .type = .down, .ctrl = true, .shift = true, .alt = true },
    .{ .bytes = "\x1b[1;8C", .type = .right, .ctrl = true, .shift = true, .alt = true },
    .{ .bytes = "\x1b[1;8D", .type = .left, .ctrl = true, .shift = true, .alt = true },

    // Miscellaneous keys
    .{ .bytes = "\x1b[Z", .type = .tab, .shift = true },

    .{ .bytes = "\x1b[2~", .type = .insert },
    .{ .bytes = "\x1b[3;2~", .type = .insert, .alt = true },

    .{ .bytes = "\x1b[3~", .type = .question_mark },
    .{ .bytes = "\x1b[3;3~", .type = .question_mark, .alt = true },

    .{ .bytes = "\x1b[5~", .type = .pg_up },
    .{ .bytes = "\x1b[5;3~", .type = .pg_up, .alt = true },
    .{ .bytes = "\x1b[5;5~", .type = .pg_up, .ctrl = true },
    .{ .bytes = "\x1b[5^", .type = .pg_up, .ctrl = true }, // urxvt
    .{ .bytes = "\x1b[5;7~", .type = .pg_up, .ctrl = true, .alt = true },

    .{ .bytes = "\x1b[6~", .type = .pg_down },
    .{ .bytes = "\x1b[6;3~", .type = .pg_down, .alt = true },
    .{ .bytes = "\x1b[6;5~", .type = .pg_down, .ctrl = true },
    .{ .bytes = "\x1b[6^", .type = .pg_down, .ctrl = true }, // urxvt
    .{ .bytes = "\x1b[6;7~", .type = .pg_down, .ctrl = true, .alt = true },

    .{ .bytes = "\x1b[1~", .type = .home },
    .{ .bytes = "\x1b[H", .type = .home }, // xterm, lxterm
    .{ .bytes = "\x1b[1;3H", .type = .home, .alt = true }, // xterm, lxterm
    .{ .bytes = "\x1b[1;5H", .type = .home, .ctrl = true }, // xterm, lxterm
    .{ .bytes = "\x1b[1;7H", .type = .home, .ctrl = true, .alt = true }, // xterm, lxterm
    .{ .bytes = "\x1b[1;2H", .type = .home, .shift = true }, // xterm, lxterm
    .{ .bytes = "\x1b[1;4H", .type = .home, .shift = true, .alt = true }, // xterm, lxterm
    .{ .bytes = "\x1b[1;6H", .type = .home, .ctrl = true, .shift = true }, // xterm, lxterm
    .{ .bytes = "\x1b[1;8H", .type = .home, .ctrl = true, .shift = true, .alt = true }, // xterm, lxterm

    .{ .bytes = "\x1b[4~", .type = .end },
    .{ .bytes = "\x1b[F", .type = .end }, // xterm, lxterm
    .{ .bytes = "\x1b[1;3F", .type = .end, .alt = true }, // xterm, lxterm
    .{ .bytes = "\x1b[1;5F", .type = .end, .ctrl = true }, // xterm, lxterm
    .{ .bytes = "\x1b[1;7F", .type = .end, .ctrl = true, .alt = true }, // xterm, lxterm
    .{ .bytes = "\x1b[1;2F", .type = .end, .shift = true }, // xterm, lxterm
    .{ .bytes = "\x1b[1;4F", .type = .end, .shift = true, .alt = true }, // xterm, lxterm
    .{ .bytes = "\x1b[1;6F", .type = .end, .ctrl = true, .shift = true }, // xterm, lxterm
    .{ .bytes = "\x1b[1;8F", .type = .end, .ctrl = true, .shift = true, .alt = true }, // xterm, lxterm
    .{ .bytes = "\x1b[7~", .type = .home }, // urxvt
    .{ .bytes = "\x1b[7^", .type = .home, .ctrl = true }, // urxvt
    .{ .bytes = "\x1b[7$", .type = .home, .shift = true }, // urxvt
    .{ .bytes = "\x1b[7@", .type = .home, .ctrl = true, .shift = true }, // urxvt
    .{ .bytes = "\x1b[8~", .type = .end }, // urxvt
    .{ .bytes = "\x1b[8^", .type = .end, .ctrl = true }, // urxvt
    .{ .bytes = "\x1b[8$", .type = .end, .shift = true }, // urxvt
    .{ .bytes = "\x1b[8@", .type = .end, .ctrl = true, .shift = true }, // urxvt

    // Function keys, Linux console
    .{ .bytes = "\x1b[[A", .type = .f1 }, // linux console
    .{ .bytes = "\x1b[[B", .type = .f2 }, // linux console
    .{ .bytes = "\x1b[[C", .type = .f3 }, // linux console
    .{ .bytes = "\x1b[[D", .type = .f4 }, // linux console
    .{ .bytes = "\x1b[[E", .type = .f5 }, // linux console

    // Function keys, X11
    .{ .bytes = "\x1b_oP", .type = .f1 }, // vt100, xterm
    .{ .bytes = "\x1b_oQ", .type = .f2 }, // vt100, xterm
    .{ .bytes = "\x1b_oR", .type = .f3 }, // vt100, xterm
    .{ .bytes = "\x1b_oS", .type = .f4 }, // vt100, xterm
    .{ .bytes = "\x1b[1;3P", .type = .f1, .alt = true }, // vt100, xterm
    .{ .bytes = "\x1b[1;3Q", .type = .f2, .alt = true }, // vt100, xterm
    .{ .bytes = "\x1b[1;3R", .type = .f3, .alt = true }, // vt100, xterm
    .{ .bytes = "\x1b[1;3S", .type = .f4, .alt = true }, // vt100, xterm
    .{ .bytes = "\x1b[11~", .type = .f1 }, // urxvt
    .{ .bytes = "\x1b[12~", .type = .f2 }, // urxvt
    .{ .bytes = "\x1b[13~", .type = .f3 }, // urxvt
    .{ .bytes = "\x1b[14~", .type = .f4 }, // urxvt
    .{ .bytes = "\x1b[15~", .type = .f5 }, // vt100, xterm, also urxvt
    .{ .bytes = "\x1b[15;3~", .type = .f5, .alt = true }, // vt100, xterm, also urxvt
    .{ .bytes = "\x1b[17~", .type = .f6 }, // vt100, xterm, also urxvt
    .{ .bytes = "\x1b[18~", .type = .f7 }, // vt100, xterm, also urxvt
    .{ .bytes = "\x1b[19~", .type = .f8 }, // vt100, xterm, also urxvt
    .{ .bytes = "\x1b[20~", .type = .f9 }, // vt100, xterm, also urxvt
    .{ .bytes = "\x1b[21~", .type = .f10 }, // vt100, xterm, also urxvt
    .{ .bytes = "\x1b[17;3~", .type = .f6, .alt = true }, // vt100, xterm
    .{ .bytes = "\x1b[18;3~", .type = .f7, .alt = true }, // vt100, xterm
    .{ .bytes = "\x1b[19;3~", .type = .f8, .alt = true }, // vt100, xterm
    .{ .bytes = "\x1b[20;3~", .type = .f9, .alt = true }, // vt100, xterm
    .{ .bytes = "\x1b[21;3~", .type = .f10, .alt = true }, // vt100, xterm
    .{ .bytes = "\x1b[23~", .type = .f11 }, // vt100, xterm, also urxvt
    .{ .bytes = "\x1b[24~", .type = .f12 }, // vt100, xterm, also urxvt
    .{ .bytes = "\x1b[23;3~", .type = .f11, .alt = true }, // vt100, xterm
    .{ .bytes = "\x1b[24;3~", .type = .f12, .alt = true }, // vt100, xterm

    .{ .bytes = "\x1b[1;2P", .type = .f13 },
    .{ .bytes = "\x1b[1;2Q", .type = .f14 },
    .{ .bytes = "\x1b[25~", .type = .f13 }, // vt100, xterm, also urxvt
    .{ .bytes = "\x1b[26~", .type = .f14 }, // vt100, xterm, also urxvt
    .{ .bytes = "\x1b[25;3~", .type = .f13, .alt = true }, // vt100, xterm
    .{ .bytes = "\x1b[26;3~", .type = .f14, .alt = true }, // vt100, xterm

    .{ .bytes = "\x1b[1;2R", .type = .f15 },
    .{ .bytes = "\x1b[1;2S", .type = .f16 },
    .{ .bytes = "\x1b[28~", .type = .f15 }, // vt100, xterm, also urxvt
    .{ .bytes = "\x1b[29~", .type = .f16 }, // vt100, xterm, also urxvt
    .{ .bytes = "\x1b[28;3~", .type = .f15, .alt = true }, // vt100, xterm
    .{ .bytes = "\x1b[29;3~", .type = .f16, .alt = true }, // vt100, xterm

    .{ .bytes = "\x1b[15;2~", .type = .f17 },
    .{ .bytes = "\x1b[17;2~", .type = .f18 },
    .{ .bytes = "\x1b[18;2~", .type = .f19 },
    .{ .bytes = "\x1b[19;2~", .type = .f20 },

    .{ .bytes = "\x1b[31~", .type = .f17 },
    .{ .bytes = "\x1b[32~", .type = .f18 },
    .{ .bytes = "\x1b[33~", .type = .f19 },
    .{ .bytes = "\x1b[34~", .type = .f20 },

    // Powershell sequences.
    .{ .bytes = "\x1b_oA", .type = .up, .alt = false },
    .{ .bytes = "\x1b_oB", .type = .down, .alt = false },
    .{ .bytes = "\x1b_oC", .type = .right, .alt = false },
    .{ .bytes = "\x1b_oD", .type = .left, .alt = false },
};

pub const sequences = blk: {
    var tuples: [keys.len]SeqTuple = undefined;
    for (keys, 0..) |key, i| {
        tuples[i] = seqTuple(key);
    }
    break :blk SeqMap.initComptime(tuples);
};

// sequences plus escape character prefix
pub const ext_sequences = blk: {
    var kvs: []const SeqTuple = &.{};

    for (sequences.keys(), sequences.values()) |seq, k| {
        kvs = kvs ++ [_]SeqTuple{.{ seq, k }};
        if (!k.alt) {
            var altk = k;
            altk.bytes = "\x1b" ++ seq;
            altk.alt = true;
            kvs = kvs ++ [_]SeqTuple{seqTuple(altk)};
        }
    }

    const start = @intFromEnum(Key.Type.a);
    const end = @intFromEnum(Key.Type.space);
    for (start..end) |i| {
        const t: Key.Type = @enumFromInt(i);
        if (t == Key.Type.open_bracket) continue;

        kvs = kvs ++ [_]SeqTuple{
            seqTuple(.{ .ctrl = true, .type = t, .bytes = &[_]u8{i} }),
            seqTuple(.{ .ctrl = true, .type = t, .bytes = &[_]u8{ '\x1b', i }, .alt = true }),
        };
    }
    const qm = @intFromEnum(Key.Type.question_mark);
    kvs = kvs ++ [_]SeqTuple{
        seqTuple(.{ .type = .question_mark, .bytes = &[_]u8{qm} }),
        seqTuple(.{ .type = .question_mark, .bytes = &[_]u8{ '\x1b', qm }, .alt = true }),
        seqTuple(.{ .bytes = " ", .type = .space }),
        seqTuple(.{ .bytes = "\x1b ", .type = .space, .alt = true }),
        seqTuple(.{ .bytes = "\x1b\x1b ", .type = .space, .alt = true }),
    };
    break :blk SeqMap.initComptime(kvs);
};

const seq_lengths = blk: {
    var res: []const usize = &[_]usize{1};
    for (ext_sequences.keys()) |seq| {
        if (seq.len > res[0]) {
            res = [_]usize{seq.len} ++ res;
        } else if (seq.len < res[res.len - 1]) {
            res = res ++ [_]usize{seq.len};
        }
    }
    break :blk res;
};
