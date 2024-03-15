const std = @import("std");
const post = @import("post.zig");

// markdown source of the site
const SOURCE_DIR = "src/";

pub fn main() !void {
    // create an arena allocator. all memory will be freed at the end of the program
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    // open the source directory for walking through all the source files
    var source_dir = std.fs.cwd().openDir(SOURCE_DIR, .{ .iterate = true }) catch {
        std.log.err("couldn't open {s} for iterating", .{SOURCE_DIR});
        return;
    };
    defer source_dir.close();

    // walk through the source files
    var source_walker = try source_dir.walk(alloc);
    defer source_walker.deinit();
    while (try source_walker.next()) |f| {
        // only work with markdown files
        if (f.kind != .file or !std.mem.endsWith(u8, f.path, ".md")) continue;
        const source_path = f.path;

        // the post file path has a .html extension and is relative to the site root whereas
        // the source file path has a .md extension and is relative to SOURCE_DIR.
        const post_path = try std.mem.concat(alloc, u8, &.{ source_path[0 .. source_path.len - 2], "html" });

        // render a post file from the source file
        std.log.info("rendering post {s}", .{post_path});
        post.render(alloc, post_path, source_dir, source_path) catch {
            std.log.err("couldn't render post", .{});
        };
    }
}
