const std = @import("std");
const Input = @import("input/Input.zig");
const Key = @import("input/Key.zig");
const Sheet = @import("sheets/Sheet.zig");
const Cell = @import("sheets/Cell.zig");
const String = @import("string/String.zig");
const AST = @import("formula/AST.zig");
const common = @import("common.zig");
const InputHandler = @This();

input: *Input,
sheet: *Sheet,
allocator: std.mem.Allocator,

clipboard: ?AST = null,
current: common.upos = .{ 0, 0 },
mode: enum {
    normal,
    insert,
} = .normal,
formula: ?FormulaInput = null,

pub fn deinit(self: *InputHandler) void {
    if (self.clipboard) |*cb| cb.deinit(self.allocator);
    self.* = undefined;
}

pub const Error = error{Quit};

pub fn tick(self: *InputHandler) !void {
    while (self.input.next() catch return) |key| {
        if (self.mode == .insert) {
            if (key.code == .escape or key.code == .enter) {
                try self.leaveInsertMode();
            } else {
                try self.insertMode(key);
            }
        } else try self.normalMode(key);
    }
}

pub fn insertMode(self: *InputHandler, key: Key) !void {
    std.debug.assert(self.formula != null);
    var formula = &(self.formula orelse unreachable);
    switch (key.code) {
        .backspace => formula.backspace(),
        .arrow_left, .alt_h => formula.moveRef(self, .{ 0, -1 }),
        .arrow_down, .alt_j => formula.moveRef(self, .{ 1, 0 }),
        .arrow_up, .alt_k => formula.moveRef(self, .{ -1, 0 }),
        .arrow_right, .alt_l => formula.moveRef(self, .{ 0, 1 }),
        else => try formula.append(key.bytes),
    }
}

fn enterInsertMode(self: *InputHandler) !void {
    self.mode = .insert;

    if (self.formula) |*f| f.deinit();
    self.formula = FormulaInput.init(self.allocator, self.currentCell().input.items);
}
fn leaveInsertMode(self: *InputHandler) !void {
    if (self.formula) |*f| {
        const value = f.preview(self.allocator);
        defer {
            self.allocator.free(value);
            f.deinit();
            self.formula = null;
        }
        var c = self.currentCell();
        c.dirty = true;
        c.input.clearRetainingCapacity();
        try c.input.appendSlice(self.sheet.allocator, value);
        self.sheet.commit(self.current) orelse unreachable;
    }
    self.mode = .normal;
}

pub fn normalMode(self: *InputHandler, key: Key) !void {
    switch (key.code) {
        .arrow_left, .h => self.current -|= .{ 0, 1 },
        .arrow_down, .j => self.current += .{ 1, 0 },
        .arrow_up, .k => self.current -|= .{ 1, 0 },
        .arrow_right, .l => self.current += .{ 0, 1 },
        .i => try self.enterInsertMode(),
        .x => {
            const ast = try self.currentCell().ast.clone(self.allocator);
            self.sheet.clearAndCommit(self.current) orelse unreachable;

            if (self.clipboard) |*cb| {
                cb.deinit(self.allocator);
            }
            self.clipboard = ast;
        },
        .y => {
            const ast = try self.currentCell().ast.clone(self.allocator);
            if (self.clipboard) |*cb| {
                cb.deinit(self.allocator);
            }
            self.clipboard = ast;
        },
        .p => {
            if (self.clipboard) |cb| {
                var cell = self.currentCell();
                // cell.input.clearAndFree(self.sheet.allocator);
                // try cell.input.appendSlice(self.sheet.allocator, cb.bytes);
                // self.sheet.commit(self.current) orelse unreachable;
                cell.ast = try cb.clone(self.sheet.allocator);
            }
        },
        .equal => {
            try self.enterInsertMode();
            try self.insertMode(key);
        },
        .q => return Error.Quit,
        else => {},
    }
    self.current = @min(self.current, self.sheet.size - common.upos{ 1, 1 });
}

pub fn currentCell(self: *const InputHandler) *Cell {
    std.debug.assert(@reduce(.And, self.current < self.sheet.size));
    return self.sheet.cell(self.current) orelse unreachable;
}

pub fn currentCellPreview(self: *const InputHandler, allocator: std.mem.Allocator) []const u8 {
    if (self.mode == .insert) return self.formula.?.preview(allocator);
    const result = self.currentCell().input.clone(allocator) catch @panic("Out of memory");
    return result.items;
}

const FormulaInput = struct {
    bytes: std.ArrayList(u8),
    ref: ?common.upos,

    pub fn init(allocator: std.mem.Allocator, bytes: []const u8) FormulaInput {
        var b = std.ArrayList(u8).initCapacity(allocator, bytes.len) catch @panic("Out of memory");
        b.appendSlice(bytes) catch unreachable;
        return .{
            .bytes = b,
            .ref = null,
        };
    }

    pub fn deinit(self: *FormulaInput) void {
        self.bytes.deinit();
        self.* = undefined;
    }

    pub fn preview(self: *const FormulaInput, allocator: std.mem.Allocator) []const u8 {
        if (self.ref) |ref| {
            var buf: [256]u8 = undefined;
            const ref_bytes = refToBytes(ref, &buf);
            const result = allocator.alloc(u8, self.bytes.items.len + ref_bytes.len) catch @panic("Out of memory");
            return std.fmt.bufPrint(result, "{s}{s}", .{ self.bytes.items, ref_bytes }) catch unreachable;
        } else {
            const result = allocator.alloc(u8, self.bytes.items.len) catch @panic("Out of memory");
            @memcpy(result, self.bytes.items);
            return result;
        }
    }

    pub fn backspace(self: *FormulaInput) void {
        if (self.ref) |_| {
            self.ref = null;
        } else {
            _ = self.bytes.popOrNull();
        }
    }

    pub fn moveRef(self: *FormulaInput, state: *const InputHandler, move: common.ipos) void {
        if (self.ref == null) {
            if (self.bytes.items.len < 1 or self.bytes.items[0] != '=') return;
            self.ref = state.current;
        }
        const ref = common.posCast(self.ref.?) + move;
        self.ref = @max(ref, common.ipos{ 0, 0 });
        self.ref = @min(self.ref.?, state.sheet.size - common.upos{ 1, 1 });
    }

    pub fn append(self: *FormulaInput, bytes: []const u8) !void {
        if (self.ref) |ref| {
            var buf: [256]u8 = undefined;
            try self.bytes.appendSlice(refToBytes(ref, &buf));
            self.ref = null;
        }
        try self.bytes.appendSlice(bytes);
    }
};

fn refToBytes(ref: common.upos, buf: []u8) []const u8 {
    const letters = common.bb26(ref[1], buf);
    std.mem.copyForwards(u8, buf, letters); // copy to beginning of buf (TODO this should be the default behavior)
    const numbers = std.fmt.bufPrintIntToSlice(buf[letters.len..], ref[0] + 1, 10, .lower, .{});
    return buf[0 .. letters.len + numbers.len];
}
