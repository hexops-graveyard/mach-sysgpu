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
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .path = "src/main.zig" },
        .imports = &.{
            .{ .name = "vulkan", .module = vulkan_dep.module("vulkan-zig-generated") },
            .{ .name = "gpu", .module = mach_gpu_dep.module("mach-gpu") },
            .{ .name = "objc", .module = mach_objc_dep.module("mach-objc") },
            .{ .name = "build-options", .module = build_options.createModule() },
        },
    });
    link(b, module);

    const lib = b.addStaticLibrary(.{
        .name = "mach-sysgpu",
        .root_source_file = b.addWriteFiles().add("empty.c", ""),
        .target = target,
        .optimize = optimize,
    });
    var iter = module.import_table.iterator();
    while (iter.next()) |e| {
        lib.root_module.addImport(e.key_ptr.*, e.value_ptr.*);
    }
    link(b, &lib.root_module);
    addPaths(lib);
    b.installArtifact(lib);

    const test_step = b.step("test", "Run library tests");
    const main_tests = b.addTest(.{
        .name = "sysgpu-tests",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    iter = module.import_table.iterator();
    while (iter.next()) |e| {
        main_tests.root_module.addImport(e.key_ptr.*, e.value_ptr.*);
    }
    link(b, &main_tests.root_module);
    addPaths(main_tests);
    b.installArtifact(main_tests);

    test_step.dependOn(&b.addRunArtifact(main_tests).step);
}

fn link(b: *std.Build, module: *std.Build.Module) void {
    module.link_libc = true;

    const target = module.resolved_target.?.result;
    if (target.isDarwin()) {
        module.linkSystemLibrary("objc", .{});
        module.linkFramework("AppKit", .{});
        module.linkFramework("CoreGraphics", .{});
        module.linkFramework("Foundation", .{});
        module.linkFramework("Metal", .{});
        module.linkFramework("QuartzCore", .{});
    }
    if (target.os.tag == .windows) {
        module.linkSystemLibrary("d3d12", .{});
        module.linkSystemLibrary("d3dcompiler_47", .{});
        module.linkSystemLibrary("opengl32", .{});
        module.linkLibrary(b.dependency("direct3d_headers", .{
            .target = module.resolved_target orelse b.host,
            .optimize = module.optimize.?,
        }).artifact("direct3d-headers"));
        @import("direct3d_headers").addLibraryPathToModule(module);
        module.linkLibrary(b.dependency("opengl_headers", .{
            .target = module.resolved_target orelse b.host,
            .optimize = module.optimize.?,
        }).artifact("opengl-headers"));
    }

    module.linkLibrary(b.dependency("spirv_cross", .{
        .target = module.resolved_target orelse b.host,
        .optimize = module.optimize.?,
    }).artifact("spirv-cross"));
    module.linkLibrary(b.dependency("spirv_tools", .{
        .target = module.resolved_target orelse b.host,
        .optimize = module.optimize.?,
    }).artifact("spirv-opt"));
}

pub fn addPaths(step: *std.Build.Step.Compile) void {
    if (step.rootModuleTarget().isDarwin()) @import("xcode_frameworks").addPaths(step);
}
