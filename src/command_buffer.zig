const ChainedStruct = @import("gpu.zig").ChainedStruct;
const Impl = @import("interface.zig").Impl;

pub const CommandBuffer = opaque {
    pub const Descriptor = extern struct {
        next_in_chain: ?*const ChainedStruct = null,
        label: ?[*:0]const u8 = null,
    };
};
