const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const vulkan_dep = b.dependency("vulkan_zig_generated", .{});
    const vulkan_mod = vulkan_dep.module("vulkan-zig-generated");

    const gpu_dep = b.dependency("mach_gpu", .{
        .target = target,
        .optimize = optimize,
    });
    const gpu_mod = gpu_dep.module("mach-gpu");

    const glfw_dep = b.dependency("mach_glfw", .{
        .target = target,
        .optimize = optimize,
    });
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

    inline for (&.{ "triangle", "rotating-cube" }) |example_name| {
        const example = b.addExecutable(.{
            .name = example_name,
            .root_source_file = .{ .path = "examples/" ++ example_name ++ "/main.zig" },
            .target = target,
            .optimize = optimize,
        });
        example.addModule("dusk", module);
        example.addModule("gpu", gpu_mod);
        example.addModule("glfw", glfw_mod);
        example.addModule("objc", objc_mod);
        example.main_pkg_path = .{ .path = "examples" };

        if (target.isDarwin()) {
            example.linkFramework("AppKit");
            example.linkFramework("CoreGraphics");
            example.linkFramework("Foundation");
            example.linkFramework("Metal");
            example.linkFramework("QuartzCore");
        }

        if (target.isWindows()) {
            example.addCSourceFile(.{ .file = .{ .path = "src/d3d12/workarounds.c" }, .flags = &.{} });

            example.linkLibrary(b.dependency("direct3d_headers", .{
                .target = target,
                .optimize = optimize,
            }).artifact("direct3d-headers"));
            @import("direct3d_headers").addLibraryPath(example);
            example.linkSystemLibrary("d3d12");
            example.linkSystemLibrary("d3dcompiler_47");
        }

        @import("mach_glfw").link(glfw_dep.builder, example);
        try @import("mach_gpu").link(gpu_dep.builder, example, .{}); // link dawn
        b.installArtifact(example);

        const run_example_cmd = b.addRunArtifact(example);
        const run_example_step = b.step(example_name, "Run the " ++ example_name ++ "example");
        run_example_step.dependOn(&run_example_cmd.step);
    }

    const tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    tests.linkLibC();
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
