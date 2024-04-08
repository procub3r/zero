const std = @import("std");
const md = @import("md.zig");

pub fn main() !void {
    const source =
        \\# Zero
        \\A _static site generator_ written in **Zig**.
    ;

    const stdout = std.io.getStdIn().writer();
    try md.toHtml(stdout, source);
}
