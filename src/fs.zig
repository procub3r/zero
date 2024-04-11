const std = @import("std");

pub inline fn createFileMakePath(file_path: []const u8) !std.fs.File {
    // print error message on error
    errdefer std.log.err("couldn't create file {s}", .{file_path});

    // create the file if it doesn't exist and open it (for writing by default)
    const file = std.fs.cwd().createFile(file_path, .{}) catch mkdir: {
        // if there is an error, it is most likely because the post directory doesn't exist.
        // figure out the post directory's name
        const dir_path = std.fs.path.dirname(file_path).?;

        // create the post directory
        try std.fs.cwd().makePath(dir_path);

        // try to create the file again. if it fails, report error and give up
        break :mkdir try std.fs.cwd().createFile(file_path, .{});
    };
    return file;
}

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
