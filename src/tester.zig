const std = @import("std");
const AST = @import("formula/AST.zig");
const Sheet = @import("sheets/Sheet.zig");
const Tokenizer = @import("formula/Tokenizer.zig");
const Parser = @import("formula/Parser.zig");
const String = @import("string/String.zig");
const functions = @import("formula/functions.zig").functions;

test "string" {
    // const allocator = std.heap.page_allocator;
    // var str = try String.init(allocator, "hello 🌸");
    // defer str.deinit(allocator);
    //
    // var iter = str.iterator();
    // std.debug.print("{d} cps:{d} bytes\n", .{ str.codepoints.len, str.bytes.len });
    // var i: usize = 0;
    // while (iter.next()) |cp| : (i += 1) {
    //     std.debug.print("{d}: {any}\n", .{ i, cp });
    // }
}

test "AST functions" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("oops");
    const allocator = gpa.allocator();

    var sheet = Sheet.init(allocator, .{ 100, 100 }) catch @panic("Out of memory");
    defer sheet.deinit();

    const f = functions.get("AVG") orelse unreachable;
    var children = try allocator.alloc(AST, 3);
    children[0] = AST{ .value = .{ .number = 68 } };
    children[1] = AST{ .value = .{ .number = 69 } };
    children[2] = AST{ .value = .{ .number = 70 } };
    var ast = AST{
        .op = .{ .FN = f },
        .children = children,
    };
    defer ast.deinit(allocator);

    var value = try sheet.evaluator.eval(allocator, &ast);
    defer value.deinit(allocator);

    std.debug.print("1. === {d}\n", .{sheet.evaluator.asNumber(value)});

    var ast2 = try Parser.parse(allocator, "=aVg(68, 69, 70)");
    defer ast2.deinit(allocator);

    var value2 = try sheet.evaluator.eval(allocator, &ast2);
    defer value2.deinit(allocator);

    std.debug.print("2. === {d}\n", .{sheet.evaluator.asNumber(value2)});
}

test "basic AST" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("oops");
    const allocator = gpa.allocator();

    var sheet = Sheet.init(allocator, .{ 100, 100 }) catch @panic("Out of memory");
    defer sheet.deinit();

    sheet.cell(.{ 1, 0 }).?.ast = AST{ .value = .{ .number = -2.76 } }; // A2
    sheet.cell(.{ 3, 1 }).?.ast = AST{ .value = .{ .ref = .{ 1, 0 } } }; // B4
    sheet.tick(.{ 1, 0 });
    sheet.tick(.{ 3, 1 });

    var curr = sheet.cell(.{ 4, 4 }) orelse unreachable;
    _ = try curr.input.appendSlice(allocator, "= (A2 + B4) * -12.5");
    curr.dirty = true;
    sheet.commit(.{ 4, 4 }) orelse unreachable;

    printAST(&curr.ast, 0);
    std.debug.print("=== {d}\n", .{sheet.evaluator.asNumber(curr.value)});

    sheet.cell(.{ 5, 5 }).?.value = .{ .string = try String.init(allocator, "hello") }; // F6
    sheet.cell(.{ 3, 5 }).?.value = .{ .string = try String.init(allocator, "world") }; // F4
    curr.input.clearAndFree(allocator);
    try curr.input.appendSlice(allocator, "=F6 & \"  \"& F4");
    curr.dirty = true;
    sheet.commit(.{ 4, 4 }) orelse unreachable;

    printAST(&curr.ast, 0);
    std.debug.print("=== {s}\n", .{curr.str.bytes});

    var next = sheet.cell(.{ 10, 10 }) orelse unreachable;
    next.input.clearAndFree(allocator);
    try next.input.appendSlice(allocator, "=F6 & E5");
    next.dirty = true;
    sheet.commit(.{ 10, 10 }) orelse unreachable;

    printAST(&next.ast, 0);
    std.debug.print("=== {s}\n", .{next.value.string.bytes});
}

const indent = "-" ** 40;
fn printAST(ast: *const AST, level: usize) void {
    std.debug.print("{s} {any}\n", .{ indent[0 .. level * 2], ast.value });
    for (ast.children) |*child| {
        printAST(child, level + 1);
    }
}
