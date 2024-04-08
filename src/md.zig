const std = @import("std");
const c = @cImport({
    @cInclude("md4c-html.h");
});

// convert "src" (mardkdown source) to html and write it to the "out" writer
pub fn toHtml(out: anytype, source: []const u8) !void {
    // callback called by md4c for every chunk of converted markdown
    const process_output = struct {
        fn process_output_(text: [*c]const c.MD_CHAR, size: c_uint, userdata: ?*anyopaque) callconv(.C) void {
            // cast userdata back into a writer and write the html chunk to it
            const out_: *@TypeOf(out) = @ptrCast(@alignCast(userdata orelse @panic("md.parse: writer is null")));
            _ = out_.write(text[0..size]) catch @panic("md.parse: couldn't write html");
        }
    }.process_output_; // neat little trick for creating anonymous functions :D

    // convert markdown to html!
    // pass the "out" writer as a type-erased anyopaque pointer to md_html as the userdata argument
    const ret = c.md_html(source.ptr, @intCast(source.len), process_output, @ptrCast(@constCast(&out)), 0, 0);
    if (ret != 0) return error.MarkdownParseError;
}
