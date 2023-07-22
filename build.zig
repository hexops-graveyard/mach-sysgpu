const std = @import("std");
const mach_gpu_dawn = @import("libs/mach-gpu-dawn/build.zig");
const mach_gpu = @import("libs/mach-gpu/build.zig").Sdk(.{ .gpu_dawn = mach_gpu_dawn });
const mach_core = @import("libs/mach-core/build.zig").Sdk(.{ .gpu_dawn = mach_gpu_dawn, .gpu = mach_gpu });

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const vulkan_dep = b.dependency("vulkan", .{});
    const vulkan_mod = vulkan_dep.module("vulkan-zig-generated");

    const module = b.addModule("mach-dusk", .{
        .source_file = .{ .path = "src/main.zig" },
        .dependencies = &.{
            .{ .name = "vulkan", .module = vulkan_mod },
            .{ .name = "gpu", .module = mach_gpu.module(b) },
        },
    });

    const triangle = try mach_core.App.init(b, .{
        .name = "triangle",
        .src = "examples/triangle/main.zig",
        .target = target,
        .optimize = optimize,
        .deps = &.{.{ .name = "dusk", .module = module }},
    });

    const run_triangle_step = b.step("triangle", "Run the basic init example");
    run_triangle_step.dependOn(&triangle.run.step);

    const shader_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/shader.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(shader_tests);

    const run_shader_tests = b.addRunArtifact(shader_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_shader_tests.step);
}
