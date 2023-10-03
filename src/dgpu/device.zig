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
const FeatureName = @import("main.zig").FeatureName;
const Limits = @import("main.zig").Limits;
const ErrorType = @import("main.zig").ErrorType;
const ErrorFilter = @import("main.zig").ErrorFilter;
const LoggingType = @import("main.zig").LoggingType;
const CreatePipelineAsyncStatus = @import("main.zig").CreatePipelineAsyncStatus;
const LoggingCallback = @import("main.zig").LoggingCallback;
const ErrorCallback = @import("main.zig").ErrorCallback;
const Impl = @import("interface.zig").Impl;

pub const Device = opaque {
    pub const LostCallback = *const fn (
        reason: LostReason,
        message: []const u8,
        userdata: ?*anyopaque,
    ) void;

    pub const LostReason = enum {
        undefined,
        destroyed,
    };

    pub const Descriptor = struct {
        label: ?[:0]const u8 = null,
        required_features: []const FeatureName = &.{},
        required_limits: Limits = .{},
        default_queue: Queue.Descriptor = Queue.Descriptor{},
        device_lost_callback: LostCallback,
        device_lost_userdata: ?*anyopaque,
    };

    pub inline fn createBindGroup(device: *Device, descriptor: BindGroup.Descriptor) *BindGroup {
        return Impl.deviceCreateBindGroup(device, descriptor);
    }

    pub inline fn createBindGroupLayout(device: *Device, descriptor: BindGroupLayout.Descriptor) *BindGroupLayout {
        return Impl.deviceCreateBindGroupLayout(device, descriptor);
    }

    pub inline fn createBuffer(device: *Device, descriptor: Buffer.Descriptor) *Buffer {
        return Impl.deviceCreateBuffer(device, descriptor);
    }

    pub inline fn createCommandEncoder(device: *Device, descriptor: CommandEncoder.Descriptor) *CommandEncoder {
        return Impl.deviceCreateCommandEncoder(device, descriptor);
    }

    pub inline fn createComputePipeline(device: *Device, descriptor: ComputePipeline.Descriptor) *ComputePipeline {
        return Impl.deviceCreateComputePipeline(device, descriptor);
    }

    pub inline fn createErrorBuffer(device: *Device, descriptor: Buffer.Descriptor) *Buffer {
        return Impl.deviceCreateErrorBuffer(device, descriptor);
    }

    pub inline fn createErrorExternalTexture(device: *Device) *ExternalTexture {
        return Impl.deviceCreateErrorExternalTexture(device);
    }

    pub inline fn createErrorTexture(device: *Device, descriptor: Texture.Descriptor) *Texture {
        return Impl.deviceCreateErrorTexture(device, descriptor);
    }

    pub inline fn createExternalTexture(device: *Device, external_texture_descriptor: ExternalTexture.Descriptor) *ExternalTexture {
        return Impl.deviceCreateExternalTexture(device, external_texture_descriptor);
    }

    pub inline fn createPipelineLayout(device: *Device, pipeline_layout_descriptor: PipelineLayout.Descriptor) *PipelineLayout {
        return Impl.deviceCreatePipelineLayout(device, pipeline_layout_descriptor);
    }

    pub inline fn createQuerySet(device: *Device, descriptor: QuerySet.Descriptor) *QuerySet {
        return Impl.deviceCreateQuerySet(device, descriptor);
    }

    pub inline fn createRenderBundleEncoder(device: *Device, descriptor: RenderBundleEncoder.Descriptor) *RenderBundleEncoder {
        return Impl.deviceCreateRenderBundleEncoder(device, descriptor);
    }

    pub inline fn createRenderPipeline(device: *Device, descriptor: RenderPipeline.Descriptor) *RenderPipeline {
        return Impl.deviceCreateRenderPipeline(device, descriptor);
    }

    pub inline fn createSampler(device: *Device, descriptor: Sampler.Descriptor) *Sampler {
        return Impl.deviceCreateSampler(device, descriptor);
    }

    pub inline fn createShaderModule(device: *Device, descriptor: ShaderModule.Descriptor) *ShaderModule {
        return Impl.deviceCreateShaderModule(device, descriptor);
    }

    pub inline fn createShaderModuleWGSL(device: *Device, label: ?[:0]const u8, code: [:0]const u8) *ShaderModule {
        return device.createShaderModule(.{ .label = label, .code = .{ .wgsl = code } });
    }

    pub inline fn createSwapChain(device: *Device, surface: ?*Surface, descriptor: SwapChain.Descriptor) *SwapChain {
        return Impl.deviceCreateSwapChain(device, surface, descriptor);
    }

    pub inline fn createTexture(device: *Device, descriptor: Texture.Descriptor) *Texture {
        return Impl.deviceCreateTexture(device, descriptor);
    }

    pub inline fn destroy(device: *Device) void {
        Impl.deviceDestroy(device);
    }

    /// Call once with null to determine the array length, and again to fetch the feature list.
    ///
    /// Consider using the enumerateFeaturesOwned helper.
    pub inline fn enumerateFeatures(device: *Device, features: ?[*]FeatureName) usize {
        return Impl.deviceEnumerateFeatures(device, features);
    }

    /// Enumerates the adapter features, storing the result in an allocated slice which is owned by
    /// the caller.
    pub inline fn enumerateFeaturesOwned(device: *Device, allocator: std.mem.Allocator) ![]FeatureName {
        const count = device.enumerateFeatures(null);
        var data = try allocator.alloc(FeatureName, count);
        _ = device.enumerateFeatures(data.ptr);
        return data;
    }

    pub inline fn forceLoss(device: *Device, reason: LostReason, message: []const u8) void {
        return Impl.deviceForceLoss(device, reason, message);
    }

    pub inline fn getAdapter(device: *Device) *Adapter {
        return Impl.deviceGetAdapter(device);
    }

    pub inline fn getLimits(device: *Device, limits: *Limits) bool {
        return Impl.deviceGetLimits(device, limits);
    }

    pub inline fn getQueue(device: *Device) *Queue {
        return Impl.deviceGetQueue(device);
    }

    pub inline fn hasFeature(device: *Device, feature: FeatureName) bool {
        return Impl.deviceHasFeature(device, feature);
    }

    pub inline fn injectError(device: *Device, typ: ErrorType, message: []const u8) void {
        Impl.deviceInjectError(device, typ, message);
    }

    pub inline fn popErrorScope(
        device: *Device,
        context: anytype,
        comptime callback: fn (ctx: @TypeOf(context), typ: ErrorType, message: []const u8) callconv(.Inline) void,
    ) void {
        Impl.devicePopErrorScope(device, context, callback);
    }

    pub inline fn pushErrorScope(device: *Device, filter: ErrorFilter) void {
        Impl.devicePushErrorScope(device, filter);
    }

    pub inline fn setDeviceLostCallback(
        device: *Device,
        context: anytype,
        comptime callback: ?fn (ctx: @TypeOf(context), reason: LostReason, message: []const u8) callconv(.Inline) void,
    ) void {
        if (callback) |cb| {
            const Context = @TypeOf(context);
            const Helper = struct {
                pub fn cCallback(userdata: ?*anyopaque, reason: LostReason, message: []const u8) void {
                    cb(if (Context == void) {} else @as(Context, @ptrCast(@alignCast(userdata))), reason, message);
                }
            };
            Impl.deviceSetDeviceLostCallback(device, if (Context == void) null else context, Helper.cCallback);
        } else {
            Impl.deviceSetDeviceLostCallback(device, null, null);
        }
    }

    pub inline fn setLabel(device: *Device, label: [:0]const u8) void {
        Impl.deviceSetLabel(device, label);
    }

    pub inline fn setLoggingCallback(
        device: *Device,
        context: anytype,
        comptime callback: ?fn (ctx: @TypeOf(context), typ: LoggingType, message: []const u8) callconv(.Inline) void,
    ) void {
        if (callback) |cb| {
            const Context = @TypeOf(context);
            const Helper = struct {
                pub fn cCallback(userdata: ?*anyopaque, log_type: LoggingType, message: []const u8) void {
                    cb(if (Context == void) {} else @as(Context, @ptrCast(@alignCast(userdata))), log_type, message);
                }
            };
            Impl.deviceSetLoggingCallback(device, if (Context == void) null else context, Helper.cCallback);
        } else {
            Impl.deviceSetLoggingCallback(device, null, null);
        }
    }

    pub inline fn setUncapturedErrorCallback(
        device: *Device,
        context: anytype,
        comptime callback: ?fn (ctx: @TypeOf(context), typ: ErrorType, message: []const u8) callconv(.Inline) void,
    ) void {
        if (callback) |cb| {
            const Context = @TypeOf(context);
            const Helper = struct {
                pub fn cCallback(userdata: ?*anyopaque, error_type: ErrorType, message: []const u8) void {
                    cb(if (Context == void) {} else @as(Context, @ptrCast(@alignCast(userdata))), error_type, message);
                }
            };
            Impl.deviceSetUncapturedErrorCallback(device, if (Context == void) null else context, Helper.cCallback);
        } else {
            Impl.deviceSetUncapturedErrorCallback(device, null, null);
        }
    }

    pub inline fn tick(device: *Device) void {
        Impl.deviceTick(device);
    }

    // Mach WebGPU extension. Supported with mach-gpu-dawn.
    //
    // When making Metal interop with other APIs, we need to be careful that QueueSubmit doesn't
    // mean that the operations will be visible to other APIs/Metal devices right away. macOS
    // does have a global queue of graphics operations, but the command buffers are inserted there
    // when they are "scheduled". Submitting other operations before the command buffer is
    // scheduled could lead to races in who gets scheduled first and incorrect rendering.
    pub inline fn machWaitForCommandsToBeScheduled(device: *Device) void {
        Impl.machDeviceWaitForCommandsToBeScheduled(device);
    }

    pub inline fn validateTextureDescriptor(device: *Device, descriptor: Texture.Descriptor) void {
        Impl.deviceVlidateTextureDescriptor(device, descriptor);
    }

    pub inline fn reference(device: *Device) void {
        Impl.deviceReference(device);
    }

    pub inline fn release(device: *Device) void {
        Impl.deviceRelease(device);
    }
};
