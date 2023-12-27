const std = @import("std");
const md = @import("md.zig");

pub fn main() !void {
    const src =
        \\# Heading
        \\Paragraph.
        \\Paragraph continuation.
        \\
        \\New paragraph.
    ;

    const stdout = std.io.getStdOut().writer();
    try md.parse(stdout, src);
}
