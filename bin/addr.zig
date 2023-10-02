const std = @import("std");
const debug = std.debug;
const fmt = std.fmt;
const heap = std.heap;
const io = std.io;
const linux = std.os.linux;
const mem = std.mem;
const net = std.net;
const os = std.os;
const process = std.process;

const c = @cImport({
    @cInclude("linux/if_addr.h");
    @cInclude("linux/rtnetlink.h");
});

const nl = @import("netlink");
const util = @import("util.zig");

const native_endian = @import("builtin").target.cpu.arch.endian();

const LinkNames = util.SparseList([]u8);

const ADDR_TABLE_WIDTH: usize = 64;

pub fn run(args: *process.ArgIterator) !void {
    var buf = [_]u8{0} ** 4096;
    var sk = try os.socket(linux.AF.NETLINK, linux.SOCK.RAW, linux.NETLINK.ROUTE);
    defer os.close(sk);
    var nlh = nl.Handle.init(sk, &buf);

    const cmd = args.next() orelse "list";
    if (mem.eql(u8, cmd, "list")) {
        try list(&nlh, args);
    } else if (mem.eql(u8, cmd, "get")) {
        //try get(&nlh, args);
    } else if (mem.eql(u8, cmd, "add")) {
        try add(&nlh, args);
    } else if (mem.eql(u8, cmd, "set")) {
        //try set(&nlh, args);
    } else if (mem.eql(u8, cmd, "del")) {
        //try del(&nlh, args);
    } else {
        util.fatal("unknown addr subcommand {s}\n", .{cmd});
    }
}

fn formatCidr(writer: anytype, addr: net.Address, len: u8) !u64 {
    var cw = io.countingWriter(writer);
    switch (addr.any.family) {
        linux.AF.INET => {
            const bytes: *const [4]u8 = @ptrCast(&addr.in.sa.addr);
            try fmt.format(cw.writer(), "{}.{}.{}.{}", .{ bytes[0], bytes[1], bytes[2], bytes[3] });
        },
        linux.AF.INET6 => {
            const big_endian_parts = @as(*align(1) const [8]u16, @ptrCast(&addr.in6.sa.addr));
            const native_endian_parts = switch (native_endian) {
                .Big => big_endian_parts.*,
                .Little => blk: {
                    var buf: [8]u16 = undefined;
                    for (big_endian_parts, 0..) |part, i| {
                        buf[i] = mem.bigToNative(u16, part);
                    }
                    break :blk buf;
                },
            };

            var i: usize = 0;
            var abbrv = false;
            while (i < native_endian_parts.len) : (i += 1) {
                if (native_endian_parts[i] == 0) {
                    if (!abbrv) {
                        try cw.writer().writeAll(if (i == 0) "::" else ":");
                        abbrv = true;
                    }
                    continue;
                }
                try fmt.format(cw.writer(), "{x}", .{native_endian_parts[i]});
                if (i != native_endian_parts.len - 1) {
                    try cw.writer().writeAll(":");
                }
            }
        },
        else => return error.InvalidIPAddressFormat,
    }
    try fmt.format(cw.writer(), "/{d:<3}", .{len});
    return cw.bytes_written;
}

fn list(nlh: *nl.Handle, _: *process.ArgIterator) !void {
    var arena = heap.ArenaAllocator.init(heap.page_allocator);
    defer arena.deinit();

    var links = try LinkNames.initCapacity(arena.allocator(), 8);
    {
        var req = try nlh.new_req(nl.LinkListRequest);
        req.hdr.*.family = os.AF.PACKET;
        req.nlh.*.flags |= linux.NLM_F_DUMP;
        try nlh.send(req);

        var res = nlh.recv_all(nl.LinkResponse);
        while (try res.next()) |payload| {
            var p = payload;
            while (try p.next()) |attr| if (attr.type == @intFromEnum(linux.IFLA.IFNAME)) {
                try links.set(@intCast(payload.value.index), try arena.allocator().dupe(u8, attr.read_slice()));
            };
        }
    }

    var req = try nlh.new_req(nl.AddrListRequest);
    req.nlh.*.flags |= linux.NLM_F_DUMP;
    req.hdr.*.family = os.AF.UNSPEC;
    try nlh.send(req);

    var res = nlh.recv_all(nl.AddrResponse);

    var stdout_buffer = io.bufferedWriter(io.getStdOut().writer());
    defer stdout_buffer.flush() catch |err| {
        debug.print("unable to flush stdout: {}\n", .{err});
    };

    var stdout = stdout_buffer.writer();
    try util.writeTableSeparator(stdout, ADDR_TABLE_WIDTH);
    try fmt.format(stdout, "| {s:<16} | {s:<43} |\n", .{ "name", "address" });
    try util.writeTableSeparator(stdout, ADDR_TABLE_WIDTH);

    while (try res.next()) |payload| {
        if (payload.value.family != linux.AF.INET and payload.value.family != linux.AF.INET6) continue;

        var p = payload;
        while (try p.next()) |attr| {
            switch (attr.type) {
                c.IFA_ADDRESS => {
                    const addr = blk: {
                        if (payload.value.family == linux.AF.INET) {
                            const bytes = attr.read_slice();
                            debug.assert(bytes.len == 4);
                            break :blk net.Address.initIp4(bytes[0..4].*, 0);
                        } else {
                            const bytes = attr.read_slice();
                            debug.assert(bytes.len == 16);
                            break :blk net.Address.initIp6(bytes[0..16].*, 0, 0, 0);
                        }
                    };

                    if (links.get(payload.value.index)) |name| {
                        // The name is sentinel-terminated, but the sentinel value
                        // takes no width.
                        try fmt.format(stdout, "| {s:<17} | ", .{name});
                    } else {
                        try fmt.format(stdout, "| {d:<16} | ", .{payload.value.index});
                    }
                    const written = try formatCidr(stdout, addr, payload.value.prefixlen);
                    // Max IPv6 representation is 8 * 4 + 7 = 39
                    try stdout.writeByteNTimes(' ', 43 - written);
                    try stdout.writeAll(" |\n");
                    break;
                },
                else => {},
            }
        }
    }
    try util.writeTableSeparator(stdout, ADDR_TABLE_WIDTH);
}

fn add(nlh: *nl.Handle, args: *process.ArgIterator) !void {
    const cidr = args.next() orelse util.fatal("address is required\n", .{});
    const name = args.next() orelse util.fatal("link name is required\n", .{});

    var addrStr = cidr[0..cidr.len];
    var len: u8 = 32;
    if (mem.indexOfScalar(u8, cidr, '/')) |i| {
        addrStr = cidr[0..i];
        len = try fmt.parseInt(u8, cidr[i..], 10);
    }
    const addr = try net.Ip4Address.parse(addrStr, 0);

    const dev: u32 = blk: {
        var req = try nlh.new_req(nl.LinkGetRequest);
        _ = try req.add_str(@intFromEnum(linux.IFLA.IFNAME), @constCast(name));
        try nlh.send(req);
        var res = try nlh.recv_one(nl.LinkResponse);
        break :blk @intCast(res.value.index);
    };

    var req = try nlh.new_req(nl.AddrNewRequest);
    req.nlh.*.flags |= linux.NLM_F_CREATE;
    req.hdr.*.family = linux.AF.INET;
    req.hdr.*.prefixlen = len;
    req.hdr.*.flags = c.IFA_F_PERMANENT;
    req.hdr.*.scope = c.RT_SCOPE_UNIVERSE;
    req.hdr.*.index = dev;
    _ = try req.add_int(u32, @intCast(c.IFA_LOCAL), addr.sa.addr);
    _ = try req.add_int(u32, @intCast(c.IFA_ADDRESS), addr.sa.addr);

    try nlh.send(req);
    _ = try nlh.recv_ack();
}
