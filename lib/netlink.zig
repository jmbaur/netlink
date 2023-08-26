//! https://docs.kernel.org/next/userspace-api/netlink/intro.html

pub const message = @import("message.zig");
pub const Request = message.Request;
pub const Response = message.Response;

const handle = @import("handle.zig");
pub const Handle = handle.Handle;

test {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
