const std = @import("std");
const common = @import("../common.zig");
const Sheet = @import("Temp.zig").Sheet;
const AST = @This();

pub const NAN = std.math.nan(f64);

const Value = union(enum) {
    number: f64,
    ref: common.upos,
    err: void,

    pub fn numeralValue(self: *const Value, sht: *const Sheet) f64 {
        return switch (self.*) {
            .number => |f| f,
            .ref => |ref| if (sht.cell(ref)) |c| c.ast.evalNumeral(sht) else NAN,
            .err => NAN,
        };
    }
};

const Operator = enum { add, sub };

// the layout can be simpler - a single array thing
op: ?Operator = null,
value: ?Value = null,
// child nodes. memory is owned by the parent
children: ?[]const AST = null,

pub fn eval(self: *const AST, sht: *const Sheet) ?Value {
    if (self.value) |v| return v;
    if (self.op) |op| {
        switch (op) {
            .add => return .{
                .number = self.children.?[0].evalNumeral(sht) + self.children.?[1].evalNumeral(sht),
            },
            .sub => return .{
                .number = self.children.?[0].evalNumeral(sht) - self.children.?[1].evalNumeral(sht),
            },
        }
    }
    return null;
}

pub fn evalNumeral(self: *const AST, sht: *const Sheet) f64 {
    if (self.eval(sht)) |v| return v.numeralValue(sht);
    return NAN;
}

pub fn deinit(self: *AST) void {
    // future - are children heap allocated?
    self.* = undefined;
}
