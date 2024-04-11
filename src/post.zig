const std = @import("std");
const fs = @import("fs.zig");
const md = @import("md.zig");
const common = @import("common.zig");

pub fn render(
    alloc: std.mem.Allocator,
    source_dir: std.fs.Dir,
    source_path: std.fs.Dir.Walker.WalkerEntry,
) !void {
    // determine path to the post rendered from the source file
    const post_path = try std.mem.concat(alloc, u8, &.{ source_path.path[0 .. source_path.path.len - 2], "html" });
    std.log.info("rendering post {s}", .{post_path});

    // create the post file if it doesn't exist, and open it for writing
    const post_file = try fs.createFileMakePath(post_path);
    defer post_file.close();

    // create a buffered writer to write to the post file
    var post_writer = std.io.BufferedWriter(2 * 4096, @TypeOf(post_file.writer())){
        .unbuffered_writer = post_file.writer(),
    };
    defer post_writer.flush() catch std.log.err("couldn't flush buffer to post file", .{});

    // read the source from the source file
    var source = try fs.readFile(alloc, source_dir, source_path.path);

    // parse metadata and remove frontmatter from source
    const metadata = try alloc.create(common.PostMetadata);
    source = try parseMetadata(alloc, metadata, source);

    // get the path to the layout file and read its contents
    const layout_name = metadata.get("layout") orelse "post";
    const layout = try loadLayout(alloc, layout_name); // try fs.readFile(alloc, std.fs.cwd(), layout_path);

    // render the post using the layout
    try renderLayout(post_writer.writer(), layout, metadata, source);

    std.log.info(" rendered post {s}\n", .{post_path});
}

// populate metadata and return the source with the frontmatter stripped away
inline fn parseMetadata(
    alloc: std.mem.Allocator,
    metadata: *common.PostMetadata,
    source: []const u8,
) ![]const u8 {
    errdefer std.log.err("incorrect frontmatter formatting", .{});
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

fn loadLayout(alloc: std.mem.Allocator, layout_name: []const u8) ![]const u8 {
    // try to get the layout from the layout map
    const layout = common.layout_map.get(layout_name) orelse read_layout: {
        // if it doesn't exist in the layout map, read it from the layout file
        const layout_path = try std.mem.concat(alloc, u8, &.{ common.LAYOUT_DIR, layout_name, ".html" });
        const layout = try fs.readFile(alloc, std.fs.cwd(), layout_path);
        // and put it into the layout map for future use
        try common.layout_map.put(layout_name, layout);
        break :read_layout layout;
    };
    return layout;
}

fn renderLayout(
    post_writer: anytype,
    layout_: []const u8,
    metadata: *common.PostMetadata,
    source: []const u8,
) !void {
    var layout = layout_; // we need a mutable slice
    const var_format_start = "<!--{";
    const var_format_end = "}-->";

    // replace all the variables in the layout and write it to the post
    while (std.mem.indexOf(u8, layout, var_format_start)) |var_start| {
        // write everything up till the start of the variable as it is
        _ = try post_writer.write(layout[0..var_start]);

        // find the end index of the variable
        const var_end = std.mem.indexOf(u8, layout, var_format_end) orelse {
            std.log.warn("no matching {s} found for {s}", .{ var_format_end, var_format_start });
            layout = layout[var_start..];
            break;
        };

        // get the name and value of the variable
        const var_name = layout[var_start + var_format_start.len .. var_end];
        const var_value = metadata.get(var_name) orelse "";

        // process inbuilt variables
        if (std.mem.eql(u8, var_name, "body")) {
            try md.toHtml(post_writer, source);
        }

        // directly replace the user defined variables
        else {
            _ = try post_writer.write(var_value);
        }

        // slide the layout slice past the current variable
        layout = layout[var_end + var_format_end.len ..];
    }

    // write what's left of the layout
    _ = try post_writer.write(layout);
}
