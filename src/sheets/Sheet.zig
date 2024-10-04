const std = @import("std");
const Cell = @import("Cell.zig");
const Style = @import("../render/Style.zig");
const common = @import("../common.zig");
const Key = @import("../input/Key.zig");
const AST = @import("../formula/AST.zig");
const Parser = @import("../formula/Parser.zig");
const String = @import("../string/String.zig");
const StringWriter = @import("../string/StringWriter.zig");

const Sheet = @This();

allocator: std.mem.Allocator,
cells: [*][*]*Cell,
size: common.upos,

current: common.ipos = .{ 0, 0 },
header_style: Style = .{
    .fg = .black,
    .bg = .cyan,
    .bold = true,
},
rows: []usize,
cols: []usize,
mode: enum {
    normal,
    insert,
} = .normal,

const Error = error{ CircularDependency, OutOfBounds };

pub fn init(allocator: std.mem.Allocator, initial_size: common.upos) !Sheet {
    const cells_slc = try allocator.alloc([*]*Cell, initial_size[0]);
    for (cells_slc) |*r| {
        const row_slc = try allocator.alloc(*Cell, initial_size[1]);
        for (row_slc) |*c| {
            const cell_pt = try allocator.create(Cell);
            cell_pt.* = Cell.init(allocator);
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
        .cells = cells_slc.ptr,
        .size = initial_size,
        .rows = rows,
        .cols = cols,
    };
}

pub fn deinit(self: *Sheet) void {
    for (0..self.size[0]) |r| {
        for (0..self.size[1]) |c| {
            self.cells[r][c].deinit(self);
            self.allocator.destroy(self.cells[r][c]);
        }
        self.allocator.free(self.cells[r][0..self.size[1]]);
    }
    self.allocator.free(self.rows);
    self.allocator.free(self.cols);
    self.allocator.free(self.cells[0..self.size[0]]);
    self.* = undefined;
}

fn varcell(self: *const Sheet, pos: common.upos) ?*Cell {
    if (@reduce(.Or, pos >= self.size)) return null;
    return self.cells[pos[0]][pos[1]];
}
pub inline fn cell(self: *const Sheet, pos: common.upos) ?*const Cell {
    return self.varcell(pos);
}

pub inline fn currentCell(self: *const Sheet) *const Cell {
    return self.cell(common.posCast(self.current)) orelse unreachable;
}

pub fn onInput(self: *Sheet, input: Key) !void {
    var c: *Cell = @constCast(self.currentCell());
    c.dirty = true;
    if (input.codepoint == .backspace) {
        _ = c.input.bytes.popOrNull();
    } else {
        try c.input.writer().writeAll(input.bytes);
    }
}

fn errorAST(allocator: std.mem.Allocator) AST {
    const msg_stack = "!ERR";
    const msg = allocator.alloc(u8, msg_stack.len) catch @panic("Out of memory");
    @memcpy(msg, msg_stack);
    return AST{ .value = .{ .err = msg } };
}

pub fn tick(self: *Sheet) void {
    var c: *Cell = @constCast(self.currentCell());
    if (c.dirty) {
        var input = c.input.stringCopy(self.allocator) catch @panic("Out of memory");
        defer input.deinit(self.allocator);
        self.placeASTCurrent(
            Parser.parse(self.allocator, input.bytes) catch errorAST(self.allocator),
        ) catch |err| {
            if (err == std.mem.Allocator.Error.OutOfMemory) {
                @panic("Out of memory");
            } else {
                self.placeASTCurrent(errorAST(self.allocator)) catch @panic("Out of memory");
            }
        };
        c.dirty = false;
    }
}

pub fn placeAST(self: *const Sheet, pos: common.upos, ast: AST) Error!void {
    var c: *Cell = @constCast(self.cell(pos)) orelse return Error.OutOfBounds;
    if (isCircularRef(self, pos, &ast)) return Error.CircularDependency;
    self.removeRefs(pos, &c.ast);
    self.placeRefs(pos, &ast);
    c.ast.deinit(self.allocator);
    c.ast = ast;
    c.tick(self);
    self.cols[pos[1]] = @max(self.cols[pos[1]], c.str.displayWidth());
}

pub inline fn placeASTCurrent(self: *const Sheet, ast: AST) Error!void {
    try self.placeAST(common.posCast(self.current), ast);
}

pub fn setCell(self: *const Sheet, pos: common.upos, content: String) (Error || Parser.Error)!void {
    var c = self.varcell(pos) orelse return Error.OutOfBounds;
    c.input.clearAndFree();
    try c.input.writer().writeAll(content.bytes);
    const ast = try Parser.parse(self.allocator, content.bytes);
    try self.placeAST(pos, ast);
}

pub fn setCurrentCell(self: *const Sheet, content: String) (Error || Parser.Error)!void {
    try self.setCell(common.posCast(self.current), content);
}

/// whether `this` depends on `upon`. `upon` is out of bounds, returns false
pub fn dependsOn(self: *const Sheet, this: common.upos, upon: common.upos) bool {
    const upon_cell = self.cell(upon) orelse return false;
    if (@reduce(.And, this == upon)) return true;
    return for (upon_cell.refers.items) |refer| {
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
        if (self.varcell(ast.value.ref)) |c| {
            c.refers.append(pos) catch @panic("Out of memory");
        }
    }
    for (ast.children) |*child| {
        self.placeRefs(pos, child);
    }
}

/// remove `pos` as a refer from all cells references by `ast`
fn removeRefs(self: *const Sheet, pos: common.upos, ast: *const AST) void {
    if (ast.value == .ref) {
        if (self.varcell(ast.value.ref)) |c| {
            _ = c.removeRefer(pos);
        }
    }
    for (ast.children) |*child| {
        self.removeRefs(pos, child);
    }
}
