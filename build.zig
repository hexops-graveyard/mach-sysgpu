const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const vulkan_dep = b.dependency("vulkan-zig-generated", .{});
    const vulkan_mod = vulkan_dep.module("vulkan-zig-generated");
    const mach_gpu_mod = b.addModule("mach-gpu", .{
        .source_file = .{ .path = "libs/mach-gpu/src/main.zig" },
    });

    const module = b.addModule("dusk", .{
        .source_file = .{ .path = "src/main.zig" },
        .dependencies = &.{
            .{
                .name = "vulkan",
                .module = vulkan_mod,
            },
            .{
                .name = "mach-gpu",
                .module = mach_gpu_mod,
            },
        },
    });

    const basic_init_example = b.addExecutable(.{
        .name = "basic_init",
        .optimize = optimize,
        .target = target,
        .root_source_file = .{ .path = "examples/basic_init/main.zig" },
    });
    basic_init_example.addModule("mach-dusk", module);
    basic_init_example.addModule("mach-gpu", mach_gpu_mod);
    basic_init_example.linkLibC();
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

    const run_shader_tests = b.addRunArtifact(shader_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_shader_tests.step);
}
