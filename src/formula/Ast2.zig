const std = @import("std");

// const Ast = struct {
//     nodes: []Node,
//     values:
//
//     inline fn value(self: *Ast, value_type: usize, value_idx: usize)
// };

const Node = struct {
    first_child: usize,
    n_children: usize,
    value_type: usize,
    value_idx: usize,
};

const Value = union(enum) {
    ref: @Vector(2, u32),
    number: f64,
    string: []const u8,
};

const ValueFieldEnum = std.meta.FieldEnum(Value);

test Value {
    const v = Value{ .number = 3 };
    const v1 = Value{ .string = "hello" };
    std.debug.print("{d}:{d} is the size\n", .{ @sizeOf(Value), @sizeOf(std.meta.Tag(Value)) });
    std.debug.print("typename is {any}\n", .{@intFromEnum(std.meta.activeTag(v))});
    std.debug.print("typename is {any}\n", .{@intFromEnum(std.meta.activeTag(v1))});
}
