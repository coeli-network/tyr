const std = @import("std");

pub fn main() !u8 {
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();
    const args = try std.process.argsAlloc(std.heap.page_allocator);

    if (args.len != 2) {
        try stderr.print("one arg expected <nock code>\n", .{});
        return 1;
    }

    var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const path = std.fs.realpath(args[1], &path_buffer) catch |err| switch(err) {
        error.FileNotFound => {
            try stderr.print("could not find nock file\n", .{});
        },
        else => {
            try stderr.print("unexpected error: ${}\n", .{ err });
        }
    };

    try stdout.print("path: {s}", .{ path });

    return 0;
}
