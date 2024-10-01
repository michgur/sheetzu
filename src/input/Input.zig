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
    const cp = std.unicode.utf8Decode(bytes[0..cp_len]) catch return ParseError.SeqParseError;

    return Key{ .codepoint = @enumFromInt(cp), .bytes = bytes[0..cp_len] };
}
