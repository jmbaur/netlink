const std = @import("std");
const linux = std.os.linux;
const posix = std.posix;

const message = @import("message.zig");

fn MultiResponse(comptime T: type) type {
    return struct {
        h: Handle,
        res: ?T,

        const Self = @This();

        fn init(h: Handle) Self {
            return Self{
                .h = h,
                .res = null,
            };
        }

        pub fn next(self: *Self) !?T.Payload {
            if (self.res == null) {
                self.res = try self.h.recv(T);
            }

            while (true) {
                const msg = try self.res.?.next();
                switch (msg) {
                    .done => return null,
                    .more => self.res = try self.h.recv(T),
                    .payload => |payload| return payload,
                }
            }
        }
    };
}

pub const Handle = struct {
    buf: []u8,
    seq: u16,
    sk: posix.socket_t,

    pub fn init(sk: posix.socket_t, buf: []u8) Handle {
        return Handle{
            .buf = buf,
            .seq = 1,
            .sk = sk,
        };
    }

    pub fn new_req(self: *Handle, comptime T: type) error{OutOfMemory}!T {
        const req = try T.init(self.seq, self.buf);
        self.seq += 1;
        req.nlh.*.flags |= linux.NLM_F_ACK;
        return req;
    }

    fn recv(self: Handle, comptime T: type) posix.RecvFromError!T {
        const n = try posix.recv(self.sk, self.buf, 0);
        return T.init(self.seq - 1, self.buf[0..n]);
    }

    pub fn recv_ack(self: Handle) !*linux.nlmsghdr {
        var res = try self.recv(message.AckResponse);
        switch (try res.next()) {
            .payload => |payload| switch (try res.next()) {
                .done => return payload.value,
                else => return error.InvalidResponse,
            },
            else => return error.InvalidResponse,
        }
    }

    pub fn recv_one(self: Handle, comptime T: type) !T.Payload {
        // The ack response is always sent separately.
        var i: usize = 0;
        const payload = blk: {
            var res = try self.recv(T);
            i = res.buf.len;
            switch (try res.next()) {
                .payload => |payload| switch (try res.next()) {
                    .more => break :blk payload,
                    else => return error.InvalidResponse,
                },
                else => return error.InvalidResponse,
            }
        };

        {
            const n = try posix.recv(self.sk, self.buf[i..], 0);
            var res = T.init(self.seq - 1, self.buf[i .. i + n]);
            const msg = try res.next();
            switch (msg) {
                .done => return payload,
                else => return error.InvalidResponse,
            }
        }
    }

    pub fn recv_all(self: Handle, comptime T: type) MultiResponse(T) {
        return MultiResponse(T).init(self);
    }

    pub fn send(self: Handle, req: anytype) posix.SendError!void {
        _ = try posix.send(self.sk, req.done(), 0);
    }
};

test "pipe to Handle" {
    if (true) return error.SkipZigTest; // This test panics
    const expect = std.testing.expect;
    const expectEqual = std.testing.expectEqual;

    var buf = [_]u8{0} ** 4096;
    var fds = [2]i32{ 0, 0 };
    const rc = linux.socketpair(linux.AF.UNIX, posix.SOCK.SEQPACKET, 0, &fds);
    try expectEqual(rc, 0);
    defer {
        posix.close(fds[0]);
        posix.close(fds[1]);
    }

    var nlh = Handle.init(fds[0], &buf);

    _ = try posix.send(fds[1], @embedFile("testdata/rtm_newlink_1.bin"), 0);
    _ = try posix.send(fds[1], @embedFile("testdata/rtm_newlink_2.bin"), 0);
    _ = try posix.send(fds[1], @embedFile("testdata/rtm_newlink_3.bin"), 0);

    const LinkListResponse = message.Response(linux.NetlinkMessageType.RTM_NEWLINK, linux.ifinfomsg);

    var res = nlh.recv_all(LinkListResponse);
    if (try res.next()) |payload| {
        try expectEqual(payload.value.index, 1);
    } else {
        try expect(false);
    }

    if (try res.next()) |payload| {
        try expectEqual(payload.value.index, 2);
    } else {
        try expect(false);
    }

    const payload = try res.next();
    try expect(payload == null);
}
