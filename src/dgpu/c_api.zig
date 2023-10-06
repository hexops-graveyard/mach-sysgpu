const std = @import("std");
const dgpu = @import("main.zig");
const span = std.mem.span;

const InstanceDescriptor = extern struct {};

const DeviceDescriptor = extern struct {
    label: ?[*:0]const u8 = null,
    required_features_count: usize = 0,
    required_features: ?[*]const dgpu.FeatureName = null,
    required_limits: *const dgpu.Limits = &.{},
    default_queue: QueueDescriptor = .{},
    device_lost_callback: dgpu.Device.LostCallback,
    device_lost_userdata: ?*anyopaque,
};

const QueueDescriptor = extern struct {
    label: ?[*:0]const u8 = null,
};

/// Exports C ABI function declarations for the given dgpu.Interface implementation.
pub fn Export(comptime T: type) type {
    return struct {
        // DGPU_EXPORT DGPUInstance dgpuCreateInstance(DGPUInstanceDescriptor descriptor);
        export fn dgpuCreateInstance(descriptor: *const dgpu.Instance.Descriptor) ?*dgpu.Instance {
            _ = descriptor;
            return T.createInstance(.{});
        }

        // DGPU_EXPORT DGPUProc dgpuGetProcAddress(DGPUDevice device, char const * procName);
        export fn dgpuGetProcAddress(device: *dgpu.Device, proc_name: [*:0]const u8) ?dgpu.Proc {
            return T.getProcAddress(device, span(proc_name));
        }

        // DGPU_EXPORT DGPUDevice dgpuAdapterCreateDevice(DGPUAdapter adapter, DGPUDeviceDescriptor descriptor);
        export fn dgpuAdapterCreateDevice(adapter: *dgpu.Adapter, descriptor: DeviceDescriptor) ?*dgpu.Device {
            return T.adapterCreateDevice(adapter, .{
                .label = if (descriptor.label) |l| span(l) else null,
                .required_features = if (descriptor.required_features) |f| f[0..descriptor.required_features_count] else &.{},
                .required_limits = descriptor.required_limits.*,
                .default_queue = .{ .label = if (descriptor.default_queue.label) |l| span(l) else null },
                .device_lost_callback = descriptor.device_lost_callback,
                .device_lost_userdata = descriptor.device_lost_userdata,
            });
        }

        // DGPU_EXPORT size_t dgpuAdapterEnumerateFeatures(DGPUAdapter adapter, DGPUFeatureName * features);
        export fn dgpuAdapterEnumerateFeatures(adapter: *dgpu.Adapter, features: ?[*]dgpu.FeatureName) usize {
            return T.adapterEnumerateFeatures(adapter, features);
        }

        // // DGPU_EXPORT DGPUInstance dgpuAdapterGetInstance(DGPUAdapter adapter);
        // export fn dgpuAdapterGetInstance(adapter: *dgpu.Adapter) *dgpu.Instance {
        //     return T.adapterGetInstance(adapter);
        // }

        // // DGPU_EXPORT DGPUBool dgpuAdapterGetLimits(DGPUAdapter adapter, DGPUSupportedLimits * limits);
        // export fn dgpuAdapterGetLimits(adapter: *dgpu.Adapter, limits: *dgpu.Limits) u32 {
        //     return T.adapterGetLimits(adapter, limits);
        // }

        // // DGPU_EXPORT void dgpuAdapterGetProperties(DGPUAdapter adapter, DGPUAdapterProperties * properties);
        // export fn dgpuAdapterGetProperties(adapter: *dgpu.Adapter, properties: *dgpu.Adapter.Properties) void {
        //     return T.adapterGetProperties(adapter, properties);
        // }

        // // DGPU_EXPORT DGPUBool dgpuAdapterHasFeature(DGPUAdapter adapter, DGPUFeatureName feature);
        // export fn dgpuAdapterHasFeature(adapter: *dgpu.Adapter, feature: dgpu.FeatureName) u32 {
        //     return T.adapterHasFeature(adapter, feature);
        // }

        // // DGPU_EXPORT void dgpuAdapterPropertiesFreeMembers(DGPUAdapterProperties value);
        // export fn dgpuAdapterPropertiesFreeMembers(value: dgpu.Adapter.Properties) void {
        //     T.adapterPropertiesFreeMembers(value);
        // }

        // // DGPU_EXPORT void dgpuAdapterReference(DGPUAdapter adapter);
        // export fn dgpuAdapterReference(adapter: *dgpu.Adapter) void {
        //     T.adapterReference(adapter);
        // }

        // // DGPU_EXPORT void dgpuAdapterRelease(DGPUAdapter adapter);
        // export fn dgpuAdapterRelease(adapter: *dgpu.Adapter) void {
        //     T.adapterRelease(adapter);
        // }

        // // DGPU_EXPORT void dgpuBindGroupSetLabel(DGPUBindGroup bindGroup, char const * label);
        // export fn dgpuBindGroupSetLabel(bind_group: *dgpu.BindGroup, label: [:0]const u8) void {
        //     T.bindGroupSetLabel(bind_group, label);
        // }

        // // DGPU_EXPORT void dgpuBindGroupReference(DGPUBindGroup bindGroup);
        // export fn dgpuBindGroupReference(bind_group: *dgpu.BindGroup) void {
        //     T.bindGroupReference(bind_group);
        // }

        // // DGPU_EXPORT void dgpuBindGroupRelease(DGPUBindGroup bindGroup);
        // export fn dgpuBindGroupRelease(bind_group: *dgpu.BindGroup) void {
        //     T.bindGroupRelease(bind_group);
        // }

        // // DGPU_EXPORT void dgpuBindGroupLayoutSetLabel(DGPUBindGroupLayout bindGroupLayout, char const * label);
        // export fn dgpuBindGroupLayoutSetLabel(bind_group_layout: *dgpu.BindGroupLayout, label: [:0]const u8) void {
        //     T.bindGroupLayoutSetLabel(bind_group_layout, label);
        // }

        // // DGPU_EXPORT void dgpuBindGroupLayoutReference(DGPUBindGroupLayout bindGroupLayout);
        // export fn dgpuBindGroupLayoutReference(bind_group_layout: *dgpu.BindGroupLayout) void {
        //     T.bindGroupLayoutReference(bind_group_layout);
        // }

        // // DGPU_EXPORT void dgpuBindGroupLayoutRelease(DGPUBindGroupLayout bindGroupLayout);
        // export fn dgpuBindGroupLayoutRelease(bind_group_layout: *dgpu.BindGroupLayout) void {
        //     T.bindGroupLayoutRelease(bind_group_layout);
        // }

        // // DGPU_EXPORT void dgpuBufferDestroy(DGPUBuffer buffer);
        // export fn dgpuBufferDestroy(buffer: *dgpu.Buffer) void {
        //     T.bufferDestroy(buffer);
        // }

        // // DGPU_EXPORT void const * dgpuBufferGetConstMappedRange(DGPUBuffer buffer, size_t offset, size_t size);
        // export fn dgpuBufferGetConstMappedRange(buffer: *dgpu.Buffer, offset: usize, size: usize) ?*const anyopaque {
        //     return T.bufferGetConstMappedRange(buffer, offset, size);
        // }

        // // DGPU_EXPORT void * dgpuBufferGetMappedRange(DGPUBuffer buffer, size_t offset, size_t size);
        // export fn dgpuBufferGetMappedRange(buffer: *dgpu.Buffer, offset: usize, size: usize) ?*anyopaque {
        //     return T.bufferGetMappedRange(buffer, offset, size);
        // }

        // // DGPU_EXPORT uint64_t dgpuBufferGetSize(DGPUBuffer buffer);
        // export fn dgpuBufferGetSize(buffer: *dgpu.Buffer) u64 {
        //     return T.bufferGetSize(buffer);
        // }

        // // DGPU_EXPORT DGPUBufferUsage dgpuBufferGetUsage(DGPUBuffer buffer);
        // export fn dgpuBufferGetUsage(buffer: *dgpu.Buffer) dgpu.Buffer.UsageFlags {
        //     return T.bufferGetUsage(buffer);
        // }

        // // DGPU_EXPORT void dgpuBufferSetLabel(DGPUBuffer buffer, char const * label);
        // export fn dgpuBufferSetLabel(buffer: *dgpu.Buffer, label: [:0]const u8) void {
        //     T.bufferSetLabel(buffer, label);
        // }

        // // DGPU_EXPORT void dgpuBufferUnmap(DGPUBuffer buffer);
        // export fn dgpuBufferUnmap(buffer: *dgpu.Buffer) void {
        //     T.bufferUnmap(buffer);
        // }

        // // DGPU_EXPORT void dgpuBufferReference(DGPUBuffer buffer);
        // export fn dgpuBufferReference(buffer: *dgpu.Buffer) void {
        //     T.bufferReference(buffer);
        // }

        // // DGPU_EXPORT void dgpuBufferRelease(DGPUBuffer buffer);
        // export fn dgpuBufferRelease(buffer: *dgpu.Buffer) void {
        //     T.bufferRelease(buffer);
        // }

        // // DGPU_EXPORT void dgpuCommandBufferSetLabel(DGPUCommandBuffer commandBuffer, char const * label);
        // export fn dgpuCommandBufferSetLabel(command_buffer: *dgpu.CommandBuffer, label: [:0]const u8) void {
        //     T.commandBufferSetLabel(command_buffer, label);
        // }

        // // DGPU_EXPORT void dgpuCommandBufferReference(DGPUCommandBuffer commandBuffer);
        // export fn dgpuCommandBufferReference(command_buffer: *dgpu.CommandBuffer) void {
        //     T.commandBufferReference(command_buffer);
        // }

        // // DGPU_EXPORT void dgpuCommandBufferRelease(DGPUCommandBuffer commandBuffer);
        // export fn dgpuCommandBufferRelease(command_buffer: *dgpu.CommandBuffer) void {
        //     T.commandBufferRelease(command_buffer);
        // }

        // // DGPU_EXPORT DGPUComputePassEncoder dgpuCommandEncoderBeginComputePass(DGPUCommandEncoder commandEncoder, DGPUComputePassDescriptor const * descriptor /* nullable */);
        // export fn dgpuCommandEncoderBeginComputePass(command_encoder: *dgpu.CommandEncoder, descriptor: dgpu.ComputePassDescriptor) *dgpu.ComputePassEncoder {
        //     return T.commandEncoderBeginComputePass(command_encoder, descriptor);
        // }

        // // DGPU_EXPORT DGPURenderPassEncoder dgpuCommandEncoderBeginRenderPass(DGPUCommandEncoder commandEncoder, DGPURenderPassDescriptor const * descriptor);
        // export fn dgpuCommandEncoderBeginRenderPass(command_encoder: *dgpu.CommandEncoder, descriptor: dgpu.RenderPassDescriptor) *dgpu.RenderPassEncoder {
        //     return T.commandEncoderBeginRenderPass(command_encoder, descriptor);
        // }

        // // DGPU_EXPORT void dgpuCommandEncoderClearBuffer(DGPUCommandEncoder commandEncoder, DGPUBuffer buffer, uint64_t offset, uint64_t size);
        // export fn dgpuCommandEncoderClearBuffer(command_encoder: *dgpu.CommandEncoder, buffer: *dgpu.Buffer, offset: u64, size: u64) void {
        //     T.commandEncoderClearBuffer(command_encoder, buffer, offset, size);
        // }

        // // DGPU_EXPORT void dgpuCommandEncoderCopyBufferToBuffer(DGPUCommandEncoder commandEncoder, DGPUBuffer source, uint64_t sourceOffset, DGPUBuffer destination, uint64_t destinationOffset, uint64_t size);
        // export fn dgpuCommandEncoderCopyBufferToBuffer(command_encoder: *dgpu.CommandEncoder, source: *dgpu.Buffer, source_offset: u64, destination: *dgpu.Buffer, destination_offset: u64, size: u64) void {
        //     T.commandEncoderCopyBufferToBuffer(command_encoder, source, source_offset, destination, destination_offset, size);
        // }

        // // DGPU_EXPORT void dgpuCommandEncoderCopyBufferToTexture(DGPUCommandEncoder commandEncoder, DGPUImageCopyBuffer const * source, DGPUImageCopyTexture const * destination, DGPUExtent3D const * copySize);
        // export fn dgpuCommandEncoderCopyBufferToTexture(command_encoder: *dgpu.CommandEncoder, source: *const dgpu.ImageCopyBuffer, destination: *const dgpu.ImageCopyTexture, copy_size: *const dgpu.Extent3D) void {
        //     T.commandEncoderCopyBufferToTexture(command_encoder, source, destination, copy_size);
        // }

        // // DGPU_EXPORT void dgpuCommandEncoderCopyTextureToBuffer(DGPUCommandEncoder commandEncoder, DGPUImageCopyTexture const * source, DGPUImageCopyBuffer const * destination, DGPUExtent3D const * copySize);
        // export fn dgpuCommandEncoderCopyTextureToBuffer(command_encoder: *dgpu.CommandEncoder, source: *const dgpu.ImageCopyTexture, destination: *const dgpu.ImageCopyBuffer, copy_size: *const dgpu.Extent3D) void {
        //     T.commandEncoderCopyTextureToBuffer(command_encoder, source, destination, copy_size);
        // }

        // // DGPU_EXPORT void dgpuCommandEncoderCopyTextureToTexture(DGPUCommandEncoder commandEncoder, DGPUImageCopyTexture const * source, DGPUImageCopyTexture const * destination, DGPUExtent3D const * copySize);
        // export fn dgpuCommandEncoderCopyTextureToTexture(command_encoder: *dgpu.CommandEncoder, source: *const dgpu.ImageCopyTexture, destination: *const dgpu.ImageCopyTexture, copy_size: *const dgpu.Extent3D) void {
        //     T.commandEncoderCopyTextureToTexture(command_encoder, source, destination, copy_size);
        // }

        // // DGPU_EXPORT DGPUCommandBuffer dgpuCommandEncoderFinish(DGPUCommandEncoder commandEncoder, DGPUCommandBufferDescriptor const * descriptor /* nullable */);
        // export fn dgpuCommandEncoderFinish(command_encoder: *dgpu.CommandEncoder, descriptor: dgpu.CommandBuffer.Descriptor) *dgpu.CommandBuffer {
        //     return T.commandEncoderFinish(command_encoder, descriptor);
        // }

        // // DGPU_EXPORT void dgpuCommandEncoderInjectValidationError(DGPUCommandEncoder commandEncoder, char const * message);
        // export fn dgpuCommandEncoderInjectValidationError(command_encoder: *dgpu.CommandEncoder, message: [*:0]const u8) void {
        //     T.commandEncoderInjectValidationError(command_encoder, message);
        // }

        // // DGPU_EXPORT void dgpuCommandEncoderInsertDebugMarker(DGPUCommandEncoder commandEncoder, char const * markerLabel);
        // export fn dgpuCommandEncoderInsertDebugMarker(command_encoder: *dgpu.CommandEncoder, marker_label: [*:0]const u8) void {
        //     T.commandEncoderInsertDebugMarker(command_encoder, marker_label);
        // }

        // // DGPU_EXPORT void dgpuCommandEncoderPopDebugGroup(DGPUCommandEncoder commandEncoder);
        // export fn dgpuCommandEncoderPopDebugGroup(command_encoder: *dgpu.CommandEncoder) void {
        //     T.commandEncoderPopDebugGroup(command_encoder);
        // }

        // // DGPU_EXPORT void dgpuCommandEncoderPushDebugGroup(DGPUCommandEncoder commandEncoder, char const * groupLabel);
        // export fn dgpuCommandEncoderPushDebugGroup(command_encoder: *dgpu.CommandEncoder, group_label: [*:0]const u8) void {
        //     T.commandEncoderPushDebugGroup(command_encoder, group_label);
        // }

        // // DGPU_EXPORT void dgpuCommandEncoderResolveQuerySet(DGPUCommandEncoder commandEncoder, DGPUQuerySet querySet, uint32_t firstQuery, uint32_t queryCount, DGPUBuffer destination, uint64_t destinationOffset);
        // export fn dgpuCommandEncoderResolveQuerySet(command_encoder: *dgpu.CommandEncoder, query_set: *dgpu.QuerySet, first_query: u32, query_count: u32, destination: *dgpu.Buffer, destination_offset: u64) void {
        //     T.commandEncoderResolveQuerySet(command_encoder, query_set, first_query, query_count, destination, destination_offset);
        // }

        // // DGPU_EXPORT void dgpuCommandEncoderSetLabel(DGPUCommandEncoder commandEncoder, char const * label);
        // export fn dgpuCommandEncoderSetLabel(command_encoder: *dgpu.CommandEncoder, label: [:0]const u8) void {
        //     T.commandEncoderSetLabel(command_encoder, label);
        // }

        // // DGPU_EXPORT void dgpuCommandEncoderWriteBuffer(DGPUCommandEncoder commandEncoder, DGPUBuffer buffer, uint64_t bufferOffset, uint8_t const * data, uint64_t size);
        // export fn dgpuCommandEncoderWriteBuffer(command_encoder: *dgpu.CommandEncoder, buffer: *dgpu.Buffer, buffer_offset: u64, data: [*]const u8, size: u64) void {
        //     T.commandEncoderWriteBuffer(command_encoder, buffer, buffer_offset, data, size);
        // }

        // // DGPU_EXPORT void dgpuCommandEncoderWriteTimestamp(DGPUCommandEncoder commandEncoder, DGPUQuerySet querySet, uint32_t queryIndex);
        // export fn dgpuCommandEncoderWriteTimestamp(command_encoder: *dgpu.CommandEncoder, query_set: *dgpu.QuerySet, query_index: u32) void {
        //     T.commandEncoderWriteTimestamp(command_encoder, query_set, query_index);
        // }

        // // DGPU_EXPORT void dgpuCommandEncoderReference(DGPUCommandEncoder commandEncoder);
        // export fn dgpuCommandEncoderReference(command_encoder: *dgpu.CommandEncoder) void {
        //     T.commandEncoderReference(command_encoder);
        // }

        // // DGPU_EXPORT void dgpuCommandEncoderRelease(DGPUCommandEncoder commandEncoder);
        // export fn dgpuCommandEncoderRelease(command_encoder: *dgpu.CommandEncoder) void {
        //     T.commandEncoderRelease(command_encoder);
        // }

        // // DGPU_EXPORT void dgpuComputePassEncoderDispatchWorkgroups(DGPUComputePassEncoder computePassEncoder, uint32_t workgroupCountX, uint32_t workgroupCountY, uint32_t workgroupCountZ);
        // export fn dgpuComputePassEncoderDispatchWorkgroups(compute_pass_encoder: *dgpu.ComputePassEncoder, workgroup_count_x: u32, workgroup_count_y: u32, workgroup_count_z: u32) void {
        //     T.computePassEncoderDispatchWorkgroups(compute_pass_encoder, workgroup_count_x, workgroup_count_y, workgroup_count_z);
        // }

        // // DGPU_EXPORT void dgpuComputePassEncoderDispatchWorkgroupsIndirect(DGPUComputePassEncoder computePassEncoder, DGPUBuffer indirectBuffer, uint64_t indirectOffset);
        // export fn dgpuComputePassEncoderDispatchWorkgroupsIndirect(compute_pass_encoder: *dgpu.ComputePassEncoder, indirect_buffer: *dgpu.Buffer, indirect_offset: u64) void {
        //     T.computePassEncoderDispatchWorkgroupsIndirect(compute_pass_encoder, indirect_buffer, indirect_offset);
        // }

        // // DGPU_EXPORT void dgpuComputePassEncoderEnd(DGPUComputePassEncoder computePassEncoder);
        // export fn dgpuComputePassEncoderEnd(compute_pass_encoder: *dgpu.ComputePassEncoder) void {
        //     T.computePassEncoderEnd(compute_pass_encoder);
        // }

        // // DGPU_EXPORT void dgpuComputePassEncoderInsertDebugMarker(DGPUComputePassEncoder computePassEncoder, char const * markerLabel);
        // export fn dgpuComputePassEncoderInsertDebugMarker(compute_pass_encoder: *dgpu.ComputePassEncoder, marker_label: [*:0]const u8) void {
        //     T.computePassEncoderInsertDebugMarker(compute_pass_encoder, marker_label);
        // }

        // // DGPU_EXPORT void dgpuComputePassEncoderPopDebugGroup(DGPUComputePassEncoder computePassEncoder);
        // export fn dgpuComputePassEncoderPopDebugGroup(compute_pass_encoder: *dgpu.ComputePassEncoder) void {
        //     T.computePassEncoderPopDebugGroup(compute_pass_encoder);
        // }

        // // DGPU_EXPORT void dgpuComputePassEncoderPushDebugGroup(DGPUComputePassEncoder computePassEncoder, char const * groupLabel);
        // export fn dgpuComputePassEncoderPushDebugGroup(compute_pass_encoder: *dgpu.ComputePassEncoder, group_label: [*:0]const u8) void {
        //     T.computePassEncoderPushDebugGroup(compute_pass_encoder, group_label);
        // }

        // // DGPU_EXPORT void dgpuComputePassEncoderSetBindGroup(DGPUComputePassEncoder computePassEncoder, uint32_t groupIndex, DGPUBindGroup group, size_t dynamicOffsetCount, uint32_t const * dynamicOffsets);
        // export fn dgpuComputePassEncoderSetBindGroup(compute_pass_encoder: *dgpu.ComputePassEncoder, group_index: u32, group: *dgpu.BindGroup, dynamic_offset_count: usize, dynamic_offsets: ?[*]const u32) void {
        //     T.computePassEncoderSetBindGroup(compute_pass_encoder, group_index, group, dynamic_offset_count, dynamic_offsets);
        // }

        // // DGPU_EXPORT void dgpuComputePassEncoderSetLabel(DGPUComputePassEncoder computePassEncoder, char const * label);
        // export fn dgpuComputePassEncoderSetLabel(compute_pass_encoder: *dgpu.ComputePassEncoder, label: [:0]const u8) void {
        //     T.computePassEncoderSetLabel(compute_pass_encoder, label);
        // }

        // // DGPU_EXPORT void dgpuComputePassEncoderSetPipeline(DGPUComputePassEncoder computePassEncoder, DGPUComputePipeline pipeline);
        // export fn dgpuComputePassEncoderSetPipeline(compute_pass_encoder: *dgpu.ComputePassEncoder, pipeline: *dgpu.ComputePipeline) void {
        //     T.computePassEncoderSetPipeline(compute_pass_encoder, pipeline);
        // }

        // // DGPU_EXPORT void dgpuComputePassEncoderWriteTimestamp(DGPUComputePassEncoder computePassEncoder, DGPUQuerySet querySet, uint32_t queryIndex);
        // export fn dgpuComputePassEncoderWriteTimestamp(compute_pass_encoder: *dgpu.ComputePassEncoder, query_set: *dgpu.QuerySet, query_index: u32) void {
        //     T.computePassEncoderWriteTimestamp(compute_pass_encoder, query_set, query_index);
        // }

        // // DGPU_EXPORT void dgpuComputePassEncoderReference(DGPUComputePassEncoder computePassEncoder);
        // export fn dgpuComputePassEncoderReference(compute_pass_encoder: *dgpu.ComputePassEncoder) void {
        //     T.computePassEncoderReference(compute_pass_encoder);
        // }

        // // DGPU_EXPORT void dgpuComputePassEncoderRelease(DGPUComputePassEncoder computePassEncoder);
        // export fn dgpuComputePassEncoderRelease(compute_pass_encoder: *dgpu.ComputePassEncoder) void {
        //     T.computePassEncoderRelease(compute_pass_encoder);
        // }

        // // DGPU_EXPORT DGPUBindGroupLayout dgpuComputePipelineGetBindGroupLayout(DGPUComputePipeline computePipeline, uint32_t groupIndex);
        // export fn dgpuComputePipelineGetBindGroupLayout(compute_pipeline: *dgpu.ComputePipeline, group_index: u32) *dgpu.BindGroupLayout {
        //     return T.computePipelineGetBindGroupLayout(compute_pipeline, group_index);
        // }

        // // DGPU_EXPORT void dgpuComputePipelineSetLabel(DGPUComputePipeline computePipeline, char const * label);
        // export fn dgpuComputePipelineSetLabel(compute_pipeline: *dgpu.ComputePipeline, label: [:0]const u8) void {
        //     T.computePipelineSetLabel(compute_pipeline, label);
        // }

        // // DGPU_EXPORT void dgpuComputePipelineReference(DGPUComputePipeline computePipeline);
        // export fn dgpuComputePipelineReference(compute_pipeline: *dgpu.ComputePipeline) void {
        //     T.computePipelineReference(compute_pipeline);
        // }

        // // DGPU_EXPORT void dgpuComputePipelineRelease(DGPUComputePipeline computePipeline);
        // export fn dgpuComputePipelineRelease(compute_pipeline: *dgpu.ComputePipeline) void {
        //     T.computePipelineRelease(compute_pipeline);
        // }

        // // DGPU_EXPORT DGPUBindGroup dgpuDeviceCreateBindGroup(DGPUDevice device, DGPUBindGroupDescriptor const * descriptor);
        // export fn dgpuDeviceCreateBindGroup(device: *dgpu.Device, descriptor: dgpu.BindGroup.Descriptor) *dgpu.BindGroup {
        //     return T.deviceCreateBindGroup(device, descriptor);
        // }

        // // DGPU_EXPORT DGPUBindGroupLayout dgpuDeviceCreateBindGroupLayout(DGPUDevice device, DGPUBindGroupLayout.Descriptor const * descriptor);
        // export fn dgpuDeviceCreateBindGroupLayout(device: *dgpu.Device, descriptor: dgpu.BindGroupLayout.Descriptor) *dgpu.BindGroupLayout {
        //     return T.deviceCreateBindGroupLayout(device, descriptor);
        // }

        // // DGPU_EXPORT DGPUBuffer dgpuDeviceCreateBuffer(DGPUDevice device, DGPUBuffer.Descriptor const * descriptor);
        // export fn dgpuDeviceCreateBuffer(device: *dgpu.Device, descriptor: dgpu.Buffer.Descriptor) *dgpu.Buffer {
        //     return T.deviceCreateBuffer(device, descriptor);
        // }

        // // DGPU_EXPORT DGPUCommandEncoder dgpuDeviceCreateCommandEncoder(DGPUDevice device, DGPUCommandEncoderDescriptor const * descriptor /* nullable */);
        // export fn dgpuDeviceCreateCommandEncoder(device: *dgpu.Device, descriptor: dgpu.CommandEncoder.Descriptor) *dgpu.CommandEncoder {
        //     return T.deviceCreateCommandEncoder(device, descriptor);
        // }

        // // DGPU_EXPORT DGPUComputePipeline dgpuDeviceCreateComputePipeline(DGPUDevice device, DGPUComputePipelineDescriptor const * descriptor);
        // export fn dgpuDeviceCreateComputePipeline(device: *dgpu.Device, descriptor: dgpu.ComputePipeline.Descriptor) *dgpu.ComputePipeline {
        //     return T.deviceCreateComputePipeline(device, descriptor);
        // }

        // // DGPU_EXPORT DGPUBuffer dgpuDeviceCreateErrorBuffer(DGPUDevice device, DGPUBufferDescriptor const * descriptor);
        // export fn dgpuDeviceCreateErrorBuffer(device: *dgpu.Device, descriptor: dgpu.Buffer.Descriptor) *dgpu.Buffer {
        //     return T.deviceCreateErrorBuffer(device, descriptor);
        // }

        // // DGPU_EXPORT DGPUExternalTexture dgpuDeviceCreateErrorExternalTexture(DGPUDevice device);
        // export fn dgpuDeviceCreateErrorExternalTexture(device: *dgpu.Device) *dgpu.ExternalTexture {
        //     return T.deviceCreateErrorExternalTexture(device);
        // }

        // // DGPU_EXPORT DGPUTexture dgpuDeviceCreateErrorTexture(DGPUDevice device, DGPUTextureDescriptor const * descriptor);
        // export fn dgpuDeviceCreateErrorTexture(device: *dgpu.Device, descriptor: dgpu.Texture.Descriptor) *dgpu.Texture {
        //     return T.deviceCreateErrorTexture(device, descriptor);
        // }

        // // DGPU_EXPORT DGPUExternalTexture dgpuDeviceCreateExternalTexture(DGPUDevice device, DGPUExternalTextureDescriptor const * externalTextureDescriptor);
        // export fn dgpuDeviceCreateExternalTexture(device: *dgpu.Device, descriptor: dgpu.ExternalTexture.Descriptor) *dgpu.ExternalTexture {
        //     return T.deviceCreateExternalTexture(device, external_texture_descriptor);
        // }

        // // DGPU_EXPORT DGPUPipelineLayout dgpuDeviceCreatePipelineLayout(DGPUDevice device, DGPUPipelineLayoutDescriptor const * descriptor);
        // export fn dgpuDeviceCreatePipelineLayout(device: *dgpu.Device, descriptor: dgpu.PipelineLayout.Descriptor) *dgpu.PipelineLayout {
        //     return T.deviceCreatePipelineLayout(device, pipeline_layout_descriptor);
        // }

        // // DGPU_EXPORT DGPUQuerySet dgpuDeviceCreateQuerySet(DGPUDevice device, DGPUQuerySetDescriptor const * descriptor);
        // export fn dgpuDeviceCreateQuerySet(device: *dgpu.Device, descriptor: dgpu.QuerySet.Descriptor) *dgpu.QuerySet {
        //     return T.deviceCreateQuerySet(device, descriptor);
        // }

        // // DGPU_EXPORT DGPURenderBundleEncoder dgpuDeviceCreateRenderBundleEncoder(DGPUDevice device, DGPURenderBundleEncoderDescriptor const * descriptor);
        // export fn dgpuDeviceCreateRenderBundleEncoder(device: *dgpu.Device, descriptor: dgpu.RenderBundleEncoder.Descriptor) *dgpu.RenderBundleEncoder {
        //     return T.deviceCreateRenderBundleEncoder(device, descriptor);
        // }

        // // DGPU_EXPORT DGPURenderPipeline dgpuDeviceCreateRenderPipeline(DGPUDevice device, DGPURenderPipelineDescriptor const * descriptor);
        // export fn dgpuDeviceCreateRenderPipeline(device: *dgpu.Device, descriptor: dgpu.RenderPipeline.Descriptor) *dgpu.RenderPipeline {
        //     return T.deviceCreateRenderPipeline(device, descriptor);
        // }

        // // DGPU_EXPORT DGPUSampler dgpuDeviceCreateSampler(DGPUDevice device, DGPUSamplerDescriptor const * descriptor /* nullable */);
        // export fn dgpuDeviceCreateSampler(device: *dgpu.Device, descriptor: dgpu.Sampler.Descriptor) *dgpu.Sampler {
        //     return T.deviceCreateSampler(device, descriptor);
        // }

        // // DGPU_EXPORT DGPUShaderModule dgpuDeviceCreateShaderModule(DGPUDevice device, DGPUShaderModuleDescriptor const * descriptor);
        // export fn dgpuDeviceCreateShaderModule(device: *dgpu.Device, descriptor: dgpu.ShaderModule.Descriptor) *dgpu.ShaderModule {
        //     return T.deviceCreateShaderModule(device, descriptor);
        // }

        // // DGPU_EXPORT DGPUSwapChain dgpuDeviceCreateSwapChain(DGPUDevice device, DGPUSurface surface /* nullable */, DGPUSwapChainDescriptor const * descriptor);
        // export fn dgpuDeviceCreateSwapChain(device: *dgpu.Device, surface: ?*dgpu.Surface, descriptor: dgpu.SwapChain.Descriptor) *dgpu.SwapChain {
        //     return T.deviceCreateSwapChain(device, surface, descriptor);
        // }

        // // DGPU_EXPORT DGPUTexture dgpuDeviceCreateTexture(DGPUDevice device, DGPUTextureDescriptor const * descriptor);
        // export fn dgpuDeviceCreateTexture(device: *dgpu.Device, descriptor: dgpu.Texture.Descriptor) *dgpu.Texture {
        //     return T.deviceCreateTexture(device, descriptor);
        // }

        // // DGPU_EXPORT void dgpuDeviceDestroy(DGPUDevice device);
        // export fn dgpuDeviceDestroy(device: *dgpu.Device) void {
        //     T.deviceDestroy(device);
        // }

        // // DGPU_EXPORT size_t dgpuDeviceEnumerateFeatures(DGPUDevice device, DGPUFeatureName * features);
        // export fn dgpuDeviceEnumerateFeatures(device: *dgpu.Device, features: ?[*]dgpu.FeatureName) usize {
        //     return T.deviceEnumerateFeatures(device, features);
        // }

        // // DGPU_EXPORT DGPUBool dgpuDeviceGetLimits(DGPUDevice device, DGPUSupportedLimits * limits);
        // export fn dgpuDeviceGetLimits(device: *dgpu.Device, limits: *dgpu.Limits) u32 {
        //     return T.deviceGetLimits(device, limits);
        // }

        // // DGPU_EXPORT DGPUSharedFence dgpuDeviceImportSharedFence(DGPUDevice device, DGPUSharedFenceDescriptor const * descriptor);
        // export fn dgpuDeviceImportSharedFence(device: *dgpu.Device, descriptor: dgpu.SharedFence.Descriptor) *dgpu.SharedFence {
        //     return T.deviceImportSharedFence(device, descriptor);
        // }

        // // DGPU_EXPORT DGPUSharedTextureMemory dgpuDeviceImportSharedTextureMemory(DGPUDevice device, DGPUSharedTextureMemoryDescriptor const * descriptor);
        // export fn dgpuDeviceImportSharedTextureMemory(device: *dgpu.Device, descriptor: dgpu.SharedTextureMemory.Descriptor) *dgpu.SharedTextureMemory {
        //     return T.deviceImportSharedTextureMemory(device, descriptor);
        // }

        // // DGPU_EXPORT DGPUQueue dgpuDeviceGetQueue(DGPUDevice device);
        // export fn dgpuDeviceGetQueue(device: *dgpu.Device) *dgpu.Queue {
        //     return T.deviceGetQueue(device);
        // }

        // // DGPU_EXPORT bool dgpuDeviceHasFeature(DGPUDevice device, DGPUFeatureName feature);
        // export fn dgpuDeviceHasFeature(device: *dgpu.Device, feature: dgpu.FeatureName) u32 {
        //     return T.deviceHasFeature(device, feature);
        // }

        // // DGPU_EXPORT void dgpuDeviceInjectError(DGPUDevice device, DGPUErrorType type, char const * message);
        // export fn dgpuDeviceInjectError(device: *dgpu.Device, typ: dgpu.ErrorType, message: [*:0]const u8) void {
        //     T.deviceInjectError(device, typ, message);
        // }

        // // DGPU_EXPORT void dgpuDevicePopErrorScope(DGPUDevice device, DGPUErrorCallback callback, void * userdata);
        // export fn dgpuDevicePopErrorScope(device: *dgpu.Device, callback: dgpu.ErrorCallback, userdata: ?*anyopaque) void {
        //     T.devicePopErrorScope(device, callback, userdata);
        // }

        // // DGPU_EXPORT void dgpuDevicePushErrorScope(DGPUDevice device, DGPUErrorFilter filter);
        // export fn dgpuDevicePushErrorScope(device: *dgpu.Device, filter: dgpu.ErrorFilter) void {
        //     T.devicePushErrorScope(device, filter);
        // }

        // // TODO: dawn: callback not marked as nullable in dawn.json but in fact is.
        // // DGPU_EXPORT void dgpuDeviceSetDeviceLostCallback(DGPUDevice device, DGPUDeviceLostCallback callback, void * userdata);
        // export fn dgpuDeviceSetDeviceLostCallback(device: *dgpu.Device, callback: ?dgpu.Device.LostCallback, userdata: ?*anyopaque) void {
        //     T.deviceSetDeviceLostCallback(device, callback, userdata);
        // }

        // // DGPU_EXPORT void dgpuDeviceSetLabel(DGPUDevice device, char const * label);
        // export fn dgpuDeviceSetLabel(device: *dgpu.Device, label: [:0]const u8) void {
        //     T.deviceSetLabel(device, label);
        // }

        // // TODO: dawn: callback not marked as nullable in dawn.json but in fact is.
        // // DGPU_EXPORT void dgpuDeviceSetLoggingCallback(DGPUDevice device, DGPULoggingCallback callback, void * userdata);
        // export fn dgpuDeviceSetLoggingCallback(device: *dgpu.Device, callback: ?dgpu.LoggingCallback, userdata: ?*anyopaque) void {
        //     T.deviceSetLoggingCallback(device, callback, userdata);
        // }

        // // TODO: dawn: callback not marked as nullable in dawn.json but in fact is.
        // // DGPU_EXPORT void dgpuDeviceSetUncapturedErrorCallback(DGPUDevice device, DGPUErrorCallback callback, void * userdata);
        // export fn dgpuDeviceSetUncapturedErrorCallback(device: *dgpu.Device, callback: ?dgpu.ErrorCallback, userdata: ?*anyopaque) void {
        //     T.deviceSetUncapturedErrorCallback(device, callback, userdata);
        // }

        // // DGPU_EXPORT void dgpuDeviceTick(DGPUDevice device);
        // export fn dgpuDeviceTick(device: *dgpu.Device) void {
        //     T.deviceTick(device);
        // }

        // // DGPU_EXPORT void dgpuMachDeviceWaitForCommandsToBeScheduled(DGPUDevice device);
        // export fn dgpuMachDeviceWaitForCommandsToBeScheduled(device: *dgpu.Device) void {
        //     T.machDeviceWaitForCommandsToBeScheduled(device);
        // }

        // // DGPU_EXPORT void dgpuDeviceReference(DGPUDevice device);
        // export fn dgpuDeviceReference(device: *dgpu.Device) void {
        //     T.deviceReference(device);
        // }

        // // DGPU_EXPORT void dgpuDeviceRelease(DGPUDevice device);
        // export fn dgpuDeviceRelease(device: *dgpu.Device) void {
        //     T.deviceRelease(device);
        // }

        // // DGPU_EXPORT void dgpuExternalTextureDestroy(DGPUExternalTexture externalTexture);
        // export fn dgpuExternalTextureDestroy(external_texture: *dgpu.ExternalTexture) void {
        //     T.externalTextureDestroy(external_texture);
        // }

        // // DGPU_EXPORT void dgpuExternalTextureSetLabel(DGPUExternalTexture externalTexture, char const * label);
        // export fn dgpuExternalTextureSetLabel(external_texture: *dgpu.ExternalTexture, label: [:0]const u8) void {
        //     T.externalTextureSetLabel(external_texture, label);
        // }

        // // DGPU_EXPORT void dgpuExternalTextureReference(DGPUExternalTexture externalTexture);
        // export fn dgpuExternalTextureReference(external_texture: *dgpu.ExternalTexture) void {
        //     T.externalTextureReference(external_texture);
        // }

        // // DGPU_EXPORT void dgpuExternalTextureRelease(DGPUExternalTexture externalTexture);
        // export fn dgpuExternalTextureRelease(external_texture: *dgpu.ExternalTexture) void {
        //     T.externalTextureRelease(external_texture);
        // }

        // // DGPU_EXPORT DGPUSurface dgpuInstanceCreateSurface(DGPUInstance instance, DGPUSurfaceDescriptor const * descriptor);
        // export fn dgpuInstanceCreateSurface(instance: *dgpu.Instance, descriptor: dgpu.Surface.Descriptor) *dgpu.Surface {
        //     return T.instanceCreateSurface(instance, descriptor);
        // }

        // // DGPU_EXPORT void instanceProcessEvents(DGPUInstance instance);
        // export fn dgpuInstanceProcessEvents(instance: *dgpu.Instance) void {
        //     T.instanceProcessEvents(instance);
        // }

        // // DGPU_EXPORT DGPUAdapter dgpuInstanceCreateAdapter(DGPUInstance instance, DGPUAdapterDescriptor const * descriptor);
        // export fn dgpuInstanceCreateAdapter(instance: *dgpu.Instance, descriptor: dgpu.Adapter.Descriptor) *dgpu.Adapter {
        //     T.instanceCreateAdapter(instance, descriptor);
        // }

        // // DGPU_EXPORT void dgpuInstanceReference(DGPUInstance instance);
        // export fn dgpuInstanceReference(instance: *dgpu.Instance) void {
        //     T.instanceReference(instance);
        // }

        // // DGPU_EXPORT void dgpuInstanceRelease(DGPUInstance instance);
        // export fn dgpuInstanceRelease(instance: *dgpu.Instance) void {
        //     T.instanceRelease(instance);
        // }

        // // DGPU_EXPORT void dgpuPipelineLayoutSetLabel(DGPUPipelineLayout pipelineLayout, char const * label);
        // export fn dgpuPipelineLayoutSetLabel(pipeline_layout: *dgpu.PipelineLayout, label: [:0]const u8) void {
        //     T.pipelineLayoutSetLabel(pipeline_layout, label);
        // }

        // // DGPU_EXPORT void dgpuPipelineLayoutReference(DGPUPipelineLayout pipelineLayout);
        // export fn dgpuPipelineLayoutReference(pipeline_layout: *dgpu.PipelineLayout) void {
        //     T.pipelineLayoutReference(pipeline_layout);
        // }

        // // DGPU_EXPORT void dgpuPipelineLayoutRelease(DGPUPipelineLayout pipelineLayout);
        // export fn dgpuPipelineLayoutRelease(pipeline_layout: *dgpu.PipelineLayout) void {
        //     T.pipelineLayoutRelease(pipeline_layout);
        // }

        // // DGPU_EXPORT void dgpuQuerySetDestroy(DGPUQuerySet querySet);
        // export fn dgpuQuerySetDestroy(query_set: *dgpu.QuerySet) void {
        //     T.querySetDestroy(query_set);
        // }

        // // DGPU_EXPORT uint32_t dgpuQuerySetGetCount(DGPUQuerySet querySet);
        // export fn dgpuQuerySetGetCount(query_set: *dgpu.QuerySet) u32 {
        //     return T.querySetGetCount(query_set);
        // }

        // // DGPU_EXPORT DGPUQueryType dgpuQuerySetGetType(DGPUQuerySet querySet);
        // export fn dgpuQuerySetGetType(query_set: *dgpu.QuerySet) dgpu.QueryType {
        //     return T.querySetGetType(query_set);
        // }

        // // DGPU_EXPORT void dgpuQuerySetSetLabel(DGPUQuerySet querySet, char const * label);
        // export fn dgpuQuerySetSetLabel(query_set: *dgpu.QuerySet, label: [:0]const u8) void {
        //     T.querySetSetLabel(query_set, label);
        // }

        // // DGPU_EXPORT void dgpuQuerySetReference(DGPUQuerySet querySet);
        // export fn dgpuQuerySetReference(query_set: *dgpu.QuerySet) void {
        //     T.querySetReference(query_set);
        // }

        // // DGPU_EXPORT void dgpuQuerySetRelease(DGPUQuerySet querySet);
        // export fn dgpuQuerySetRelease(query_set: *dgpu.QuerySet) void {
        //     T.querySetRelease(query_set);
        // }

        // // DGPU_EXPORT void dgpuQueueCopyTextureForBrowser(DGPUQueue queue, DGPUImageCopyTexture const * source, DGPUImageCopyTexture const * destination, DGPUExtent3D const * copySize, DGPUCopyTextureForBrowserOptions const * options);
        // export fn dgpuQueueCopyTextureForBrowser(queue: *dgpu.Queue, source: *const dgpu.ImageCopyTexture, destination: *const dgpu.ImageCopyTexture, copy_size: *const dgpu.Extent3D, options: *const dgpu.CopyTextureForBrowserOptions) void {
        //     T.queueCopyTextureForBrowser(queue, source, destination, copy_size, options);
        // }

        // // DGPU_EXPORT void dgpuQueueOnSubmittedWorkDone(DGPUQueue queue, uint64_t signalValue, DGPUQueueWorkDoneCallback callback, void * userdata);
        // export fn dgpuQueueOnSubmittedWorkDone(queue: *dgpu.Queue, signal_value: u64, callback: dgpu.Queue.WorkDoneCallback, userdata: ?*anyopaque) void {
        //     T.queueOnSubmittedWorkDone(queue, signal_value, callback, userdata);
        // }

        // // DGPU_EXPORT void dgpuQueueSetLabel(DGPUQueue queue, char const * label);
        // export fn dgpuQueueSetLabel(queue: *dgpu.Queue, label: [:0]const u8) void {
        //     T.queueSetLabel(queue, label);
        // }

        // // DGPU_EXPORT void dgpuQueueSubmit(DGPUQueue queue, size_t commandCount, DGPUCommandBuffer const * commands);
        // export fn dgpuQueueSubmit(queue: *dgpu.Queue, command_count: usize, commands: [*]const *const dgpu.CommandBuffer) void {
        //     T.queueSubmit(queue, command_count, commands);
        // }

        // // DGPU_EXPORT void dgpuQueueWriteBuffer(DGPUQueue queue, DGPUBuffer buffer, uint64_t bufferOffset, void const * data, size_t size);
        // export fn dgpuQueueWriteBuffer(queue: *dgpu.Queue, buffer: *dgpu.Buffer, buffer_offset: u64, data: *const anyopaque, size: usize) void {
        //     T.queueWriteBuffer(queue, buffer, buffer_offset, data, size);
        // }

        // // DGPU_EXPORT void dgpuQueueWriteTexture(DGPUQueue queue, DGPUImageCopyTexture const * destination, void const * data, size_t dataSize, DGPUTextureDataLayout const * dataLayout, DGPUExtent3D const * writeSize);
        // export fn dgpuQueueWriteTexture(queue: *dgpu.Queue, destination: *const dgpu.ImageCopyTexture, data: *const anyopaque, data_size: usize, data_layout: *const dgpu.Texture.DataLayout, write_size: *const dgpu.Extent3D) void {
        //     T.queueWriteTexture(queue, destination, data, data_size, data_layout, write_size);
        // }

        // // DGPU_EXPORT void dgpuQueueReference(DGPUQueue queue);
        // export fn dgpuQueueReference(queue: *dgpu.Queue) void {
        //     T.queueReference(queue);
        // }

        // // DGPU_EXPORT void dgpuQueueRelease(DGPUQueue queue);
        // export fn dgpuQueueRelease(queue: *dgpu.Queue) void {
        //     T.queueRelease(queue);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleSetLabel(DGPURenderBundle renderBundle, char const * label);
        // export fn dgpuRenderBundleSetLabel(render_bundle: *dgpu.RenderBundle, label: [:0]const u8) void {
        //     T.renderBundleSetLabel(render_bundle, label);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleReference(DGPURenderBundle renderBundle);
        // export fn dgpuRenderBundleReference(render_bundle: *dgpu.RenderBundle) void {
        //     T.renderBundleReference(render_bundle);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleRelease(DGPURenderBundle renderBundle);
        // export fn dgpuRenderBundleRelease(render_bundle: *dgpu.RenderBundle) void {
        //     T.renderBundleRelease(render_bundle);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleEncoderDraw(DGPURenderBundleEncoder renderBundleEncoder, uint32_t vertexCount, uint32_t instanceCount, uint32_t firstVertex, uint32_t firstInstance);
        // export fn dgpuRenderBundleEncoderDraw(render_bundle_encoder: *dgpu.RenderBundleEncoder, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void {
        //     T.renderBundleEncoderDraw(render_bundle_encoder, vertex_count, instance_count, first_vertex, first_instance);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleEncoderDrawIndexed(DGPURenderBundleEncoder renderBundleEncoder, uint32_t indexCount, uint32_t instanceCount, uint32_t firstIndex, int32_t baseVertex, uint32_t firstInstance);
        // export fn dgpuRenderBundleEncoderDrawIndexed(render_bundle_encoder: *dgpu.RenderBundleEncoder, index_count: u32, instance_count: u32, first_index: u32, base_vertex: i32, first_instance: u32) void {
        //     T.renderBundleEncoderDrawIndexed(render_bundle_encoder, index_count, instance_count, first_index, base_vertex, first_instance);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleEncoderDrawIndexedIndirect(DGPURenderBundleEncoder renderBundleEncoder, DGPUBuffer indirectBuffer, uint64_t indirectOffset);
        // export fn dgpuRenderBundleEncoderDrawIndexedIndirect(render_bundle_encoder: *dgpu.RenderBundleEncoder, indirect_buffer: *dgpu.Buffer, indirect_offset: u64) void {
        //     T.renderBundleEncoderDrawIndexedIndirect(render_bundle_encoder, indirect_buffer, indirect_offset);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleEncoderDrawIndirect(DGPURenderBundleEncoder renderBundleEncoder, DGPUBuffer indirectBuffer, uint64_t indirectOffset);
        // export fn dgpuRenderBundleEncoderDrawIndirect(render_bundle_encoder: *dgpu.RenderBundleEncoder, indirect_buffer: *dgpu.Buffer, indirect_offset: u64) void {
        //     T.renderBundleEncoderDrawIndirect(render_bundle_encoder, indirect_buffer, indirect_offset);
        // }

        // // DGPU_EXPORT DGPURenderBundle dgpuRenderBundleEncoderFinish(DGPURenderBundleEncoder renderBundleEncoder, DGPURenderBundleDescriptor const * descriptor /* nullable */);
        // export fn dgpuRenderBundleEncoderFinish(render_bundle_encoder: *dgpu.RenderBundleEncoder, descriptor: dgpu.RenderBundle.Descriptor) *dgpu.RenderBundle {
        //     return T.renderBundleEncoderFinish(render_bundle_encoder, descriptor);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleEncoderInsertDebugMarker(DGPURenderBundleEncoder renderBundleEncoder, char const * markerLabel);
        // export fn dgpuRenderBundleEncoderInsertDebugMarker(render_bundle_encoder: *dgpu.RenderBundleEncoder, marker_label: [*:0]const u8) void {
        //     T.renderBundleEncoderInsertDebugMarker(render_bundle_encoder, marker_label);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleEncoderPopDebugGroup(DGPURenderBundleEncoder renderBundleEncoder);
        // export fn dgpuRenderBundleEncoderPopDebugGroup(render_bundle_encoder: *dgpu.RenderBundleEncoder) void {
        //     T.renderBundleEncoderPopDebugGroup(render_bundle_encoder);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleEncoderPushDebugGroup(DGPURenderBundleEncoder renderBundleEncoder, char const * groupLabel);
        // export fn dgpuRenderBundleEncoderPushDebugGroup(render_bundle_encoder: *dgpu.RenderBundleEncoder, group_label: [*:0]const u8) void {
        //     T.renderBundleEncoderPushDebugGroup(render_bundle_encoder, group_label);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleEncoderSetBindGroup(DGPURenderBundleEncoder renderBundleEncoder, uint32_t groupIndex, DGPUBindGroup group, size_t dynamicOffsetCount, uint32_t const * dynamicOffsets);
        // export fn dgpuRenderBundleEncoderSetBindGroup(render_bundle_encoder: *dgpu.RenderBundleEncoder, group_index: u32, group: *dgpu.BindGroup, dynamic_offset_count: usize, dynamic_offsets: ?[*]const u32) void {
        //     T.renderBundleEncoderSetBindGroup(render_bundle_encoder, group_index, group, dynamic_offset_count, dynamic_offsets);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleEncoderSetIndexBuffer(DGPURenderBundleEncoder renderBundleEncoder, DGPUBuffer buffer, DGPUIndexFormat format, uint64_t offset, uint64_t size);
        // export fn dgpuRenderBundleEncoderSetIndexBuffer(render_bundle_encoder: *dgpu.RenderBundleEncoder, buffer: *dgpu.Buffer, format: dgpu.IndexFormat, offset: u64, size: u64) void {
        //     T.renderBundleEncoderSetIndexBuffer(render_bundle_encoder, buffer, format, offset, size);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleEncoderSetLabel(DGPURenderBundleEncoder renderBundleEncoder, char const * label);
        // export fn dgpuRenderBundleEncoderSetLabel(render_bundle_encoder: *dgpu.RenderBundleEncoder, label: [:0]const u8) void {
        //     T.renderBundleEncoderSetLabel(render_bundle_encoder, label);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleEncoderSetPipeline(DGPURenderBundleEncoder renderBundleEncoder, DGPURenderPipeline pipeline);
        // export fn dgpuRenderBundleEncoderSetPipeline(render_bundle_encoder: *dgpu.RenderBundleEncoder, pipeline: *dgpu.RenderPipeline) void {
        //     T.renderBundleEncoderSetPipeline(render_bundle_encoder, pipeline);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleEncoderSetVertexBuffer(DGPURenderBundleEncoder renderBundleEncoder, uint32_t slot, DGPUBuffer buffer, uint64_t offset, uint64_t size);
        // export fn dgpuRenderBundleEncoderSetVertexBuffer(render_bundle_encoder: *dgpu.RenderBundleEncoder, slot: u32, buffer: *dgpu.Buffer, offset: u64, size: u64) void {
        //     T.renderBundleEncoderSetVertexBuffer(render_bundle_encoder, slot, buffer, offset, size);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleEncoderReference(DGPURenderBundleEncoder renderBundleEncoder);
        // export fn dgpuRenderBundleEncoderReference(render_bundle_encoder: *dgpu.RenderBundleEncoder) void {
        //     T.renderBundleEncoderReference(render_bundle_encoder);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleEncoderRelease(DGPURenderBundleEncoder renderBundleEncoder);
        // export fn dgpuRenderBundleEncoderRelease(render_bundle_encoder: *dgpu.RenderBundleEncoder) void {
        //     T.renderBundleEncoderRelease(render_bundle_encoder);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderBeginOcclusionQuery(DGPURenderPassEncoder renderPassEncoder, uint32_t queryIndex);
        // export fn dgpuRenderPassEncoderBeginOcclusionQuery(render_pass_encoder: *dgpu.RenderPassEncoder, query_index: u32) void {
        //     T.renderPassEncoderBeginOcclusionQuery(render_pass_encoder, query_index);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderDraw(DGPURenderPassEncoder renderPassEncoder, uint32_t vertexCount, uint32_t instanceCount, uint32_t firstVertex, uint32_t firstInstance);
        // export fn dgpuRenderPassEncoderDraw(render_pass_encoder: *dgpu.RenderPassEncoder, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void {
        //     T.renderPassEncoderDraw(render_pass_encoder, vertex_count, instance_count, first_vertex, first_instance);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderDrawIndexed(DGPURenderPassEncoder renderPassEncoder, uint32_t indexCount, uint32_t instanceCount, uint32_t firstIndex, int32_t baseVertex, uint32_t firstInstance);
        // export fn dgpuRenderPassEncoderDrawIndexed(render_pass_encoder: *dgpu.RenderPassEncoder, index_count: u32, instance_count: u32, first_index: u32, base_vertex: i32, first_instance: u32) void {
        //     T.renderPassEncoderDrawIndexed(render_pass_encoder, index_count, instance_count, first_index, base_vertex, first_instance);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderDrawIndexedIndirect(DGPURenderPassEncoder renderPassEncoder, DGPUBuffer indirectBuffer, uint64_t indirectOffset);
        // export fn dgpuRenderPassEncoderDrawIndexedIndirect(render_pass_encoder: *dgpu.RenderPassEncoder, indirect_buffer: *dgpu.Buffer, indirect_offset: u64) void {
        //     T.renderPassEncoderDrawIndexedIndirect(render_pass_encoder, indirect_buffer, indirect_offset);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderDrawIndirect(DGPURenderPassEncoder renderPassEncoder, DGPUBuffer indirectBuffer, uint64_t indirectOffset);
        // export fn dgpuRenderPassEncoderDrawIndirect(render_pass_encoder: *dgpu.RenderPassEncoder, indirect_buffer: *dgpu.Buffer, indirect_offset: u64) void {
        //     T.renderPassEncoderDrawIndirect(render_pass_encoder, indirect_buffer, indirect_offset);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderEnd(DGPURenderPassEncoder renderPassEncoder);
        // export fn dgpuRenderPassEncoderEnd(render_pass_encoder: *dgpu.RenderPassEncoder) void {
        //     T.renderPassEncoderEnd(render_pass_encoder);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderEndOcclusionQuery(DGPURenderPassEncoder renderPassEncoder);
        // export fn dgpuRenderPassEncoderEndOcclusionQuery(render_pass_encoder: *dgpu.RenderPassEncoder) void {
        //     T.renderPassEncoderEndOcclusionQuery(render_pass_encoder);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderExecuteBundles(DGPURenderPassEncoder renderPassEncoder, size_t bundleCount, DGPURenderBundle const * bundles);
        // export fn dgpuRenderPassEncoderExecuteBundles(render_pass_encoder: *dgpu.RenderPassEncoder, bundles_count: usize, bundles: [*]const *const dgpu.RenderBundle) void {
        //     T.renderPassEncoderExecuteBundles(render_pass_encoder, bundles_count, bundles);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderInsertDebugMarker(DGPURenderPassEncoder renderPassEncoder, char const * markerLabel);
        // export fn dgpuRenderPassEncoderInsertDebugMarker(render_pass_encoder: *dgpu.RenderPassEncoder, marker_label: [*:0]const u8) void {
        //     T.renderPassEncoderInsertDebugMarker(render_pass_encoder, marker_label);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderPopDebugGroup(DGPURenderPassEncoder renderPassEncoder);
        // export fn dgpuRenderPassEncoderPopDebugGroup(render_pass_encoder: *dgpu.RenderPassEncoder) void {
        //     T.renderPassEncoderPopDebugGroup(render_pass_encoder);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderPushDebugGroup(DGPURenderPassEncoder renderPassEncoder, char const * groupLabel);
        // export fn dgpuRenderPassEncoderPushDebugGroup(render_pass_encoder: *dgpu.RenderPassEncoder, group_label: [*:0]const u8) void {
        //     T.renderPassEncoderPushDebugGroup(render_pass_encoder, group_label);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderSetBindGroup(DGPURenderPassEncoder renderPassEncoder, uint32_t groupIndex, DGPUBindGroup group, size_t dynamicOffsetCount, uint32_t const * dynamicOffsets);
        // export fn dgpuRenderPassEncoderSetBindGroup(render_pass_encoder: *dgpu.RenderPassEncoder, group_index: u32, group: *dgpu.BindGroup, dynamic_offset_count: usize, dynamic_offsets: ?[*]const u32) void {
        //     T.renderPassEncoderSetBindGroup(render_pass_encoder, group_index, group, dynamic_offset_count, dynamic_offsets);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderSetBlendConstant(DGPURenderPassEncoder renderPassEncoder, DGPUColor const * color);
        // export fn dgpuRenderPassEncoderSetBlendConstant(render_pass_encoder: *dgpu.RenderPassEncoder, color: *const dgpu.Color) void {
        //     T.renderPassEncoderSetBlendConstant(render_pass_encoder, color);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderSetIndexBuffer(DGPURenderPassEncoder renderPassEncoder, DGPUBuffer buffer, DGPUIndexFormat format, uint64_t offset, uint64_t size);
        // export fn dgpuRenderPassEncoderSetIndexBuffer(render_pass_encoder: *dgpu.RenderPassEncoder, buffer: *dgpu.Buffer, format: dgpu.IndexFormat, offset: u64, size: u64) void {
        //     T.renderPassEncoderSetIndexBuffer(render_pass_encoder, buffer, format, offset, size);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderSetLabel(DGPURenderPassEncoder renderPassEncoder, char const * label);
        // export fn dgpuRenderPassEncoderSetLabel(render_pass_encoder: *dgpu.RenderPassEncoder, label: [:0]const u8) void {
        //     T.renderPassEncoderSetLabel(render_pass_encoder, label);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderSetPipeline(DGPURenderPassEncoder renderPassEncoder, DGPURenderPipeline pipeline);
        // export fn dgpuRenderPassEncoderSetPipeline(render_pass_encoder: *dgpu.RenderPassEncoder, pipeline: *dgpu.RenderPipeline) void {
        //     T.renderPassEncoderSetPipeline(render_pass_encoder, pipeline);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderSetScissorRect(DGPURenderPassEncoder renderPassEncoder, uint32_t x, uint32_t y, uint32_t width, uint32_t height);
        // export fn dgpuRenderPassEncoderSetScissorRect(render_pass_encoder: *dgpu.RenderPassEncoder, x: u32, y: u32, width: u32, height: u32) void {
        //     T.renderPassEncoderSetScissorRect(render_pass_encoder, x, y, width, height);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderSetStencilReference(DGPURenderPassEncoder renderPassEncoder, uint32_t reference);
        // export fn dgpuRenderPassEncoderSetStencilReference(render_pass_encoder: *dgpu.RenderPassEncoder, reference: u32) void {
        //     T.renderPassEncoderSetStencilReference(render_pass_encoder, reference);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderSetVertexBuffer(DGPURenderPassEncoder renderPassEncoder, uint32_t slot, DGPUBuffer buffer, uint64_t offset, uint64_t size);
        // export fn dgpuRenderPassEncoderSetVertexBuffer(render_pass_encoder: *dgpu.RenderPassEncoder, slot: u32, buffer: *dgpu.Buffer, offset: u64, size: u64) void {
        //     T.renderPassEncoderSetVertexBuffer(render_pass_encoder, slot, buffer, offset, size);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderSetViewport(DGPURenderPassEncoder renderPassEncoder, float x, float y, float width, float height, float minDepth, float maxDepth);
        // export fn dgpuRenderPassEncoderSetViewport(render_pass_encoder: *dgpu.RenderPassEncoder, x: f32, y: f32, width: f32, height: f32, min_depth: f32, max_depth: f32) void {
        //     T.renderPassEncoderSetViewport(render_pass_encoder, x, y, width, height, min_depth, max_depth);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderWriteTimestamp(DGPURenderPassEncoder renderPassEncoder, DGPUQuerySet querySet, uint32_t queryIndex);
        // export fn dgpuRenderPassEncoderWriteTimestamp(render_pass_encoder: *dgpu.RenderPassEncoder, query_set: *dgpu.QuerySet, query_index: u32) void {
        //     T.renderPassEncoderWriteTimestamp(render_pass_encoder, query_set, query_index);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderReference(DGPURenderPassEncoder renderPassEncoder);
        // export fn dgpuRenderPassEncoderReference(render_pass_encoder: *dgpu.RenderPassEncoder) void {
        //     T.renderPassEncoderReference(render_pass_encoder);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderRelease(DGPURenderPassEncoder renderPassEncoder);
        // export fn dgpuRenderPassEncoderRelease(render_pass_encoder: *dgpu.RenderPassEncoder) void {
        //     T.renderPassEncoderRelease(render_pass_encoder);
        // }

        // // DGPU_EXPORT DGPUBindGroupLayout dgpuRenderPipelineGetBindGroupLayout(DGPURenderPipeline renderPipeline, uint32_t groupIndex);
        // export fn dgpuRenderPipelineGetBindGroupLayout(render_pipeline: *dgpu.RenderPipeline, group_index: u32) *dgpu.BindGroupLayout {
        //     return T.renderPipelineGetBindGroupLayout(render_pipeline, group_index);
        // }

        // // DGPU_EXPORT void dgpuRenderPipelineSetLabel(DGPURenderPipeline renderPipeline, char const * label);
        // export fn dgpuRenderPipelineSetLabel(render_pipeline: *dgpu.RenderPipeline, label: [:0]const u8) void {
        //     T.renderPipelineSetLabel(render_pipeline, label);
        // }

        // // DGPU_EXPORT void dgpuRenderPipelineReference(DGPURenderPipeline renderPipeline);
        // export fn dgpuRenderPipelineReference(render_pipeline: *dgpu.RenderPipeline) void {
        //     T.renderPipelineReference(render_pipeline);
        // }

        // // DGPU_EXPORT void dgpuRenderPipelineRelease(DGPURenderPipeline renderPipeline);
        // export fn dgpuRenderPipelineRelease(render_pipeline: *dgpu.RenderPipeline) void {
        //     T.renderPipelineRelease(render_pipeline);
        // }

        // // DGPU_EXPORT void dgpuSamplerSetLabel(DGPUSampler sampler, char const * label);
        // export fn dgpuSamplerSetLabel(sampler: *dgpu.Sampler, label: [:0]const u8) void {
        //     T.samplerSetLabel(sampler, label);
        // }

        // // DGPU_EXPORT void dgpuSamplerReference(DGPUSampler sampler);
        // export fn dgpuSamplerReference(sampler: *dgpu.Sampler) void {
        //     T.samplerReference(sampler);
        // }

        // // DGPU_EXPORT void dgpuSamplerRelease(DGPUSampler sampler);
        // export fn dgpuSamplerRelease(sampler: *dgpu.Sampler) void {
        //     T.samplerRelease(sampler);
        // }

        // // DGPU_EXPORT void dgpuShaderModuleGetCompilationInfo(DGPUShaderModule shaderModule, DGPUCompilationInfoCallback callback, void * userdata);
        // export fn dgpuShaderModuleGetCompilationInfo(shader_module: *dgpu.ShaderModule, callback: dgpu.CompilationInfoCallback, userdata: ?*anyopaque) void {
        //     T.shaderModuleGetCompilationInfo(shader_module, callback, userdata);
        // }

        // // DGPU_EXPORT void dgpuShaderModuleSetLabel(DGPUShaderModule shaderModule, char const * label);
        // export fn dgpuShaderModuleSetLabel(shader_module: *dgpu.ShaderModule, label: [:0]const u8) void {
        //     T.shaderModuleSetLabel(shader_module, label);
        // }

        // // DGPU_EXPORT void dgpuShaderModuleReference(DGPUShaderModule shaderModule);
        // export fn dgpuShaderModuleReference(shader_module: *dgpu.ShaderModule) void {
        //     T.shaderModuleReference(shader_module);
        // }

        // // DGPU_EXPORT void dgpuShaderModuleRelease(DGPUShaderModule shaderModule);
        // export fn dgpuShaderModuleRelease(shader_module: *dgpu.ShaderModule) void {
        //     T.shaderModuleRelease(shader_module);
        // }

        // // DGPU_EXPORT void dgpuSharedFenceExportInfo(DGPUSharedFence sharedFence, DGPUSharedFenceExportInfo * info);
        // export fn dgpuSharedFenceExportInfo(shared_fence: *dgpu.SharedFence, info: *dgpu.SharedFence.ExportInfo) void {
        //     T.sharedFenceExportInfo(shared_fence, info);
        // }

        // // DGPU_EXPORT void dgpuSharedFenceReference(DGPUSharedFence sharedFence);
        // export fn dgpuSharedFenceReference(shared_fence: *dgpu.SharedFence) void {
        //     T.sharedFenceReference(shared_fence);
        // }

        // // DGPU_EXPORT void dgpuSharedFenceRelease(DGPUSharedFence sharedFence);
        // export fn dgpuSharedFenceRelease(shared_fence: *dgpu.SharedFence) void {
        //     T.sharedFenceRelease(shared_fence);
        // }

        // // DGPU_EXPORT void dgpuSharedTextureMemoryBeginAccess(DGPUSharedTextureMemory sharedTextureMemory, DGPUTexture texture, DGPUSharedTextureMemoryBeginAccessDescriptor const * descriptor);
        // export fn dgpuSharedTextureMemoryBeginAccess(shared_texture_memory: *dgpu.SharedTextureMemory, texture: *dgpu.Texture, descriptor: dgpu.SharedTextureMemory.BeginAccessDescriptor) void {
        //     T.sharedTextureMemoryBeginAccess(shared_texture_memory, texture, descriptor);
        // }

        // // DGPU_EXPORT DGPUTexture dgpuSharedTextureMemoryCreateTexture(DGPUSharedTextureMemory sharedTextureMemory, DGPUTextureDescriptor const * descriptor);
        // export fn dgpuSharedTextureMemoryCreateTexture(shared_texture_memory: *dgpu.SharedTextureMemory, descriptor: dgpu.Texture.Descriptor) *dgpu.Texture {
        //     return T.sharedTextureMemoryCreateTexture(shared_texture_memory, descriptor);
        // }

        // // DGPU_EXPORT void dgpuSharedTextureMemoryEndAccess(DGPUSharedTextureMemory sharedTextureMemory, DGPUTexture texture, DGPUSharedTextureMemoryEndAccessState * descriptor);
        // export fn dgpuSharedTextureMemoryEndAccess(shared_texture_memory: *dgpu.SharedTextureMemory, texture: *dgpu.Texture, descriptor: *dgpu.SharedTextureMemory.EndAccessState) void {
        //     T.sharedTextureMemoryEndAccess(shared_texture_memory, texture, descriptor);
        // }

        // // DGPU_EXPORT void dgpuSharedTextureMemoryEndAccessStateFreeMembers(DGPUSharedTextureMemoryEndAccessState value);
        // export fn dgpuSharedTextureMemoryEndAccessStateFreeMembers(value: dgpu.SharedTextureMemory.EndAccessState) void {
        //     T.sharedTextureMemoryEndAccessStateFreeMembers(value);
        // }

        // // DGPU_EXPORT void dgpuSharedTextureMemoryGetProperties(DGPUSharedTextureMemory sharedTextureMemory, DGPUSharedTextureMemoryProperties * properties);
        // export fn dgpuSharedTextureMemoryGetProperties(shared_texture_memory: *dgpu.SharedTextureMemory, properties: *dgpu.SharedTextureMemory.Properties) void {
        //     T.sharedTextureMemoryGetProperties(shared_texture_memory, properties);
        // }

        // // DGPU_EXPORT void dgpuSharedTextureMemorySetLabel(DGPUSharedTextureMemory sharedTextureMemory, char const * label);
        // export fn dgpuSharedTextureMemorySetLabel(shared_texture_memory: *dgpu.SharedTextureMemory, label: [:0]const u8) void {
        //     T.sharedTextureMemorySetLabel(shared_texture_memory, label);
        // }

        // // DGPU_EXPORT void dgpuSharedTextureMemoryReference(DGPUSharedTextureMemory sharedTextureMemory);
        // export fn dgpuSharedTextureMemoryReference(shared_texture_memory: *dgpu.SharedTextureMemory) void {
        //     T.sharedTextureMemoryReference(shared_texture_memory);
        // }

        // // DGPU_EXPORT void dgpuSharedTextureMemoryRelease(DGPUSharedTextureMemory sharedTextureMemory);
        // export fn dgpuSharedTextureMemoryRelease(shared_texture_memory: *dgpu.SharedTextureMemory) void {
        //     T.sharedTextureMemoryRelease(shared_texture_memory);
        // }

        // // DGPU_EXPORT void dgpuSurfaceReference(DGPUSurface surface);
        // export fn dgpuSurfaceReference(surface: *dgpu.Surface) void {
        //     T.surfaceReference(surface);
        // }

        // // DGPU_EXPORT void dgpuSurfaceRelease(DGPUSurface surface);
        // export fn dgpuSurfaceRelease(surface: *dgpu.Surface) void {
        //     T.surfaceRelease(surface);
        // }

        // // DGPU_EXPORT DGPUTexture dgpuSwapChainGetCurrentTexture(DGPUSwapChain swapChain);
        // export fn dgpuSwapChainGetCurrentTexture(swap_chain: *dgpu.SwapChain) ?*dgpu.Texture {
        //     return T.swapChainGetCurrentTexture(swap_chain);
        // }

        // // DGPU_EXPORT DGPUTextureView dgpuSwapChainGetCurrentTextureView(DGPUSwapChain swapChain);
        // export fn dgpuSwapChainGetCurrentTextureView(swap_chain: *dgpu.SwapChain) ?*dgpu.TextureView {
        //     return T.swapChainGetCurrentTextureView(swap_chain);
        // }

        // // DGPU_EXPORT void dgpuSwapChainPresent(DGPUSwapChain swapChain);
        // export fn dgpuSwapChainPresent(swap_chain: *dgpu.SwapChain) void {
        //     T.swapChainPresent(swap_chain);
        // }

        // // DGPU_EXPORT void dgpuSwapChainReference(DGPUSwapChain swapChain);
        // export fn dgpuSwapChainReference(swap_chain: *dgpu.SwapChain) void {
        //     T.swapChainReference(swap_chain);
        // }

        // // DGPU_EXPORT void dgpuSwapChainRelease(DGPUSwapChain swapChain);
        // export fn dgpuSwapChainRelease(swap_chain: *dgpu.SwapChain) void {
        //     T.swapChainRelease(swap_chain);
        // }

        // // DGPU_EXPORT DGPUTextureView dgpuTextureCreateView(DGPUTexture texture, DGPUTextureViewDescriptor const * descriptor /* nullable */);
        // export fn dgpuTextureCreateView(texture: *dgpu.Texture, descriptor: dgpu.TextureView.Descriptor) *dgpu.TextureView {
        //     return T.textureCreateView(texture, descriptor);
        // }

        // // DGPU_EXPORT void dgpuTextureDestroy(DGPUTexture texture);
        // export fn dgpuTextureDestroy(texture: *dgpu.Texture) void {
        //     T.textureDestroy(texture);
        // }

        // // DGPU_EXPORT uint32_t dgpuTextureGetDepthOrArrayLayers(DGPUTexture texture);
        // export fn dgpuTextureGetDepthOrArrayLayers(texture: *dgpu.Texture) u32 {
        //     return T.textureGetDepthOrArrayLayers(texture);
        // }

        // // DGPU_EXPORT DGPUTextureDimension dgpuTextureGetDimension(DGPUTexture texture);
        // export fn dgpuTextureGetDimension(texture: *dgpu.Texture) dgpu.Texture.Dimension {
        //     return T.textureGetDimension(texture);
        // }

        // // DGPU_EXPORT DGPUTextureFormat dgpuTextureGetFormat(DGPUTexture texture);
        // export fn dgpuTextureGetFormat(texture: *dgpu.Texture) dgpu.Texture.Format {
        //     return T.textureGetFormat(texture);
        // }

        // // DGPU_EXPORT uint32_t dgpuTextureGetHeight(DGPUTexture texture);
        // export fn dgpuTextureGetHeight(texture: *dgpu.Texture) u32 {
        //     return T.textureGetHeight(texture);
        // }

        // // DGPU_EXPORT uint32_t dgpuTextureGetMipLevelCount(DGPUTexture texture);
        // export fn dgpuTextureGetMipLevelCount(texture: *dgpu.Texture) u32 {
        //     return T.textureGetMipLevelCount(texture);
        // }

        // // DGPU_EXPORT uint32_t dgpuTextureGetSampleCount(DGPUTexture texture);
        // export fn dgpuTextureGetSampleCount(texture: *dgpu.Texture) u32 {
        //     return T.textureGetSampleCount(texture);
        // }

        // // DGPU_EXPORT DGPUTextureUsage dgpuTextureGetUsage(DGPUTexture texture);
        // export fn dgpuTextureGetUsage(texture: *dgpu.Texture) dgpu.Texture.UsageFlags {
        //     return T.textureGetUsage(texture);
        // }

        // // DGPU_EXPORT uint32_t dgpuTextureGetWidth(DGPUTexture texture);
        // export fn dgpuTextureGetWidth(texture: *dgpu.Texture) u32 {
        //     return T.textureGetWidth(texture);
        // }

        // // DGPU_EXPORT void dgpuTextureSetLabel(DGPUTexture texture, char const * label);
        // export fn dgpuTextureSetLabel(texture: *dgpu.Texture, label: [:0]const u8) void {
        //     T.textureSetLabel(texture, label);
        // }

        // // DGPU_EXPORT void dgpuTextureReference(DGPUTexture texture);
        // export fn dgpuTextureReference(texture: *dgpu.Texture) void {
        //     T.textureReference(texture);
        // }

        // // DGPU_EXPORT void dgpuTextureRelease(DGPUTexture texture);
        // export fn dgpuTextureRelease(texture: *dgpu.Texture) void {
        //     T.textureRelease(texture);
        // }

        // // DGPU_EXPORT void dgpuTextureViewSetLabel(DGPUTextureView textureView, char const * label);
        // export fn dgpuTextureViewSetLabel(texture_view: *dgpu.TextureView, label: [:0]const u8) void {
        //     T.textureViewSetLabel(texture_view, label);
        // }

        // // DGPU_EXPORT void dgpuTextureViewReference(DGPUTextureView textureView);
        // export fn dgpuTextureViewReference(texture_view: *dgpu.TextureView) void {
        //     T.textureViewReference(texture_view);
        // }

        // // DGPU_EXPORT void dgpuTextureViewRelease(DGPUTextureView textureView);
        // export fn dgpuTextureViewRelease(texture_view: *dgpu.TextureView) void {
        //     T.textureViewRelease(texture_view);
        // }
    };
}
