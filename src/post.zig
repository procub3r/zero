const std = @import("std");
const md = @import("md.zig");

// render the post to the "out" writer from the "src" markdown source
pub fn render(alloc: std.mem.Allocator, out: anytype, src: []const u8) !void {
    // parse yaml frontmatter
    if (!std.mem.startsWith(u8, src, "---\n")) return error.IncorrectFormat;
    const frontmatter_end = std.mem.indexOf(u8, src, "\n---\n") orelse return error.IncorrectFormat;
    const frontmatter = src[4 .. frontmatter_end + 1]; // let it include the last newline char

    // str -> str hashmap to keep track of frontmatter key -> value pairs
    var metadata = std.StringHashMap([]const u8).init(alloc);
    defer metadata.deinit();

    // simple key: value pair frontmatter parser
    var cursor: usize = 0;
    while (cursor < frontmatter.len) {
        const colon = std.mem.indexOfScalar(u8, frontmatter[cursor..], ':') orelse return error.IncorrectFormat;
        const key = std.mem.trim(u8, frontmatter[cursor..][0..colon], " ");

        const newline = std.mem.indexOfScalar(u8, frontmatter[cursor..], '\n') orelse return error.IncorrectFormat;
        const value = std.mem.trim(u8, frontmatter[cursor..][colon + 1 .. newline], " ");

        // store the key: value pair in metadata
        try metadata.put(key, value);
        cursor += newline + 1;
    }

    // print all the metadata
    var metadata_iter = metadata.iterator();
    while (metadata_iter.next()) |entry| {
        std.debug.print("{s}: {s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
    }

    // convert md to html and write it to "out"
    const md_begin = frontmatter_end + 5;
    try md.parse(out, src[md_begin..]);
}
