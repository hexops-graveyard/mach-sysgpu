const std = @import("std");
const glfw = @import("libs/mach-glfw/build.zig");

pub fn build(b: *std.Build) !void {
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

    const triangle_example = b.addExecutable(.{
        .name = "triangle",
        .optimize = optimize,
        .target = target,
        .root_source_file = .{ .path = "examples/triangle/main.zig" },
    });
    triangle_example.addModule("mach-dusk", module);
    triangle_example.addModule("mach-gpu", mach_gpu_mod);
    triangle_example.addModule("mach-glfw", glfw.module(b));
    try glfw.link(b, triangle_example, .{});

    b.installArtifact(triangle_example);

    const run_triangle_example = b.addRunArtifact(triangle_example);
    const run_triangle_example_step = b.step("triangle", "Run the basic init example");
    run_triangle_example_step.dependOn(&run_triangle_example.step);

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
