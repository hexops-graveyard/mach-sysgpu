const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const vulkan_dep = b.dependency("vulkan_zig_generated", .{});
    const mach_gpu_dep = b.dependency("mach_gpu", .{
        .target = target,
        .optimize = optimize,
    });
    const mach_objc_dep = b.dependency("mach_objc", .{
        .target = target,
        .optimize = optimize,
    });

    const module = b.addModule("mach-dusk", .{
        .source_file = .{ .path = "src/main.zig" },
        .dependencies = &.{
            .{ .name = "vulkan", .module = vulkan_dep.module("vulkan-zig-generated") },
            .{ .name = "gpu", .module = mach_gpu_dep.module("mach-gpu") },
            .{ .name = "objc", .module = mach_objc_dep.module("mach-objc") },
        },
    });

    const lib = b.addStaticLibrary(.{
        .name = "mach-dusk",
        .root_source_file = b.addWriteFiles().add("empty.c", ""),
        .target = target,
        .optimize = optimize,
    });
    if (target.isWindows()) {
        lib.addCSourceFile(.{ .file = .{ .path = "src/d3d12/workarounds.c" }, .flags = &.{} });
    }
    link(b, lib);
    b.installArtifact(lib);

    const test_step = b.step("test", "Run library tests");
    const main_tests = b.addTest(.{
        .name = "dusk-tests",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    var iter = module.dependencies.iterator();
    while (iter.next()) |e| {
        main_tests.addModule(e.key_ptr.*, e.value_ptr.*);
    }
    main_tests.linkLibrary(lib);
    link(b, main_tests);
    b.installArtifact(main_tests);

    test_step.dependOn(&b.addRunArtifact(main_tests).step);
}

pub fn link(b: *std.Build, step: *std.build.CompileStep) void {
    if (step.target.isDarwin()) {
        @import("xcode_frameworks").addPaths(b, step);
        step.linkFramework("AppKit");
        step.linkFramework("CoreGraphics");
        step.linkFramework("Foundation");
        step.linkFramework("Metal");
        step.linkFramework("QuartzCore");
    }

    if (step.target.isWindows()) {
        step.linkLibC();
        step.linkLibrary(b.dependency("direct3d_headers", .{
            .target = step.target,
            .optimize = step.optimize,
        }).artifact("direct3d-headers"));
        @import("direct3d_headers").addLibraryPath(step);
        step.linkSystemLibrary("d3d12");
        step.linkSystemLibrary("d3dcompiler_47");
    }
}
