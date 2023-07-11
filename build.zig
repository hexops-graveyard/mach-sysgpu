const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const vulkan_dep = b.dependency("vulkan", .{});
    const vulkan_mod = vulkan_dep.module("vulkan-zig-generated");
    const glfw_dep = b.dependency("mach-glfw", .{});
    const glfw_mod = glfw_dep.module("mach-glfw");
    const mach_gpu_mod = b.addModule("gpu", .{
        .source_file = .{ .path = "libs/mach-gpu/src/main.zig" },
    });

    const module = b.addModule("mach-dusk", .{
        .source_file = .{ .path = "src/main.zig" },
        .dependencies = &.{
            .{
                .name = "vulkan",
                .module = vulkan_mod,
            },
            .{
                .name = "gpu",
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
    glfwLink(b, triangle_example);
    triangle_example.addModule("dusk", module);
    triangle_example.addModule("gpu", mach_gpu_mod);
    triangle_example.addModule("glfw", glfw_mod);

    b.installArtifact(triangle_example);

    const run_triangle_example = b.addRunArtifact(triangle_example);
    const run_triangle_example_step = b.step("triangle", "Run the basic init example");
    run_triangle_example_step.dependOn(&run_triangle_example.step);

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

fn glfwLink(b: *std.Build, step: *std.build.CompileStep) void {
    const glfw_dep = b.dependency("mach-glfw", .{
        .target = step.target,
        .optimize = step.optimize,
    });
    step.linkLibrary(glfw_dep.artifact("mach-glfw"));
    step.addModule("glfw", glfw_dep.module("mach-glfw"));

    // TODO(build-system): Zig package manager currently can't handle transitive deps like this, so we need to use
    // these explicitly here:
    @import("glfw").addPaths(step);
    step.linkLibrary(b.dependency("vulkan_headers", .{
        .target = step.target,
        .optimize = step.optimize,
    }).artifact("vulkan-headers"));
    step.linkLibrary(b.dependency("x11_headers", .{
        .target = step.target,
        .optimize = step.optimize,
    }).artifact("x11-headers"));
    step.linkLibrary(b.dependency("wayland_headers", .{
        .target = step.target,
        .optimize = step.optimize,
    }).artifact("wayland-headers"));
}
