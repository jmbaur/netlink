const std = @import("std");
const linux = std.os.linux;
const mem = std.mem;
const posix = std.posix;

const c = @cImport({
    @cInclude("linux/if.h");
    @cInclude("linux/if_arp.h");
});

const nl = @import("netlink");
const util = @import("util.zig");

const LinkResponse = nl.Response2(linux.NetlinkMessageType.RTM_NEWLINK, linux.ifinfomsg);
const LinkNames = util.SparseList([]u8);
const Client = nl.NewClient(.{
    .{ nl.LinkListRequest, LinkResponse },
});

pub fn main() !void {
    var mem_buf = [_]u8{0} ** 1024;
    var fba = std.heap.FixedBufferAllocator.init(&mem_buf);
    var list = try LinkNames.initCapacity(fba.allocator(), 8);

    const sk = try posix.socket(linux.AF.NETLINK, linux.SOCK.RAW, linux.NETLINK.ROUTE);
    var buf = [_]u8{0} ** 4096;

    var client = Client.init();
    var req = try client.new_req(nl.LinkListRequest, &buf);

    req.nlh.*.flags |= @intCast(linux.NLM_F_DUMP);
    req.hdr.*.family = linux.AF.PACKET;
    _ = try posix.send(sk, req.done(), 0);
    var res = client.sent_req(req);

    while (res.needs_more_data()) {
        const n = try posix.recv(sk, &buf, 0);
        try res.handle_input(buf[0..n]);
        while (try res.next()) |msg| {
            const index: usize = @intCast(msg.hdr.index);
            if ((msg.hdr.flags & c.IFF_UP) != c.IFF_UP) continue;
            switch (msg.hdr.type) {
                c.ARPHRD_ETHER, c.ARPHRD_IPGRE, c.ARPHRD_LOOPBACK, c.ARPHRD_RAWIP, c.ARPHRD_TUNNEL => {},
                else => continue,
            }

            var iter = msg.attr_iter();
            while (try iter.next()) |attr| switch (attr.type) {
                @intFromEnum(linux.IFLA.IFNAME) => try list.set(index, try fba.allocator().dupe(u8, attr.slice())),
                else => {},
            };
        }
    }

    for (0.., list.items) |i, item| {
        if (item) |name| std.debug.print("{d:<3} {s:<16}\n", .{ i, name });
    }
}
