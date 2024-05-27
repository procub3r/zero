const std = @import("std");
const md = @import("md.zig");

const DEFAULT_LAYOUT_NAME = "post";
const LAYOUT_DIR = "layouts/";

// load layout from file if not already in layout_map
pub fn load(
    alloc: std.mem.Allocator,
    layout_map: *std.StringHashMap([]const u8),
    name: ?[]const u8,
) ![]const u8 {
    const layout_name = name orelse DEFAULT_LAYOUT_NAME;
    const layout = layout_map.get(layout_name) orelse load: {
        const layout_path = try std.mem.concat(alloc, u8, &.{ LAYOUT_DIR, layout_name, ".html" });
        defer alloc.free(layout_path);
        std.log.info("loading layout {s}", .{layout_path});
        const layout = try std.fs.cwd().readFileAlloc(alloc, layout_path, 1 << 30);
        try layout_map.put(layout_name, layout);
        break :load layout;
    };
    return layout;
}

const Post = @import("post.zig").Post;

pub fn render(out: anytype, layout_: []const u8, source_md: []const u8, post: *Post) !void {
    // render the layout by replacing the variables
    const var_format_start = "<!--{";
    const var_format_end = "}-->";

    // we need a mutable layout slice
    var layout = layout_;

    // iterate through all the variables
    while (std.mem.indexOf(u8, layout, var_format_start)) |var_start| {
        // write everything up till the variable as it is
        try out.writeAll(layout[0..var_start]);

        // find the end index of the variable
        const var_end = std.mem.indexOf(u8, layout, var_format_end) orelse {
            layout = layout[var_start..];
            break;
        };

        // get the variable's name and value
        const var_name = layout[var_start + var_format_start.len .. var_end];

        // replace in-built variables
        if (std.mem.eql(u8, var_name, "body")) {
            // render markdown to html and write to out_buf
            try md.toHtml(out, source_md);
        }

        // else, replace the variable with the value from frontmatter
        else {
            if (post.get(var_name)) |var_value| {
                try out.writeAll(var_value);
            } else {
                try std.fmt.format(out, "<!--{{{s} not found}}-->", .{var_name});
            }
        }

        // slide the layout slice past the current variable
        layout = layout[var_end + var_format_end.len ..];
    }

    // write what's left of the layout
    try out.writeAll(layout);
}
