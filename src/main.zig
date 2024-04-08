const std = @import("std");
const fs = @import("fs.zig");
const md = @import("md.zig");
const post = @import("post.zig");
const config = @import("config.zig");

pub fn main() !void {
    // create an arena allocator. all memory will be freed at the end of the program
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    // open the source directory
    var source_dir = std.fs.cwd().openDir(config.CONTENT_DIR, .{ .iterate = true }) catch {
        std.log.err("source directory {s} not found.", .{config.CONTENT_DIR});
        return;
    };
    defer source_dir.close();

    // walk through the source files
    var source_walker = try source_dir.walk(alloc);
    defer source_walker.deinit();

    while (try source_walker.next()) |file| {
        // only work with markdown files
        if (file.kind != .file or !std.mem.endsWith(u8, file.path, ".md")) continue;
        try post.render(alloc, source_dir, file);
    }
}
