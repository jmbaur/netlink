const std = @import("std");
const debug = std.debug;
const linux = std.os.linux;
const mem = std.mem;
const posix = std.posix;

pub fn nl_align(len: usize) usize {
    return mem.alignForward(usize, len, linux.rtattr.ALIGNTO);
}

pub const NLMSG_HDRLEN = nl_align(@sizeOf(linux.nlmsghdr));

pub fn parse_nlmsghdr(buf: []const u8) !*const linux.nlmsghdr {
    if (buf.len < NLMSG_HDRLEN) return error.OutOfMemory;
    const nlh: *const linux.nlmsghdr = @ptrCast(@alignCast(buf.ptr));
    if (nlh.len < NLMSG_HDRLEN) return error.InvalidMessage;
    if (nlh.len > buf.len) return error.OutOfMemory;
    return nlh;
}

pub const nlmsgerr = extern struct {
    code: c_int,
    msg: linux.nlmsghdr,
};

pub const AckResponse = Response(linux.NetlinkMessageType.ERROR, linux.nlmsghdr);
pub const AckResponse2 = Response2(linux.NetlinkMessageType.ERROR, linux.nlmsghdr);

pub const Attr = packed struct {
    len: u16,
    // Note to self: to support big endian machines, I think I could use @Type()
    // to reorder these fields.
    type: u14,
    net_byteorder: bool,
    nested: bool,

    pub fn init_read(buf: []const u8) error{OutOfMemory}!*const Attr {
        if (buf.len < @sizeOf(Attr)) return error.OutOfMemory;
        const attr: *const Attr = @ptrCast(@alignCast(buf.ptr));
        if (buf.len < attr.len) return error.OutOfMemory;
        return attr;
    }

    pub fn init_write(buf: []u8) error{OutOfMemory}!*Attr {
        if (buf.len < @sizeOf(Attr)) return error.OutOfMemory;
        const attr: *Attr = @ptrCast(@alignCast(buf.ptr));
        attr.len = @intCast(buf.len);
        attr.type = 0;
        attr.net_byteorder = false;
        attr.nested = false;
        return attr;
    }

    pub fn size(self: Attr) u16 {
        return self.len - @sizeOf(Attr);
    }

    pub fn int(self: *Attr, comptime T: type) error{InvalidAttrCast}!*T {
        if (@sizeOf(T) + @sizeOf(Attr) != self.len) return error.InvalidAttrCast;
        const start: [*]u8 = @ptrCast(self);
        return @ptrCast(@alignCast(start + @sizeOf(Attr)));
    }

    pub fn slice(self: anytype) switch (@TypeOf(self)) {
        *Attr => []u8,
        *const Attr => []const u8,
        else => unreachable,
    } {
        const start: [*]u8 = @ptrCast(@constCast(self));
        return start[@sizeOf(Attr)..self.len];
    }
};

test "Attr bit fields" {
    const native_endian = @import("builtin").cpu.arch.endian();
    const expect = std.testing.expect;
    const expectEqual = std.testing.expectEqual;

    switch (native_endian) {
        .Little => {
            var actual = [_]u8{ 4, 0, 3, 0 };
            var expected = actual;
            const end: usize = 4;
            const attr = try Attr.init_read(actual[0..end]);

            try expectEqual(attr.len, 4);
            try expectEqual(attr.type, 3);
            try expectEqual(false, attr.nested);
            try expectEqual(false, attr.net_byteorder);

            attr.*.nested = true;
            expected[3] = 0x80;
            try expectEqual(expected, actual);

            attr.*.type = 300;
            expected[2] = 300 & 0x00ff;
            expected[3] |= (300 & 0xff00) >> 8;
            try expectEqual(expected, actual);

            attr.*.net_byteorder = true;
            expected[3] |= 0x40;
            try expectEqual(expected, actual);
        },
        .Big => {
            // TODO: test this in an emulator
            try expect(false);
        },
    }
}

pub const NestedAttr = struct {
    attr: *Attr,
    start: usize,
    index: *usize,

    pub fn end(self: NestedAttr) void {
        self.attr.*.len = @intCast(self.index.* - self.start);
    }
};

fn put_type(comptime T: type, buf: []u8) error{OutOfMemory}!*T {
    if (nl_align(@sizeOf(T)) > buf.len) return error.OutOfMemory;
    return @ptrCast(@alignCast(buf.ptr));
}

pub fn Request(comptime nlmsg_type: linux.NetlinkMessageType, comptime T: type) type {
    return struct {
        // These fields are meant to be accessed by users.
        nlh: *linux.nlmsghdr,
        hdr: *T,
        // These fields should be considered private.
        i: usize,
        buf: []u8,

        const Self = @This();

        pub fn init(buf: []u8) error{OutOfMemory}!Self {
            const nlh = try put_type(linux.nlmsghdr, buf);
            nlh.len = 0; // This will be set when `done()` is called.
            nlh.type = nlmsg_type;
            nlh.flags = @intCast(linux.NLM_F_REQUEST);
            nlh.seq = 0;
            nlh.pid = 0;
            const hdr = try put_type(T, buf[NLMSG_HDRLEN..]);
            const hdr_len = nl_align(@sizeOf(T));
            @memset(buf[NLMSG_HDRLEN..][0..hdr_len], 0);

            return Self{
                .nlh = nlh,
                .hdr = hdr,
                .i = NLMSG_HDRLEN + hdr_len,
                .buf = buf,
            };
        }

        pub fn init_seq(seq: u16, buf: []u8) error{OutOfMemory}!Self {
            const req = try Self.init(buf);
            req.nlh.seq = seq;
            return req;
        }

        // `nlattr.nla_len` includes the size of the header, but the `len`
        // argument should only measure the data length.
        pub fn add_attr(self: *Self, type_: u14, len: u16) error{OutOfMemory}!*Attr {
            const total_len = len + @sizeOf(Attr);
            const aligned_len = nl_align(total_len);

            if (aligned_len > self.buf.len - self.i) return error.OutOfMemory;
            // Because the aligned length is strictly greater than the actual
            // length, allocating the Attr will not fail.
            const attr = Attr.init_write(self.buf[self.i .. self.i + total_len]) catch unreachable;
            attr.*.type = type_;
            self.i += aligned_len;
            return attr;
        }

        pub fn add_bytes(self: *Self, type_: u14, bytes: []const u8) error{OutOfMemory}!*Attr {
            var attr = try self.add_attr(type_, @intCast(bytes.len));
            const dst = attr.slice();
            debug.assert(dst.len == bytes.len);
            @memcpy(dst, bytes);
            return attr;
        }

        pub fn add_empty(self: *Self, type_: u14) error{OutOfMemory}!*Attr {
            return try self.add_attr(type_, 0);
        }

        pub fn add_int(self: *Self, comptime Int: type, type_: u14, val: Int) error{OutOfMemory}!*Attr {
            const attr = try self.add_attr(type_, @sizeOf(Int));
            (attr.int(Int) catch unreachable).* = val;
            return attr;
        }

        pub fn add_nested(self: *Self, type_: u14) error{OutOfMemory}!NestedAttr {
            const start = self.i;
            const attr = try self.add_empty(type_);
            return NestedAttr{
                .attr = attr,
                .start = start,
                .index = &self.i,
            };
        }

        pub fn add_str(self: *Self, type_: u14, str: [:0]const u8) error{OutOfMemory}!*Attr {
            var attr = try self.add_attr(type_, @intCast(str.len + 1));
            const dst = attr.slice();
            debug.assert(dst.len == str.len + 1);
            @memcpy(dst, str[0 .. str.len + 1]);
            return attr;
        }

        pub fn done(self: Self) []u8 {
            self.nlh.*.len = @intCast(self.i);
            return self.buf[0..self.i];
        }
    };
}

pub fn Response(comptime nlmsg_type: linux.NetlinkMessageType, comptime T: type) type {
    return struct {
        i: usize,
        done: bool,
        buf: []u8,
        seq: u32,

        pub const Payload = struct {
            value: *T,
            attrs: []u8,
            i: usize,

            fn init(value: *T, attrs: []u8) Payload {
                return Payload{ .value = value, .attrs = attrs, .i = 0 };
            }

            pub fn next(self: *Payload) !?*const Attr {
                if (self.i >= self.attrs.len) return null;

                const attr = try Attr.init_read(self.attrs[self.i..]);
                if (attr.len == 0) return error.InvalidResponse;

                self.i += nl_align(attr.len);
                return attr;
            }
        };

        pub const Message = union(enum) {
            done: void,
            more: void,
            payload: Payload,
        };

        const Self = @This();

        pub fn init(seq: u32, buf: []u8) Self {
            return Self{
                .i = 0,
                .done = false,
                .buf = buf,
                .seq = seq,
            };
        }

        pub fn next(self: *Self) !Message {
            if (self.done) return Message{ .done = void{} };
            if (self.i >= self.buf.len) return Message{ .more = void{} };

            if (self.buf.len < @sizeOf(linux.nlmsghdr)) return error.InvalidResponse;

            const start = self.i;
            const nlh: *linux.nlmsghdr = @ptrCast(@alignCast(self.buf.ptr + start));
            if (nlh.len < @sizeOf(linux.nlmsghdr) or nlh.len > self.buf.len) return error.InvalidResponse;

            const len = mem.alignForward(usize, nlh.len, linux.rtattr.ALIGNTO);
            self.*.i += len;

            if (nlh.seq != self.seq) return error.InvalidResponse;

            switch (nlh.*.type) {
                .DONE => {
                    self.*.done = true;
                    return Message{ .done = void{} };
                },
                .ERROR => {
                    const payload: *nlmsgerr = @ptrCast(@alignCast(self.buf.ptr + start + NLMSG_HDRLEN));
                    const code = if (payload.*.code >= 0) payload.*.code else -payload.*.code;
                    self.*.done = true;
                    const errno: linux.E = @enumFromInt(code);
                    switch (errno) {
                        .SUCCESS => if (nlmsg_type == linux.NetlinkMessageType.ERROR) {
                            return Message{ .payload = Payload.init(&payload.*.msg, &[_]u8{}) };
                        } else {
                            return Message{ .done = void{} };
                        },
                        .EXIST => return error.AlreadyExists,
                        .INVAL => return error.InvalidRequest,
                        .NODEV => return error.NoDevice,
                        .OPNOTSUPP => return error.NotSupported,
                        .PERM => return error.AccessDenied,
                        else => |err| return posix.unexpectedErrno(err),
                    }
                },
                else => |type_| {
                    if (type_ != nlmsg_type) return error.UnexpectedType;

                    const value: *T = @ptrCast(@alignCast(self.buf.ptr + start + NLMSG_HDRLEN));
                    const attr_start = start + NLMSG_HDRLEN + mem.alignForward(usize, @sizeOf(T), linux.rtattr.ALIGNTO);
                    const attr_end = start + len;
                    return Message{ .payload = Payload.init(value, self.buf[attr_start..attr_end]) };
                },
            }
        }
    };
}

/// This is a read-only iterator for attributes of a response message.
pub const AttrIter = struct {
    i: usize,
    buf: []const u8,

    fn init(buf: []const u8) AttrIter {
        return AttrIter{ .buf = buf, .i = 0 };
    }

    pub fn next(self: *AttrIter) !?*const Attr {
        if (self.i >= self.buf.len) return null;

        const attr = try Attr.init_read(self.buf[self.i..]);
        if (attr.len == 0) return error.InvalidResponse;

        self.i += nl_align(attr.len);
        return attr;
    }
};

pub const ParseError = error{
    InvalidMessage,
    OutOfMemory,
};

pub fn Response2(comptime nlmsg_type: linux.NetlinkMessageType, comptime T: type) type {
    return struct {
        // These fields are meant to be accessed by users.
        nlh: *const linux.nlmsghdr,
        hdr: *const T,
        // These fields should be considered private.
        rest: []const u8,

        const Self = @This();

        pub const TYPE = nlmsg_type;

        pub fn attr_iter(self: Self) AttrIter {
            return AttrIter.init(self.rest);
        }

        pub fn attr_table(self: Self, comptime max: usize) [max]?*const Attr {
            var table = [_]?*const Attr{null} * max + 1;
            var iter = self.attr_iter();
            while (iter.next()) |attr| {
                debug.assert(attr.type <= max);
                table[attr.type] = attr;
            }
            return table;
        }

        pub fn init(buf: []const u8) ParseError!Self {
            const nlh = try parse_nlmsghdr(buf);
            if (nlh.type != Self.TYPE) return error.InvalidMessage;

            const hdr_len = NLMSG_HDRLEN + nl_align(@sizeOf(T));
            if (buf.len < hdr_len) return error.OutOfMemory;
            if (nlh.len < hdr_len) return error.InvalidMessage;

            const hdr: *const T = @ptrCast(@alignCast(buf.ptr + NLMSG_HDRLEN));
            return Self{
                .nlh = nlh,
                .hdr = hdr,
                .rest = buf[hdr_len..nlh.len],
            };
        }

        pub fn size(self: Self) usize {
            return nl_align(self.nlh.len);
        }
    };
}

test "build RTM_NEWLINK request" {
    const testing = std.testing;
    // linux/if_link.h
    const IFLA_INFO_KIND = 1;

    var buf: [128]u8 = undefined;
    const LinkNewRequest = Request(linux.NetlinkMessageType.RTM_NEWLINK, linux.ifinfomsg);
    var req = try LinkNewRequest.init(1, &buf);

    const name = "new-device";
    const type_ = "dummy";

    {
        const attr = try req.add_str(@intFromEnum(linux.IFLA.IFNAME), name);
        const len = @sizeOf(Attr) + name.len + 1;
        try testing.expectEqual(len, attr.len);
    }

    var link_info = try req.add_nested(@intFromEnum(linux.IFLA.LINKINFO));
    try testing.expectEqual(link_info.attr.len, @sizeOf(Attr));
    var nested_len = nl_align(link_info.attr.len);

    {
        const attr = try req.add_str(IFLA_INFO_KIND, type_);
        const len = @sizeOf(Attr) + type_.len + 1;
        try testing.expectEqual(len, attr.len);
        nested_len += nl_align(attr.len);
    }
    link_info.end();
    try testing.expectEqual(nested_len, link_info.attr.len);

    const msg = req.done();
    try testing.expectEqual(msg.len, req.nlh.*.len);
}

test "parse RTM_NEWLINK response" {
    const expect = std.testing.expect;
    const expectEqual = std.testing.expectEqual;
    const expectEqualSlices = std.testing.expectEqualSlices;

    const c = @cImport({
        @cInclude("linux/if.h");
        @cInclude("linux/if_arp.h");
    });

    const raw = @embedFile("testdata/rtm_newlink_combined.bin");
    const LinkListResponse = Response(linux.NetlinkMessageType.RTM_NEWLINK, linux.ifinfomsg);
    var res = LinkListResponse.init(1691933945, @constCast(raw));

    {
        var msg = try res.next();
        switch (msg) {
            .payload => |*payload| {
                try expectEqual(payload.value.index, 1);
                try expectEqual(@as(c_uint, @intCast(c.IFF_UP)), (payload.value.flags & c.IFF_UP));
                try expectEqual(c.ARPHRD_LOOPBACK, payload.value.type);

                var count: usize = 0;
                while (try payload.next()) |attr| {
                    switch (attr.type) {
                        c.IFLA_IFNAME => {
                            var name = [_]u8{ 'l', 'o', 0 };
                            const start: usize = 0;
                            try expectEqualSlices(u8, name[start..], attr.slice());
                        },
                        else => {},
                    }
                    count += 1;
                }
                try expectEqual(count, 31);
            },
            else => try expect(false),
        }
    }
    {
        var msg = try res.next();
        switch (msg) {
            .payload => |*payload| {
                try expectEqual(payload.value.index, 2);
                try expectEqual(@as(c_uint, @intCast(c.IFF_UP)), (payload.value.flags & c.IFF_UP));
                try expectEqual(c.ARPHRD_ETHER, payload.value.type);

                var count: usize = 0;
                while (try payload.next()) |attr| {
                    switch (attr.type) {
                        c.IFLA_IFNAME => {
                            var name: [:0]const u8 = "wlp0s20f3";
                            name.len += 1;
                            const start: usize = 0;
                            try expectEqualSlices(u8, name[start..], attr.slice());
                        },
                        else => {},
                    }
                    count += 1;
                }
                try expectEqual(count, 34);
            },
            else => try expect(false),
        }
    }
    {
        const msg = try res.next();
        switch (msg) {
            .done => {},
            else => try expect(false),
        }
    }
}
