const std = @import("std");
const SheetRenderer = @import("render/SheetRenderer.zig");
const Sheet = @import("sheets/Sheet.zig");
const Cell = @import("sheets/Cell.zig");
const Screen = @import("render/Screen.zig");
const common = @import("common.zig");
const String = @import("string/String.zig");
const Term = @import("Term.zig");

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
    defer term.deinit();

    const screen = term.screen(allocator);
    defer screen.deinit();

    var sht = try Sheet.init(allocator, .{ 60, 100 });
    defer sht.deinit();

    var clipboard: ?String = null;
    defer if (clipboard) |*cb| cb.deinit(allocator);

    var renderer = SheetRenderer{ .screen = screen };

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

        try renderer.render(&sht);
        try term.flush();

        while (term.input.next() catch continue :outer) |key| {
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
                    .j => sht.current += .{ 1, 0 },
                    .k => sht.current -|= .{ 1, 0 },
                    .l => sht.current += .{ 0, 1 },
                    .i => {
                        sht.mode = .insert;
                    },
                    .x => {
                        const str = try sht.yank(allocator);
                        sht.clearSelection();
                        sht.commit();

                        if (clipboard) |*cb| {
                            cb.deinit(allocator);
                        }
                        clipboard = str;
                    },
                    .y => {
                        const str = try sht.yank(allocator);
                        if (clipboard) |*cb| {
                            cb.deinit(allocator);
                        }
                        clipboard = str;
                    },
                    .p => {
                        if (clipboard) |cb| {
                            var cell: *Cell = sht.currentCell();
                            cell.input.clearAndFree(sht.allocator);
                            try cell.input.appendSlice(sht.allocator, cb.bytes);
                            sht.commit();
                        }
                    },
                    .equal => {
                        var cell: *Cell = sht.currentCell();
                        cell.input.clearAndFree(sht.allocator);
                        try cell.input.append(sht.allocator, '=');
                        sht.mode = .insert;
                    },
                    .q => break :outer,
                    else => {},
                }
                sht.current = @min(sht.current, common.upos{ sht.rows.len - 1, sht.cols.len - 1 });
            }
        }
    }
}
