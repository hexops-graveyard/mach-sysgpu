const std = @import("std");
const builtin = @import("builtin");
const gpu = @import("gpu");
const shader = @import("shader.zig");
const utils = @import("utils.zig");

const backend_type: gpu.BackendType = switch (builtin.target.os.tag) {
    .linux, .windows => .vulkan,
    .macos, .ios => .metal,
    else => @compileError("unsupported platform"),
};
const impl = switch (backend_type) {
    .vulkan => @import("vulkan.zig"),
    .metal => @import("metal.zig"),
    else => unreachable,
};

var inited = false;
var allocator: std.mem.Allocator = undefined;

pub const Interface = struct {
    pub fn init(alloc: std.mem.Allocator, options: impl.InitOptions) !void {
        inited = true;
        allocator = alloc;
        try impl.init(alloc, options);
    }

    pub fn createInstance(descriptor: ?*const gpu.Instance.Descriptor) ?*gpu.Instance {
        if (builtin.mode == .Debug and !inited) {
            std.log.err("dusk not initialized; did you forget to call gpu.Impl.init()?", .{});
        }

        const instance = impl.Instance.init(descriptor orelse &gpu.Instance.Descriptor{}) catch unreachable;
        return @as(*gpu.Instance, @ptrCast(instance));
    }

    pub fn getProcAddress(device: *gpu.Device, proc_name: [*:0]const u8) ?gpu.Proc {
        _ = device;
        _ = proc_name;
        unreachable;
    }

    pub fn adapterCreateDevice(adapter_raw: *gpu.Adapter, descriptor: ?*const gpu.Device.Descriptor) ?*gpu.Device {
        const adapter: *impl.Adapter = @ptrCast(@alignCast(adapter_raw));
        const device = adapter.createDevice(descriptor) catch return null;
        return @as(*gpu.Device, @ptrCast(device));
    }

    pub fn adapterEnumerateFeatures(adapter: *gpu.Adapter, features: ?[*]gpu.FeatureName) usize {
        _ = adapter;
        _ = features;
        unreachable;
    }

    pub fn adapterGetLimits(adapter: *gpu.Adapter, limits: *gpu.SupportedLimits) u32 {
        _ = adapter;
        _ = limits;
        unreachable;
    }

    pub fn adapterGetInstance(adapter: *gpu.Adapter) *gpu.Instance {
        _ = adapter;
        unreachable;
    }

    pub fn adapterGetProperties(adapter_raw: *gpu.Adapter, properties: *gpu.Adapter.Properties) void {
        const adapter: *impl.Adapter = @ptrCast(@alignCast(adapter_raw));
        properties.* = adapter.getProperties();
    }

    pub fn adapterHasFeature(adapter: *gpu.Adapter, feature: gpu.FeatureName) u32 {
        _ = adapter;
        _ = feature;
        unreachable;
    }

    pub fn adapterPropertiesFreeMembers(value: gpu.Adapter.Properties) void {
        _ = value;
        unreachable;
    }

    pub fn adapterRequestDevice(adapter: *gpu.Adapter, descriptor: ?*const gpu.Device.Descriptor, callback: gpu.RequestDeviceCallback, userdata: ?*anyopaque) void {
        _ = adapter;
        _ = descriptor;
        _ = callback;
        _ = userdata;
        unreachable;
    }

    pub fn adapterReference(adapter_raw: *gpu.Adapter) void {
        var adapter: *impl.Adapter = @ptrCast(@alignCast(adapter_raw));
        adapter.manager.reference();
    }

    pub fn adapterRelease(adapter_raw: *gpu.Adapter) void {
        var adapter: *impl.Adapter = @ptrCast(@alignCast(adapter_raw));
        adapter.manager.release();
    }

    pub fn bindGroupSetLabel(bind_group: *gpu.BindGroup, label: [*:0]const u8) void {
        _ = bind_group;
        _ = label;
        unreachable;
    }

    pub fn bindGroupReference(bind_group: *gpu.BindGroup) void {
        _ = bind_group;
        unreachable;
    }

    pub fn bindGroupRelease(bind_group: *gpu.BindGroup) void {
        _ = bind_group;
        unreachable;
    }

    pub fn bindGroupLayoutSetLabel(bind_group_layout: *gpu.BindGroupLayout, label: [*:0]const u8) void {
        _ = bind_group_layout;
        _ = label;
        unreachable;
    }

    pub fn bindGroupLayoutReference(bind_group_layout: *gpu.BindGroupLayout) void {
        _ = bind_group_layout;
        unreachable;
    }

    pub fn bindGroupLayoutRelease(bind_group_layout: *gpu.BindGroupLayout) void {
        _ = bind_group_layout;
        unreachable;
    }

    pub fn bufferDestroy(buffer: *gpu.Buffer) void {
        _ = buffer;
        unreachable;
    }

    pub fn bufferGetConstMappedRange(buffer: *gpu.Buffer, offset: usize, size: usize) ?*const anyopaque {
        _ = buffer;
        _ = offset;
        _ = size;
        unreachable;
    }

    pub fn bufferGetMappedRange(buffer: *gpu.Buffer, offset: usize, size: usize) ?*anyopaque {
        _ = buffer;
        _ = offset;
        _ = size;
        unreachable;
    }

    pub fn bufferGetSize(buffer: *gpu.Buffer) u64 {
        _ = buffer;
        unreachable;
    }

    pub fn bufferGetUsage(buffer: *gpu.Buffer) gpu.Buffer.UsageFlags {
        _ = buffer;
        unreachable;
    }

    pub fn bufferMapAsync(buffer: *gpu.Buffer, mode: gpu.MapModeFlags, offset: usize, size: usize, callback: gpu.Buffer.MapCallback, userdata: ?*anyopaque) void {
        _ = buffer;
        _ = mode;
        _ = offset;
        _ = size;
        _ = callback;
        _ = userdata;
        unreachable;
    }

    pub fn bufferSetLabel(buffer: *gpu.Buffer, label: [*:0]const u8) void {
        _ = buffer;
        _ = label;
        unreachable;
    }

    pub fn bufferUnmap(buffer: *gpu.Buffer) void {
        _ = buffer;
        unreachable;
    }

    pub fn bufferReference(buffer: *gpu.Buffer) void {
        _ = buffer;
        unreachable;
    }

    pub fn bufferRelease(buffer: *gpu.Buffer) void {
        _ = buffer;
        unreachable;
    }

    pub fn commandBufferSetLabel(command_buffer: *gpu.CommandBuffer, label: [*:0]const u8) void {
        _ = command_buffer;
        _ = label;
        unreachable;
    }

    pub fn commandBufferReference(command_buffer_raw: *gpu.CommandBuffer) void {
        const command_buffer: *impl.CommandBuffer = @ptrCast(@alignCast(command_buffer_raw));
        command_buffer.manager.reference();
    }

    pub fn commandBufferRelease(command_buffer_raw: *gpu.CommandBuffer) void {
        const command_buffer: *impl.CommandBuffer = @ptrCast(@alignCast(command_buffer_raw));
        command_buffer.manager.release();
    }

    pub fn commandEncoderBeginComputePass(command_encoder: *gpu.CommandEncoder, descriptor: ?*const gpu.ComputePassDescriptor) *gpu.ComputePassEncoder {
        _ = command_encoder;
        _ = descriptor;
        unreachable;
    }

    pub fn commandEncoderBeginRenderPass(command_encoder_raw: *gpu.CommandEncoder, descriptor: *const gpu.RenderPassDescriptor) *gpu.RenderPassEncoder {
        const command_encoder: *impl.CommandEncoder = @ptrCast(@alignCast(command_encoder_raw));
        const render_pass = command_encoder.beginRenderPass(descriptor) catch unreachable;
        return @ptrCast(render_pass);
    }

    pub fn commandEncoderClearBuffer(command_encoder: *gpu.CommandEncoder, buffer: *gpu.Buffer, offset: u64, size: u64) void {
        _ = command_encoder;
        _ = buffer;
        _ = offset;
        _ = size;
        unreachable;
    }

    pub fn commandEncoderCopyBufferToBuffer(command_encoder: *gpu.CommandEncoder, source: *gpu.Buffer, source_offset: u64, destination: *gpu.Buffer, destination_offset: u64, size: u64) void {
        _ = command_encoder;
        _ = source;
        _ = source_offset;
        _ = destination;
        _ = destination_offset;
        _ = size;
        unreachable;
    }

    pub fn commandEncoderCopyBufferToTexture(command_encoder: *gpu.CommandEncoder, source: *const gpu.ImageCopyBuffer, destination: *const gpu.ImageCopyTexture, copy_size: *const gpu.Extent3D) void {
        _ = command_encoder;
        _ = source;
        _ = destination;
        _ = copy_size;
        unreachable;
    }

    pub fn commandEncoderCopyTextureToBuffer(command_encoder: *gpu.CommandEncoder, source: *const gpu.ImageCopyTexture, destination: *const gpu.ImageCopyBuffer, copy_size: *const gpu.Extent3D) void {
        _ = command_encoder;
        _ = source;
        _ = destination;
        _ = copy_size;
        unreachable;
    }

    pub fn commandEncoderCopyTextureToTexture(command_encoder: *gpu.CommandEncoder, source: *const gpu.ImageCopyTexture, destination: *const gpu.ImageCopyTexture, copy_size: *const gpu.Extent3D) void {
        _ = command_encoder;
        _ = source;
        _ = destination;
        _ = copy_size;
        unreachable;
    }

    pub fn commandEncoderCopyTextureToTextureInternal(command_encoder: *gpu.CommandEncoder, source: *const gpu.ImageCopyTexture, destination: *const gpu.ImageCopyTexture, copy_size: *const gpu.Extent3D) void {
        _ = command_encoder;
        _ = source;
        _ = destination;
        _ = copy_size;
        unreachable;
    }

    pub fn commandEncoderFinish(command_encoder_raw: *gpu.CommandEncoder, descriptor: ?*const gpu.CommandBuffer.Descriptor) *gpu.CommandBuffer {
        const command_encoder: *impl.CommandEncoder = @ptrCast(@alignCast(command_encoder_raw));
        const command_buffer = command_encoder.finish(descriptor orelse &.{}) catch unreachable;
        return @ptrCast(command_buffer);
    }

    pub fn commandEncoderInjectValidationError(command_encoder: *gpu.CommandEncoder, message: [*:0]const u8) void {
        _ = command_encoder;
        _ = message;
        unreachable;
    }

    pub fn commandEncoderInsertDebugMarker(command_encoder: *gpu.CommandEncoder, marker_label: [*:0]const u8) void {
        _ = command_encoder;
        _ = marker_label;
        unreachable;
    }

    pub fn commandEncoderPopDebugGroup(command_encoder: *gpu.CommandEncoder) void {
        _ = command_encoder;
        unreachable;
    }

    pub fn commandEncoderPushDebugGroup(command_encoder: *gpu.CommandEncoder, group_label: [*:0]const u8) void {
        _ = command_encoder;
        _ = group_label;
        unreachable;
    }

    pub fn commandEncoderResolveQuerySet(command_encoder: *gpu.CommandEncoder, query_set: *gpu.QuerySet, first_query: u32, query_count: u32, destination: *gpu.Buffer, destination_offset: u64) void {
        _ = command_encoder;
        _ = query_set;
        _ = first_query;
        _ = query_count;
        _ = destination;
        _ = destination_offset;
        unreachable;
    }

    pub fn commandEncoderSetLabel(command_encoder: *gpu.CommandEncoder, label: [*:0]const u8) void {
        _ = command_encoder;
        _ = label;
        unreachable;
    }

    pub fn commandEncoderWriteBuffer(command_encoder: *gpu.CommandEncoder, buffer: *gpu.Buffer, buffer_offset: u64, data: [*]const u8, size: u64) void {
        _ = command_encoder;
        _ = buffer;
        _ = buffer_offset;
        _ = data;
        _ = size;
        unreachable;
    }

    pub fn commandEncoderWriteTimestamp(command_encoder: *gpu.CommandEncoder, query_set: *gpu.QuerySet, query_index: u32) void {
        _ = command_encoder;
        _ = query_set;
        _ = query_index;
        unreachable;
    }

    pub fn commandEncoderReference(command_encoder_raw: *gpu.CommandEncoder) void {
        const command_encoder: *impl.CommandEncoder = @ptrCast(@alignCast(command_encoder_raw));
        command_encoder.manager.reference();
    }

    pub fn commandEncoderRelease(command_encoder_raw: *gpu.CommandEncoder) void {
        const command_encoder: *impl.CommandEncoder = @ptrCast(@alignCast(command_encoder_raw));
        command_encoder.manager.release();
    }

    pub fn computePassEncoderDispatchWorkgroups(compute_pass_encoder: *gpu.ComputePassEncoder, workgroup_count_x: u32, workgroup_count_y: u32, workgroup_count_z: u32) void {
        _ = compute_pass_encoder;
        _ = workgroup_count_x;
        _ = workgroup_count_y;
        _ = workgroup_count_z;
        unreachable;
    }

    pub fn computePassEncoderDispatchWorkgroupsIndirect(compute_pass_encoder: *gpu.ComputePassEncoder, indirect_buffer: *gpu.Buffer, indirect_offset: u64) void {
        _ = compute_pass_encoder;
        _ = indirect_buffer;
        _ = indirect_offset;
        unreachable;
    }

    pub fn computePassEncoderEnd(compute_pass_encoder: *gpu.ComputePassEncoder) void {
        _ = compute_pass_encoder;
        unreachable;
    }

    pub fn computePassEncoderInsertDebugMarker(compute_pass_encoder: *gpu.ComputePassEncoder, marker_label: [*:0]const u8) void {
        _ = compute_pass_encoder;
        _ = marker_label;
        unreachable;
    }

    pub fn computePassEncoderPopDebugGroup(compute_pass_encoder: *gpu.ComputePassEncoder) void {
        _ = compute_pass_encoder;
        unreachable;
    }

    pub fn computePassEncoderPushDebugGroup(compute_pass_encoder: *gpu.ComputePassEncoder, group_label: [*:0]const u8) void {
        _ = compute_pass_encoder;
        _ = group_label;
        unreachable;
    }

    pub fn computePassEncoderSetBindGroup(compute_pass_encoder: *gpu.ComputePassEncoder, group_index: u32, group: *gpu.BindGroup, dynamic_offset_count: usize, dynamic_offsets: ?[*]const u32) void {
        _ = compute_pass_encoder;
        _ = group_index;
        _ = group;
        _ = dynamic_offset_count;
        _ = dynamic_offsets;
        unreachable;
    }

    pub fn computePassEncoderSetLabel(compute_pass_encoder: *gpu.ComputePassEncoder, label: [*:0]const u8) void {
        _ = compute_pass_encoder;
        _ = label;
        unreachable;
    }

    pub fn computePassEncoderSetPipeline(compute_pass_encoder: *gpu.ComputePassEncoder, pipeline: *gpu.ComputePipeline) void {
        _ = compute_pass_encoder;
        _ = pipeline;
        unreachable;
    }

    pub fn computePassEncoderWriteTimestamp(compute_pass_encoder: *gpu.ComputePassEncoder, query_set: *gpu.QuerySet, query_index: u32) void {
        _ = compute_pass_encoder;
        _ = query_set;
        _ = query_index;
        unreachable;
    }

    pub fn computePassEncoderReference(compute_pass_encoder: *gpu.ComputePassEncoder) void {
        _ = compute_pass_encoder;
        unreachable;
    }

    pub fn computePassEncoderRelease(compute_pass_encoder: *gpu.ComputePassEncoder) void {
        _ = compute_pass_encoder;
        unreachable;
    }

    pub fn computePipelineGetBindGroupLayout(compute_pipeline: *gpu.ComputePipeline, group_index: u32) *gpu.BindGroupLayout {
        _ = compute_pipeline;
        _ = group_index;
        unreachable;
    }

    pub fn computePipelineSetLabel(compute_pipeline: *gpu.ComputePipeline, label: [*:0]const u8) void {
        _ = compute_pipeline;
        _ = label;
        unreachable;
    }

    pub fn computePipelineReference(compute_pipeline: *gpu.ComputePipeline) void {
        _ = compute_pipeline;
        unreachable;
    }

    pub fn computePipelineRelease(compute_pipeline: *gpu.ComputePipeline) void {
        _ = compute_pipeline;
        unreachable;
    }

    pub fn deviceCreateBindGroup(device: *gpu.Device, descriptor: *const gpu.BindGroup.Descriptor) *gpu.BindGroup {
        _ = device;
        _ = descriptor;
        unreachable;
    }

    pub fn deviceCreateBindGroupLayout(device: *gpu.Device, descriptor: *const gpu.BindGroupLayout.Descriptor) *gpu.BindGroupLayout {
        _ = device;
        _ = descriptor;
        unreachable;
    }

    pub fn deviceCreateBuffer(device: *gpu.Device, descriptor: *const gpu.Buffer.Descriptor) *gpu.Buffer {
        _ = device;
        _ = descriptor;
        unreachable;
    }

    pub fn deviceCreateCommandEncoder(device_raw: *gpu.Device, descriptor: ?*const gpu.CommandEncoder.Descriptor) *gpu.CommandEncoder {
        const device: *impl.Device = @ptrCast(@alignCast(device_raw));
        const command_encoder = impl.Device.createCommandEncoder(device, descriptor orelse &.{}) catch unreachable;
        return @ptrCast(command_encoder);
    }

    pub fn deviceCreateComputePipeline(device: *gpu.Device, descriptor: *const gpu.ComputePipeline.Descriptor) *gpu.ComputePipeline {
        _ = device;
        _ = descriptor;
        unreachable;
    }

    pub fn deviceCreateComputePipelineAsync(device: *gpu.Device, descriptor: *const gpu.ComputePipeline.Descriptor, callback: gpu.CreateComputePipelineAsyncCallback, userdata: ?*anyopaque) void {
        _ = device;
        _ = descriptor;
        _ = callback;
        _ = userdata;
        unreachable;
    }

    pub fn deviceCreateErrorBuffer(device: *gpu.Device, descriptor: *const gpu.Buffer.Descriptor) *gpu.Buffer {
        _ = device;
        _ = descriptor;
        unreachable;
    }

    pub fn deviceCreateErrorExternalTexture(device: *gpu.Device) *gpu.ExternalTexture {
        _ = device;
        unreachable;
    }

    pub fn deviceCreateErrorTexture(device: *gpu.Device, descriptor: *const gpu.Texture.Descriptor) *gpu.Texture {
        _ = device;
        _ = descriptor;
        unreachable;
    }

    pub fn deviceCreateExternalTexture(device: *gpu.Device, external_texture_descriptor: *const gpu.ExternalTexture.Descriptor) *gpu.ExternalTexture {
        _ = device;
        _ = external_texture_descriptor;
        unreachable;
    }

    pub fn deviceCreatePipelineLayout(device: *gpu.Device, pipeline_layout_descriptor: *const gpu.PipelineLayout.Descriptor) *gpu.PipelineLayout {
        _ = device;
        _ = pipeline_layout_descriptor;
        unreachable;
    }

    pub fn deviceCreateQuerySet(device: *gpu.Device, descriptor: *const gpu.QuerySet.Descriptor) *gpu.QuerySet {
        _ = device;
        _ = descriptor;
        unreachable;
    }

    pub fn deviceCreateRenderBundleEncoder(device: *gpu.Device, descriptor: *const gpu.RenderBundleEncoder.Descriptor) *gpu.RenderBundleEncoder {
        _ = device;
        _ = descriptor;
        unreachable;
    }

    pub fn deviceCreateRenderPipeline(device_raw: *gpu.Device, descriptor: *const gpu.RenderPipeline.Descriptor) *gpu.RenderPipeline {
        const device: *impl.Device = @ptrCast(@alignCast(device_raw));
        const render_pipeline = impl.Device.createRenderPipeline(device, descriptor) catch unreachable;
        return @ptrCast(render_pipeline);
    }

    pub fn deviceCreateRenderPipelineAsync(device: *gpu.Device, descriptor: *const gpu.RenderPipeline.Descriptor, callback: gpu.CreateRenderPipelineAsyncCallback, userdata: ?*anyopaque) void {
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

    pub inline fn deviceCreateShaderModule(device_raw: *gpu.Device, descriptor: *const gpu.ShaderModule.Descriptor) *gpu.ShaderModule {
        std.debug.assert(backend_type == .vulkan or backend_type == .metal);

        const device: *impl.Device = @ptrCast(@alignCast(device_raw));

        var errors = try shader.ErrorList.init(allocator);
        defer errors.deinit();
        if (utils.findChained(gpu.ShaderModule.WGSLDescriptor, descriptor.next_in_chain.generic)) |wgsl_descriptor| {
            var ast = shader.Ast.parse(allocator, &errors, std.mem.span(wgsl_descriptor.code)) catch unreachable;
            defer ast.deinit(allocator);

            var air = shader.Air.generate(allocator, &ast, &errors, null) catch unreachable;
            defer air.deinit(allocator);

            const language = if (backend_type == .vulkan) .spirv else .msl;
            const output = shader.CodeGen.generate(allocator, &air, language, .{ .emit_source_file = "" }) catch unreachable;
            defer allocator.free(output);

            const shader_module = impl.Device.createShaderModule(device, output) catch unreachable;
            return @ptrCast(shader_module);
        } else if (utils.findChained(gpu.ShaderModule.SPIRVDescriptor, descriptor.next_in_chain.generic)) |spirv_descriptor| {
            const output = std.mem.sliceAsBytes(spirv_descriptor.code[0..spirv_descriptor.code_size]);
            const shader_module = impl.Device.createShaderModule(device, output) catch unreachable;
            return @ptrCast(shader_module);
        }

        unreachable;
    }

    pub fn deviceCreateSwapChain(device_raw: *gpu.Device, surface_raw: ?*gpu.Surface, descriptor: *const gpu.SwapChain.Descriptor) *gpu.SwapChain {
        const device: *impl.Device = @ptrCast(@alignCast(device_raw));
        const surface: *impl.Surface = @ptrCast(@alignCast(surface_raw.?));
        const swapchain = impl.Device.createSwapChain(device, surface, descriptor) catch unreachable;
        return @ptrCast(swapchain);
    }

    pub fn deviceCreateTexture(device: *gpu.Device, descriptor: *const gpu.Texture.Descriptor) *gpu.Texture {
        _ = device;
        _ = descriptor;
        unreachable;
    }

    pub fn deviceDestroy(device: *gpu.Device) void {
        _ = device;
        unreachable;
    }

    pub fn deviceEnumerateFeatures(device: *gpu.Device, features: ?[*]gpu.FeatureName) usize {
        _ = device;
        _ = features;
        unreachable;
    }

    pub fn deviceGetLimits(device: *gpu.Device, limits: *gpu.SupportedLimits) u32 {
        _ = device;
        _ = limits;
        unreachable;
    }

    pub fn deviceGetQueue(device_raw: *gpu.Device) *gpu.Queue {
        const device: *impl.Device = @ptrCast(@alignCast(device_raw));
        const queue = device.getQueue() catch unreachable;
        return @ptrCast(queue);
    }

    pub fn deviceHasFeature(device: *gpu.Device, feature: gpu.FeatureName) u32 {
        _ = device;
        _ = feature;
        unreachable;
    }

    pub fn deviceImportSharedFence(device: *gpu.Device, descriptor: *const gpu.SharedFence.Descriptor) *gpu.SharedFence {
        _ = device;
        _ = descriptor;
        unreachable;
    }

    pub fn deviceImportSharedTextureMemory(device: *gpu.Device, descriptor: *const gpu.SharedTextureMemory.Descriptor) *gpu.SharedTextureMemory {
        _ = device;
        _ = descriptor;
        unreachable;
    }

    pub fn deviceInjectError(device: *gpu.Device, typ: gpu.ErrorType, message: [*:0]const u8) void {
        _ = device;
        _ = typ;
        _ = message;
        unreachable;
    }

    pub fn deviceLoseForTesting(device: *gpu.Device) void {
        _ = device;
        unreachable;
    }

    pub fn devicePopErrorScope(device: *gpu.Device, callback: gpu.ErrorCallback, userdata: ?*anyopaque) void {
        _ = device;
        _ = callback;
        _ = userdata;
        unreachable;
    }

    pub fn devicePushErrorScope(device: *gpu.Device, filter: gpu.ErrorFilter) void {
        _ = device;
        _ = filter;
        unreachable;
    }

    pub fn deviceSetDeviceLostCallback(device: *gpu.Device, callback: ?gpu.Device.LostCallback, userdata: ?*anyopaque) void {
        _ = device;
        _ = callback;
        _ = userdata;
        unreachable;
    }

    pub fn deviceSetLabel(device: *gpu.Device, label: [*:0]const u8) void {
        _ = device;
        _ = label;
        unreachable;
    }

    pub fn deviceSetLoggingCallback(device: *gpu.Device, callback: ?gpu.LoggingCallback, userdata: ?*anyopaque) void {
        _ = device;
        _ = callback;
        _ = userdata;
        unreachable;
    }

    pub fn deviceSetUncapturedErrorCallback(device_raw: *gpu.Device, callback: ?gpu.ErrorCallback, userdata: ?*anyopaque) void {
        const device: *impl.Device = @ptrCast(@alignCast(device_raw));
        device.err_cb = callback;
        device.err_cb_userdata = userdata;
    }

    pub fn deviceTick(device: *gpu.Device) void {
        _ = device;
    }

    pub fn machDeviceWaitForCommandsToBeScheduled(device: *gpu.Device) void {
        _ = device;
    }

    pub fn deviceReference(device_raw: *gpu.Device) void {
        var device: *impl.Device = @ptrCast(@alignCast(device_raw));
        device.manager.reference();
    }

    pub fn deviceRelease(device_raw: *gpu.Device) void {
        var device: *impl.Device = @ptrCast(@alignCast(device_raw));
        device.manager.release();
    }

    pub fn externalTextureDestroy(external_texture: *gpu.ExternalTexture) void {
        _ = external_texture;
        unreachable;
    }

    pub fn externalTextureSetLabel(external_texture: *gpu.ExternalTexture, label: [*:0]const u8) void {
        _ = external_texture;
        _ = label;
        unreachable;
    }

    pub fn externalTextureReference(external_texture: *gpu.ExternalTexture) void {
        _ = external_texture;
        unreachable;
    }

    pub fn externalTextureRelease(external_texture: *gpu.ExternalTexture) void {
        _ = external_texture;
        unreachable;
    }

    pub fn instanceCreateSurface(instance_raw: *gpu.Instance, descriptor: *const gpu.Surface.Descriptor) *gpu.Surface {
        const instance: *impl.Instance = @ptrCast(@alignCast(instance_raw));
        const surface = impl.Instance.createSurface(instance, descriptor) catch unreachable;
        return @ptrCast(surface);
    }

    pub fn instanceProcessEvents(instance: *gpu.Instance) void {
        _ = instance;
        unreachable;
    }

    pub fn instanceRequestAdapter(
        instance_raw: *gpu.Instance,
        options: ?*const gpu.RequestAdapterOptions,
        callback: gpu.RequestAdapterCallback,
        userdata: ?*anyopaque,
    ) void {
        const instance: *impl.Instance = @ptrCast(@alignCast(instance_raw));
        const adapter = impl.Adapter.init(instance, options orelse &gpu.RequestAdapterOptions{}) catch |err| {
            return callback(.err, undefined, @errorName(err), userdata);
        };
        callback(.success, @as(*gpu.Adapter, @ptrCast(adapter)), null, userdata);
    }

    pub fn instanceReference(instance_raw: *gpu.Instance) void {
        var instance: *impl.Instance = @ptrCast(@alignCast(instance_raw));
        instance.manager.reference();
    }

    pub fn instanceRelease(instance_raw: *gpu.Instance) void {
        var instance: *impl.Instance = @ptrCast(@alignCast(instance_raw));
        instance.manager.release();
    }

    pub fn pipelineLayoutSetLabel(pipeline_layout: *gpu.PipelineLayout, label: [*:0]const u8) void {
        _ = pipeline_layout;
        _ = label;
        unreachable;
    }

    pub fn pipelineLayoutReference(pipeline_layout: *gpu.PipelineLayout) void {
        _ = pipeline_layout;
        unreachable;
    }

    pub fn pipelineLayoutRelease(pipeline_layout: *gpu.PipelineLayout) void {
        _ = pipeline_layout;
        unreachable;
    }

    pub fn querySetDestroy(query_set: *gpu.QuerySet) void {
        _ = query_set;
        unreachable;
    }

    pub fn querySetGetCount(query_set: *gpu.QuerySet) u32 {
        _ = query_set;
        unreachable;
    }

    pub fn querySetGetType(query_set: *gpu.QuerySet) gpu.QueryType {
        _ = query_set;
        unreachable;
    }

    pub fn querySetSetLabel(query_set: *gpu.QuerySet, label: [*:0]const u8) void {
        _ = query_set;
        _ = label;
        unreachable;
    }

    pub fn querySetReference(query_set: *gpu.QuerySet) void {
        _ = query_set;
        unreachable;
    }

    pub fn querySetRelease(query_set: *gpu.QuerySet) void {
        _ = query_set;
        unreachable;
    }

    pub fn queueCopyTextureForBrowser(queue: *gpu.Queue, source: *const gpu.ImageCopyTexture, destination: *const gpu.ImageCopyTexture, copy_size: *const gpu.Extent3D, options: *const gpu.CopyTextureForBrowserOptions) void {
        _ = queue;
        _ = source;
        _ = destination;
        _ = copy_size;
        _ = options;
        unreachable;
    }

    pub fn queueOnSubmittedWorkDone(queue: *gpu.Queue, signal_value: u64, callback: gpu.Queue.WorkDoneCallback, userdata: ?*anyopaque) void {
        _ = queue;
        _ = signal_value;
        _ = callback;
        _ = userdata;
        unreachable;
    }

    pub fn queueSetLabel(queue: *gpu.Queue, label: [*:0]const u8) void {
        _ = queue;
        _ = label;
        unreachable;
    }

    pub fn queueSubmit(queue_raw: *gpu.Queue, command_count: usize, commands_raw: [*]const *const gpu.CommandBuffer) void {
        const queue: *impl.Queue = @ptrCast(@alignCast(queue_raw));
        const commands: []const *impl.CommandBuffer = @ptrCast(commands_raw[0..command_count]);
        queue.submit(commands) catch unreachable;
    }

    pub fn queueWriteBuffer(queue: *gpu.Queue, buffer: *gpu.Buffer, buffer_offset: u64, data: *const anyopaque, size: usize) void {
        _ = queue;
        _ = buffer;
        _ = buffer_offset;
        _ = data;
        _ = size;
        unreachable;
    }

    pub fn queueWriteTexture(queue: *gpu.Queue, destination: *const gpu.ImageCopyTexture, data: *const anyopaque, data_size: usize, data_layout: *const gpu.Texture.DataLayout, write_size: *const gpu.Extent3D) void {
        _ = queue;
        _ = destination;
        _ = data;
        _ = data_size;
        _ = data_layout;
        _ = write_size;
        unreachable;
    }

    pub fn queueReference(queue_raw: *gpu.Queue) void {
        var queue: *impl.Queue = @ptrCast(@alignCast(queue_raw));
        queue.manager.reference();
    }

    pub fn queueRelease(queue_raw: *gpu.Queue) void {
        var queue: *impl.Queue = @ptrCast(@alignCast(queue_raw));
        queue.manager.release();
    }

    pub fn renderBundleReference(render_bundle: *gpu.RenderBundle) void {
        _ = render_bundle;
        unreachable;
    }

    pub fn renderBundleRelease(render_bundle: *gpu.RenderBundle) void {
        _ = render_bundle;
        unreachable;
    }

    pub fn renderBundleSetLabel(render_bundle: *gpu.RenderBundle, name: [*:0]const u8) void {
        _ = name;
        _ = render_bundle;
        unreachable;
    }

    pub fn renderBundleEncoderDraw(render_bundle_encoder: *gpu.RenderBundleEncoder, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void {
        _ = render_bundle_encoder;
        _ = vertex_count;
        _ = instance_count;
        _ = first_vertex;
        _ = first_instance;
        unreachable;
    }

    pub fn renderBundleEncoderDrawIndexed(render_bundle_encoder: *gpu.RenderBundleEncoder, index_count: u32, instance_count: u32, first_index: u32, base_vertex: i32, first_instance: u32) void {
        _ = render_bundle_encoder;
        _ = index_count;
        _ = instance_count;
        _ = first_index;
        _ = base_vertex;
        _ = first_instance;
        unreachable;
    }

    pub fn renderBundleEncoderDrawIndexedIndirect(render_bundle_encoder: *gpu.RenderBundleEncoder, indirect_buffer: *gpu.Buffer, indirect_offset: u64) void {
        _ = render_bundle_encoder;
        _ = indirect_buffer;
        _ = indirect_offset;
        unreachable;
    }

    pub fn renderBundleEncoderDrawIndirect(render_bundle_encoder: *gpu.RenderBundleEncoder, indirect_buffer: *gpu.Buffer, indirect_offset: u64) void {
        _ = render_bundle_encoder;
        _ = indirect_buffer;
        _ = indirect_offset;
        unreachable;
    }

    pub fn renderBundleEncoderFinish(render_bundle_encoder: *gpu.RenderBundleEncoder, descriptor: ?*const gpu.RenderBundle.Descriptor) *gpu.RenderBundle {
        _ = render_bundle_encoder;
        _ = descriptor;
        unreachable;
    }

    pub fn renderBundleEncoderInsertDebugMarker(render_bundle_encoder: *gpu.RenderBundleEncoder, marker_label: [*:0]const u8) void {
        _ = render_bundle_encoder;
        _ = marker_label;
        unreachable;
    }

    pub fn renderBundleEncoderPopDebugGroup(render_bundle_encoder: *gpu.RenderBundleEncoder) void {
        _ = render_bundle_encoder;
        unreachable;
    }

    pub fn renderBundleEncoderPushDebugGroup(render_bundle_encoder: *gpu.RenderBundleEncoder, group_label: [*:0]const u8) void {
        _ = render_bundle_encoder;
        _ = group_label;
        unreachable;
    }

    pub fn renderBundleEncoderSetBindGroup(render_bundle_encoder: *gpu.RenderBundleEncoder, group_index: u32, group: *gpu.BindGroup, dynamic_offset_count: usize, dynamic_offsets: ?[*]const u32) void {
        _ = render_bundle_encoder;
        _ = group_index;
        _ = group;
        _ = dynamic_offset_count;
        _ = dynamic_offsets;
        unreachable;
    }

    pub fn renderBundleEncoderSetIndexBuffer(render_bundle_encoder: *gpu.RenderBundleEncoder, buffer: *gpu.Buffer, format: gpu.IndexFormat, offset: u64, size: u64) void {
        _ = render_bundle_encoder;
        _ = buffer;
        _ = format;
        _ = offset;
        _ = size;
        unreachable;
    }

    pub fn renderBundleEncoderSetLabel(render_bundle_encoder: *gpu.RenderBundleEncoder, label: [*:0]const u8) void {
        _ = render_bundle_encoder;
        _ = label;
        unreachable;
    }

    pub fn renderBundleEncoderSetPipeline(render_bundle_encoder: *gpu.RenderBundleEncoder, pipeline: *gpu.RenderPipeline) void {
        _ = render_bundle_encoder;
        _ = pipeline;
        unreachable;
    }

    pub fn renderBundleEncoderSetVertexBuffer(render_bundle_encoder: *gpu.RenderBundleEncoder, slot: u32, buffer: *gpu.Buffer, offset: u64, size: u64) void {
        _ = render_bundle_encoder;
        _ = slot;
        _ = buffer;
        _ = offset;
        _ = size;
        unreachable;
    }

    pub fn renderBundleEncoderReference(render_bundle_encoder: *gpu.RenderBundleEncoder) void {
        _ = render_bundle_encoder;
        unreachable;
    }

    pub fn renderBundleEncoderRelease(render_bundle_encoder: *gpu.RenderBundleEncoder) void {
        _ = render_bundle_encoder;
        unreachable;
    }

    pub fn renderPassEncoderBeginOcclusionQuery(render_pass_encoder: *gpu.RenderPassEncoder, query_index: u32) void {
        _ = render_pass_encoder;
        _ = query_index;
        unreachable;
    }

    pub fn renderPassEncoderDraw(render_pass_encoder_raw: *gpu.RenderPassEncoder, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void {
        const render_pass_encoder: *impl.RenderPassEncoder = @ptrCast(@alignCast(render_pass_encoder_raw));
        render_pass_encoder.draw(vertex_count, instance_count, first_vertex, first_instance);
    }

    pub fn renderPassEncoderDrawIndexed(render_pass_encoder: *gpu.RenderPassEncoder, index_count: u32, instance_count: u32, first_index: u32, base_vertex: i32, first_instance: u32) void {
        _ = render_pass_encoder;
        _ = index_count;
        _ = instance_count;
        _ = first_index;
        _ = base_vertex;
        _ = first_instance;
        unreachable;
    }

    pub fn renderPassEncoderDrawIndexedIndirect(render_pass_encoder: *gpu.RenderPassEncoder, indirect_buffer: *gpu.Buffer, indirect_offset: u64) void {
        _ = render_pass_encoder;
        _ = indirect_buffer;
        _ = indirect_offset;
        unreachable;
    }

    pub fn renderPassEncoderDrawIndirect(render_pass_encoder: *gpu.RenderPassEncoder, indirect_buffer: *gpu.Buffer, indirect_offset: u64) void {
        _ = render_pass_encoder;
        _ = indirect_buffer;
        _ = indirect_offset;
        unreachable;
    }

    pub fn renderPassEncoderEnd(render_pass_encoder_raw: *gpu.RenderPassEncoder) void {
        const render_pass_encoder: *impl.RenderPassEncoder = @ptrCast(@alignCast(render_pass_encoder_raw));
        render_pass_encoder.end();
    }

    pub fn renderPassEncoderEndOcclusionQuery(render_pass_encoder: *gpu.RenderPassEncoder) void {
        _ = render_pass_encoder;
        unreachable;
    }

    pub fn renderPassEncoderExecuteBundles(render_pass_encoder: *gpu.RenderPassEncoder, bundles_count: usize, bundles: [*]const *const gpu.RenderBundle) void {
        _ = render_pass_encoder;
        _ = bundles_count;
        _ = bundles;
        unreachable;
    }

    pub fn renderPassEncoderInsertDebugMarker(render_pass_encoder: *gpu.RenderPassEncoder, marker_label: [*:0]const u8) void {
        _ = render_pass_encoder;
        _ = marker_label;
        unreachable;
    }

    pub fn renderPassEncoderPopDebugGroup(render_pass_encoder: *gpu.RenderPassEncoder) void {
        _ = render_pass_encoder;
        unreachable;
    }

    pub fn renderPassEncoderPushDebugGroup(render_pass_encoder: *gpu.RenderPassEncoder, group_label: [*:0]const u8) void {
        _ = render_pass_encoder;
        _ = group_label;
        unreachable;
    }

    pub fn renderPassEncoderSetBindGroup(render_pass_encoder: *gpu.RenderPassEncoder, group_index: u32, group: *gpu.BindGroup, dynamic_offset_count: usize, dynamic_offsets: ?[*]const u32) void {
        _ = render_pass_encoder;
        _ = group_index;
        _ = group;
        _ = dynamic_offset_count;
        _ = dynamic_offsets;
        unreachable;
    }

    pub fn renderPassEncoderSetBlendConstant(render_pass_encoder: *gpu.RenderPassEncoder, color: *const gpu.Color) void {
        _ = render_pass_encoder;
        _ = color;
        unreachable;
    }

    pub fn renderPassEncoderSetIndexBuffer(render_pass_encoder: *gpu.RenderPassEncoder, buffer: *gpu.Buffer, format: gpu.IndexFormat, offset: u64, size: u64) void {
        _ = render_pass_encoder;
        _ = buffer;
        _ = format;
        _ = offset;
        _ = size;
        unreachable;
    }

    pub fn renderPassEncoderSetLabel(render_pass_encoder: *gpu.RenderPassEncoder, label: [*:0]const u8) void {
        _ = render_pass_encoder;
        _ = label;
        unreachable;
    }

    pub fn renderPassEncoderSetPipeline(render_pass_encoder_raw: *gpu.RenderPassEncoder, pipeline_raw: *gpu.RenderPipeline) void {
        const render_pass_encoder: *impl.RenderPassEncoder = @ptrCast(@alignCast(render_pass_encoder_raw));
        const pipeline: *impl.RenderPipeline = @ptrCast(@alignCast(pipeline_raw));
        render_pass_encoder.setPipeline(pipeline) catch unreachable;
    }

    pub fn renderPassEncoderSetScissorRect(render_pass_encoder: *gpu.RenderPassEncoder, x: u32, y: u32, width: u32, height: u32) void {
        _ = render_pass_encoder;
        _ = x;
        _ = y;
        _ = width;
        _ = height;
        unreachable;
    }

    pub fn renderPassEncoderSetStencilReference(render_pass_encoder: *gpu.RenderPassEncoder, reference: u32) void {
        _ = render_pass_encoder;
        _ = reference;
        unreachable;
    }

    pub fn renderPassEncoderSetVertexBuffer(render_pass_encoder: *gpu.RenderPassEncoder, slot: u32, buffer: *gpu.Buffer, offset: u64, size: u64) void {
        _ = render_pass_encoder;
        _ = slot;
        _ = buffer;
        _ = offset;
        _ = size;
        unreachable;
    }

    pub fn renderPassEncoderSetViewport(render_pass_encoder: *gpu.RenderPassEncoder, x: f32, y: f32, width: f32, height: f32, min_depth: f32, max_depth: f32) void {
        _ = render_pass_encoder;
        _ = x;
        _ = y;
        _ = width;
        _ = height;
        _ = min_depth;
        _ = max_depth;
        unreachable;
    }

    pub fn renderPassEncoderWriteTimestamp(render_pass_encoder: *gpu.RenderPassEncoder, query_set: *gpu.QuerySet, query_index: u32) void {
        _ = render_pass_encoder;
        _ = query_set;
        _ = query_index;
        unreachable;
    }

    pub fn renderPassEncoderReference(render_pass_encoder_raw: *gpu.RenderPassEncoder) void {
        const render_pass_encoder: *impl.RenderPassEncoder = @ptrCast(@alignCast(render_pass_encoder_raw));
        render_pass_encoder.manager.reference();
    }

    pub fn renderPassEncoderRelease(render_pass_encoder_raw: *gpu.RenderPassEncoder) void {
        const render_pass_encoder: *impl.RenderPassEncoder = @ptrCast(@alignCast(render_pass_encoder_raw));
        render_pass_encoder.manager.release();
    }

    pub fn renderPipelineGetBindGroupLayout(render_pipeline: *gpu.RenderPipeline, group_index: u32) *gpu.BindGroupLayout {
        _ = render_pipeline;
        _ = group_index;
        unreachable;
    }

    pub fn renderPipelineSetLabel(render_pipeline: *gpu.RenderPipeline, label: [*:0]const u8) void {
        _ = render_pipeline;
        _ = label;
        unreachable;
    }

    pub fn renderPipelineReference(render_pipeline_raw: *gpu.RenderPipeline) void {
        var render_pipeline: *impl.RenderPipeline = @ptrCast(@alignCast(render_pipeline_raw));
        render_pipeline.manager.reference();
    }

    pub fn renderPipelineRelease(render_pipeline_raw: *gpu.RenderPipeline) void {
        var render_pipeline: *impl.RenderPipeline = @ptrCast(@alignCast(render_pipeline_raw));
        render_pipeline.manager.release();
    }

    pub fn samplerSetLabel(sampler: *gpu.Sampler, label: [*:0]const u8) void {
        _ = sampler;
        _ = label;
        unreachable;
    }

    pub fn samplerReference(sampler: *gpu.Sampler) void {
        _ = sampler;
        unreachable;
    }

    pub fn samplerRelease(sampler: *gpu.Sampler) void {
        _ = sampler;
        unreachable;
    }

    pub fn shaderModuleGetCompilationInfo(shader_module: *gpu.ShaderModule, callback: gpu.CompilationInfoCallback, userdata: ?*anyopaque) void {
        _ = shader_module;
        _ = callback;
        _ = userdata;
        unreachable;
    }

    pub fn shaderModuleSetLabel(shader_module: *gpu.ShaderModule, label: [*:0]const u8) void {
        _ = shader_module;
        _ = label;
        unreachable;
    }

    pub fn shaderModuleReference(shader_module_raw: *gpu.ShaderModule) void {
        var shader_module: *impl.ShaderModule = @ptrCast(@alignCast(shader_module_raw));
        shader_module.manager.reference();
    }

    pub fn shaderModuleRelease(shader_module_raw: *gpu.ShaderModule) void {
        var shader_module: *impl.ShaderModule = @ptrCast(@alignCast(shader_module_raw));
        shader_module.manager.release();
    }

    pub fn sharedFenceExportInfo(shared_fence: *gpu.SharedFence, info: *gpu.SharedFence.ExportInfo) void {
        _ = shared_fence;
        _ = info;
        unreachable;
    }

    pub fn sharedFenceReference(shared_fence: *gpu.SharedFence) void {
        _ = shared_fence;
        unreachable;
    }

    pub fn sharedFenceRelease(shared_fence: *gpu.SharedFence) void {
        _ = shared_fence;
        unreachable;
    }

    pub fn sharedTextureMemoryBeginAccess(shared_texture_memory: *gpu.SharedTextureMemory, texture: *gpu.Texture, descriptor: *const gpu.SharedTextureMemory.BeginAccessDescriptor) void {
        _ = shared_texture_memory;
        _ = texture;
        _ = descriptor;
        unreachable;
    }

    pub fn sharedTextureMemoryCreateTexture(shared_texture_memory: *gpu.SharedTextureMemory, descriptor: *const gpu.Texture.Descriptor) *gpu.Texture {
        _ = shared_texture_memory;
        _ = descriptor;
        unreachable;
    }

    pub fn sharedTextureMemoryEndAccess(shared_texture_memory: *gpu.SharedTextureMemory, texture: *gpu.Texture, descriptor: *gpu.SharedTextureMemory.EndAccessState) void {
        _ = shared_texture_memory;
        _ = texture;
        _ = descriptor;
        unreachable;
    }

    pub fn sharedTextureMemoryEndAccessStateFreeMembers(value: gpu.SharedTextureMemory.EndAccessState) void {
        _ = value;
        unreachable;
    }

    pub fn sharedTextureMemoryGetProperties(shared_texture_memory: *gpu.SharedTextureMemory, properties: *gpu.SharedTextureMemory.Properties) void {
        _ = shared_texture_memory;
        _ = properties;
        unreachable;
    }

    pub fn sharedTextureMemorySetLabel(shared_texture_memory: *gpu.SharedTextureMemory, label: [*:0]const u8) void {
        _ = shared_texture_memory;
        _ = label;
        unreachable;
    }

    pub fn sharedTextureMemoryReference(shared_texture_memory: *gpu.SharedTextureMemory) void {
        _ = shared_texture_memory;
        unreachable;
    }

    pub fn sharedTextureMemoryRelease(shared_texture_memory: *gpu.SharedTextureMemory) void {
        _ = shared_texture_memory;
        unreachable;
    }

    pub fn surfaceReference(surface_raw: *gpu.Surface) void {
        var surface: *impl.Surface = @ptrCast(@alignCast(surface_raw));
        surface.manager.reference();
    }

    pub fn surfaceRelease(surface_raw: *gpu.Surface) void {
        var surface: *impl.Surface = @ptrCast(@alignCast(surface_raw));
        surface.manager.release();
    }

    pub fn swapChainConfigure(swap_chain: *gpu.SwapChain, format: gpu.Texture.Format, allowed_usage: gpu.Texture.UsageFlags, width: u32, height: u32) void {
        _ = swap_chain;
        _ = format;
        _ = allowed_usage;
        _ = width;
        _ = height;
        unreachable;
    }

    pub fn swapChainGetCurrentTexture(swap_chain: *gpu.SwapChain) ?*gpu.Texture {
        _ = swap_chain;
        unreachable;
    }

    pub fn swapChainGetCurrentTextureView(swap_chain_raw: *gpu.SwapChain) ?*gpu.TextureView {
        const swap_chain: *impl.SwapChain = @ptrCast(@alignCast(swap_chain_raw));
        const texture_view = swap_chain.getCurrentTextureView() catch unreachable;
        return @ptrCast(texture_view);
    }

    pub fn swapChainPresent(swap_chain_raw: *gpu.SwapChain) void {
        const swap_chain: *impl.SwapChain = @ptrCast(@alignCast(swap_chain_raw));
        swap_chain.present() catch unreachable;
    }

    pub fn swapChainReference(swap_chain_raw: *gpu.SwapChain) void {
        var swap_chain: *impl.SwapChain = @ptrCast(@alignCast(swap_chain_raw));
        swap_chain.manager.reference();
    }

    pub fn swapChainRelease(swap_chain_raw: *gpu.SwapChain) void {
        var swap_chain: *impl.SwapChain = @ptrCast(@alignCast(swap_chain_raw));
        swap_chain.manager.release();
    }

    pub fn textureCreateView(texture: *gpu.Texture, descriptor: ?*const gpu.TextureView.Descriptor) *gpu.TextureView {
        _ = texture;
        _ = descriptor;
        unreachable;
    }

    pub fn textureDestroy(texture: *gpu.Texture) void {
        _ = texture;
        unreachable;
    }

    pub fn textureGetDepthOrArrayLayers(texture: *gpu.Texture) u32 {
        _ = texture;
        unreachable;
    }

    pub fn textureGetDimension(texture: *gpu.Texture) gpu.Texture.Dimension {
        _ = texture;
        unreachable;
    }

    pub fn textureGetFormat(texture: *gpu.Texture) gpu.Texture.Format {
        _ = texture;
        unreachable;
    }

    pub fn textureGetHeight(texture: *gpu.Texture) u32 {
        _ = texture;
        unreachable;
    }

    pub fn textureGetMipLevelCount(texture: *gpu.Texture) u32 {
        _ = texture;
        unreachable;
    }

    pub fn textureGetSampleCount(texture: *gpu.Texture) u32 {
        _ = texture;
        unreachable;
    }

    pub fn textureGetUsage(texture: *gpu.Texture) gpu.Texture.UsageFlags {
        _ = texture;
        unreachable;
    }

    pub fn textureGetWidth(texture: *gpu.Texture) u32 {
        _ = texture;
        unreachable;
    }

    pub fn textureSetLabel(texture: *gpu.Texture, label: [*:0]const u8) void {
        _ = texture;
        _ = label;
        unreachable;
    }

    pub fn textureReference(texture: *gpu.Texture) void {
        _ = texture;
        unreachable;
    }

    pub fn textureRelease(texture: *gpu.Texture) void {
        _ = texture;
        unreachable;
    }

    pub fn textureViewSetLabel(texture_view: *gpu.TextureView, label: [*:0]const u8) void {
        _ = texture_view;
        _ = label;
        unreachable;
    }

    pub fn textureViewReference(texture_view_raw: *gpu.TextureView) void {
        const texture_view: *impl.TextureView = @ptrCast(@alignCast(texture_view_raw));
        texture_view.manager.reference();
    }

    pub fn textureViewRelease(texture_view_raw: *gpu.TextureView) void {
        const texture_view: *impl.TextureView = @ptrCast(@alignCast(texture_view_raw));
        texture_view.manager.release();
    }
};

test "export" {
    _ = gpu.Export(Interface);
}
