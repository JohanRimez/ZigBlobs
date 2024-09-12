// ZIG GENERIC BUILD SCRIPT for SDL2 - projects
// JohanRimez

const programName = "ZigBlobs";
const mainEntry = "BlobsMain.zig";

// To compile for linux on a windows machine: add libSD2.a & libSDL2.so to the project root

// Up till the moment the "Linux Native Build bug" (https://github.com/ziglang/zig/issues/21376) is fixed, compilation in Linux requires
// the explicit target parameter

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
        .name = programName,
        .root_source_file = b.path("src/" ++ mainEntry),
        .target = target,
        .optimize = optimize,
    });

    exe.addIncludePath(.{ .cwd_relative = "src/" });
    switch (target.result.os.tag) {
        .windows => {
            exe.addIncludePath(.{ .cwd_relative = "C:/Users/Public/Includes/SDL2/include/" });
            exe.addLibraryPath(.{ .cwd_relative = "C:/Users/Public/Includes/SDL2/lib/x64/" });
            exe.subsystem = .Windows;
        },
        .linux => {
            switch (b.host.result.os.tag) {
                .linux => {
                    exe.addIncludePath(.{ .cwd_relative = "/usr/include" });
                    exe.addIncludePath(.{ .cwd_relative = "/usr/include/x86_64-linux-gnu" });
                    exe.addLibraryPath(.{ .cwd_relative = "/usr/lib/x86_64-linux-gnu" });
                },
                .windows => exe.addLibraryPath(.{ .cwd_relative = "." }),
                else => @panic("This type of compilation has not been implemented"),
            }
        },
        else => @panic("Build only configured for Windows & Linux"),
    }
    exe.linkLibC();
    exe.linkSystemLibrary("SDL2");
    b.installArtifact(exe);

    // direct build-run action
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}