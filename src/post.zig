const std = @import("std");
const fs = @import("fs.zig");
const md = @import("md.zig");

pub fn render(alloc: std.mem.Allocator, source_dir: std.fs.Dir, source_path: std.fs.Dir.Walker.WalkerEntry) !void {
    // determine path to the post rendered from the source file
    var post_dir_path = source_path.path[0 .. source_path.path.len - source_path.basename.len];
    post_dir_path = if (post_dir_path.len != 0) post_dir_path else "./"; // set to cwd if it's empty
    const post_path = try std.mem.concat(alloc, u8, &.{ source_path.basename[0 .. source_path.basename.len - 2], "html" });
    std.log.info("rendering post {s}{s}", .{ post_dir_path, post_path });

    // create the post directory if it doesn't exist, and open it
    var post_dir = try std.fs.cwd().makeOpenPath(post_dir_path, .{});
    defer post_dir.close();

    // create the post file if it doesn't exist, and open it for writing
    const post_file = post_dir.createFile(post_path, .{}) catch {
        std.log.err("couldn't open file {s}{s} for writing", .{ post_dir_path, post_path });
        return;
    };
    defer post_file.close();

    // create a buffered writer to write to the post file
    var post_writer = std.io.bufferedWriter(post_file.writer());
    defer post_writer.flush() catch std.log.err("couldn't flush buffer to post file", .{});

    // read the source from the source file
    const source = try fs.readFile(alloc, source_dir, source_path.path);

    // render the raw md from source to post for debug purposes
    try md.toHtml(post_writer, source);

    std.log.info(" rendered post {s}{s}\n", .{ post_dir_path, post_path });
}
