const std = @import("std");
const c = @cImport({
    @cInclude("cmark.h");
    @cInclude("stdlib.h");
});

pub fn parse(out: anytype, src: []const u8) !void {
    const parser = c.cmark_parser_new(c.CMARK_OPT_DEFAULT);
    defer c.cmark_parser_free(parser);

    c.cmark_parser_feed(parser, @ptrCast(src), src.len);

    const doc = c.cmark_parser_finish(parser);
    defer c.cmark_node_free(doc);

    const html = c.cmark_render_html(doc, c.CMARK_OPT_DEFAULT);
    defer c.free(html);

    try out.print("{s}", .{html});
}
