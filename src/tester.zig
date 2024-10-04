const std = @import("std");
const AST = @import("formula/AST.zig");
const Sheet = @import("sheets/Sheet.zig");
const isCircularRef = @import("formula/Temp.zig").isCircularRef;
const Tokenizer = @import("formula/Tokenizer.zig");
const Parser = @import("formula/Parser.zig");
const String = @import("string/String.zig");

test "string" {
    const allocator = std.heap.page_allocator;
    var str = try String.init(allocator, "hello 🌸");
    defer str.deinit(allocator);

    var iter = str.iterator();
    std.debug.print("{d} cps:{d} bytes\n", .{ str.codepoints.len, str.bytes.len });
    var i: usize = 0;
    while (iter.next()) |cp| : (i += 1) {
        std.debug.print("{d}: {any}\n", .{ i, cp });
    }
}
// test "basic AST" {
//     std.testing.refAllDecls(@This());
//
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     defer if (gpa.deinit() != .ok) @panic("oops");
//     const allocator = gpa.allocator();
//
//     var sheet = Sheet.init(allocator, .{ 100, 100 }) catch @panic("Out of memory");
//     defer sheet.deinit();
//
//     try sheet.placeAST(.{ 2, 0 }, AST{ .value = .{ .number = -2.76 } });
//     try sheet.placeAST(.{ 4, 1 }, AST{ .value = .{ .ref = .{ 2, 0 } } });
//
//     var curr = @constCast(sheet.currentCell());
//     _ = try curr.input.replaceAll("= (A2 + B4) * -12.5");
//     curr.dirty = true;
//     sheet.tick();
//
//     printAST(&curr.ast, 0);
//     std.debug.print("=== {d}\n", .{curr.ast.evalNumeral(&sheet)});
// }

const indent = "-" ** 40;
fn printAST(ast: *const AST, level: usize) void {
    std.debug.print("{s} {any}\n", .{ indent[0 .. level * 2], ast.value });
    for (ast.children) |*child| {
        printAST(child, level + 1);
    }
}
