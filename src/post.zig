const std = @import("std");
const md = @import("md.zig");
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

    // load the layout for the post
    const layout_name = post.get("layout");
    var layout_src = try layout.load(alloc, layout_map, layout_name);

    // render the layout by replacing the variables
    const var_format_start = "<!--{";
    const var_format_end = "}-->";

    // iterate through all the variables
    while (std.mem.indexOf(u8, layout_src, var_format_start)) |var_start| {
        // write everything up till the variable as it is
        try out_buf.writer().writeAll(layout_src[0..var_start]);

        // find the end index of the variable
        const var_end = std.mem.indexOf(u8, layout_src, var_format_end) orelse {
            layout_src = layout_src[var_start..];
            break;
        };

        // get the variable's name and value
        const var_name = layout_src[var_start + var_format_start.len .. var_end];

        // replace in-built variables
        if (std.mem.eql(u8, var_name, "body")) {
            // render markdown to html and write to out_buf
            const source_md = source[frontmatter_len + 4 ..];
            try md.toHtml(out_buf.writer(), source_md);
        }

        // else, replace the variable with the value from frontmatter
        else {
            if (post.get(var_name)) |var_value| {
                try out_buf.writer().writeAll(var_value);
            } else {
                try std.fmt.format(out_buf.writer(), "<!--{{{s} not defined}}-->", .{var_name});
            }
        }

        // slide the layout slice past the current variable
        layout_src = layout_src[var_end + var_format_end.len ..];
    }

    // write what's left of the layout
    try out_buf.writer().writeAll(layout_src);

    // write out_buf to out file
    try out.writeAll(out_buf.items);
}
