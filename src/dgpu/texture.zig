const std = @import("std");
const TextureView = @import("texture_view.zig").TextureView;
const Extent3D = @import("main.zig").Extent3D;
const Impl = @import("interface.zig").Impl;
const types = @import("main.zig");

pub const Texture = opaque {
    pub const Aspect = enum {
        all,
        stencil_only,
        depth_only,
        plane0_only,
        plane1_only,
    };

    pub const Dimension = enum {
        dimension_1d,
        dimension_2d,
        dimension_3d,
    };

    pub const Format = enum {
        undefined,
        r8_unorm,
        r8_snorm,
        r8_uint,
        r8_sint,
        r16_uint,
        r16_sint,
        r16_float,
        rg8_unorm,
        rg8_snorm,
        rg8_uint,
        rg8_sint,
        r32_float,
        r32_uint,
        r32_sint,
        rg16_uint,
        rg16_sint,
        rg16_float,
        rgba8_unorm,
        rgba8_unorm_srgb,
        rgba8_snorm,
        rgba8_uint,
        rgba8_sint,
        bgra8_unorm,
        bgra8_unorm_srgb,
        rgb10_a2_unorm,
        rg11_b10_ufloat,
        rgb9_e5_ufloat,
        rg32_float,
        rg32_uint,
        rg32_sint,
        rgba16_uint,
        rgba16_sint,
        rgba16_float,
        rgba32_float,
        rgba32_uint,
        rgba32_sint,
        stencil8,
        depth16_unorm,
        depth24_plus,
        depth24_plus_stencil8,
        depth32_float,
        depth32_float_stencil8,
        bc1_rgba_unorm,
        bc1_rgba_unorm_srgb,
        bc2_rgba_unorm,
        bc2_rgba_unorm_srgb,
        bc3_rgba_unorm,
        bc3_rgba_unorm_srgb,
        bc4_runorm,
        bc4_rsnorm,
        bc5_rg_unorm,
        bc5_rg_snorm,
        bc6_hrgb_ufloat,
        bc6_hrgb_float,
        bc7_rgba_unorm,
        bc7_rgba_unorm_srgb,
        etc2_rgb8_unorm,
        etc2_rgb8_unorm_srgb,
        etc2_rgb8_a1_unorm,
        etc2_rgb8_a1_unorm_srgb,
        etc2_rgba8_unorm,
        etc2_rgba8_unorm_srgb,
        eacr11_unorm,
        eacr11_snorm,
        eacrg11_unorm,
        eacrg11_snorm,
        astc4x4_unorm,
        astc4x4_unorm_srgb,
        astc5x4_unorm,
        astc5x4_unorm_srgb,
        astc5x5_unorm,
        astc5x5_unorm_srgb,
        astc6x5_unorm,
        astc6x5_unorm_srgb,
        astc6x6_unorm,
        astc6x6_unorm_srgb,
        astc8x5_unorm,
        astc8x5_unorm_srgb,
        astc8x6_unorm,
        astc8x6_unorm_srgb,
        astc8x8_unorm,
        astc8x8_unorm_srgb,
        astc10x5_unorm,
        astc10x5_unorm_srgb,
        astc10x6_unorm,
        astc10x6_unorm_srgb,
        astc10x8_unorm,
        astc10x8_unorm_srgb,
        astc10x10_unorm,
        astc10x10_unorm_srgb,
        astc12x10_unorm,
        astc12x10_unorm_srgb,
        astc12x12_unorm,
        astc12x12_unorm_srgb,
        r8_bg8_biplanar420_unorm,
    };

    pub const SampleType = enum {
        undefined,
        float,
        unfilterable_float,
        depth,
        sint,
        uint,
    };

    pub const UsageFlags = packed struct(u32) {
        copy_src: bool = false,
        copy_dst: bool = false,
        texture_binding: bool = false,
        storage_binding: bool = false,
        render_attachment: bool = false,
        transient_attachment: bool = false,

        _padding: u26 = 0,

        pub const none = UsageFlags{};

        pub fn equal(a: UsageFlags, b: UsageFlags) bool {
            return @as(u6, @truncate(@as(u32, @bitCast(a)))) == @as(u6, @truncate(@as(u32, @bitCast(b))));
        }
    };

    pub const BindingLayout = struct {
        sample_type: SampleType = .undefined,
        view_dimension: TextureView.Dimension = .dimension_undefined,
        multisampled: bool = false,
    };

    pub const DataLayout = struct {
        offset: u64 = 0,
        bytes_per_row: ?u32 = null,
        rows_per_image: ?u32 = null,
    };

    pub const Descriptor = struct {
        label: ?[:0]const u8 = null,
        usage: UsageFlags,
        dimension: Dimension = .dimension_2d,
        size: Extent3D,
        format: Format,
        mip_level_count: u32 = 1,
        sample_count: u32 = 1,
        view_formats: []const Format = &.{},
    };

    pub inline fn createView(texture: *Texture, descriptor: TextureView.Descriptor) *TextureView {
        return Impl.textureCreateView(texture, descriptor);
    }

    pub inline fn destroy(texture: *Texture) void {
        Impl.textureDestroy(texture);
    }

    pub inline fn getDepthOrArrayLayers(texture: *Texture) u32 {
        return Impl.textureGetDepthOrArrayLayers(texture);
    }

    pub inline fn getDimension(texture: *Texture) Dimension {
        return Impl.textureGetDimension(texture);
    }

    pub inline fn getFormat(texture: *Texture) Format {
        return Impl.textureGetFormat(texture);
    }

    pub inline fn getHeight(texture: *Texture) u32 {
        return Impl.textureGetHeight(texture);
    }

    pub inline fn getMipLevelCount(texture: *Texture) u32 {
        return Impl.textureGetMipLevelCount(texture);
    }

    pub inline fn getSampleCount(texture: *Texture) u32 {
        return Impl.textureGetSampleCount(texture);
    }

    pub inline fn getUsage(texture: *Texture) UsageFlags {
        return Impl.textureGetUsage(texture);
    }

    pub inline fn getWidth(texture: *Texture) u32 {
        return Impl.textureGetWidth(texture);
    }

    pub inline fn setLabel(texture: *Texture, label: [:0]const u8) void {
        Impl.textureSetLabel(texture, label);
    }

    pub inline fn reference(texture: *Texture) void {
        Impl.textureReference(texture);
    }

    pub inline fn release(texture: *Texture) void {
        Impl.textureRelease(texture);
    }
};
