const ShaderStageFlags = @import("main.zig").ShaderStageFlags;
const Buffer = @import("buffer.zig").Buffer;
const Sampler = @import("sampler.zig").Sampler;
const Texture = @import("texture.zig").Texture;
const StorageTextureBindingLayout = @import("main.zig").StorageTextureBindingLayout;
const ExternalTexture = @import("external_texture.zig").ExternalTexture;
const Impl = @import("interface.zig").Impl;

pub const BindGroupLayout = opaque {
    pub const Entry = struct {
        binding: u32,
        visibility: ShaderStageFlags,
        resource_layout: ResourceLayout,

        const ResourceLayout = union(enum) {
            buffer: Buffer.BindingLayout,
            sampler: Sampler.BindingLayout,
            texture: Texture.BindingLayout,
            storage_texture: StorageTextureBindingLayout,
            external_texture: ExternalTexture.BindingLayout,
        };
    };

    pub const Descriptor = struct {
        label: ?[:0]const u8 = null,
        entries: []const Entry = &.{},
    };

    pub inline fn setLabel(bind_group_layout: *BindGroupLayout, label: [:0]const u8) void {
        Impl.bindGroupLayoutSetLabel(bind_group_layout, label);
    }

    pub inline fn reference(bind_group_layout: *BindGroupLayout) void {
        Impl.bindGroupLayoutReference(bind_group_layout);
    }

    pub inline fn release(bind_group_layout: *BindGroupLayout) void {
        Impl.bindGroupLayoutRelease(bind_group_layout);
    }
};
