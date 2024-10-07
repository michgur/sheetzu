//////////////////////////////////////////////////////////////
// Grammar:                                                 //
//////////////////////////////////////////////////////////////
// <Formula>      ::= <Expression>                          //
// <Expression>   ::= <Term> { ("+" | "-" | "&") <Term> }*  //
// <Term>         ::= <Factor> { ("*" | "/") <Factor> }*    //
// <Factor>       ::= "-" <Factor>                          //
//                  | <Primary>                             //
// <Primary>      ::= <number>                              //
//                  | <string>                              //
//                  | <ref>                                 //
//                  | "(" <Expression> ")"                  //
//                  | <FunctionCall>                        //
// <FunctionCall> ::= <identifier> "(" <ArgumentList> ")"   //
// <ArgumentList> ::= <Expression> ("," <Expression>)*      //
//////////////////////////////////////////////////////////////

const std = @import("std");
const common = @import("../common.zig");
const Tokenizer = @import("Tokenizer.zig");
const AST = @import("AST.zig");
const String = @import("../string/String.zig");
const functions = @import("functions.zig").functions;
const entities = @import("entities.zig");
const Parser = @This();

tokenizer: Tokenizer,
allocator: std.mem.Allocator,

pub const Error = Tokenizer.Error || error{ParsingError} || std.mem.Allocator.Error;

pub fn parse(allocator: std.mem.Allocator, input: []const u8) Error!AST {
    const is_formula = input.len > 0 and input[0] == '=';
    const tokenizer = Tokenizer.init(if (is_formula) input[1..] else input);
    var parser = Parser{ .tokenizer = tokenizer, .allocator = allocator };
    return if (is_formula) parser.parseFormula() else parser.parseRaw(input);
}

inline fn valueNode(value: entities.Value) AST {
    return AST{ .content = .{
        .value = value,
    } };
}

// currently can only be a string or a number
fn parseRaw(self: *Parser, bytes: []const u8) Error!AST {
    const token = self.tokenizer.head catch return valueNode(.{ .string = try String.init(self.allocator, bytes) });
    return switch (token.type) {
        .number => valueNode(.{
            .number = std.fmt.parseFloat(f64, token.bytes) catch return Error.ParsingError,
        }),
        else => valueNode(.{ .string = try String.init(self.allocator, bytes) }),
    };
}

fn parseFormula(self: *Parser) Error!AST {
    var result = try self.parseExpression();
    errdefer result.deinit(self.allocator);

    const eof = try self.tokenizer.head;
    return if (eof.type == .eof) result else Error.ParsingError;
}

fn parsePrimary(self: *Parser) Error!AST {
    const token = try self.tokenizer.head;
    switch (token.type) {
        .identifier => return self.parseFunctionCall(),
        .string => return self.parseString(),
        .number => return self.parseNumber(),
        .open_paren => {
            self.tokenizer.consume();
            var result = try self.parseExpression();
            errdefer result.deinit(self.allocator);

            const last_token = try self.tokenizer.head;
            self.tokenizer.consume();
            return if (last_token.type == .close_paren) result else Error.ParsingError;
        },
        .ref => return self.parseRef(),
        else => return Error.ParsingError,
    }
}

fn parseFunctionCall(self: *Parser) Error!AST {
    const fname = try self.tokenizer.head;
    std.debug.assert(fname.type == .identifier);
    self.tokenizer.consume();
    const open_paren = try self.tokenizer.head;
    if (open_paren.type != .open_paren) {
        return Error.ParsingError;
    }
    self.tokenizer.consume();

    const f = functions.get(fname.bytes) orelse return Error.ParsingError;
    var args = try self.parseArgumentList(f);
    errdefer args.deinit(self.allocator);

    const close_paren = try self.tokenizer.head;
    if (close_paren.type != .close_paren) {
        return Error.ParsingError;
    }
    self.tokenizer.consume();

    return args;
}

fn parseArgumentList(self: *Parser, function: entities.Function) Error!AST {
    var children = std.ArrayList(AST).init(self.allocator);
    errdefer children.deinit();
    try children.append(try self.parseExpression());

    while (true) {
        const token = try self.tokenizer.head;
        switch (token.type) {
            .close_paren => break,
            .comma => self.tokenizer.consume(),
            else => return Error.ParsingError,
        }

        try children.append(try self.parseExpression());
    }

    return AST{ .children = try children.toOwnedSlice(), .content = .{ .function = function } };
}

fn parseExpression(self: *Parser) Error!AST {
    var result = try self.parseTerm();
    errdefer result.deinit(self.allocator);

    while (true) {
        const token = try self.tokenizer.head;
        switch (token.type) {
            .plus, .dash, .ampersand => |t| {
                self.tokenizer.consume();
                var next_term = try self.parseTerm();
                errdefer next_term.deinit(self.allocator);

                const children = try self.allocator.alloc(AST, 2);
                children[0] = result;
                children[1] = next_term;
                result = AST{
                    .content = .{
                        .operator = switch (t) {
                            .plus => .add,
                            .dash => .sub,
                            .ampersand => .concat,
                            else => unreachable,
                        },
                    },
                    .children = children,
                };
            },
            else => return result,
        }
    }
}

fn parseTerm(self: *Parser) Error!AST {
    var result = try self.parseFactor();
    errdefer result.deinit(self.allocator);

    while (true) {
        const next_token = try self.tokenizer.head;
        switch (next_token.type) {
            .asterisk, .forward_slash => |t| {
                self.tokenizer.consume();
                var next_factor = try self.parseFactor();
                errdefer next_factor.deinit(self.allocator);

                const children = try self.allocator.alloc(AST, 2);
                children[0] = result;
                children[1] = next_factor;
                result = AST{
                    .content = .{ .operator = if (t == .asterisk) .mul else .div },
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
        errdefer result.deinit(self.allocator);

        const children = try self.allocator.alloc(AST, 2);
        children[0] = valueNode(.{ .number = 0 });
        children[1] = result;
        return AST{
            .content = .{ .operator = .sub },
            .children = children,
        };
    } else {
        return self.parsePrimary();
    }
}

fn parseString(self: *Parser) Error!AST {
    const token = try self.tokenizer.head;
    defer self.tokenizer.consume();
    return valueNode(.{
        .string = try String.init(self.allocator, token.bytes[1 .. token.bytes.len - 1]),
    });
}

// positive number, optionally with a decimal point
fn parseNumber(self: *Parser) Error!AST {
    const token = try self.tokenizer.head;
    defer self.tokenizer.consume();

    const value = std.fmt.parseFloat(f64, token.bytes) catch unreachable;
    return valueNode(.{ .number = value });
}

fn parseRef(self: *Parser) Error!AST {
    const token = try self.tokenizer.head;
    defer self.tokenizer.consume();

    const col_len = for (token.bytes, 0..) |b, i| {
        if (std.ascii.isDigit(b)) break i;
    } else unreachable;
    const col_idx = common.frombb26(token.bytes[0..col_len]);
    const row_idx = std.fmt.parseInt(usize, token.bytes[col_len..], 10) catch return Error.ParsingError;
    return valueNode(.{ .ref = .{ row_idx - 1, col_idx } });
}
