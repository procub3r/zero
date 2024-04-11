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
}
