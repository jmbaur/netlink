const std = @import("std");
const debug = std.debug;
const heap = std.heap;
const io = std.io;
const linux = std.os.linux;
const mem = std.mem;
const os = std.os;
const process = std.process;

const addr = @import("addr.zig");
const link = @import("link.zig");
const netns = @import("netns.zig");
const util = @import("util.zig");

const usage_main =
    \\Usage: plog [options]
    \\
    \\Options:
    \\
    \\  -h, --help       Print command-specific usage
    \\  -v, --version    Print program version
    \\
    \\
;

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    var arena = heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    var args = try process.ArgIterator.initWithAllocator(arena.allocator());
    defer args.deinit();

    _ = args.next().?; // program name
    const cmd = args.next() orelse util.fatal("command is required\n", .{});
    if (util.flag_is_help(cmd)) {
        debug.print("{s}", .{usage_main});
        return;
    } else if (util.flag_is_version(cmd)) {
        const build_options = @import("build_options");
        try io.getStdOut().writeAll(build_options.version ++ "\n");
        return;
    } else if (mem.eql(u8, cmd, "a") or mem.eql(u8, cmd, "addr")) {
        return addr.run(&args);
    } else if (mem.eql(u8, cmd, "l") or mem.eql(u8, cmd, "link")) {
        return link.run(&args);
    } else if (mem.eql(u8, cmd, "ns")) {
        return netns.run(&args);
    }

    util.fatal("unknown command {s}", .{cmd});
}
