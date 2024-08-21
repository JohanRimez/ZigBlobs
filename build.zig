const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "ZigRipples",
        .root_source_file = b.path("src/ZigBlobs.zig"),
        .target = target,
        .optimize = optimize,
    });
    // SDL2
    exe.addIncludePath(.{ .cwd_relative = "C:/Users/Public/Includes/SDL2/include/" });
    exe.addLibraryPath(.{ .cwd_relative = "C:/Users/Public/Includes/SDL2/lib/x64/" });
    exe.linkSystemLibrary("SDL2");
    exe.linkLibC();

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
