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

pub const ATTRS = struct {
    pub const IFLA = enum(u14) {
        address = 1,
        broadcast = 2,
        ifname = 3,
        mtu = 4,
        link = 5,
        qdisc = 6,
        stats = 7,
        cost = 8,
        priority = 9,
        master = 10,
        wireless = 11,
        protinfo = 12,
        txqlen = 13,
        map = 14,
        weight = 15,
        operstate = 16,
        linkmode = 17,
        linkinfo = 18,
        net_ns_pid = 19,
        ifalias = 20,
        num_vf = 21,
        vfinfo_list = 22,
        stats64 = 23,
        vf_ports = 24,
        port_self = 25,
        af_spec = 26,
        group = 27,
        net_ns_fd = 28,
        ext_mask = 29,
        promiscuity = 30,
        num_tx_queues = 31,
        num_rx_queues = 32,
        carrier = 33,
        phys_port_id = 34,
        carrier_changes = 35,
        phys_switch_id = 36,
        link_netnsid = 37,
        phys_port_name = 38,
        proto_down = 39,
        gso_max_segs = 40,
        gso_max_size = 41,
        pad = 42,
        xdp = 43,
        event = 44,
        new_netnsid = 45,
        target_netnsid = 46,
        carrier_up_count = 47,
        carrier_down_count = 48,
        new_ifindex = 49,
        min_mtu = 50,
        max_mtu = 51,
        prop_list = 52,
        alt_ifname = 53,
        perm_address = 54,
        proto_down_reason = 55,
        parent_dev_name = 56,
        parent_dev_bus_name = 57,
        gro_max_size = 58,
        tso_max_size = 59,
        tso_max_segs = 60,
        allmulti = 61,
        devlink_port = 62,
        gso_ipv4_max_size = 63,
        gro_ipv4_max_size = 64,
    };

    pub const AF_SPEC = enum(u14) {
        inet = 2,
        inet6 = 10,
        mctp = 45,
    };

    pub const VFINFO = enum(u14) { _ };

    pub const VF_PORTS = enum(u14) { _ };

    pub const PORT_SELF = enum(u14) { _ };

    pub const LINKINFO = enum(u14) {
        kind = 1,
        data = 2,
        xstats = 3,
        slave_kind = 4,
        slave_data = 5,
    };

    pub const IFLA_BR = enum(u14) {
        forward_delay = 1,
        hello_time = 2,
        max_age = 3,
        ageing_time = 4,
        stp_state = 5,
        priority = 6,
        vlan_filtering = 7,
        vlan_protocol = 8,
        group_fwd_mask = 9,
        root_id = 10,
        bridge_id = 11,
        root_port = 12,
        root_path_cost = 13,
        topology_change = 14,
        topology_change_detected = 15,
        hello_timer = 16,
        tcn_timer = 17,
        topology_change_timer = 18,
        gc_timer = 19,
        group_addr = 20,
        fdb_flush = 21,
        mcast_router = 22,
        mcast_snooping = 23,
        mcast_query_use_ifaddr = 24,
        mcast_querier = 25,
        mcast_hash_elasticity = 26,
        mcast_hash_max = 27,
        mcast_last_member_cnt = 28,
        mcast_startup_query_cnt = 29,
        mcast_last_member_intvl = 30,
        mcast_membership_intvl = 31,
        mcast_querier_intvl = 32,
        mcast_query_intvl = 33,
        mcast_query_response_intvl = 34,
        mcast_startup_query_intvl = 35,
        nf_call_iptables = 36,
        nf_call_ip6_tables = 37,
        nf_call_arptables = 38,
        vlan_default_pvid = 39,
        pad = 40,
        vlan_stats_enabled = 41,
        mcast_stats_enabled = 42,
        mcast_igmp_version = 43,
        mcast_mld_version = 44,
        vlan_stats_per_port = 45,
        multi_boolopt = 46,
        mcast_querier_state = 47,
    };

    pub const IFLA_BRPORT = enum(u14) {
        state = 1,
        priority = 2,
        cost = 3,
        mode = 4,
        guard = 5,
        protect = 6,
        fast_leave = 7,
        learning = 8,
        unicast_flood = 9,
        proxyarp = 10,
        learning_sync = 11,
        proxyarp_wifi = 12,
        root_id = 13,
        bridge_id = 14,
        designated_port = 15,
        designated_cost = 16,
        id = 17,
        no = 18,
        topology_change_ack = 19,
        config_pending = 20,
        message_age_timer = 21,
        forward_delay_timer = 22,
        hold_timer = 23,
        flush = 24,
        multicast_router = 25,
        pad = 26,
        mcast_flood = 27,
        mcast_to_ucast = 28,
        vlan_tunnel = 29,
        bcast_flood = 30,
        group_fwd_mask = 31,
        neigh_suppress = 32,
        isolated = 33,
        backup_port = 34,
        mrp_ring_open = 35,
        mrp_in_open = 36,
        mcast_eht_hosts_limit = 37,
        mcast_eht_hosts_cnt = 38,
        locked = 39,
        mab = 40,
        mcast_n_groups = 41,
        mcast_max_groups = 42,
        neigh_vlan_suppress = 43,
        backup_nhid = 44,
    };

    pub const IFLA_GRE = enum(u14) {
        link = 1,
        iflags = 2,
        oflags = 3,
        ikey = 4,
        okey = 5,
        local = 6,
        remote = 7,
        ttl = 8,
        tos = 9,
        pmtudisc = 10,
        encap_limit = 11,
        flowinfo = 12,
        flags = 13,
        encap_type = 14,
        encap_flags = 15,
        encap_sport = 16,
        encap_dport = 17,
        collect_metadata = 18,
        ignore_df = 19,
        fwmark = 20,
        erspan_index = 21,
        erspan_ver = 22,
        erspan_dir = 23,
        erspan_hwid = 24,
    };

    pub const IFLA_GENEVE = enum(u14) {
        id = 1,
        remote = 2,
        ttl = 3,
        tos = 4,
        port = 5,
        collect_metadata = 6,
        remote6 = 7,
        udp_csum = 8,
        udp_zero_csum6_tx = 9,
        udp_zero_csum6_rx = 10,
        label = 11,
        ttl_inherit = 12,
        df = 13,
        inner_proto_inherit = 14,
    };

    pub const IFLA_IPTUN = enum(u14) {
        link = 1,
        local = 2,
        remote = 3,
        ttl = 4,
        tos = 5,
        encap_limit = 6,
        flowinfo = 7,
        flags = 8,
        proto = 9,
        pmtudisc = 10,
        @"6rd_prefix" = 11,
        @"6rd_relay_prefix" = 12,
        @"6rd_prefixlen" = 13,
        @"6rd_relay_prefixlen" = 14,
        encap_type = 15,
        encap_flags = 16,
        encap_sport = 17,
        encap_dport = 18,
        collect_metadata = 19,
        fwmark = 20,
    };

    pub const IFLA_TUN = enum(u14) {
        owner = 1,
        group = 2,
        type = 3,
        pi = 4,
        vnet_hdr = 5,
        persist = 6,
        multi_queue = 7,
        num_queues = 8,
        num_disabled_queues = 9,
    };

    pub const IFLA_VRF = enum(u14) {
        table = 1,
    };

    pub const XDP = enum(u14) {
        fd = 1,
        attached = 2,
        flags = 3,
        prog_id = 4,
        drv_prog_id = 5,
        skb_prog_id = 6,
        hw_prog_id = 7,
        expected_fd = 8,
    };

    pub const IFLA_INET = enum(u14) {
        conf = 1,
    };

    pub const IFLA_INET6 = enum(u14) {
        flags = 1,
        conf = 2,
        stats = 3,
        mcast = 4,
        cacheinfo = 5,
        icmp6_stats = 6,
        token = 7,
        addr_gen_mode = 8,
        ra_mtu = 9,
    };

    pub const MCTP = enum(u14) {
        net = 1,
    };

    pub const IFLA_STATS = enum(u14) {
        link_64 = 1,
        link_xstats = 2,
        link_xstats_slave = 3,
        link_offload_xstats = 4,
        af_spec = 5,
    };

    pub const LINK_OFFLOAD_XSTATS = enum(u14) {
        cpu_hit = 1,
        hw_s_info = 2,
        l3_stats = 3,
    };

    pub const HW_S_INFO_ONE = enum(u14) {
        request = 1,
        used = 2,
    };
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
