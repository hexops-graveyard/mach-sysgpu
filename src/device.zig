const std = @import("std");
const Adapter = @import("adapter.zig").Adapter;
const Queue = @import("queue.zig").Queue;
const BindGroup = @import("bind_group.zig").BindGroup;
const BindGroupLayout = @import("bind_group_layout.zig").BindGroupLayout;
const Buffer = @import("buffer.zig").Buffer;
const CommandEncoder = @import("command_encoder.zig").CommandEncoder;
const ComputePipeline = @import("compute_pipeline.zig").ComputePipeline;
const ExternalTexture = @import("external_texture.zig").ExternalTexture;
const PipelineLayout = @import("pipeline_layout.zig").PipelineLayout;
const QuerySet = @import("query_set.zig").QuerySet;
const RenderBundleEncoder = @import("render_bundle_encoder.zig").RenderBundleEncoder;
const RenderPipeline = @import("render_pipeline.zig").RenderPipeline;
const Sampler = @import("sampler.zig").Sampler;
const ShaderModule = @import("shader_module.zig").ShaderModule;
const Surface = @import("surface.zig").Surface;
const SwapChain = @import("swap_chain.zig").SwapChain;
const Texture = @import("texture.zig").Texture;
const ChainedStruct = @import("gpu.zig").ChainedStruct;
const FeatureName = @import("gpu.zig").FeatureName;
const RequiredLimits = @import("gpu.zig").RequiredLimits;
const SupportedLimits = @import("gpu.zig").SupportedLimits;
const ErrorType = @import("gpu.zig").ErrorType;
const ErrorFilter = @import("gpu.zig").ErrorFilter;
const LoggingType = @import("gpu.zig").LoggingType;
const CreatePipelineAsyncStatus = @import("gpu.zig").CreatePipelineAsyncStatus;
const LoggingCallback = @import("gpu.zig").LoggingCallback;
const ErrorCallback = @import("gpu.zig").ErrorCallback;
const CreateComputePipelineAsyncCallback = @import("gpu.zig").CreateComputePipelineAsyncCallback;
const CreateRenderPipelineAsyncCallback = @import("gpu.zig").CreateRenderPipelineAsyncCallback;
const Impl = @import("interface.zig").Impl;
const dawn = @import("dawn.zig");

pub const Device = opaque {
    pub const LostCallback = *const fn (
        reason: LostReason,
        message: [*:0]const u8,
        userdata: ?*anyopaque,
    ) callconv(.C) void;

    pub const LostReason = enum(u32) {
        undefined = 0x00000000,
        destroyed = 0x00000001,
    };

    pub const Descriptor = extern struct {
        pub const NextInChain = extern union {
            generic: ?*const ChainedStruct,
            dawn_toggles_device_descriptor: *const dawn.TogglesDeviceDescriptor,
            dawn_cache_device_descriptor: *const dawn.CacheDeviceDescriptor,
        };

        next_in_chain: NextInChain = .{ .generic = null },
        label: ?[*:0]const u8 = null,
        required_features_count: u32 = 0,
        required_features: ?[*]const FeatureName = null,
        required_limits: ?*const RequiredLimits = null,
        default_queue: Queue.Descriptor = Queue.Descriptor{},

        /// Provides a slightly friendlier Zig API to initialize this structure.
        pub inline fn init(v: struct {
            next_in_chain: NextInChain = .{ .generic = null },
            label: ?[*:0]const u8 = null,
            required_features: ?[]const FeatureName = null,
            required_limits: ?*const RequiredLimits = null,
            default_queue: Queue.Descriptor = Queue.Descriptor{},
        }) Descriptor {
            return .{
                .next_in_chain = v.next_in_chain,
                .label = v.label,
                .required_features_count = if (v.required_features) |e| @intCast(u32, e.len) else 0,
                .required_features = if (v.required_features) |e| e.ptr else null,
                .default_queue = v.default_queue,
            };
        }
    };
};
