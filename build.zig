const std = @import("std");

// run: zig build
pub fn build(b: *std.Build) void {
    const exe_opts = std.Build.ExecutableOptions{
        .name = "sheetzu",
        .root_source_file = b.path("src/main.zig"),
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
    const check_exe = b.addExecutable(exe_opts);
    const check_step = b.step("check", "Check if foo compiles");
    check_step.dependOn(&check_exe.step);

    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/tester.zig"),
    });
    unit_tests.addIncludePath(b.path("."));
    const test_exe = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&test_exe.step);

    // run step
    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_exe.step);
}
