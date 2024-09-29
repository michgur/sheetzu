const std = @import("std");
const Cell = @import("Cell.zig");
const Style = @import("../render/Style.zig");
const common = @import("../common.zig");
const Key = @import("../input/Key.zig");

const Sheet = @This();

rows: []usize,
cols: []usize,
cells: []Cell,

current: common.ipos = .{ 0, 0 },
header_style: Style = .{
    .fg = .black,
    .bg = .cyan,
    .bold = true,
},

pub fn init(allocator: std.mem.Allocator, rows: usize, cols: usize) !Sheet {
    const sht = Sheet{
        .cells = try allocator.alloc(Cell, rows * cols),
        .rows = try allocator.alloc(usize, rows),
        .cols = try allocator.alloc(usize, cols),
    };
    for (0..sht.cells.len) |i| {
        sht.cells[i] = Cell.init(allocator);
    }
    for (0..rows) |i| {
        sht.rows[i] = 1; // ignored for now
    }
    for (0..cols) |i| {
        sht.cols[i] = 9;
    }
    return sht;
}

pub fn getCell(self: *const Sheet, position: common.upos) ?*Cell {
    if (position[0] >= self.rows.len or position[1] >= self.cols.len) return null;
    return &self.cells[position[0] * self.cols.len + position[1]];
}

pub inline fn getCurrentCell(self: *const Sheet) *Cell {
    return self.getCell(common.posCast(self.current)) orelse unreachable;
}

pub fn setCell(self: *Sheet, position: common.upos, content: []const u8) !void {
    const row: usize = @intCast(position[0]);
    const col: usize = @intCast(position[1]);
    var cell = &self.cells[row * self.cols.len + col];
    _ = try cell.str.replaceAll(content);
    self.cols[col] = @max(self.cols[col], cell.str.display_width());
    cell.tick();
}

pub inline fn setCurrentCell(self: *Sheet, content: []const u8) !void {
    try self.setCell(common.posCast(self.current), content);
}

pub fn onInput(self: *Sheet, input: Key) !void {
    const row: usize = @intCast(self.current[0]);
    const col: usize = @intCast(self.current[1]);
    var cell = &self.cells[row * self.cols.len + col];
    if (input.codepoint == .backspace) {
        if (cell.str.graphemes.items.len > 0) {
            cell.str.remove(cell.str.graphemes.items.len - 1);
        }
    } else {
        try cell.str.append(input.bytes);
        self.cols[col] = @max(self.cols[col], cell.str.display_width());
    }
}
