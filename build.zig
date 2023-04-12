const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const dusk_mod = b.addModule("mach-dusk", .{
        .source_file = .{ .path = "src/main.zig" },
    });

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&testStep(b, dusk_mod, optimize, target).step);
}

pub fn testStep(
    b: *std.Build,
    dusk_mod: *std.Build.Module,
    optimize: std.builtin.OptimizeMode,
    target: std.zig.CrossTarget,
) *std.build.RunStep {
    const lib_tests = b.addTest(.{
        .name = "dusk-lib-tests",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const main_tests = b.addTest(.{
        .name = "dusk-tests",
        .root_source_file = .{ .path = "test/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    main_tests.addModule("dusk", dusk_mod);

    const run_step = main_tests.run();
    run_step.step.dependOn(&lib_tests.run().step);
    return main_tests.run();
}
