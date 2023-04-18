const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&testStep(b, optimize, target).step);
}

pub fn testStep(
    b: *std.Build,
    optimize: std.builtin.OptimizeMode,
    target: std.zig.CrossTarget,
) *std.build.RunStep {
    const main_tests = b.addTest(.{
        .name = "dusk-tests",
        .root_source_file = .{ .path = "src/test.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(main_tests);
    // TODO: b.addRunArtifact adds -listen=- which gives no output
    const run_step = std.Build.RunStep.create(b, "run dusk-tests");
    run_step.addArtifactArg(main_tests);
    return run_step;
}
