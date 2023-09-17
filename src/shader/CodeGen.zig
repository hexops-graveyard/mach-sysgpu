const std = @import("std");
const Air = @import("Air.zig");
const genSpirv = @import("codegen/SpirV.zig").gen;
const genMsl = @import("codegen/msl.zig").gen;
const genHlsl = @import("codegen/hlsl.zig").gen;

pub const Language = enum {
    spirv,
    msl,
    hlsl,
};

pub const DebugInfo = struct {
    emit_source_file: ?[]const u8 = null,
    emit_names: bool = true,
};

pub fn generate(
    allocator: std.mem.Allocator,
    air: *const Air,
    out_lang: Language,
    debug_info: DebugInfo,
) ![]const u8 {
    return switch (out_lang) {
        .spirv => try genSpirv(allocator, air, debug_info),
        .msl => try genMsl(allocator, air, debug_info),
        .hlsl => try genHlsl(allocator, air, debug_info),
    };
}
