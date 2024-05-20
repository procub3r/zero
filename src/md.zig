const c = @cImport(@cInclude("md4c-html.h"));

// convert the source markdown to html and write it to the out writer
pub fn toHtml(out: anytype, source: []const u8) !void {
    // md4c calls this callback for every chunk of converted markdown
    const process_output = struct {
        fn f(chunk: [*c]const c.MD_CHAR, size: c.MD_SIZE, userdata: ?*anyopaque) callconv(.C) void {
            // cast userdata back to the out writer and write the html chunk to it
            const out_: *@TypeOf(out) = @ptrCast(@alignCast(userdata));
            _ = out_.write(chunk[0..size]) catch @panic("toHtml: couldn't write html chunk");
        }
    }.f; // neat little trick for creating anonymous functions :D

    // pass the out writer as a type erased any-opaque pointer to md4c so we can get it back in the callback
    const ret = c.md_html(source.ptr, @intCast(source.len), process_output, @ptrCast(@constCast(&out)), 0, 0);
    if (ret != 0) return error.MdToHtmlError;
}
