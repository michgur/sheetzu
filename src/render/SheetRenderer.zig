const std = @import("std");
const common = @import("../common.zig");
const Screen = @import("Screen.zig");
const Sheet = @import("../sheets/Sheet.zig");
const Style = @import("Style.zig");
const String = @import("../string/String.zig");
const StringWriter = @import("../string/StringWriter.zig");
const InputHandler = @import("../InputHandler.zig");

const SheetRenderer = @This();

screen: *const Screen,
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

const RenderOptions = struct {
    alignment: enum { left, right, center } = .left,
    cursor: bool = false,
};

fn renderCell(
    self: *SheetRenderer,
    width: usize,
    content: String,
    style: Style,
    opts: RenderOptions,
) PenError!void {
    const EMPTY: u8 = '\x20';

    const content_width = content.displayWidth() + @intFromBool(opts.cursor);
    const left_padding = switch (opts.alignment) {
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
    if (opts.cursor) {
        self.put(EMPTY, .{ .bg = .blue });
        try self.penNext(1);
    }

    for (0..right_padding) |_| {
        self.put(EMPTY, style);
        try self.penNext(1);
    }
}

const scrolloff: usize = 1;
var offset: common.upos = .{ 0, 0 };
fn computeCellOffset(self: *SheetRenderer, sht: *const Sheet, state: *const InputHandler) void {
    const sizes = [2][]usize{ sht.rows, sht.cols };
    const paddings = [2]usize{ 2, 0 };
    for (0..2) |d| {
        const curr: usize = @intCast(state.current[d]);
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

pub fn render(self: *SheetRenderer, sht: *const Sheet, state: *const InputHandler) !void {
    var render_arena = std.heap.ArenaAllocator.init(sht.allocator); // carelessly allocate temporary strings for rendering
    defer render_arena.deinit();
    const allocator = render_arena.allocator();
    var str_writer = StringWriter.init(allocator);
    var buf: [32]u8 = undefined; // for string operations
    const current_cell_preview = try String.init(allocator, state.currentCellPreview(allocator));

    self.penReset();
    self.computeCellOffset(sht, state);

    { // render current ref
        try str_writer.writer().print("{s}{d}", .{
            common.bb26(@intCast(state.current[1]), &buf),
            state.current[0] + 1,
        });
        const str = try str_writer.string(allocator);
        self.renderCell(
            self.screen.size[1],
            str,
            .{ .fg = .green },
            .{},
        ) catch {};
        self.penDown() catch return;
    }
    { // render input
        self.renderCell(self.screen.size[1], current_cell_preview, .{}, .{}) catch {};
        self.penDown() catch return;
    }

    const row_header_w = std.math.log10(sht.cols.len) + 2;
    { // render sheetzu
        const str = try String.init(allocator, "•ᴥ•");
        self.renderCell(
            row_header_w,
            str,
            .{ .fg = .cyan },
            .{ .alignment = .right },
        ) catch {};
    }
    { // render column headers
        for (sht.cols[offset[1]..], offset[1]..) |w, i| {
            const header = common.bb26(i, &buf);
            const str = try String.init(allocator, header);
            var st = sht.header_style;
            if (i == state.current[1]) st.reverse = true;
            self.renderCell(w, str, st, .{ .alignment = .center }) catch break;
        }
    }

    // render rows
    for (sht.rows[offset[0]..], offset[0]..) |_, r| {
        self.penDown() catch break;

        // row header
        try str_writer.writer().print("{d}\x20", .{r + 1});
        const header = try str_writer.string(allocator);
        var st = sht.header_style;
        if (r == state.current[0]) st.reverse = true;
        self.renderCell(row_header_w, header, st, .{ .alignment = .right }) catch continue;

        const formula_ref = if (state.formula) |f| if (f.ref) |ref| ref else null else null;
        // row content
        for (sht.cols[offset[1]..], offset[1]..) |w, c| {
            const cell = sht.cell(.{ r, c }) orelse break;
            const is_current = r == state.current[0] and c == state.current[1];
            const is_current_insert = is_current and state.mode == .insert;
            const is_formula_ref = if (formula_ref) |ref| ref[0] == r and ref[1] == c else false;
            const cellstr = if (is_current_insert) current_cell_preview else cell.str;
            self.renderCell(
                w,
                cellstr,
                if (is_current) st else if (is_formula_ref) .{ .fg = .black, .bg = .magenta } else cell.style,
                .{ .alignment = if (cell.value == .number and !is_current_insert) .right else .left, .cursor = is_current_insert },
            ) catch break;
        }
    }
}
