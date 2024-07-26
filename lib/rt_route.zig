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

pub const ATTRS = struct {
    pub const ROUTE = enum(u14) {
        dst = 1,
        src = 2,
        iif = 3,
        oif = 4,
        gateway = 5,
        priority = 6,
        prefsrc = 7,
        metrics = 8,
        multipath = 9,
        protoinfo = 10,
        flow = 11,
        cacheinfo = 12,
        session = 13,
        mp_algo = 14,
        table = 15,
        mark = 16,
        mfc_stats = 17,
        via = 18,
        newdst = 19,
        pref = 20,
        encap_type = 21,
        encap = 22,
        expires = 23,
        pad = 24,
        uid = 25,
        ttl_propagate = 26,
        ip_proto = 27,
        sport = 28,
        dport = 29,
        nh_id = 30,
    };

    pub const RTA_METRICS = enum(u14) {
        unspec = 0,
        lock = 1,
        mtu = 2,
        window = 3,
        rtt = 4,
        rttvar = 5,
        ssthresh = 6,
        cwnd = 7,
        advmss = 8,
        reordering = 9,
        hoplimit = 10,
        initcwnd = 11,
        features = 12,
        rto_min = 13,
        initrwnd = 14,
        quickack = 15,
        cc_algo = 16,
        fastopen_no_cookie = 17,
    };
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
