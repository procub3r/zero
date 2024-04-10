const std = @import("std");
const fs = @import("fs.zig");
const md = @import("md.zig");
const common = @import("common.zig");

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
    var source = try fs.readFile(alloc, source_dir, source_path.path);

    // parse metadata
    const metadata = try alloc.create(common.PostMetadata);
    source = parseMetadata(alloc, metadata, source) catch return;

    // print metadata for debugging
    var metadata_iter = metadata.iterator();
    while (metadata_iter.next()) |entry| {
        std.log.info("{s}:\t{s}", .{ entry.key_ptr.*, entry.value_ptr.* });
    }

    // render the raw md from source to post for debug purposes
    try md.toHtml(post_writer, source);

    std.log.info(" rendered post {s}\n", .{post_path});
}

// populate metadata and return the source with the frontmatter stripped away
inline fn parseMetadata(alloc: std.mem.Allocator, metadata: *common.PostMetadata, source: []const u8) ![]const u8 {
    errdefer std.log.err("incorrect frontmatter formatting. post not rendered", .{});
    metadata.* = common.PostMetadata.init(alloc);

    // parse frontmatter
    const begin = "---\n";
    const end = "---\n\n";
    if (!std.mem.startsWith(u8, source, begin)) return error.IncorrectFrontmatterFormat;
    const end_index = std.mem.indexOf(u8, source, end) orelse return error.IncorrectFrontmatterFormat;

    // loop through all key: val pairs and put them in metadata
    var line_iter = std.mem.splitScalar(u8, source[begin.len..end_index], '\n');
    while (line_iter.next()) |line| {
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
        const key = std.mem.trim(u8, line[0..colon], " \t");
        const value = std.mem.trim(u8, line[colon + 1 ..], " \t");
        try metadata.put(key, value);
    }

    // add default values
    if (!metadata.contains("title")) try metadata.put("title", "Untitled Post");
    return source[end_index + end.len ..]; // return raw source without frontmatter
}
