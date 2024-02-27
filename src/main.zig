const std = @import("std");
const post = @import("post.zig");

// all .md files reside here
const SRC_DIR = "src";

pub fn main() !void {
    // create an arena allocator. all memory will be freed at the end of the program
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    // open the src dir for iterating
    var src_dir = std.fs.cwd().openDir(SRC_DIR, .{ .iterate = true }) catch {
        std.debug.print("error: couldn't open {s}/\n", .{SRC_DIR});
        return;
    };
    defer src_dir.close();

    // iterate ("walk") through the src dir
    var src_walker = try src_dir.walk(alloc);
    defer src_walker.deinit();
    while (try src_walker.next()) |f| {
        // only work with files that have a .md extension
        if (f.kind != .file) continue;
        if (!std.mem.endsWith(u8, f.path, ".md")) continue;

        // replace .md with .html to obtain the name of the post
        const post_name = try std.mem.concat(alloc, u8, &.{ f.path[0 .. f.path.len - 2], "html" });
        // open the post file for writing. create it if it doesn't already exist
        const post_file = std.fs.cwd().createFile(post_name, .{}) catch {
            std.debug.print("error: couldn't open {s} for writing\n", .{post_name});
            continue;
        };
        defer post_file.close();

        // open the source file and read its contents
        const src_file = try src_dir.openFile(f.path, .{ .mode = .read_only });
        defer src_file.close();
        const src = try src_file.readToEndAlloc(alloc, 1024 * 1024);

        // create a buffered writer to write to the post file
        var post_file_buffered = std.io.bufferedWriter(post_file.writer());

        // render the markdown from the source into a html post, write it to the post file
        std.debug.print("rendering {s}/{s} -> {s}\n", .{ SRC_DIR, f.path, post_name });
        try post.render(post_file_buffered.writer(), src);
        try post_file_buffered.flush();
    }
}
