const std = @import("std");

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
