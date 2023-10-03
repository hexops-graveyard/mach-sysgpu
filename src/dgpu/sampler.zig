const FilterMode = @import("main.zig").FilterMode;
const MipmapFilterMode = @import("main.zig").MipmapFilterMode;
const CompareFunction = @import("main.zig").CompareFunction;
const Impl = @import("interface.zig").Impl;

pub const Sampler = opaque {
    pub const AddressMode = enum {
        repeat,
        mirror_repeat,
        clamp_to_edge,
    };

    pub const BindingType = enum {
        undefined,
        filtering,
        non_filtering,
        comparison,
    };

    pub const BindingLayout = struct {
        type: BindingType = .undefined,
    };

    pub const Descriptor = struct {
        label: ?[:0]const u8 = null,
        address_mode_u: AddressMode = .clamp_to_edge,
        address_mode_v: AddressMode = .clamp_to_edge,
        address_mode_w: AddressMode = .clamp_to_edge,
        mag_filter: FilterMode = .nearest,
        min_filter: FilterMode = .nearest,
        mipmap_filter: MipmapFilterMode = .nearest,
        lod_min_clamp: f32 = 0.0,
        lod_max_clamp: f32 = 32.0,
        compare: CompareFunction = .undefined,
        max_anisotropy: u16 = 1,
    };

    pub inline fn setLabel(sampler: *Sampler, label: [:0]const u8) void {
        Impl.samplerSetLabel(sampler, label);
    }

    pub inline fn reference(sampler: *Sampler) void {
        Impl.samplerReference(sampler);
    }

    pub inline fn release(sampler: *Sampler) void {
        Impl.samplerRelease(sampler);
    }
};
