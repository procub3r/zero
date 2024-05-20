const std = @import("std");

pub fn build(b: *std.Build) void {
    // use standard target and optimization options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zero",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // link md4c
    exe.linkLibC(); // md4c needs a libc
    exe.addIncludePath(b.path("deps/md4c/src"));
    exe.addCSourceFiles(.{ .files = &.{
        "deps/md4c/src/md4c.c",
        "deps/md4c/src/entity.c",
        "deps/md4c/src/md4c-html.c",
    } });

    // install zero after building it
    b.installArtifact(exe);
}
