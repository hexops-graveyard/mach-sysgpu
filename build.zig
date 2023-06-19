const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.addModule("gpu", .{
        .source_file = .{ .path = "src/gpu.zig" },
    });

    const basic_init_example = b.addExecutable(.{
        .name = "basic_init",
        .optimize = optimize,
        .target = target,
        .root_source_file = .{ .path = "examples/basic_init/main.zig" },
    });

    if (target.getOsTag() == .linux) {
        basic_init_example.linkSystemLibrary("vulkan");
    } else {
        @panic("TODO");
    }

    basic_init_example.linkLibC();

    basic_init_example.addModule("gpu", module);
    b.installArtifact(basic_init_example);

    const run_basic_init_example = b.addRunArtifact(basic_init_example);
    const run_basic_init_example_step = b.step("basic_init", "Run the basic init example");
    run_basic_init_example_step.dependOn(&run_basic_init_example.step);

    const shader_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/shader/test.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(shader_tests);

    const stub_impl_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/interface.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(stub_impl_tests);

    const run_shader_tests = b.addRunArtifact(shader_tests);
    const run_stub_impl_tests = b.addRunArtifact(stub_impl_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_shader_tests.step);
    test_step.dependOn(&run_stub_impl_tests.step);
}
