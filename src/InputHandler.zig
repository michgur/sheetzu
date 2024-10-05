const std = @import("std");
const Input = @import("input/Input.zig");
const Key = @import("input/Key.zig");
const Sheet = @import("sheets/Sheet.zig");
const Cell = @import("sheets/Cell.zig");
const String = @import("string/String.zig");
const common = @import("common.zig");
const InputHandler = @This();

input: *Input,
sheet: *Sheet,
allocator: std.mem.Allocator,

clipboard: ?String = null,
current: common.upos = .{ 0, 0 },
mode: enum {
    normal,
    insert,
} = .normal,

pub fn deinit(self: *InputHandler) void {
    if (self.clipboard) |*cb| cb.deinit(self.allocator);
    self.* = undefined;
}

pub const Error = error{Quit};

pub fn tick(self: *InputHandler) !void {
    while (self.input.next() catch return) |key| {
        if (self.mode == .insert) {
            if (key.codepoint == .escape) {
                self.sheet.commit(self.current) orelse unreachable;
                self.mode = .normal;
            } else {
                try self.insertMode(key);
            }
        } else try self.normalMode(key);
    }
}

pub fn insertMode(self: *InputHandler, input: Key) !void {
    var c = self.currentCell();
    c.dirty = true;
    if (input.codepoint == .backspace) {
        _ = c.input.popOrNull();
    } else {
        try c.input.appendSlice(self.allocator, input.bytes);
    }
}

pub fn normalMode(self: *InputHandler, key: Key) !void {
    switch (key.codepoint) {
        .arrow_left, .h => self.current -|= .{ 0, 1 },
        .arrow_down, .j => self.current += .{ 1, 0 },
        .arrow_up, .k => self.current -|= .{ 1, 0 },
        .arrow_right, .l => self.current += .{ 0, 1 },
        .i => self.mode = .insert,
        .x => {
            const str = try self.currentCell().str.clone(self.allocator);
            self.sheet.clearAndCommit(self.current) orelse unreachable;

            if (self.clipboard) |*cb| {
                cb.deinit(self.allocator);
            }
            self.clipboard = str;
        },
        .y => {
            const str = try self.currentCell().str.clone(self.allocator);
            if (self.clipboard) |*cb| {
                cb.deinit(self.allocator);
            }
            self.clipboard = str;
        },
        .p => {
            if (self.clipboard) |cb| {
                var cell = self.currentCell();
                cell.input.clearAndFree(self.sheet.allocator);
                try cell.input.appendSlice(self.sheet.allocator, cb.bytes);
                self.sheet.commit(self.current) orelse unreachable;
            }
        },
        .equal => {
            var cell = self.currentCell();
            cell.input.clearAndFree(self.sheet.allocator);
            try cell.input.append(self.sheet.allocator, '=');
            self.mode = .insert;
        },
        .q => return Error.Quit,
        else => {},
    }
}

pub fn currentCell(self: *const InputHandler) *Cell {
    std.debug.assert(@reduce(.And, self.current < self.sheet.size));
    return self.sheet.cell(self.current) orelse unreachable;
}
