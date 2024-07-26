/// This file is generated from the rt-route spec; do not edit.
const std = @import("std");
pub const msg = @import("message.zig");

pub const rtm_type = enum(u8) {
    unspec,
    unicast,
    local,
    broadcast,
    anycast,
    multicast,
    blackhole,
    unreachable_,
    prohibit,
    throw,
    nat,
    xresolve,
};

pub const rtmsg = extern struct {
    rtm_family: u8,
    rtm_dst_len: u8,
    rtm_src_len: u8,
    rtm_tos: u8,
    rtm_table: u8,
    rtm_protocol: u8,
    rtm_scope: u8,
    rtm_type: rtm_type,
    rtm_flags: u32,
};

pub const rta_cacheinfo = extern struct {
    rta_clntref: u32,
    rta_lastuse: u32,
    rta_expires: u32,
    rta_error: u32,
    rta_used: u32,
};

pub const GetRouteRequest = msg.Request(@enumFromInt(26), rtmsg);
pub const GetRouteResponse = msg.Response(@enumFromInt(24), rtmsg);
pub const NewRouteRequest = msg.Request(@enumFromInt(24), rtmsg);
pub const DelRouteRequest = msg.Request(@enumFromInt(25), rtmsg);

pub const Ops = .{
    .{ GetRouteRequest, GetRouteResponse },
    .{ NewRouteRequest, msg.AckResponse },
    .{ DelRouteRequest, msg.AckResponse },
};
