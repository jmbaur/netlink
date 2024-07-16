//! https://docs.kernel.org/next/userspace-api/netlink/intro.html
const std = @import("std");
const linux = std.os.linux;

pub const message = @import("message.zig");
pub const Request = message.Request;
pub const Response = message.Response;
pub const Response2 = message.Response2;
pub const NewClient = @import("client.zig").NewClient;

const handle = @import("handle.zig");
pub const Handle = handle.Handle;

pub const ifaddrmsg = extern struct {
    family: u8,
    prefixlen: u8,
    flags: u8,
    scope: u8,
    index: u32,
};

pub const rtgenmsg = extern struct {
    family: u8,
};

pub const rtmsg = extern struct {
    family: u8,
    dst_len: u8,
    src_len: u8,
    tos: u8,

    table: u8,
    protocol: u8,
    scope: u8,
    type: u8,

    flags: u16,
};

pub const AddrListRequest = Request(linux.NetlinkMessageType.RTM_GETADDR, ifaddrmsg);
pub const AddrNewRequest = Request(linux.NetlinkMessageType.RTM_NEWADDR, ifaddrmsg);
pub const AddrResponse = Response(linux.NetlinkMessageType.RTM_NEWADDR, ifaddrmsg);

pub const LinkListRequest = Request(linux.NetlinkMessageType.RTM_GETLINK, rtgenmsg);
pub const LinkGetRequest = Request(linux.NetlinkMessageType.RTM_GETLINK, linux.ifinfomsg);
pub const LinkNewRequest = Request(linux.NetlinkMessageType.RTM_NEWLINK, linux.ifinfomsg);
pub const LinkDelRequest = Request(linux.NetlinkMessageType.RTM_DELLINK, linux.ifinfomsg);
pub const LinkResponse = Response(linux.NetlinkMessageType.RTM_NEWLINK, linux.ifinfomsg);

pub const RouteNewRequest = Request(linux.NetlinkMessageType.RTM_NEWROUTE, rtmsg);

test {
    std.testing.refAllDecls(@This());
}
