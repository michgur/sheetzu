const std = @import("std");
const common = @import("../common.zig");
const Sheet = @import("Temp.zig").Sheet;
const DisplayString = @import("../DisplayString.zig");
const AST = @This();

pub const NAN = std.math.nan(f64);

const Value = union(enum) {
    blank: void,
    number: f64,
    string: DisplayString,
    ref: common.upos,
    err: []const u8,

    pub fn numeralValue(self: *const Value, sht: *const Sheet) f64 {
        const result = switch (self.*) {
            .number => |f| f,
            .ref => |ref| if (sht.cell(ref)) |c| c.ast.evalNumeral(sht) else NAN,
            .blank, .err => NAN,
            .string => |s| std.fmt.parseFloat(f64, s.bytes.items) catch NAN,
        };
        return result;
    }

    pub fn deinit(self: *Value, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .string => |*s| s.deinit(), // I'm strongly considering making this unmanaged
            .err => |e| allocator.free(e),
            else => {},
        }
        self.* = undefined;
    }
};

const Operator = enum { add, sub };

op: ?Operator = null,
value: Value = .{ .blank = {} },
// child nodes. memory is owned by the parent
children: []AST = &.{},

pub fn eval(self: *const AST, sht: *const Sheet) Value {
    if (self.op) |op| {
        switch (op) {
            .add => return .{
                .number = self.children[0].evalNumeral(sht) + self.children[1].evalNumeral(sht),
            },
            .sub => return .{
                .number = self.children[0].evalNumeral(sht) - self.children[1].evalNumeral(sht),
            },
        }
    }
    return self.value;
}

pub fn evalNumeral(self: *const AST, sht: *const Sheet) f64 {
    return self.eval(sht).numeralValue(sht);
}

pub fn deinit(self: *AST) void {
    // future - are children heap allocated?
    self.value.deinit(std.heap.page_allocator);
    for (self.children) |*child| {
        child.deinit();
    }
    std.heap.page_allocator.free(self.children);
    self.* = undefined;
}

fn parseValue(input: []const u8) Value {
    if (input.len == 0) return .{ .blank = {} };
    if (std.fmt.parseFloat(f64, input)) |f| {
        return .{ .number = f };
    } else |_| {}
    return .{
        .string = DisplayString.initBytes(
            std.heap.page_allocator,
            input,
        ) catch @panic("Out of memory"),
    };
}

pub fn parse(input: []const u8) AST {
    const allocator = std.heap.page_allocator;
    if (input[0] != '=') return AST{ .value = parseValue(input) };
    const err = AST{ .value = .{
        .err = std.fmt.allocPrint(allocator, "INVALID FORMULA", .{}) catch @panic("Out of memory"),
    } };
    const ac = if (input[1] <= 'Z' and input[1] >= 'A') input[1] - 'A' else return err;
    const bc = if (input[4] <= 'Z' and input[4] >= 'A') input[4] - 'A' else return err;
    if (input[3] != '+') return err;
    const ar = if (input[2] <= '9' and input[2] >= '0') input[2] - '1' else return err;
    const br = if (input[5] <= '9' and input[5] >= '0') input[5] - '1' else return err;
    const children = allocator.alloc(AST, 2) catch @panic("Out of memory");
    children[0] = AST{ .value = .{ .ref = .{ ar, ac } } };
    children[1] = AST{ .value = .{ .ref = .{ br, bc } } };
    return AST{ .op = .add, .children = children };
}
