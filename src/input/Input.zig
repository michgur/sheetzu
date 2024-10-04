const std = @import("std");
const Key = @import("Key.zig");

const Input = @This();

reader: std.fs.File.Reader,
buf: [256]u8 = undefined,
read_len: usize = 0,
leftovers: usize = 0,
index: usize = 0,

const ReadError = error{
    ReaderError,
    EmptyReadError,
};
const ParseError = error{
    PartialError,
    SeqParseError,
};
const Error = ReadError || ParseError;

fn read(self: *Input) ReadError!void {
    // move leftovers to beginning of buf
    self.leftovers = self.read_len - self.index;
    @memcpy(self.buf[0..self.leftovers], self.buf[self.index..self.read_len]);

    self.read_len = self.reader.read(self.buf[self.leftovers..]) catch return Error.ReaderError;
    self.read_len += self.leftovers;
    self.leftovers = 0;
    self.index = 0;
    if (self.read_len == 0) return Error.EmptyReadError;
}
pub fn next(self: *Input) ReadError!?Key {
    const key = self.parseSingleKey() catch |err| {
        switch (err) {
            ParseError.PartialError => {
                try self.read();
            },
            ParseError.SeqParseError => {
                self.index += 1;
            },
        }
        return self.next();
    };
    self.index += key.bytes.len;
    return key;
}

fn parseSingleKey(self: *const Input) ParseError!Key {
    if (self.index >= self.read_len) return Error.PartialError;

    const bytes = self.buf[self.index..self.read_len];

    const cp_len = std.unicode.utf8ByteSequenceLength(bytes[0]) catch return ParseError.SeqParseError;
    const cp_int = std.unicode.utf8Decode(bytes[0..cp_len]) catch return ParseError.SeqParseError;
    const cp: Key.Codepoint = @enumFromInt(cp_int);

    if (cp == .escape and bytes.len > cp_len) return self.parseEscSeq(bytes);
    return Key{ .codepoint = cp, .bytes = bytes[0..cp_len] };
}

fn parseEscSeq(self: *const Input, bytes: []const u8) ParseError!Key {
    std.debug.assert(cpEq(bytes[0], .escape) and bytes.len > 1);
    if (cpEq(bytes[1], .open_square_bracket)) return self.parseCSISeq(bytes);
    return ParseError.SeqParseError;
}

fn parseCSISeq(_: *const Input, bytes: []const u8) ParseError!Key {
    std.debug.assert(cpEq(bytes[0], .csi) or (cpEq(bytes[0], .escape) and cpEq(bytes[1], .open_square_bracket)));
    // assume for now only the second option
    return Key{
        .codepoint = Key.fromCSI(bytes[2]),
        .bytes = bytes[0..3],
    };
}

inline fn cpEq(byte: u8, cp: Key.Codepoint) bool {
    return byte == @intFromEnum(cp);
}
