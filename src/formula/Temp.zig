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

pub fn isCircularRef(sht: *const Sheet, selfref: common.upos, ast: *const AST) bool {
    // todo: tweak to use .refers
    if (ast.value == .ref) {
        const isDirectRef = @reduce(.And, ast.value.ref == selfref);
        const isNestedRef = if (sht.cell(ast.value.ref)) |refed| isCircularRef(sht, selfref, &refed.ast) else false;
        return isDirectRef or isNestedRef;
    }
    for (ast.children) |child| {
        if (isCircularRef(sht, selfref, &child)) return true;
    }
    return false;
}

// each Cell should contain:
// 1. AST - this is how the contents are computed on tick
// 2. List of ref
// 3. Cached value - what's displayed
