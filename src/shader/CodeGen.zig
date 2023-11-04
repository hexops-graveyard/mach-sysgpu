const std = @import("std");
const Air = @import("Air.zig");
const genGlsl = @import("codegen/glsl.zig").gen;
const genHlsl = @import("codegen/hlsl.zig").gen;
const genMsl = @import("codegen/msl.zig").gen;
const genSpirv = @import("codegen/spirv.zig").gen;

pub const Language = enum {
    glsl,
    hlsl,
    msl,
    spirv,
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
    entrypoint: ?[*:0]const u8,
) ![]const u8 {
    return switch (out_lang) {
        .glsl => try genGlsl(allocator, air, debug_info, entrypoint.?),
        .hlsl => try genHlsl(allocator, air, debug_info),
        .msl => try genMsl(allocator, air, debug_info),
        .spirv => try genSpirv(allocator, air, debug_info),
    };
}
