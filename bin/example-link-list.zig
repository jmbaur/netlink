const std = @import("std");
const linux = std.os.linux;
const mem = std.mem;
const os = std.os;

const c = @cImport({
    @cInclude("linux/if.h");
    @cInclude("linux/if_arp.h");
});

const nl = @import("netlink");
const util = @import("util.zig");

const LinkNames = util.SparseList([]u8);

pub fn main() !void {
    var mem_buf = [_]u8{0} ** 1024;
    var fba = std.heap.FixedBufferAllocator.init(&mem_buf);
    var list = try LinkNames.initCapacity(fba.allocator(), 8);

    const sk = try os.socket(linux.AF.NETLINK, linux.SOCK.RAW, linux.NETLINK.ROUTE);
    var buf = [_]u8{0} ** 4096;

    const seq = 0;
    var req = try nl.LinkListRequest.init(seq, &buf);

    req.nlh.*.flags = @intCast(linux.NLM_F_REQUEST | linux.NLM_F_ACK | linux.NLM_F_DUMP);

    req.hdr.*.family = os.AF.PACKET;
    _ = try os.send(sk, req.done(), 0);

    recv: while (true) {
        const n = try os.recv(sk, &buf, 0);
        var res = nl.LinkResponse.init(seq, buf[0..n]);
        while (true) {
            var msg = try res.next();
            switch (msg) {
                .done => break :recv,
                .more => continue :recv,
                .payload => |*payload| {
                    const index: usize = @intCast(payload.value.index);
                    if ((payload.value.flags & c.IFF_UP) != c.IFF_UP) continue;
                    switch (payload.value.type) {
                        c.ARPHRD_ETHER, c.ARPHRD_IPGRE, c.ARPHRD_LOOPBACK, c.ARPHRD_RAWIP, c.ARPHRD_TUNNEL => {},
                        else => continue,
                    }

                    while (try payload.next()) |attr| {
                        switch (attr.type) {
                            @intFromEnum(linux.IFLA.IFNAME) => try list.set(index, try fba.allocator().dupe(u8, attr.slice())),
                            else => {},
                        }
                    }
                },
            }
        }
    }

    for (0.., list.items) |i, item| {
        if (item) |name| std.debug.print("{d:<3} {s:<16}\n", .{ i, name });
    }
}
