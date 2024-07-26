const std = @import("std");
const debug = std.debug;
const fmt = std.fmt;
const heap = std.heap;
const io = std.io;
const linux = std.os.linux;
const mem = std.mem;
const posix = std.posix;
const process = std.process;

const c = @cImport({
    @cInclude("linux/if_arp.h");
});

const nl = @import("netlink");
const util = @import("util.zig");

const Link = struct {
    id: u32,
    name: ?[]const u8,
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
    const sk = try posix.socket(linux.AF.NETLINK, linux.SOCK.RAW, linux.NETLINK.ROUTE);
    defer posix.close(sk);
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
    const req = try nlh.new_req(nl.link.GetLinkRequest);
    req.hdr.ifi_family = linux.AF.PACKET;
    var res = try nlh.dump(req);

    var stdout_buffer = io.bufferedWriter(io.getStdOut().writer());
    defer stdout_buffer.flush() catch |err| {
        debug.print("unable to flush stdout: {}\n", .{err});
    };

    const stdout = stdout_buffer.writer();
    try util.writeTableSeparator(stdout, LINK_TABLE_WIDTH);
    try fmt.format(stdout, "| {s:<3} | {s:<15} | {s:<9} | {s:<17} | {s:<2} |\n", .{ "id", "name", "type", "address", "up" });
    try util.writeTableSeparator(stdout, LINK_TABLE_WIDTH);

    while (try res.next()) |msg| {
        var link = Link.init(@intCast(msg.hdr.ifi_index), @truncate(msg.hdr.ifi_type), (msg.hdr.ifi_flags.isSet(nl.link.ifinfo_flags.UP)));

        var attrs = msg.attr_iter();
        while (try attrs.next()) |attr| switch (@as(nl.link.ATTRS.IFLA, @enumFromInt(attr.type))) {
            .ifname => link.name = attr.slice(),
            .address => {
                const addr = attr.slice();
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

    var req = try nlh.new_req(nl.link.GetLinkRequest);
    _ = try req.add_str(@intFromEnum(nl.link.ATTRS.IFLA.ifname), name);
    var msg = try nlh.do(req);
    const index: u32 = @intCast(msg.hdr.ifi_index);
    debug.print("{d:>2}:", .{index});

    var found_name: ?[]const u8 = null;
    var attrs = msg.attr_iter();
    while (try attrs.next()) |attr| switch (@as(nl.link.ATTRS.IFLA, @enumFromInt(attr.type))) {
        .ifname => {
            found_name = attr.slice();
            break;
        },
        else => {},
    };
    debug.print(" {s:<16}\n", .{found_name orelse "<unknown>"});
}

fn add(nlh: *nl.Handle, args: *process.ArgIterator) !void {
    const name = args.next() orelse util.fatal("link name is required\n", .{});
    const type_ = args.next() orelse util.fatal("link type is required\n", .{});
    const parent: u32 = blk: {
        if (args.next()) |parent_name| {
            var req = try nlh.new_req(nl.link.GetLinkRequest);
            _ = try req.add_str(@intFromEnum(linux.IFLA.IFNAME), parent_name);
            const msg = try nlh.do(req);
            break :blk @intCast(msg.hdr.ifi_index);
        } else {
            break :blk 0;
        }
    };

    var req = try nlh.new_req(nl.link.NewLinkRequest);
    req.nlh.*.flags |= (linux.NLM_F_CREATE | linux.NLM_F_EXCL);
    _ = try req.add_str(@intFromEnum(linux.IFLA.IFNAME), name);

    if (mem.eql(u8, type_, "vlan")) {
        if (parent == 0) util.fatal("parent device is required\n", .{});
        const vlan_id_str = args.next() orelse util.fatal("VLAN ID is required\n", .{});
        const vlan_id = try fmt.parseInt(u16, vlan_id_str, 10);

        _ = try req.add_int(u32, @intFromEnum(nl.link.ATTRS.IFLA.link), parent);

        var link_info = try req.add_nested(@intFromEnum(nl.link.ATTRS.IFLA.linkinfo));
        {
            defer link_info.end();
            _ = try req.add_str(@intFromEnum(nl.link.ATTRS.LINKINFO.kind), type_);

            var info_data = try req.add_nested(@intFromEnum(nl.link.ATTRS.LINKINFO.data));
            {
                defer info_data.end();
                // IFLA_VLAN is not in spec
                _ = try req.add_int(u16, c.IFLA_VLAN_ID, vlan_id);
            }
        }
    } else {
        var link_info = try req.add_nested(@intFromEnum(nl.link.ATTRS.IFLA.linkinfo));
        _ = try req.add_str(@intFromEnum(nl.link.ATTRS.LINKINFO.kind), type_);
        link_info.end();
    }

    try nlh.do_ack(req);
}

fn del(nlh: *nl.Handle, args: *process.ArgIterator) !void {
    const name = args.next() orelse util.fatal("link name is required\n", .{});

    var req = try nlh.new_req(nl.link.DelLinkRequest);
    _ = try req.add_str(@intFromEnum(nl.link.ATTRS.IFLA.ifname), name);

    try nlh.do_ack(req);
}

fn set(nlh: *nl.Handle, args: *process.ArgIterator) !void {
    const name = args.next() orelse util.fatal("link name is required\n", .{});

    var req = try nlh.new_req(nl.link.SetLinkRequest);
    _ = try req.add_str(@intFromEnum(nl.link.ATTRS.IFLA.ifname), name);

    var any = false;
    while (args.next()) |arg| {
        any = true;

        if (mem.eql(u8, arg, "up")) {
            req.hdr.ifi_flags.set(nl.link.ifinfo_flags.UP);
            req.hdr.ifi_change = req.hdr.ifi_flags.mask;
        } else {
            util.fatal("unknown attribute {s}\n", .{arg});
        }
    }

    if (!any) util.fatal("must provide one or more attributes\n", .{});

    try nlh.do_ack(req);

    // mac
    //_ = try req.add_str(@intFromEnum(linux.IFLA.ADDRESS), name);
    //c.mnl_attr_put(nlh, c.IFLA_ADDRESS, addr.len, &addr[0]);
}
