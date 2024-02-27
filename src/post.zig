const std = @import("std");
const md = @import("md.zig");

// render the post to the "out" writer from the "src" markdown source
pub fn render(out: anytype, src: []const u8) !void {
    // parse yaml frontmatter
    if (!std.mem.startsWith(u8, src, "---\n")) return error.IncorrectFormat;
    const frontmatter_end = std.mem.indexOf(u8, src, "\n---\n") orelse return error.IncorrectFormat;
    const md_begin = frontmatter_end + 5;

    // convert md to html and write it to "out"
    try md.parse(out, src[md_begin..]);
}
