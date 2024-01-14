const std = @import("std");

pub const Backend = enum {
    default,
    webgpu,
    d3d12,
    metal,
    vulkan,
    opengl,
};

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const backend = b.option(Backend, "backend", "API Backend") orelse .default;

    const vulkan_dep = b.dependency("vulkan_zig_generated", .{});
    const mach_gpu_dep = b.dependency("mach_gpu", .{
        .target = target,
        .optimize = optimize,
    });
    const mach_objc_dep = b.dependency("mach_objc", .{
        .target = target,
        .optimize = optimize,
    });

    const build_options = b.addOptions();
    build_options.addOption(Backend, "backend", backend);

    const module = b.addModule("mach-sysgpu", .{
        .root_source_file = .{ .path = "src/main.zig" },
        .imports = &.{
            .{ .name = "vulkan", .module = vulkan_dep.module("vulkan-zig-generated") },
            .{ .name = "gpu", .module = mach_gpu_dep.module("mach-gpu") },
            .{ .name = "objc", .module = mach_objc_dep.module("mach-objc") },
            .{ .name = "build-options", .module = build_options.createModule() },
        },
    });

    const lib = b.addStaticLibrary(.{
        .name = "mach-sysgpu",
        .root_source_file = b.addWriteFiles().add("empty.c", ""),
        .target = target,
        .optimize = optimize,
    });
    link(b, lib);
    b.installArtifact(lib);

    const test_step = b.step("test", "Run library tests");
    const main_tests = b.addTest(.{
        .name = "sysgpu-tests",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    var iter = module.import_table.iterator();
    while (iter.next()) |e| {
        main_tests.root_module.addImport(e.key_ptr.*, e.value_ptr.*);
    }
    main_tests.linkLibrary(lib);
    link(b, main_tests);
    b.installArtifact(main_tests);

    test_step.dependOn(&b.addRunArtifact(main_tests).step);
}

pub fn link(b: *std.Build, step: *std.Build.Step.Compile) void {
    const target = step.rootModuleTarget();
    if (target.isDarwin()) {
        @import("xcode_frameworks").addPaths(step);
        step.linkFramework("AppKit");
        step.linkFramework("CoreGraphics");
        step.linkFramework("Foundation");
        step.linkFramework("Metal");
        step.linkFramework("QuartzCore");
    }

    if (target.os.tag == .windows) {
        step.linkLibC();

        step.linkLibrary(b.dependency("direct3d_headers", .{
            .target = step.root_module.resolved_target orelse b.host,
            .optimize = step.root_module.optimize.?,
        }).artifact("direct3d-headers"));
        @import("direct3d_headers").addLibraryPath(step);
        step.linkSystemLibrary("d3d12");
        step.linkSystemLibrary("d3dcompiler_47");

        step.linkLibrary(b.dependency("opengl_headers", .{
            .target = step.root_module.resolved_target orelse b.host,
            .optimize = step.root_module.optimize.?,
        }).artifact("opengl-headers"));
        step.linkSystemLibrary("opengl32");
    }

    step.linkLibrary(b.dependency("spirv_cross", .{
        .target = step.root_module.resolved_target orelse b.host,
        .optimize = step.root_module.optimize.?,
    }).artifact("spirv-cross"));
    step.linkLibrary(b.dependency("spirv_tools", .{
        .target = step.root_module.resolved_target orelse b.host,
        .optimize = step.root_module.optimize.?,
    }).artifact("spirv-opt"));
}
