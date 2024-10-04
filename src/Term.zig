const std = @import("std");
const Input = @import("input/Input.zig");
const SheetRenderer = @import("render/SheetRenderer.zig");
const Sheet = @import("sheets/Sheet.zig");
const Cell = @import("sheets/Cell.zig");
const common = @import("common.zig");
const Screen = @import("render/Screen.zig");
const String = @import("string/String.zig");

const posix = std.posix;

const Term = @This();

tty: std.fs.File,
raw_termios: posix.termios = undefined,
orig_termios: posix.termios = undefined,
uncooked: bool = false,
render_screen: ?Screen = null,
input: Input,

pub fn init() !Term {
    const tty = try std.fs.cwd().openFile("/dev/tty", .{ .mode = .read_write });
    try posix.sigaction(posix.SIG.WINCH, &posix.Sigaction{
        .handler = .{ .handler = handleSigWinch },
        .mask = 0,
        .flags = 0,
    }, null);
    var result = Term{
        .tty = tty,
        .input = Input{ .reader = tty.reader() },
    };
    try result.uncook();
    return result;
}

pub fn deinit(self: *Term) void {
    self.cook() catch {};
    self.tty.close();
}

fn cook(self: *Term) !void {
    if (!self.uncooked) return;
    defer self.uncooked = false;

    try posix.tcsetattr(self.tty.handle, .FLUSH, self.orig_termios);
}

fn uncook(self: *Term) !void {
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

/// create a screen buffer bound to this term.
/// memory is owned by the caller.
/// must be deinitialized separately, before calling this term's deinit().
/// if a screen has already been created, returns that screen
pub fn screen(self: *const Term, allocator: std.mem.Allocator) *Screen {
    if (self.render_screen == null) {
        @constCast(self).render_screen = Screen.init(
            self.tty.writer(),
            allocator,
            self.getSize() catch @panic("failed to get size"),
        ) catch @panic("Out of memory");
    }
    return @constCast(&self.render_screen.?);
}

var winch: bool = false;

pub fn flush(self: *const Term) !void {
    var scr = self.render_screen orelse return;

    try scr.flush();
    if (winch) {
        try scr.resize(try self.getSize());
        winch = false;
    }
}

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
