const std = @import("std");
const post = @import("post.zig");

const SOURCE_DIR = "source/";
const OUT_DIR = "out/";

pub fn main() !void {
    // // create an arena allocator. all memory will be freed at the end
    // var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // defer arena.deinit();
    // const alloc = arena.allocator();

    // create a general purpose allocator for debug purposes
    var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 30 }){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const alloc = gpa.allocator();

    // all posts are stored in this post array
    var posts = try std.ArrayList(post.Post).initCapacity(alloc, 32);
    defer deletePosts(posts);

    // open source directory
    var source_dir = try std.fs.cwd().openDir(SOURCE_DIR, .{ .iterate = true });
    defer source_dir.close();

    // iterate through the source directory
    var source_walker = try source_dir.walk(alloc);
    defer source_walker.deinit();
    while (try source_walker.next()) |f| {
        // render only markdown files
        if (f.kind != .file or !std.mem.endsWith(u8, f.basename, ".md")) continue;
        std.log.info("rendering {s}", .{f.path});

        // open the source file
        const source_file = try f.dir.openFile(f.basename, .{});
        defer source_file.close();

        // construct out file path and open it
        const out_path = try std.mem.concat(alloc, u8, &.{
            OUT_DIR, "/", f.path[0 .. f.path.len - 2], "html",
        });
        defer alloc.free(out_path);
        const out_file = try createMakePath(out_path);
        defer out_file.close();

        // create a post
        var p = try post.Post.init(alloc, out_file, source_file);
        try posts.append(p); // append post to posts array
        try p.render(alloc); // render the post
    }
}

// create a file, make the necessary directories
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

// delete all the posts in the post array
fn deletePosts(posts: std.ArrayList(post.Post)) void {
    for (posts.items) |*p| {
        p.data.deinit(); // deinit the data hashmap
        p.source.deinit(); // deinit the source arraylist
    }
    posts.deinit(); // deinit the posts array itself
}
