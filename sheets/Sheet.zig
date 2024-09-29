const std = @import("std");
const Cell = @import("Cell.zig");
const Renderer = @import("../render/Renderer.zig");
const Style = @import("../render/Style.zig");
const common = @import("../common.zig");
const Key = @import("../input/Key.zig");
const DisplayString = @import("../DisplayString.zig");

const Sheet = @This();

rows: []usize,
cols: []usize,
cells: []Cell,

current: common.ipos = .{ 0, 0 },

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

const header_style = Style{
    .fg = .black,
    .bg = .cyan,
    .bold = true,
};
pub fn render(self: *const Sheet, renderer: *Renderer) !void {
    const buf = renderer.buf;

    // render sheetzu
    const row_header_w = std.math.log10(self.cols.len) + 2;
    for (0..row_header_w) |i| {
        buf.pixels[i].style = .{
            .fg = .cyan,
        };
    }
    const sheetzu_idx = row_header_w - 4;
    const eye = DisplayString.Grapheme.parseSingle("•");
    const mth = DisplayString.Grapheme.parseSingle("ᴥ");
    buf.pixels[sheetzu_idx + 1].set(eye);
    buf.pixels[sheetzu_idx + 2].set(mth);
    buf.pixels[sheetzu_idx + 3].set(eye);

    // render column headers
    var col_offset: usize = row_header_w;
    var bb26buf: [8]u8 = undefined;
    header: for (self.cols, 0..) |w, i| {
        const header = common.bb26(i, &bb26buf);
        const padding = (w - header.len) / 2;
        for (0..w) |cell_offset| {
            if (col_offset + cell_offset >= renderer.buf.size[1]) break :header;

            const px = &buf.pixels[col_offset + cell_offset];
            px.style = header_style;
            if (i == self.current[1]) px.style.reverse = true;
            if (header.len + padding > cell_offset and cell_offset >= padding) {
                px.setAscii(header[cell_offset - padding]);
            }
        }
        col_offset += w;
    }

    var pd = try DisplayString.initBytes(buf.allocator, &[_]u8{32});
    var row_offset: usize = buf.size[1];
    for (self.rows, 0..) |_, r| {
        if (r >= buf.size[0] - 1) break;

        const header = common.b10(r + 1);
        const padding = row_header_w - header.len - 1;
        for (0..row_header_w) |i| {
            const px = &buf.pixels[row_offset + i];
            px.style = header_style;
            if (r == self.current[0]) px.style.reverse = true;
            if (i >= padding and header.len + padding > i) {
                px.setAscii(header[i - padding]);
            }
        }
        col_offset = row_header_w;
        col: for (self.cols, 0..) |w, c| {
            const cell = self.cells[r * self.cols.len + c];
            var pos = common.upos{ r + 1, col_offset };
            const is_current = r == self.current[0] and c == self.current[1];
            const rect = renderer.writeStr(
                pos,
                cell.str,
                if (is_current) header_style else cell.style,
            );
            if (w < rect[1]) self.cols[c] = rect[1];
            pos[1] += rect[1];
            for (0..w - rect[1]) |_| {
                pos += renderer.writeStr(pos, pd, if (is_current) header_style else cell.style);
            }
            col_offset += w;
            if (buf.size[1] <= col_offset) break :col;
        }
        row_offset += buf.size[1];
    }
    pd.deinit();
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
    try cell.str.replaceAll(content);
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
