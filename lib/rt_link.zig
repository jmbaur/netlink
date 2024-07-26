/// This file is generated from the rt-link spec; do not edit.
const std = @import("std");
pub const msg = @import("message.zig");

pub const ifinfo_flags = struct {
    pub const UP = 0;
    pub const BROADCAST = 1;
    pub const DEBUG = 2;
    pub const LOOPBACK = 3;
    pub const POINT_TO_POINT = 4;
    pub const NO_TRAILERS = 5;
    pub const RUNNING = 6;
    pub const NO_ARP = 7;
    pub const PROMISC = 8;
    pub const ALL_MULTI = 9;
    pub const MASTER = 10;
    pub const SLAVE = 11;
    pub const MULTICAST = 12;
    pub const PORTSEL = 13;
    pub const AUTO_MEDIA = 14;
    pub const DYNAMIC = 15;
    pub const LOWER_UP = 16;
    pub const DORMANT = 17;
    pub const ECHO = 18;
};

pub const rtgenmsg = extern struct {
    family: u8,
};

pub const ifinfomsg = extern struct {
    ifi_family: u8,
    pad: [1]u8,
    ifi_type: u16,
    ifi_index: i32,
    ifi_flags: std.bit_set.IntegerBitSet(32),
    ifi_change: u32,
};

pub const ifla_bridge_id = extern struct {
    prio: u16,
    addr: [6]u8,
};

pub const ifla_cacheinfo = extern struct {
    max_reasm_len: u32,
    tstamp: u32,
    reachable_time: i32,
    retrans_time: u32,
};

pub const rtnl_link_stats = extern struct {
    rx_packets: u32,
    tx_packets: u32,
    rx_bytes: u32,
    tx_bytes: u32,
    rx_errors: u32,
    tx_errors: u32,
    rx_dropped: u32,
    tx_dropped: u32,
    multicast: u32,
    collisions: u32,
    rx_length_errors: u32,
    rx_over_errors: u32,
    rx_crc_errors: u32,
    rx_frame_errors: u32,
    rx_fifo_errors: u32,
    rx_missed_errors: u32,
    tx_aborted_errors: u32,
    tx_carrier_errors: u32,
    tx_fifo_errors: u32,
    tx_heartbeat_errors: u32,
    tx_window_errors: u32,
    rx_compressed: u32,
    tx_compressed: u32,
    rx_nohandler: u32,
};

pub const rtnl_link_stats64 = extern struct {
    rx_packets: u64,
    tx_packets: u64,
    rx_bytes: u64,
    tx_bytes: u64,
    rx_errors: u64,
    tx_errors: u64,
    rx_dropped: u64,
    tx_dropped: u64,
    multicast: u64,
    collisions: u64,
    rx_length_errors: u64,
    rx_over_errors: u64,
    rx_crc_errors: u64,
    rx_frame_errors: u64,
    rx_fifo_errors: u64,
    rx_missed_errors: u64,
    tx_aborted_errors: u64,
    tx_carrier_errors: u64,
    tx_fifo_errors: u64,
    tx_heartbeat_errors: u64,
    tx_window_errors: u64,
    rx_compressed: u64,
    tx_compressed: u64,
    rx_nohandler: u64,
    rx_otherhost_dropped: u64,
};

pub const rtnl_link_ifmap = extern struct {
    mem_start: u64,
    mem_end: u64,
    base_addr: u64,
    irq: u16,
    dma: u8,
    port: u8,
};

pub const ipv4_devconf = extern struct {
    forwarding: u32,
    mc_forwarding: u32,
    proxy_arp: u32,
    accept_redirects: u32,
    secure_redirects: u32,
    send_redirects: u32,
    shared_media: u32,
    rp_filter: u32,
    accept_source_route: u32,
    bootp_relay: u32,
    log_martians: u32,
    tag: u32,
    arpfilter: u32,
    medium_id: u32,
    noxfrm: u32,
    nopolicy: u32,
    force_igmp_version: u32,
    arp_announce: u32,
    arp_ignore: u32,
    promote_secondaries: u32,
    arp_accept: u32,
    arp_notify: u32,
    accept_local: u32,
    src_vmark: u32,
    proxy_arp_pvlan: u32,
    route_localnet: u32,
    igmpv2_unsolicited_report_interval: u32,
    igmpv3_unsolicited_report_interval: u32,
    ignore_routes_with_linkdown: u32,
    drop_unicast_in_l2_multicast: u32,
    drop_gratuitous_arp: u32,
    bc_forwarding: u32,
    arp_evict_nocarrier: u32,
};

pub const ipv6_devconf = extern struct {
    forwarding: u32,
    hoplimit: u32,
    mtu6: u32,
    accept_ra: u32,
    accept_redirects: u32,
    autoconf: u32,
    dad_transmits: u32,
    rtr_solicits: u32,
    rtr_solicit_interval: u32,
    rtr_solicit_delay: u32,
    use_tempaddr: u32,
    temp_valid_lft: u32,
    temp_prefered_lft: u32,
    regen_max_retry: u32,
    max_desync_factor: u32,
    max_addresses: u32,
    force_mld_version: u32,
    accept_ra_defrtr: u32,
    accept_ra_pinfo: u32,
    accept_ra_rtr_pref: u32,
    rtr_probe_interval: u32,
    accept_ra_rt_info_max_plen: u32,
    proxy_ndp: u32,
    optimistic_dad: u32,
    accept_source_route: u32,
    mc_forwarding: u32,
    disable_ipv6: u32,
    accept_dad: u32,
    force_tllao: u32,
    ndisc_notify: u32,
    mldv1_unsolicited_report_interval: u32,
    mldv2_unsolicited_report_interval: u32,
    suppress_frag_ndisc: u32,
    accept_ra_from_local: u32,
    use_optimistic: u32,
    accept_ra_mtu: u32,
    stable_secret: u32,
    use_oif_addrs_only: u32,
    accept_ra_min_hop_limit: u32,
    ignore_routes_with_linkdown: u32,
    drop_unicast_in_l2_multicast: u32,
    drop_unsolicited_na: u32,
    keep_addr_on_down: u32,
    rtr_solicit_max_interval: u32,
    seg6_enabled: u32,
    seg6_require_hmac: u32,
    enhanced_dad: u32,
    addr_gen_mode: u8,
    disable_policy: u32,
    accept_ra_rt_info_min_plen: u32,
    ndisc_tclass: u32,
    rpl_seg_enabled: u32,
    ra_defrtr_metric: u32,
    ioam6_enabled: u32,
    ioam6_id: u32,
    ioam6_id_wide: u32,
    ndisc_evict_nocarrier: u32,
    accept_untracked_na: u32,
};

pub const ifla_icmp6_stats = extern struct {
    inmsgs: u64,
    inerrors: u64,
    outmsgs: u64,
    outerrors: u64,
    csumerrors: u64,
    ratelimithost: u64,
};

pub const ifla_inet6_stats = extern struct {
    inpkts: u64,
    inoctets: u64,
    indelivers: u64,
    outforwdatagrams: u64,
    outpkts: u64,
    outoctets: u64,
    inhdrerrors: u64,
    intoobigerrors: u64,
    innoroutes: u64,
    inaddrerrors: u64,
    inunknownprotos: u64,
    intruncatedpkts: u64,
    indiscards: u64,
    outdiscards: u64,
    outnoroutes: u64,
    reasmtimeout: u64,
    reasmreqds: u64,
    reasmoks: u64,
    reasmfails: u64,
    fragoks: u64,
    fragfails: u64,
    fragcreates: u64,
    inmcastpkts: u64,
    outmcastpkts: u64,
    inbcastpkts: u64,
    outbcastpkts: u64,
    inmcastoctets: u64,
    outmcastoctets: u64,
    inbcastoctets: u64,
    outbcastoctets: u64,
    csumerrors: u64,
    noectpkts: u64,
    ect1_pkts: u64,
    ect0_pkts: u64,
    cepkts: u64,
    reasm_overlaps: u64,
};

pub const br_boolopt_multi = extern struct {
    optval: u32,
    optmask: u32,
};

pub const if_stats_msg = extern struct {
    family: u8,
    pad: [3]u8,
    ifindex: u32,
    filter_mask: u32,
};

pub const NewLinkRequest = msg.Request(@enumFromInt(16), ifinfomsg);
pub const DelLinkRequest = msg.Request(@enumFromInt(17), ifinfomsg);
pub const GetLinkRequest = msg.Request(@enumFromInt(18), ifinfomsg);
pub const GetLinkResponse = msg.Response(@enumFromInt(16), ifinfomsg);
pub const SetLinkRequest = msg.Request(@enumFromInt(19), ifinfomsg);
pub const GetStatsRequest = msg.Request(@enumFromInt(94), if_stats_msg);
pub const GetStatsResponse = msg.Response(@enumFromInt(92), if_stats_msg);

pub const Ops = .{
    .{ NewLinkRequest, msg.AckResponse },
    .{ DelLinkRequest, msg.AckResponse },
    .{ GetLinkRequest, GetLinkResponse },
    .{ SetLinkRequest, msg.AckResponse },
    .{ GetStatsRequest, GetStatsResponse },
};
