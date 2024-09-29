const std = @import("std");
const common = @import("../common.zig");
const Screen = @import("Screen.zig");
const Sheet = @import("../sheets/Sheet.zig");
const Style = @import("Style.zig");
const DisplayString = @import("../DisplayString.zig");

const SheetRenderer = @This();

screen: *Screen,
pen: common.upos = .{ 0, 0 },

inline fn put(self: *SheetRenderer, value: anytype, style: ?Style) void {
    var px = self.screen.getPixel(self.pen) orelse unreachable;
    switch (@TypeOf(value)) {
        u8 => px.setAscii(value),
        DisplayString.Grapheme => px.set(value),
        else => @compileError(std.fmt.comptimePrint("Unsupported render type {s}", .{@typeName(@TypeOf(value))})),
    }
    if (style) |st| px.style = st;
}

const PenError = error{OutOfScreen};
inline fn penDown(self: *SheetRenderer) PenError!void {
    if (self.pen[0] + 1 >= self.screen.size[0]) return PenError.OutOfScreen;

    self.pen[0] += 1;
    self.pen[1] = 0;
}
inline fn penNext(self: *SheetRenderer) PenError!void {
    if (self.pen[1] + 1 >= self.screen.size[1]) return PenError.OutOfScreen;
    self.pen[1] += 1;
}
inline fn penReset(self: *SheetRenderer) void {
    self.pen = .{ 0, 0 };
}

fn renderCell(
    self: *SheetRenderer,
    width: usize,
    content: *DisplayString,
    style: Style,
    alignment: enum { left, right, center },
) PenError!void {
    const EMPTY: u8 = '\x20';
    const content_width = content.display_width();
    const end_pos = self.pen + common.upos{ 0, width };
    const left_padding = switch (alignment) {
        .left => 0,
        .center => @max(0, width - content_width) / 2,
        .right => @max(0, width - content_width), // this seems wrong
    };

    for (0..left_padding) |_| {
        self.put(EMPTY, style);
        try self.penNext();
    }

    var iter = content.iterator();
    while (iter.next()) |grapheme| {
        self.put(grapheme, style);
        try self.penNext();
    }

    if (self.pen[1] < end_pos[1]) {
        for (self.pen[1]..end_pos[1]) |_| {
            self.put(EMPTY, style);
            try self.penNext();
        }
    }
}

pub fn render(self: *SheetRenderer, sht: *const Sheet) !void {
    var allocator = std.heap.stackFallback(2048, std.heap.page_allocator);
    var buf: [16]u8 = undefined; // for string operations
    var str = DisplayString.init(allocator.get());
    defer str.deinit();

    self.penReset();

    try str.append(common.bb26(@intCast(sht.current[1]), &buf));
    try str.append(":");
    try str.append(try std.fmt.bufPrint(&buf, "{d}", .{sht.current[0] + 1}));
    self.renderCell(
        self.screen.size[1],
        &str,
        .{ .fg = .green },
        .left,
    ) catch {};
    self.penDown() catch return;

    self.renderCell(self.screen.size[1], try str.replaceAll(sht.getCurrentCell().str.bytes.items), .{}, .left) catch {};
    self.penDown() catch return;

    // render sheetzu
    const row_header_w = std.math.log10(sht.cols.len) + 2;
    self.renderCell(
        row_header_w,
        try str.replaceAll("•ᴥ•"),
        .{ .fg = .cyan },
        .right,
    ) catch {};

    // render column headers
    for (sht.cols, 0..) |w, i| {
        const header = common.bb26(i, &buf);

        var st = sht.header_style;
        if (i == sht.current[1]) st.reverse = true;
        self.renderCell(w, try str.replaceAll(header), st, .center) catch break;
    }

    for (sht.rows, 0..) |_, r| {
        self.penDown() catch break;

        // row header
        const header = try str.replaceAll(try std.fmt.bufPrint(&buf, "{d}", .{r + 1}));
        try header.append(&.{'\x20'});
        var st = sht.header_style;
        if (r == sht.current[0]) st.reverse = true;
        self.renderCell(row_header_w, header, st, .right) catch continue;

        // row content
        for (sht.cols, 0..) |w, c| {
            var cell = sht.cells[r * sht.cols.len + c];
            const is_current = r == sht.current[0] and c == sht.current[1];
            self.renderCell(
                w,
                &cell.str,
                if (is_current) sht.header_style else cell.style,
                .left,
            ) catch break;
        }
    }
}
