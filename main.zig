const std = @import("std");
const Input = @import("input/Input.zig");
const Renderer = @import("render/Renderer.zig");
const Sheet = @import("sheets/Sheet.zig");
const Position = @import("common.zig").ipos;
const common = @import("common.zig");

const posix = std.posix;

const Term = @This();

tty: std.fs.File,
raw_termios: posix.termios = undefined,
orig_termios: posix.termios = undefined,
uncooked: bool = false,
size: Size = undefined,
renderer: Renderer = undefined,

const Size = struct { rows: usize, cols: usize };

pub fn init() !Term {
    return Term{
        .tty = try std.fs.cwd().openFile("/dev/tty", .{ .mode = .read_write }),
    };
}

pub fn deinit(self: *Term) void {
    self.cook() catch {};
    self.tty.close();
}

pub fn cook(self: *Term) !void {
    if (!self.uncooked) return;
    defer self.uncooked = false;

    try posix.tcsetattr(self.tty.handle, .FLUSH, self.orig_termios);
}

pub fn uncook(self: *Term) !void {
    if (self.uncooked) return;
    defer self.uncooked = true;

    self.orig_termios = try posix.tcgetattr(self.tty.handle);
    errdefer self.cook() catch {};

    self.raw_termios = self.orig_termios;
    self.raw_termios.lflag.ECHO = false;
    self.raw_termios.lflag.ECHONL = false;
    self.raw_termios.lflag.ICANON = false;
    self.raw_termios.lflag.ISIG = false;
    self.raw_termios.lflag.IEXTEN = false;
    self.raw_termios.iflag.IGNCR = false;
    self.raw_termios.iflag.INLCR = false;
    self.raw_termios.iflag.PARMRK = false;
    self.raw_termios.iflag.IGNBRK = false;
    self.raw_termios.iflag.IXON = false;
    // self.raw_termios.iflag.ICRNL = false;
    self.raw_termios.iflag.BRKINT = false;
    self.raw_termios.iflag.ISTRIP = false;
    self.raw_termios.oflag.OPOST = false;
    self.raw_termios.cflag.PARENB = false;
    self.raw_termios.cflag.CSIZE = .CS8;
    self.raw_termios.cc[@intFromEnum(posix.system.V.TIME)] = 0;
    self.raw_termios.cc[@intFromEnum(posix.system.V.MIN)] = 0;
    try posix.tcsetattr(self.tty.handle, .FLUSH, self.raw_termios);
}

pub fn clear_screen(self: *const Term) !void {
    const writer = self.tty.writer();
    try writer.writeAll("\x1b[s"); // Save cursor position.
    try writer.writeAll("\x1b[?47h"); // Save screen.
    try writer.writeAll("\x1b[?1049h"); // Enable alternative buffer.
    try writer.writeAll("\x1b[2J"); // Clear screen
}

pub fn restore_screen(self: *const Term) !void {
    const writer = self.tty.writer();
    try writer.writeAll("\x1b[?1049l"); // Disable alternative buffer.
    try writer.writeAll("\x1b[?47l"); // Restore screen.
    try writer.writeAll("\x1b[u"); // Restore cursor position.
}

pub fn main() !void {
    var term = try Term.init();
    try term.uncook();
    defer {
        term.restore_screen() catch {};
        term.deinit();
    }
    global_term = &term;

    term.renderer = try Renderer.init(
        term.tty.writer(),
        std.heap.page_allocator,
        term.size.rows,
        term.size.cols,
    );

    try term.clear_screen();
    try term.updateSize();

    var sht = try Sheet.init(std.heap.page_allocator, 60, 100);

    try posix.sigaction(posix.SIG.WINCH, &posix.Sigaction{
        .handler = .{ .handler = handleSigWinch },
        .mask = 0,
        .flags = 0,
    }, null);
    var input = Input{ .reader = term.tty.reader() };
    var insert_mode = false;

    const fps = 60;
    const npf: u64 = 1_000_000_000 / fps; // nanos per frame (more or less...)

    var then = std.time.nanoTimestamp();
    outer: while (true) {
        const now = std.time.nanoTimestamp();
        const dt: u64 = @intCast(now - then);
        if (dt < npf) {
            std.time.sleep(dt);
        }
        then = now;

        try sht.render(&term.renderer);
        try term.renderer.flush();

        while (input.next() catch continue :outer) |key| {
            if (insert_mode) {
                if (key.codepoint == .escape) {
                    if (insert_mode) {
                        sht.tick();
                        insert_mode = false;
                    }
                } else {
                    try sht.onInput(key);
                }
            } else {
                switch (key.codepoint) {
                    .h => sht.current -= .{ 0, 1 },
                    .l => sht.current += .{ 0, 1 },
                    .j => sht.current += .{ 1, 0 },
                    .k => sht.current -= .{ 1, 0 },
                    .i => {
                        insert_mode = true;
                    },
                    .x => try sht.setCell(common.posCast(sht.current), &.{}),
                    .q => break :outer,
                    else => {},
                }
                sht.current = @max(sht.current, Position{ 0, 0 });
                sht.current = @min(sht.current, Position{ @intCast(sht.rows.len - 1), @intCast(sht.cols.len - 1) });
            }
        }
    }
}

var global_term: *Term = undefined;
fn handleSigWinch(_: c_int) callconv(.C) void {
    global_term.updateSize() catch return;
}

pub fn updateSize(self: *Term) !void {
    var size = std.mem.zeroes(posix.winsize);
    const err = posix.system.ioctl(self.tty.handle, posix.T.IOCGWINSZ, @intFromPtr(&size));
    if (posix.errno(err) != .SUCCESS) {
        return posix.unexpectedErrno(@enumFromInt(err));
    }
    self.size = Size{
        .rows = size.ws_row,
        .cols = size.ws_col,
    };
    try self.renderer.resize(self.size.rows, self.size.cols);
}
