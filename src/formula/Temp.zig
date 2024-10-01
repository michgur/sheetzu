const std = @import("std");
const common = @import("../common.zig");
const DisplayString = @import("../DisplayString.zig");
const AST = @import("AST.zig");

const Cell = struct {
    // value: Value, // future, cached value
    ast: AST,
    refers: std.ArrayList(common.upos),

    pub fn init(allocator: std.mem.Allocator, ast: AST) Cell {
        return .{
            .ast = ast,
            .refers = std.ArrayList(common.upos).init(allocator),
        };
    }

    pub fn deinit(self: *Cell) void {
        self.refers.deinit();
        self.ast.deinit();
    }
};

pub const Sheet = struct {
    allocator: std.mem.Allocator,
    cells: [*][*]*Cell,
    size: common.upos,

    pub fn init(allocator: std.mem.Allocator, initial_size: common.upos) !Sheet {
        const cells_slc = try allocator.alloc([*]*Cell, initial_size[0]);
        for (cells_slc) |*r| {
            const row_slc = try allocator.alloc(*Cell, initial_size[1]);
            for (row_slc) |*c| {
                const cell_pt = try allocator.create(Cell);
                cell_pt.* = Cell.init(allocator, AST{});
                c.* = cell_pt;
            }
            r.* = row_slc.ptr;
        }
        return Sheet{
            .allocator = allocator,
            .cells = cells_slc.ptr,
            .size = initial_size,
        };
    }

    /// safe cell access
    pub fn cell(self: *const Sheet, pos: common.upos) ?*Cell {
        if (@reduce(.Or, pos >= self.size)) return null;
        return self.cells[pos[0]][pos[1]];
    }

    pub fn deinit(self: *Sheet) void {
        for (0..self.size[0]) |r| {
            for (0..self.size[1]) |c| {
                self.cells[r][c].deinit();
                self.allocator.destroy(self.cells[r][c]);
            }
            self.allocator.free(self.cells[r][0..self.size[1]]);
        }
        self.allocator.free(self.cells[0..self.size[0]]);
        self.* = undefined;
    }
};

fn isCircularRef(sht: *const Sheet, selfref: common.upos, ast: *const AST) bool {
    // todo: tweak to use .refers
    if (ast.value) |v| if (v == .ref) {
        const isDirectRef = @reduce(.And, v.ref == selfref);
        const isNestedRef = if (sht.cell(v.ref)) |refed| isCircularRef(sht, selfref, &refed.ast) else false;
        return isDirectRef or isNestedRef;
    };
    if (ast.children) |children| {
        for (children) |child| {
            if (isCircularRef(sht, selfref, &child)) return true;
        }
    }
    return false;
}

test "basic AST" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("oops");
    const allocator = gpa.allocator();

    var sheet = Sheet.init(allocator, .{ 100, 100 }) catch @panic("Out of memory");
    defer sheet.deinit();

    sheet.cell(.{ 0, 0 }).?.ast = AST{ .value = .{ .number = 3 } };
    sheet.cell(.{ 1, 1 }).?.ast = AST{ .value = .{ .ref = .{ 0, 0 } } };
    sheet.cell(.{ 2, 3 }).?.ast = AST{ // C4=A1+B2
        .op = .add,
        .children = &.{
            AST{ .value = .{ .ref = .{ 0, 0 } } },
            AST{ .value = .{ .ref = .{ 1, 1 } } },
        },
    };
    // A1=C4
    try std.testing.expect(isCircularRef(&sheet, .{ 0, 0 }, &AST{ .value = .{ .ref = .{ 2, 3 } } }));
    try std.testing.expectEqual(6, sheet.cell(.{ 2, 3 }).?.ast.evalNumeral(&sheet));
}

// each Cell should contain:
// 1. AST - this is how the contents are computed on tick
// 2. List of ref
// 3. Cached value - what's displayed
