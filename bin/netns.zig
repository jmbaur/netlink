const std = @import("std");
const debug = std.debug;
const fmt = std.fmt;
const fs = std.fs;
const io = std.io;
const linux = os.linux;
const mem = std.mem;
const os = std.os;
const process = std.process;
const time = std.time;

const c = @cImport({
    @cInclude("linux/net_namespace.h");
});

const nl = @import("netlink");
const util = @import("util.zig");

const NETNS_TABLE_WIDTH: usize = 53;

const NsidNewRequest = nl.Request(linux.NetlinkMessageType.RTM_NEWNSID, nl.rtgenmsg);

const PidFdOpenError = error{
    SystemFdQuotaExceeded,
    ProcessFdQuotaExceeded,
    NoDevice,
    SystemResources,
    ProcessTerminated,
} || os.UnexpectedError;

fn pidfd_open(pid: linux.pid_t, flags: u32) PidFdOpenError!linux.fd_t {
    debug.assert(flags == 0);
    const rc = linux.pidfd_open(pid, flags);
    switch (linux.getErrno(rc)) {
        .SUCCESS => return @as(linux.fd_t, @intCast(rc)),
        .NFILE => return error.SystemFdQuotaExceeded,
        .MFILE => return error.ProcessFdQuotaExceeded,
        .NODEV => return error.NoDevice,
        .NOMEM => return error.SystemResources,
        .SRCH => return error.ProcessTerminated,
        else => |err| return os.unexpectedErrno(err),
    }
}

// This belongs in std.os.linux?
const SetnsError = error{
    InvalidFlags,
    SystemResources,
    PermissionDenied,
    ProcessTerminated,
} || os.UnexpectedError;

fn setns(fd: linux.fd_t, ns_type: i32) SetnsError!void {
    switch (os.errno(linux.syscall2(.setns, @as(usize, @bitCast(@as(isize, fd))), @as(usize, @bitCast(@as(isize, ns_type)))))) {
        .SUCCESS => return,
        .INVAL => return error.InvalidFlags,
        .NOMEM => return error.SystemResources,
        .PERM => return error.PermissionDenied,
        .SRCH => return error.ProcessTerminated,
        else => |err| return os.unexpectedErrno(err),
    }
}

const UnshareError = error{
    InvalidFlags,
    PermissionDenied,
    SystemResources,
    UserNamespaceLimit,
} || os.UnexpectedError;

fn unshare(flags: usize) UnshareError!void {
    switch (os.errno(linux.unshare(flags))) {
        .SUCCESS => return,
        .INVAL => return error.InvalidFlags,
        .NOMEM => return error.SystemResources,
        .NOSPC => return error.SystemResources,
        .PERM => return error.PermissionDenied,
        .USERS => return error.UserNamespaceLimit,
        else => |err| return os.unexpectedErrno(err),
    }
}

// unshare -Urn
fn unshare_map_user(flags: usize) !void {
    var buf: [16]u8 = undefined;
    const euid = linux.geteuid();
    const egid = linux.getegid();
    try unshare(linux.CLONE.NEWUSER | flags);
    {
        const data = try fmt.bufPrint(&buf, "0 {} 1", .{euid});
        var f = try fs.openFileAbsolute("/proc/self/uid_map", .{ .mode = .read_write });
        defer f.close();
        try f.writeAll(data);
    }
    {
        var f = try fs.openFileAbsolute("/proc/self/setgroups", .{ .mode = .read_write });
        defer f.close();
        try f.writeAll("deny");
    }
    {
        const data = try fmt.bufPrint(&buf, "0 {} 1", .{egid});
        var f = try fs.openFileAbsolute("/proc/self/gid_map", .{ .mode = .read_write });
        defer f.close();
        try f.writeAll(data);
    }
}

const usize_bits = @typeInfo(usize).Int.bits;

fn sigdelset(set: *linux.sigset_t, sig: u6) void {
    const s = sig - 1;
    // shift in musl: s&8*sizeof *set->__bits-1
    const shift = @as(u5, @intCast(s & (usize_bits - 1)));
    const val = @as(u32, @intCast(1)) << shift;
    (set.*)[@as(usize, @intCast(s)) / usize_bits] &= ~val;
}

fn state_dir_path(buf: []u8) ![:0]u8 {
    if (os.getenv("XDG_STATE_HOME")) |state_home| {
        return try fmt.bufPrintZ(buf, "{s}/magic-vm", .{state_home});
    } else {
        const home = os.getenv("HOME") orelse return error.MissingHome;
        return try fmt.bufPrintZ(buf, "{s}/.local/state/net", .{home});
    }
}

pub fn run(args: *process.ArgIterator) !void {
    var path_buf: [os.PATH_MAX:0]u8 = undefined;
    const state_path = try state_dir_path(&path_buf);

    const state_dir = fs.openDirAbsoluteZ(state_path, .{ .access_sub_paths = true }) catch |err| blk: {
        if (err != error.FileNotFound) return err;
        try fs.makeDirAbsoluteZ(state_path);
        break :blk try fs.openDirAbsoluteZ(state_path, .{ .access_sub_paths = true });
    };

    const cmd = args.next() orelse "list";
    if (mem.eql(u8, cmd, "list")) {
        try list(args, state_dir);
    } else if (mem.eql(u8, cmd, "add")) {
        try add(args, state_dir);
    } else if (mem.eql(u8, cmd, "del")) {
        try del(args, state_dir);
    } else if (mem.eql(u8, cmd, "enter")) {
        try enter(args, state_dir);
    } else if (mem.eql(u8, cmd, "set")) {
        try set_id(args, state_dir);
    } else {
        util.fatal("unknown ns subcommand {s}\n", .{cmd});
    }
}

const NsTime = struct {
    ns: i128,

    pub fn init(ns: i128) NsTime {
        return NsTime{ .ns = ns };
    }

    pub fn format(self: NsTime, comptime spec: []const u8, _: std.fmt.FormatOptions, out_stream: anytype) !void {
        if (spec.len != 0) std.fmt.invalidFmtError(spec, self);
        const ep = time.epoch.EpochSeconds{ .secs = @intCast(@divFloor(self.ns, time.ns_per_s)) };
        const yd = ep.getEpochDay().calculateYearDay();
        const md = yd.calculateMonthDay();
        const ds = ep.getDaySeconds();
        try fmt.format(out_stream, "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}", .{ yd.year, md.month.numeric(), md.day_index + 1, ds.getHoursIntoDay(), ds.getMinutesIntoHour(), ds.getSecondsIntoMinute() });
    }
};

fn list(_: *process.ArgIterator, state: fs.Dir) !void {
    var stdout_buffer = io.bufferedWriter(io.getStdOut().writer());
    defer stdout_buffer.flush() catch |err| {
        debug.print("unable to flush stdout: {}\n", .{err});
    };

    const stdout = stdout_buffer.writer();
    try util.writeTableSeparator(stdout, NETNS_TABLE_WIDTH);
    try fmt.format(stdout, "| {s:<16} | {s:<10} | {s:<19} |\n", .{ "name", "pid", "created" });
    try util.writeTableSeparator(stdout, NETNS_TABLE_WIDTH);

    var pid_buf = [_]u8{0} ** 16;
    var iter = state.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;
        const stat = try state.statFile(entry.name);
        const pid = try state.readFile(entry.name, &pid_buf);
        try fmt.format(stdout, "| {s:<16} | {s:<10} | {} |\n", .{ mem.sliceTo(entry.name, '.'), pid, NsTime.init(stat.ctime) });
    }

    try util.writeTableSeparator(stdout, NETNS_TABLE_WIDTH);
}

fn set_id(args: *process.ArgIterator, state: fs.Dir) !void {
    const name = args.next() orelse util.fatal("name is required\n", .{});
    const pid = try get_pid(state, name);

    var buf = [_]u8{0} ** 4096;
    const sk = try os.socket(linux.AF.NETLINK, linux.SOCK.RAW, linux.NETLINK.ROUTE);
    defer os.close(sk);
    var nlh = nl.Handle.init(sk, &buf);

    var req = try nlh.new_req(NsidNewRequest);
    req.hdr.*.family = os.AF.UNSPEC;

    _ = try req.add_int(u32, c.NETNSA_PID, @as(u32, @intCast(pid)));
    const nsid: i32 = -1;
    _ = try req.add_int(u32, c.NETNSA_NSID, @as(u32, @bitCast(nsid)));
    try nlh.send(req);

    const nlmsg = try nlh.recv_ack();
    debug.print("{}\n", .{nlmsg});
}

fn add(args: *process.ArgIterator, state: fs.Dir) !void {
    const name = args.next() orelse util.fatal("name is required\n", .{});
    if (name.len > 16) util.fatal("name must be at most 16 characters\n", .{});

    var file_name_buf = [_]u8{0} ** 32;
    const file_name = try fmt.bufPrint(&file_name_buf, "{s}.pid", .{name});
    var file = state.createFile(file_name, .{ .exclusive = true }) catch |err| {
        if (err == error.PathAlreadyExists) util.fatal("network namespace {s} already exists\n", .{name});
        return err;
    };
    errdefer file.close();

    const pid = try os.fork();
    if (pid != 0) {
        file.close();
        return;
    }

    try unshare_map_user(linux.CLONE.NEWNET);
    try fmt.formatInt(linux.getpid(), 10, .lower, .{}, file.writer());
    file.close();

    var mask = os.empty_sigset;
    linux.sigaddset(&mask, linux.SIG.TERM);
    const sig_fd = try os.signalfd(-1, &mask, 0);
    defer os.close(sig_fd);

    // Block all signals except `SIGTERM`.  Without `sigprocmask()`, other
    // terminating signal such as `SIGINT` will cause `read()` to exit without
    // returning.
    mask = linux.all_mask;
    sigdelset(&mask, linux.SIG.TERM);
    os.sigprocmask(linux.SIG.SETMASK, &mask, null);

    // Wait for SIGTERM.
    var buf = [_]u8{0} ** @sizeOf(linux.signalfd_siginfo);
    const len = try os.read(sig_fd, &buf);
    debug.assert(len == buf.len);

    state.deleteFile(file_name) catch {};
}

fn get_pid(state: fs.Dir, name: []const u8) !linux.pid_t {
    var buf = [_]u8{0} ** 24;
    const pid = blk: {
        const file_name = try fmt.bufPrint(&buf, "{s}.pid", .{name});
        const pid_str = state.readFile(file_name, &buf) catch |err| {
            if (err == error.FileNotFound) util.fatal("network namespace {s} does not exist\n", .{name});
            return err;
        };
        break :blk try fmt.parseInt(linux.pid_t, pid_str, 10);
    };

    // Attempt to parse /proc/<pid>/cmdline to make sure the PID hasn't been
    // reused.  This does not guarantee safety, but it is better than nothing.
    var f = blk: {
        const file_name = try fmt.bufPrintZ(&buf, "/proc/{d}/cmdline", .{pid});
        break :blk fs.openFileAbsoluteZ(file_name, .{}) catch |err| {
            if (err == error.FileNotFound) {
                const pid_file_name = try fmt.bufPrintZ(&buf, "{s}.pid", .{name});
                try state.deleteFileZ(pid_file_name);
                util.fatal("network namespace {s} does not exist\n", .{name});
            }
            return err;
        };
    };

    defer f.close();

    const len = try f.readAll(&buf);
    if (!mem.endsWith(u8, mem.sliceTo(buf[0..len], 0), "net")) return error.ProcessTerminated;
    return pid;
}

// nsenter -U -n --preserve-credentials -t $(cat ${HOME}/.local/state/net/<name>.pid)
fn enter(args: *process.ArgIterator, state: fs.Dir) !void {
    const name = args.next() orelse util.fatal("name is required\n", .{});

    const pid = try get_pid(state, name);
    {
        const pidfd = try pidfd_open(pid, 0);
        defer os.close(pidfd);
        try setns(pidfd, linux.CLONE.NEWUSER | linux.CLONE.NEWNET);
    }

    const shell = os.getenv("SHELL") orelse "/bin/sh";
    const argv = [_:null]?[*:0]const u8{ shell, null };
    return os.execveZ(shell, &argv, std.c.environ);
}

fn del(args: *process.ArgIterator, state: fs.Dir) !void {
    const name = args.next() orelse util.fatal("name is required\n", .{});
    const pid = try get_pid(state, name);

    try os.kill(pid, linux.SIG.TERM);
}
