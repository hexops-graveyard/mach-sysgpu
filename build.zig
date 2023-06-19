const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const shader_compiler = b.addTest(.{
        .root_source_file = .{ .path = "src/shader/test.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(shader_compiler);

    const run_shader_compiler = b.addRunArtifact(shader_compiler);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_shader_compiler.step);
}
