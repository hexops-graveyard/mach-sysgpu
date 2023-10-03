const TextureView = @import("texture_view.zig").TextureView;
const Origin2D = @import("main.zig").Origin2D;
const Extent2D = @import("main.zig").Extent2D;
const Impl = @import("interface.zig").Impl;

pub const ExternalTexture = opaque {
    const Rotation = enum {
        rotate_0_degrees,
        rotate_90_degrees,
        rotate_180_degrees,
        rotate_270_degrees,
    };

    pub const Descriptor = struct {
        label: ?[:0]const u8 = null,
        plane0: *TextureView,
        plane1: ?*TextureView = null,
        visible_origin: Origin2D,
        visible_size: Extent2D,
        do_yuv_to_rgb_conversion_only: bool = false,
        yuv_to_rgb_conversion_matrix: ?*const [12]f32 = null,
        src_transform_function_parameters: *const [7]f32,
        dst_transform_function_parameters: *const [7]f32,
        gamut_conversion_matrix: *const [9]f32,
        flip_y: bool,
        rotation: Rotation,
    };

    pub const BindingLayout = struct {};

    pub inline fn destroy(external_texture: *ExternalTexture) void {
        Impl.externalTextureDestroy(external_texture);
    }

    pub inline fn setLabel(external_texture: *ExternalTexture, label: [:0]const u8) void {
        Impl.externalTextureSetLabel(external_texture, label);
    }

    pub inline fn reference(external_texture: *ExternalTexture) void {
        Impl.externalTextureReference(external_texture);
    }

    pub inline fn release(external_texture: *ExternalTexture) void {
        Impl.externalTextureRelease(external_texture);
    }
};
