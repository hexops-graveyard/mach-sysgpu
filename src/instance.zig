const ChainedStruct = @import("gpu.zig").ChainedStruct;
const RequestAdapterStatus = @import("gpu.zig").RequestAdapterStatus;
const Surface = @import("surface.zig").Surface;
const Adapter = @import("adapter.zig").Adapter;
const RequestAdapterOptions = @import("gpu.zig").RequestAdapterOptions;
const RequestAdapterCallback = @import("gpu.zig").RequestAdapterCallback;
const Impl = @import("interface.zig").Impl;
const dawn = @import("dawn.zig");

pub const Instance = opaque {
    pub const Descriptor = extern struct {
        pub const NextInChain = extern union {
            generic: ?*const ChainedStruct,
            dawn_instance_descriptor: *const dawn.InstanceDescriptor,
        };

        next_in_chain: NextInChain = .{ .generic = null },
    };
};
