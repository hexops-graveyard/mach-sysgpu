const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const vulkan_dep = b.dependency("vulkan", .{});
    const vulkan_mod = vulkan_dep.module("vulkan-zig-generated");

    const gpu_dep = b.dependency("mach_gpu", .{});
    const gpu_mod = gpu_dep.module("mach-gpu");

    const glfw_dep = b.dependency("mach_glfw", .{});
    const glfw_mod = glfw_dep.module("mach-glfw");

    const module = b.addModule("mach-dusk", .{
        .source_file = .{ .path = "src/main.zig" },
        .dependencies = &.{
            .{ .name = "vulkan", .module = vulkan_mod },
            .{ .name = "gpu", .module = gpu_mod },
        },
    });

    const triangle = b.addExecutable(.{
        .name = "triangle",
        .root_source_file = .{ .path = "examples/triangle/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    triangle.addModule("dusk", module);
    triangle.addModule("gpu", gpu_mod);
    triangle.addModule("glfw", glfw_mod);
    try @import("mach_glfw").link(b, triangle);
    try @import("mach_gpu").link(b, triangle, .{}); // link dawn
    b.installArtifact(triangle);

    const run_traingle_cmd = b.addRunArtifact(triangle);
    const run_triangle_step = b.step("triangle", "Run the basic init example");
    run_triangle_step.dependOn(&run_traingle_cmd.step);

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
