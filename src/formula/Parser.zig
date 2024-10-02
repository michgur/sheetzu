////////////////////////////////////////////////////////////
// Grammar:                                               //
////////////////////////////////////////////////////////////
// <Formula>      ::= <Expression>                        //
// <Expression>   ::= <Term> { ("+" | "-") <Term> }*      //
// <Term>         ::= <Factor> { ("*" | "/") <Factor> }*  //
// <Factor>       ::= "-" <Factor>                        //
//                  | <Primary>                           //
// <Primary>      ::= <number>                            //
//                  | <string>                            //
//                  | <ref>                               //
//                  | "(" <Expression> ")"                //
//                  | <FunctionCall>                      //
// <FunctionCall> ::= <identifier> "(" <ArgumentList> ")" //
// <ArgumentList> ::= <Expression> ("," <Expression>)*    //
////////////////////////////////////////////////////////////

const std = @import("std");
const common = @import("../common.zig");
const Tokenizer = @import("Tokenizer.zig");
const AST = @import("AST.zig");
const DisplayString = @import("../DisplayString.zig");
const Parser = @This();

tokenizer: Tokenizer,
allocator: std.mem.Allocator,

pub const Error = Tokenizer.Error || error{ParsingError} || std.mem.Allocator.Error;

pub fn out(self: *Parser) Error!AST {
    self.tokenizer.consume();

    var result = try self.parseExpression();
    errdefer result.deinit();

    const eof = try self.tokenizer.head;
    return if (eof.type == .eof) result else Error.ParsingError;
}

fn parsePrimary(self: *Parser) Error!AST {
    const token = try self.tokenizer.head;
    switch (token.type) {
        // .identifier => return self.parseFunctionCall(token),
        .string => return self.parseString(),
        .number => return self.parseNumber(),
        .open_paren => {
            self.tokenizer.consume();
            var result = try self.parseExpression();
            errdefer result.deinit();

            const last_token = try self.tokenizer.head;
            self.tokenizer.consume();
            return if (last_token.type == .close_paren) result else Error.ParsingError;
        },
        .ref => return self.parseRef(),
        else => return Error.ParsingError,
    }
}

// fn parseFunctionCall(self: *Parser, token: Tokenizer.Token) Error!AST {
//     if (token.type != .open_paren) return Error.ParsingError;
// }

fn parseExpression(self: *Parser) Error!AST {
    var result = try self.parseTerm();
    errdefer result.deinit();

    while (true) {
        const token = try self.tokenizer.head;
        switch (token.type) {
            .plus, .dash => |t| {
                self.tokenizer.consume();
                const next_term = try self.parseTerm();
                const children = try self.allocator.alloc(AST, 2);
                children[0] = result;
                children[1] = next_term;
                result = AST{
                    .op = if (t == .plus) .add else .sub,
                    .children = children,
                };
            },
            else => return result,
        }
    }
}

fn parseTerm(self: *Parser) Error!AST {
    var result = try self.parseFactor();
    errdefer result.deinit();

    while (true) {
        const next_token = try self.tokenizer.head;
        switch (next_token.type) {
            .asterisk, .forward_slash => |t| {
                self.tokenizer.consume();
                const next_factor = try self.parseFactor();
                const children = try self.allocator.alloc(AST, 2);
                children[0] = result;
                children[1] = next_factor;
                result = AST{
                    .op = if (t == .asterisk) .mul else .div,
                    .children = children,
                };
            },
            else => return result,
        }
    }
}

fn parseFactor(self: *Parser) Error!AST {
    const token = try self.tokenizer.head;
    if (token.type == .dash) {
        self.tokenizer.consume();
        var result = try self.parsePrimary();
        errdefer result.deinit();

        if (result.value == .number) {
            result.value.number *= -1;
            return result;
        } else return Error.ParsingError;
    } else {
        return self.parsePrimary();
    }
}

fn parseString(self: *Parser) Error!AST {
    const token = try self.tokenizer.head;
    defer self.tokenizer.consume();
    return AST{
        .value = .{
            .string = try DisplayString.initBytes(self.allocator, token.bytes),
        },
    };
}

// positive number, optionally with a decimal point
fn parseNumber(self: *Parser) Error!AST {
    const token = try self.tokenizer.head;
    defer self.tokenizer.consume();

    const value = std.fmt.parseFloat(f64, token.bytes) catch unreachable;
    return AST{
        .value = .{ .number = value },
    };
}

fn parseRef(self: *Parser) Error!AST {
    const token = try self.tokenizer.head;
    defer self.tokenizer.consume();

    const col_len = for (token.bytes, 0..) |b, i| {
        if (std.ascii.isDigit(b)) break i;
    } else unreachable;
    const col_idx = common.frombb26(token.bytes[0..col_len]);
    const row_idx = std.fmt.parseInt(usize, token.bytes[col_len..], 10) catch return Error.ParsingError;
    return AST{
        .value = .{ .ref = .{ row_idx, col_idx } },
    };
}

