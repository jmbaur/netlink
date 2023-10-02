const std = @import("std");
const debug = std.debug;
const fmt = std.fmt;
const heap = std.heap;
const io = std.io;
const linux = std.os.linux;
const mem = std.mem;
const os = std.os;
const process = std.process;

const c = @cImport({
    @cInclude("linux/if.h");
    @cInclude("linux/if_arp.h");
});

const nl = @import("netlink");
const util = @import("util.zig");

const Link = struct {
    id: u32,
    name: ?[]u8,
    type: u14,
    addr: ?[6]u8,
    up: bool,

    fn init(id: u32, type_: u14, up: bool) Link {
        return Link{
            .id = id,
            .name = null,
            .type = type_,
            .addr = null,
            .up = up,
        };
    }

    fn writeRow(self: Link, out_stream: anytype) !void {
        try fmt.format(out_stream, "| {d:<3} | ", .{self.id});
        if (self.name) |name| {
            try fmt.format(out_stream, "{s:<16}", .{name});
        } else {
            try out_stream.writeByteNTimes(' ', 15);
        }
        try out_stream.writeAll(" | ");

        try switch (self.type) {
            c.ARPHRD_ETHER => fmt.format(out_stream, "{s:<9}", .{"ether"}),
            c.ARPHRD_TUNNEL => fmt.format(out_stream, "{s:<9}", .{"ipip"}),
            c.ARPHRD_LOOPBACK => fmt.format(out_stream, "{s:<9}", .{"loopback"}),
            c.ARPHRD_IPGRE => fmt.format(out_stream, "{s:<9}", .{"gre"}),
            c.ARPHRD_NETLINK => fmt.format(out_stream, "{s:<9}", .{"netlink"}),
            else => |type_| fmt.format(out_stream, "{d:<9}", .{type_}),
        };
        try out_stream.writeAll(" | ");

        if (self.addr) |addr| {
            try fmt.format(out_stream, "{x:0>2}:{x:0>2}:{x:0>2}:{x:0>2}:{x:0>2}:{x:0>2}", .{ addr[0], addr[1], addr[2], addr[3], addr[4], addr[5] });
        } else {
            try out_stream.writeByteNTimes(' ', 17);
        }
        try out_stream.writeAll(" | ");

        if (self.up) {
            try out_stream.writeByte('*');
        } else {
            try out_stream.writeByte(' ');
        }
        try out_stream.writeAll("  |\n");
    }
};

const LINK_TABLE_WIDTH: usize = 60;

pub fn run(args: *process.ArgIterator) !void {
    var buf = [_]u8{0} ** 4096;
    var sk = try os.socket(linux.AF.NETLINK, linux.SOCK.RAW, linux.NETLINK.ROUTE);
    defer os.close(sk);
    var nlh = nl.Handle.init(sk, &buf);

    const cmd = args.next() orelse "list";
    if (mem.eql(u8, cmd, "list")) {
        try list(&nlh);
    } else if (mem.eql(u8, cmd, "get")) {
        try get(&nlh, args);
    } else if (mem.eql(u8, cmd, "add")) {
        try add(&nlh, args);
    } else if (mem.eql(u8, cmd, "set")) {
        try set(&nlh, args);
    } else if (mem.eql(u8, cmd, "del")) {
        try del(&nlh, args);
    } else {
        util.fatal("unknown link subcommand {s}\n", .{cmd});
    }
}

fn list(nlh: *nl.Handle) !void {
    var req = try nlh.new_req(nl.LinkListRequest);
    req.hdr.*.family = os.AF.PACKET;
    req.nlh.*.flags |= linux.NLM_F_DUMP;
    try nlh.send(req);

    var res = nlh.recv_all(nl.LinkResponse);

    var stdout_buffer = io.bufferedWriter(io.getStdOut().writer());
    defer stdout_buffer.flush() catch |err| {
        debug.print("unable to flush stdout: {}\n", .{err});
    };

    var stdout = stdout_buffer.writer();
    try util.writeTableSeparator(stdout, LINK_TABLE_WIDTH);
    try fmt.format(stdout, "| {s:<3} | {s:<15} | {s:<9} | {s:<17} | {s:<2} |\n", .{ "id", "name", "type", "address", "up" });
    try util.writeTableSeparator(stdout, LINK_TABLE_WIDTH);

    while (try res.next()) |payload| {
        var link = Link.init(@intCast(payload.value.index), @intCast(payload.value.type), (payload.value.flags & c.IFF_UP) == c.IFF_UP);

        var p = payload;
        while (try p.next()) |attr| switch (attr.type) {
            @intFromEnum(linux.IFLA.IFNAME) => link.name = attr.read_slice(),
            @intFromEnum(linux.IFLA.ADDRESS) => {
                const addr = attr.read_slice();
                debug.assert(addr.len == 6);
                link.addr = addr[0..6].*;
            },
            // TODO: read c.IFLA_LINKINFO with nested c.IFLA_INFO_KIND
            else => {},
        };

        try link.writeRow(stdout);
    }

    try util.writeTableSeparator(stdout, LINK_TABLE_WIDTH);
}

fn get(nlh: *nl.Handle, args: *process.ArgIterator) !void {
    const name = args.next() orelse util.fatal("link name is required\n", .{});

    var req = try nlh.new_req(nl.LinkGetRequest);
    _ = try req.add_str(@intFromEnum(linux.IFLA.IFNAME), @constCast(name));
    try nlh.send(req);
    var res = try nlh.recv_one(nl.LinkResponse);
    const index: u32 = @intCast(res.value.index);
    debug.print("{d:>2}:", .{index});

    var found_name: ?[]u8 = null;
    while (try res.next()) |attr| {
        switch (attr.type) {
            c.IFLA_IFNAME => {
                found_name = attr.read_slice();
                break;
            },
            else => {},
        }
    }
    debug.print(" {s:<16}\n", .{found_name orelse "<unknown>"});
}

fn add(nlh: *nl.Handle, args: *process.ArgIterator) !void {
    const name = args.next() orelse util.fatal("link name is required\n", .{});
    const type_ = args.next() orelse util.fatal("link type is required\n", .{});

    var req = try nlh.new_req(nl.LinkNewRequest);
    req.nlh.*.flags |= (linux.NLM_F_CREATE | linux.NLM_F_EXCL);
    _ = try req.add_str(@intFromEnum(linux.IFLA.IFNAME), @constCast(name));

    const start = req.i;
    var link_info = try req.add_empty(@intFromEnum(linux.IFLA.LINKINFO));
    _ = try req.add_str(c.IFLA_INFO_KIND, @constCast(type_));

    link_info.*.len = @intCast(req.i - start);

    try nlh.send(req);
    _ = try nlh.recv_ack();
}

fn del(nlh: *nl.Handle, args: *process.ArgIterator) !void {
    const name = args.next() orelse util.fatal("link name is required\n", .{});

    var req = try nlh.new_req(nl.LinkDelRequest);
    _ = try req.add_str(@intFromEnum(linux.IFLA.IFNAME), @constCast(name));

    try nlh.send(req);
    _ = try nlh.recv_ack();
}

fn set(nlh: *nl.Handle, args: *process.ArgIterator) !void {
    const name = args.next() orelse util.fatal("link name is required\n", .{});

    var req = try nlh.new_req(nl.LinkNewRequest);
    _ = try req.add_str(@intFromEnum(linux.IFLA.IFNAME), @constCast(name));

    var any = false;
    while (args.next()) |arg| {
        any = true;

        if (mem.eql(u8, arg, "up")) {
            req.hdr.*.change = 1; // IFF_UP
            req.hdr.*.flags = 1;
        } else {
            util.fatal("unknown attribute {s}\n", .{arg});
        }
    }

    if (!any) util.fatal("must provide one or more attributes\n", .{});

    try nlh.send(req);
    _ = try nlh.recv_ack();

    // mac
    //_ = try req.add_str(@intFromEnum(linux.IFLA.ADDRESS), @constCast(name));
    //c.mnl_attr_put(nlh, c.IFLA_ADDRESS, addr.len, &addr[0]);
}
