const std = @import("std");
const Air = @import("Air.zig");
const genSpirv = @import("codegen/SpirV.zig").gen;

pub const Language = enum {
    spirv,
};

pub fn generate(allocator: std.mem.Allocator, air: *const Air, out_lang: Language) ![]const u8 {
    return switch (out_lang) {
        .spirv => try genSpirv(allocator, air),
    };
}
