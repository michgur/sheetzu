const std = @import("std");
const common = @import("../common.zig");
const Screen = @import("Screen.zig");
const Sheet = @import("../sheets/Sheet.zig");
const Style = @import("Style.zig");
const DisplayString = @import("../DisplayString.zig");

const SheetRenderer = @This();

screen: *Screen,

inline fn put(self: *SheetRenderer, pos: common.upos, value: anytype, style: ?Style) bool {
    var px = self.screen.getPixel(pos) orelse return false;
    switch (@TypeOf(value)) {
        u8 => px.setAscii(value),
        DisplayString.Grapheme => px.set(value),
        else => @compileError(std.fmt.comptimePrint("Unsupported render type {s}", .{@typeName(@TypeOf(value))})),
    }
    if (style) |st| px.style = st;
    return true;
}

fn renderCell(
    self: *SheetRenderer,
    start_pos: common.upos,
    width: usize,
    content: *DisplayString,
    style: Style,
    alignment: enum { left, right, center },
) void {
    const EMPTY: u8 = '\x20';
    const content_width = content.display_width();
    const end_pos = start_pos + common.upos{ 0, width };
    const left_padding = switch (alignment) {
        .left => 0,
        .center => @max(0, width - content_width) / 2,
        .right => @max(0, width - content_width), // this seems wrong
    };

    var write_pos = start_pos;
    for (0..left_padding) |_| {
        if (write_pos[1] > end_pos[1] or !self.put(write_pos, EMPTY, style)) return;
        write_pos[1] += 1;
    }

    var iter = content.iterator();
    while (iter.next()) |grapheme| {
        if (write_pos[1] > end_pos[1] or !self.put(write_pos, grapheme, style)) return;
        write_pos[1] += 1;
    }

    if (write_pos[1] < end_pos[1]) {
        for (write_pos[1]..end_pos[1]) |_| {
            if (!self.put(write_pos, EMPTY, style)) return;
            write_pos[1] += 1;
        }
    }
}

pub fn render(self: *SheetRenderer, sht: *const Sheet) !void {
    var str = DisplayString.init(std.heap.page_allocator);
    defer str.deinit();

    // render sheetzu
    const row_header_w = std.math.log10(sht.cols.len) + 2;
    self.renderCell(
        .{ 0, 0 },
        row_header_w,
        try str.replaceAll("•ᴥ•"),
        .{ .fg = .cyan },
        .right,
    );

    var x: usize = row_header_w;
    var y: usize = 0;

    // render column headers
    var bb26buf: [8]u8 = undefined;
    for (sht.cols, 0..) |w, i| {
        const header = common.bb26(i, &bb26buf);

        var st = sht.header_style;
        if (i == sht.current[1]) st.reverse = true;
        self.renderCell(.{ y, x }, w, try str.replaceAll(header), st, .center);

        x += w;
        if (x >= self.screen.size[1]) break;
    }

    var pd: [16]u8 = undefined;
    @memset(&pd, 32);
    var b10buf: [16]u8 = undefined;
    for (sht.rows, 0..) |_, r| {
        y += 1;
        if (y >= self.screen.size[0]) break;

        // row header
        const header = try str.replaceAll(try std.fmt.bufPrint(&b10buf, "{d}", .{y}));
        try header.append(&.{'\x20'});
        var st = sht.header_style;
        if (r == sht.current[0]) st.reverse = true;
        self.renderCell(.{ y, 0 }, row_header_w, header, st, .right);

        // row content
        x = row_header_w;
        for (sht.cols, 0..) |w, c| {
            var cell = sht.cells[r * sht.cols.len + c];
            const is_current = r == sht.current[0] and c == sht.current[1];
            self.renderCell(
                .{ y, x },
                w,
                &cell.str,
                if (is_current) sht.header_style else cell.style,
                .left,
            );
            x += w;
            if (x >= self.screen.size[1]) break;
        }
    }
}
