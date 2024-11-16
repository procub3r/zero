const std = @import("std");
const c = @cImport(@cInclude("md4c-html.h"));

// TODO: read from cmdline args or a config file
const OUT_DIR = ".";
const SRC_DIR = "src";
const LAYOUTS_DIR = "layouts";
const DEFAULT_LAYOUT = "base.html";

// Store all layouts in a hashmap, with the keys being the
// layout name and the values being the layout file contents
var layouts: std.StringHashMap([]const u8) = undefined;

pub fn main() !void {
    // Initialize the main allocator.
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}).init;
    gpa_impl.backing_allocator = std.heap.c_allocator;
    // Check for leaks while deinitializing
    defer std.debug.assert(gpa_impl.deinit() == .ok);
    const gpa = gpa_impl.allocator();

    // Open site directory to write the rendered html files
    var site_dir = std.fs.cwd().openDir(OUT_DIR, .{}) catch |err| {
        std.log.err("couldn't open site directory \"" ++ OUT_DIR ++ "\"", .{});
        return err;
    };
    defer site_dir.close();
    // Open source directory to iterate through all markdown files and render them
    var source_dir = std.fs.cwd().openDir(SRC_DIR, .{ .iterate = true }) catch |err| {
        std.log.err("couldn't open source directory \"" ++ SRC_DIR ++ "\"", .{});
        return err;
    };
    defer source_dir.close();

    // Store all posts in a hashmap, with the keys being the path
    // to the rendered html file and the values being Post structs.
    // TODO: Use std.StringArrayHashmap to be able to sort by date.
    var posts = std.StringHashMap(Post).init(gpa);
    defer {
        var posts_it = posts.iterator();
        while (posts_it.next()) |entry| {
            gpa.free(entry.key_ptr.*); // Free html path string
            entry.value_ptr.deinit(gpa); // Deinit post struct
        }
        posts.deinit();
    }

    // Initialize the layouts hashmap
    layouts = std.StringHashMap([]const u8).init(gpa);
    defer {
        var layouts_it = layouts.iterator();
        while (layouts_it.next()) |entry| {
            gpa.free(entry.key_ptr.*); // Free the layout name
            gpa.free(entry.value_ptr.*); // Free the layout file content
        }
        layouts.deinit();
    }

    // Loop through all markdown files in the source folder
    var source_walker = try source_dir.walk(gpa);
    defer source_walker.deinit();
    while (try source_walker.next()) |f| {
        if (f.kind != .file or !std.mem.endsWith(u8, f.basename, ".md")) continue;
        std.log.info("Rendering " ++ SRC_DIR ++ "/{s}", .{f.path});

        // Allocate and read the markdown file. Eventually freed when the post is freed
        const source = try source_dir.readFileAlloc(gpa, f.path, std.math.maxInt(usize));

        // Convert path/to/file.md to path/to/file.html.
        // This is also used as a key in the posts hashmap.
        // Eventually freed when the post entry is freed in the posts hashmap or when the post is re-rendered.
        const html_path = try std.mem.concat(gpa, u8, &.{ f.path[0 .. f.path.len - 2], "html" });
        const html_file = try site_dir.createFile(html_path, .{});
        defer html_file.close();

        // Create a buffered writer to write the rendered html
        var html_writer = std.io.bufferedWriter(html_file.writer());
        defer html_writer.flush() catch unreachable;

        // Render the post and store the post struct in the posts hashmap
        const post = Post.initAndRender(gpa, html_writer.writer(), source) catch |err| {
            std.debug.print("{}\n", .{err});
            return err;
        };
        // TODO: deinit old post on clobber (will happen while live rendering)
        try posts.put(html_path, post);
    }
}

pub const Post = struct {
    frontmatter: []const u8,
    metadata: std.StringHashMap([]const u8),

    const Self = @This();

    /// Render the post and return the corresponding post struct
    pub fn initAndRender(allocator: std.mem.Allocator, writer: anytype, source: []u8) !Self {
        var metadata = std.StringHashMap([]const u8).init(allocator);

        // Parse frontmatter
        const delim = "---\n";
        if (!std.mem.startsWith(u8, source, delim)) return error.IncorrectFrontmatterFormat;
        const frontmatter_end = delim.len + (std.mem.indexOf(u8, source[delim.len..], delim) orelse {
            return error.IncorrectFrontmatterFormat;
        });

        // Parse key: value pairs into the post hashmap
        var line_iter = std.mem.splitScalar(u8, source[delim.len..frontmatter_end], '\n');
        while (line_iter.next()) |line| {
            const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
            const key = std.mem.trim(u8, line[0..colon], " \t");
            const value = std.mem.trim(u8, line[colon + 1 ..], " \t");
            try metadata.put(key, value);
        }

        // Read layout from layouts hashmap
        const layout_name = metadata.get("layout") orelse DEFAULT_LAYOUT;
        var layout = layouts.get(layout_name) orelse blk: {
            // Read layout from disk if not in hashmap
            // TODO: maybe open layouts_dir in the outer scope
            const layouts_dir = std.fs.cwd().openDir(LAYOUTS_DIR, .{}) catch |err| {
                std.log.err("couldn't open layouts directory \"" ++ LAYOUTS_DIR ++ "\"", .{});
                return err;
            };
            const layout = layouts_dir.readFileAlloc(allocator, layout_name, std.math.maxInt(usize)) catch |err| {
                std.log.err("couldn't open layout file " ++ LAYOUTS_DIR ++ "/{s}", .{layout_name});
                return err;
            };
            // Allocate and copy and don't rely on the post's frontmatter memory for the
            // layout name because the post will be deinitialized while re-rendering.
            const layout_name_dup = try allocator.dupe(u8, layout_name);
            try layouts.put(layout_name_dup, layout);
            break :blk layout;
        };

        // Render layout, replacing variables with metadata and content
        const VAR_OPEN = "<!--{";
        const VAR_CLOSE = "}-->";

        // Loop through all variables in the layout
        while (std.mem.indexOf(u8, layout, VAR_OPEN)) |var_begin| {
            // Write layout until the current variable
            try writer.writeAll(layout[0..var_begin]);

            // Determine index of variable close tag
            const var_end = std.mem.indexOf(u8, layout, VAR_CLOSE) orelse {
                // If there is no corresponding variable close tag, print a warning,
                // break out of the loop and write what's left of the layout there.
                std.log.warn("Corresponding variable close tag not found", .{});
                layout = layout[var_begin..];
                break;
            };

            // Name and value of the variable
            const var_name = layout[var_begin + VAR_OPEN.len .. var_end];
            const var_value = metadata.get(var_name) orelse layout[var_begin .. var_end + VAR_CLOSE.len];

            // Replace variable with its value. Check for special variables first
            if (std.mem.eql(u8, var_name, "content")) {
                // Render the markdown content to html
                try mdToHtml(writer, source[frontmatter_end + delim.len ..]);
            } else {
                // If the variable isn't a special variable, write the value read from the metadata
                try writer.writeAll(var_value);
            }

            // Slide the layout forward past the variable
            layout = layout[var_end + VAR_CLOSE.len ..];
        }

        // Write the remaining layout after the last variable
        try writer.writeAll(layout);

        // Resize the memory used by source to free all the markdown and only retain the
        // frontmatter. Keys and values in the metadata are slices into this frontmatter
        // memory which is eventually freed when the post struct is deinitialized.
        if (!allocator.resize(source, frontmatter_end)) unreachable;
        return Self{ .frontmatter = source[0..frontmatter_end], .metadata = metadata };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.metadata.deinit();
        allocator.free(self.frontmatter);
    }

    /// Convert `md` to html and write it using `writer`
    pub fn mdToHtml(writer: anytype, md: []const u8) !void {
        // MD4C calls this callback for every chunk of generated html
        const process_output = struct {
            fn f(html: [*c]const c.MD_CHAR, size: c.MD_SIZE, userdata: ?*anyopaque) callconv(.c) void {
                // Cast userdata back into a writer and write the html chunk
                const writer_: *@TypeOf(writer) = @alignCast(@ptrCast(userdata));
                writer_.writeAll(html[0..size]) catch unreachable;
            }
        }.f; // process_output is a function pointer
        // Pass the addr of the writer as userdata
        const ret = c.md_html(md.ptr, @intCast(md.len), process_output, @constCast(@ptrCast(&writer)), 0, 0);
        if (ret != 0) return error.MdToHtmlError;
    }
};
