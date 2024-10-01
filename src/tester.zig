const std = @import("std");
const AST = @import("formula/AST.zig");
const Sheet = @import("formula/Temp.zig").Sheet;
const isCircularRef = @import("formula/Temp.zig").isCircularRef;
const Tokenizer = @import("formula/Tokenizer.zig");

test "basic AST" {
    std.testing.refAllDecls(@This());

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("oops");
    const allocator = gpa.allocator();

    var sheet = Sheet.init(allocator, .{ 100, 100 }) catch @panic("Out of memory");
    defer sheet.deinit();

    sheet.cell(.{ 0, 0 }).?.ast = AST{ .value = .{ .number = 3 } };
    sheet.cell(.{ 1, 1 }).?.ast = AST{ .value = .{ .ref = .{ 0, 0 } } };
    // sheet.cell(.{ 2, 3 }).?.ast = AST{ // C4=A1+B2
    //     .op = .add,
    //     .children = @constCast(&[_]AST{
    //         AST{ .value = .{ .ref = .{ 0, 0 } } },
    //         AST{ .value = .{ .ref = .{ 1, 1 } } },
    //     }),
    // };
    //
    // // A1=C4
    // try std.testing.expect(isCircularRef(&sheet, .{ 0, 0 }, &AST{ .value = .{ .ref = .{ 2, 3 } } }));
    // try std.testing.expectEqual(6, sheet.cell(.{ 2, 3 }).?.ast.evalNumeral(&sheet));
    try std.testing.expectEqual(6, AST.parse("=A1+B2").evalNumeral(&sheet));

    var tokenizer = Tokenizer{ .input = "BANANA(A2+B4, 15.3)" };
    while (tokenizer.next() catch @panic("Invalid formula provided")) |token| {
        std.debug.print("{any}: {s}\n", .{ token.type, token.bytes });
    }
}
