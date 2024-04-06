const std = @import("std");

pub fn readFile(alloc: std.mem.Allocator, dir: std.fs.Dir, path: []const u8) ![]const u8 {
    const file = dir.openFile(path, .{ .mode = .read_only }) catch |err| {
        std.log.err("couldn't open file {s} for reading", .{path});
        return err;
    };
    defer file.close();

    // cap the file size at 1MiB
    const content = file.readToEndAlloc(alloc, 1024 * 1024) catch |err| {
        std.log.err("[{}] {s}", .{ err, path });
        return err;
    };

    return content;
}
