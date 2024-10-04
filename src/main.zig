const std = @import("std");
const Input = @import("input/Input.zig");
const SheetRenderer = @import("render/SheetRenderer.zig");
const Sheet = @import("sheets/Sheet.zig");
const common = @import("common.zig");
const Screen = @import("render/Screen.zig");
const String = @import("string/String.zig");

const posix = std.posix;

const Term = @This();

tty: std.fs.File,
raw_termios: posix.termios = undefined,
orig_termios: posix.termios = undefined,
uncooked: bool = false,
screen: Screen = undefined,
clipboard: ?String = null,

pub fn init() !Term {
    return Term{
        .tty = try std.fs.cwd().openFile("/dev/tty", .{ .mode = .read_write }),
    };
}

pub fn deinit(self: *Term) void {
    self.screen.deinit();
    if (self.clipboard) |*cb| cb.deinit(self.screen.allocator);

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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer switch (gpa.deinit()) {
        .leak => {
            std.debug.print("oops, leaky time!", .{});
        },
        .ok => {},
    };

    var term = try Term.init();
    try term.uncook();
    defer term.deinit();

    term.screen = try Screen.init(term.tty.writer(), allocator, try term.getSize());

    var sht = try Sheet.init(allocator, .{ 60, 100 });
    defer sht.deinit();

    var renderer = SheetRenderer{ .screen = &term.screen };

    try posix.sigaction(posix.SIG.WINCH, &posix.Sigaction{
        .handler = .{ .handler = handleSigWinch },
        .mask = 0,
        .flags = 0,
    }, null);
    var input = Input{ .reader = term.tty.reader() };

    const fps = 60;
    const npf: u64 = 1_000_000_000 / fps; // nanos per frame (more or less...)

    var then = std.time.nanoTimestamp();
    outer: while (true) {
        const now = std.time.nanoTimestamp();
        const dt: u64 = @intCast(@as(i64, @truncate(now - then)));
        if (dt < npf) {
            std.time.sleep(dt);
        }
        then = now;

        if (winch) {
            try term.screen.resize(try term.getSize());
            winch = false;
        }

        try renderer.render(&sht);
        try term.screen.flush();

        while (input.next() catch continue :outer) |key| {
            if (sht.mode == .insert) {
                if (key.codepoint == .escape) {
                    sht.commit();
                    sht.mode = .normal;
                } else {
                    try sht.onInput(key);
                }
            } else {
                switch (key.codepoint) {
                    .h => sht.current -|= .{ 0, 1 },
                    .l => sht.current += .{ 0, 1 },
                    .j => sht.current += .{ 1, 0 },
                    .k => sht.current -|= .{ 1, 0 },
                    .i => {
                        sht.mode = .insert;
                    },
                    .x => {
                        var cell = @constCast(sht.currentCell());
                        cell.input.clearAndFree();
                        const str = try cell.str.clone(allocator);
                        sht.commit();

                        if (term.clipboard) |*cb| {
                            cb.deinit(allocator);
                        }
                        term.clipboard = str;
                    },
                    .y => {
                        const str = try sht.currentCell().str.clone(allocator);
                        if (term.clipboard) |*cb| {
                            cb.deinit(allocator);
                        }
                        term.clipboard = str;
                    },
                    .p => {
                        if (term.clipboard) |cb| {
                            var cell = @constCast(sht.currentCell());
                            cell.input.clearAndFree();
                            try cell.input.writer().writeAll(cb.bytes);
                            sht.commit();
                        }
                    },
                    .q => break :outer,
                    else => {},
                }
                sht.current = @min(sht.current, common.upos{ sht.rows.len - 1, sht.cols.len - 1 });
            }
        }
    }
}

var winch: bool = false;

fn handleSigWinch(_: c_int) callconv(.C) void {
    winch = true;
}

fn getSize(self: *const Term) !common.upos {
    var size = std.mem.zeroes(posix.winsize);
    const err = posix.system.ioctl(self.tty.handle, posix.T.IOCGWINSZ, @intFromPtr(&size));
    if (posix.errno(err) != .SUCCESS) {
        return posix.unexpectedErrno(@enumFromInt(err));
    }
    return .{ size.ws_row, size.ws_col };
}
