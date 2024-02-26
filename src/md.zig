const std = @import("std");
const c = @cImport({
    @cInclude("md4c-html.h");
});

fn process_output(text: [*c]const c.MD_CHAR, size: c_uint, userdata: ?*anyopaque) callconv(.C) void {
    const out: *std.fs.File.Writer = @ptrCast(@alignCast(userdata orelse @panic("error: md4c hasn't populated userdata")));
    _ = out.write(text[0..size]) catch @panic("error: couldn't write to file");
}

pub fn parse(out: anytype, src: []const u8) !void {
    const ret = c.md_html(src.ptr, @intCast(src.len), process_output, @ptrCast(@constCast(&out)), 0, c.MD_HTML_FLAG_DEBUG);
    if (ret != 0) return error.MarkdownParseError;
}
