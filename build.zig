const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const vulkan_dep = b.dependency("vulkan_zig_generated", .{});
    const vulkan_mod = vulkan_dep.module("vulkan-zig-generated");

    const gpu_dep = b.dependency("mach_gpu", .{});
    const gpu_mod = gpu_dep.module("mach-gpu");

    const glfw_dep = b.dependency("mach_glfw", .{});
    const glfw_mod = glfw_dep.module("mach-glfw");

    const objc_dep = b.dependency("mach_objc", .{
        .target = target,
        .optimize = optimize,
    });
    const objc_mod = objc_dep.module("mach-objc");

    const module = b.addModule("mach-dusk", .{
        .source_file = .{ .path = "src/main.zig" },
        .dependencies = &.{
            .{ .name = "vulkan", .module = vulkan_mod },
            .{ .name = "gpu", .module = gpu_mod },
            .{ .name = "objc", .module = objc_mod },
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
    triangle.addModule("objc", objc_mod);

    if (target.isDarwin()) {
        triangle.linkFramework("AppKit");
        triangle.linkFramework("CoreGraphics");
        triangle.linkFramework("Foundation");
        triangle.linkFramework("Metal");
        triangle.linkFramework("QuartzCore");
    }

    if (target.isWindows()) {
        triangle.addCSourceFile(.{ .file = .{ .path = "src/d3d12/workarounds.c" }, .flags = &.{} });

        triangle.linkLibrary(b.dependency("direct3d_headers", .{
            .target = target,
            .optimize = optimize,
        }).artifact("direct3d-headers"));
        @import("direct3d_headers").addLibraryPath(triangle);
        triangle.linkSystemLibrary("d3d12");
        triangle.linkSystemLibrary("d3dcompiler_47");
    }

    @import("mach_glfw").link(glfw_dep.builder, triangle);
    try @import("mach_gpu").link(gpu_dep.builder, triangle, .{}); // link dawn
    b.installArtifact(triangle);

    const run_triangle_cmd = b.addRunArtifact(triangle);
    const run_triangle_step = b.step("triangle", "Run the basic init example");
    run_triangle_step.dependOn(&run_triangle_cmd.step);

    const tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    tests.addModule("vulkan", vulkan_mod);
    tests.addModule("gpu", gpu_mod);
    tests.addModule("objc", objc_mod);

    if (target.isDarwin()) {
        tests.linkFramework("AppKit");
        tests.linkFramework("CoreGraphics");
        tests.linkFramework("Foundation");
        tests.linkFramework("Metal");
        tests.linkFramework("QuartzCore");
    }

    if (target.isWindows()) {
        tests.addCSourceFile(.{ .file = .{ .path = "src/d3d12/workarounds.c" }, .flags = &.{} });

        tests.linkLibrary(b.dependency("direct3d_headers", .{
            .target = target,
            .optimize = optimize,
        }).artifact("direct3d-headers"));
        @import("direct3d_headers").addLibraryPath(tests);
        tests.linkSystemLibrary("d3d12");
        tests.linkSystemLibrary("d3dcompiler_47");
    }

    b.installArtifact(tests);

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_tests.step);
}
