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

const Operator = enum { add, sub, mul, div };

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
            .mul => return .{
                .number = self.children[0].evalNumeral(sht) * self.children[1].evalNumeral(sht),
            },
            .div => return .{
                .number = self.children[0].evalNumeral(sht) / self.children[1].evalNumeral(sht),
            },
        }
    }
    return self.value;
}

pub fn evalNumeral(self: *const AST, sht: *const Sheet) f64 {
    return self.eval(sht).numeralValue(sht);
}

pub fn deinit(self: *AST, allocator: std.mem.Allocator) void {
    // future - are children heap allocated?
    self.value.deinit(allocator);
    for (self.children) |*child| {
        child.deinit(allocator);
    }
    allocator.free(self.children);
    self.* = undefined;
}
