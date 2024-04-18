const std = @import("std");
const c = @cImport({
    @cInclude("md4c-html.h");
});

const LAYOUTS_DIR = "layouts/";
const DEFAULT_LAYOUT = "post";

// type of posts
pub const Post = std.StringHashMap([]const u8);
// array of all posts
pub var posts: std.ArrayList(Post) = undefined;

// map all layout names to their content
pub var layout_map: std.StringHashMap([]const u8) = undefined;

/// render source to "out" writer
pub fn render(alloc: std.mem.Allocator, out: anytype, post: *Post) !void {
    var source = post.get("source").?;

    // iterate through all lines
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
        const value = std.mem.trim(u8, line[colon + 1 ..], " \t");

        // put the key value pair into the post map
        try post.put(key, value);
    }

    // strip the source of its frontmatter
    source = source[frontmatter_len + 4 ..];

    // load layout
    const layout_name = post.get("layout") orelse "post";
    var layout = layout_map.get(layout_name) orelse load_layout: {
        const layout_path = try std.mem.concat(alloc, u8, &.{ LAYOUTS_DIR, layout_name, ".html" });
        defer alloc.free(layout_path);
        const layout = std.fs.cwd().readFileAlloc(alloc, layout_path, 1024 * 1024) catch {
            std.log.err("couldn't read layout file {s}", .{layout_path});
            return;
        };
        try layout_map.put(layout_name, layout);
        break :load_layout layout;
    };

    // render layout by replacing variables
    const var_format_start = "<!--{";
    const var_format_end = "}-->";

    while (std.mem.indexOf(u8, layout, var_format_start)) |var_start| {
        // write everything up till the start of the variable as it is
        _ = try out.write(layout[0..var_start]);

        const var_end = std.mem.indexOf(u8, layout, var_format_end) orelse {
            layout = layout[var_start..];
            break;
        };

        // get the variable's name and value
        const var_name = layout[var_start + var_format_start.len .. var_end];
        const var_value = post.get(var_name) orelse "";

        // replace in-built variables
        if (std.mem.eql(u8, var_name, "body")) {
            // render markdown body to html
            try mdToHtml(out, source);
        }

        // else, replace the variable with the value from frontmatter
        else {
            _ = try out.write(var_value);
        }

        // slide the layout slice past the current variable
        layout = layout[var_end + var_format_end.len ..];
    }

    // write what's left of the layout
    _ = try out.write(layout);
}

/// convert "src" (mardkdown source) to html and write it to the "out" writer
fn mdToHtml(out: anytype, source: []const u8) !void {
    // callback called by md4c for every chunk of converted markdown
    const process_output = struct {
        fn f(text: [*c]const c.MD_CHAR, size: c_uint, userdata: ?*anyopaque) callconv(.C) void {
            // cast userdata back into a writer and write the html chunk to it
            const out_: *@TypeOf(out) = @ptrCast(@alignCast(userdata orelse @panic("md.parse: writer is null")));
            _ = out_.write(text[0..size]) catch @panic("md.parse: couldn't write html");
        }
    }.f; // neat little trick for creating anonymous functions :D

    // convert markdown to html!
    // pass the "out" writer as a type-erased anyopaque pointer to md_html as the userdata argument
    const ret = c.md_html(source.ptr, @intCast(source.len), process_output, @ptrCast(@constCast(&out)), 0, 0);
    if (ret != 0) return error.MarkdownParseError;
}
