const std = @import("std");
const common = @import("../common.zig");
const DisplayString = @import("../DisplayString.zig");
const AST = @import("AST.zig");

const Cell = struct {
    value: AST.Value,
    str: DisplayString,
    ast: AST,
    refers: std.ArrayList(common.upos),

    pub fn init(allocator: std.mem.Allocator, ast: AST) Cell {
        return .{
            .ast = ast,
            .refers = std.ArrayList(common.upos).init(allocator),
            .value = .{ .blank = {} },
            .str = DisplayString.init(allocator),
        };
    }

    pub fn deinit(self: *Cell) void {
        self.refers.deinit();
        self.ast.deinit(self.refers.allocator); // should prolly be unmanaged
    }

    pub fn removeRefer(self: *Cell, refer: common.upos) bool {
        return for (self.refers.items, 0..) |r, i| {
            if (@reduce(.And, r == refer)) {
                self.refers.swapRemove(i);
                break true;
            }
        } else false;
    }

    pub fn tick(self: *Cell, sht: *const Sheet) void {
        self.value = self.ast.eval(sht);
        const str = self.value.tostring(self.str.bytes.allocator);
        self.str.deinit();
        self.str = str;

        for (self.refers) |refer| {
            refer.tick(sht);
        }
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
    pub fn cell(self: *const Sheet, pos: common.upos) ?*const Cell {
        if (@reduce(.Or, pos >= self.size)) return null;
        return self.cells[pos[0]][pos[1]];
    }

    const Error = error{ CircularDependency, OutOfBounds };
    pub fn placeAST(self: *const Sheet, pos: common.upos, ast: AST) Error!void {
        var c = self.cell(pos) orelse return Error.OutOfBounds;
        if (isCircularRef(self, pos, ast)) return Error.CircularDependency;
        self.removeRefs(pos, c.ast);
        self.placeRefs(pos, ast);
        c.ast.deinit(self.allocator);
        c.ast = ast;
        c.tick(self);
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

    /// whether `this` depends on `upon`. `upon` is out of bounds, returns false
    pub fn dependsOn(self: *const Sheet, this: common.upos, upon: common.upos) bool {
        const upon_cell = self.cell(upon) orelse return false;
        if (@reduce(.And, this == upon)) return true;
        return for (upon_cell.refers) |refer| {
            if (@reduce(.And, this == refer)) break true;
        } else false;
    }

    /// whether placing `ast` on `pos` will cause a circluar dependency
    /// i.e. the AST references a cell that depends on `pos`
    fn isCircularRef(self: *const Sheet, pos: common.upos, ast: *const AST) bool {
        if (ast.value == .ref) {
            return self.dependsOn(ast.value.ref, pos);
        }
        for (ast.children) |child| {
            if (self.isCircularRef(pos, &child)) return true;
        }
        return false;
    }

    fn placeRefs(self: *const Sheet, pos: common.upos, ast: *const AST) void {
        if (ast.value == .ref) {
            if (self.cell(ast.value.ref)) |c| {
                c.refers.append(pos);
            }
        }
        for (ast.children) |child| {
            self.placeRefs(pos, child);
        }
    }

    /// remove `pos` as a refer from all cells references by `ast`
    fn removeRefs(self: *const Sheet, pos: common.upos, ast: *const AST) void {
        if (ast.value == .ref) {
            if (self.cell(ast.value.ref)) |c| {
                _ = c.removeRefer(pos);
            }
        }
        for (ast.children) |child| {
            self.removeRefs(pos, child);
        }
    }
};
