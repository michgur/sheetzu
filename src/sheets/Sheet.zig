const std = @import("std");
const Cell = @import("Cell.zig");
const Style = @import("../render/Style.zig");
const common = @import("../common.zig");
const Key = @import("../input/Key.zig");
const AST = @import("../formula/AST.zig");
const Parser = @import("../formula/Parser.zig");
const String = @import("../string/String.zig");
const StringWriter = @import("../string/StringWriter.zig");
const Evaluator = @import("../formula/Evaluator.zig");

const Sheet = @This();

allocator: std.mem.Allocator,
evaluator: Evaluator,
cells: [*][*]*Cell,
size: common.upos,

header_style: Style = .{
    .fg = .black,
    .bg = .cyan,
    .bold = true,
},
cursor_style: Style = .{
    .fg = .white,
    .bg = .blue,
},
rows: []usize,
cols: []usize,

const Error = error{ CircularDependency, OutOfBounds };

pub fn init(allocator: std.mem.Allocator, initial_size: common.upos) !Sheet {
    const cells_slc = try allocator.alloc([*]*Cell, initial_size[0]);
    for (cells_slc) |*r| {
        const row_slc = try allocator.alloc(*Cell, initial_size[1]);
        for (row_slc) |*c| {
            const cell_pt = try allocator.create(Cell);
            cell_pt.* = Cell{};
            c.* = cell_pt;
        }
        r.* = row_slc.ptr;
    }

    const rows = try allocator.alloc(usize, initial_size[0]);
    @memset(rows, 1); // ignored for now
    const cols = try allocator.alloc(usize, initial_size[1]);
    @memset(cols, 9);
    return Sheet{
        .allocator = allocator,
        .evaluator = Evaluator.init(),
        .cells = cells_slc.ptr,
        .size = initial_size,
        .rows = rows,
        .cols = cols,
    };
}

pub fn deinit(self: *Sheet) void {
    for (0..self.size[0]) |r| {
        for (0..self.size[1]) |c| {
            self.cells[r][c].deinit(self.allocator);
            self.allocator.destroy(self.cells[r][c]);
        }
        self.allocator.free(self.cells[r][0..self.size[1]]);
    }
    self.allocator.free(self.cells[0..self.size[0]]);
    self.allocator.free(self.rows);
    self.allocator.free(self.cols);
    self.evaluator.deinit();
    self.* = undefined;
}

pub fn cell(self: *const Sheet, pos: common.upos) ?*Cell {
    if (@reduce(.Or, pos >= self.size)) return null;
    return self.cells[pos[0]][pos[1]];
}

fn errorAST(allocator: std.mem.Allocator) AST {
    const msg_stack = "!ERR";
    const msg = allocator.alloc(u8, msg_stack.len) catch @panic("Out of memory");
    @memcpy(msg, msg_stack);
    return AST{ .content = .{ .value = .{ .err = msg } } };
}

pub fn clearAndCommit(self: *Sheet, pos: common.upos) ?void {
    var cl = self.cell(pos) orelse return null;
    cl.input.clearAndFree(self.allocator);
    cl.dirty = true;
    self.commit(pos) orelse unreachable;
}

pub fn commit(self: *Sheet, pos: common.upos) ?void {
    var cl = self.cell(pos) orelse return null;
    var input = String.init(self.allocator, cl.input.items) catch @panic("Out of memory");
    defer input.deinit(self.allocator);

    var ast = Parser.parse(self.allocator, input.bytes) catch errorAST(self.allocator);
    if (self.isCircularRef(pos, &ast)) {
        ast.deinit(self.allocator);
        ast = errorAST(self.allocator);
    }
    self.removeRefs(pos, &cl.ast);
    self.placeRefs(pos, &ast);

    cl.ast.deinit(self.allocator);
    cl.ast = ast;
    self.tick(pos);
}

pub fn tick(self: *Sheet, pos: common.upos) void {
    var cl = self.cell(pos) orelse return;

    cl.value.deinit(self.allocator);
    cl.str.deinit(self.allocator);

    self.evaluator.sheet = self;
    cl.value = self.evaluator.eval(self.allocator, &cl.ast) catch @panic("fuck");
    cl.str = self.evaluator.asOwnedString(self.allocator, cl.value) catch @panic("fuck2");

    for (cl.referrers.items) |refer| {
        self.tick(refer);
    }

    self.cols[pos[1]] = @max(self.cols[pos[1]], cl.str.displayWidth());
}

/// whether `this` depends on `upon`. `upon` is out of bounds, returns false
pub fn dependsOn(self: *const Sheet, this: common.upos, upon: common.upos) bool {
    const upon_cell = self.cell(upon) orelse return false;
    if (@reduce(.And, this == upon)) return true;
    return for (upon_cell.referrers.items) |refer| {
        if (@reduce(.And, this == refer)) break true;
    } else false;
}

/// whether placing `ast` on `pos` will cause a circluar dependency
/// i.e. the AST references a cell that depends on `pos`
fn isCircularRef(self: *const Sheet, pos: common.upos, ast: *const AST) bool {
    if (ast.content == .value and ast.content.value == .ref) {
        return self.dependsOn(ast.content.value.ref, pos);
    }
    for (ast.children) |child| {
        if (self.isCircularRef(pos, &child)) return true;
    }
    return false;
}

fn placeRefs(self: *const Sheet, pos: common.upos, ast: *const AST) void {
    if (ast.content == .value and ast.content.value == .ref) {
        if (self.cell(ast.content.value.ref)) |c| {
            c.referrers.append(self.allocator, pos) catch @panic("Out of memory");
        }
    }
    for (ast.children) |*child| {
        self.placeRefs(pos, child);
    }
}

/// remove `pos` as a refer from all cells references by `ast`
fn removeRefs(self: *const Sheet, pos: common.upos, ast: *const AST) void {
    if (ast.content == .value and ast.content.value == .ref) {
        if (self.cell(ast.content.value.ref)) |c| {
            _ = c.removeReferrer(pos);
        }
    }
    for (ast.children) |*child| {
        self.removeRefs(pos, child);
    }
}
