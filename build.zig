const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addModule("netlink", .{
        .source_file = .{ .path = "lib/netlink.zig" },
    });

    const tests = b.addTest(.{
        .root_source_file = .{ .path = "lib/netlink.zig" },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    const exe = b.addExecutable(.{
        .name = "net",
        .root_source_file = .{ .path = "bin/main.zig" },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const exe_options = b.addOptions();
    exe_options.addOption([:0]const u8, "version", "dev");
    exe.addOptions("build_options", exe_options);

    exe.addModule("netlink", lib);

    b.installArtifact(exe);

    const exe_link_list = b.addExecutable(.{
        .name = "example-link-list",
        .root_source_file = .{ .path = "bin/example-link-list.zig" },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    exe_link_list.addModule("netlink", lib);

    b.installArtifact(exe_link_list);
}
