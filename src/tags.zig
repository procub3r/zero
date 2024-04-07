const std = @import("std");

const TAGS_PAGE = "/tags.html";

pub fn renderTagsInPost(out: anytype, raw_tags_str: []const u8) !void {
    // iterate through all the tags
    var tag_iter = std.mem.splitScalar(u8, raw_tags_str, ',');
    while (tag_iter.next()) |tag_| {
        const tag = std.mem.trim(u8, tag_, " \t");
        if (tag.len == 0) continue; // skip empty tags
        // write a link which links to the tag's id in the tags.html page
        try std.fmt.format(
            out,
            "<a class=\"tag\" href=\"{s}#{s}\">{s}</a> ",
            .{ TAGS_PAGE, tag, tag },
        );
    }
}
