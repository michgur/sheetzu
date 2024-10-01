const std = @import("std");
const Tokenizer = @This();

input: []const u8,

pub const Error = error{
    InvalidChar,
    InvalidSyntax,
};

pub fn next(self: *Tokenizer) Error!?Token {
    if (self.input.len == 0) return null;
    const token = self.nextInternal() catch |err| return err;
    self.input = self.input[token.bytes.len..];
    if (token.type == .ignore) return self.next();
    return token;
}

fn nextInternal(self: *Tokenizer) Error!Token {
    switch (self.input[0]) {
        '+' => return Token{ .bytes = self.input[0..1], .type = .plus },
        '-' => return Token{ .bytes = self.input[0..1], .type = .dash },
        '*' => return Token{ .bytes = self.input[0..1], .type = .asterisk },
        '/' => return Token{ .bytes = self.input[0..1], .type = .forward_slash },
        '(' => return Token{ .bytes = self.input[0..1], .type = .open_paren },
        ')' => return Token{ .bytes = self.input[0..1], .type = .close_paren },
        ',' => return Token{ .bytes = self.input[0..1], .type = .comma },
        '0'...'9' => return self.readNumber(),
        'A'...'Z' => return self.readRef() catch self.readIdentifier(), // try ref, fallback to identifier
        'a'...'z' => return self.readIdentifier(), // identifier
        '"' => return self.readString(),
        else => {
            if (!std.ascii.isWhitespace(self.input[0])) return Error.InvalidChar;
            return self.readWhitespace();
        },
    }
}

fn readWhitespace(self: *Tokenizer) Token {
    std.debug.assert(std.ascii.isWhitespace(self.input[0]));
    for (self.input, 0..) |c, i| {
        if (!std.ascii.isWhitespace(c)) {
            return Token{
                .type = .ignore,
                .bytes = self.input[0..i],
            };
        }
    }
    unreachable;
}

fn readNumber(self: *Tokenizer) Token {
    var encountered_decimal_point: bool = false;
    var end = for (self.input, 0..) |c, i| {
        if (c == '.' and !encountered_decimal_point) {
            encountered_decimal_point = true;
        } else if (!std.ascii.isDigit(c)) break i;
    } else self.input.len;
    if (encountered_decimal_point and self.input[end - 1] == '.') {
        end -= 1;
    }
    return Token{ .bytes = self.input[0..end], .type = .number };
}

fn readIdentifier(self: *Tokenizer) Token {
    std.debug.assert(std.ascii.isAlphabetic(self.input[0]));
    for (self.input, 0..) |c, i| {
        if (!std.ascii.isAlphanumeric(c)) {
            return Token{ .type = .identifier, .bytes = self.input[0..i] };
        }
    }
    return Token{ .type = .identifier, .bytes = self.input };
}

fn readRef(self: *Tokenizer) Error!Token {
    std.debug.assert(std.ascii.isUpper(self.input[0]));
    const letters_end = for (self.input, 0..) |c, i| {
        if (!std.ascii.isUpper(c)) break i;
    } else return Error.InvalidSyntax;
    const numbers_end = for (self.input[letters_end..], letters_end..) |c, i| {
        if (!std.ascii.isDigit(c)) break i;
    } else self.input.len;
    if (numbers_end <= letters_end) return Error.InvalidSyntax;
    return Token{
        .type = .ref,
        .bytes = self.input[0..numbers_end],
    };
}

fn readString(self: *Tokenizer) Error!Token {
    std.debug.assert(self.input[0] == '"');
    for (self.input[1..], 0..) |c, i| {
        if (c == '"') return Token{ .bytes = self.input[0 .. i + 1], .type = .string };
    }
    return Error.InvalidSyntax; // unbalanced quotes
}

pub const Token = struct {
    type: Type,
    bytes: []const u8,

    pub const Type = enum {
        ref,
        number,
        string,
        identifier,
        open_paren,
        close_paren,
        comma,
        plus,
        dash,
        asterisk,
        forward_slash,
        ignore,
    };
};
