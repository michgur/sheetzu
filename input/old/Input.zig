const std = @import("std");
const Key = @import("Key.zig");
const detectSequence = @import("sequences.zig").detectSequence;

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
};
const Error = ReadError || ParseError;

fn read(self: *Input) ReadError!void {
    self.read_len = self.reader.readAll(self.buf[self.leftovers..]) catch return Error.ReaderError;
    self.read_len += self.leftovers;
    self.leftovers = 0;
    self.index = 0;
    if (self.read_len == 0) return Error.EmptyReadError;
    std.debug.print("read {d} bytes {any}\n", .{ self.read_len, self.buf[0..self.read_len] });
}
pub fn next(self: *Input) ReadError!?Key {
    const key = self.detectOneKey() catch {
        // last seq may be partial, set as leftovers
        self.leftovers = self.read_len - self.index;
        @memcpy(self.buf[0..self.leftovers], self.buf[self.index..self.read_len]);
        try self.read();
        return self.next();
    };
    self.index += key.bytes.len;
    std.debug.print("adding {d} to start index\n", .{key.bytes.len});
    return key;
}

fn detectOneKey(self: *const Input) ParseError!Key {
    if (self.index >= self.read_len) return Error.PartialError;

    const bytes = self.buf[self.index..self.read_len];
    const maybe_partial = self.read_len == self.buf.len;

    const mouse_event_x10_len = 6;
    if (bytes.len >= mouse_event_x10_len and bytes[0] == '\x1b' and bytes[1] == '[') {
        switch (bytes[2]) {
            'M' => return Key{ .type = .null, .bytes = bytes[0..mouse_event_x10_len] }, // todo mouse_event_x10
            '<' => return Key{ .type = .null, .bytes = bytes[0..mouse_event_x10_len] }, // todo mouse_event_sgr
            else => {},
        }
    }

    // todo focus events
    // todo bracketed paste https://github.com/charmbracelet/bubbletea/blob/bd77483b4441220586615000a6eeee04c7678658/key.go#L631

    std.debug.print("start index is {d}/{d}\n", .{ self.index, self.read_len });
    if (detectSequence(bytes)) |key| {
        return key;
    }

    var i: usize = 0;
    var alt = false;
    if (bytes[0] == '\x1b') {
        alt = true;
        i += 1;
    }

    if (i < bytes.len and bytes[i] == 0) { // what is the zero check here? is it actually zero or undefined?
        return Key{ .type = .null, .alt = alt, .bytes = bytes[0..i] };
    }

    while (i < bytes.len) {
        const rw = std.unicode.utf8ByteSequenceLength(bytes[i]) catch break;
        const r = std.unicode.utf8Decode(bytes[i .. i + rw]) catch break;
        if (r <= @intFromEnum(Key.Type.caret) or r == @intFromEnum(Key.Type.question_mark) or r == ' ') break;
        i += rw;
        if (alt) break;
    }
    if (i >= bytes.len and maybe_partial) {
        return Error.PartialError;
    }

    if (i > 0) {
        var k = Key{ .type = .runes, .bytes = bytes[0..i], .alt = alt };
        if (i == 1 and bytes[0] == ' ') {
            k.type = .space;
        }
        return k;
    }

    if (alt and bytes.len == 1) {
        return Key{ .type = .open_bracket, .ctrl = true, .bytes = bytes[0..1] };
    }

    return Key{ .type = .unknown, .bytes = bytes[0..1] };
}
