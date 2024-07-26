/// This file is generated from the rt-addr spec; do not edit.
const std = @import("std");
pub const msg = @import("message.zig");

pub const ifaddrmsg = extern struct {
    ifa_family: u8,
    ifa_prefixlen: u8,
    ifa_flags: std.bit_set.IntegerBitSet(8),
    ifa_scope: u8,
    ifa_index: u32,
};

pub const ifa_cacheinfo = extern struct {
    ifa_prefered: u32,
    ifa_valid: u32,
    cstamp: u32,
    tstamp: u32,
};

pub const ifa_flags = struct {
    pub const SECONDARY = 0;
    pub const NODAD = 1;
    pub const OPTIMISTIC = 2;
    pub const DADFAILED = 3;
    pub const HOMEADDRESS = 4;
    pub const DEPRECATED = 5;
    pub const TENTATIVE = 6;
    pub const PERMANENT = 7;
    pub const MANAGETEMPADDR = 8;
    pub const NOPREFIXROUTE = 9;
    pub const MCAUTOJOIN = 10;
    pub const STABLE_PRIVACY = 11;
};

pub const ATTRS = struct {
    pub const IFA = enum(u14) {
        address = 1,
        local = 2,
        label = 3,
        broadcast = 4,
        anycast = 5,
        cacheinfo = 6,
        multicast = 7,
        flags = 8,
        rt_priority = 9,
        target_netnsid = 10,
        proto = 11,
    };
};

pub const NewAddrRequest = msg.Request(@enumFromInt(20), ifaddrmsg);
pub const DelAddrRequest = msg.Request(@enumFromInt(21), ifaddrmsg);
pub const GetAddrRequest = msg.Request(@enumFromInt(22), ifaddrmsg);
pub const GetAddrResponse = msg.Response(@enumFromInt(20), ifaddrmsg);

pub const Ops = .{
    .{ NewAddrRequest, msg.AckResponse },
    .{ DelAddrRequest, msg.AckResponse },
    .{ GetAddrRequest, GetAddrResponse },
};
