const Buffer = @import("buffer.zig").Buffer;
const Sampler = @import("sampler.zig").Sampler;
const TextureView = @import("texture_view.zig").TextureView;
const BindGroupLayout = @import("bind_group_layout.zig").BindGroupLayout;
const ExternalTexture = @import("external_texture.zig").ExternalTexture;
const Impl = @import("interface.zig").Impl;

pub const BindGroup = opaque {
    pub const Entry = struct {
        binding: u32,
        offset: u64 = 0,
        size: u64,
        resource: Resource,

        pub const Resource = union(enum) {
            buffer: *Buffer,
            sampler: *Sampler,
            texture_view: *TextureView,
            external_texture: *ExternalTexture,
        };
    };

    pub const Descriptor = struct {
        label: ?[:0]const u8 = null,
        layout: *BindGroupLayout,
        entries: []const Entry = &.{},
    };

    pub inline fn setLabel(bind_group: *BindGroup, label: [:0]const u8) void {
        Impl.bindGroupSetLabel(bind_group, label);
    }

    pub inline fn reference(bind_group: *BindGroup) void {
        Impl.bindGroupReference(bind_group);
    }

    pub inline fn release(bind_group: *BindGroup) void {
        Impl.bindGroupRelease(bind_group);
    }
};
