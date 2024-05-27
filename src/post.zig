const std = @import("std");
const layout = @import("layout.zig");

// Post type. posts are just key: val pairs
pub const Post = std.StringHashMap([]const u8);

// render a post to out file
pub fn render(
    alloc: std.mem.Allocator,
    out: std.fs.File,
    layout_map: *std.StringHashMap([]const u8),
    post: *Post,
    source: []const u8,
) !void {
    // the post will be rendered to out_buf first
    var out_buf = try std.ArrayList(u8).initCapacity(alloc, source.len);
    defer out_buf.deinit();

    // parse frontmatter using a line iterator
    var line_iter = std.mem.splitScalar(u8, source, '\n');

    // the first line must be "---\n"
    const first_line = line_iter.next() orelse return error.IncorrectFormat;
    if (!std.mem.eql(u8, first_line, "---")) return error.IncorrectFormat;

    var frontmatter_len: usize = 4;
    while (line_iter.next()) |line| {
        if (std.mem.eql(u8, line, "---")) break; // frontmatter end
        frontmatter_len += line.len + 1;

        // parse the key and the value
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
        const key = std.mem.trim(u8, line[0..colon], " \t");
        const value_ = std.mem.trim(u8, line[colon + 1 ..], " \t");
        // allocate value because source will be freed (and with it, value_)
        const value = try alloc.dupe(u8, value_);

        // put the key value pair into the post map
        try post.put(key, value);
    }

    // load the layout and render it
    const layout_name = post.get("layout");
    const layout_src = try layout.load(alloc, layout_map, layout_name);
    const source_md = source[frontmatter_len + 4 ..];
    try layout.render(out_buf.writer(), layout_src, source_md, post);

    // write out_buf to out file
    try out.writeAll(out_buf.items);
}
