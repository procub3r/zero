const std = @import("std");
const c = @cImport({
    @cInclude("md4c-html.h");
});

// convert "src" (mardkdown source) to html and write it to the "out" writer
pub fn parse(out: anytype, src: []const u8) !void {
    // this function is defined inside parse() because we need to access the exact
    // type of the "out" writer in order to cast it back to a writer in the callback.
    const process_output = struct {
        // callback called by md4c for every chunk of converted markdown
        fn f(text: [*c]const c.MD_CHAR, size: c_uint, userdata: ?*anyopaque) callconv(.C) void {
            // userdata is a writer passed to md4c, which is then passed back to this callback.
            // cast it back into a writer and write the html chunk to it
            const out_: *@TypeOf(out) = @ptrCast(@alignCast(userdata orelse @panic("userdata doesn't point to an \"out\" writer")));
            _ = out_.write(text[0..size]) catch @panic("error: couldn't write to file");
        }
    }.f; // neat little trick for creating anonymous functions :D

    // convert markdown to html!
    // pass the "out" writer as a type-erased anyopaque pointer to md_html.
    // it will then be passed back to us in the process_output callback
    const ret = c.md_html(src.ptr, @intCast(src.len), process_output, @ptrCast(@constCast(&out)), 0, c.MD_HTML_FLAG_DEBUG);
    if (ret != 0) return error.MarkdownParseError;
}
