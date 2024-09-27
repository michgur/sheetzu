const std = @import("std");

// run: zig build
pub fn build(b: *std.Build) void {
    const exe_opts = std.Build.ExecutableOptions{
        .name = "sheetzu",
        .root_source_file = b.path("main.zig"),
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
        .version = .{ .major = 0, .minor = 0, .patch = 1 },
    };
    const exe = b.addExecutable(exe_opts);
    exe.addIncludePath(b.path("."));

    const install = b.addInstallArtifact(exe, .{});
    install.step.dependOn(&exe.step);
    install.dest_dir = .{ .custom = ".." };
    b.default_step.dependOn(&install.step);

    // "check" step
    const exe_check = b.addExecutable(exe_opts);
    const check = b.step("check", "Check if foo compiles");
    check.dependOn(&exe_check.step);
}
