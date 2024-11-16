const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zero",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);

    exe.linkLibC();
    exe.addIncludePath(b.path("md4c/src"));
    exe.addCSourceFiles(.{ .files = &.{
        "md4c/src/md4c.c",
        "md4c/src/entity.c",
        "md4c/src/md4c-html.c",
    } });

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run zero");
    run_step.dependOn(&run_cmd.step);
}
