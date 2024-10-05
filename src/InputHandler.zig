const std = @import("std");
const Input = @import("input/Input.zig");
const Key = @import("input/Key.zig");
const Sheet = @import("sheets/Sheet.zig");
const Cell = @import("sheets/Cell.zig");
const String = @import("string/String.zig");
const InputHandler = @This();

input: *Input,
sheet: *Sheet,

clipboard: ?String = null,
allocator: std.mem.Allocator,

pub fn deinit(self: *InputHandler) void {
    if (self.clipboard) |*cb| cb.deinit(self.allocator);
    self.* = undefined;
}

pub const Error = error{Quit};

pub fn tick(self: *InputHandler) !void {
    while (self.input.next() catch return) |key| {
        if (self.sheet.mode == .insert) {
            if (key.codepoint == .escape) {
                self.sheet.commit();
                self.sheet.mode = .normal;
            } else {
                try self.sheet.onInput(key);
            }
        } else switch (key.codepoint) {
            .arrow_left, .h => self.sheet.current -|= .{ 0, 1 },
            .arrow_down, .j => self.sheet.current += .{ 1, 0 },
            .arrow_up, .k => self.sheet.current -|= .{ 1, 0 },
            .arrow_right, .l => self.sheet.current += .{ 0, 1 },
            .i => {
                self.sheet.mode = .insert;
            },
            .x => {
                const str = try self.sheet.yank(self.allocator);
                self.sheet.clearSelection();
                self.sheet.commit();

                if (self.clipboard) |*cb| {
                    cb.deinit(self.allocator);
                }
                self.clipboard = str;
            },
            .y => {
                const str = try self.sheet.yank(self.allocator);
                if (self.clipboard) |*cb| {
                    cb.deinit(self.allocator);
                }
                self.clipboard = str;
            },
            .p => {
                if (self.clipboard) |cb| {
                    var cell: *Cell = self.sheet.currentCell();
                    cell.input.clearAndFree(self.sheet.allocator);
                    try cell.input.appendSlice(self.sheet.allocator, cb.bytes);
                    self.sheet.commit();
                }
            },
            .equal => {
                var cell: *Cell = self.sheet.currentCell();
                cell.input.clearAndFree(self.sheet.allocator);
                try cell.input.append(self.sheet.allocator, '=');
                self.sheet.mode = .insert;
            },
            .q => return Error.Quit,
            else => {},
        }
    }
}
