const std = @import("std");
const md = @import("md.zig");

pub const Post = struct {
    source: std.ArrayList(u8), // source string
    data: std.StringHashMap([]const u8), // metadata
    out: std.fs.File, // out file to render the post to

    const Self = @This();

    // create a post and return it
    pub fn init(
        alloc: std.mem.Allocator,
        out_file: std.fs.File,
        source_file: std.fs.File,
    ) !Self {
        var p = Self{
            .source = std.ArrayList(u8).init(alloc),
            .data = std.StringHashMap([]const u8).init(alloc),
            .out = out_file,
        };

        // read the source. cap it to 1G
        try source_file.reader().readAllArrayList(&p.source, 1 << 30);
        return p;
    }

    // render a post to its out file
    pub fn render(self: *Self, alloc: std.mem.Allocator) !void {
        // render the post to out_buf first
        var out_buf = try std.ArrayList(u8).initCapacity(alloc, self.source.items.len);
        defer out_buf.deinit();
        try md.toHtml(out_buf.writer(), self.source.items);

        // write out_buf to out file
        try self.out.writeAll(out_buf.items);
    }
};
