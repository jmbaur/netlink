//! https://docs.kernel.org/next/userspace-api/netlink/intro.html
const std = @import("std");
const linux = std.os.linux;

const message = @import("message.zig");
pub const Request = message.Request;
pub const Response = message.Response;
pub const Response2 = message.Response2;
pub const route = @import("route.zig");
pub const NewClient = @import("client.zig").NewClient;
pub const DefaultClient = NewClient(route.DefaultRoundTrips);

const handle = @import("handle.zig");
pub const Handle = handle.Handle;

pub const AddrListRequest = Request(linux.NetlinkMessageType.RTM_GETADDR, route.ifaddrmsg);
pub const AddrNewRequest = Request(linux.NetlinkMessageType.RTM_NEWADDR, route.ifaddrmsg);
pub const AddrResponse = Response(linux.NetlinkMessageType.RTM_NEWADDR, route.ifaddrmsg);

pub const LinkListRequest = Request(linux.NetlinkMessageType.RTM_GETLINK, route.rtgenmsg);
pub const LinkGetRequest = Request(linux.NetlinkMessageType.RTM_GETLINK, linux.ifinfomsg);
pub const LinkNewRequest = Request(linux.NetlinkMessageType.RTM_NEWLINK, linux.ifinfomsg);
pub const LinkDelRequest = Request(linux.NetlinkMessageType.RTM_DELLINK, linux.ifinfomsg);
pub const LinkResponse = Response(linux.NetlinkMessageType.RTM_NEWLINK, linux.ifinfomsg);

pub const RouteNewRequest = Request(linux.NetlinkMessageType.RTM_NEWROUTE, route.rtmsg);

test {
    std.testing.refAllDecls(@This());
}
