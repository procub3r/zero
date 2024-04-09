const std = @import("std");
const fs = @import("fs.zig");
const md = @import("md.zig");

pub fn render(alloc: std.mem.Allocator, source_dir: std.fs.Dir, source_path: std.fs.Dir.Walker.WalkerEntry) !void {
    // determine path to the post rendered from the source file
    const post_path = try std.mem.concat(alloc, u8, &.{ source_path.path[0 .. source_path.path.len - 2], "html" });
    std.log.info("rendering post {s}", .{post_path});

    // create the post file if it doesn't exist, and open it for writing
    const post_file = try fs.createFileMakePath(post_path);
    defer post_file.close();

    // create a buffered writer to write to the post file
    var post_writer = std.io.bufferedWriter(post_file.writer());
    defer post_writer.flush() catch std.log.err("couldn't flush buffer to post file", .{});

    // read the source from the source file
    const source = try fs.readFile(alloc, source_dir, source_path.path);

    // render the raw md from source to post for debug purposes
    try md.toHtml(post_writer, source);

    std.log.info(" rendered post {s}\n", .{post_path});
}
