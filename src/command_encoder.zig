const std = @import("std");
const ComputePassEncoder = @import("compute_pass_encoder.zig").ComputePassEncoder;
const RenderPassEncoder = @import("render_pass_encoder.zig").RenderPassEncoder;
const CommandBuffer = @import("command_buffer.zig").CommandBuffer;
const Buffer = @import("buffer.zig").Buffer;
const QuerySet = @import("query_set.zig").QuerySet;
const RenderPassDescriptor = @import("gpu.zig").RenderPassDescriptor;
const ComputePassDescriptor = @import("gpu.zig").ComputePassDescriptor;
const ChainedStruct = @import("gpu.zig").ChainedStruct;
const ImageCopyBuffer = @import("gpu.zig").ImageCopyBuffer;
const ImageCopyTexture = @import("gpu.zig").ImageCopyTexture;
const Extent3D = @import("gpu.zig").Extent3D;
const Impl = @import("interface.zig").Impl;
const dawn = @import("dawn.zig");

pub const CommandEncoder = opaque {
    pub const Descriptor = extern struct {
        pub const NextInChain = extern union {
            generic: ?*const ChainedStruct,
            dawn_encoder_internal_usage_descriptor: *const dawn.EncoderInternalUsageDescriptor,
        };

        next_in_chain: NextInChain = .{ .generic = null },
        label: ?[*:0]const u8 = null,
    };
};
