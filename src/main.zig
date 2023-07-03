const std = @import("std");
const builtin = @import("builtin");
const gpu = @import("mach-gpu");

var inited = false;
var allocator: std.mem.Allocator = undefined;
const impl = switch (builtin.os.tag) {
    .linux, .windows => @import("vulkan.zig"),
    .macos, .ios => @compileError("TODO: unsupported platform"),
    else => @compileError("unsupported platform"),
};

fn RefCounted(comptime T: type) type {
    return struct {
        ref_count: usize = 0,
        item: T,

        pub fn reference(self: *@This()) void {
            self.ref_count += 1;
        }

        pub fn release(self: *@This()) void {
            // If we try to release with no references, something went wrong!
            std.debug.assert(self.ref_count > 0);

            self.ref_count -= 1;
            if (self.ref_count == 0 and @hasField(T, "deinit")) {
                self.item.deinit();
            }
        }
    };
}

const Instance = RefCounted(impl.Instance);
const Adapter = RefCounted(impl.Adapter);
const Device = RefCounted(impl.Device);
const Surface = RefCounted(impl.Surface);

pub const Interface = struct {
    pub fn init(passed_allocator: std.mem.Allocator) void {
        inited = true;
        allocator = passed_allocator;
    }

    pub inline fn createInstance(descriptor: ?*const gpu.Instance.Descriptor) ?*gpu.Instance {
        if (builtin.mode == .Debug and !inited) {
            @panic("dusk: not initialized; did you forget to call gpu.Impl.init()?");
        }

        const instance = impl.Instance.init(descriptor orelse &gpu.Instance.Descriptor{}, allocator) catch return null;

        var instance_rc = allocator.create(Instance) catch return null;
        instance_rc.* = .{ .item = instance };
        instance_rc.reference();

        return @as(*gpu.Instance, @ptrCast(instance_rc));
    }

    pub inline fn getProcAddress(device: *gpu.Device, proc_name: [*:0]const u8) ?gpu.Proc {
        _ = device;
        _ = proc_name;
        unreachable;
    }

    pub inline fn adapterCreateDevice(adapter_raw: *gpu.Adapter, descriptor: ?*const gpu.Device.Descriptor) ?*gpu.Device {
        const adapter: *Adapter = @ptrCast(@alignCast(adapter_raw));

        const default_descriptor = gpu.Device.Descriptor{
            .device_lost_callback = undefined,
            .device_lost_userdata = null,
        };
        const device = adapter.item.createDevice(descriptor orelse &default_descriptor) catch return null;

        var device_rc = allocator.create(Device) catch return null;
        device_rc.* = .{ .item = device };
        device_rc.reference();

        return @as(*gpu.Device, @ptrCast(device_rc));
    }

    pub inline fn adapterEnumerateFeatures(adapter: *gpu.Adapter, features: ?[*]gpu.FeatureName) usize {
        _ = adapter;
        _ = features;
        unreachable;
    }

    pub inline fn adapterGetLimits(adapter: *gpu.Adapter, limits: *gpu.SupportedLimits) bool {
        _ = adapter;
        _ = limits;
        unreachable;
    }

    pub inline fn adapterGetInstance(adapter: *gpu.Adapter) *gpu.Instance {
        _ = adapter;
        unreachable;
    }

    pub inline fn adapterGetProperties(adapter_raw: *gpu.Adapter, properties: *gpu.Adapter.Properties) void {
        const adapter: *Adapter = @ptrCast(@alignCast(adapter_raw));
        properties.* = adapter.item.getProperties();
    }

    pub inline fn adapterHasFeature(adapter: *gpu.Adapter, feature: gpu.FeatureName) bool {
        _ = adapter;
        _ = feature;
        unreachable;
    }

    pub inline fn adapterRequestDevice(adapter: *gpu.Adapter, descriptor: ?*const gpu.Device.Descriptor, callback: gpu.RequestDeviceCallback, userdata: ?*anyopaque) void {
        _ = adapter;
        _ = descriptor;
        _ = callback;
        _ = userdata;
        unreachable;
    }

    pub inline fn adapterReference(adapter_raw: *gpu.Adapter) void {
        var adapter: *Adapter = @ptrCast(@alignCast(adapter_raw));
        adapter.reference();
    }

    pub inline fn adapterRelease(adapter_raw: *gpu.Adapter) void {
        var adapter: *Adapter = @ptrCast(@alignCast(adapter_raw));
        adapter.release();
    }

    pub inline fn bindGroupSetLabel(bind_group: *gpu.BindGroup, label: [*:0]const u8) void {
        _ = bind_group;
        _ = label;
        unreachable;
    }

    pub inline fn bindGroupReference(bind_group: *gpu.BindGroup) void {
        _ = bind_group;
        unreachable;
    }

    pub inline fn bindGroupRelease(bind_group: *gpu.BindGroup) void {
        _ = bind_group;
        unreachable;
    }

    pub inline fn bindGroupLayoutSetLabel(bind_group_layout: *gpu.BindGroupLayout, label: [*:0]const u8) void {
        _ = bind_group_layout;
        _ = label;
        unreachable;
    }

    pub inline fn bindGroupLayoutReference(bind_group_layout: *gpu.BindGroupLayout) void {
        _ = bind_group_layout;
        unreachable;
    }

    pub inline fn bindGroupLayoutRelease(bind_group_layout: *gpu.BindGroupLayout) void {
        _ = bind_group_layout;
        unreachable;
    }

    pub inline fn bufferDestroy(buffer: *gpu.Buffer) void {
        _ = buffer;
        unreachable;
    }

    pub inline fn bufferGetConstMappedRange(buffer: *gpu.Buffer, offset: usize, size: usize) ?*const anyopaque {
        _ = buffer;
        _ = offset;
        _ = size;
        unreachable;
    }

    pub inline fn bufferGetMappedRange(buffer: *gpu.Buffer, offset: usize, size: usize) ?*anyopaque {
        _ = buffer;
        _ = offset;
        _ = size;
        unreachable;
    }

    pub inline fn bufferGetSize(buffer: *gpu.Buffer) u64 {
        _ = buffer;
        unreachable;
    }

    pub inline fn bufferGetUsage(buffer: *gpu.Buffer) gpu.Buffer.UsageFlags {
        _ = buffer;
        unreachable;
    }

    pub inline fn bufferMapAsync(buffer: *gpu.Buffer, mode: gpu.MapModeFlags, offset: usize, size: usize, callback: gpu.Buffer.MapCallback, userdata: ?*anyopaque) void {
        _ = buffer;
        _ = mode;
        _ = offset;
        _ = size;
        _ = callback;
        _ = userdata;
        unreachable;
    }

    pub inline fn bufferSetLabel(buffer: *gpu.Buffer, label: [*:0]const u8) void {
        _ = buffer;
        _ = label;
        unreachable;
    }

    pub inline fn bufferUnmap(buffer: *gpu.Buffer) void {
        _ = buffer;
        unreachable;
    }

    pub inline fn bufferReference(buffer: *gpu.Buffer) void {
        _ = buffer;
        unreachable;
    }

    pub inline fn bufferRelease(buffer: *gpu.Buffer) void {
        _ = buffer;
        unreachable;
    }

    pub inline fn commandBufferSetLabel(command_buffer: *gpu.CommandBuffer, label: [*:0]const u8) void {
        _ = command_buffer;
        _ = label;
        unreachable;
    }

    pub inline fn commandBufferReference(command_buffer: *gpu.CommandBuffer) void {
        _ = command_buffer;
        unreachable;
    }

    pub inline fn commandBufferRelease(command_buffer: *gpu.CommandBuffer) void {
        _ = command_buffer;
        unreachable;
    }

    pub inline fn commandEncoderBeginComputePass(command_encoder: *gpu.CommandEncoder, descriptor: ?*const gpu.ComputePassDescriptor) *gpu.ComputePassEncoder {
        _ = command_encoder;
        _ = descriptor;
        unreachable;
    }

    pub inline fn commandEncoderBeginRenderPass(command_encoder: *gpu.CommandEncoder, descriptor: *const gpu.RenderPassDescriptor) *gpu.RenderPassEncoder {
        _ = command_encoder;
        _ = descriptor;
        unreachable;
    }

    pub inline fn commandEncoderClearBuffer(command_encoder: *gpu.CommandEncoder, buffer: *gpu.Buffer, offset: u64, size: u64) void {
        _ = command_encoder;
        _ = buffer;
        _ = offset;
        _ = size;
        unreachable;
    }

    pub inline fn commandEncoderCopyBufferToBuffer(command_encoder: *gpu.CommandEncoder, source: *gpu.Buffer, source_offset: u64, destination: *gpu.Buffer, destination_offset: u64, size: u64) void {
        _ = command_encoder;
        _ = source;
        _ = source_offset;
        _ = destination;
        _ = destination_offset;
        _ = size;
        unreachable;
    }

    pub inline fn commandEncoderCopyBufferToTexture(command_encoder: *gpu.CommandEncoder, source: *const gpu.ImageCopyBuffer, destination: *const gpu.ImageCopyTexture, copy_size: *const gpu.Extent3D) void {
        _ = command_encoder;
        _ = source;
        _ = destination;
        _ = copy_size;
        unreachable;
    }

    pub inline fn commandEncoderCopyTextureToBuffer(command_encoder: *gpu.CommandEncoder, source: *const gpu.ImageCopyTexture, destination: *const gpu.ImageCopyBuffer, copy_size: *const gpu.Extent3D) void {
        _ = command_encoder;
        _ = source;
        _ = destination;
        _ = copy_size;
        unreachable;
    }

    pub inline fn commandEncoderCopyTextureToTexture(command_encoder: *gpu.CommandEncoder, source: *const gpu.ImageCopyTexture, destination: *const gpu.ImageCopyTexture, copy_size: *const gpu.Extent3D) void {
        _ = command_encoder;
        _ = source;
        _ = destination;
        _ = copy_size;
        unreachable;
    }

    pub inline fn commandEncoderCopyTextureToTextureInternal(command_encoder: *gpu.CommandEncoder, source: *const gpu.ImageCopyTexture, destination: *const gpu.ImageCopyTexture, copy_size: *const gpu.Extent3D) void {
        _ = command_encoder;
        _ = source;
        _ = destination;
        _ = copy_size;
        unreachable;
    }

    pub inline fn commandEncoderFinish(command_encoder: *gpu.CommandEncoder, descriptor: ?*const gpu.CommandBuffer.Descriptor) *gpu.CommandBuffer {
        _ = command_encoder;
        _ = descriptor;
        unreachable;
    }

    pub inline fn commandEncoderInjectValidationError(command_encoder: *gpu.CommandEncoder, message: [*:0]const u8) void {
        _ = command_encoder;
        _ = message;
        unreachable;
    }

    pub inline fn commandEncoderInsertDebugMarker(command_encoder: *gpu.CommandEncoder, marker_label: [*:0]const u8) void {
        _ = command_encoder;
        _ = marker_label;
        unreachable;
    }

    pub inline fn commandEncoderPopDebugGroup(command_encoder: *gpu.CommandEncoder) void {
        _ = command_encoder;
        unreachable;
    }

    pub inline fn commandEncoderPushDebugGroup(command_encoder: *gpu.CommandEncoder, group_label: [*:0]const u8) void {
        _ = command_encoder;
        _ = group_label;
        unreachable;
    }

    pub inline fn commandEncoderResolveQuerySet(command_encoder: *gpu.CommandEncoder, query_set: *gpu.QuerySet, first_query: u32, query_count: u32, destination: *gpu.Buffer, destination_offset: u64) void {
        _ = command_encoder;
        _ = query_set;
        _ = first_query;
        _ = query_count;
        _ = destination;
        _ = destination_offset;
        unreachable;
    }

    pub inline fn commandEncoderSetLabel(command_encoder: *gpu.CommandEncoder, label: [*:0]const u8) void {
        _ = command_encoder;
        _ = label;
        unreachable;
    }

    pub inline fn commandEncoderWriteBuffer(command_encoder: *gpu.CommandEncoder, buffer: *gpu.Buffer, buffer_offset: u64, data: [*]const u8, size: u64) void {
        _ = command_encoder;
        _ = buffer;
        _ = buffer_offset;
        _ = data;
        _ = size;
        unreachable;
    }

    pub inline fn commandEncoderWriteTimestamp(command_encoder: *gpu.CommandEncoder, query_set: *gpu.QuerySet, query_index: u32) void {
        _ = command_encoder;
        _ = query_set;
        _ = query_index;
        unreachable;
    }

    pub inline fn commandEncoderReference(command_encoder: *gpu.CommandEncoder) void {
        _ = command_encoder;
        unreachable;
    }

    pub inline fn commandEncoderRelease(command_encoder: *gpu.CommandEncoder) void {
        _ = command_encoder;
        unreachable;
    }

    pub inline fn computePassEncoderDispatchWorkgroups(compute_pass_encoder: *gpu.ComputePassEncoder, workgroup_count_x: u32, workgroup_count_y: u32, workgroup_count_z: u32) void {
        _ = compute_pass_encoder;
        _ = workgroup_count_x;
        _ = workgroup_count_y;
        _ = workgroup_count_z;
        unreachable;
    }

    pub inline fn computePassEncoderDispatchWorkgroupsIndirect(compute_pass_encoder: *gpu.ComputePassEncoder, indirect_buffer: *gpu.Buffer, indirect_offset: u64) void {
        _ = compute_pass_encoder;
        _ = indirect_buffer;
        _ = indirect_offset;
        unreachable;
    }

    pub inline fn computePassEncoderEnd(compute_pass_encoder: *gpu.ComputePassEncoder) void {
        _ = compute_pass_encoder;
        unreachable;
    }

    pub inline fn computePassEncoderInsertDebugMarker(compute_pass_encoder: *gpu.ComputePassEncoder, marker_label: [*:0]const u8) void {
        _ = compute_pass_encoder;
        _ = marker_label;
        unreachable;
    }

    pub inline fn computePassEncoderPopDebugGroup(compute_pass_encoder: *gpu.ComputePassEncoder) void {
        _ = compute_pass_encoder;
        unreachable;
    }

    pub inline fn computePassEncoderPushDebugGroup(compute_pass_encoder: *gpu.ComputePassEncoder, group_label: [*:0]const u8) void {
        _ = compute_pass_encoder;
        _ = group_label;
        unreachable;
    }

    pub inline fn computePassEncoderSetBindGroup(compute_pass_encoder: *gpu.ComputePassEncoder, group_index: u32, group: *gpu.BindGroup, dynamic_offset_count: usize, dynamic_offsets: ?[*]const u32) void {
        _ = compute_pass_encoder;
        _ = group_index;
        _ = group;
        _ = dynamic_offset_count;
        _ = dynamic_offsets;
        unreachable;
    }

    pub inline fn computePassEncoderSetLabel(compute_pass_encoder: *gpu.ComputePassEncoder, label: [*:0]const u8) void {
        _ = compute_pass_encoder;
        _ = label;
        unreachable;
    }

    pub inline fn computePassEncoderSetPipeline(compute_pass_encoder: *gpu.ComputePassEncoder, pipeline: *gpu.ComputePipeline) void {
        _ = compute_pass_encoder;
        _ = pipeline;
        unreachable;
    }

    pub inline fn computePassEncoderWriteTimestamp(compute_pass_encoder: *gpu.ComputePassEncoder, query_set: *gpu.QuerySet, query_index: u32) void {
        _ = compute_pass_encoder;
        _ = query_set;
        _ = query_index;
        unreachable;
    }

    pub inline fn computePassEncoderReference(compute_pass_encoder: *gpu.ComputePassEncoder) void {
        _ = compute_pass_encoder;
        unreachable;
    }

    pub inline fn computePassEncoderRelease(compute_pass_encoder: *gpu.ComputePassEncoder) void {
        _ = compute_pass_encoder;
        unreachable;
    }

    pub inline fn computePipelineGetBindGroupLayout(compute_pipeline: *gpu.ComputePipeline, group_index: u32) *gpu.BindGroupLayout {
        _ = compute_pipeline;
        _ = group_index;
        unreachable;
    }

    pub inline fn computePipelineSetLabel(compute_pipeline: *gpu.ComputePipeline, label: [*:0]const u8) void {
        _ = compute_pipeline;
        _ = label;
        unreachable;
    }

    pub inline fn computePipelineReference(compute_pipeline: *gpu.ComputePipeline) void {
        _ = compute_pipeline;
        unreachable;
    }

    pub inline fn computePipelineRelease(compute_pipeline: *gpu.ComputePipeline) void {
        _ = compute_pipeline;
        unreachable;
    }

    pub inline fn deviceCreateBindGroup(device: *gpu.Device, descriptor: *const gpu.BindGroup.Descriptor) *gpu.BindGroup {
        _ = device;
        _ = descriptor;
        unreachable;
    }

    pub inline fn deviceCreateBindGroupLayout(device: *gpu.Device, descriptor: *const gpu.BindGroupLayout.Descriptor) *gpu.BindGroupLayout {
        _ = device;
        _ = descriptor;
        unreachable;
    }

    pub inline fn deviceCreateBuffer(device: *gpu.Device, descriptor: *const gpu.Buffer.Descriptor) *gpu.Buffer {
        _ = device;
        _ = descriptor;
        unreachable;
    }

    pub inline fn deviceCreateCommandEncoder(device: *gpu.Device, descriptor: ?*const gpu.CommandEncoder.Descriptor) *gpu.CommandEncoder {
        _ = device;
        _ = descriptor;
        unreachable;
    }

    pub inline fn deviceCreateComputePipeline(device: *gpu.Device, descriptor: *const gpu.ComputePipeline.Descriptor) *gpu.ComputePipeline {
        _ = device;
        _ = descriptor;
        unreachable;
    }

    pub inline fn deviceCreateComputePipelineAsync(device: *gpu.Device, descriptor: *const gpu.ComputePipeline.Descriptor, callback: gpu.CreateComputePipelineAsyncCallback, userdata: ?*anyopaque) void {
        _ = device;
        _ = descriptor;
        _ = callback;
        _ = userdata;
        unreachable;
    }

    pub inline fn deviceCreateErrorBuffer(device: *gpu.Device, descriptor: *const gpu.Buffer.Descriptor) *gpu.Buffer {
        _ = device;
        _ = descriptor;
        unreachable;
    }

    pub inline fn deviceCreateErrorExternalTexture(device: *gpu.Device) *gpu.ExternalTexture {
        _ = device;
        unreachable;
    }

    pub inline fn deviceCreateErrorTexture(device: *gpu.Device, descriptor: *const gpu.Texture.Descriptor) *gpu.Texture {
        _ = device;
        _ = descriptor;
        unreachable;
    }

    pub inline fn deviceCreateExternalTexture(device: *gpu.Device, external_texture_descriptor: *const gpu.ExternalTexture.Descriptor) *gpu.ExternalTexture {
        _ = device;
        _ = external_texture_descriptor;
        unreachable;
    }

    pub inline fn deviceCreatePipelineLayout(device: *gpu.Device, pipeline_layout_descriptor: *const gpu.PipelineLayout.Descriptor) *gpu.PipelineLayout {
        _ = device;
        _ = pipeline_layout_descriptor;
        unreachable;
    }

    pub inline fn deviceCreateQuerySet(device: *gpu.Device, descriptor: *const gpu.QuerySet.Descriptor) *gpu.QuerySet {
        _ = device;
        _ = descriptor;
        unreachable;
    }

    pub inline fn deviceCreateRenderBundleEncoder(device: *gpu.Device, descriptor: *const gpu.RenderBundleEncoder.Descriptor) *gpu.RenderBundleEncoder {
        _ = device;
        _ = descriptor;
        unreachable;
    }

    pub inline fn deviceCreateRenderPipeline(device: *gpu.Device, descriptor: *const gpu.RenderPipeline.Descriptor) *gpu.RenderPipeline {
        _ = device;
        _ = descriptor;
        unreachable;
    }

    pub inline fn deviceCreateRenderPipelineAsync(device: *gpu.Device, descriptor: *const gpu.RenderPipeline.Descriptor, callback: gpu.CreateRenderPipelineAsyncCallback, userdata: ?*anyopaque) void {
        _ = device;
        _ = descriptor;
        _ = callback;
        _ = userdata;
        unreachable;
    }

    pub fn deviceCreateSampler(device: *gpu.Device, descriptor: ?*const gpu.Sampler.Descriptor) *gpu.Sampler {
        _ = device;
        _ = descriptor;
        unreachable;
    }

    pub inline fn deviceCreateShaderModule(device: *gpu.Device, descriptor: *const gpu.ShaderModule.Descriptor) *gpu.ShaderModule {
        _ = device;
        _ = descriptor;
        unreachable;
    }

    pub inline fn deviceCreateSwapChain(device: *gpu.Device, surface: ?*gpu.Surface, descriptor: *const gpu.SwapChain.Descriptor) *gpu.SwapChain {
        _ = device;
        _ = surface;
        _ = descriptor;
        unreachable;
    }

    pub inline fn deviceCreateTexture(device: *gpu.Device, descriptor: *const gpu.Texture.Descriptor) *gpu.Texture {
        _ = device;
        _ = descriptor;
        unreachable;
    }

    pub inline fn deviceDestroy(device: *gpu.Device) void {
        _ = device;
        unreachable;
    }

    pub inline fn deviceEnumerateFeatures(device: *gpu.Device, features: ?[*]gpu.FeatureName) usize {
        _ = device;
        _ = features;
        unreachable;
    }

    pub inline fn deviceGetLimits(device: *gpu.Device, limits: *gpu.SupportedLimits) bool {
        _ = device;
        _ = limits;
        unreachable;
    }

    pub inline fn deviceGetQueue(device: *gpu.Device) *gpu.Queue {
        _ = device;
        unreachable;
    }

    pub inline fn deviceHasFeature(device: *gpu.Device, feature: gpu.FeatureName) bool {
        _ = device;
        _ = feature;
        unreachable;
    }

    pub inline fn deviceInjectError(device: *gpu.Device, typ: gpu.ErrorType, message: [*:0]const u8) void {
        _ = device;
        _ = typ;
        _ = message;
        unreachable;
    }

    pub inline fn deviceLoseForTesting(device: *gpu.Device) void {
        _ = device;
        unreachable;
    }

    pub inline fn devicePopErrorScope(device: *gpu.Device, callback: gpu.ErrorCallback, userdata: ?*anyopaque) void {
        _ = device;
        _ = callback;
        _ = userdata;
        unreachable;
    }

    pub inline fn devicePushErrorScope(device: *gpu.Device, filter: gpu.ErrorFilter) void {
        _ = device;
        _ = filter;
        unreachable;
    }

    pub inline fn deviceSetDeviceLostCallback(device: *gpu.Device, callback: ?gpu.Device.LostCallback, userdata: ?*anyopaque) void {
        _ = device;
        _ = callback;
        _ = userdata;
        unreachable;
    }

    pub inline fn deviceSetLabel(device: *gpu.Device, label: [*:0]const u8) void {
        _ = device;
        _ = label;
        unreachable;
    }

    pub inline fn deviceSetLoggingCallback(device: *gpu.Device, callback: ?gpu.LoggingCallback, userdata: ?*anyopaque) void {
        _ = device;
        _ = callback;
        _ = userdata;
        unreachable;
    }

    pub inline fn deviceSetUncapturedErrorCallback(device: *gpu.Device, callback: ?gpu.ErrorCallback, userdata: ?*anyopaque) void {
        _ = device;
        _ = callback;
        _ = userdata;
        unreachable;
    }

    pub inline fn deviceTick(device: *gpu.Device) void {
        _ = device;
        unreachable;
    }

    pub inline fn deviceReference(device_raw: *gpu.Device) void {
        var device: *Device = @ptrCast(@alignCast(device_raw));
        device.reference();
    }

    pub inline fn deviceRelease(device_raw: *gpu.Device) void {
        var device: *Device = @ptrCast(@alignCast(device_raw));
        device.release();
    }

    pub inline fn externalTextureDestroy(external_texture: *gpu.ExternalTexture) void {
        _ = external_texture;
        unreachable;
    }

    pub inline fn externalTextureSetLabel(external_texture: *gpu.ExternalTexture, label: [*:0]const u8) void {
        _ = external_texture;
        _ = label;
        unreachable;
    }

    pub inline fn externalTextureReference(external_texture: *gpu.ExternalTexture) void {
        _ = external_texture;
        unreachable;
    }

    pub inline fn externalTextureRelease(external_texture: *gpu.ExternalTexture) void {
        _ = external_texture;
        unreachable;
    }

    pub inline fn instanceCreateSurface(instance_raw: *gpu.Instance, descriptor: *const gpu.Surface.Descriptor) *gpu.Surface {
        const instance: *Instance = @ptrCast(@alignCast(instance_raw));
        const surface = impl.Instance.createSurface(instance.item, descriptor) catch unreachable;

        var surface_rc = allocator.create(Surface) catch unreachable;
        surface_rc.* = .{ .item = surface };
        surface_rc.reference();

        return @ptrCast(surface_rc);
    }

    pub inline fn instanceProcessEvents(instance: *gpu.Instance) void {
        _ = instance;
        unreachable;
    }

    pub inline fn instanceRequestAdapter(
        instance_raw: *gpu.Instance,
        options: ?*const gpu.RequestAdapterOptions,
        callback: gpu.RequestAdapterCallback,
        userdata: ?*anyopaque,
    ) void {
        const instance: *Instance = @ptrCast(@alignCast(instance_raw));
        const adapter = impl.Adapter.init(instance.item, options orelse &gpu.RequestAdapterOptions{}) catch |err| {
            return callback(.err, undefined, @errorName(err), userdata);
        };

        var adapter_rc = allocator.create(Adapter) catch |err| {
            return callback(.err, undefined, @errorName(err), userdata);
        };
        adapter_rc.* = .{ .item = adapter };
        adapter_rc.reference();

        callback(.success, @as(*gpu.Adapter, @ptrCast(adapter_rc)), null, userdata);
    }

    pub inline fn instanceReference(instance_raw: *gpu.Instance) void {
        var instance: *Instance = @ptrCast(@alignCast(instance_raw));
        instance.reference();
    }

    pub inline fn instanceRelease(instance_raw: *gpu.Instance) void {
        var instance: *Instance = @ptrCast(@alignCast(instance_raw));
        instance.release();
    }

    pub inline fn pipelineLayoutSetLabel(pipeline_layout: *gpu.PipelineLayout, label: [*:0]const u8) void {
        _ = pipeline_layout;
        _ = label;
        unreachable;
    }

    pub inline fn pipelineLayoutReference(pipeline_layout: *gpu.PipelineLayout) void {
        _ = pipeline_layout;
        unreachable;
    }

    pub inline fn pipelineLayoutRelease(pipeline_layout: *gpu.PipelineLayout) void {
        _ = pipeline_layout;
        unreachable;
    }

    pub inline fn querySetDestroy(query_set: *gpu.QuerySet) void {
        _ = query_set;
        unreachable;
    }

    pub inline fn querySetGetCount(query_set: *gpu.QuerySet) u32 {
        _ = query_set;
        unreachable;
    }

    pub inline fn querySetGetType(query_set: *gpu.QuerySet) gpu.QueryType {
        _ = query_set;
        unreachable;
    }

    pub inline fn querySetSetLabel(query_set: *gpu.QuerySet, label: [*:0]const u8) void {
        _ = query_set;
        _ = label;
        unreachable;
    }

    pub inline fn querySetReference(query_set: *gpu.QuerySet) void {
        _ = query_set;
        unreachable;
    }

    pub inline fn querySetRelease(query_set: *gpu.QuerySet) void {
        _ = query_set;
        unreachable;
    }

    pub inline fn queueCopyTextureForBrowser(queue: *gpu.Queue, source: *const gpu.ImageCopyTexture, destination: *const gpu.ImageCopyTexture, copy_size: *const gpu.Extent3D, options: *const gpu.CopyTextureForBrowserOptions) void {
        _ = queue;
        _ = source;
        _ = destination;
        _ = copy_size;
        _ = options;
        unreachable;
    }

    pub inline fn queueOnSubmittedWorkDone(queue: *gpu.Queue, signal_value: u64, callback: gpu.Queue.WorkDoneCallback, userdata: ?*anyopaque) void {
        _ = queue;
        _ = signal_value;
        _ = callback;
        _ = userdata;
        unreachable;
    }

    pub inline fn queueSetLabel(queue: *gpu.Queue, label: [*:0]const u8) void {
        _ = queue;
        _ = label;
        unreachable;
    }

    pub inline fn queueSubmit(queue: *gpu.Queue, command_count: usize, commands: [*]const *const gpu.CommandBuffer) void {
        _ = queue;
        _ = command_count;
        _ = commands;
        unreachable;
    }

    pub inline fn queueWriteBuffer(queue: *gpu.Queue, buffer: *gpu.Buffer, buffer_offset: u64, data: *const anyopaque, size: usize) void {
        _ = queue;
        _ = buffer;
        _ = buffer_offset;
        _ = data;
        _ = size;
        unreachable;
    }

    pub inline fn queueWriteTexture(queue: *gpu.Queue, destination: *const gpu.ImageCopyTexture, data: *const anyopaque, data_size: usize, data_layout: *const gpu.Texture.DataLayout, write_size: *const gpu.Extent3D) void {
        _ = queue;
        _ = destination;
        _ = data;
        _ = data_size;
        _ = data_layout;
        _ = write_size;
        unreachable;
    }

    pub inline fn queueReference(queue: *gpu.Queue) void {
        _ = queue;
        unreachable;
    }

    pub inline fn queueRelease(queue: *gpu.Queue) void {
        _ = queue;
        unreachable;
    }

    pub inline fn renderBundleReference(render_bundle: *gpu.RenderBundle) void {
        _ = render_bundle;
        unreachable;
    }

    pub inline fn renderBundleRelease(render_bundle: *gpu.RenderBundle) void {
        _ = render_bundle;
        unreachable;
    }

    pub inline fn renderBundleSetLabel(render_bundle: *gpu.RenderBundle, name: [*:0]const u8) void {
        _ = name;
        _ = render_bundle;
        unreachable;
    }

    pub inline fn renderBundleEncoderDraw(render_bundle_encoder: *gpu.RenderBundleEncoder, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void {
        _ = render_bundle_encoder;
        _ = vertex_count;
        _ = instance_count;
        _ = first_vertex;
        _ = first_instance;
        unreachable;
    }

    pub inline fn renderBundleEncoderDrawIndexed(render_bundle_encoder: *gpu.RenderBundleEncoder, index_count: u32, instance_count: u32, first_index: u32, base_vertex: i32, first_instance: u32) void {
        _ = render_bundle_encoder;
        _ = index_count;
        _ = instance_count;
        _ = first_index;
        _ = base_vertex;
        _ = first_instance;
        unreachable;
    }

    pub inline fn renderBundleEncoderDrawIndexedIndirect(render_bundle_encoder: *gpu.RenderBundleEncoder, indirect_buffer: *gpu.Buffer, indirect_offset: u64) void {
        _ = render_bundle_encoder;
        _ = indirect_buffer;
        _ = indirect_offset;
        unreachable;
    }

    pub inline fn renderBundleEncoderDrawIndirect(render_bundle_encoder: *gpu.RenderBundleEncoder, indirect_buffer: *gpu.Buffer, indirect_offset: u64) void {
        _ = render_bundle_encoder;
        _ = indirect_buffer;
        _ = indirect_offset;
        unreachable;
    }

    pub inline fn renderBundleEncoderFinish(render_bundle_encoder: *gpu.RenderBundleEncoder, descriptor: ?*const gpu.RenderBundle.Descriptor) *gpu.RenderBundle {
        _ = render_bundle_encoder;
        _ = descriptor;
        unreachable;
    }

    pub inline fn renderBundleEncoderInsertDebugMarker(render_bundle_encoder: *gpu.RenderBundleEncoder, marker_label: [*:0]const u8) void {
        _ = render_bundle_encoder;
        _ = marker_label;
        unreachable;
    }

    pub inline fn renderBundleEncoderPopDebugGroup(render_bundle_encoder: *gpu.RenderBundleEncoder) void {
        _ = render_bundle_encoder;
        unreachable;
    }

    pub inline fn renderBundleEncoderPushDebugGroup(render_bundle_encoder: *gpu.RenderBundleEncoder, group_label: [*:0]const u8) void {
        _ = render_bundle_encoder;
        _ = group_label;
        unreachable;
    }

    pub inline fn renderBundleEncoderSetBindGroup(render_bundle_encoder: *gpu.RenderBundleEncoder, group_index: u32, group: *gpu.BindGroup, dynamic_offset_count: usize, dynamic_offsets: ?[*]const u32) void {
        _ = render_bundle_encoder;
        _ = group_index;
        _ = group;
        _ = dynamic_offset_count;
        _ = dynamic_offsets;
        unreachable;
    }

    pub inline fn renderBundleEncoderSetIndexBuffer(render_bundle_encoder: *gpu.RenderBundleEncoder, buffer: *gpu.Buffer, format: gpu.IndexFormat, offset: u64, size: u64) void {
        _ = render_bundle_encoder;
        _ = buffer;
        _ = format;
        _ = offset;
        _ = size;
        unreachable;
    }

    pub inline fn renderBundleEncoderSetLabel(render_bundle_encoder: *gpu.RenderBundleEncoder, label: [*:0]const u8) void {
        _ = render_bundle_encoder;
        _ = label;
        unreachable;
    }

    pub inline fn renderBundleEncoderSetPipeline(render_bundle_encoder: *gpu.RenderBundleEncoder, pipeline: *gpu.RenderPipeline) void {
        _ = render_bundle_encoder;
        _ = pipeline;
        unreachable;
    }

    pub inline fn renderBundleEncoderSetVertexBuffer(render_bundle_encoder: *gpu.RenderBundleEncoder, slot: u32, buffer: *gpu.Buffer, offset: u64, size: u64) void {
        _ = render_bundle_encoder;
        _ = slot;
        _ = buffer;
        _ = offset;
        _ = size;
        unreachable;
    }

    pub inline fn renderBundleEncoderReference(render_bundle_encoder: *gpu.RenderBundleEncoder) void {
        _ = render_bundle_encoder;
        unreachable;
    }

    pub inline fn renderBundleEncoderRelease(render_bundle_encoder: *gpu.RenderBundleEncoder) void {
        _ = render_bundle_encoder;
        unreachable;
    }

    pub inline fn renderPassEncoderBeginOcclusionQuery(render_pass_encoder: *gpu.RenderPassEncoder, query_index: u32) void {
        _ = render_pass_encoder;
        _ = query_index;
        unreachable;
    }

    pub inline fn renderPassEncoderDraw(render_pass_encoder: *gpu.RenderPassEncoder, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void {
        _ = render_pass_encoder;
        _ = vertex_count;
        _ = instance_count;
        _ = first_vertex;
        _ = first_instance;
        unreachable;
    }

    pub inline fn renderPassEncoderDrawIndexed(render_pass_encoder: *gpu.RenderPassEncoder, index_count: u32, instance_count: u32, first_index: u32, base_vertex: i32, first_instance: u32) void {
        _ = render_pass_encoder;
        _ = index_count;
        _ = instance_count;
        _ = first_index;
        _ = base_vertex;
        _ = first_instance;
        unreachable;
    }

    pub inline fn renderPassEncoderDrawIndexedIndirect(render_pass_encoder: *gpu.RenderPassEncoder, indirect_buffer: *gpu.Buffer, indirect_offset: u64) void {
        _ = render_pass_encoder;
        _ = indirect_buffer;
        _ = indirect_offset;
        unreachable;
    }

    pub inline fn renderPassEncoderDrawIndirect(render_pass_encoder: *gpu.RenderPassEncoder, indirect_buffer: *gpu.Buffer, indirect_offset: u64) void {
        _ = render_pass_encoder;
        _ = indirect_buffer;
        _ = indirect_offset;
        unreachable;
    }

    pub inline fn renderPassEncoderEnd(render_pass_encoder: *gpu.RenderPassEncoder) void {
        _ = render_pass_encoder;
        unreachable;
    }

    pub inline fn renderPassEncoderEndOcclusionQuery(render_pass_encoder: *gpu.RenderPassEncoder) void {
        _ = render_pass_encoder;
        unreachable;
    }

    pub inline fn renderPassEncoderExecuteBundles(render_pass_encoder: *gpu.RenderPassEncoder, bundles_count: usize, bundles: [*]const *const gpu.RenderBundle) void {
        _ = render_pass_encoder;
        _ = bundles_count;
        _ = bundles;
        unreachable;
    }

    pub inline fn renderPassEncoderInsertDebugMarker(render_pass_encoder: *gpu.RenderPassEncoder, marker_label: [*:0]const u8) void {
        _ = render_pass_encoder;
        _ = marker_label;
        unreachable;
    }

    pub inline fn renderPassEncoderPopDebugGroup(render_pass_encoder: *gpu.RenderPassEncoder) void {
        _ = render_pass_encoder;
        unreachable;
    }

    pub inline fn renderPassEncoderPushDebugGroup(render_pass_encoder: *gpu.RenderPassEncoder, group_label: [*:0]const u8) void {
        _ = render_pass_encoder;
        _ = group_label;
        unreachable;
    }

    pub inline fn renderPassEncoderSetBindGroup(render_pass_encoder: *gpu.RenderPassEncoder, group_index: u32, group: *gpu.BindGroup, dynamic_offset_count: usize, dynamic_offsets: ?[*]const u32) void {
        _ = render_pass_encoder;
        _ = group_index;
        _ = group;
        _ = dynamic_offset_count;
        _ = dynamic_offsets;
        unreachable;
    }

    pub inline fn renderPassEncoderSetBlendConstant(render_pass_encoder: *gpu.RenderPassEncoder, color: *const gpu.Color) void {
        _ = render_pass_encoder;
        _ = color;
        unreachable;
    }

    pub inline fn renderPassEncoderSetIndexBuffer(render_pass_encoder: *gpu.RenderPassEncoder, buffer: *gpu.Buffer, format: gpu.IndexFormat, offset: u64, size: u64) void {
        _ = render_pass_encoder;
        _ = buffer;
        _ = format;
        _ = offset;
        _ = size;
        unreachable;
    }

    pub inline fn renderPassEncoderSetLabel(render_pass_encoder: *gpu.RenderPassEncoder, label: [*:0]const u8) void {
        _ = render_pass_encoder;
        _ = label;
        unreachable;
    }

    pub inline fn renderPassEncoderSetPipeline(render_pass_encoder: *gpu.RenderPassEncoder, pipeline: *gpu.RenderPipeline) void {
        _ = render_pass_encoder;
        _ = pipeline;
        unreachable;
    }

    pub inline fn renderPassEncoderSetScissorRect(render_pass_encoder: *gpu.RenderPassEncoder, x: u32, y: u32, width: u32, height: u32) void {
        _ = render_pass_encoder;
        _ = x;
        _ = y;
        _ = width;
        _ = height;
        unreachable;
    }

    pub inline fn renderPassEncoderSetStencilReference(render_pass_encoder: *gpu.RenderPassEncoder, reference: u32) void {
        _ = render_pass_encoder;
        _ = reference;
        unreachable;
    }

    pub inline fn renderPassEncoderSetVertexBuffer(render_pass_encoder: *gpu.RenderPassEncoder, slot: u32, buffer: *gpu.Buffer, offset: u64, size: u64) void {
        _ = render_pass_encoder;
        _ = slot;
        _ = buffer;
        _ = offset;
        _ = size;
        unreachable;
    }

    pub inline fn renderPassEncoderSetViewport(render_pass_encoder: *gpu.RenderPassEncoder, x: f32, y: f32, width: f32, height: f32, min_depth: f32, max_depth: f32) void {
        _ = render_pass_encoder;
        _ = x;
        _ = y;
        _ = width;
        _ = height;
        _ = min_depth;
        _ = max_depth;
        unreachable;
    }

    pub inline fn renderPassEncoderWriteTimestamp(render_pass_encoder: *gpu.RenderPassEncoder, query_set: *gpu.QuerySet, query_index: u32) void {
        _ = render_pass_encoder;
        _ = query_set;
        _ = query_index;
        unreachable;
    }

    pub inline fn renderPassEncoderReference(render_pass_encoder: *gpu.RenderPassEncoder) void {
        _ = render_pass_encoder;
        unreachable;
    }

    pub inline fn renderPassEncoderRelease(render_pass_encoder: *gpu.RenderPassEncoder) void {
        _ = render_pass_encoder;
        unreachable;
    }

    pub inline fn renderPipelineGetBindGroupLayout(render_pipeline: *gpu.RenderPipeline, group_index: u32) *gpu.BindGroupLayout {
        _ = render_pipeline;
        _ = group_index;
        unreachable;
    }

    pub inline fn renderPipelineSetLabel(render_pipeline: *gpu.RenderPipeline, label: [*:0]const u8) void {
        _ = render_pipeline;
        _ = label;
        unreachable;
    }

    pub inline fn renderPipelineReference(render_pipeline: *gpu.RenderPipeline) void {
        _ = render_pipeline;
        unreachable;
    }

    pub inline fn renderPipelineRelease(render_pipeline: *gpu.RenderPipeline) void {
        _ = render_pipeline;
        unreachable;
    }

    pub inline fn samplerSetLabel(sampler: *gpu.Sampler, label: [*:0]const u8) void {
        _ = sampler;
        _ = label;
        unreachable;
    }

    pub inline fn samplerReference(sampler: *gpu.Sampler) void {
        _ = sampler;
        unreachable;
    }

    pub inline fn samplerRelease(sampler: *gpu.Sampler) void {
        _ = sampler;
        unreachable;
    }

    pub inline fn shaderModuleGetCompilationInfo(shader_module: *gpu.ShaderModule, callback: gpu.CompilationInfoCallback, userdata: ?*anyopaque) void {
        _ = shader_module;
        _ = callback;
        _ = userdata;
        unreachable;
    }

    pub inline fn shaderModuleSetLabel(shader_module: *gpu.ShaderModule, label: [*:0]const u8) void {
        _ = shader_module;
        _ = label;
        unreachable;
    }

    pub inline fn shaderModuleReference(shader_module: *gpu.ShaderModule) void {
        _ = shader_module;
        unreachable;
    }

    pub inline fn shaderModuleRelease(shader_module: *gpu.ShaderModule) void {
        _ = shader_module;
        unreachable;
    }

    pub inline fn surfaceReference(surface: *gpu.Surface) void {
        _ = surface;
        unreachable;
    }

    pub inline fn surfaceRelease(surface: *gpu.Surface) void {
        _ = surface;
        unreachable;
    }

    pub inline fn swapChainConfigure(swap_chain: *gpu.SwapChain, format: gpu.Texture.Format, allowed_usage: gpu.Texture.UsageFlags, width: u32, height: u32) void {
        _ = swap_chain;
        _ = format;
        _ = allowed_usage;
        _ = width;
        _ = height;
        unreachable;
    }

    pub inline fn swapChainGetCurrentTexture(swap_chain: *gpu.SwapChain) ?*gpu.Texture {
        _ = swap_chain;
        unreachable;
    }

    pub inline fn swapChainGetCurrentTextureView(swap_chain: *gpu.SwapChain) ?*gpu.TextureView {
        _ = swap_chain;
        unreachable;
    }

    pub inline fn swapChainPresent(swap_chain: *gpu.SwapChain) void {
        _ = swap_chain;
        unreachable;
    }

    pub inline fn swapChainReference(swap_chain: *gpu.SwapChain) void {
        _ = swap_chain;
        unreachable;
    }

    pub inline fn swapChainRelease(swap_chain: *gpu.SwapChain) void {
        _ = swap_chain;
        unreachable;
    }

    pub inline fn textureCreateView(texture: *gpu.Texture, descriptor: ?*const gpu.TextureView.Descriptor) *gpu.TextureView {
        _ = texture;
        _ = descriptor;
        unreachable;
    }

    pub inline fn textureDestroy(texture: *gpu.Texture) void {
        _ = texture;
        unreachable;
    }

    pub inline fn textureGetDepthOrArrayLayers(texture: *gpu.Texture) u32 {
        _ = texture;
        unreachable;
    }

    pub inline fn textureGetDimension(texture: *gpu.Texture) gpu.Texture.Dimension {
        _ = texture;
        unreachable;
    }

    pub inline fn textureGetFormat(texture: *gpu.Texture) gpu.Texture.Format {
        _ = texture;
        unreachable;
    }

    pub inline fn textureGetHeight(texture: *gpu.Texture) u32 {
        _ = texture;
        unreachable;
    }

    pub inline fn textureGetMipLevelCount(texture: *gpu.Texture) u32 {
        _ = texture;
        unreachable;
    }

    pub inline fn textureGetSampleCount(texture: *gpu.Texture) u32 {
        _ = texture;
        unreachable;
    }

    pub inline fn textureGetUsage(texture: *gpu.Texture) gpu.Texture.UsageFlags {
        _ = texture;
        unreachable;
    }

    pub inline fn textureGetWidth(texture: *gpu.Texture) u32 {
        _ = texture;
        unreachable;
    }

    pub inline fn textureSetLabel(texture: *gpu.Texture, label: [*:0]const u8) void {
        _ = texture;
        _ = label;
        unreachable;
    }

    pub inline fn textureReference(texture: *gpu.Texture) void {
        _ = texture;
        unreachable;
    }

    pub inline fn textureRelease(texture: *gpu.Texture) void {
        _ = texture;
        unreachable;
    }

    pub inline fn textureViewSetLabel(texture_view: *gpu.TextureView, label: [*:0]const u8) void {
        _ = texture_view;
        _ = label;
        unreachable;
    }

    pub inline fn textureViewReference(texture_view: *gpu.TextureView) void {
        _ = texture_view;
        unreachable;
    }

    pub inline fn textureViewRelease(texture_view: *gpu.TextureView) void {
        _ = texture_view;
        unreachable;
    }
};

test "dusk impl" {
    _ = gpu.Export(Interface);
}
