const dgpu = @import("main.zig");

/// The dgpu.Interface implementation that is used by the entire program. Only one may exist, since
/// it is resolved fully at comptime with no vtable indirection, etc.
///
/// Depending on the implementation, it may need to be `.init()`ialized before use.
pub const Impl = blk: {
    if (@import("builtin").is_test) {
        break :blk StubInterface;
    } else {
        const root = @import("root");
        if (!@hasDecl(root, "DGPUInterface")) @compileError("expected to find `pub const DGPUInterface = T;` in root file");
        _ = dgpu.Interface(root.DGPUInterface); // verify the type
        break :blk root.DGPUInterface;
    }
};

/// Verifies that a dgpu.Interface implementation exposes the expected function declarations.
pub fn Interface(comptime T: type) type {
    // dgpu.Device
    assertDecl(T, "deviceCreateRenderPipeline", fn (device: *dgpu.Device, descriptor: dgpu.RenderPipeline.Descriptor) callconv(.Inline) *dgpu.RenderPipeline);
    assertDecl(T, "deviceCreatePipelineLayout", fn (device: *dgpu.Device, descriptor: dgpu.PipelineLayout.Descriptor) callconv(.Inline) *dgpu.PipelineLayout);

    // dgpu.PipelineLayout
    assertDecl(T, "pipelineLayoutSetLabel", fn (pipeline_layout: *dgpu.PipelineLayout, label: [:0]const u8) callconv(.Inline) void);
    assertDecl(T, "pipelineLayoutReference", fn (pipeline_layout: *dgpu.PipelineLayout) callconv(.Inline) void);
    assertDecl(T, "pipelineLayoutRelease", fn (pipeline_layout: *dgpu.PipelineLayout) callconv(.Inline) void);

    // dgpu.RenderBundleEncoder
    assertDecl(T, "renderBundleEncoderSetPipeline", fn (render_bundle_encoder: *dgpu.RenderBundleEncoder, pipeline: *dgpu.RenderPipeline) callconv(.Inline) void);
    assertDecl(T, "renderBundleEncoderSetBindGroup", fn (render_bundle_encoder: *dgpu.RenderBundleEncoder, group_index: u32, group: *dgpu.BindGroup, dynamic_offset_count: usize, dynamic_offsets: ?[*]const u32) callconv(.Inline) void);

    // dgpu.RenderPassEncoder
    assertDecl(T, "renderPassEncoderSetPipeline", fn (render_pass_encoder: *dgpu.RenderPassEncoder, pipeline: *dgpu.RenderPipeline) callconv(.Inline) void);
    assertDecl(T, "renderPassEncoderSetBindGroup", fn (render_pass_encoder: *dgpu.RenderPassEncoder, group_index: u32, group: *dgpu.BindGroup, dynamic_offset_count: usize, dynamic_offsets: ?[*]const u32) callconv(.Inline) void);

    // dgpu.BindGroup
    assertDecl(T, "bindGroupSetLabel", fn (bind_group: *dgpu.BindGroup, label: [:0]const u8) callconv(.Inline) void);
    assertDecl(T, "bindGroupReference", fn (bind_group: *dgpu.BindGroup) callconv(.Inline) void);
    assertDecl(T, "bindGroupRelease", fn (bind_group: *dgpu.BindGroup) callconv(.Inline) void);

    // dgpu.BindGroupLayout
    assertDecl(T, "bindGroupLayoutSetLabel", fn (bind_group_layout: *dgpu.BindGroupLayout, label: [:0]const u8) callconv(.Inline) void);
    assertDecl(T, "bindGroupLayoutReference", fn (bind_group_layout: *dgpu.BindGroupLayout) callconv(.Inline) void);
    assertDecl(T, "bindGroupLayoutRelease", fn (bind_group_layout: *dgpu.BindGroupLayout) callconv(.Inline) void);

    // dgpu.RenderPipeline
    assertDecl(T, "renderPipelineGetBindGroupLayout", fn (render_pipeline: *dgpu.RenderPipeline, group_index: u32) callconv(.Inline) *dgpu.BindGroupLayout);
    assertDecl(T, "renderPipelineSetLabel", fn (render_pipeline: *dgpu.RenderPipeline, label: [:0]const u8) callconv(.Inline) void);
    assertDecl(T, "renderPipelineReference", fn (render_pipeline: *dgpu.RenderPipeline) callconv(.Inline) void);
    assertDecl(T, "renderPipelineRelease", fn (render_pipeline: *dgpu.RenderPipeline) callconv(.Inline) void);

    // dgpu.Instance
    assertDecl(T, "createInstance", fn (descriptor: dgpu.Instance.Descriptor) callconv(.Inline) ?*dgpu.Instance);

    // dgpu.Adapter
    assertDecl(T, "adapterCreateDevice", fn (adapter: *dgpu.Adapter, descriptor: dgpu.Device.Descriptor) callconv(.Inline) ?*dgpu.Device);
    assertDecl(T, "adapterEnumerateFeatures", fn (adapter: *dgpu.Adapter, features: ?[*]dgpu.FeatureName) callconv(.Inline) usize);
    assertDecl(T, "adapterGetInstance", fn (adapter: *dgpu.Adapter) callconv(.Inline) *dgpu.Instance);
    assertDecl(T, "adapterGetLimits", fn (adapter: *dgpu.Adapter, limits: *dgpu.Limits) callconv(.Inline) u32);
    assertDecl(T, "adapterGetProperties", fn (adapter: *dgpu.Adapter) callconv(.Inline) dgpu.Adapter.Properties);
    assertDecl(T, "adapterHasFeature", fn (adapter: *dgpu.Adapter, feature: dgpu.FeatureName) callconv(.Inline) u32);
    assertDecl(T, "adapterPropertiesFreeMembers", fn (value: dgpu.Adapter.Properties) callconv(.Inline) void);
    assertDecl(T, "adapterReference", fn (adapter: *dgpu.Adapter) callconv(.Inline) void);
    assertDecl(T, "adapterRelease", fn (adapter: *dgpu.Adapter) callconv(.Inline) void);

    // dgpu.Buffer
    assertDecl(T, "bufferDestroy", fn (buffer: *dgpu.Buffer) callconv(.Inline) void);
    assertDecl(T, "bufferGetConstMappedRange", fn (buffer: *dgpu.Buffer, offset: usize, size: usize) callconv(.Inline) ?*const anyopaque);
    assertDecl(T, "bufferGetMappedRange", fn (buffer: *dgpu.Buffer, offset: usize, size: usize) callconv(.Inline) ?*anyopaque);
    assertDecl(T, "bufferGetSize", fn (buffer: *dgpu.Buffer) callconv(.Inline) u64);
    assertDecl(T, "bufferGetUsage", fn (buffer: *dgpu.Buffer) callconv(.Inline) dgpu.Buffer.UsageFlags);
    assertDecl(T, "bufferSetLabel", fn (buffer: *dgpu.Buffer, label: [:0]const u8) callconv(.Inline) void);
    assertDecl(T, "bufferUnmap", fn (buffer: *dgpu.Buffer) callconv(.Inline) void);
    assertDecl(T, "bufferReference", fn (buffer: *dgpu.Buffer) callconv(.Inline) void);
    assertDecl(T, "bufferRelease", fn (buffer: *dgpu.Buffer) callconv(.Inline) void);

    // dgpu.CommandBuffer
    assertDecl(T, "commandBufferSetLabel", fn (command_buffer: *dgpu.CommandBuffer, label: [:0]const u8) callconv(.Inline) void);
    assertDecl(T, "commandBufferReference", fn (command_buffer: *dgpu.CommandBuffer) callconv(.Inline) void);
    assertDecl(T, "commandBufferRelease", fn (command_buffer: *dgpu.CommandBuffer) callconv(.Inline) void);

    // dgpu.CommandEncoder
    assertDecl(T, "commandEncoderBeginComputePass", fn (command_encoder: *dgpu.CommandEncoder, descriptor: dgpu.ComputePassDescriptor) callconv(.Inline) *dgpu.ComputePassEncoder);
    assertDecl(T, "commandEncoderBeginRenderPass", fn (command_encoder: *dgpu.CommandEncoder, descriptor: dgpu.RenderPassDescriptor) callconv(.Inline) *dgpu.RenderPassEncoder);
    assertDecl(T, "commandEncoderClearBuffer", fn (command_encoder: *dgpu.CommandEncoder, buffer: *dgpu.Buffer, offset: u64, size: u64) callconv(.Inline) void);
    assertDecl(T, "commandEncoderCopyBufferToBuffer", fn (command_encoder: *dgpu.CommandEncoder, source: *dgpu.Buffer, source_offset: u64, destination: *dgpu.Buffer, destination_offset: u64, size: u64) callconv(.Inline) void);
    assertDecl(T, "commandEncoderCopyBufferToTexture", fn (command_encoder: *dgpu.CommandEncoder, source: *const dgpu.ImageCopyBuffer, destination: *const dgpu.ImageCopyTexture, copy_size: *const dgpu.Extent3D) callconv(.Inline) void);
    assertDecl(T, "commandEncoderCopyTextureToBuffer", fn (command_encoder: *dgpu.CommandEncoder, source: *const dgpu.ImageCopyTexture, destination: *const dgpu.ImageCopyBuffer, copy_size: *const dgpu.Extent3D) callconv(.Inline) void);
    assertDecl(T, "commandEncoderCopyTextureToTexture", fn (command_encoder: *dgpu.CommandEncoder, source: *const dgpu.ImageCopyTexture, destination: *const dgpu.ImageCopyTexture, copy_size: *const dgpu.Extent3D) callconv(.Inline) void);
    assertDecl(T, "commandEncoderFinish", fn (command_encoder: *dgpu.CommandEncoder, descriptor: dgpu.CommandBuffer.Descriptor) callconv(.Inline) *dgpu.CommandBuffer);
    assertDecl(T, "commandEncoderInjectValidationError", fn (command_encoder: *dgpu.CommandEncoder, message: [:0]const u8) callconv(.Inline) void);
    assertDecl(T, "commandEncoderInsertDebugMarker", fn (command_encoder: *dgpu.CommandEncoder, marker_label: [:0]const u8) callconv(.Inline) void);
    assertDecl(T, "commandEncoderPopDebugGroup", fn (command_encoder: *dgpu.CommandEncoder) callconv(.Inline) void);
    assertDecl(T, "commandEncoderPushDebugGroup", fn (command_encoder: *dgpu.CommandEncoder, group_label: [:0]const u8) callconv(.Inline) void);
    assertDecl(T, "commandEncoderResolveQuerySet", fn (command_encoder: *dgpu.CommandEncoder, query_set: *dgpu.QuerySet, first_query: u32, query_count: u32, destination: *dgpu.Buffer, destination_offset: u64) callconv(.Inline) void);
    assertDecl(T, "commandEncoderSetLabel", fn (command_encoder: *dgpu.CommandEncoder, label: [:0]const u8) callconv(.Inline) void);
    assertDecl(T, "commandEncoderWriteBuffer", fn (command_encoder: *dgpu.CommandEncoder, buffer: *dgpu.Buffer, buffer_offset: u64, data: [*]const u8, size: u64) callconv(.Inline) void);
    assertDecl(T, "commandEncoderWriteTimestamp", fn (command_encoder: *dgpu.CommandEncoder, query_set: *dgpu.QuerySet, query_index: u32) callconv(.Inline) void);
    assertDecl(T, "commandEncoderReference", fn (command_encoder: *dgpu.CommandEncoder) callconv(.Inline) void);
    assertDecl(T, "commandEncoderRelease", fn (command_encoder: *dgpu.CommandEncoder) callconv(.Inline) void);

    // dgpu.ComputePassEncoder
    assertDecl(T, "computePassEncoderDispatchWorkgroups", fn (compute_pass_encoder: *dgpu.ComputePassEncoder, workgroup_count_x: u32, workgroup_count_y: u32, workgroup_count_z: u32) callconv(.Inline) void);
    assertDecl(T, "computePassEncoderDispatchWorkgroupsIndirect", fn (compute_pass_encoder: *dgpu.ComputePassEncoder, indirect_buffer: *dgpu.Buffer, indirect_offset: u64) callconv(.Inline) void);
    assertDecl(T, "computePassEncoderEnd", fn (compute_pass_encoder: *dgpu.ComputePassEncoder) callconv(.Inline) void);
    assertDecl(T, "computePassEncoderInsertDebugMarker", fn (compute_pass_encoder: *dgpu.ComputePassEncoder, marker_label: [:0]const u8) callconv(.Inline) void);
    assertDecl(T, "computePassEncoderPopDebugGroup", fn (compute_pass_encoder: *dgpu.ComputePassEncoder) callconv(.Inline) void);
    assertDecl(T, "computePassEncoderPushDebugGroup", fn (compute_pass_encoder: *dgpu.ComputePassEncoder, group_label: [:0]const u8) callconv(.Inline) void);
    assertDecl(T, "computePassEncoderSetBindGroup", fn (compute_pass_encoder: *dgpu.ComputePassEncoder, group_index: u32, group: *dgpu.BindGroup, dynamic_offset_count: usize, dynamic_offsets: ?[*]const u32) callconv(.Inline) void);
    assertDecl(T, "computePassEncoderSetLabel", fn (compute_pass_encoder: *dgpu.ComputePassEncoder, label: [:0]const u8) callconv(.Inline) void);
    assertDecl(T, "computePassEncoderSetPipeline", fn (compute_pass_encoder: *dgpu.ComputePassEncoder, pipeline: *dgpu.ComputePipeline) callconv(.Inline) void);
    assertDecl(T, "computePassEncoderWriteTimestamp", fn (compute_pass_encoder: *dgpu.ComputePassEncoder, query_set: *dgpu.QuerySet, query_index: u32) callconv(.Inline) void);
    assertDecl(T, "computePassEncoderReference", fn (compute_pass_encoder: *dgpu.ComputePassEncoder) callconv(.Inline) void);
    assertDecl(T, "computePassEncoderRelease", fn (compute_pass_encoder: *dgpu.ComputePassEncoder) callconv(.Inline) void);

    // dgpu.ComputePipeline
    assertDecl(T, "computePipelineGetBindGroupLayout", fn (compute_pipeline: *dgpu.ComputePipeline, group_index: u32) callconv(.Inline) *dgpu.BindGroupLayout);
    assertDecl(T, "computePipelineSetLabel", fn (compute_pipeline: *dgpu.ComputePipeline, label: [:0]const u8) callconv(.Inline) void);
    assertDecl(T, "computePipelineReference", fn (compute_pipeline: *dgpu.ComputePipeline) callconv(.Inline) void);
    assertDecl(T, "computePipelineRelease", fn (compute_pipeline: *dgpu.ComputePipeline) callconv(.Inline) void);

    // dgpu.Device
    assertDecl(T, "getProcAddress", fn (device: *dgpu.Device, proc_name: [:0]const u8) callconv(.Inline) ?dgpu.Proc);
    assertDecl(T, "deviceCreateBindGroup", fn (device: *dgpu.Device, descriptor: dgpu.BindGroup.Descriptor) callconv(.Inline) *dgpu.BindGroup);
    assertDecl(T, "deviceCreateBindGroupLayout", fn (device: *dgpu.Device, descriptor: dgpu.BindGroupLayout.Descriptor) callconv(.Inline) *dgpu.BindGroupLayout);
    assertDecl(T, "deviceCreateBuffer", fn (device: *dgpu.Device, descriptor: dgpu.Buffer.Descriptor) callconv(.Inline) *dgpu.Buffer);
    assertDecl(T, "deviceCreateCommandEncoder", fn (device: *dgpu.Device, descriptor: dgpu.CommandEncoder.Descriptor) callconv(.Inline) *dgpu.CommandEncoder);
    assertDecl(T, "deviceCreateComputePipeline", fn (device: *dgpu.Device, descriptor: dgpu.ComputePipeline.Descriptor) callconv(.Inline) *dgpu.ComputePipeline);
    assertDecl(T, "deviceCreateErrorBuffer", fn (device: *dgpu.Device, descriptor: dgpu.Buffer.Descriptor) callconv(.Inline) *dgpu.Buffer);
    assertDecl(T, "deviceCreateErrorExternalTexture", fn (device: *dgpu.Device) callconv(.Inline) *dgpu.ExternalTexture);
    assertDecl(T, "deviceCreateErrorTexture", fn (device: *dgpu.Device, descriptor: dgpu.Texture.Descriptor) callconv(.Inline) *dgpu.Texture);
    assertDecl(T, "deviceCreateExternalTexture", fn (device: *dgpu.Device, descriptor: dgpu.ExternalTexture.Descriptor) callconv(.Inline) *dgpu.ExternalTexture);
    assertDecl(T, "deviceCreateQuerySet", fn (device: *dgpu.Device, descriptor: dgpu.QuerySet.Descriptor) callconv(.Inline) *dgpu.QuerySet);
    assertDecl(T, "deviceCreateRenderBundleEncoder", fn (device: *dgpu.Device, descriptor: dgpu.RenderBundleEncoder.Descriptor) callconv(.Inline) *dgpu.RenderBundleEncoder);
    // TODO(self-hosted): this cannot be marked as inline for some reason:
    // https://github.com/ziglang/zig/issues/12545
    assertDecl(T, "deviceCreateSampler", fn (device: *dgpu.Device, descriptor: dgpu.Sampler.Descriptor) *dgpu.Sampler);
    assertDecl(T, "deviceCreateShaderModule", fn (device: *dgpu.Device, descriptor: dgpu.ShaderModule.Descriptor) callconv(.Inline) *dgpu.ShaderModule);
    assertDecl(T, "deviceCreateSwapChain", fn (device: *dgpu.Device, surface: ?*dgpu.Surface, descriptor: dgpu.SwapChain.Descriptor) callconv(.Inline) *dgpu.SwapChain);
    assertDecl(T, "deviceCreateTexture", fn (device: *dgpu.Device, descriptor: dgpu.Texture.Descriptor) callconv(.Inline) *dgpu.Texture);
    assertDecl(T, "deviceDestroy", fn (device: *dgpu.Device) callconv(.Inline) void);
    assertDecl(T, "deviceEnumerateFeatures", fn (device: *dgpu.Device, features: ?[*]dgpu.FeatureName) callconv(.Inline) usize);
    assertDecl(T, "deviceGetLimits", fn (device: *dgpu.Device, limits: *dgpu.Limits) callconv(.Inline) u32);
    assertDecl(T, "deviceGetQueue", fn (device: *dgpu.Device) callconv(.Inline) *dgpu.Queue);
    assertDecl(T, "deviceHasFeature", fn (device: *dgpu.Device, feature: dgpu.FeatureName) callconv(.Inline) u32);
    assertDecl(T, "deviceImportSharedFence", fn (device: *dgpu.Device, descriptor: dgpu.SharedFence.Descriptor) callconv(.Inline) *dgpu.SharedFence);
    assertDecl(T, "deviceImportSharedTextureMemory", fn (device: *dgpu.Device, descriptor: dgpu.SharedTextureMemory.Descriptor) callconv(.Inline) *dgpu.SharedTextureMemory);
    assertDecl(T, "deviceInjectError", fn (device: *dgpu.Device, typ: dgpu.ErrorType, message: [:0]const u8) callconv(.Inline) void);
    assertDecl(T, "devicePopErrorScope", fn (device: *dgpu.Device, callback: dgpu.ErrorCallback, userdata: ?*anyopaque) callconv(.Inline) void);
    assertDecl(T, "devicePushErrorScope", fn (device: *dgpu.Device, filter: dgpu.ErrorFilter) callconv(.Inline) void);
    assertDecl(T, "deviceSetDeviceLostCallback", fn (device: *dgpu.Device, callback: ?dgpu.Device.LostCallback, userdata: ?*anyopaque) callconv(.Inline) void);
    assertDecl(T, "deviceSetLabel", fn (device: *dgpu.Device, label: [:0]const u8) callconv(.Inline) void);
    assertDecl(T, "deviceSetLoggingCallback", fn (device: *dgpu.Device, callback: ?dgpu.LoggingCallback, userdata: ?*anyopaque) callconv(.Inline) void);
    assertDecl(T, "deviceSetUncapturedErrorCallback", fn (device: *dgpu.Device, callback: ?dgpu.ErrorCallback, userdata: ?*anyopaque) callconv(.Inline) void);
    assertDecl(T, "deviceTick", fn (device: *dgpu.Device) callconv(.Inline) void);
    assertDecl(T, "machDeviceWaitForCommandsToBeScheduled", fn (device: *dgpu.Device) callconv(.Inline) void);
    assertDecl(T, "deviceReference", fn (device: *dgpu.Device) callconv(.Inline) void);
    assertDecl(T, "deviceRelease", fn (device: *dgpu.Device) callconv(.Inline) void);

    // dgpu.ExternalTexture
    assertDecl(T, "externalTextureDestroy", fn (external_texture: *dgpu.ExternalTexture) callconv(.Inline) void);
    assertDecl(T, "externalTextureSetLabel", fn (external_texture: *dgpu.ExternalTexture, label: [:0]const u8) callconv(.Inline) void);
    assertDecl(T, "externalTextureReference", fn (external_texture: *dgpu.ExternalTexture) callconv(.Inline) void);
    assertDecl(T, "externalTextureRelease", fn (external_texture: *dgpu.ExternalTexture) callconv(.Inline) void);

    // dgpu.Instance
    assertDecl(T, "instanceCreateSurface", fn (instance: *dgpu.Instance, descriptor: dgpu.Surface.Descriptor) callconv(.Inline) *dgpu.Surface);
    assertDecl(T, "instanceProcessEvents", fn (instance: *dgpu.Instance) callconv(.Inline) void);
    assertDecl(T, "instanceCreateAdapter", fn (instance: *dgpu.Instance, descriptor: dgpu.Adapter.Descriptor) callconv(.Inline) *dgpu.Adapter);
    assertDecl(T, "instanceReference", fn (instance: *dgpu.Instance) callconv(.Inline) void);
    assertDecl(T, "instanceRelease", fn (instance: *dgpu.Instance) callconv(.Inline) void);

    // dgpu.QuerySet
    assertDecl(T, "querySetDestroy", fn (query_set: *dgpu.QuerySet) callconv(.Inline) void);
    assertDecl(T, "querySetGetCount", fn (query_set: *dgpu.QuerySet) callconv(.Inline) u32);
    assertDecl(T, "querySetGetType", fn (query_set: *dgpu.QuerySet) callconv(.Inline) dgpu.QueryType);
    assertDecl(T, "querySetSetLabel", fn (query_set: *dgpu.QuerySet, label: [:0]const u8) callconv(.Inline) void);
    assertDecl(T, "querySetReference", fn (query_set: *dgpu.QuerySet) callconv(.Inline) void);
    assertDecl(T, "querySetRelease", fn (query_set: *dgpu.QuerySet) callconv(.Inline) void);

    // dgpu.Queue
    assertDecl(T, "queueCopyTextureForBrowser", fn (queue: *dgpu.Queue, source: *const dgpu.ImageCopyTexture, destination: *const dgpu.ImageCopyTexture, copy_size: *const dgpu.Extent3D, options: *const dgpu.CopyTextureForBrowserOptions) callconv(.Inline) void);
    assertDecl(T, "queueOnSubmittedWorkDone", fn (queue: *dgpu.Queue, signal_value: u64, callback: dgpu.Queue.WorkDoneCallback, userdata: ?*anyopaque) callconv(.Inline) void);
    assertDecl(T, "queueSetLabel", fn (queue: *dgpu.Queue, label: [:0]const u8) callconv(.Inline) void);
    assertDecl(T, "queueSubmit", fn (queue: *dgpu.Queue, command_count: usize, commands: [*]const *const dgpu.CommandBuffer) callconv(.Inline) void);
    assertDecl(T, "queueWriteBuffer", fn (queue: *dgpu.Queue, buffer: *dgpu.Buffer, buffer_offset: u64, data: *const anyopaque, size: usize) callconv(.Inline) void);
    assertDecl(T, "queueWriteTexture", fn (queue: *dgpu.Queue, destination: *const dgpu.ImageCopyTexture, data: *const anyopaque, data_size: usize, data_layout: *const dgpu.Texture.DataLayout, write_size: *const dgpu.Extent3D) callconv(.Inline) void);
    assertDecl(T, "queueReference", fn (queue: *dgpu.Queue) callconv(.Inline) void);
    assertDecl(T, "queueRelease", fn (queue: *dgpu.Queue) callconv(.Inline) void);

    // dgpu.RenderBundle
    assertDecl(T, "renderBundleSetLabel", fn (render_bundle: *dgpu.RenderBundle, label: [:0]const u8) callconv(.Inline) void);
    assertDecl(T, "renderBundleReference", fn (render_bundle: *dgpu.RenderBundle) callconv(.Inline) void);
    assertDecl(T, "renderBundleRelease", fn (render_bundle: *dgpu.RenderBundle) callconv(.Inline) void);

    // dgpu.RenderBundleEncoder
    assertDecl(T, "renderBundleEncoderDraw", fn (render_bundle_encoder: *dgpu.RenderBundleEncoder, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) callconv(.Inline) void);
    assertDecl(T, "renderBundleEncoderDrawIndexed", fn (render_bundle_encoder: *dgpu.RenderBundleEncoder, index_count: u32, instance_count: u32, first_index: u32, base_vertex: i32, first_instance: u32) callconv(.Inline) void);
    assertDecl(T, "renderBundleEncoderDrawIndexedIndirect", fn (render_bundle_encoder: *dgpu.RenderBundleEncoder, indirect_buffer: *dgpu.Buffer, indirect_offset: u64) callconv(.Inline) void);
    assertDecl(T, "renderBundleEncoderDrawIndirect", fn (render_bundle_encoder: *dgpu.RenderBundleEncoder, indirect_buffer: *dgpu.Buffer, indirect_offset: u64) callconv(.Inline) void);
    assertDecl(T, "renderBundleEncoderFinish", fn (render_bundle_encoder: *dgpu.RenderBundleEncoder, descriptor: dgpu.RenderBundle.Descriptor) callconv(.Inline) *dgpu.RenderBundle);
    assertDecl(T, "renderBundleEncoderInsertDebugMarker", fn (render_bundle_encoder: *dgpu.RenderBundleEncoder, marker_label: [:0]const u8) callconv(.Inline) void);
    assertDecl(T, "renderBundleEncoderPopDebugGroup", fn (render_bundle_encoder: *dgpu.RenderBundleEncoder) callconv(.Inline) void);
    assertDecl(T, "renderBundleEncoderPushDebugGroup", fn (render_bundle_encoder: *dgpu.RenderBundleEncoder, group_label: [:0]const u8) callconv(.Inline) void);
    assertDecl(T, "renderBundleEncoderSetIndexBuffer", fn (render_bundle_encoder: *dgpu.RenderBundleEncoder, buffer: *dgpu.Buffer, format: dgpu.IndexFormat, offset: u64, size: u64) callconv(.Inline) void);
    assertDecl(T, "renderBundleEncoderSetLabel", fn (render_bundle_encoder: *dgpu.RenderBundleEncoder, label: [:0]const u8) callconv(.Inline) void);
    assertDecl(T, "renderBundleEncoderSetVertexBuffer", fn (render_bundle_encoder: *dgpu.RenderBundleEncoder, slot: u32, buffer: *dgpu.Buffer, offset: u64, size: u64) callconv(.Inline) void);
    assertDecl(T, "renderBundleEncoderReference", fn (render_bundle_encoder: *dgpu.RenderBundleEncoder) callconv(.Inline) void);
    assertDecl(T, "renderBundleEncoderRelease", fn (render_bundle_encoder: *dgpu.RenderBundleEncoder) callconv(.Inline) void);

    // dgpu.RenderPassEncoder
    assertDecl(T, "renderPassEncoderBeginOcclusionQuery", fn (render_pass_encoder: *dgpu.RenderPassEncoder, query_index: u32) callconv(.Inline) void);
    assertDecl(T, "renderPassEncoderDraw", fn (render_pass_encoder: *dgpu.RenderPassEncoder, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) callconv(.Inline) void);
    assertDecl(T, "renderPassEncoderDrawIndexed", fn (render_pass_encoder: *dgpu.RenderPassEncoder, index_count: u32, instance_count: u32, first_index: u32, base_vertex: i32, first_instance: u32) callconv(.Inline) void);
    assertDecl(T, "renderPassEncoderDrawIndexedIndirect", fn (render_pass_encoder: *dgpu.RenderPassEncoder, indirect_buffer: *dgpu.Buffer, indirect_offset: u64) callconv(.Inline) void);
    assertDecl(T, "renderPassEncoderDrawIndirect", fn (render_pass_encoder: *dgpu.RenderPassEncoder, indirect_buffer: *dgpu.Buffer, indirect_offset: u64) callconv(.Inline) void);
    assertDecl(T, "renderPassEncoderEnd", fn (render_pass_encoder: *dgpu.RenderPassEncoder) callconv(.Inline) void);
    assertDecl(T, "renderPassEncoderEndOcclusionQuery", fn (render_pass_encoder: *dgpu.RenderPassEncoder) callconv(.Inline) void);
    assertDecl(T, "renderPassEncoderExecuteBundles", fn (render_pass_encoder: *dgpu.RenderPassEncoder, bundles_count: usize, bundles: [*]const *const dgpu.RenderBundle) callconv(.Inline) void);
    assertDecl(T, "renderPassEncoderInsertDebugMarker", fn (render_pass_encoder: *dgpu.RenderPassEncoder, marker_label: [:0]const u8) callconv(.Inline) void);
    assertDecl(T, "renderPassEncoderPopDebugGroup", fn (render_pass_encoder: *dgpu.RenderPassEncoder) callconv(.Inline) void);
    assertDecl(T, "renderPassEncoderPushDebugGroup", fn (render_pass_encoder: *dgpu.RenderPassEncoder, group_label: [:0]const u8) callconv(.Inline) void);
    assertDecl(T, "renderPassEncoderSetBlendConstant", fn (render_pass_encoder: *dgpu.RenderPassEncoder, color: *const dgpu.Color) callconv(.Inline) void);
    assertDecl(T, "renderPassEncoderSetIndexBuffer", fn (render_pass_encoder: *dgpu.RenderPassEncoder, buffer: *dgpu.Buffer, format: dgpu.IndexFormat, offset: u64, size: u64) callconv(.Inline) void);
    assertDecl(T, "renderPassEncoderSetLabel", fn (render_pass_encoder: *dgpu.RenderPassEncoder, label: [:0]const u8) callconv(.Inline) void);
    assertDecl(T, "renderPassEncoderSetScissorRect", fn (render_pass_encoder: *dgpu.RenderPassEncoder, x: u32, y: u32, width: u32, height: u32) callconv(.Inline) void);
    assertDecl(T, "renderPassEncoderSetStencilReference", fn (render_pass_encoder: *dgpu.RenderPassEncoder, reference: u32) callconv(.Inline) void);
    assertDecl(T, "renderPassEncoderSetVertexBuffer", fn (render_pass_encoder: *dgpu.RenderPassEncoder, slot: u32, buffer: *dgpu.Buffer, offset: u64, size: u64) callconv(.Inline) void);
    assertDecl(T, "renderPassEncoderSetViewport", fn (render_pass_encoder: *dgpu.RenderPassEncoder, x: f32, y: f32, width: f32, height: f32, min_depth: f32, max_depth: f32) callconv(.Inline) void);
    assertDecl(T, "renderPassEncoderWriteTimestamp", fn (render_pass_encoder: *dgpu.RenderPassEncoder, query_set: *dgpu.QuerySet, query_index: u32) callconv(.Inline) void);
    assertDecl(T, "renderPassEncoderReference", fn (render_pass_encoder: *dgpu.RenderPassEncoder) callconv(.Inline) void);
    assertDecl(T, "renderPassEncoderRelease", fn (render_pass_encoder: *dgpu.RenderPassEncoder) callconv(.Inline) void);

    // dgpu.Sampler
    assertDecl(T, "samplerSetLabel", fn (sampler: *dgpu.Sampler, label: [:0]const u8) callconv(.Inline) void);
    assertDecl(T, "samplerReference", fn (sampler: *dgpu.Sampler) callconv(.Inline) void);
    assertDecl(T, "samplerRelease", fn (sampler: *dgpu.Sampler) callconv(.Inline) void);

    // dgpu.ShaderModule
    assertDecl(T, "shaderModuleGetCompilationInfo", fn (shader_module: *dgpu.ShaderModule, callback: dgpu.CompilationInfoCallback, userdata: ?*anyopaque) callconv(.Inline) void);
    assertDecl(T, "shaderModuleSetLabel", fn (shader_module: *dgpu.ShaderModule, label: [:0]const u8) callconv(.Inline) void);
    assertDecl(T, "shaderModuleReference", fn (shader_module: *dgpu.ShaderModule) callconv(.Inline) void);
    assertDecl(T, "shaderModuleRelease", fn (shader_module: *dgpu.ShaderModule) callconv(.Inline) void);

    // dgpu.SharedFence
    assertDecl(T, "sharedFenceExportInfo", fn (shared_fence: *dgpu.SharedFence, info: *dgpu.SharedFence.BackendHandle) callconv(.Inline) void);
    assertDecl(T, "sharedFenceReference", fn (shared_fence: *dgpu.SharedFence) callconv(.Inline) void);
    assertDecl(T, "sharedFenceRelease", fn (shared_fence: *dgpu.SharedFence) callconv(.Inline) void);

    // dgpu.SharedTextureMemory
    assertDecl(T, "sharedTextureMemoryBeginAccess", fn (shared_texture_memory: *dgpu.SharedTextureMemory, texture: *dgpu.Texture, descriptor: dgpu.SharedTextureMemory.BeginAccessDescriptor) callconv(.Inline) void);
    assertDecl(T, "sharedTextureMemoryCreateTexture", fn (shared_texture_memory: *dgpu.SharedTextureMemory, descriptor: dgpu.Texture.Descriptor) callconv(.Inline) *dgpu.Texture);
    assertDecl(T, "sharedTextureMemoryEndAccess", fn (shared_texture_memory: *dgpu.SharedTextureMemory, texture: *dgpu.Texture, descriptor: *dgpu.SharedTextureMemory.EndAccessState) callconv(.Inline) void);
    assertDecl(T, "sharedTextureMemoryEndAccessStateFreeMembers", fn (value: dgpu.SharedTextureMemory.EndAccessState) callconv(.Inline) void);
    assertDecl(T, "sharedTextureMemoryGetProperties", fn (shared_texture_memory: *dgpu.SharedTextureMemory, properties: *dgpu.SharedTextureMemory.Properties) callconv(.Inline) void);
    assertDecl(T, "sharedTextureMemorySetLabel", fn (shared_texture_memory: *dgpu.SharedTextureMemory, label: [:0]const u8) callconv(.Inline) void);
    assertDecl(T, "sharedTextureMemoryReference", fn (shared_texture_memory: *dgpu.SharedTextureMemory) callconv(.Inline) void);
    assertDecl(T, "sharedTextureMemoryRelease", fn (shared_texture_memory: *dgpu.SharedTextureMemory) callconv(.Inline) void);

    // dgpu.Surface
    assertDecl(T, "surfaceReference", fn (surface: *dgpu.Surface) callconv(.Inline) void);
    assertDecl(T, "surfaceRelease", fn (surface: *dgpu.Surface) callconv(.Inline) void);

    // dgpu.SwapChain
    assertDecl(T, "swapChainGetCurrentTexture", fn (swap_chain: *dgpu.SwapChain) callconv(.Inline) ?*dgpu.Texture);
    assertDecl(T, "swapChainGetCurrentTextureView", fn (swap_chain: *dgpu.SwapChain) callconv(.Inline) ?*dgpu.TextureView);
    assertDecl(T, "swapChainPresent", fn (swap_chain: *dgpu.SwapChain) callconv(.Inline) void);
    assertDecl(T, "swapChainReference", fn (swap_chain: *dgpu.SwapChain) callconv(.Inline) void);
    assertDecl(T, "swapChainRelease", fn (swap_chain: *dgpu.SwapChain) callconv(.Inline) void);

    // dgpu.Texture
    assertDecl(T, "textureCreateView", fn (texture: *dgpu.Texture, descriptor: dgpu.TextureView.Descriptor) callconv(.Inline) *dgpu.TextureView);
    assertDecl(T, "textureDestroy", fn (texture: *dgpu.Texture) callconv(.Inline) void);
    assertDecl(T, "textureGetDepthOrArrayLayers", fn (texture: *dgpu.Texture) callconv(.Inline) u32);
    assertDecl(T, "textureGetDimension", fn (texture: *dgpu.Texture) callconv(.Inline) dgpu.Texture.Dimension);
    assertDecl(T, "textureGetFormat", fn (texture: *dgpu.Texture) callconv(.Inline) dgpu.Texture.Format);
    assertDecl(T, "textureGetHeight", fn (texture: *dgpu.Texture) callconv(.Inline) u32);
    assertDecl(T, "textureGetMipLevelCount", fn (texture: *dgpu.Texture) callconv(.Inline) u32);
    assertDecl(T, "textureGetSampleCount", fn (texture: *dgpu.Texture) callconv(.Inline) u32);
    assertDecl(T, "textureGetUsage", fn (texture: *dgpu.Texture) callconv(.Inline) dgpu.Texture.UsageFlags);
    assertDecl(T, "textureGetWidth", fn (texture: *dgpu.Texture) callconv(.Inline) u32);
    assertDecl(T, "textureSetLabel", fn (texture: *dgpu.Texture, label: [:0]const u8) callconv(.Inline) void);
    assertDecl(T, "textureReference", fn (texture: *dgpu.Texture) callconv(.Inline) void);
    assertDecl(T, "textureRelease", fn (texture: *dgpu.Texture) callconv(.Inline) void);
    assertDecl(T, "textureViewSetLabel", fn (texture_view: *dgpu.TextureView, label: [:0]const u8) callconv(.Inline) void);
    assertDecl(T, "textureViewReference", fn (texture_view: *dgpu.TextureView) callconv(.Inline) void);
    assertDecl(T, "textureViewRelease", fn (texture_view: *dgpu.TextureView) callconv(.Inline) void);
    return T;
}

fn assertDecl(comptime T: anytype, comptime name: []const u8, comptime Decl: type) void {
    if (!@hasDecl(T, name)) @compileError("dgpu.Interface missing declaration: " ++ @typeName(Decl));
    const FoundDecl = @TypeOf(@field(T, name));
    if (FoundDecl != Decl) @compileError("dgpu.Interface field '" ++ name ++ "'\n\texpected type: " ++ @typeName(Decl) ++ "\n\t   found type: " ++ @typeName(FoundDecl));
}

/// A stub dgpu.Interface in which every function is implemented by `unreachable;`
pub const StubInterface = Interface(struct {
    // pub inline fn createInstance(descriptor: dgpu.Instance.Descriptor) ?*dgpu.Instance {
    //     _ = descriptor;
    //     unreachable;
    // }

    // pub inline fn getProcAddress(device: *dgpu.Device, proc_name: [*:0]const u8) ?dgpu.Proc {
    //     _ = device;
    //     _ = proc_name;
    //     unreachable;
    // }

    // pub inline fn adapterCreateDevice(adapter: *dgpu.Adapter, descriptor: dgpu.Device.Descriptor) ?*dgpu.Device {
    //     _ = adapter;
    //     _ = descriptor;
    //     unreachable;
    // }

    // pub inline fn adapterEnumerateFeatures(adapter: *dgpu.Adapter, features: ?[*]dgpu.FeatureName) usize {
    //     _ = adapter;
    //     _ = features;
    //     unreachable;
    // }

    // pub inline fn adapterGetInstance(adapter: *dgpu.Adapter) *dgpu.Instance {
    //     _ = adapter;
    //     unreachable;
    // }

    // pub inline fn adapterGetLimits(adapter: *dgpu.Adapter, limits: *dgpu.Limits) u32 {
    //     _ = adapter;
    //     _ = limits;
    //     unreachable;
    // }

    // pub inline fn adapterGetProperties(adapter: *dgpu.Adapter, properties: *dgpu.Adapter.Properties) void {
    //     _ = adapter;
    //     _ = properties;
    //     unreachable;
    // }

    // pub inline fn adapterHasFeature(adapter: *dgpu.Adapter, feature: dgpu.FeatureName) u32 {
    //     _ = adapter;
    //     _ = feature;
    //     unreachable;
    // }

    // pub inline fn adapterPropertiesFreeMembers(value: dgpu.Adapter.Properties) void {
    //     _ = value;
    //     unreachable;
    // }

    // pub inline fn adapterReference(adapter: *dgpu.Adapter) void {
    //     _ = adapter;
    //     unreachable;
    // }

    // pub inline fn adapterRelease(adapter: *dgpu.Adapter) void {
    //     _ = adapter;
    //     unreachable;
    // }

    // pub inline fn bindGroupSetLabel(bind_group: *dgpu.BindGroup, label: [:0]const u8) void {
    //     _ = bind_group;
    //     _ = label;
    //     unreachable;
    // }

    // pub inline fn bindGroupReference(bind_group: *dgpu.BindGroup) void {
    //     _ = bind_group;
    //     unreachable;
    // }

    // pub inline fn bindGroupRelease(bind_group: *dgpu.BindGroup) void {
    //     _ = bind_group;
    //     unreachable;
    // }

    // pub inline fn bindGroupLayoutSetLabel(bind_group_layout: *dgpu.BindGroupLayout, label: [:0]const u8) void {
    //     _ = bind_group_layout;
    //     _ = label;
    //     unreachable;
    // }

    // pub inline fn bindGroupLayoutReference(bind_group_layout: *dgpu.BindGroupLayout) void {
    //     _ = bind_group_layout;
    //     unreachable;
    // }

    // pub inline fn bindGroupLayoutRelease(bind_group_layout: *dgpu.BindGroupLayout) void {
    //     _ = bind_group_layout;
    //     unreachable;
    // }

    // pub inline fn bufferDestroy(buffer: *dgpu.Buffer) void {
    //     _ = buffer;
    //     unreachable;
    // }

    // // TODO: dawn: return value not marked as nullable in dawn.json but in fact is.
    // pub inline fn bufferGetConstMappedRange(buffer: *dgpu.Buffer, offset: usize, size: usize) ?*const anyopaque {
    //     _ = buffer;
    //     _ = offset;
    //     _ = size;
    //     unreachable;
    // }

    // // TODO: dawn: return value not marked as nullable in dawn.json but in fact is.
    // pub inline fn bufferGetMappedRange(buffer: *dgpu.Buffer, offset: usize, size: usize) ?*anyopaque {
    //     _ = buffer;
    //     _ = offset;
    //     _ = size;
    //     unreachable;
    // }

    // pub inline fn bufferGetSize(buffer: *dgpu.Buffer) u64 {
    //     _ = buffer;
    //     unreachable;
    // }

    // pub inline fn bufferGetUsage(buffer: *dgpu.Buffer) dgpu.Buffer.UsageFlags {
    //     _ = buffer;
    //     unreachable;
    // }

    // pub inline fn bufferSetLabel(buffer: *dgpu.Buffer, label: [:0]const u8) void {
    //     _ = buffer;
    //     _ = label;
    //     unreachable;
    // }

    // pub inline fn bufferUnmap(buffer: *dgpu.Buffer) void {
    //     _ = buffer;
    //     unreachable;
    // }

    // pub inline fn bufferReference(buffer: *dgpu.Buffer) void {
    //     _ = buffer;
    //     unreachable;
    // }

    // pub inline fn bufferRelease(buffer: *dgpu.Buffer) void {
    //     _ = buffer;
    //     unreachable;
    // }

    // pub inline fn commandBufferSetLabel(command_buffer: *dgpu.CommandBuffer, label: [:0]const u8) void {
    //     _ = command_buffer;
    //     _ = label;
    //     unreachable;
    // }

    // pub inline fn commandBufferReference(command_buffer: *dgpu.CommandBuffer) void {
    //     _ = command_buffer;
    //     unreachable;
    // }

    // pub inline fn commandBufferRelease(command_buffer: *dgpu.CommandBuffer) void {
    //     _ = command_buffer;
    //     unreachable;
    // }

    // pub inline fn commandEncoderBeginComputePass(command_encoder: *dgpu.CommandEncoder, descriptor: dgpu.ComputePassDescriptor) *dgpu.ComputePassEncoder {
    //     _ = command_encoder;
    //     _ = descriptor;
    //     unreachable;
    // }

    // pub inline fn commandEncoderBeginRenderPass(command_encoder: *dgpu.CommandEncoder, descriptor: dgpu.RenderPassDescriptor) *dgpu.RenderPassEncoder {
    //     _ = command_encoder;
    //     _ = descriptor;
    //     unreachable;
    // }

    // pub inline fn commandEncoderClearBuffer(command_encoder: *dgpu.CommandEncoder, buffer: *dgpu.Buffer, offset: u64, size: u64) void {
    //     _ = command_encoder;
    //     _ = buffer;
    //     _ = offset;
    //     _ = size;
    //     unreachable;
    // }

    // pub inline fn commandEncoderCopyBufferToBuffer(command_encoder: *dgpu.CommandEncoder, source: *dgpu.Buffer, source_offset: u64, destination: *dgpu.Buffer, destination_offset: u64, size: u64) void {
    //     _ = command_encoder;
    //     _ = source;
    //     _ = source_offset;
    //     _ = destination;
    //     _ = destination_offset;
    //     _ = size;
    //     unreachable;
    // }

    // pub inline fn commandEncoderCopyBufferToTexture(command_encoder: *dgpu.CommandEncoder, source: *const dgpu.ImageCopyBuffer, destination: *const dgpu.ImageCopyTexture, copy_size: *const dgpu.Extent3D) void {
    //     _ = command_encoder;
    //     _ = source;
    //     _ = destination;
    //     _ = copy_size;
    //     unreachable;
    // }

    // pub inline fn commandEncoderCopyTextureToBuffer(command_encoder: *dgpu.CommandEncoder, source: *const dgpu.ImageCopyTexture, destination: *const dgpu.ImageCopyBuffer, copy_size: *const dgpu.Extent3D) void {
    //     _ = command_encoder;
    //     _ = source;
    //     _ = destination;
    //     _ = copy_size;
    //     unreachable;
    // }

    // pub inline fn commandEncoderCopyTextureToTexture(command_encoder: *dgpu.CommandEncoder, source: *const dgpu.ImageCopyTexture, destination: *const dgpu.ImageCopyTexture, copy_size: *const dgpu.Extent3D) void {
    //     _ = command_encoder;
    //     _ = source;
    //     _ = destination;
    //     _ = copy_size;
    //     unreachable;
    // }

    // pub inline fn commandEncoderFinish(command_encoder: *dgpu.CommandEncoder, descriptor: dgpu.CommandBuffer.Descriptor) *dgpu.CommandBuffer {
    //     _ = command_encoder;
    //     _ = descriptor;
    //     unreachable;
    // }

    // pub inline fn commandEncoderInjectValidationError(command_encoder: *dgpu.CommandEncoder, message: [*:0]const u8) void {
    //     _ = command_encoder;
    //     _ = message;
    //     unreachable;
    // }

    // pub inline fn commandEncoderInsertDebugMarker(command_encoder: *dgpu.CommandEncoder, marker_label: [*:0]const u8) void {
    //     _ = command_encoder;
    //     _ = marker_label;
    //     unreachable;
    // }

    // pub inline fn commandEncoderPopDebugGroup(command_encoder: *dgpu.CommandEncoder) void {
    //     _ = command_encoder;
    //     unreachable;
    // }

    // pub inline fn commandEncoderPushDebugGroup(command_encoder: *dgpu.CommandEncoder, group_label: [*:0]const u8) void {
    //     _ = command_encoder;
    //     _ = group_label;
    //     unreachable;
    // }

    // pub inline fn commandEncoderResolveQuerySet(command_encoder: *dgpu.CommandEncoder, query_set: *dgpu.QuerySet, first_query: u32, query_count: u32, destination: *dgpu.Buffer, destination_offset: u64) void {
    //     _ = command_encoder;
    //     _ = query_set;
    //     _ = first_query;
    //     _ = query_count;
    //     _ = destination;
    //     _ = destination_offset;
    //     unreachable;
    // }

    // pub inline fn commandEncoderSetLabel(command_encoder: *dgpu.CommandEncoder, label: [:0]const u8) void {
    //     _ = command_encoder;
    //     _ = label;
    //     unreachable;
    // }

    // pub inline fn commandEncoderWriteBuffer(command_encoder: *dgpu.CommandEncoder, buffer: *dgpu.Buffer, buffer_offset: u64, data: [*]const u8, size: u64) void {
    //     _ = command_encoder;
    //     _ = buffer;
    //     _ = buffer_offset;
    //     _ = data;
    //     _ = size;
    //     unreachable;
    // }

    // pub inline fn commandEncoderWriteTimestamp(command_encoder: *dgpu.CommandEncoder, query_set: *dgpu.QuerySet, query_index: u32) void {
    //     _ = command_encoder;
    //     _ = query_set;
    //     _ = query_index;
    //     unreachable;
    // }

    // pub inline fn commandEncoderReference(command_encoder: *dgpu.CommandEncoder) void {
    //     _ = command_encoder;
    //     unreachable;
    // }

    // pub inline fn commandEncoderRelease(command_encoder: *dgpu.CommandEncoder) void {
    //     _ = command_encoder;
    //     unreachable;
    // }

    // pub inline fn computePassEncoderDispatchWorkgroups(compute_pass_encoder: *dgpu.ComputePassEncoder, workgroup_count_x: u32, workgroup_count_y: u32, workgroup_count_z: u32) void {
    //     _ = compute_pass_encoder;
    //     _ = workgroup_count_x;
    //     _ = workgroup_count_y;
    //     _ = workgroup_count_z;
    //     unreachable;
    // }

    // pub inline fn computePassEncoderDispatchWorkgroupsIndirect(compute_pass_encoder: *dgpu.ComputePassEncoder, indirect_buffer: *dgpu.Buffer, indirect_offset: u64) void {
    //     _ = compute_pass_encoder;
    //     _ = indirect_buffer;
    //     _ = indirect_offset;
    //     unreachable;
    // }

    // pub inline fn computePassEncoderEnd(compute_pass_encoder: *dgpu.ComputePassEncoder) void {
    //     _ = compute_pass_encoder;
    //     unreachable;
    // }

    // pub inline fn computePassEncoderInsertDebugMarker(compute_pass_encoder: *dgpu.ComputePassEncoder, marker_label: [*:0]const u8) void {
    //     _ = compute_pass_encoder;
    //     _ = marker_label;
    //     unreachable;
    // }

    // pub inline fn computePassEncoderPopDebugGroup(compute_pass_encoder: *dgpu.ComputePassEncoder) void {
    //     _ = compute_pass_encoder;
    //     unreachable;
    // }

    // pub inline fn computePassEncoderPushDebugGroup(compute_pass_encoder: *dgpu.ComputePassEncoder, group_label: [*:0]const u8) void {
    //     _ = compute_pass_encoder;
    //     _ = group_label;
    //     unreachable;
    // }

    // pub inline fn computePassEncoderSetBindGroup(compute_pass_encoder: *dgpu.ComputePassEncoder, group_index: u32, group: *dgpu.BindGroup, dynamic_offset_count: usize, dynamic_offsets: ?[*]const u32) void {
    //     _ = compute_pass_encoder;
    //     _ = group_index;
    //     _ = group;
    //     _ = dynamic_offset_count;
    //     _ = dynamic_offsets;
    //     unreachable;
    // }

    // pub inline fn computePassEncoderSetLabel(compute_pass_encoder: *dgpu.ComputePassEncoder, label: [:0]const u8) void {
    //     _ = compute_pass_encoder;
    //     _ = label;
    //     unreachable;
    // }

    // pub inline fn computePassEncoderSetPipeline(compute_pass_encoder: *dgpu.ComputePassEncoder, pipeline: *dgpu.ComputePipeline) void {
    //     _ = compute_pass_encoder;
    //     _ = pipeline;
    //     unreachable;
    // }

    // pub inline fn computePassEncoderWriteTimestamp(compute_pass_encoder: *dgpu.ComputePassEncoder, query_set: *dgpu.QuerySet, query_index: u32) void {
    //     _ = compute_pass_encoder;
    //     _ = query_set;
    //     _ = query_index;
    //     unreachable;
    // }

    // pub inline fn computePassEncoderReference(compute_pass_encoder: *dgpu.ComputePassEncoder) void {
    //     _ = compute_pass_encoder;
    //     unreachable;
    // }

    // pub inline fn computePassEncoderRelease(compute_pass_encoder: *dgpu.ComputePassEncoder) void {
    //     _ = compute_pass_encoder;
    //     unreachable;
    // }

    // pub inline fn computePipelineGetBindGroupLayout(compute_pipeline: *dgpu.ComputePipeline, group_index: u32) *dgpu.BindGroupLayout {
    //     _ = compute_pipeline;
    //     _ = group_index;
    //     unreachable;
    // }

    // pub inline fn computePipelineSetLabel(compute_pipeline: *dgpu.ComputePipeline, label: [:0]const u8) void {
    //     _ = compute_pipeline;
    //     _ = label;
    //     unreachable;
    // }

    // pub inline fn computePipelineReference(compute_pipeline: *dgpu.ComputePipeline) void {
    //     _ = compute_pipeline;
    //     unreachable;
    // }

    // pub inline fn computePipelineRelease(compute_pipeline: *dgpu.ComputePipeline) void {
    //     _ = compute_pipeline;
    //     unreachable;
    // }

    // pub inline fn deviceCreateBindGroup(device: *dgpu.Device, descriptor: dgpu.BindGroup.Descriptor) *dgpu.BindGroup {
    //     _ = device;
    //     _ = descriptor;
    //     unreachable;
    // }

    // pub inline fn deviceCreateBindGroupLayout(device: *dgpu.Device, descriptor: dgpu.BindGroupLayout.Descriptor) *dgpu.BindGroupLayout {
    //     _ = device;
    //     _ = descriptor;
    //     unreachable;
    // }

    // pub inline fn deviceCreateBuffer(device: *dgpu.Device, descriptor: dgpu.Buffer.Descriptor) *dgpu.Buffer {
    //     _ = device;
    //     _ = descriptor;
    //     unreachable;
    // }

    // pub inline fn deviceCreateCommandEncoder(device: *dgpu.Device, descriptor: dgpu.CommandEncoder.Descriptor) *dgpu.CommandEncoder {
    //     _ = device;
    //     _ = descriptor;
    //     unreachable;
    // }

    // pub inline fn deviceCreateComputePipeline(device: *dgpu.Device, descriptor: dgpu.ComputePipeline.Descriptor) *dgpu.ComputePipeline {
    //     _ = device;
    //     _ = descriptor;
    //     unreachable;
    // }

    // pub inline fn deviceCreateErrorBuffer(device: *dgpu.Device, descriptor: dgpu.Buffer.Descriptor) *dgpu.Buffer {
    //     _ = device;
    //     _ = descriptor;
    //     unreachable;
    // }

    // pub inline fn deviceCreateErrorExternalTexture(device: *dgpu.Device) *dgpu.ExternalTexture {
    //     _ = device;
    //     unreachable;
    // }

    // pub inline fn deviceCreateErrorTexture(device: *dgpu.Device, descriptor: dgpu.Texture.Descriptor) *dgpu.Texture {
    //     _ = device;
    //     _ = descriptor;
    //     unreachable;
    // }

    // pub inline fn deviceCreateExternalTexture(device: *dgpu.Device, descriptor: dgpu.ExternalTexture.Descriptor) *dgpu.ExternalTexture {
    //     _ = device;
    //     _ = external_texture_descriptor;
    //     unreachable;
    // }

    // pub inline fn deviceCreatePipelineLayout(device: *dgpu.Device, descriptor: dgpu.PipelineLayout.Descriptor) *dgpu.PipelineLayout {
    //     _ = device;
    //     _ = pipeline_layout_descriptor;
    //     unreachable;
    // }

    // pub inline fn deviceCreateQuerySet(device: *dgpu.Device, descriptor: dgpu.QuerySet.Descriptor) *dgpu.QuerySet {
    //     _ = device;
    //     _ = descriptor;
    //     unreachable;
    // }

    // pub inline fn deviceCreateRenderBundleEncoder(device: *dgpu.Device, descriptor: dgpu.RenderBundleEncoder.Descriptor) *dgpu.RenderBundleEncoder {
    //     _ = device;
    //     _ = descriptor;
    //     unreachable;
    // }

    // pub inline fn deviceCreateRenderPipeline(device: *dgpu.Device, descriptor: dgpu.RenderPipeline.Descriptor) *dgpu.RenderPipeline {
    //     _ = device;
    //     _ = descriptor;
    //     unreachable;
    // }

    // // TODO(self-hosted): this cannot be marked as inline for some reason.
    // // https://github.com/ziglang/zig/issues/12545
    // pub fn deviceCreateSampler(device: *dgpu.Device, descriptor: dgpu.Sampler.Descriptor) *dgpu.Sampler {
    //     _ = device;
    //     _ = descriptor;
    //     unreachable;
    // }

    // pub inline fn deviceCreateShaderModule(device: *dgpu.Device, descriptor: dgpu.ShaderModule.Descriptor) *dgpu.ShaderModule {
    //     _ = device;
    //     _ = descriptor;
    //     unreachable;
    // }

    // pub inline fn deviceCreateSwapChain(device: *dgpu.Device, surface: ?*dgpu.Surface, descriptor: dgpu.SwapChain.Descriptor) *dgpu.SwapChain {
    //     _ = device;
    //     _ = surface;
    //     _ = descriptor;
    //     unreachable;
    // }

    // pub inline fn deviceCreateTexture(device: *dgpu.Device, descriptor: dgpu.Texture.Descriptor) *dgpu.Texture {
    //     _ = device;
    //     _ = descriptor;
    //     unreachable;
    // }

    // pub inline fn deviceDestroy(device: *dgpu.Device) void {
    //     _ = device;
    //     unreachable;
    // }

    // pub inline fn deviceEnumerateFeatures(device: *dgpu.Device, features: ?[*]dgpu.FeatureName) usize {
    //     _ = device;
    //     _ = features;
    //     unreachable;
    // }

    // pub inline fn deviceGetLimits(device: *dgpu.Device, limits: *dgpu.Limits) u32 {
    //     _ = device;
    //     _ = limits;
    //     unreachable;
    // }

    // pub inline fn deviceGetQueue(device: *dgpu.Device) *dgpu.Queue {
    //     _ = device;
    //     unreachable;
    // }

    // pub inline fn deviceHasFeature(device: *dgpu.Device, feature: dgpu.FeatureName) u32 {
    //     _ = device;
    //     _ = feature;
    //     unreachable;
    // }

    // pub inline fn deviceImportSharedFence(device: *dgpu.Device, descriptor: dgpu.SharedFence.Descriptor) *dgpu.SharedFence {
    //     _ = device;
    //     _ = descriptor;
    //     unreachable;
    // }

    // pub inline fn deviceImportSharedTextureMemory(device: *dgpu.Device, descriptor: dgpu.SharedTextureMemory.Descriptor) *dgpu.SharedTextureMemory {
    //     _ = device;
    //     _ = descriptor;
    //     unreachable;
    // }

    // pub inline fn deviceInjectError(device: *dgpu.Device, typ: dgpu.ErrorType, message: [*:0]const u8) void {
    //     _ = device;
    //     _ = typ;
    //     _ = message;
    //     unreachable;
    // }

    // pub inline fn deviceLoseForTesting(device: *dgpu.Device) void {
    //     _ = device;
    //     unreachable;
    // }

    // pub inline fn devicePopErrorScope(device: *dgpu.Device, callback: dgpu.ErrorCallback, userdata: ?*anyopaque) void {
    //     _ = device;
    //     _ = callback;
    //     _ = userdata;
    //     unreachable;
    // }

    // pub inline fn devicePushErrorScope(device: *dgpu.Device, filter: dgpu.ErrorFilter) void {
    //     _ = device;
    //     _ = filter;
    //     unreachable;
    // }

    // pub inline fn deviceSetDeviceLostCallback(device: *dgpu.Device, callback: ?dgpu.Device.LostCallback, userdata: ?*anyopaque) void {
    //     _ = device;
    //     _ = callback;
    //     _ = userdata;
    //     unreachable;
    // }

    // pub inline fn deviceSetLabel(device: *dgpu.Device, label: [:0]const u8) void {
    //     _ = device;
    //     _ = label;
    //     unreachable;
    // }

    // pub inline fn deviceSetLoggingCallback(device: *dgpu.Device, callback: ?dgpu.LoggingCallback, userdata: ?*anyopaque) void {
    //     _ = device;
    //     _ = callback;
    //     _ = userdata;
    //     unreachable;
    // }

    // pub inline fn deviceSetUncapturedErrorCallback(device: *dgpu.Device, callback: ?dgpu.ErrorCallback, userdata: ?*anyopaque) void {
    //     _ = device;
    //     _ = callback;
    //     _ = userdata;
    //     unreachable;
    // }

    // pub inline fn deviceTick(device: *dgpu.Device) void {
    //     _ = device;
    //     unreachable;
    // }

    // pub inline fn machDeviceWaitForCommandsToBeScheduled(device: *dgpu.Device) void {
    //     _ = device;
    //     unreachable;
    // }

    // pub inline fn deviceReference(device: *dgpu.Device) void {
    //     _ = device;
    //     unreachable;
    // }

    // pub inline fn deviceRelease(device: *dgpu.Device) void {
    //     _ = device;
    //     unreachable;
    // }

    // pub inline fn externalTextureDestroy(external_texture: *dgpu.ExternalTexture) void {
    //     _ = external_texture;
    //     unreachable;
    // }

    // pub inline fn externalTextureSetLabel(external_texture: *dgpu.ExternalTexture, label: [:0]const u8) void {
    //     _ = external_texture;
    //     _ = label;
    //     unreachable;
    // }

    // pub inline fn externalTextureReference(external_texture: *dgpu.ExternalTexture) void {
    //     _ = external_texture;
    //     unreachable;
    // }

    // pub inline fn externalTextureRelease(external_texture: *dgpu.ExternalTexture) void {
    //     _ = external_texture;
    //     unreachable;
    // }

    // pub inline fn instanceCreateSurface(instance: *dgpu.Instance, descriptor: dgpu.Surface.Descriptor) *dgpu.Surface {
    //     _ = instance;
    //     _ = descriptor;
    //     unreachable;
    // }

    // pub inline fn instanceProcessEvents(instance: *dgpu.Instance) void {
    //     _ = instance;
    //     unreachable;
    // }

    // pub inline fn instanceCreateAdapter(instance: *dgpu.Instance, descriptor: dgpu.Adapter.Descriptor) *dgpu.Adapter {
    //     _ = instance;
    //     _ = descriptor;
    //     unreachable;
    // }

    // pub inline fn instanceReference(instance: *dgpu.Instance) void {
    //     _ = instance;
    //     unreachable;
    // }

    // pub inline fn instanceRelease(instance: *dgpu.Instance) void {
    //     _ = instance;
    //     unreachable;
    // }

    // pub inline fn pipelineLayoutSetLabel(pipeline_layout: *dgpu.PipelineLayout, label: [:0]const u8) void {
    //     _ = pipeline_layout;
    //     _ = label;
    //     unreachable;
    // }

    // pub inline fn pipelineLayoutReference(pipeline_layout: *dgpu.PipelineLayout) void {
    //     _ = pipeline_layout;
    //     unreachable;
    // }

    // pub inline fn pipelineLayoutRelease(pipeline_layout: *dgpu.PipelineLayout) void {
    //     _ = pipeline_layout;
    //     unreachable;
    // }

    // pub inline fn querySetDestroy(query_set: *dgpu.QuerySet) void {
    //     _ = query_set;
    //     unreachable;
    // }

    // pub inline fn querySetGetCount(query_set: *dgpu.QuerySet) u32 {
    //     _ = query_set;
    //     unreachable;
    // }

    // pub inline fn querySetGetType(query_set: *dgpu.QuerySet) dgpu.QueryType {
    //     _ = query_set;
    //     unreachable;
    // }

    // pub inline fn querySetSetLabel(query_set: *dgpu.QuerySet, label: [:0]const u8) void {
    //     _ = query_set;
    //     _ = label;
    //     unreachable;
    // }

    // pub inline fn querySetReference(query_set: *dgpu.QuerySet) void {
    //     _ = query_set;
    //     unreachable;
    // }

    // pub inline fn querySetRelease(query_set: *dgpu.QuerySet) void {
    //     _ = query_set;
    //     unreachable;
    // }

    // pub inline fn queueCopyTextureForBrowser(queue: *dgpu.Queue, source: *const dgpu.ImageCopyTexture, destination: *const dgpu.ImageCopyTexture, copy_size: *const dgpu.Extent3D, options: *const dgpu.CopyTextureForBrowserOptions) void {
    //     _ = queue;
    //     _ = source;
    //     _ = destination;
    //     _ = copy_size;
    //     _ = options;
    //     unreachable;
    // }

    // pub inline fn queueOnSubmittedWorkDone(queue: *dgpu.Queue, signal_value: u64, callback: dgpu.Queue.WorkDoneCallback, userdata: ?*anyopaque) void {
    //     _ = queue;
    //     _ = signal_value;
    //     _ = callback;
    //     _ = userdata;
    //     unreachable;
    // }

    // pub inline fn queueSetLabel(queue: *dgpu.Queue, label: [:0]const u8) void {
    //     _ = queue;
    //     _ = label;
    //     unreachable;
    // }

    // pub inline fn queueSubmit(queue: *dgpu.Queue, command_count: usize, commands: [*]const *const dgpu.CommandBuffer) void {
    //     _ = queue;
    //     _ = command_count;
    //     _ = commands;
    //     unreachable;
    // }

    // pub inline fn queueWriteBuffer(queue: *dgpu.Queue, buffer: *dgpu.Buffer, buffer_offset: u64, data: *const anyopaque, size: usize) void {
    //     _ = queue;
    //     _ = buffer;
    //     _ = buffer_offset;
    //     _ = data;
    //     _ = size;
    //     unreachable;
    // }

    // pub inline fn queueWriteTexture(queue: *dgpu.Queue, destination: *const dgpu.ImageCopyTexture, data: *const anyopaque, data_size: usize, data_layout: *const dgpu.Texture.DataLayout, write_size: *const dgpu.Extent3D) void {
    //     _ = queue;
    //     _ = destination;
    //     _ = data;
    //     _ = data_size;
    //     _ = data_layout;
    //     _ = write_size;
    //     unreachable;
    // }

    // pub inline fn queueReference(queue: *dgpu.Queue) void {
    //     _ = queue;
    //     unreachable;
    // }

    // pub inline fn queueRelease(queue: *dgpu.Queue) void {
    //     _ = queue;
    //     unreachable;
    // }

    // pub inline fn renderBundleSetLabel(render_bundle: *dgpu.RenderBundle, label: [:0]const u8) void {
    //     _ = render_bundle;
    //     _ = label;
    //     unreachable;
    // }

    // pub inline fn renderBundleReference(render_bundle: *dgpu.RenderBundle) void {
    //     _ = render_bundle;
    //     unreachable;
    // }

    // pub inline fn renderBundleRelease(render_bundle: *dgpu.RenderBundle) void {
    //     _ = render_bundle;
    //     unreachable;
    // }

    // pub inline fn renderBundleEncoderDraw(render_bundle_encoder: *dgpu.RenderBundleEncoder, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void {
    //     _ = render_bundle_encoder;
    //     _ = vertex_count;
    //     _ = instance_count;
    //     _ = first_vertex;
    //     _ = first_instance;
    //     unreachable;
    // }

    // pub inline fn renderBundleEncoderDrawIndexed(render_bundle_encoder: *dgpu.RenderBundleEncoder, index_count: u32, instance_count: u32, first_index: u32, base_vertex: i32, first_instance: u32) void {
    //     _ = render_bundle_encoder;
    //     _ = index_count;
    //     _ = instance_count;
    //     _ = first_index;
    //     _ = base_vertex;
    //     _ = first_instance;
    //     unreachable;
    // }

    // pub inline fn renderBundleEncoderDrawIndexedIndirect(render_bundle_encoder: *dgpu.RenderBundleEncoder, indirect_buffer: *dgpu.Buffer, indirect_offset: u64) void {
    //     _ = render_bundle_encoder;
    //     _ = indirect_buffer;
    //     _ = indirect_offset;
    //     unreachable;
    // }

    // pub inline fn renderBundleEncoderDrawIndirect(render_bundle_encoder: *dgpu.RenderBundleEncoder, indirect_buffer: *dgpu.Buffer, indirect_offset: u64) void {
    //     _ = render_bundle_encoder;
    //     _ = indirect_buffer;
    //     _ = indirect_offset;
    //     unreachable;
    // }

    // pub inline fn renderBundleEncoderFinish(render_bundle_encoder: *dgpu.RenderBundleEncoder, descriptor: dgpu.RenderBundle.Descriptor) *dgpu.RenderBundle {
    //     _ = render_bundle_encoder;
    //     _ = descriptor;
    //     unreachable;
    // }

    // pub inline fn renderBundleEncoderInsertDebugMarker(render_bundle_encoder: *dgpu.RenderBundleEncoder, marker_label: [*:0]const u8) void {
    //     _ = render_bundle_encoder;
    //     _ = marker_label;
    //     unreachable;
    // }

    // pub inline fn renderBundleEncoderPopDebugGroup(render_bundle_encoder: *dgpu.RenderBundleEncoder) void {
    //     _ = render_bundle_encoder;
    //     unreachable;
    // }

    // pub inline fn renderBundleEncoderPushDebugGroup(render_bundle_encoder: *dgpu.RenderBundleEncoder, group_label: [*:0]const u8) void {
    //     _ = render_bundle_encoder;
    //     _ = group_label;
    //     unreachable;
    // }

    // pub inline fn renderBundleEncoderSetBindGroup(render_bundle_encoder: *dgpu.RenderBundleEncoder, group_index: u32, group: *dgpu.BindGroup, dynamic_offset_count: usize, dynamic_offsets: ?[*]const u32) void {
    //     _ = render_bundle_encoder;
    //     _ = group_index;
    //     _ = group;
    //     _ = dynamic_offset_count;
    //     _ = dynamic_offsets;
    //     unreachable;
    // }

    // pub inline fn renderBundleEncoderSetIndexBuffer(render_bundle_encoder: *dgpu.RenderBundleEncoder, buffer: *dgpu.Buffer, format: dgpu.IndexFormat, offset: u64, size: u64) void {
    //     _ = render_bundle_encoder;
    //     _ = buffer;
    //     _ = format;
    //     _ = offset;
    //     _ = size;
    //     unreachable;
    // }

    // pub inline fn renderBundleEncoderSetLabel(render_bundle_encoder: *dgpu.RenderBundleEncoder, label: [:0]const u8) void {
    //     _ = render_bundle_encoder;
    //     _ = label;
    //     unreachable;
    // }

    // pub inline fn renderBundleEncoderSetPipeline(render_bundle_encoder: *dgpu.RenderBundleEncoder, pipeline: *dgpu.RenderPipeline) void {
    //     _ = render_bundle_encoder;
    //     _ = pipeline;
    //     unreachable;
    // }

    // pub inline fn renderBundleEncoderSetVertexBuffer(render_bundle_encoder: *dgpu.RenderBundleEncoder, slot: u32, buffer: *dgpu.Buffer, offset: u64, size: u64) void {
    //     _ = render_bundle_encoder;
    //     _ = slot;
    //     _ = buffer;
    //     _ = offset;
    //     _ = size;
    //     unreachable;
    // }

    // pub inline fn renderBundleEncoderReference(render_bundle_encoder: *dgpu.RenderBundleEncoder) void {
    //     _ = render_bundle_encoder;
    //     unreachable;
    // }

    // pub inline fn renderBundleEncoderRelease(render_bundle_encoder: *dgpu.RenderBundleEncoder) void {
    //     _ = render_bundle_encoder;
    //     unreachable;
    // }

    // pub inline fn renderPassEncoderBeginOcclusionQuery(render_pass_encoder: *dgpu.RenderPassEncoder, query_index: u32) void {
    //     _ = render_pass_encoder;
    //     _ = query_index;
    //     unreachable;
    // }

    // pub inline fn renderPassEncoderDraw(render_pass_encoder: *dgpu.RenderPassEncoder, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void {
    //     _ = render_pass_encoder;
    //     _ = vertex_count;
    //     _ = instance_count;
    //     _ = first_vertex;
    //     _ = first_instance;
    //     unreachable;
    // }

    // pub inline fn renderPassEncoderDrawIndexed(render_pass_encoder: *dgpu.RenderPassEncoder, index_count: u32, instance_count: u32, first_index: u32, base_vertex: i32, first_instance: u32) void {
    //     _ = render_pass_encoder;
    //     _ = index_count;
    //     _ = instance_count;
    //     _ = first_index;
    //     _ = base_vertex;
    //     _ = first_instance;
    //     unreachable;
    // }

    // pub inline fn renderPassEncoderDrawIndexedIndirect(render_pass_encoder: *dgpu.RenderPassEncoder, indirect_buffer: *dgpu.Buffer, indirect_offset: u64) void {
    //     _ = render_pass_encoder;
    //     _ = indirect_buffer;
    //     _ = indirect_offset;
    //     unreachable;
    // }

    // pub inline fn renderPassEncoderDrawIndirect(render_pass_encoder: *dgpu.RenderPassEncoder, indirect_buffer: *dgpu.Buffer, indirect_offset: u64) void {
    //     _ = render_pass_encoder;
    //     _ = indirect_buffer;
    //     _ = indirect_offset;
    //     unreachable;
    // }

    // pub inline fn renderPassEncoderEnd(render_pass_encoder: *dgpu.RenderPassEncoder) void {
    //     _ = render_pass_encoder;
    //     unreachable;
    // }

    // pub inline fn renderPassEncoderEndOcclusionQuery(render_pass_encoder: *dgpu.RenderPassEncoder) void {
    //     _ = render_pass_encoder;
    //     unreachable;
    // }

    // pub inline fn renderPassEncoderExecuteBundles(render_pass_encoder: *dgpu.RenderPassEncoder, bundles_count: usize, bundles: [*]const *const dgpu.RenderBundle) void {
    //     _ = render_pass_encoder;
    //     _ = bundles_count;
    //     _ = bundles;
    //     unreachable;
    // }

    // pub inline fn renderPassEncoderInsertDebugMarker(render_pass_encoder: *dgpu.RenderPassEncoder, marker_label: [*:0]const u8) void {
    //     _ = render_pass_encoder;
    //     _ = marker_label;
    //     unreachable;
    // }

    // pub inline fn renderPassEncoderPopDebugGroup(render_pass_encoder: *dgpu.RenderPassEncoder) void {
    //     _ = render_pass_encoder;
    //     unreachable;
    // }

    // pub inline fn renderPassEncoderPushDebugGroup(render_pass_encoder: *dgpu.RenderPassEncoder, group_label: [*:0]const u8) void {
    //     _ = render_pass_encoder;
    //     _ = group_label;
    //     unreachable;
    // }

    // pub inline fn renderPassEncoderSetBindGroup(render_pass_encoder: *dgpu.RenderPassEncoder, group_index: u32, group: *dgpu.BindGroup, dynamic_offset_count: usize, dynamic_offsets: ?[*]const u32) void {
    //     _ = render_pass_encoder;
    //     _ = group_index;
    //     _ = group;
    //     _ = dynamic_offset_count;
    //     _ = dynamic_offsets;
    //     unreachable;
    // }

    // pub inline fn renderPassEncoderSetBlendConstant(render_pass_encoder: *dgpu.RenderPassEncoder, color: *const dgpu.Color) void {
    //     _ = render_pass_encoder;
    //     _ = color;
    //     unreachable;
    // }

    // pub inline fn renderPassEncoderSetIndexBuffer(render_pass_encoder: *dgpu.RenderPassEncoder, buffer: *dgpu.Buffer, format: dgpu.IndexFormat, offset: u64, size: u64) void {
    //     _ = render_pass_encoder;
    //     _ = buffer;
    //     _ = format;
    //     _ = offset;
    //     _ = size;
    //     unreachable;
    // }

    // pub inline fn renderPassEncoderSetLabel(render_pass_encoder: *dgpu.RenderPassEncoder, label: [:0]const u8) void {
    //     _ = render_pass_encoder;
    //     _ = label;
    //     unreachable;
    // }

    // pub inline fn renderPassEncoderSetPipeline(render_pass_encoder: *dgpu.RenderPassEncoder, pipeline: *dgpu.RenderPipeline) void {
    //     _ = render_pass_encoder;
    //     _ = pipeline;
    //     unreachable;
    // }

    // pub inline fn renderPassEncoderSetScissorRect(render_pass_encoder: *dgpu.RenderPassEncoder, x: u32, y: u32, width: u32, height: u32) void {
    //     _ = render_pass_encoder;
    //     _ = x;
    //     _ = y;
    //     _ = width;
    //     _ = height;
    //     unreachable;
    // }

    // pub inline fn renderPassEncoderSetStencilReference(render_pass_encoder: *dgpu.RenderPassEncoder, reference: u32) void {
    //     _ = render_pass_encoder;
    //     _ = reference;
    //     unreachable;
    // }

    // pub inline fn renderPassEncoderSetVertexBuffer(render_pass_encoder: *dgpu.RenderPassEncoder, slot: u32, buffer: *dgpu.Buffer, offset: u64, size: u64) void {
    //     _ = render_pass_encoder;
    //     _ = slot;
    //     _ = buffer;
    //     _ = offset;
    //     _ = size;
    //     unreachable;
    // }

    // pub inline fn renderPassEncoderSetViewport(render_pass_encoder: *dgpu.RenderPassEncoder, x: f32, y: f32, width: f32, height: f32, min_depth: f32, max_depth: f32) void {
    //     _ = render_pass_encoder;
    //     _ = x;
    //     _ = y;
    //     _ = width;
    //     _ = height;
    //     _ = min_depth;
    //     _ = max_depth;
    //     unreachable;
    // }

    // pub inline fn renderPassEncoderWriteTimestamp(render_pass_encoder: *dgpu.RenderPassEncoder, query_set: *dgpu.QuerySet, query_index: u32) void {
    //     _ = render_pass_encoder;
    //     _ = query_set;
    //     _ = query_index;
    //     unreachable;
    // }

    // pub inline fn renderPassEncoderReference(render_pass_encoder: *dgpu.RenderPassEncoder) void {
    //     _ = render_pass_encoder;
    //     unreachable;
    // }

    // pub inline fn renderPassEncoderRelease(render_pass_encoder: *dgpu.RenderPassEncoder) void {
    //     _ = render_pass_encoder;
    //     unreachable;
    // }

    // pub inline fn renderPipelineGetBindGroupLayout(render_pipeline: *dgpu.RenderPipeline, group_index: u32) *dgpu.BindGroupLayout {
    //     _ = render_pipeline;
    //     _ = group_index;
    //     unreachable;
    // }

    // pub inline fn renderPipelineSetLabel(render_pipeline: *dgpu.RenderPipeline, label: [:0]const u8) void {
    //     _ = render_pipeline;
    //     _ = label;
    //     unreachable;
    // }

    // pub inline fn renderPipelineReference(render_pipeline: *dgpu.RenderPipeline) void {
    //     _ = render_pipeline;
    //     unreachable;
    // }

    // pub inline fn renderPipelineRelease(render_pipeline: *dgpu.RenderPipeline) void {
    //     _ = render_pipeline;
    //     unreachable;
    // }

    // pub inline fn samplerSetLabel(sampler: *dgpu.Sampler, label: [:0]const u8) void {
    //     _ = sampler;
    //     _ = label;
    //     unreachable;
    // }

    // pub inline fn samplerReference(sampler: *dgpu.Sampler) void {
    //     _ = sampler;
    //     unreachable;
    // }

    // pub inline fn samplerRelease(sampler: *dgpu.Sampler) void {
    //     _ = sampler;
    //     unreachable;
    // }

    // pub inline fn shaderModuleGetCompilationInfo(shader_module: *dgpu.ShaderModule, callback: dgpu.CompilationInfoCallback, userdata: ?*anyopaque) void {
    //     _ = shader_module;
    //     _ = callback;
    //     _ = userdata;
    //     unreachable;
    // }

    // pub inline fn shaderModuleSetLabel(shader_module: *dgpu.ShaderModule, label: [:0]const u8) void {
    //     _ = shader_module;
    //     _ = label;
    //     unreachable;
    // }

    // pub inline fn shaderModuleReference(shader_module: *dgpu.ShaderModule) void {
    //     _ = shader_module;
    //     unreachable;
    // }

    // pub inline fn shaderModuleRelease(shader_module: *dgpu.ShaderModule) void {
    //     _ = shader_module;
    //     unreachable;
    // }

    // pub inline fn sharedFenceExportInfo(shared_fence: *dgpu.SharedFence, info: *dgpu.SharedFence.ExportInfo) void {
    //     _ = shared_fence;
    //     _ = info;
    //     unreachable;
    // }

    // pub inline fn sharedFenceReference(shared_fence: *dgpu.SharedFence) void {
    //     _ = shared_fence;
    //     unreachable;
    // }

    // pub inline fn sharedFenceRelease(shared_fence: *dgpu.SharedFence) void {
    //     _ = shared_fence;
    //     unreachable;
    // }

    // pub inline fn sharedTextureMemoryBeginAccess(shared_texture_memory: *dgpu.SharedTextureMemory, texture: *dgpu.Texture, descriptor: dgpu.SharedTextureMemory.BeginAccessDescriptor) void {
    //     _ = shared_texture_memory;
    //     _ = texture;
    //     _ = descriptor;
    //     unreachable;
    // }

    // pub inline fn sharedTextureMemoryCreateTexture(shared_texture_memory: *dgpu.SharedTextureMemory, descriptor: dgpu.Texture.Descriptor) *dgpu.Texture {
    //     _ = shared_texture_memory;
    //     _ = descriptor;
    //     unreachable;
    // }

    // pub inline fn sharedTextureMemoryEndAccess(shared_texture_memory: *dgpu.SharedTextureMemory, texture: *dgpu.Texture, descriptor: *dgpu.SharedTextureMemory.EndAccessState) void {
    //     _ = shared_texture_memory;
    //     _ = texture;
    //     _ = descriptor;
    //     unreachable;
    // }

    // pub inline fn sharedTextureMemoryEndAccessStateFreeMembers(value: dgpu.SharedTextureMemory.EndAccessState) void {
    //     _ = value;
    //     unreachable;
    // }

    // pub inline fn sharedTextureMemoryGetProperties(shared_texture_memory: *dgpu.SharedTextureMemory, properties: *dgpu.SharedTextureMemory.Properties) void {
    //     _ = shared_texture_memory;
    //     _ = properties;
    //     unreachable;
    // }

    // pub inline fn sharedTextureMemorySetLabel(shared_texture_memory: *dgpu.SharedTextureMemory, label: [:0]const u8) void {
    //     _ = shared_texture_memory;
    //     _ = label;
    //     unreachable;
    // }

    // pub inline fn sharedTextureMemoryReference(shared_texture_memory: *dgpu.SharedTextureMemory) void {
    //     _ = shared_texture_memory;
    //     unreachable;
    // }

    // pub inline fn sharedTextureMemoryRelease(shared_texture_memory: *dgpu.SharedTextureMemory) void {
    //     _ = shared_texture_memory;
    //     unreachable;
    // }

    // pub inline fn surfaceReference(surface: *dgpu.Surface) void {
    //     _ = surface;
    //     unreachable;
    // }

    // pub inline fn surfaceRelease(surface: *dgpu.Surface) void {
    //     _ = surface;
    //     unreachable;
    // }

    // pub inline fn swapChainGetCurrentTexture(swap_chain: *dgpu.SwapChain) ?*dgpu.Texture {
    //     _ = swap_chain;
    //     unreachable;
    // }

    // pub inline fn swapChainGetCurrentTextureView(swap_chain: *dgpu.SwapChain) ?*dgpu.TextureView {
    //     _ = swap_chain;
    //     unreachable;
    // }

    // pub inline fn swapChainPresent(swap_chain: *dgpu.SwapChain) void {
    //     _ = swap_chain;
    //     unreachable;
    // }

    // pub inline fn swapChainReference(swap_chain: *dgpu.SwapChain) void {
    //     _ = swap_chain;
    //     unreachable;
    // }

    // pub inline fn swapChainRelease(swap_chain: *dgpu.SwapChain) void {
    //     _ = swap_chain;
    //     unreachable;
    // }

    // pub inline fn textureCreateView(texture: *dgpu.Texture, descriptor: dgpu.TextureView.Descriptor) *dgpu.TextureView {
    //     _ = texture;
    //     _ = descriptor;
    //     unreachable;
    // }

    // pub inline fn textureDestroy(texture: *dgpu.Texture) void {
    //     _ = texture;
    //     unreachable;
    // }

    // pub inline fn textureGetDepthOrArrayLayers(texture: *dgpu.Texture) u32 {
    //     _ = texture;
    //     unreachable;
    // }

    // pub inline fn textureGetDimension(texture: *dgpu.Texture) dgpu.Texture.Dimension {
    //     _ = texture;
    //     unreachable;
    // }

    // pub inline fn textureGetFormat(texture: *dgpu.Texture) dgpu.Texture.Format {
    //     _ = texture;
    //     unreachable;
    // }

    // pub inline fn textureGetHeight(texture: *dgpu.Texture) u32 {
    //     _ = texture;
    //     unreachable;
    // }

    // pub inline fn textureGetMipLevelCount(texture: *dgpu.Texture) u32 {
    //     _ = texture;
    //     unreachable;
    // }

    // pub inline fn textureGetSampleCount(texture: *dgpu.Texture) u32 {
    //     _ = texture;
    //     unreachable;
    // }

    // pub inline fn textureGetUsage(texture: *dgpu.Texture) dgpu.Texture.UsageFlags {
    //     _ = texture;
    //     unreachable;
    // }

    // pub inline fn textureGetWidth(texture: *dgpu.Texture) u32 {
    //     _ = texture;
    //     unreachable;
    // }

    // pub inline fn textureSetLabel(texture: *dgpu.Texture, label: [:0]const u8) void {
    //     _ = texture;
    //     _ = label;
    //     unreachable;
    // }

    // pub inline fn textureReference(texture: *dgpu.Texture) void {
    //     _ = texture;
    //     unreachable;
    // }

    // pub inline fn textureRelease(texture: *dgpu.Texture) void {
    //     _ = texture;
    //     unreachable;
    // }

    // pub inline fn textureViewSetLabel(texture_view: *dgpu.TextureView, label: [:0]const u8) void {
    //     _ = texture_view;
    //     _ = label;
    //     unreachable;
    // }

    // pub inline fn textureViewReference(texture_view: *dgpu.TextureView) void {
    //     _ = texture_view;
    //     unreachable;
    // }

    // pub inline fn textureViewRelease(texture_view: *dgpu.TextureView) void {
    //     _ = texture_view;
    //     unreachable;
    // }
});

test "stub" {
    _ = StubInterface;
}
