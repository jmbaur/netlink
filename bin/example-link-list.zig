const std = @import("std");
const linux = std.os.linux;
const mem = std.mem;
const os = std.os;

const c = @cImport({
    @cInclude("linux/if.h");
    @cInclude("linux/if_arp.h");
});

const nl = @import("netlink");

const LinkNames = SparseList([]u8);
const LinkListRequest = nl.Request(linux.NetlinkMessageType.RTM_GETLINK, rtgenmsg);
const LinkListResponse = nl.Response(linux.NetlinkMessageType.RTM_NEWLINK, linux.ifinfomsg);

const rtgenmsg = extern struct {
    rtgen_family: u8,
};

pub fn main() !void {
    var mem_buf = [_]u8{0} ** 1024;
    var fba = std.heap.FixedBufferAllocator.init(&mem_buf);
    var list = try LinkNames.initCapacity(fba.allocator(), 8);

    var sk = try os.socket(linux.AF.NETLINK, linux.SOCK.RAW, linux.NETLINK.ROUTE);
    var buf = [_]u8{0} ** 4096;

    const seq = 0;
    var req = try LinkListRequest.init(seq, &buf);

    req.nlh.*.flags = @intCast(linux.NLM_F_REQUEST | linux.NLM_F_ACK | linux.NLM_F_DUMP);

    req.hdr.*.rtgen_family = os.AF.PACKET;
    _ = try os.send(sk, req.done(), 0);

    recv: while (true) {
        const n = try os.recv(sk, &buf, 0);
        var res = LinkListResponse.init(seq, buf[0..n]);
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
                            @intFromEnum(linux.IFLA.IFNAME) => try list.set(index, try fba.allocator().dupe(u8, attr.read_slice())),
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

/// This data structures is like `std.ArrayList`, except it initializes all
/// items to `null`.  It is useful for storing links because they are _almost_
/// contiguous.
fn SparseList(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: mem.Allocator,
        items: []?T,

        pub fn init(allocator: mem.Allocator) Self {
            return Self{
                .allocator = allocator,
                .items = &[_]T{},
            };
        }

        pub fn initCapacity(allocator: mem.Allocator, capacity: usize) mem.Allocator.Error!Self {
            var items = try allocator.alloc(?T, capacity);
            for (0..capacity) |i| items.ptr[i] = null;

            return Self{
                .allocator = allocator,
                .items = items,
            };
        }

        pub fn get(self: Self, index: usize) ?T {
            if (index >= self.items.len) return null;
            return self.items[index];
        }

        pub fn set(self: *Self, index: usize, value: T) mem.Allocator.Error!void {
            if (index >= self.items.len) {
                const old_len = self.items.len;
                var new_len = old_len;
                if (new_len == 0) new_len = 1;
                while (new_len <= index) new_len *|= 2;

                if (!self.allocator.resize(self.items, new_len)) {
                    const new_memory = try self.allocator.alignedAlloc(?T, null, new_len);
                    @memcpy(new_memory[0..self.items.len], self.items);
                    self.allocator.free(self.items);
                    self.items = new_memory;
                }

                for (old_len..self.items.len) |i| self.items.ptr[i] = null;
            }
            self.items[index] = value;
        }
    };
}
