//! https://docs.kernel.org/next/userspace-api/netlink/intro.html
const std = @import("std");
const linux = std.os.linux;

const message = @import("message.zig");
pub const Request = message.Request;
pub const Response = message.Response;
pub const AckResponse = message.AckResponse;

pub const addr = @import("rt_addr.zig");
pub const link = @import("rt_link.zig");
pub const route = @import("rt_route.zig");

pub const NewClient = @import("client.zig").NewClient;
pub const DefaultOps = addr.Ops ++ link.Ops ++ route.Ops;
pub const DefaultClient = NewClient(DefaultOps);

const handle = @import("handle.zig");
pub const Handle = handle.Handle;

test {
    std.testing.refAllDecls(@This());
}
