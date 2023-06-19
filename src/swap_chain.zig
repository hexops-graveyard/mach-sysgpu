const ChainedStruct = @import("gpu.zig").ChainedStruct;
const PresentMode = @import("gpu.zig").PresentMode;
const Texture = @import("texture.zig").Texture;
const TextureView = @import("texture_view.zig").TextureView;
const Impl = @import("interface.zig").Impl;

pub const SwapChain = opaque {
    pub const Descriptor = extern struct {
        next_in_chain: ?*const ChainedStruct = null,
        label: ?[*:0]const u8 = null,
        usage: Texture.UsageFlags,
        format: Texture.Format,
        width: u32,
        height: u32,
        present_mode: PresentMode,
        /// deprecated
        implementation: u64 = 0,
    };
};
