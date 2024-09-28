const std = @import("std");
const Cell = @import("Cell.zig");
const Renderer = @import("../render/Renderer.zig");
const Style = @import("../render/Style.zig");
const common = @import("../common.zig");
const Key = @import("../input/Key.zig");
const Str = @import("../utf8.zig").Str;

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
    // render column headers
    const row_header_w = std.math.log10(self.cols.len) + 2;

    const buf = renderer.buf;
    for (0..row_header_w) |i| {
        buf.pixels[i].style = .{
            .fg = .cyan,
        };
    }
    const sheetzu_idx = row_header_w - 4;
    @memcpy(buf.pixels[sheetzu_idx + 1].content[0..3], "•");
    @memcpy(buf.pixels[sheetzu_idx + 2].content[0..3], "ᴥ");
    @memcpy(buf.pixels[sheetzu_idx + 3].content[0..3], "•");
    buf.pixels[sheetzu_idx + 1].content_len = 3;
    buf.pixels[sheetzu_idx + 2].content_len = 3;
    buf.pixels[sheetzu_idx + 3].content_len = 3;
    var col_offset: usize = row_header_w;
    header: for (self.cols, 0..) |w, i| {
        const header = common.b26(i);
        const padding = (w - header.len) / 2;
        for (0..w) |cell_offset| {
            if (col_offset + cell_offset >= renderer.buf.size[1]) break :header;

            const px = &buf.pixels[col_offset + cell_offset];
            px.style = header_style;
            if (i == self.current[1]) px.style.reverse = true;
            px.content_len = 1;
            if (header.len + padding > cell_offset and cell_offset >= padding) {
                px.content[0] = header[cell_offset - padding];
            }
        }
        col_offset += w;
    }

    var pd = try Str.initBytes(buf.allocator, &[_]u8{32});
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
                px.content[0] = header[i - padding];
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

fn unicodeLen(bytes: []const u8) usize {
    var i: usize = 0;
    for (0..bytes.len) |len| {
        i += std.unicode.utf8ByteSequenceLength(bytes[i]) catch 1;
        if (i >= bytes.len) return len + 1;
    }
    return bytes.len;
}
pub fn setCell(self: *Sheet, position: common.upos, content: []const u8) !void {
    const row: usize = @intCast(position[0]);
    const col: usize = @intCast(position[1]);
    var cell = &self.cells[row * self.cols.len + col];
    try cell.str.replaceAll(content);
    self.cols[col] = @max(self.cols[col], cell.str.display_width());
    cell.tick();
}

pub fn onInput(self: *Sheet, input: Key) !void {
    const row: usize = @intCast(self.current[0]);
    const col: usize = @intCast(self.current[1]);
    var cell = &self.cells[row * self.cols.len + col];
    if (input.codepoint == .backspace) {
        if (cell.str.codepoints.items.len > 0) {
            cell.str.remove(cell.str.codepoints.items.len - 1);
        }
    } else {
        try cell.str.append(input.bytes);
        self.cols[col] = @max(self.cols[col], cell.str.display_width());
    }
}

pub fn tick(self: *Sheet) void {
    const row: usize = @intCast(self.current[0]);
    const col: usize = @intCast(self.current[1]);
    var cell = &self.cells[row * self.cols.len + col];
    cell.tick();
}
