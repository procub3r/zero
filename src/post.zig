const std = @import("std");
const md = @import("md.zig");

var layouts = std.StringHashMap([]const u8);

pub fn render(dest: anytype, src: []const u8) !void {
    if (!std.mem.startsWith(u8, src, "---\n")) return error.IncorrectFormat;
    const frontmatter_end = std.mem.indexOf(u8, src, "\n---\n") orelse return error.IncorrectFormat;
    const md_begin = frontmatter_end + 5;

    try md.parse(dest, src[md_begin..]);
}
