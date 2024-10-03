const std = @import("std");
const common = @import("../common.zig");
const Screen = @import("Screen.zig");
const Sheet = @import("../sheets/Sheet.zig");
const Style = @import("Style.zig");
const String = @import("../String.zig");

const SheetRenderer = @This();

screen: *Screen,
pen: common.upos = .{ 0, 0 },

inline fn put(self: *SheetRenderer, value: anytype, style: ?Style) void {
    var px = self.screen.getPixel(self.pen) orelse unreachable;
    switch (@TypeOf(value)) {
        u8 => px.setAscii(value),
        String.Codepoint => px.set(value),
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
inline fn penNext(self: *SheetRenderer, amt: usize) PenError!void {
    if (self.pen[1] + amt >= self.screen.size[1]) return PenError.OutOfScreen;
    self.pen[1] += amt;
}
inline fn penReset(self: *SheetRenderer) void {
    self.pen = .{ 0, 0 };
}

fn renderCell(
    self: *SheetRenderer,
    width: usize,
    content: *String,
    style: Style,
    alignment: enum { left, right, center },
) PenError!void {
    const EMPTY: u8 = '\x20';
    const content_width = content.display_width();
    const left_padding = switch (alignment) {
        .left => 0,
        .center => (width -| content_width) / 2,
        .right => width -| content_width, // this seems wrong
    };
    const right_padding = width -| content_width -| left_padding;

    for (0..left_padding) |_| {
        self.put(EMPTY, style);
        try self.penNext(1);
    }

    var iter = content.iterator();
    while (iter.next()) |codepoint| {
        self.put(codepoint, style);
        try self.penNext(codepoint.info.display_width);
    }

    for (0..right_padding) |_| {
        self.put(EMPTY, style);
        try self.penNext(1);
    }
}

const scrolloff: usize = 1;
var offset: common.upos = .{ 0, 0 };
fn computeCellOffset(self: *SheetRenderer, sht: *const Sheet) void {
    const sizes = [2][]usize{ sht.rows, sht.cols };
    const paddings = [2]usize{ 2, 0 };
    for (0..2) |d| {
        const curr: usize = @intCast(sht.current[d]);
        const start = curr + 1 -| scrolloff;
        const end = @min(sizes[d].len, curr + scrolloff);
        if (start < offset[d]) {
            offset[d] = @max(0, start);
            continue;
        }

        var acc_size: usize = 0;
        for (offset[d]..end) |i| {
            acc_size += sizes[d][i];
        }
        for (offset[d]..end) |i| {
            if (acc_size < self.screen.size[d] - paddings[d]) break;
            acc_size -= sizes[d][i];
            offset[d] += 1;
        }
    }
}

pub fn render(self: *SheetRenderer, sht: *const Sheet) !void {
    var allocator = std.heap.stackFallback(2048, std.heap.page_allocator);
    var buf: [16]u8 = undefined; // for string operations
    var str = String.init(allocator.get());
    defer str.deinit();

    self.penReset();
    self.computeCellOffset(sht);

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

    self.renderCell(self.screen.size[1], try str.replaceAll(sht.currentCell().input.bytes.items), .{}, .left) catch {};
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
    for (sht.cols[offset[1]..], offset[1]..) |w, i| {
        const header = common.bb26(i, &buf);

        var st = sht.header_style;
        if (i == sht.current[1]) st.reverse = true;
        self.renderCell(w, try str.replaceAll(header), st, .center) catch break;
    }

    for (sht.rows[offset[0]..], offset[0]..) |_, r| {
        self.penDown() catch break;

        // row header
        const header = try str.replaceAll(try std.fmt.bufPrint(&buf, "{d}", .{r + 1}));
        try header.append(&.{'\x20'});
        var st = sht.header_style;
        if (r == sht.current[0]) st.reverse = true;
        self.renderCell(row_header_w, header, st, .right) catch continue;

        // row content
        for (sht.cols[offset[1]..], offset[1]..) |w, c| {
            var cell = sht.cell(.{ r, c }) orelse break;
            const is_current = r == sht.current[0] and c == sht.current[1];
            var cellstr = try (if (cell.dirty) cell.input else cell.str).clone();
            defer cellstr.deinit();
            self.renderCell(
                w,
                &cellstr,
                if (is_current) sht.header_style else cell.style,
                if (cell.value == .number) .right else .left,
            ) catch break;
        }
    }
}
