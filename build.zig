const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addModule("netlink", .{
        .root_source_file = b.path("lib/netlink.zig"),
    });

    const tests = b.addTest(.{
        .root_source_file = b.path("lib/netlink.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    const exe = b.addExecutable(.{
        .name = "net",
        .root_source_file = b.path("bin/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const exe_options = b.addOptions();
    exe_options.addOption([:0]const u8, "version", "dev");
    exe.root_module.addOptions("build_options", exe_options);

    exe.root_module.addImport("netlink", lib);

    exe.addIncludePath(.{ .cwd_relative = "/usr/include/x86_64-linux-gnu" });

    b.installArtifact(exe);

    const exe_link_list = b.addExecutable(.{
        .name = "example-link-list",
        .root_source_file = b.path("bin/example-link-list.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    exe_link_list.root_module.addImport("netlink", lib);

    exe_link_list.addIncludePath(.{ .cwd_relative = "/usr/include/x86_64-linux-gnu" });

    b.installArtifact(exe_link_list);
}
