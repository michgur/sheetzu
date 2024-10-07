const std = @import("std");
const SheetRenderer = @import("render/SheetRenderer.zig");
const Sheet = @import("sheets/Sheet.zig");
const Cell = @import("sheets/Cell.zig");
const Screen = @import("render/Screen.zig");
const common = @import("common.zig");
const String = @import("string/String.zig");
const Term = @import("Term.zig");
const InputHandler = @import("InputHandler.zig");

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

    var input_handler = InputHandler{
        .allocator = allocator,
        .input = &term.input,
        .sheet = &sht,
    };
    defer input_handler.deinit();

    const fps = 60;
    const npf: u64 = 1_000_000_000 / fps; // nanos per frame (more or less...)

    var then = std.time.nanoTimestamp();
    while (true) {
        const now = std.time.nanoTimestamp();
        const dt: u64 = @intCast(@as(i64, @truncate(now - then)));
        if (dt < npf) {
            std.time.sleep(dt);
        }
        then = now;

        try renderer.render(&sht, &input_handler);
        try term.flush();

        input_handler.tick() catch |err| {
            if (err == InputHandler.Error.Quit) break;
            return err;
        };
    }
}
