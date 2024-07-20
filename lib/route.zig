const std = @import("std");
const linux = std.os.linux;

pub const msg = @import("message.zig");

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

pub const AddrListRequest = msg.Request(linux.NetlinkMessageType.RTM_GETADDR, ifaddrmsg);
pub const AddrNewRequest = msg.Request(linux.NetlinkMessageType.RTM_NEWADDR, ifaddrmsg);
pub const AddrResponse = msg.Response2(linux.NetlinkMessageType.RTM_NEWADDR, ifaddrmsg);

pub const LinkListRequest = msg.Request(linux.NetlinkMessageType.RTM_GETLINK, linux.ifinfomsg);
pub const LinkGetRequest = msg.Request(linux.NetlinkMessageType.RTM_GETLINK, linux.ifinfomsg);
pub const LinkNewRequest = msg.Request(linux.NetlinkMessageType.RTM_NEWLINK, linux.ifinfomsg);
pub const LinkDelRequest = msg.Request(linux.NetlinkMessageType.RTM_DELLINK, linux.ifinfomsg);
pub const LinkResponse = msg.Response2(linux.NetlinkMessageType.RTM_NEWLINK, linux.ifinfomsg);

pub const RouteNewRequest = msg.Request(linux.NetlinkMessageType.RTM_NEWROUTE, rtmsg);

pub const NsidNewRequest = msg.Request(linux.NetlinkMessageType.RTM_NEWNSID, rtgenmsg);

pub const DefaultRoundTrips = .{
    .{ AddrListRequest, AddrResponse },
    .{ AddrNewRequest, msg.AckResponse2 },
    .{ LinkListRequest, LinkResponse },
    .{ LinkGetRequest, LinkResponse },
    .{ LinkNewRequest, msg.AckResponse2 },
    .{ LinkDelRequest, msg.AckResponse2 },
    .{ NsidNewRequest, msg.AckResponse2 },
};
