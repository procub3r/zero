const std = @import("std");
const md = @import("md.zig");

const LAYOUT_DIR = "layouts/";
const DEFAULT_LAYOUT = "post";

pub fn renderFromSourceFile(
    alloc: std.mem.Allocator,
    post_path: []const u8,
    layouts: *std.StringHashMap([]const u8),
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
    const source = try readFile(alloc, source_dir, source_path);

    // render the post
    try render(alloc, &post_writer_buffered, layouts, source);
    try post_writer_buffered.flush();
}

pub fn render(
    alloc: std.mem.Allocator,
    post_writer: anytype,
    layouts: *std.StringHashMap([]const u8),
    source: []const u8,
) !void {
    // parse metadata from the frontmatter
    const frontmatter_end = try getFrontmatterEnd(source);
    const frontmatter = source[4..frontmatter_end];
    var metadata = try parseMetadata(alloc, frontmatter);
    defer metadata.deinit();

    // get the name of the layout from the metadata
    const layout_name = metadata.get("layout") orelse blk: {
        std.log.warn("layout field not set. defaulting to {s}", .{DEFAULT_LAYOUT});
        break :blk DEFAULT_LAYOUT;
    };
    std.log.info("using layout {s}", .{layout_name});

    // load layout and write it to the post file, replacing all variables
    var layout = try loadLayout(alloc, layouts, layout_name);
    while (std.mem.indexOf(u8, layout, "<!--{")) |var_start| {
        // write everything up till the start of the variable
        _ = try post_writer.write(layout[0..var_start]);

        // determine where the variable name ends
        const var_end = std.mem.indexOf(u8, layout, "}-->") orelse {
            // if there's no close tag, write what's left of the layout and break
            std.log.warn("no matching }}--> found for <!--{{", .{});
            _ = try post_writer.write(layout[var_start..]);
            break;
        };

        const var_name = layout[var_start + 5 .. var_end];
        if (std.mem.eql(u8, var_name, "content")) {
            // if the name of the variable is "content", render the md source
            const source_md = source[frontmatter_end + 6 ..];
            try md.parse(post_writer.writer(), source_md);
        } else {
            // else, obtain the value of the variable from the metadata and write it
            const var_value = metadata.get(var_name) orelse "";
            _ = try post_writer.write(var_value);
        }

        // slide the layout slice past the current variable
        layout = layout[var_end + 4 ..];
    } else {
        // write what's left of the layout
        _ = try post_writer.write(layout);
    }
}

fn loadLayout(alloc: std.mem.Allocator, layouts: *std.StringHashMap([]const u8), layout_name: []const u8) ![]const u8 {
    const layout = layouts.get(layout_name) orelse blk: {
        // if the layout isn't in the hashmap yet, read it from the layout file
        const layout_filename = try std.mem.concat(alloc, u8, &.{ LAYOUT_DIR, layout_name, ".html" });
        const layout = try readFile(alloc, std.fs.cwd(), layout_filename);
        try layouts.put(layout_name, layout);
        std.log.info("loaded layout {s}", .{layout_filename});
        break :blk layout;
    };
    return layout;
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

fn readFile(alloc: std.mem.Allocator, dir: std.fs.Dir, path: []const u8) ![]const u8 {
    const file = dir.openFile(path, .{ .mode = .read_only }) catch |err| {
        std.log.err("couldn't open file {s} for reading", .{path});
        return err;
    };
    defer file.close();

    // cap the file size at 1MiB
    const content = file.readToEndAlloc(alloc, 1024 * 1024) catch |err| {
        std.log.err("[{}] {s}", .{ err, path });
        return err;
    };

    return content;
}
