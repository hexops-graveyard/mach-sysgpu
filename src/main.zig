const std = @import("std");
const builtin = @import("builtin");
pub const dgpu = @import("dgpu/main.zig");
const shader = @import("shader.zig");
const utils = @import("utils.zig");

const backend_type: dgpu.BackendType = switch (builtin.target.os.tag) {
    .linux => .vulkan,
    .macos, .ios => .metal,
    .windows => .d3d12,
    else => @compileError("unsupported platform"),
};
const impl = switch (backend_type) {
    .d3d12 => @import("d3d12.zig"),
    .metal => @import("metal.zig"),
    .vulkan => @import("vulkan.zig"),
    else => unreachable,
};

var inited = false;
var allocator: std.mem.Allocator = undefined;

pub const Impl = struct {
    pub fn init(alloc: std.mem.Allocator, options: impl.InitOptions) !void {
        inited = true;
        allocator = alloc;
        try impl.init(alloc, options);
    }

    pub inline fn createInstance(descriptor: ?*const dgpu.Instance.Descriptor) ?*dgpu.Instance {
        if (builtin.mode == .Debug and !inited) {
            std.log.err("dusk not initialized; did you forget to call dgpu.Impl.init()?", .{});
        }

        const instance = impl.Instance.init(descriptor orelse &dgpu.Instance.Descriptor{}) catch unreachable;
        return @as(*dgpu.Instance, @ptrCast(instance));
    }

    pub inline fn getProcAddress(device: *dgpu.Device, proc_name: [*:0]const u8) ?dgpu.Proc {
        _ = device;
        _ = proc_name;
        unreachable;
    }

    pub inline fn adapterCreateDevice(adapter_raw: *dgpu.Adapter, descriptor: ?*const dgpu.Device.Descriptor) ?*dgpu.Device {
        const adapter: *impl.Adapter = @ptrCast(@alignCast(adapter_raw));
        const device = adapter.createDevice(descriptor) catch return null;
        if (descriptor) |desc| {
            device.lost_cb = desc.device_lost_callback;
            device.lost_cb_userdata = desc.device_lost_userdata;
        }
        return @as(*dgpu.Device, @ptrCast(device));
    }

    pub inline fn adapterEnumerateFeatures(adapter: *dgpu.Adapter, features: ?[*]dgpu.FeatureName) usize {
        _ = adapter;
        _ = features;
        unreachable;
    }

    pub inline fn adapterGetLimits(adapter: *dgpu.Adapter, limits: *dgpu.SupportedLimits) u32 {
        _ = adapter;
        _ = limits;
        unreachable;
    }

    pub inline fn adapterGetInstance(adapter: *dgpu.Adapter) *dgpu.Instance {
        _ = adapter;
        unreachable;
    }

    pub inline fn adapterGetProperties(adapter_raw: *dgpu.Adapter, properties: *dgpu.Adapter.Properties) void {
        const adapter: *impl.Adapter = @ptrCast(@alignCast(adapter_raw));
        properties.* = adapter.getProperties();
    }

    pub inline fn adapterHasFeature(adapter: *dgpu.Adapter, feature: dgpu.FeatureName) u32 {
        _ = adapter;
        _ = feature;
        unreachable;
    }

    pub inline fn adapterPropertiesFreeMembers(value: dgpu.Adapter.Properties) void {
        _ = value;
        unreachable;
    }

    pub inline fn adapterRequestDevice(adapter: *dgpu.Adapter, descriptor: ?*const dgpu.Device.Descriptor, callback: dgpu.RequestDeviceCallback, userdata: ?*anyopaque) void {
        _ = adapter;
        _ = descriptor;
        _ = callback;
        _ = userdata;
        unreachable;
    }

    pub inline fn adapterReference(adapter_raw: *dgpu.Adapter) void {
        const adapter: *impl.Adapter = @ptrCast(@alignCast(adapter_raw));
        adapter.manager.reference();
    }

    pub inline fn adapterRelease(adapter_raw: *dgpu.Adapter) void {
        const adapter: *impl.Adapter = @ptrCast(@alignCast(adapter_raw));
        adapter.manager.release();
    }

    pub inline fn bindGroupSetLabel(bind_group: *dgpu.BindGroup, label: [*:0]const u8) void {
        _ = bind_group;
        _ = label;
        unreachable;
    }

    pub inline fn bindGroupReference(bind_group_raw: *dgpu.BindGroup) void {
        const bind_group: *impl.BindGroup = @ptrCast(@alignCast(bind_group_raw));
        bind_group.manager.reference();
    }

    pub inline fn bindGroupRelease(bind_group_raw: *dgpu.BindGroup) void {
        const bind_group: *impl.BindGroup = @ptrCast(@alignCast(bind_group_raw));
        bind_group.manager.release();
    }

    pub inline fn bindGroupLayoutSetLabel(bind_group_layout: *dgpu.BindGroupLayout, label: [*:0]const u8) void {
        _ = bind_group_layout;
        _ = label;
        unreachable;
    }

    pub inline fn bindGroupLayoutReference(bind_group_layout_raw: *dgpu.BindGroupLayout) void {
        const bind_group_layout: *impl.BindGroupLayout = @ptrCast(@alignCast(bind_group_layout_raw));
        bind_group_layout.manager.reference();
    }

    pub inline fn bindGroupLayoutRelease(bind_group_layout_raw: *dgpu.BindGroupLayout) void {
        const bind_group_layout: *impl.BindGroupLayout = @ptrCast(@alignCast(bind_group_layout_raw));
        bind_group_layout.manager.release();
    }

    pub inline fn bufferDestroy(buffer: *dgpu.Buffer) void {
        _ = buffer;
        unreachable;
    }

    pub inline fn bufferGetConstMappedRange(buffer_raw: *dgpu.Buffer, offset: usize, size: usize) ?*const anyopaque {
        const buffer: *impl.Buffer = @ptrCast(@alignCast(buffer_raw));
        return buffer.getConstMappedRange(offset, size) catch unreachable;
    }

    pub inline fn bufferGetMappedRange(buffer_raw: *dgpu.Buffer, offset: usize, size: usize) ?*anyopaque {
        const buffer: *impl.Buffer = @ptrCast(@alignCast(buffer_raw));
        return buffer.getConstMappedRange(offset, size) catch unreachable;
    }

    pub inline fn bufferGetSize(buffer: *dgpu.Buffer) u64 {
        _ = buffer;
        unreachable;
    }

    pub inline fn bufferGetUsage(buffer: *dgpu.Buffer) dgpu.Buffer.UsageFlags {
        _ = buffer;
        unreachable;
    }

    pub inline fn bufferMapAsync(buffer_raw: *dgpu.Buffer, mode: dgpu.MapModeFlags, offset: usize, size: usize, callback: dgpu.Buffer.MapCallback, userdata: ?*anyopaque) void {
        const buffer: *impl.Buffer = @ptrCast(@alignCast(buffer_raw));
        buffer.mapAsync(mode, offset, size, callback, userdata) catch unreachable;
    }

    pub inline fn bufferSetLabel(buffer: *dgpu.Buffer, label: [*:0]const u8) void {
        _ = buffer;
        _ = label;
        unreachable;
    }

    pub inline fn bufferUnmap(buffer_raw: *dgpu.Buffer) void {
        const buffer: *impl.Buffer = @ptrCast(@alignCast(buffer_raw));
        buffer.unmap() catch unreachable;
    }

    pub inline fn bufferReference(buffer_raw: *dgpu.Buffer) void {
        const buffer: *impl.Buffer = @ptrCast(@alignCast(buffer_raw));
        buffer.manager.reference();
    }

    pub inline fn bufferRelease(buffer_raw: *dgpu.Buffer) void {
        const buffer: *impl.Buffer = @ptrCast(@alignCast(buffer_raw));
        buffer.manager.release();
    }

    pub inline fn commandBufferSetLabel(command_buffer: *dgpu.CommandBuffer, label: [*:0]const u8) void {
        _ = command_buffer;
        _ = label;
        unreachable;
    }

    pub inline fn commandBufferReference(command_buffer_raw: *dgpu.CommandBuffer) void {
        const command_buffer: *impl.CommandBuffer = @ptrCast(@alignCast(command_buffer_raw));
        command_buffer.manager.reference();
    }

    pub inline fn commandBufferRelease(command_buffer_raw: *dgpu.CommandBuffer) void {
        const command_buffer: *impl.CommandBuffer = @ptrCast(@alignCast(command_buffer_raw));
        command_buffer.manager.release();
    }

    pub inline fn commandEncoderBeginComputePass(command_encoder_raw: *dgpu.CommandEncoder, descriptor: ?*const dgpu.ComputePassDescriptor) *dgpu.ComputePassEncoder {
        const command_encoder: *impl.CommandEncoder = @ptrCast(@alignCast(command_encoder_raw));
        const compute_pass = command_encoder.beginComputePass(descriptor orelse &.{}) catch unreachable;
        return @ptrCast(compute_pass);
    }

    pub inline fn commandEncoderBeginRenderPass(command_encoder_raw: *dgpu.CommandEncoder, descriptor: *const dgpu.RenderPassDescriptor) *dgpu.RenderPassEncoder {
        const command_encoder: *impl.CommandEncoder = @ptrCast(@alignCast(command_encoder_raw));
        const render_pass = command_encoder.beginRenderPass(descriptor) catch unreachable;
        return @ptrCast(render_pass);
    }

    pub inline fn commandEncoderClearBuffer(command_encoder: *dgpu.CommandEncoder, buffer: *dgpu.Buffer, offset: u64, size: u64) void {
        _ = command_encoder;
        _ = buffer;
        _ = offset;
        _ = size;
        unreachable;
    }

    pub inline fn commandEncoderCopyBufferToBuffer(command_encoder_raw: *dgpu.CommandEncoder, source_raw: *dgpu.Buffer, source_offset: u64, destination_raw: *dgpu.Buffer, destination_offset: u64, size: u64) void {
        const command_encoder: *impl.CommandEncoder = @ptrCast(@alignCast(command_encoder_raw));
        const source: *impl.Buffer = @ptrCast(@alignCast(source_raw));
        const destination: *impl.Buffer = @ptrCast(@alignCast(destination_raw));

        command_encoder.copyBufferToBuffer(source, source_offset, destination, destination_offset, size) catch unreachable;
    }

    pub inline fn commandEncoderCopyBufferToTexture(command_encoder: *dgpu.CommandEncoder, source: *const dgpu.ImageCopyBuffer, destination: *const dgpu.ImageCopyTexture, copy_size: *const dgpu.Extent3D) void {
        _ = command_encoder;
        _ = source;
        _ = destination;
        _ = copy_size;
        unreachable;
    }

    pub inline fn commandEncoderCopyTextureToBuffer(command_encoder: *dgpu.CommandEncoder, source: *const dgpu.ImageCopyTexture, destination: *const dgpu.ImageCopyBuffer, copy_size: *const dgpu.Extent3D) void {
        _ = command_encoder;
        _ = source;
        _ = destination;
        _ = copy_size;
        unreachable;
    }

    pub inline fn commandEncoderCopyTextureToTexture(command_encoder: *dgpu.CommandEncoder, source: *const dgpu.ImageCopyTexture, destination: *const dgpu.ImageCopyTexture, copy_size: *const dgpu.Extent3D) void {
        _ = command_encoder;
        _ = source;
        _ = destination;
        _ = copy_size;
        unreachable;
    }

    pub inline fn commandEncoderCopyTextureToTextureInternal(command_encoder: *dgpu.CommandEncoder, source: *const dgpu.ImageCopyTexture, destination: *const dgpu.ImageCopyTexture, copy_size: *const dgpu.Extent3D) void {
        _ = command_encoder;
        _ = source;
        _ = destination;
        _ = copy_size;
        unreachable;
    }

    pub inline fn commandEncoderFinish(command_encoder_raw: *dgpu.CommandEncoder, descriptor: ?*const dgpu.CommandBuffer.Descriptor) *dgpu.CommandBuffer {
        const command_encoder: *impl.CommandEncoder = @ptrCast(@alignCast(command_encoder_raw));
        const command_buffer = command_encoder.finish(descriptor orelse &.{}) catch unreachable;
        command_buffer.manager.reference();
        return @ptrCast(command_buffer);
    }

    pub inline fn commandEncoderInjectValidationError(command_encoder: *dgpu.CommandEncoder, message: [*:0]const u8) void {
        _ = command_encoder;
        _ = message;
        unreachable;
    }

    pub inline fn commandEncoderInsertDebugMarker(command_encoder: *dgpu.CommandEncoder, marker_label: [*:0]const u8) void {
        _ = command_encoder;
        _ = marker_label;
        unreachable;
    }

    pub inline fn commandEncoderPopDebugGroup(command_encoder: *dgpu.CommandEncoder) void {
        _ = command_encoder;
        unreachable;
    }

    pub inline fn commandEncoderPushDebugGroup(command_encoder: *dgpu.CommandEncoder, group_label: [*:0]const u8) void {
        _ = command_encoder;
        _ = group_label;
        unreachable;
    }

    pub inline fn commandEncoderResolveQuerySet(command_encoder: *dgpu.CommandEncoder, query_set: *dgpu.QuerySet, first_query: u32, query_count: u32, destination: *dgpu.Buffer, destination_offset: u64) void {
        _ = command_encoder;
        _ = query_set;
        _ = first_query;
        _ = query_count;
        _ = destination;
        _ = destination_offset;
        unreachable;
    }

    pub inline fn commandEncoderSetLabel(command_encoder: *dgpu.CommandEncoder, label: [*:0]const u8) void {
        _ = command_encoder;
        _ = label;
        unreachable;
    }

    pub inline fn commandEncoderWriteBuffer(command_encoder: *dgpu.CommandEncoder, buffer: *dgpu.Buffer, buffer_offset: u64, data: [*]const u8, size: u64) void {
        _ = command_encoder;
        _ = buffer;
        _ = buffer_offset;
        _ = data;
        _ = size;
        unreachable;
    }

    pub inline fn commandEncoderWriteTimestamp(command_encoder: *dgpu.CommandEncoder, query_set: *dgpu.QuerySet, query_index: u32) void {
        _ = command_encoder;
        _ = query_set;
        _ = query_index;
        unreachable;
    }

    pub inline fn commandEncoderReference(command_encoder_raw: *dgpu.CommandEncoder) void {
        const command_encoder: *impl.CommandEncoder = @ptrCast(@alignCast(command_encoder_raw));
        command_encoder.manager.reference();
    }

    pub inline fn commandEncoderRelease(command_encoder_raw: *dgpu.CommandEncoder) void {
        const command_encoder: *impl.CommandEncoder = @ptrCast(@alignCast(command_encoder_raw));
        command_encoder.manager.release();
    }

    pub inline fn computePassEncoderDispatchWorkgroups(compute_pass_encoder_raw: *dgpu.ComputePassEncoder, workgroup_count_x: u32, workgroup_count_y: u32, workgroup_count_z: u32) void {
        const compute_pass_encoder: *impl.ComputePassEncoder = @ptrCast(@alignCast(compute_pass_encoder_raw));
        compute_pass_encoder.dispatchWorkgroups(workgroup_count_x, workgroup_count_y, workgroup_count_z);
    }

    pub inline fn computePassEncoderDispatchWorkgroupsIndirect(compute_pass_encoder: *dgpu.ComputePassEncoder, indirect_buffer: *dgpu.Buffer, indirect_offset: u64) void {
        _ = compute_pass_encoder;
        _ = indirect_buffer;
        _ = indirect_offset;
        unreachable;
    }

    pub inline fn computePassEncoderEnd(compute_pass_encoder_raw: *dgpu.ComputePassEncoder) void {
        const compute_pass_encoder: *impl.ComputePassEncoder = @ptrCast(@alignCast(compute_pass_encoder_raw));
        compute_pass_encoder.end();
    }

    pub inline fn computePassEncoderInsertDebugMarker(compute_pass_encoder: *dgpu.ComputePassEncoder, marker_label: [*:0]const u8) void {
        _ = compute_pass_encoder;
        _ = marker_label;
        unreachable;
    }

    pub inline fn computePassEncoderPopDebugGroup(compute_pass_encoder: *dgpu.ComputePassEncoder) void {
        _ = compute_pass_encoder;
        unreachable;
    }

    pub inline fn computePassEncoderPushDebugGroup(compute_pass_encoder: *dgpu.ComputePassEncoder, group_label: [*:0]const u8) void {
        _ = compute_pass_encoder;
        _ = group_label;
        unreachable;
    }

    pub inline fn computePassEncoderSetBindGroup(compute_pass_encoder_raw: *dgpu.ComputePassEncoder, group_index: u32, group_raw: *dgpu.BindGroup, dynamic_offset_count: usize, dynamic_offsets: ?[*]const u32) void {
        const compute_pass_encoder: *impl.ComputePassEncoder = @ptrCast(@alignCast(compute_pass_encoder_raw));
        const group: *impl.BindGroup = @ptrCast(@alignCast(group_raw));
        compute_pass_encoder.setBindGroup(group_index, group, dynamic_offset_count, dynamic_offsets) catch unreachable;
    }

    pub inline fn computePassEncoderSetLabel(compute_pass_encoder: *dgpu.ComputePassEncoder, label: [*:0]const u8) void {
        _ = compute_pass_encoder;
        _ = label;
        unreachable;
    }

    pub inline fn computePassEncoderSetPipeline(compute_pass_encoder_raw: *dgpu.ComputePassEncoder, pipeline_raw: *dgpu.ComputePipeline) void {
        const compute_pass_encoder: *impl.ComputePassEncoder = @ptrCast(@alignCast(compute_pass_encoder_raw));
        const pipeline: *impl.ComputePipeline = @ptrCast(@alignCast(pipeline_raw));
        compute_pass_encoder.setPipeline(pipeline) catch unreachable;
    }

    pub inline fn computePassEncoderWriteTimestamp(compute_pass_encoder: *dgpu.ComputePassEncoder, query_set: *dgpu.QuerySet, query_index: u32) void {
        _ = compute_pass_encoder;
        _ = query_set;
        _ = query_index;
        unreachable;
    }

    pub inline fn computePassEncoderReference(compute_pass_encoder_raw: *dgpu.ComputePassEncoder) void {
        const compute_pass_encoder: *impl.ComputePassEncoder = @ptrCast(@alignCast(compute_pass_encoder_raw));
        compute_pass_encoder.manager.reference();
    }

    pub inline fn computePassEncoderRelease(compute_pass_encoder_raw: *dgpu.ComputePassEncoder) void {
        const compute_pass_encoder: *impl.ComputePassEncoder = @ptrCast(@alignCast(compute_pass_encoder_raw));
        compute_pass_encoder.manager.release();
    }

    pub inline fn computePipelineGetBindGroupLayout(compute_pipeline_raw: *dgpu.ComputePipeline, group_index: u32) *dgpu.BindGroupLayout {
        const compute_pipeline: *impl.ComputePipeline = @ptrCast(@alignCast(compute_pipeline_raw));
        const layout = compute_pipeline.getBindGroupLayout(group_index);
        layout.manager.reference();
        return @ptrCast(layout);
    }

    pub inline fn computePipelineSetLabel(compute_pipeline: *dgpu.ComputePipeline, label: [*:0]const u8) void {
        _ = compute_pipeline;
        _ = label;
        unreachable;
    }

    pub inline fn computePipelineReference(compute_pipeline_raw: *dgpu.ComputePipeline) void {
        const compute_pipeline: *impl.ComputePipeline = @ptrCast(@alignCast(compute_pipeline_raw));
        compute_pipeline.manager.reference();
    }

    pub inline fn computePipelineRelease(compute_pipeline_raw: *dgpu.ComputePipeline) void {
        const compute_pipeline: *impl.ComputePipeline = @ptrCast(@alignCast(compute_pipeline_raw));
        compute_pipeline.manager.release();
    }

    pub inline fn deviceCreateBindGroup(device_raw: *dgpu.Device, descriptor: *const dgpu.BindGroup.Descriptor) *dgpu.BindGroup {
        const device: *impl.Device = @ptrCast(@alignCast(device_raw));
        const group = device.createBindGroup(descriptor) catch unreachable;
        return @ptrCast(group);
    }

    pub inline fn deviceCreateBindGroupLayout(device_raw: *dgpu.Device, descriptor: *const dgpu.BindGroupLayout.Descriptor) *dgpu.BindGroupLayout {
        const device: *impl.Device = @ptrCast(@alignCast(device_raw));
        const layout = device.createBindGroupLayout(descriptor) catch unreachable;
        return @ptrCast(layout);
    }

    pub inline fn deviceCreateBuffer(device_raw: *dgpu.Device, descriptor: *const dgpu.Buffer.Descriptor) *dgpu.Buffer {
        const device: *impl.Device = @ptrCast(@alignCast(device_raw));
        const buffer = device.createBuffer(descriptor) catch unreachable;
        return @ptrCast(buffer);
    }

    pub inline fn deviceCreateCommandEncoder(device_raw: *dgpu.Device, descriptor: ?*const dgpu.CommandEncoder.Descriptor) *dgpu.CommandEncoder {
        const device: *impl.Device = @ptrCast(@alignCast(device_raw));
        const command_encoder = device.createCommandEncoder(descriptor orelse &.{}) catch unreachable;
        return @ptrCast(command_encoder);
    }

    pub inline fn deviceCreateComputePipeline(device_raw: *dgpu.Device, descriptor: *const dgpu.ComputePipeline.Descriptor) *dgpu.ComputePipeline {
        const device: *impl.Device = @ptrCast(@alignCast(device_raw));
        const pipeline = device.createComputePipeline(descriptor) catch unreachable;
        return @ptrCast(pipeline);
    }

    pub inline fn deviceCreateComputePipelineAsync(device: *dgpu.Device, descriptor: *const dgpu.ComputePipeline.Descriptor, callback: dgpu.CreateComputePipelineAsyncCallback, userdata: ?*anyopaque) void {
        _ = device;
        _ = descriptor;
        _ = callback;
        _ = userdata;
        unreachable;
    }

    pub inline fn deviceCreateErrorBuffer(device: *dgpu.Device, descriptor: *const dgpu.Buffer.Descriptor) *dgpu.Buffer {
        _ = device;
        _ = descriptor;
        unreachable;
    }

    pub inline fn deviceCreateErrorExternalTexture(device: *dgpu.Device) *dgpu.ExternalTexture {
        _ = device;
        unreachable;
    }

    pub inline fn deviceCreateErrorTexture(device: *dgpu.Device, descriptor: *const dgpu.Texture.Descriptor) *dgpu.Texture {
        _ = device;
        _ = descriptor;
        unreachable;
    }

    pub inline fn deviceCreateExternalTexture(device: *dgpu.Device, external_texture_descriptor: *const dgpu.ExternalTexture.Descriptor) *dgpu.ExternalTexture {
        _ = device;
        _ = external_texture_descriptor;
        unreachable;
    }

    pub inline fn deviceCreatePipelineLayout(device_raw: *dgpu.Device, pipeline_layout_descriptor: *const dgpu.PipelineLayout.Descriptor) *dgpu.PipelineLayout {
        const device: *impl.Device = @ptrCast(@alignCast(device_raw));
        const layout = device.createPipelineLayout(pipeline_layout_descriptor) catch unreachable;
        return @ptrCast(layout);
    }

    pub inline fn deviceCreateQuerySet(device: *dgpu.Device, descriptor: *const dgpu.QuerySet.Descriptor) *dgpu.QuerySet {
        _ = device;
        _ = descriptor;
        unreachable;
    }

    pub inline fn deviceCreateRenderBundleEncoder(device: *dgpu.Device, descriptor: *const dgpu.RenderBundleEncoder.Descriptor) *dgpu.RenderBundleEncoder {
        _ = device;
        _ = descriptor;
        unreachable;
    }

    pub inline fn deviceCreateRenderPipeline(device_raw: *dgpu.Device, descriptor: *const dgpu.RenderPipeline.Descriptor) *dgpu.RenderPipeline {
        const device: *impl.Device = @ptrCast(@alignCast(device_raw));
        const render_pipeline = device.createRenderPipeline(descriptor) catch unreachable;
        return @ptrCast(render_pipeline);
    }

    pub inline fn deviceCreateRenderPipelineAsync(device: *dgpu.Device, descriptor: *const dgpu.RenderPipeline.Descriptor, callback: dgpu.CreateRenderPipelineAsyncCallback, userdata: ?*anyopaque) void {
        _ = device;
        _ = descriptor;
        _ = callback;
        _ = userdata;
        unreachable;
    }

    pub fn deviceCreateSampler(device: *dgpu.Device, descriptor: ?*const dgpu.Sampler.Descriptor) *dgpu.Sampler {
        _ = device;
        _ = descriptor;
        unreachable;
    }

    pub inline fn deviceCreateShaderModule(device_raw: *dgpu.Device, descriptor: *const dgpu.ShaderModule.Descriptor) *dgpu.ShaderModule {
        const device: *impl.Device = @ptrCast(@alignCast(device_raw));

        var errors = try shader.ErrorList.init(allocator);
        defer errors.deinit();
        if (utils.findChained(dgpu.ShaderModule.WGSLDescriptor, descriptor.next_in_chain.generic)) |wgsl_descriptor| {
            const source = std.mem.span(wgsl_descriptor.code);

            var ast = shader.Ast.parse(allocator, &errors, source) catch |err| switch (err) {
                error.Parsing => {
                    errors.print(source, null) catch unreachable;
                    std.process.exit(1);
                },
                else => unreachable,
            };
            defer ast.deinit(allocator);

            var air = shader.Air.generate(allocator, &ast, &errors, null) catch |err| switch (err) {
                error.AnalysisFail => {
                    errors.print(source, null) catch unreachable;
                    std.process.exit(1);
                },
                else => unreachable,
            };
            defer air.deinit(allocator);

            const shader_module = device.createShaderModuleAir(&air) catch unreachable;
            return @ptrCast(shader_module);
        } else if (utils.findChained(dgpu.ShaderModule.SPIRVDescriptor, descriptor.next_in_chain.generic)) |spirv_descriptor| {
            const output = std.mem.sliceAsBytes(spirv_descriptor.code[0..spirv_descriptor.code_size]);
            const shader_module = device.createShaderModuleSpirv(output) catch unreachable;
            return @ptrCast(shader_module);
        }

        unreachable;
    }

    pub inline fn deviceCreateSwapChain(device_raw: *dgpu.Device, surface_raw: ?*dgpu.Surface, descriptor: *const dgpu.SwapChain.Descriptor) *dgpu.SwapChain {
        const device: *impl.Device = @ptrCast(@alignCast(device_raw));
        const surface: *impl.Surface = @ptrCast(@alignCast(surface_raw.?));
        const swapchain = device.createSwapChain(surface, descriptor) catch unreachable;
        return @ptrCast(swapchain);
    }

    pub inline fn deviceCreateTexture(device_raw: *dgpu.Device, descriptor: *const dgpu.Texture.Descriptor) *dgpu.Texture {
        const device: *impl.Device = @ptrCast(@alignCast(device_raw));
        const texture = device.createTexture(descriptor) catch unreachable;
        return @ptrCast(texture);
    }

    pub inline fn deviceDestroy(device: *dgpu.Device) void {
        _ = device;
        unreachable;
    }

    pub inline fn deviceEnumerateFeatures(device: *dgpu.Device, features: ?[*]dgpu.FeatureName) usize {
        _ = device;
        _ = features;
        unreachable;
    }

    pub inline fn deviceGetLimits(device: *dgpu.Device, limits: *dgpu.SupportedLimits) u32 {
        _ = device;
        _ = limits;
        unreachable;
    }

    pub inline fn deviceGetQueue(device_raw: *dgpu.Device) *dgpu.Queue {
        const device: *impl.Device = @ptrCast(@alignCast(device_raw));
        const queue = device.getQueue() catch unreachable;
        queue.manager.reference();
        return @ptrCast(queue);
    }

    pub inline fn deviceHasFeature(device: *dgpu.Device, feature: dgpu.FeatureName) u32 {
        _ = device;
        _ = feature;
        unreachable;
    }

    pub inline fn deviceImportSharedFence(device: *dgpu.Device, descriptor: *const dgpu.SharedFence.Descriptor) *dgpu.SharedFence {
        _ = device;
        _ = descriptor;
        unreachable;
    }

    pub inline fn deviceImportSharedTextureMemory(device: *dgpu.Device, descriptor: *const dgpu.SharedTextureMemory.Descriptor) *dgpu.SharedTextureMemory {
        _ = device;
        _ = descriptor;
        unreachable;
    }

    pub inline fn deviceInjectError(device: *dgpu.Device, typ: dgpu.ErrorType, message: [*:0]const u8) void {
        _ = device;
        _ = typ;
        _ = message;
        unreachable;
    }

    pub inline fn deviceLoseForTesting(device: *dgpu.Device) void {
        _ = device;
        unreachable;
    }

    pub inline fn devicePopErrorScope(device: *dgpu.Device, callback: dgpu.ErrorCallback, userdata: ?*anyopaque) void {
        _ = device;
        _ = callback;
        _ = userdata;
        unreachable;
    }

    pub inline fn devicePushErrorScope(device: *dgpu.Device, filter: dgpu.ErrorFilter) void {
        _ = device;
        _ = filter;
        unreachable;
    }

    pub inline fn deviceSetDeviceLostCallback(device_raw: *dgpu.Device, callback: ?dgpu.Device.LostCallback, userdata: ?*anyopaque) void {
        const device: *impl.Device = @ptrCast(@alignCast(device_raw));
        device.lost_cb = callback;
        device.lost_cb_userdata = userdata;
    }

    pub inline fn deviceSetLabel(device: *dgpu.Device, label: [*:0]const u8) void {
        _ = device;
        _ = label;
        unreachable;
    }

    pub inline fn deviceSetLoggingCallback(device_raw: *dgpu.Device, callback: ?dgpu.LoggingCallback, userdata: ?*anyopaque) void {
        const device: *impl.Device = @ptrCast(@alignCast(device_raw));
        device.log_cb = callback;
        device.log_cb_userdata = userdata;
    }

    pub inline fn deviceSetUncapturedErrorCallback(device_raw: *dgpu.Device, callback: ?dgpu.ErrorCallback, userdata: ?*anyopaque) void {
        const device: *impl.Device = @ptrCast(@alignCast(device_raw));
        device.err_cb = callback;
        device.err_cb_userdata = userdata;
    }

    pub inline fn deviceTick(device_raw: *dgpu.Device) void {
        const device: *impl.Device = @ptrCast(@alignCast(device_raw));
        device.tick() catch unreachable;
    }

    pub inline fn machDeviceWaitForCommandsToBeScheduled(device: *dgpu.Device) void {
        _ = device;
    }

    pub inline fn deviceReference(device_raw: *dgpu.Device) void {
        const device: *impl.Device = @ptrCast(@alignCast(device_raw));
        device.manager.reference();
    }

    pub inline fn deviceRelease(device_raw: *dgpu.Device) void {
        const device: *impl.Device = @ptrCast(@alignCast(device_raw));
        device.manager.release();
    }

    pub inline fn externalTextureDestroy(external_texture: *dgpu.ExternalTexture) void {
        _ = external_texture;
        unreachable;
    }

    pub inline fn externalTextureSetLabel(external_texture: *dgpu.ExternalTexture, label: [*:0]const u8) void {
        _ = external_texture;
        _ = label;
        unreachable;
    }

    pub inline fn externalTextureReference(external_texture: *dgpu.ExternalTexture) void {
        _ = external_texture;
        unreachable;
    }

    pub inline fn externalTextureRelease(external_texture: *dgpu.ExternalTexture) void {
        _ = external_texture;
        unreachable;
    }

    pub inline fn instanceCreateSurface(instance_raw: *dgpu.Instance, descriptor: *const dgpu.Surface.Descriptor) *dgpu.Surface {
        const instance: *impl.Instance = @ptrCast(@alignCast(instance_raw));
        const surface = instance.createSurface(descriptor) catch unreachable;
        return @ptrCast(surface);
    }

    pub inline fn instanceProcessEvents(instance: *dgpu.Instance) void {
        _ = instance;
        unreachable;
    }

    pub inline fn instanceRequestAdapter(
        instance_raw: *dgpu.Instance,
        options: ?*const dgpu.RequestAdapterOptions,
        callback: dgpu.RequestAdapterCallback,
        userdata: ?*anyopaque,
    ) void {
        const instance: *impl.Instance = @ptrCast(@alignCast(instance_raw));
        const adapter = impl.Adapter.init(instance, options orelse &dgpu.RequestAdapterOptions{}) catch |err| {
            return callback(.err, undefined, @errorName(err), userdata);
        };
        callback(.success, @as(*dgpu.Adapter, @ptrCast(adapter)), null, userdata);
    }

    pub inline fn instanceReference(instance_raw: *dgpu.Instance) void {
        const instance: *impl.Instance = @ptrCast(@alignCast(instance_raw));
        instance.manager.reference();
    }

    pub inline fn instanceRelease(instance_raw: *dgpu.Instance) void {
        const instance: *impl.Instance = @ptrCast(@alignCast(instance_raw));
        instance.manager.release();
    }

    pub inline fn pipelineLayoutSetLabel(pipeline_layout: *dgpu.PipelineLayout, label: [*:0]const u8) void {
        _ = pipeline_layout;
        _ = label;
        unreachable;
    }

    pub inline fn pipelineLayoutReference(pipeline_layout_raw: *dgpu.PipelineLayout) void {
        const pipeline_layout: *impl.PipelineLayout = @ptrCast(@alignCast(pipeline_layout_raw));
        pipeline_layout.manager.reference();
    }

    pub inline fn pipelineLayoutRelease(pipeline_layout_raw: *dgpu.PipelineLayout) void {
        const pipeline_layout: *impl.PipelineLayout = @ptrCast(@alignCast(pipeline_layout_raw));
        pipeline_layout.manager.release();
    }

    pub inline fn querySetDestroy(query_set: *dgpu.QuerySet) void {
        _ = query_set;
        unreachable;
    }

    pub inline fn querySetGetCount(query_set: *dgpu.QuerySet) u32 {
        _ = query_set;
        unreachable;
    }

    pub inline fn querySetGetType(query_set: *dgpu.QuerySet) dgpu.QueryType {
        _ = query_set;
        unreachable;
    }

    pub inline fn querySetSetLabel(query_set: *dgpu.QuerySet, label: [*:0]const u8) void {
        _ = query_set;
        _ = label;
        unreachable;
    }

    pub inline fn querySetReference(query_set: *dgpu.QuerySet) void {
        _ = query_set;
        unreachable;
    }

    pub inline fn querySetRelease(query_set: *dgpu.QuerySet) void {
        _ = query_set;
        unreachable;
    }

    pub inline fn queueCopyTextureForBrowser(queue: *dgpu.Queue, source: *const dgpu.ImageCopyTexture, destination: *const dgpu.ImageCopyTexture, copy_size: *const dgpu.Extent3D, options: *const dgpu.CopyTextureForBrowserOptions) void {
        _ = queue;
        _ = source;
        _ = destination;
        _ = copy_size;
        _ = options;
        unreachable;
    }

    pub inline fn queueOnSubmittedWorkDone(queue: *dgpu.Queue, signal_value: u64, callback: dgpu.Queue.WorkDoneCallback, userdata: ?*anyopaque) void {
        _ = queue;
        _ = signal_value;
        _ = callback;
        _ = userdata;
        unreachable;
    }

    pub inline fn queueSetLabel(queue: *dgpu.Queue, label: [*:0]const u8) void {
        _ = queue;
        _ = label;
        unreachable;
    }

    pub inline fn queueSubmit(queue_raw: *dgpu.Queue, command_count: usize, commands_raw: [*]const *const dgpu.CommandBuffer) void {
        const queue: *impl.Queue = @ptrCast(@alignCast(queue_raw));
        const commands: []const *impl.CommandBuffer = @ptrCast(commands_raw[0..command_count]);
        queue.submit(commands) catch unreachable;
    }

    pub inline fn queueWriteBuffer(queue_raw: *dgpu.Queue, buffer_raw: *dgpu.Buffer, buffer_offset: u64, data: *const anyopaque, size: usize) void {
        const queue: *impl.Queue = @ptrCast(@alignCast(queue_raw));
        const buffer: *impl.Buffer = @ptrCast(@alignCast(buffer_raw));
        queue.writeBuffer(buffer, buffer_offset, @ptrCast(data), size) catch unreachable;
    }

    pub inline fn queueWriteTexture(queue: *dgpu.Queue, destination: *const dgpu.ImageCopyTexture, data: *const anyopaque, data_size: usize, data_layout: *const dgpu.Texture.DataLayout, write_size: *const dgpu.Extent3D) void {
        _ = queue;
        _ = destination;
        _ = data;
        _ = data_size;
        _ = data_layout;
        _ = write_size;
        unreachable;
    }

    pub inline fn queueReference(queue_raw: *dgpu.Queue) void {
        const queue: *impl.Queue = @ptrCast(@alignCast(queue_raw));
        queue.manager.reference();
    }

    pub inline fn queueRelease(queue_raw: *dgpu.Queue) void {
        const queue: *impl.Queue = @ptrCast(@alignCast(queue_raw));
        queue.manager.release();
    }

    pub inline fn renderBundleReference(render_bundle: *dgpu.RenderBundle) void {
        _ = render_bundle;
        unreachable;
    }

    pub inline fn renderBundleRelease(render_bundle: *dgpu.RenderBundle) void {
        _ = render_bundle;
        unreachable;
    }

    pub inline fn renderBundleSetLabel(render_bundle: *dgpu.RenderBundle, name: [*:0]const u8) void {
        _ = name;
        _ = render_bundle;
        unreachable;
    }

    pub inline fn renderBundleEncoderDraw(render_bundle_encoder: *dgpu.RenderBundleEncoder, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void {
        _ = render_bundle_encoder;
        _ = vertex_count;
        _ = instance_count;
        _ = first_vertex;
        _ = first_instance;
        unreachable;
    }

    pub inline fn renderBundleEncoderDrawIndexed(render_bundle_encoder: *dgpu.RenderBundleEncoder, index_count: u32, instance_count: u32, first_index: u32, base_vertex: i32, first_instance: u32) void {
        _ = render_bundle_encoder;
        _ = index_count;
        _ = instance_count;
        _ = first_index;
        _ = base_vertex;
        _ = first_instance;
        unreachable;
    }

    pub inline fn renderBundleEncoderDrawIndexedIndirect(render_bundle_encoder: *dgpu.RenderBundleEncoder, indirect_buffer: *dgpu.Buffer, indirect_offset: u64) void {
        _ = render_bundle_encoder;
        _ = indirect_buffer;
        _ = indirect_offset;
        unreachable;
    }

    pub inline fn renderBundleEncoderDrawIndirect(render_bundle_encoder: *dgpu.RenderBundleEncoder, indirect_buffer: *dgpu.Buffer, indirect_offset: u64) void {
        _ = render_bundle_encoder;
        _ = indirect_buffer;
        _ = indirect_offset;
        unreachable;
    }

    pub inline fn renderBundleEncoderFinish(render_bundle_encoder: *dgpu.RenderBundleEncoder, descriptor: ?*const dgpu.RenderBundle.Descriptor) *dgpu.RenderBundle {
        _ = render_bundle_encoder;
        _ = descriptor;
        unreachable;
    }

    pub inline fn renderBundleEncoderInsertDebugMarker(render_bundle_encoder: *dgpu.RenderBundleEncoder, marker_label: [*:0]const u8) void {
        _ = render_bundle_encoder;
        _ = marker_label;
        unreachable;
    }

    pub inline fn renderBundleEncoderPopDebugGroup(render_bundle_encoder: *dgpu.RenderBundleEncoder) void {
        _ = render_bundle_encoder;
        unreachable;
    }

    pub inline fn renderBundleEncoderPushDebugGroup(render_bundle_encoder: *dgpu.RenderBundleEncoder, group_label: [*:0]const u8) void {
        _ = render_bundle_encoder;
        _ = group_label;
        unreachable;
    }

    pub inline fn renderBundleEncoderSetBindGroup(render_bundle_encoder: *dgpu.RenderBundleEncoder, group_index: u32, group: *dgpu.BindGroup, dynamic_offset_count: usize, dynamic_offsets: ?[*]const u32) void {
        _ = render_bundle_encoder;
        _ = group_index;
        _ = group;
        _ = dynamic_offset_count;
        _ = dynamic_offsets;
        unreachable;
    }

    pub inline fn renderBundleEncoderSetIndexBuffer(render_bundle_encoder: *dgpu.RenderBundleEncoder, buffer: *dgpu.Buffer, format: dgpu.IndexFormat, offset: u64, size: u64) void {
        _ = render_bundle_encoder;
        _ = buffer;
        _ = format;
        _ = offset;
        _ = size;
        unreachable;
    }

    pub inline fn renderBundleEncoderSetLabel(render_bundle_encoder: *dgpu.RenderBundleEncoder, label: [*:0]const u8) void {
        _ = render_bundle_encoder;
        _ = label;
        unreachable;
    }

    pub inline fn renderBundleEncoderSetPipeline(render_bundle_encoder: *dgpu.RenderBundleEncoder, pipeline: *dgpu.RenderPipeline) void {
        _ = render_bundle_encoder;
        _ = pipeline;
        unreachable;
    }

    pub inline fn renderBundleEncoderSetVertexBuffer(render_bundle_encoder: *dgpu.RenderBundleEncoder, slot: u32, buffer: *dgpu.Buffer, offset: u64, size: u64) void {
        _ = render_bundle_encoder;
        _ = slot;
        _ = buffer;
        _ = offset;
        _ = size;
        unreachable;
    }

    pub inline fn renderBundleEncoderReference(render_bundle_encoder: *dgpu.RenderBundleEncoder) void {
        _ = render_bundle_encoder;
        unreachable;
    }

    pub inline fn renderBundleEncoderRelease(render_bundle_encoder: *dgpu.RenderBundleEncoder) void {
        _ = render_bundle_encoder;
        unreachable;
    }

    pub inline fn renderPassEncoderBeginOcclusionQuery(render_pass_encoder: *dgpu.RenderPassEncoder, query_index: u32) void {
        _ = render_pass_encoder;
        _ = query_index;
        unreachable;
    }

    pub inline fn renderPassEncoderDraw(render_pass_encoder_raw: *dgpu.RenderPassEncoder, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void {
        const render_pass_encoder: *impl.RenderPassEncoder = @ptrCast(@alignCast(render_pass_encoder_raw));
        render_pass_encoder.draw(vertex_count, instance_count, first_vertex, first_instance);
    }

    pub inline fn renderPassEncoderDrawIndexed(render_pass_encoder: *dgpu.RenderPassEncoder, index_count: u32, instance_count: u32, first_index: u32, base_vertex: i32, first_instance: u32) void {
        _ = render_pass_encoder;
        _ = index_count;
        _ = instance_count;
        _ = first_index;
        _ = base_vertex;
        _ = first_instance;
        unreachable;
    }

    pub inline fn renderPassEncoderDrawIndexedIndirect(render_pass_encoder: *dgpu.RenderPassEncoder, indirect_buffer: *dgpu.Buffer, indirect_offset: u64) void {
        _ = render_pass_encoder;
        _ = indirect_buffer;
        _ = indirect_offset;
        unreachable;
    }

    pub inline fn renderPassEncoderDrawIndirect(render_pass_encoder: *dgpu.RenderPassEncoder, indirect_buffer: *dgpu.Buffer, indirect_offset: u64) void {
        _ = render_pass_encoder;
        _ = indirect_buffer;
        _ = indirect_offset;
        unreachable;
    }

    pub inline fn renderPassEncoderEnd(render_pass_encoder_raw: *dgpu.RenderPassEncoder) void {
        const render_pass_encoder: *impl.RenderPassEncoder = @ptrCast(@alignCast(render_pass_encoder_raw));
        render_pass_encoder.end();
    }

    pub inline fn renderPassEncoderEndOcclusionQuery(render_pass_encoder: *dgpu.RenderPassEncoder) void {
        _ = render_pass_encoder;
        unreachable;
    }

    pub inline fn renderPassEncoderExecuteBundles(render_pass_encoder: *dgpu.RenderPassEncoder, bundles_count: usize, bundles: [*]const *const dgpu.RenderBundle) void {
        _ = render_pass_encoder;
        _ = bundles_count;
        _ = bundles;
        unreachable;
    }

    pub inline fn renderPassEncoderInsertDebugMarker(render_pass_encoder: *dgpu.RenderPassEncoder, marker_label: [*:0]const u8) void {
        _ = render_pass_encoder;
        _ = marker_label;
        unreachable;
    }

    pub inline fn renderPassEncoderPopDebugGroup(render_pass_encoder: *dgpu.RenderPassEncoder) void {
        _ = render_pass_encoder;
        unreachable;
    }

    pub inline fn renderPassEncoderPushDebugGroup(render_pass_encoder: *dgpu.RenderPassEncoder, group_label: [*:0]const u8) void {
        _ = render_pass_encoder;
        _ = group_label;
        unreachable;
    }

    pub inline fn renderPassEncoderSetBindGroup(
        render_pass_encoder_raw: *dgpu.RenderPassEncoder,
        group_index: u32,
        group_raw: *dgpu.BindGroup,
        dynamic_offset_count: usize,
        dynamic_offsets: ?[*]const u32,
    ) void {
        const render_pass_encoder: *impl.RenderPassEncoder = @ptrCast(@alignCast(render_pass_encoder_raw));
        const group: *impl.BindGroup = @ptrCast(@alignCast(group_raw));
        render_pass_encoder.setBindGroup(group_index, group, dynamic_offset_count, dynamic_offsets) catch unreachable;
    }

    pub inline fn renderPassEncoderSetBlendConstant(render_pass_encoder: *dgpu.RenderPassEncoder, color: *const dgpu.Color) void {
        _ = render_pass_encoder;
        _ = color;
        unreachable;
    }

    pub inline fn renderPassEncoderSetIndexBuffer(render_pass_encoder: *dgpu.RenderPassEncoder, buffer: *dgpu.Buffer, format: dgpu.IndexFormat, offset: u64, size: u64) void {
        _ = render_pass_encoder;
        _ = buffer;
        _ = format;
        _ = offset;
        _ = size;
        unreachable;
    }

    pub inline fn renderPassEncoderSetLabel(render_pass_encoder: *dgpu.RenderPassEncoder, label: [*:0]const u8) void {
        _ = render_pass_encoder;
        _ = label;
        unreachable;
    }

    pub inline fn renderPassEncoderSetPipeline(render_pass_encoder_raw: *dgpu.RenderPassEncoder, pipeline_raw: *dgpu.RenderPipeline) void {
        const render_pass_encoder: *impl.RenderPassEncoder = @ptrCast(@alignCast(render_pass_encoder_raw));
        const pipeline: *impl.RenderPipeline = @ptrCast(@alignCast(pipeline_raw));
        render_pass_encoder.setPipeline(pipeline) catch unreachable;
    }

    pub inline fn renderPassEncoderSetScissorRect(render_pass_encoder: *dgpu.RenderPassEncoder, x: u32, y: u32, width: u32, height: u32) void {
        _ = render_pass_encoder;
        _ = x;
        _ = y;
        _ = width;
        _ = height;
        unreachable;
    }

    pub inline fn renderPassEncoderSetStencilReference(render_pass_encoder: *dgpu.RenderPassEncoder, reference: u32) void {
        _ = render_pass_encoder;
        _ = reference;
        unreachable;
    }

    pub inline fn renderPassEncoderSetVertexBuffer(render_pass_encoder_raw: *dgpu.RenderPassEncoder, slot: u32, buffer_raw: *dgpu.Buffer, offset: u64, size: u64) void {
        const render_pass_encoder: *impl.RenderPassEncoder = @ptrCast(@alignCast(render_pass_encoder_raw));
        const buffer: *impl.Buffer = @ptrCast(@alignCast(buffer_raw));
        render_pass_encoder.setVertexBuffer(slot, buffer, offset, size) catch unreachable;
    }

    pub inline fn renderPassEncoderSetViewport(render_pass_encoder: *dgpu.RenderPassEncoder, x: f32, y: f32, width: f32, height: f32, min_depth: f32, max_depth: f32) void {
        _ = render_pass_encoder;
        _ = x;
        _ = y;
        _ = width;
        _ = height;
        _ = min_depth;
        _ = max_depth;
        unreachable;
    }

    pub inline fn renderPassEncoderWriteTimestamp(render_pass_encoder: *dgpu.RenderPassEncoder, query_set: *dgpu.QuerySet, query_index: u32) void {
        _ = render_pass_encoder;
        _ = query_set;
        _ = query_index;
        unreachable;
    }

    pub inline fn renderPassEncoderReference(render_pass_encoder_raw: *dgpu.RenderPassEncoder) void {
        const render_pass_encoder: *impl.RenderPassEncoder = @ptrCast(@alignCast(render_pass_encoder_raw));
        render_pass_encoder.manager.reference();
    }

    pub inline fn renderPassEncoderRelease(render_pass_encoder_raw: *dgpu.RenderPassEncoder) void {
        const render_pass_encoder: *impl.RenderPassEncoder = @ptrCast(@alignCast(render_pass_encoder_raw));
        render_pass_encoder.manager.release();
    }

    pub inline fn renderPipelineGetBindGroupLayout(render_pipeline_raw: *dgpu.RenderPipeline, group_index: u32) *dgpu.BindGroupLayout {
        const render_pipeline: *impl.RenderPipeline = @ptrCast(@alignCast(render_pipeline_raw));
        const layout: *impl.BindGroupLayout = render_pipeline.getBindGroupLayout(group_index);
        layout.manager.reference();
        return @ptrCast(layout);
    }

    pub inline fn renderPipelineSetLabel(render_pipeline: *dgpu.RenderPipeline, label: [*:0]const u8) void {
        _ = render_pipeline;
        _ = label;
        unreachable;
    }

    pub inline fn renderPipelineReference(render_pipeline_raw: *dgpu.RenderPipeline) void {
        const render_pipeline: *impl.RenderPipeline = @ptrCast(@alignCast(render_pipeline_raw));
        render_pipeline.manager.reference();
    }

    pub inline fn renderPipelineRelease(render_pipeline_raw: *dgpu.RenderPipeline) void {
        const render_pipeline: *impl.RenderPipeline = @ptrCast(@alignCast(render_pipeline_raw));
        render_pipeline.manager.release();
    }

    pub inline fn samplerSetLabel(sampler: *dgpu.Sampler, label: [*:0]const u8) void {
        _ = sampler;
        _ = label;
        unreachable;
    }

    pub inline fn samplerReference(sampler: *dgpu.Sampler) void {
        _ = sampler;
        unreachable;
    }

    pub inline fn samplerRelease(sampler: *dgpu.Sampler) void {
        _ = sampler;
        unreachable;
    }

    pub inline fn shaderModuleGetCompilationInfo(shader_module: *dgpu.ShaderModule, callback: dgpu.CompilationInfoCallback, userdata: ?*anyopaque) void {
        _ = shader_module;
        _ = callback;
        _ = userdata;
        unreachable;
    }

    pub inline fn shaderModuleSetLabel(shader_module: *dgpu.ShaderModule, label: [*:0]const u8) void {
        _ = shader_module;
        _ = label;
        unreachable;
    }

    pub inline fn shaderModuleReference(shader_module_raw: *dgpu.ShaderModule) void {
        const shader_module: *impl.ShaderModule = @ptrCast(@alignCast(shader_module_raw));
        shader_module.manager.reference();
    }

    pub inline fn shaderModuleRelease(shader_module_raw: *dgpu.ShaderModule) void {
        const shader_module: *impl.ShaderModule = @ptrCast(@alignCast(shader_module_raw));
        shader_module.manager.release();
    }

    pub inline fn sharedFenceExportInfo(shared_fence: *dgpu.SharedFence, info: *dgpu.SharedFence.ExportInfo) void {
        _ = shared_fence;
        _ = info;
        unreachable;
    }

    pub inline fn sharedFenceReference(shared_fence: *dgpu.SharedFence) void {
        _ = shared_fence;
        unreachable;
    }

    pub inline fn sharedFenceRelease(shared_fence: *dgpu.SharedFence) void {
        _ = shared_fence;
        unreachable;
    }

    pub inline fn sharedTextureMemoryBeginAccess(shared_texture_memory: *dgpu.SharedTextureMemory, texture: *dgpu.Texture, descriptor: *const dgpu.SharedTextureMemory.BeginAccessDescriptor) void {
        _ = shared_texture_memory;
        _ = texture;
        _ = descriptor;
        unreachable;
    }

    pub inline fn sharedTextureMemoryCreateTexture(shared_texture_memory: *dgpu.SharedTextureMemory, descriptor: *const dgpu.Texture.Descriptor) *dgpu.Texture {
        _ = shared_texture_memory;
        _ = descriptor;
        unreachable;
    }

    pub inline fn sharedTextureMemoryEndAccess(shared_texture_memory: *dgpu.SharedTextureMemory, texture: *dgpu.Texture, descriptor: *dgpu.SharedTextureMemory.EndAccessState) void {
        _ = shared_texture_memory;
        _ = texture;
        _ = descriptor;
        unreachable;
    }

    pub inline fn sharedTextureMemoryEndAccessStateFreeMembers(value: dgpu.SharedTextureMemory.EndAccessState) void {
        _ = value;
        unreachable;
    }

    pub inline fn sharedTextureMemoryGetProperties(shared_texture_memory: *dgpu.SharedTextureMemory, properties: *dgpu.SharedTextureMemory.Properties) void {
        _ = shared_texture_memory;
        _ = properties;
        unreachable;
    }

    pub inline fn sharedTextureMemorySetLabel(shared_texture_memory: *dgpu.SharedTextureMemory, label: [*:0]const u8) void {
        _ = shared_texture_memory;
        _ = label;
        unreachable;
    }

    pub inline fn sharedTextureMemoryReference(shared_texture_memory: *dgpu.SharedTextureMemory) void {
        _ = shared_texture_memory;
        unreachable;
    }

    pub inline fn sharedTextureMemoryRelease(shared_texture_memory: *dgpu.SharedTextureMemory) void {
        _ = shared_texture_memory;
        unreachable;
    }

    pub inline fn surfaceReference(surface_raw: *dgpu.Surface) void {
        const surface: *impl.Surface = @ptrCast(@alignCast(surface_raw));
        surface.manager.reference();
    }

    pub inline fn surfaceRelease(surface_raw: *dgpu.Surface) void {
        const surface: *impl.Surface = @ptrCast(@alignCast(surface_raw));
        surface.manager.release();
    }

    pub inline fn swapChainConfigure(swap_chain: *dgpu.SwapChain, format: dgpu.Texture.Format, allowed_usage: dgpu.Texture.UsageFlags, width: u32, height: u32) void {
        _ = swap_chain;
        _ = format;
        _ = allowed_usage;
        _ = width;
        _ = height;
        unreachable;
    }

    pub inline fn swapChainGetCurrentTexture(swap_chain: *dgpu.SwapChain) ?*dgpu.Texture {
        _ = swap_chain;
        unreachable;
    }

    pub inline fn swapChainGetCurrentTextureView(swap_chain_raw: *dgpu.SwapChain) ?*dgpu.TextureView {
        const swap_chain: *impl.SwapChain = @ptrCast(@alignCast(swap_chain_raw));
        const texture_view = swap_chain.getCurrentTextureView() catch unreachable;
        return @ptrCast(texture_view);
    }

    pub inline fn swapChainPresent(swap_chain_raw: *dgpu.SwapChain) void {
        const swap_chain: *impl.SwapChain = @ptrCast(@alignCast(swap_chain_raw));
        swap_chain.present() catch unreachable;
    }

    pub inline fn swapChainReference(swap_chain_raw: *dgpu.SwapChain) void {
        const swap_chain: *impl.SwapChain = @ptrCast(@alignCast(swap_chain_raw));
        swap_chain.manager.reference();
    }

    pub inline fn swapChainRelease(swap_chain_raw: *dgpu.SwapChain) void {
        const swap_chain: *impl.SwapChain = @ptrCast(@alignCast(swap_chain_raw));
        swap_chain.manager.release();
    }

    pub inline fn textureCreateView(texture_raw: *dgpu.Texture, descriptor: ?*const dgpu.TextureView.Descriptor) *dgpu.TextureView {
        const texture: *impl.Texture = @ptrCast(@alignCast(texture_raw));
        const texture_view = texture.createView(descriptor) catch unreachable;
        return @ptrCast(texture_view);
    }

    pub inline fn textureDestroy(texture: *dgpu.Texture) void {
        _ = texture;
        unreachable;
    }

    pub inline fn textureGetDepthOrArrayLayers(texture: *dgpu.Texture) u32 {
        _ = texture;
        unreachable;
    }

    pub inline fn textureGetDimension(texture: *dgpu.Texture) dgpu.Texture.Dimension {
        _ = texture;
        unreachable;
    }

    pub inline fn textureGetFormat(texture: *dgpu.Texture) dgpu.Texture.Format {
        _ = texture;
        unreachable;
    }

    pub inline fn textureGetHeight(texture: *dgpu.Texture) u32 {
        _ = texture;
        unreachable;
    }

    pub inline fn textureGetMipLevelCount(texture: *dgpu.Texture) u32 {
        _ = texture;
        unreachable;
    }

    pub inline fn textureGetSampleCount(texture: *dgpu.Texture) u32 {
        _ = texture;
        unreachable;
    }

    pub inline fn textureGetUsage(texture: *dgpu.Texture) dgpu.Texture.UsageFlags {
        _ = texture;
        unreachable;
    }

    pub inline fn textureGetWidth(texture: *dgpu.Texture) u32 {
        _ = texture;
        unreachable;
    }

    pub inline fn textureSetLabel(texture: *dgpu.Texture, label: [*:0]const u8) void {
        _ = texture;
        _ = label;
        unreachable;
    }

    pub inline fn textureReference(texture_raw: *dgpu.Texture) void {
        const texture: *impl.Texture = @ptrCast(@alignCast(texture_raw));
        texture.manager.reference();
    }

    pub inline fn textureRelease(texture_raw: *dgpu.Texture) void {
        const texture: *impl.Texture = @ptrCast(@alignCast(texture_raw));
        texture.manager.release();
    }

    pub inline fn textureViewSetLabel(texture_view: *dgpu.TextureView, label: [*:0]const u8) void {
        _ = texture_view;
        _ = label;
        unreachable;
    }

    pub inline fn textureViewReference(texture_view_raw: *dgpu.TextureView) void {
        const texture_view: *impl.TextureView = @ptrCast(@alignCast(texture_view_raw));
        texture_view.manager.reference();
    }

    pub inline fn textureViewRelease(texture_view_raw: *dgpu.TextureView) void {
        const texture_view: *impl.TextureView = @ptrCast(@alignCast(texture_view_raw));
        texture_view.manager.release();
    }
};

test "refAllDeclsRecursive" {
    std.testing.refAllDeclsRecursive(@This());
}

test "export" {
    _ = dgpu.Export(Impl);
}
