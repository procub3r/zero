const std = @import("std");

// config options
pub const SOURCE_DIR = "source/";
pub const LAYOUT_DIR = "layouts/";

// type decls
pub const PostMetadata = std.StringHashMap([]const u8);

// global state
pub var layout_map: std.StringHashMap([]const u8) = undefined;
