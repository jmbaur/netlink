const std = @import("std");
const debug = std.debug;
const mem = std.mem;
const process = std.process;

pub fn fatal(comptime format: []const u8, args: anytype) noreturn {
    debug.print(format, args);
    process.exit(1);
}

pub fn flag_is_help(flag: [:0]const u8) bool {
    const flag_h = "-h";
    const flag_help = "--help";
    return mem.eql(u8, flag, flag_h) or mem.eql(u8, flag, flag_help);
}

pub fn flag_is_version(flag: [:0]const u8) bool {
    const flag_v = "-v";
    const flag_version = "--version";
    return mem.eql(u8, flag, flag_v) or mem.eql(u8, flag, flag_version);
}

pub fn writeTableSeparator(writer: anytype, len: usize) !void {
    try writer.writeByte('|');
    try writer.writeByteNTimes('-', len);
    try writer.writeByte('|');
    try writer.writeByte('\n');
}

/// This data structures is like `std.ArrayList`, except it initializes all
/// items to `null`.  It is useful for storing links because they are _almost_
/// contiguous.
pub fn SparseList(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: mem.Allocator,
        items: []?T,

        pub fn init(allocator: mem.Allocator) Self {
            return Self{
                .allocator = allocator,
                .items = &[_]T{},
            };
        }

        pub fn initCapacity(allocator: mem.Allocator, capacity: usize) mem.Allocator.Error!Self {
            var items = try allocator.alloc(?T, capacity);
            for (0..capacity) |i| items.ptr[i] = null;

            return Self{
                .allocator = allocator,
                .items = items,
            };
        }

        pub fn get(self: Self, index: usize) ?T {
            if (index >= self.items.len) return null;
            return self.items[index];
        }

        pub fn set(self: *Self, index: usize, value: T) mem.Allocator.Error!void {
            if (index >= self.items.len) {
                const old_len = self.items.len;
                var new_len = old_len;
                if (new_len == 0) new_len = 1;
                while (new_len <= index) new_len *|= 2;

                if (!self.allocator.resize(self.items, new_len)) {
                    const new_memory = try self.allocator.alignedAlloc(?T, null, new_len);
                    @memcpy(new_memory[0..self.items.len], self.items);
                    self.allocator.free(self.items);
                    self.items = new_memory;
                }

                for (old_len..self.items.len) |i| self.items.ptr[i] = null;
            }
            self.items[index] = value;
        }
    };
}
