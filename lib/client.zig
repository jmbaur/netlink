const std = @import("std");
const debug = std.debug;
const linux = std.os.linux;
const mem = std.mem;
const posix = std.posix;

const msg = @import("message.zig");

pub fn NewClient(comptime round_trips: anytype) type {
    const RoundTripsType = @TypeOf(round_trips);
    const round_trips_type_info = @typeInfo(RoundTripsType);
    if (round_trips_type_info != .Struct) {
        @compileError("expected struct argument, found " ++ @typeName(RoundTripsType));
    }
    for (round_trips_type_info.Struct.fields) |field| {
        const field_type_info = @typeInfo(field.type);
        if (field_type_info != .Struct) @compileError("expected struct field type to be a struct, found " ++ @typeName(field.type));
        if (field_type_info.Struct.fields.len != 2) @compileError("expected struct field type to be a struct, found " ++ @typeName(field.type));
    }

    return union(enum) {
        const Client = @This();

        done: u32,
        pending: u32,

        pub fn init() Client {
            return Client{ .done = 0 };
        }

        fn req_to_res(comptime Request: type) type {
            inline for (round_trips) |rt| {
                if (rt[0] == Request) return rt[1];
            }
            @compileError("client cannot send requests of type " ++ @typeName(Request));
        }

        pub fn reset(self: *Client) void {
            switch (self) {
                .done => {},
                .pending => |pending| self = .{ .done = pending.seq },
            }
        }

        pub fn new_req(self: Client, comptime T: type, buf: []u8) error{ OutOfMemory, PendingRequest }!T {
            const req = try T.init(buf);
            req.nlh.seq = switch (self) {
                .done => |seq| seq + 1,
                .pending => return error.PendingRequest,
            };
            req.nlh.*.flags |= linux.NLM_F_ACK;
            return req;
        }

        pub fn sent_req(self: *Client, req: anytype) Future(req_to_res(@TypeOf(req))) {
            // Ensure that `req` is a type created by `Request(T)`.
            comptime {
                const Request = @TypeOf(req);
                const type_info = @typeInfo(Request);
                if (type_info != .Struct) {
                    @compileError("expected struct argument, found " ++ @typeName(Request));
                }
                for (type_info.Struct.fields) |field| {
                    if (mem.eql(u8, field.name, "nlh") and field.type == *linux.nlmsghdr) break;
                } else @compileError("missing `nlh: *linux.nlmsghdr` field");
            }

            const dump = (req.nlh.flags & linux.NLM_F_DUMP) == linux.NLM_F_DUMP;
            const fut = Future(req_to_res(@TypeOf(req))).init(self, req.nlh.seq, dump);
            self.* = .{ .pending = req.nlh.seq };
            return fut;
        }

        fn Future(comptime T: type) type {
            return struct {
                pub const Self = @This();

                client: *Client,
                buf: ?[]const u8,
                dump: bool,
                state: union(enum) {
                    done: void,
                    expecting: u32,
                },

                fn init(client: *Client, seq: u32, dump: bool) Self {
                    return Self{
                        .client = client,
                        .buf = null,
                        .dump = dump,
                        .state = .{ .expecting = seq },
                    };
                }

                //        pub fn one(self: *Self) !Response(T) {
                //            const res = self.next() orelse return error.ExpectedResponse;
                //            if (self.next()) |_| return error.UnexpectedResponse;
                //            return res;
                //        }

                pub fn ack(self: *Self) !void {
                    if (T != msg.AckResponse) @compileError("Future(T).ack() can only be called on T == AckResponse");
                    _ = try self.next();
                    if (try self.next()) return error.InvalidResponse;
                }

                pub fn handle_input(self: *Self, buf: []const u8) !void {
                    switch (self.state) {
                        .done => return error.UnexpectedInput,
                        .expecting => |seq| {
                            var i: usize = 0;
                            while (i < buf.len) {
                                const hdr = try msg.parse_nlmsghdr(buf[i..]);
                                i += msg.nl_align(hdr.len);

                                // This is not expected, but it should be safe to ignore old
                                // messages in case the client hit an error or called
                                // `Request.sent()` before reading all the data.
                                if (hdr.seq < seq) continue;

                                if (hdr.seq > seq) return error.UnexpectedResponse;

                                // The client will never expect this type.
                                if (hdr.type == .DONE) {
                                    // The caller has done something wrong.
                                    debug.assert(hdr.type != linux.NetlinkMessageType.ERROR);

                                    if (!self.dump) return error.UnexpectedResponse;
                                    self.state = .{ .done = void{} };
                                    if (i < buf.len) return error.UnexpectedResponse;
                                    return;
                                }

                                if (hdr.type != T.TYPE) return error.UnexpectedResponse;

                                switch (hdr.type) {
                                    .DONE => unreachable,
                                    .ERROR => {
                                        self.state = .{ .done = void{} };
                                        const payload: *const msg.nlmsgerr = @ptrCast(@alignCast(buf.ptr + i + msg.NLMSG_HDRLEN));
                                        const code = if (payload.*.code >= 0) payload.*.code else -payload.*.code;
                                        const errno: linux.E = @enumFromInt(code);
                                        switch (errno) {
                                            .SUCCESS => {
                                                if (i < buf.len) return error.UnexpectedResponse;
                                                return;
                                            },
                                            .EXIST => return error.AlreadyExists,
                                            .INVAL => return error.InvalidRequest,
                                            .NODEV => return error.NoDevice,
                                            .OPNOTSUPP => return error.NotSupported,
                                            .PERM => return error.AccessDenied,
                                            else => |err| return posix.unexpectedErrno(err),
                                        }
                                    },
                                    else => {
                                        if (self.dump != ((hdr.flags & linux.NLM_F_MULTI) == linux.NLM_F_MULTI)) return error.InvalidResponse;
                                        self.buf = buf[0..i];
                                    },
                                }
                            }
                        },
                    }
                }

                pub fn needs_more_data(self: *Self) bool {
                    return switch (self.state) {
                        .done => false,
                        .expecting => true,
                    };
                }

                pub fn next(self: *Self) msg.ParseError!?T {
                    const buf = self.buf orelse return null;

                    const res = try T.init(buf);
                    const size = res.size();
                    debug.assert(buf.len >= size);

                    self.buf = if (buf.len == size) null else buf[size..];
                    return res;
                }
            };
        }
    };
}