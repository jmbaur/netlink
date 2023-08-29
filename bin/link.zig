const std = @import("std");
const debug = std.debug;
const heap = std.heap;
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

const rtgenmsg = extern struct {
    rtgen_family: u8,
};

const LinkListRequest = nl.Request(linux.NetlinkMessageType.RTM_GETLINK, rtgenmsg);
const LinkGetRequest = nl.Request(linux.NetlinkMessageType.RTM_GETLINK, linux.ifinfomsg);
const LinkNewRequest = nl.Request(linux.NetlinkMessageType.RTM_NEWLINK, linux.ifinfomsg);
const LinkDelRequest = nl.Request(linux.NetlinkMessageType.RTM_DELLINK, linux.ifinfomsg);
const LinkResponse = nl.Response(linux.NetlinkMessageType.RTM_NEWLINK, linux.ifinfomsg);

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
    var req = try nlh.new_req(LinkListRequest);
    req.hdr.*.rtgen_family = os.AF.PACKET;
    req.nlh.*.flags |= linux.NLM_F_DUMP;
    try nlh.send(req);

    var res = nlh.recv_all(LinkResponse);
    while (try res.next()) |payload| {
        const index: u32 = @intCast(payload.value.index);
        //if ((payload.value.flags & c.IFF_UP) != c.IFF_UP) continue;
        switch (payload.value.type) {
            c.ARPHRD_ETHER, c.ARPHRD_IPGRE, c.ARPHRD_LOOPBACK, c.ARPHRD_RAWIP, c.ARPHRD_TUNNEL => {},
            else => continue,
        }

        var p = payload;
        while (try p.next()) |attr| {
            switch (attr.type) {
                c.IFLA_IFNAME => {
                    debug.print("{d:>2}: {s:<16}\n", .{ index, attr.read_slice() });
                    break;
                },
                else => {},
            }
        }
    }
}

fn get(nlh: *nl.Handle, args: *process.ArgIterator) !void {
    const name = args.next() orelse util.fatal("link name is required\n", .{});

    var req = try nlh.new_req(LinkGetRequest);
    _ = try req.add_str(@intFromEnum(linux.IFLA.IFNAME), @constCast(name));
    try nlh.send(req);
    var res = try nlh.recv_one(LinkResponse);
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

    var req = try nlh.new_req(LinkNewRequest);
    req.nlh.*.flags |= (linux.NLM_F_CREATE | linux.NLM_F_EXCL);
    _ = try req.add_str(@intFromEnum(linux.IFLA.IFNAME), @constCast(name));

    const start = req.i;
    var link_info = try req.add_empty(@intFromEnum(linux.IFLA.LINKINFO));
    _ = try req.add_str(c.IFLA_INFO_KIND, @constCast(type_));

    link_info.*.len = @intCast(req.i - start);

    try nlh.send(req);
    var nlmsg = try nlh.recv_ack();
    debug.print("{}\n", .{nlmsg});
}

fn del(nlh: *nl.Handle, args: *process.ArgIterator) !void {
    const name = args.next() orelse util.fatal("link name is required\n", .{});

    var req = try nlh.new_req(LinkDelRequest);
    _ = try req.add_str(@intFromEnum(linux.IFLA.IFNAME), @constCast(name));

    try nlh.send(req);
    _ = try nlh.recv_ack();
}

fn set(nlh: *nl.Handle, args: *process.ArgIterator) !void {
    const name = args.next() orelse util.fatal("link name is required\n", .{});

    var req = try nlh.new_req(LinkNewRequest);
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
