const std = @import("std");
const md = @import("md.zig");

pub fn render(alloc: std.mem.Allocator, post_path: []const u8, source_dir: std.fs.Dir, source_path: []const u8) !void {
    // open the post file for writing
    const post_file = std.fs.cwd().createFile(post_path, .{}) catch |err| {
        std.log.err("couldn't open file {s} for writing", .{post_path});
        return err;
    };
    defer post_file.close();

    // create a buffered writer to write the post
    var post_writer_buffered = std.io.bufferedWriter(post_file.writer());

    // open the source file and read its contents
    const source = try readSource(alloc, source_dir, source_path);

    // parse metadata from the frontmatter
    const frontmatter_end = try getFrontmatterEnd(source);
    const frontmatter = source[4..frontmatter_end];
    var metadata = try parseMetadata(alloc, frontmatter);
    defer metadata.deinit();

    // print metadata for debug purposes
    var metadata_iter = metadata.iterator();
    while (metadata_iter.next()) |entry| {
        std.debug.print("{s}:\t{s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
    }

    const source_md = source[frontmatter_end + 6 ..];
    try md.parse(post_writer_buffered.writer(), source_md);
    try post_writer_buffered.flush();
}

// simple key: value pair parser
fn parseMetadata(alloc: std.mem.Allocator, frontmatter: []const u8) !std.StringHashMap([]const u8) {
    var metadata = std.StringHashMap([]const u8).init(alloc);

    // loop through all lines
    var line_iter = std.mem.splitScalar(u8, frontmatter, '\n');
    while (line_iter.next()) |line| {
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
        const key = std.mem.trim(u8, line[0..colon], " ");
        const value = std.mem.trim(u8, line[colon + 1 ..], " ");

        // put the key: value pair into the metadata hashmap
        try metadata.put(key, value);
    }

    return metadata;
}

fn getFrontmatterEnd(source: []const u8) !usize {
    const err = error.IncorrectFormat;
    errdefer std.log.err("incorrect frontmatter format", .{});

    // all source files must start with a ---\n and
    // the frontmatter must end with a \n---\n\n
    if (!std.mem.startsWith(u8, source, "---\n")) return err;
    const end = std.mem.indexOf(u8, source, "\n---\n\n") orelse return err;
    return end;
}

fn readSource(alloc: std.mem.Allocator, source_dir: std.fs.Dir, source_path: []const u8) ![]const u8 {
    const source_file = source_dir.openFile(source_path, .{ .mode = .read_only }) catch |err| {
        std.log.err("couldn't open file SOURCE_DIR/{s} for reading", .{source_path});
        return err;
    };
    defer source_file.close();

    // cap the file size at 1MiB
    const source = source_file.readToEndAlloc(alloc, 1024 * 1024) catch |err| {
        std.log.err("[{}] {s}", .{ err, source_path });
        return err;
    };

    return source;
}
