const std = @import("std");

// config options
pub const SOURCE_DIR = "source/";
pub const LAYOUT_DIR = "layouts/";
pub const TAG_PAGES_DIR = "tags/";

// type decls
pub const PostMetadata = std.StringHashMap([]const u8);

// global state
pub var layout_map: std.StringHashMap([]const u8) = undefined;
pub var tag_map: std.StringHashMap(std.ArrayList(*PostMetadata)) = undefined;
