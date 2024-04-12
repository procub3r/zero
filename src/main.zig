const std = @import("std");
const fs = @import("fs.zig");
const md = @import("md.zig");
const post = @import("post.zig");
const common = @import("common.zig");

pub fn main() !void {
    // create an arena allocator. all memory will be freed at the end of the program
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    // initialize the layout map
    common.layout_map = @TypeOf(common.layout_map).init(alloc);
    defer common.layout_map.deinit();

    // initialize the tag map
    common.tag_map = @TypeOf(common.tag_map).init(alloc);
    defer common.tag_map.deinit();

    // open the source directory
    var source_dir = std.fs.cwd().openDir(common.SOURCE_DIR, .{ .iterate = true }) catch {
        std.log.err("source directory {s} not found.", .{common.SOURCE_DIR});
        return;
    };
    defer source_dir.close();

    // walk through the source files
    var source_walker = try source_dir.walk(alloc);
    defer source_walker.deinit();

    while (try source_walker.next()) |file| {
        // only work with markdown files
        if (file.kind != .file or !std.mem.endsWith(u8, file.path, ".md")) continue;
        post.render(alloc, source_dir, file) catch std.log.err("post not rendered\n", .{});
    }

    // render all tag pages
    var tag_map_iter = common.tag_map.iterator();
    while (tag_map_iter.next()) |entry| {
        const tag = entry.key_ptr.*;
        const tag_path = try std.mem.concat(alloc, u8, &.{ common.TAG_PAGES_DIR, tag, ".html" });
        std.log.info("rendering tag file {s}", .{tag_path});

        // create the tag file if it doesn't exist, and open it for writing
        const tag_file = try fs.createFileMakePath(tag_path);
        defer tag_file.close();

        // create a buffered writer to write to the post file.
        // the buffer size is SO over the top but who cares :D
        var tag_writer = std.io.BufferedWriter(16 * 4096, @TypeOf(tag_file.writer())){
            .unbuffered_writer = tag_file.writer(),
        };
        defer tag_writer.flush() catch std.log.err("couldn't flush buffer to tag file", .{});

        // write post metadata to the tag file
        const posts = entry.value_ptr.items;
        for (posts) |p| {
            try std.fmt.format(tag_writer.writer(),
                \\<h2><a href="/{s}">{s}</a></h2>
                \\<p>{s}</p>
                \\
            , .{
                p.get("path") orelse "",
                p.get("title") orelse "",
                p.get("desc") orelse "",
            });
            std.log.info("\t{?s}, ", .{p.get("title")});
        }
    }
}
