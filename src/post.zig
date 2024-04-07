const std = @import("std");
const md = @import("md.zig");
const common = @import("common.zig");
const layouts = @import("layouts.zig");

pub fn renderFromSourceFile(
    alloc: std.mem.Allocator,
    post_path: []const u8,
    source_dir: std.fs.Dir,
    source_path: []const u8,
) !void {
    // open the post file for writing
    const post_file = std.fs.cwd().createFile(post_path, .{}) catch |err| {
        std.log.err("couldn't open file {s} for writing", .{post_path});
        return err;
    };
    defer post_file.close();

    // create a buffered writer to write the post
    var post_writer_buffered = std.io.bufferedWriter(post_file.writer());

    // open the source file and read its contents
    const source = try common.readFile(alloc, source_dir, source_path);
    // don't free source as parts of it will be used to render
    // a post description in the tags page.

    // render the post
    try render(alloc, &post_writer_buffered, source);
    try post_writer_buffered.flush();
}

pub fn render(
    alloc: std.mem.Allocator,
    post_writer: anytype,
    source: []const u8,
) !void {
    // determine the bounds of the frontmatter and source markdown
    const frontmatter_end = try getFrontmatterEnd(source);
    const frontmatter = source[4..frontmatter_end];
    const source_md = source[frontmatter_end + 6 ..];

    // parse metadata from the frontmatter
    var metadata = try parseMetadata(alloc, frontmatter);
    defer metadata.deinit();

    // get the name of the layout from the metadata
    const layout_name = metadata.get("layout") orelse blk: {
        std.log.warn("layout field not set. defaulting to {s}", .{layouts.DEFAULT_LAYOUT});
        break :blk layouts.DEFAULT_LAYOUT;
    };
    std.log.info("using layout {s}", .{layout_name});

    // replace all variables in the layout and write it to the post file
    try layouts.renderLayout(alloc, post_writer, layout_name, metadata, source_md);
}

// simple key: value pair parser
fn parseMetadata(alloc: std.mem.Allocator, frontmatter: []const u8) !std.StringHashMap([]const u8) {
    var metadata = std.StringHashMap([]const u8).init(alloc);

    // loop through all lines
    var line_iter = std.mem.splitScalar(u8, frontmatter, '\n');
    while (line_iter.next()) |line| {
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
        const key = std.mem.trim(u8, line[0..colon], " \t");
        const value = std.mem.trim(u8, line[colon + 1 ..], " \t");

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
