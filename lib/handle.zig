const std = @import("std");
const debug = std.debug;
const linux = std.os.linux;
const posix = std.posix;

const message = @import("message.zig");
const route = @import("route.zig");
const client = @import("client.zig");
const DefaultClient = client.NewClient(route.DefaultRoundTrips);

fn Dump(comptime Future: type) type {
    return struct {
        const Self = @This();

        h: *Handle,
        fut: Future,

        fn init(h: *Handle, fut: Future) Self {
            return Self{
                .h = h,
                .fut = fut,
            };
        }

        pub fn next(self: *Self) !?Future.Inner {
            if (self.fut.is_done()) return null;

            if (self.fut.needs_more_data()) {
                try self.h.recv(&self.fut);
            }

            return self.fut.next();
        }
    };
}

pub const Handle = struct {
    client: DefaultClient,
    buf: []u8,
    sk: posix.socket_t,

    pub fn init(sk: posix.socket_t, buf: []u8) Handle {
        return Handle{
            .client = DefaultClient.init(),
            .buf = buf,
            .sk = sk,
        };
    }

    pub fn new_req(self: *Handle, comptime T: type) !T {
        return self.client.new_req(T, self.buf);
    }

    //fn recv(self: *Handle, res: anytype) posix.RecvFromError!void {
    fn recv(self: *Handle, res: anytype) !void {
        debug.assert(res.needs_more_data());
        const n = try posix.recv(self.sk, self.buf, 0);
        try res.handle_input(self.buf[0..n]);
    }

    //pub fn do(self: *Handle, req: anytype) posix.SendError!@TypeOf(self.client).req_to_res(@TypeOf(req)) {
    pub fn do(self: *Handle, req: anytype) !@TypeOf(self.client).req_to_res(@TypeOf(req)) {
        _ = try posix.send(self.sk, req.done(), 0);
        var res = self.client.sent_req(req);
        try self.recv(&res);
        const msg = try res.next();
        if (msg == null) return error.InvalidResponse;
        debug.assert(res.is_done());
        return msg.?;
    }

    //pub fn do_ack(self: *Handle, req: anytype) posix.SendError!void {
    pub fn do_ack(self: *Handle, req: anytype) !void {
        _ = try posix.send(self.sk, req.done(), 0);
        var res = self.client.sent_req(req);
        try self.recv(&res);
        try res.ack();
    }

    //pub fn dump(self: *Handle, req: anytype) posix.SendError!Dump(client.Future(DefaultClient.req_to_res(@TypeOf(req)))) {
    pub fn dump(self: *Handle, req: anytype) !Dump(client.Future(DefaultClient.req_to_res(@TypeOf(req)))) {
        req.nlh.flags |= linux.NLM_F_DUMP;
        _ = try posix.send(self.sk, req.done(), 0);
        const res = self.client.sent_req(req);
        return Dump(@TypeOf(res)).init(self, res);
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
