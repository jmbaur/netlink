const std = @import("std");
const debug = std.debug;
const heap = std.heap;
const io = std.io;
const linux = std.os.linux;
const mem = std.mem;
const os = std.os;
const process = std.process;

const link = @import("link.zig");

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

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.log.err(format, args);
    process.exit(1);
}

fn flag_is_help(flag: [:0]const u8) bool {
    const flag_h = "-h";
    const flag_help = "--help";
    return mem.eql(u8, flag, flag_h) or mem.eql(u8, flag, flag_help);
}

fn flag_is_version(flag: [:0]const u8) bool {
    const flag_v = "-v";
    const flag_version = "--version";
    return mem.eql(u8, flag, flag_v) or mem.eql(u8, flag, flag_version);
}

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    var arena = heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    var args = try process.ArgIterator.initWithAllocator(arena.allocator());
    defer args.deinit();

    _ = args.next().?; // program name
    const cmd = args.next() orelse fatal("command is required\n", .{});
    if (flag_is_help(cmd)) {
        debug.print("{s}", .{usage_main});
        return;
    } else if (flag_is_version(cmd)) {
        const build_options = @import("build_options");
        try io.getStdOut().writeAll(build_options.version ++ "\n");
        return;
    } else if (mem.eql(u8, cmd, "l") or mem.eql(u8, cmd, "link")) {
        return link.run(&args);
    }

    fatal("unknown command {s}", .{cmd});
}
