const std = @import("std");
const md = @import("md.zig");
const common = @import("common.zig");

const LAYOUT_DIR = "layouts/";
pub const DEFAULT_LAYOUT = "post";

// all layouts are stored in this hashmap. (layout_name: layout_content)
var layout_map: std.StringHashMap([]const u8) = undefined;

pub fn init(alloc: std.mem.Allocator) void {
    layout_map = std.StringHashMap([]const u8).init(alloc);
}

pub fn deinit() void {
    layout_map.deinit();
}

pub fn renderLayout(
    alloc: std.mem.Allocator,
    out: anytype,
    layout_name: []const u8,
    metadata: std.StringHashMap([]const u8),
    source_md: []const u8,
) !void {
    // load the layout from the layout file
    var layout = try load(alloc, layout_name);

    // replace all variables in the layout and write it to the "out" writer
    while (std.mem.indexOf(u8, layout, "<!--{")) |var_start| {
        // write everything up till the start of the variable
        _ = try out.write(layout[0..var_start]);

        // determine where the variable name ends
        const var_end = std.mem.indexOf(u8, layout, "}-->") orelse {
            // if there's no close tag, break and write what's left of the layout
            std.log.warn("no matching }}--> found for <!--{{", .{});
            layout = layout[var_start..];
            break;
        };

        const var_name = layout[var_start + 5 .. var_end];
        if (std.mem.eql(u8, var_name, "content")) {
            // if the name of the variable is "content", render the md source
            try md.parse(out.writer(), source_md);
        } else {
            // else, obtain the value of the variable from the metadata and write it
            const var_value = metadata.get(var_name) orelse "";
            _ = try out.write(var_value);
        }

        // slide the layout slice past the current variable
        layout = layout[var_end + 4 ..];
    }

    // write what's left of the layout
    _ = try out.write(layout);
}

fn load(alloc: std.mem.Allocator, layout_name: []const u8) ![]const u8 {
    const layout = layout_map.get(layout_name) orelse blk: {
        // if the layout isn't in the hashmap yet, read it from the layout file
        const layout_filename = try std.mem.concat(alloc, u8, &.{ LAYOUT_DIR, layout_name, ".html" });
        defer alloc.free(layout_filename);
        const layout = try common.readFile(alloc, std.fs.cwd(), layout_filename);
        try layout_map.put(layout_name, layout);
        std.log.info("loaded layout {s}", .{layout_filename});
        break :blk layout;
    };
    return layout;
}
