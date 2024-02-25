const std = @import("std");
const post = @import("post.zig");

const SRC_DIR = "src";

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var src_dir = try std.fs.cwd().openDir(SRC_DIR, .{ .iterate = true });
    defer src_dir.close();

    var src_walker = try src_dir.walk(alloc);
    defer src_walker.deinit();
    while (try src_walker.next()) |f| {
        if (f.kind != .file) continue;
        if (!std.mem.endsWith(u8, f.path, ".md")) continue;

        const post_name = try std.mem.concat(alloc, u8, &.{ f.path[0 .. f.path.len - 2], "html" });
        const post_file = std.fs.cwd().createFile(post_name, .{}) catch {
            std.debug.print("error: couldn't open {s} for writing\n", .{post_name});
            continue;
        };
        defer post_file.close();

        const src_file = try src_dir.openFile(f.path, .{ .mode = .read_only });
        defer src_file.close();
        const src = try src_file.readToEndAlloc(alloc, 1024 * 1024);

        std.debug.print("rendering {s}/{s} -> {s}\n", .{ SRC_DIR, f.path, post_name });
        try post.render(post_file.writer(), src);
    }
}
