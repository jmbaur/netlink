# netlink

A low-level library for creating and parsing netlink messages.  Inspired by
[libmnl][].

While this library is a decent replacement for [libmnl][], it is nowhere near
the scope of libraries like [libnl][].

There is also a program that reimplements some functionality of `iproute2`, but
its primary purpose is to verify that the library works.


## Usage

`Request` and `Response` are `comptime` functions that wrap a type which is
transferred over an `AF_NETLINK` socket, e.g. `rtgenmsg` and `ifinfomsg`.  Both
are backed by a buffer so that appending `nlattr`s does not require allocation.

So to create a new link, create a new type for that specific request:
```zig
const std = @import("std");
const nl = @import("netlink");
const linux = std.os.linux;

const LinkNewRequest = nl.Request(linux.NetlinkMessageType.RTM_NEWLINK, linux.ifinfomsg);

var buf = [_]u8{0} ** 128;
var req = LinkListRequest.init(&buf);
req.nlh.*.flags |= (linux.NLM_F_CREATE | linux.NLM_F_EXCL);

const name: [:0]u8 = "asdf";
_ = try req.add_str(@intFromEnum(linux.IFLA.IFNAME), name);
_ = req.done(); // Finalize the request by setting its length.
```

The `Response` type is created similarly, but supports an iterator pattern
for traversing multiple messages in a single response and each message's
attributes.

```zig
const LinkListResponse = nl.Response(linux.NetlinkMessageType.RTM_NEWLINK, linux.ifinfomsg);

const seq = 0;
const buf: []u8 = ""; // say this contains a netlink response
var res = LinkListResponse.init(seq, buf);

while (true) {
    var msg = try res.next();
    switch (msg) {
        // No more messages in this sequence are expected, and all future calls
        // of `res.next()` will return `.done`.
        .done => {},
        // There are more messages, but not in the current buffer.  You need to
        // call `std.os.recv()` on the netlink socket again and recreate `res`.
        .more => {},
        // The message contained the `Response`'s inner message type (e.g.
        // `ifinfomsg`).
        // The capture should _always_ be a pointer.
        .payload => |*payload| {
            while (try payload.next()) |attr| {
                if (attr.type == @intFromEnum(linux.IFLA.IFNAME)) std.debug.print("{s}\n", .{attr.read_slice()});
            }
        },
    }
}
```

The `Handle` structure wraps a netlink socket and byte buffer and reduces
boilerplate required when receiving and parsing messages.  Because when using
`NLM_F_ACK`, the client should check that a message sequence is terminated by a
`NLMSG_DONE` or `NLMSG_ERROR` message.


## Example

```zig
const std = @import("std");
const nl = @import("netlink");

const rtgenmsg = extern struct {
    rtgen_family: u8,
};

const LinkListRequest = nl.message.Request(linux.NetlinkMessageType.RTM_GETLINK, rtgenmsg);
const LinkResponse = nl.message.Response(linux.NetlinkMessageType.RTM_NEWLINK, std.os.linux.ifinfomsg);

var buf = [_]u8{0} ** 4096;
var sk = try std.os.socket(std.os.linux.AF.NETLINK, std.os.linux.SOCK.RAW, std.os.linux.NETLINK.ROUTE);
defer std.os.close(sk);
var nlh = nl.Handle.init(sk, &buf);

var req = try nlh.new_req(LinkListRequest);
req.hdr.*.rtgen_family = std.os.AF.PACKET;
req.nlh.*.flags |= std.os.linux.NLM_F_DUMP;
try nlh.send(req);

var res = nlh.recv_all(LinkResponse);
while (try res.next()) |payload| {
    std.debug.print("{}\n", .{payload.value.index});
}
```

There is plenty more example code in the `bin/` directory.


## Code Generation

```
$ export KERNEL_PATH=...
$ export PYTHONPATH="${KERNEL_PATH}/tools/net/ynl/lib"
$ for name in rt_addr rt_link rt_route; do ./gen.py ${KERNEL_PATH}/Documentation/netlink/specs/${name}.yaml > lib/${name}.zig && zig fmt lib/${name}.zig; done
```




[libmnl]: https://netfilter.org/projects/libmnl/
[libnl]: https://www.infradead.org/~tgr/libnl/
