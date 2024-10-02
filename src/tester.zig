const std = @import("std");
const AST = @import("formula/AST.zig");
const Sheet = @import("formula/Temp.zig").Sheet;
const isCircularRef = @import("formula/Temp.zig").isCircularRef;
const Tokenizer = @import("formula/Tokenizer.zig");
const Parser = @import("formula/Parser.zig");

test "basic AST" {
    std.testing.refAllDecls(@This());

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("oops");
    const allocator = gpa.allocator();

    var sheet = Sheet.init(allocator, .{ 100, 100 }) catch @panic("Out of memory");
    defer sheet.deinit();

    sheet.cell(.{ 2, 0 }).?.ast = AST{ .value = .{ .number = -2.76 } };
    sheet.cell(.{ 4, 1 }).?.ast = AST{ .value = .{ .ref = .{ 2, 0 } } };

    const tokenizer = Tokenizer{ .input = "(A2 + B4) * -12.5" };
    var parser = Parser{
        .allocator = allocator,
        .tokenizer = tokenizer,
    };
    var result = parser.out() catch @panic("Invalid formula provided");
    defer result.deinit(allocator);

    printAST(&result, 0);
    std.debug.print("=== {d}\n", .{result.evalNumeral(&sheet)});
}

const indent = "-" ** 40;
fn printAST(ast: *const AST, level: usize) void {
    std.debug.print("{s} {any}\n", .{ indent[0 .. level * 2], ast.value });
    for (ast.children) |*child| {
        printAST(child, level + 1);
    }
}
