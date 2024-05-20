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
    defer deletePosts(alloc, posts);

    var layout_map = std.StringHashMap([]const u8).init(alloc);
    defer deleteLayoutMap(alloc, &layout_map);

    // open source directory
    var source_dir = try std.fs.cwd().openDir(SOURCE_DIR, .{ .iterate = true });
    defer source_dir.close();

    // iterate through the source directory
    var source_walker = try source_dir.walk(alloc);
    defer source_walker.deinit();
    while (try source_walker.next()) |f| {
        // render only markdown files
        if (f.kind != .file or !std.mem.endsWith(u8, f.basename, ".md")) continue;
        std.log.info("rendering " ++ SOURCE_DIR ++ "{s}", .{f.path});

        // open and read from the source file
        const source_file = try f.dir.openFile(f.basename, .{});
        defer source_file.close();
        const source = try source_file.readToEndAlloc(alloc, 1 << 30);
        defer alloc.free(source);

        // construct out file path and open it
        const out_path = try std.mem.concat(alloc, u8, &.{
            OUT_DIR, "/", f.path[0 .. f.path.len - 2], "html",
        });
        defer alloc.free(out_path);
        const out_file = try createMakePath(out_path);
        defer out_file.close();

        // create and render the post
        var p = post.Post.init(alloc);
        post.render(alloc, out_file, &layout_map, &p, source) catch |err| {
            std.debug.print("error: {}\n", .{err});
        };
        try posts.append(p); // append post to the posts array
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
fn deletePosts(alloc: std.mem.Allocator, posts: std.ArrayList(post.Post)) void {
    for (posts.items) |*p| {
        var p_iter = p.valueIterator();
        while (p_iter.next()) |value| {
            alloc.free(value.*); // free hashmap values
        }
        p.deinit(); // deinit the post hashmap
    }
    posts.deinit(); // deinit the posts array itself
}

// delete all the layouts in the layout map
fn deleteLayoutMap(alloc: std.mem.Allocator, layout_map: *std.StringHashMap([]const u8)) void {
    var layout_iter = layout_map.valueIterator();
    while (layout_iter.next()) |layout| {
        alloc.free(layout.*); // free layout slice
    }
    layout_map.deinit(); // deinit the layout map
}
