const std = @import("std");
const post = @import("post.zig");

const SOURCE_DIR = "source/";

pub fn main() !void {
    // // create the allocator
    // var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // defer arena.deinit();
    // const alloc = arena.allocator();

    // create a gpa allocator for testing
    var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 30 }){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const alloc = gpa.allocator();

    // initialize the post array
    post.posts = @TypeOf(post.posts).init(alloc);
    defer {
        // free all posts
        for (post.posts.items) |*p| {
            alloc.free(p.get("source").?);
            p.deinit();
        }
        // deinit the post array
        post.posts.deinit();
    }

    // initialize layout map
    post.layout_map = @TypeOf(post.layout_map).init(alloc);
    defer {
        // free all layouts
        var layout_iter = post.layout_map.valueIterator();
        while (layout_iter.next()) |layout| {
            alloc.free(layout.*);
        }
        // deinit the layout map
        post.layout_map.deinit();
    }

    // open the source directory
    var source_dir = try std.fs.cwd().openDir(SOURCE_DIR, .{ .iterate = true });
    defer source_dir.close();

    // iterate through the source directory
    var source_walker = try source_dir.walk(alloc);
    defer source_walker.deinit();
    while (try source_walker.next()) |f| {
        // only render markdown files
        if (f.kind != .file or !std.mem.endsWith(u8, f.basename, ".md")) continue;
        std.log.info("rendering " ++ SOURCE_DIR ++ "{s}", .{f.path});

        // create a post
        var p = post.Post.init(alloc);
        defer post.posts.append(p) catch std.log.err("couldn't append post to post array", .{});

        // read the source file
        const source = try f.dir.readFileAlloc(alloc, f.basename, 1024 * 1024);
        try p.put("source", source);

        // create the post file
        const post_path = try std.mem.concat(alloc, u8, &.{ f.path[0 .. f.path.len - 2], "html" });
        defer alloc.free(post_path);
        const post_file = try createMakePath(post_path);
        defer post_file.close();

        // create the post writer
        var post_writer = std.io.BufferedWriter(4 * 4096, @TypeOf(post_file.writer())){
            .unbuffered_writer = post_file.writer(),
        };
        defer post_writer.flush() catch std.log.err("couldn't flush to post file", .{});

        // render the post file
        try post.render(alloc, post_writer.writer(), &p);
    }
}

/// create the file if it doesn't exist and open it (for writing by default)
fn createMakePath(file_path: []const u8) !std.fs.File {
    const file = std.fs.cwd().createFile(file_path, .{}) catch mkdir: {
        // if there is an error, it is most likely because the directory doesn't exist.
        // figure out the post directory's name
        const dir_path = std.fs.path.dirname(file_path).?;

        // create the post directory
        try std.fs.cwd().makePath(dir_path);

        // try to create the file again. if it fails, report error and give up
        break :mkdir try std.fs.cwd().createFile(file_path, .{});
    };
    return file;
}
