const std = @import("std");
const Texture = @import("texture.zig").Texture;
const Impl = @import("interface.zig").Impl;
const types = @import("main.zig");

pub const TextureView = opaque {
    pub const Dimension = enum {
        dimension_undefined,
        dimension_1d,
        dimension_2d,
        dimension_2d_array,
        dimension_cube,
        dimension_cube_array,
        dimension_3d,
    };

    pub const Descriptor = struct {
        label: ?[:0]const u8 = null,
        format: Texture.Format = .undefined,
        dimension: Dimension = .dimension_undefined,
        base_mip_level: u32 = 0,
        mip_level_count: u32 = std.math.maxInt(u32),
        base_array_layer: u32 = 0,
        array_layer_count: u32 = std.math.maxInt(u32),
        aspect: Texture.Aspect = .all,
    };

    pub inline fn setLabel(texture_view: *TextureView, label: [:0]const u8) void {
        Impl.textureViewSetLabel(texture_view, label);
    }

    pub inline fn reference(texture_view: *TextureView) void {
        Impl.textureViewReference(texture_view);
    }

    pub inline fn release(texture_view: *TextureView) void {
        Impl.textureViewRelease(texture_view);
    }
};
