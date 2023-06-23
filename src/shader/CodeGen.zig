const std = @import("std");
const Air = @import("Air.zig");
const Backend = @import("shader.zig").Backend;
const genSpirv = @import("codegen/spirv.zig").gen;

pub fn generate(allocator: std.mem.Allocator, air: *const Air, backend: Backend) ![]const u8 {
    return switch (backend) {
        .spirv => try genSpirv(allocator, air),
    };
}
