const std = @import("std");
const Position = @import("common.zig").ipos;

const Cursor = @This();

pos: Position,
writer: std.fs.File.Writer,

pub fn init(writer: std.fs.File.Writer) Cursor {
    const result = Cursor{
        .pos = Position{ 0, 0 },
        .writer = writer,
    };
    result.writePos() catch {};
    return result;
}

fn writePos(self: *const Cursor) !void {
    try self.writer.print("\x1B[{};{}H", .{
        self.pos[0] + 1,
        self.pos[1] + 1,
    });
}

pub const Movement = enum { rel, abs };
pub fn move(self: *Cursor, pos: Position, comptime movement: Movement) !void {
    const prev = self.pos;
    errdefer self.pos = prev;

    self.pos = if (movement == .abs) pos else self.pos + pos;
    self.pos = @max(self.pos, Position{ 0, 0 });
    try self.writePos();
}

pub fn storePos(self: *const Cursor) !void {
    try self.writer.writeAll("\x1B[s");
}

pub fn restorePos(self: *const Cursor) !void {
    try self.writer.writeAll("\x1B[u");
}

pub fn hide(self: *const Cursor) !void {
    try self.writer.writeAll("\x1B[?25l");
}
pub fn show(self: *const Cursor) !void {
    try self.writer.writeAll("\x1B[?25h");
}
