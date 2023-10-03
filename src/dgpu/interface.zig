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
    // // dgpu.Device
    // assertDecl(T, "deviceCreateRenderPipeline", fn (device: *dgpu.Device, descriptor: dgpu.RenderPipeline.Descriptor) callconv(.Inline) *dgpu.RenderPipeline);
    // assertDecl(T, "deviceCreateRenderPipelineAsync", fn (device: *dgpu.Device, descriptor: dgpu.RenderPipeline.Descriptor, callback: dgpu.CreateRenderPipelineAsyncCallback, userdata: ?*anyopaque) callconv(.Inline) void);
    // assertDecl(T, "deviceCreatePipelineLayout", fn (device: *dgpu.Device, pipeline_layout_descriptor: *const dgpu.PipelineLayout.Descriptor) callconv(.Inline) *dgpu.PipelineLayout);

    // // dgpu.PipelineLayout
    // assertDecl(T, "pipelineLayoutSetLabel", fn (pipeline_layout: *dgpu.PipelineLayout, label: [:0]const u8) callconv(.Inline) void);
    // assertDecl(T, "pipelineLayoutReference", fn (pipeline_layout: *dgpu.PipelineLayout) callconv(.Inline) void);
    // assertDecl(T, "pipelineLayoutRelease", fn (pipeline_layout: *dgpu.PipelineLayout) callconv(.Inline) void);

    // // dgpu.RenderBundleEncoder
    // assertDecl(T, "renderBundleEncoderSetPipeline", fn (render_bundle_encoder: *dgpu.RenderBundleEncoder, pipeline: *dgpu.RenderPipeline) callconv(.Inline) void);
    // assertDecl(T, "renderBundleEncoderSetBindGroup", fn (render_bundle_encoder: *dgpu.RenderBundleEncoder, group_index: u32, group: *dgpu.BindGroup, dynamic_offset_count: usize, dynamic_offsets: ?[*]const u32) callconv(.Inline) void);

    // // dgpu.RenderPassEncoder
    // assertDecl(T, "renderPassEncoderSetPipeline", fn (render_pass_encoder: *dgpu.RenderPassEncoder, pipeline: *dgpu.RenderPipeline) callconv(.Inline) void);
    // assertDecl(T, "renderPassEncoderSetBindGroup", fn (render_pass_encoder: *dgpu.RenderPassEncoder, group_index: u32, group: *dgpu.BindGroup, dynamic_offset_count: usize, dynamic_offsets: ?[*]const u32) callconv(.Inline) void);

    // // dgpu.BindGroup
    // assertDecl(T, "bindGroupSetLabel", fn (bind_group: *dgpu.BindGroup, label: [:0]const u8) callconv(.Inline) void);
    // assertDecl(T, "bindGroupReference", fn (bind_group: *dgpu.BindGroup) callconv(.Inline) void);
    // assertDecl(T, "bindGroupRelease", fn (bind_group: *dgpu.BindGroup) callconv(.Inline) void);

    // // dgpu.BindGroupLayout
    // assertDecl(T, "bindGroupLayoutSetLabel", fn (bind_group_layout: *dgpu.BindGroupLayout, label: [:0]const u8) callconv(.Inline) void);
    // assertDecl(T, "bindGroupLayoutReference", fn (bind_group_layout: *dgpu.BindGroupLayout) callconv(.Inline) void);
    // assertDecl(T, "bindGroupLayoutRelease", fn (bind_group_layout: *dgpu.BindGroupLayout) callconv(.Inline) void);

    // // dgpu.RenderPipeline
    // assertDecl(T, "renderPipelineGetBindGroupLayout", fn (render_pipeline: *dgpu.RenderPipeline, group_index: u32) callconv(.Inline) *dgpu.BindGroupLayout);
    // assertDecl(T, "renderPipelineSetLabel", fn (render_pipeline: *dgpu.RenderPipeline, label: [:0]const u8) callconv(.Inline) void);
    // assertDecl(T, "renderPipelineReference", fn (render_pipeline: *dgpu.RenderPipeline) callconv(.Inline) void);
    // assertDecl(T, "renderPipelineRelease", fn (render_pipeline: *dgpu.RenderPipeline) callconv(.Inline) void);

    // // dgpu.Instance
    // assertDecl(T, "createInstance", fn (descriptor: dgpu.Instance.Descriptor) callconv(.Inline) ?*dgpu.Instance);

    // // dgpu.Adapter
    // assertDecl(T, "adapterCreateDevice", fn (adapter: *dgpu.Adapter, descriptor: dgpu.Device.Descriptor) callconv(.Inline) ?*dgpu.Device);
    // assertDecl(T, "adapterEnumerateFeatures", fn (adapter: *dgpu.Adapter, features: ?[*]dgpu.FeatureName) callconv(.Inline) usize);
    // assertDecl(T, "adapterGetInstance", fn (adapter: *dgpu.Adapter) callconv(.Inline) *dgpu.Instance);
    // assertDecl(T, "adapterGetLimits", fn (adapter: *dgpu.Adapter, limits: *dgpu.Limits) callconv(.Inline) u32);
    // assertDecl(T, "adapterGetProperties", fn (adapter: *dgpu.Adapter, properties: *dgpu.Adapter.Properties) callconv(.Inline) void);
    // assertDecl(T, "adapterHasFeature", fn (adapter: *dgpu.Adapter, feature: dgpu.FeatureName) callconv(.Inline) u32);
    // assertDecl(T, "adapterPropertiesFreeMembers", fn (value: dgpu.Adapter.Properties) callconv(.Inline) void);
    // assertDecl(T, "adapterRequestDevice", fn (adapter: *dgpu.Adapter, descriptor: dgpu.Device.Descriptor, callback: dgpu.RequestDeviceCallback, userdata: ?*anyopaque) callconv(.Inline) void);
    // assertDecl(T, "adapterReference", fn (adapter: *dgpu.Adapter) callconv(.Inline) void);
    // assertDecl(T, "adapterRelease", fn (adapter: *dgpu.Adapter) callconv(.Inline) void);

    // // dgpu.Buffer
    // assertDecl(T, "bufferDestroy", fn (buffer: *dgpu.Buffer) callconv(.Inline) void);
    // assertDecl(T, "bufferGetConstMappedRange", fn (buffer: *dgpu.Buffer, offset: usize, size: usize) callconv(.Inline) ?*const anyopaque);
    // assertDecl(T, "bufferGetMappedRange", fn (buffer: *dgpu.Buffer, offset: usize, size: usize) callconv(.Inline) ?*anyopaque);
    // assertDecl(T, "bufferGetSize", fn (buffer: *dgpu.Buffer) callconv(.Inline) u64);
    // assertDecl(T, "bufferGetUsage", fn (buffer: *dgpu.Buffer) callconv(.Inline) dgpu.Buffer.UsageFlags);
    // assertDecl(T, "bufferMapAsync", fn (buffer: *dgpu.Buffer, mode: dgpu.MapModeFlags, offset: usize, size: usize, callback: dgpu.Buffer.MapCallback, userdata: ?*anyopaque) callconv(.Inline) void);
    // assertDecl(T, "bufferSetLabel", fn (buffer: *dgpu.Buffer, label: [:0]const u8) callconv(.Inline) void);
    // assertDecl(T, "bufferUnmap", fn (buffer: *dgpu.Buffer) callconv(.Inline) void);
    // assertDecl(T, "bufferReference", fn (buffer: *dgpu.Buffer) callconv(.Inline) void);
    // assertDecl(T, "bufferRelease", fn (buffer: *dgpu.Buffer) callconv(.Inline) void);

    // // dgpu.CommandBuffer
    // assertDecl(T, "commandBufferSetLabel", fn (command_buffer: *dgpu.CommandBuffer, label: [:0]const u8) callconv(.Inline) void);
    // assertDecl(T, "commandBufferReference", fn (command_buffer: *dgpu.CommandBuffer) callconv(.Inline) void);
    // assertDecl(T, "commandBufferRelease", fn (command_buffer: *dgpu.CommandBuffer) callconv(.Inline) void);

    // // dgpu.CommandEncoder
    // assertDecl(T, "commandEncoderBeginComputePass", fn (command_encoder: *dgpu.CommandEncoder, descriptor: dgpu.ComputePassDescriptor) callconv(.Inline) *dgpu.ComputePassEncoder);
    // assertDecl(T, "commandEncoderBeginRenderPass", fn (command_encoder: *dgpu.CommandEncoder, descriptor: dgpu.RenderPassDescriptor) callconv(.Inline) *dgpu.RenderPassEncoder);
    // assertDecl(T, "commandEncoderClearBuffer", fn (command_encoder: *dgpu.CommandEncoder, buffer: *dgpu.Buffer, offset: u64, size: u64) callconv(.Inline) void);
    // assertDecl(T, "commandEncoderCopyBufferToBuffer", fn (command_encoder: *dgpu.CommandEncoder, source: *dgpu.Buffer, source_offset: u64, destination: *dgpu.Buffer, destination_offset: u64, size: u64) callconv(.Inline) void);
    // assertDecl(T, "commandEncoderCopyBufferToTexture", fn (command_encoder: *dgpu.CommandEncoder, source: *const dgpu.ImageCopyBuffer, destination: *const dgpu.ImageCopyTexture, copy_size: *const dgpu.Extent3D) callconv(.Inline) void);
    // assertDecl(T, "commandEncoderCopyTextureToBuffer", fn (command_encoder: *dgpu.CommandEncoder, source: *const dgpu.ImageCopyTexture, destination: *const dgpu.ImageCopyBuffer, copy_size: *const dgpu.Extent3D) callconv(.Inline) void);
    // assertDecl(T, "commandEncoderCopyTextureToTexture", fn (command_encoder: *dgpu.CommandEncoder, source: *const dgpu.ImageCopyTexture, destination: *const dgpu.ImageCopyTexture, copy_size: *const dgpu.Extent3D) callconv(.Inline) void);
    // assertDecl(T, "commandEncoderFinish", fn (command_encoder: *dgpu.CommandEncoder, descriptor: dgpu.CommandBuffer.Descriptor) callconv(.Inline) *dgpu.CommandBuffer);
    // assertDecl(T, "commandEncoderInjectValidationError", fn (command_encoder: *dgpu.CommandEncoder, message: [*:0]const u8) callconv(.Inline) void);
    // assertDecl(T, "commandEncoderInsertDebugMarker", fn (command_encoder: *dgpu.CommandEncoder, marker_label: [*:0]const u8) callconv(.Inline) void);
    // assertDecl(T, "commandEncoderPopDebugGroup", fn (command_encoder: *dgpu.CommandEncoder) callconv(.Inline) void);
    // assertDecl(T, "commandEncoderPushDebugGroup", fn (command_encoder: *dgpu.CommandEncoder, group_label: [*:0]const u8) callconv(.Inline) void);
    // assertDecl(T, "commandEncoderResolveQuerySet", fn (command_encoder: *dgpu.CommandEncoder, query_set: *dgpu.QuerySet, first_query: u32, query_count: u32, destination: *dgpu.Buffer, destination_offset: u64) callconv(.Inline) void);
    // assertDecl(T, "commandEncoderSetLabel", fn (command_encoder: *dgpu.CommandEncoder, label: [:0]const u8) callconv(.Inline) void);
    // assertDecl(T, "commandEncoderWriteBuffer", fn (command_encoder: *dgpu.CommandEncoder, buffer: *dgpu.Buffer, buffer_offset: u64, data: [*]const u8, size: u64) callconv(.Inline) void);
    // assertDecl(T, "commandEncoderWriteTimestamp", fn (command_encoder: *dgpu.CommandEncoder, query_set: *dgpu.QuerySet, query_index: u32) callconv(.Inline) void);
    // assertDecl(T, "commandEncoderReference", fn (command_encoder: *dgpu.CommandEncoder) callconv(.Inline) void);
    // assertDecl(T, "commandEncoderRelease", fn (command_encoder: *dgpu.CommandEncoder) callconv(.Inline) void);

    // // dgpu.ComputePassEncoder
    // assertDecl(T, "computePassEncoderDispatchWorkgroups", fn (compute_pass_encoder: *dgpu.ComputePassEncoder, workgroup_count_x: u32, workgroup_count_y: u32, workgroup_count_z: u32) callconv(.Inline) void);
    // assertDecl(T, "computePassEncoderDispatchWorkgroupsIndirect", fn (compute_pass_encoder: *dgpu.ComputePassEncoder, indirect_buffer: *dgpu.Buffer, indirect_offset: u64) callconv(.Inline) void);
    // assertDecl(T, "computePassEncoderEnd", fn (compute_pass_encoder: *dgpu.ComputePassEncoder) callconv(.Inline) void);
    // assertDecl(T, "computePassEncoderInsertDebugMarker", fn (compute_pass_encoder: *dgpu.ComputePassEncoder, marker_label: [*:0]const u8) callconv(.Inline) void);
    // assertDecl(T, "computePassEncoderPopDebugGroup", fn (compute_pass_encoder: *dgpu.ComputePassEncoder) callconv(.Inline) void);
    // assertDecl(T, "computePassEncoderPushDebugGroup", fn (compute_pass_encoder: *dgpu.ComputePassEncoder, group_label: [*:0]const u8) callconv(.Inline) void);
    // assertDecl(T, "computePassEncoderSetBindGroup", fn (compute_pass_encoder: *dgpu.ComputePassEncoder, group_index: u32, group: *dgpu.BindGroup, dynamic_offset_count: usize, dynamic_offsets: ?[*]const u32) callconv(.Inline) void);
    // assertDecl(T, "computePassEncoderSetLabel", fn (compute_pass_encoder: *dgpu.ComputePassEncoder, label: [:0]const u8) callconv(.Inline) void);
    // assertDecl(T, "computePassEncoderSetPipeline", fn (compute_pass_encoder: *dgpu.ComputePassEncoder, pipeline: *dgpu.ComputePipeline) callconv(.Inline) void);
    // assertDecl(T, "computePassEncoderWriteTimestamp", fn (compute_pass_encoder: *dgpu.ComputePassEncoder, query_set: *dgpu.QuerySet, query_index: u32) callconv(.Inline) void);
    // assertDecl(T, "computePassEncoderReference", fn (compute_pass_encoder: *dgpu.ComputePassEncoder) callconv(.Inline) void);
    // assertDecl(T, "computePassEncoderRelease", fn (compute_pass_encoder: *dgpu.ComputePassEncoder) callconv(.Inline) void);

    // // dgpu.ComputePipeline
    // assertDecl(T, "computePipelineGetBindGroupLayout", fn (compute_pipeline: *dgpu.ComputePipeline, group_index: u32) callconv(.Inline) *dgpu.BindGroupLayout);
    // assertDecl(T, "computePipelineSetLabel", fn (compute_pipeline: *dgpu.ComputePipeline, label: [:0]const u8) callconv(.Inline) void);
    // assertDecl(T, "computePipelineReference", fn (compute_pipeline: *dgpu.ComputePipeline) callconv(.Inline) void);
    // assertDecl(T, "computePipelineRelease", fn (compute_pipeline: *dgpu.ComputePipeline) callconv(.Inline) void);

    // // dgpu.Device
    // assertDecl(T, "getProcAddress", fn (device: *dgpu.Device, proc_name: [*:0]const u8) callconv(.Inline) ?dgpu.Proc);
    // assertDecl(T, "deviceCreateBindGroup", fn (device: *dgpu.Device, descriptor: dgpu.BindGroup.Descriptor) callconv(.Inline) *dgpu.BindGroup);
    // assertDecl(T, "deviceCreateBindGroupLayout", fn (device: *dgpu.Device, descriptor: dgpu.BindGroupLayout.Descriptor) callconv(.Inline) *dgpu.BindGroupLayout);
    // assertDecl(T, "deviceCreateBuffer", fn (device: *dgpu.Device, descriptor: dgpu.Buffer.Descriptor) callconv(.Inline) *dgpu.Buffer);
    // assertDecl(T, "deviceCreateCommandEncoder", fn (device: *dgpu.Device, descriptor: dgpu.CommandEncoder.Descriptor) callconv(.Inline) *dgpu.CommandEncoder);
    // assertDecl(T, "deviceCreateComputePipeline", fn (device: *dgpu.Device, descriptor: dgpu.ComputePipeline.Descriptor) callconv(.Inline) *dgpu.ComputePipeline);
    // assertDecl(T, "deviceCreateComputePipelineAsync", fn (device: *dgpu.Device, descriptor: dgpu.ComputePipeline.Descriptor, callback: dgpu.CreateComputePipelineAsyncCallback, userdata: ?*anyopaque) callconv(.Inline) void);
    // assertDecl(T, "deviceCreateErrorBuffer", fn (device: *dgpu.Device, descriptor: dgpu.Buffer.Descriptor) callconv(.Inline) *dgpu.Buffer);
    // assertDecl(T, "deviceCreateErrorExternalTexture", fn (device: *dgpu.Device) callconv(.Inline) *dgpu.ExternalTexture);
    // assertDecl(T, "deviceCreateErrorTexture", fn (device: *dgpu.Device, descriptor: dgpu.Texture.Descriptor) callconv(.Inline) *dgpu.Texture);
    // assertDecl(T, "deviceCreateExternalTexture", fn (device: *dgpu.Device, external_texture_descriptor: *const dgpu.ExternalTexture.Descriptor) callconv(.Inline) *dgpu.ExternalTexture);
    // assertDecl(T, "deviceCreateQuerySet", fn (device: *dgpu.Device, descriptor: dgpu.QuerySet.Descriptor) callconv(.Inline) *dgpu.QuerySet);
    // assertDecl(T, "deviceCreateRenderBundleEncoder", fn (device: *dgpu.Device, descriptor: dgpu.RenderBundleEncoder.Descriptor) callconv(.Inline) *dgpu.RenderBundleEncoder);
    // // TODO(self-hosted): this cannot be marked as inline for some reason:
    // // https://github.com/ziglang/zig/issues/12545
    // assertDecl(T, "deviceCreateSampler", fn (device: *dgpu.Device, descriptor: dgpu.Sampler.Descriptor) *dgpu.Sampler);
    // assertDecl(T, "deviceCreateShaderModule", fn (device: *dgpu.Device, descriptor: dgpu.ShaderModule.Descriptor) callconv(.Inline) *dgpu.ShaderModule);
    // assertDecl(T, "deviceCreateSwapChain", fn (device: *dgpu.Device, surface: ?*dgpu.Surface, descriptor: dgpu.SwapChain.Descriptor) callconv(.Inline) *dgpu.SwapChain);
    // assertDecl(T, "deviceCreateTexture", fn (device: *dgpu.Device, descriptor: dgpu.Texture.Descriptor) callconv(.Inline) *dgpu.Texture);
    // assertDecl(T, "deviceDestroy", fn (device: *dgpu.Device) callconv(.Inline) void);
    // assertDecl(T, "deviceEnumerateFeatures", fn (device: *dgpu.Device, features: ?[*]dgpu.FeatureName) callconv(.Inline) usize);
    // assertDecl(T, "deviceGetLimits", fn (device: *dgpu.Device, limits: *dgpu.Limits) callconv(.Inline) u32);
    // assertDecl(T, "deviceGetQueue", fn (device: *dgpu.Device) callconv(.Inline) *dgpu.Queue);
    // assertDecl(T, "deviceHasFeature", fn (device: *dgpu.Device, feature: dgpu.FeatureName) callconv(.Inline) u32);
    // assertDecl(T, "deviceImportSharedFence", fn (device: *dgpu.Device, descriptor: dgpu.SharedFence.Descriptor) callconv(.Inline) *dgpu.SharedFence);
    // assertDecl(T, "deviceImportSharedTextureMemory", fn (device: *dgpu.Device, descriptor: dgpu.SharedTextureMemory.Descriptor) callconv(.Inline) *dgpu.SharedTextureMemory);
    // assertDecl(T, "deviceInjectError", fn (device: *dgpu.Device, typ: dgpu.ErrorType, message: [*:0]const u8) callconv(.Inline) void);
    // assertDecl(T, "devicePopErrorScope", fn (device: *dgpu.Device, callback: dgpu.ErrorCallback, userdata: ?*anyopaque) callconv(.Inline) void);
    // assertDecl(T, "devicePushErrorScope", fn (device: *dgpu.Device, filter: dgpu.ErrorFilter) callconv(.Inline) void);
    // assertDecl(T, "deviceSetDeviceLostCallback", fn (device: *dgpu.Device, callback: ?dgpu.Device.LostCallback, userdata: ?*anyopaque) callconv(.Inline) void);
    // assertDecl(T, "deviceSetLabel", fn (device: *dgpu.Device, label: [:0]const u8) callconv(.Inline) void);
    // assertDecl(T, "deviceSetLoggingCallback", fn (device: *dgpu.Device, callback: ?dgpu.LoggingCallback, userdata: ?*anyopaque) callconv(.Inline) void);
    // assertDecl(T, "deviceSetUncapturedErrorCallback", fn (device: *dgpu.Device, callback: ?dgpu.ErrorCallback, userdata: ?*anyopaque) callconv(.Inline) void);
    // assertDecl(T, "deviceTick", fn (device: *dgpu.Device) callconv(.Inline) void);
    // assertDecl(T, "machDeviceWaitForCommandsToBeScheduled", fn (device: *dgpu.Device) callconv(.Inline) void);
    // assertDecl(T, "deviceReference", fn (device: *dgpu.Device) callconv(.Inline) void);
    // assertDecl(T, "deviceRelease", fn (device: *dgpu.Device) callconv(.Inline) void);

    // // dgpu.ExternalTexture
    // assertDecl(T, "externalTextureDestroy", fn (external_texture: *dgpu.ExternalTexture) callconv(.Inline) void);
    // assertDecl(T, "externalTextureSetLabel", fn (external_texture: *dgpu.ExternalTexture, label: [:0]const u8) callconv(.Inline) void);
    // assertDecl(T, "externalTextureReference", fn (external_texture: *dgpu.ExternalTexture) callconv(.Inline) void);
    // assertDecl(T, "externalTextureRelease", fn (external_texture: *dgpu.ExternalTexture) callconv(.Inline) void);

    // // dgpu.Instance
    // assertDecl(T, "instanceCreateSurface", fn (instance: *dgpu.Instance, descriptor: dgpu.Surface.Descriptor) callconv(.Inline) *dgpu.Surface);
    // assertDecl(T, "instanceProcessEvents", fn (instance: *dgpu.Instance) callconv(.Inline) void);
    // assertDecl(T, "instanceRequestAdapter", fn (instance: *dgpu.Instance, options: ?*const dgpu.RequestAdapterOptions, callback: dgpu.RequestAdapterCallback, userdata: ?*anyopaque) callconv(.Inline) void);
    // assertDecl(T, "instanceReference", fn (instance: *dgpu.Instance) callconv(.Inline) void);
    // assertDecl(T, "instanceRelease", fn (instance: *dgpu.Instance) callconv(.Inline) void);

    // // dgpu.QuerySet
    // assertDecl(T, "querySetDestroy", fn (query_set: *dgpu.QuerySet) callconv(.Inline) void);
    // assertDecl(T, "querySetGetCount", fn (query_set: *dgpu.QuerySet) callconv(.Inline) u32);
    // assertDecl(T, "querySetGetType", fn (query_set: *dgpu.QuerySet) callconv(.Inline) dgpu.QueryType);
    // assertDecl(T, "querySetSetLabel", fn (query_set: *dgpu.QuerySet, label: [:0]const u8) callconv(.Inline) void);
    // assertDecl(T, "querySetReference", fn (query_set: *dgpu.QuerySet) callconv(.Inline) void);
    // assertDecl(T, "querySetRelease", fn (query_set: *dgpu.QuerySet) callconv(.Inline) void);

    // // dgpu.Queue
    // assertDecl(T, "queueCopyTextureForBrowser", fn (queue: *dgpu.Queue, source: *const dgpu.ImageCopyTexture, destination: *const dgpu.ImageCopyTexture, copy_size: *const dgpu.Extent3D, options: *const dgpu.CopyTextureForBrowserOptions) callconv(.Inline) void);
    // assertDecl(T, "queueOnSubmittedWorkDone", fn (queue: *dgpu.Queue, signal_value: u64, callback: dgpu.Queue.WorkDoneCallback, userdata: ?*anyopaque) callconv(.Inline) void);
    // assertDecl(T, "queueSetLabel", fn (queue: *dgpu.Queue, label: [:0]const u8) callconv(.Inline) void);
    // assertDecl(T, "queueSubmit", fn (queue: *dgpu.Queue, command_count: usize, commands: [*]const *const dgpu.CommandBuffer) callconv(.Inline) void);
    // assertDecl(T, "queueWriteBuffer", fn (queue: *dgpu.Queue, buffer: *dgpu.Buffer, buffer_offset: u64, data: *const anyopaque, size: usize) callconv(.Inline) void);
    // assertDecl(T, "queueWriteTexture", fn (queue: *dgpu.Queue, destination: *const dgpu.ImageCopyTexture, data: *const anyopaque, data_size: usize, data_layout: *const dgpu.Texture.DataLayout, write_size: *const dgpu.Extent3D) callconv(.Inline) void);
    // assertDecl(T, "queueReference", fn (queue: *dgpu.Queue) callconv(.Inline) void);
    // assertDecl(T, "queueRelease", fn (queue: *dgpu.Queue) callconv(.Inline) void);

    // // dgpu.RenderBundle
    // assertDecl(T, "renderBundleSetLabel", fn (render_bundle: *dgpu.RenderBundle, label: [:0]const u8) callconv(.Inline) void);
    // assertDecl(T, "renderBundleReference", fn (render_bundle: *dgpu.RenderBundle) callconv(.Inline) void);
    // assertDecl(T, "renderBundleRelease", fn (render_bundle: *dgpu.RenderBundle) callconv(.Inline) void);

    // // dgpu.RenderBundleEncoder
    // assertDecl(T, "renderBundleEncoderDraw", fn (render_bundle_encoder: *dgpu.RenderBundleEncoder, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) callconv(.Inline) void);
    // assertDecl(T, "renderBundleEncoderDrawIndexed", fn (render_bundle_encoder: *dgpu.RenderBundleEncoder, index_count: u32, instance_count: u32, first_index: u32, base_vertex: i32, first_instance: u32) callconv(.Inline) void);
    // assertDecl(T, "renderBundleEncoderDrawIndexedIndirect", fn (render_bundle_encoder: *dgpu.RenderBundleEncoder, indirect_buffer: *dgpu.Buffer, indirect_offset: u64) callconv(.Inline) void);
    // assertDecl(T, "renderBundleEncoderDrawIndirect", fn (render_bundle_encoder: *dgpu.RenderBundleEncoder, indirect_buffer: *dgpu.Buffer, indirect_offset: u64) callconv(.Inline) void);
    // assertDecl(T, "renderBundleEncoderFinish", fn (render_bundle_encoder: *dgpu.RenderBundleEncoder, descriptor: dgpu.RenderBundle.Descriptor) callconv(.Inline) *dgpu.RenderBundle);
    // assertDecl(T, "renderBundleEncoderInsertDebugMarker", fn (render_bundle_encoder: *dgpu.RenderBundleEncoder, marker_label: [*:0]const u8) callconv(.Inline) void);
    // assertDecl(T, "renderBundleEncoderPopDebugGroup", fn (render_bundle_encoder: *dgpu.RenderBundleEncoder) callconv(.Inline) void);
    // assertDecl(T, "renderBundleEncoderPushDebugGroup", fn (render_bundle_encoder: *dgpu.RenderBundleEncoder, group_label: [*:0]const u8) callconv(.Inline) void);
    // assertDecl(T, "renderBundleEncoderSetIndexBuffer", fn (render_bundle_encoder: *dgpu.RenderBundleEncoder, buffer: *dgpu.Buffer, format: dgpu.IndexFormat, offset: u64, size: u64) callconv(.Inline) void);
    // assertDecl(T, "renderBundleEncoderSetLabel", fn (render_bundle_encoder: *dgpu.RenderBundleEncoder, label: [:0]const u8) callconv(.Inline) void);
    // assertDecl(T, "renderBundleEncoderSetVertexBuffer", fn (render_bundle_encoder: *dgpu.RenderBundleEncoder, slot: u32, buffer: *dgpu.Buffer, offset: u64, size: u64) callconv(.Inline) void);
    // assertDecl(T, "renderBundleEncoderReference", fn (render_bundle_encoder: *dgpu.RenderBundleEncoder) callconv(.Inline) void);
    // assertDecl(T, "renderBundleEncoderRelease", fn (render_bundle_encoder: *dgpu.RenderBundleEncoder) callconv(.Inline) void);

    // // dgpu.RenderPassEncoder
    // assertDecl(T, "renderPassEncoderBeginOcclusionQuery", fn (render_pass_encoder: *dgpu.RenderPassEncoder, query_index: u32) callconv(.Inline) void);
    // assertDecl(T, "renderPassEncoderDraw", fn (render_pass_encoder: *dgpu.RenderPassEncoder, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) callconv(.Inline) void);
    // assertDecl(T, "renderPassEncoderDrawIndexed", fn (render_pass_encoder: *dgpu.RenderPassEncoder, index_count: u32, instance_count: u32, first_index: u32, base_vertex: i32, first_instance: u32) callconv(.Inline) void);
    // assertDecl(T, "renderPassEncoderDrawIndexedIndirect", fn (render_pass_encoder: *dgpu.RenderPassEncoder, indirect_buffer: *dgpu.Buffer, indirect_offset: u64) callconv(.Inline) void);
    // assertDecl(T, "renderPassEncoderDrawIndirect", fn (render_pass_encoder: *dgpu.RenderPassEncoder, indirect_buffer: *dgpu.Buffer, indirect_offset: u64) callconv(.Inline) void);
    // assertDecl(T, "renderPassEncoderEnd", fn (render_pass_encoder: *dgpu.RenderPassEncoder) callconv(.Inline) void);
    // assertDecl(T, "renderPassEncoderEndOcclusionQuery", fn (render_pass_encoder: *dgpu.RenderPassEncoder) callconv(.Inline) void);
    // assertDecl(T, "renderPassEncoderExecuteBundles", fn (render_pass_encoder: *dgpu.RenderPassEncoder, bundles_count: usize, bundles: [*]const *const dgpu.RenderBundle) callconv(.Inline) void);
    // assertDecl(T, "renderPassEncoderInsertDebugMarker", fn (render_pass_encoder: *dgpu.RenderPassEncoder, marker_label: [*:0]const u8) callconv(.Inline) void);
    // assertDecl(T, "renderPassEncoderPopDebugGroup", fn (render_pass_encoder: *dgpu.RenderPassEncoder) callconv(.Inline) void);
    // assertDecl(T, "renderPassEncoderPushDebugGroup", fn (render_pass_encoder: *dgpu.RenderPassEncoder, group_label: [*:0]const u8) callconv(.Inline) void);
    // assertDecl(T, "renderPassEncoderSetBlendConstant", fn (render_pass_encoder: *dgpu.RenderPassEncoder, color: *const dgpu.Color) callconv(.Inline) void);
    // assertDecl(T, "renderPassEncoderSetIndexBuffer", fn (render_pass_encoder: *dgpu.RenderPassEncoder, buffer: *dgpu.Buffer, format: dgpu.IndexFormat, offset: u64, size: u64) callconv(.Inline) void);
    // assertDecl(T, "renderPassEncoderSetLabel", fn (render_pass_encoder: *dgpu.RenderPassEncoder, label: [:0]const u8) callconv(.Inline) void);
    // assertDecl(T, "renderPassEncoderSetScissorRect", fn (render_pass_encoder: *dgpu.RenderPassEncoder, x: u32, y: u32, width: u32, height: u32) callconv(.Inline) void);
    // assertDecl(T, "renderPassEncoderSetStencilReference", fn (render_pass_encoder: *dgpu.RenderPassEncoder, reference: u32) callconv(.Inline) void);
    // assertDecl(T, "renderPassEncoderSetVertexBuffer", fn (render_pass_encoder: *dgpu.RenderPassEncoder, slot: u32, buffer: *dgpu.Buffer, offset: u64, size: u64) callconv(.Inline) void);
    // assertDecl(T, "renderPassEncoderSetViewport", fn (render_pass_encoder: *dgpu.RenderPassEncoder, x: f32, y: f32, width: f32, height: f32, min_depth: f32, max_depth: f32) callconv(.Inline) void);
    // assertDecl(T, "renderPassEncoderWriteTimestamp", fn (render_pass_encoder: *dgpu.RenderPassEncoder, query_set: *dgpu.QuerySet, query_index: u32) callconv(.Inline) void);
    // assertDecl(T, "renderPassEncoderReference", fn (render_pass_encoder: *dgpu.RenderPassEncoder) callconv(.Inline) void);
    // assertDecl(T, "renderPassEncoderRelease", fn (render_pass_encoder: *dgpu.RenderPassEncoder) callconv(.Inline) void);

    // // dgpu.Sampler
    // assertDecl(T, "samplerSetLabel", fn (sampler: *dgpu.Sampler, label: [:0]const u8) callconv(.Inline) void);
    // assertDecl(T, "samplerReference", fn (sampler: *dgpu.Sampler) callconv(.Inline) void);
    // assertDecl(T, "samplerRelease", fn (sampler: *dgpu.Sampler) callconv(.Inline) void);

    // // dgpu.ShaderModule
    // assertDecl(T, "shaderModuleGetCompilationInfo", fn (shader_module: *dgpu.ShaderModule, callback: dgpu.CompilationInfoCallback, userdata: ?*anyopaque) callconv(.Inline) void);
    // assertDecl(T, "shaderModuleSetLabel", fn (shader_module: *dgpu.ShaderModule, label: [:0]const u8) callconv(.Inline) void);
    // assertDecl(T, "shaderModuleReference", fn (shader_module: *dgpu.ShaderModule) callconv(.Inline) void);
    // assertDecl(T, "shaderModuleRelease", fn (shader_module: *dgpu.ShaderModule) callconv(.Inline) void);

    // // dgpu.SharedFence
    // assertDecl(T, "sharedFenceExportInfo", fn (shared_fence: *dgpu.SharedFence, info: *dgpu.SharedFence.ExportInfo) callconv(.Inline) void);
    // assertDecl(T, "sharedFenceReference", fn (shared_fence: *dgpu.SharedFence) callconv(.Inline) void);
    // assertDecl(T, "sharedFenceRelease", fn (shared_fence: *dgpu.SharedFence) callconv(.Inline) void);

    // // dgpu.SharedTextureMemory
    // assertDecl(T, "sharedTextureMemoryBeginAccess", fn (shared_texture_memory: *dgpu.SharedTextureMemory, texture: *dgpu.Texture, descriptor: dgpu.SharedTextureMemory.BeginAccessDescriptor) callconv(.Inline) void);
    // assertDecl(T, "sharedTextureMemoryCreateTexture", fn (shared_texture_memory: *dgpu.SharedTextureMemory, descriptor: dgpu.Texture.Descriptor) callconv(.Inline) *dgpu.Texture);
    // assertDecl(T, "sharedTextureMemoryEndAccess", fn (shared_texture_memory: *dgpu.SharedTextureMemory, texture: *dgpu.Texture, descriptor: *dgpu.SharedTextureMemory.EndAccessState) callconv(.Inline) void);
    // assertDecl(T, "sharedTextureMemoryEndAccessStateFreeMembers", fn (value: dgpu.SharedTextureMemory.EndAccessState) callconv(.Inline) void);
    // assertDecl(T, "sharedTextureMemoryGetProperties", fn (shared_texture_memory: *dgpu.SharedTextureMemory, properties: *dgpu.SharedTextureMemory.Properties) callconv(.Inline) void);
    // assertDecl(T, "sharedTextureMemorySetLabel", fn (shared_texture_memory: *dgpu.SharedTextureMemory, label: [:0]const u8) callconv(.Inline) void);
    // assertDecl(T, "sharedTextureMemoryReference", fn (shared_texture_memory: *dgpu.SharedTextureMemory) callconv(.Inline) void);
    // assertDecl(T, "sharedTextureMemoryRelease", fn (shared_texture_memory: *dgpu.SharedTextureMemory) callconv(.Inline) void);

    // // dgpu.Surface
    // assertDecl(T, "surfaceReference", fn (surface: *dgpu.Surface) callconv(.Inline) void);
    // assertDecl(T, "surfaceRelease", fn (surface: *dgpu.Surface) callconv(.Inline) void);

    // // dgpu.SwapChain
    // assertDecl(T, "swapChainGetCurrentTexture", fn (swap_chain: *dgpu.SwapChain) callconv(.Inline) ?*dgpu.Texture);
    // assertDecl(T, "swapChainGetCurrentTextureView", fn (swap_chain: *dgpu.SwapChain) callconv(.Inline) ?*dgpu.TextureView);
    // assertDecl(T, "swapChainPresent", fn (swap_chain: *dgpu.SwapChain) callconv(.Inline) void);
    // assertDecl(T, "swapChainReference", fn (swap_chain: *dgpu.SwapChain) callconv(.Inline) void);
    // assertDecl(T, "swapChainRelease", fn (swap_chain: *dgpu.SwapChain) callconv(.Inline) void);

    // // dgpu.Texture
    // assertDecl(T, "textureCreateView", fn (texture: *dgpu.Texture, descriptor: dgpu.TextureView.Descriptor) callconv(.Inline) *dgpu.TextureView);
    // assertDecl(T, "textureDestroy", fn (texture: *dgpu.Texture) callconv(.Inline) void);
    // assertDecl(T, "textureGetDepthOrArrayLayers", fn (texture: *dgpu.Texture) callconv(.Inline) u32);
    // assertDecl(T, "textureGetDimension", fn (texture: *dgpu.Texture) callconv(.Inline) dgpu.Texture.Dimension);
    // assertDecl(T, "textureGetFormat", fn (texture: *dgpu.Texture) callconv(.Inline) dgpu.Texture.Format);
    // assertDecl(T, "textureGetHeight", fn (texture: *dgpu.Texture) callconv(.Inline) u32);
    // assertDecl(T, "textureGetMipLevelCount", fn (texture: *dgpu.Texture) callconv(.Inline) u32);
    // assertDecl(T, "textureGetSampleCount", fn (texture: *dgpu.Texture) callconv(.Inline) u32);
    // assertDecl(T, "textureGetUsage", fn (texture: *dgpu.Texture) callconv(.Inline) dgpu.Texture.UsageFlags);
    // assertDecl(T, "textureGetWidth", fn (texture: *dgpu.Texture) callconv(.Inline) u32);
    // assertDecl(T, "textureSetLabel", fn (texture: *dgpu.Texture, label: [:0]const u8) callconv(.Inline) void);
    // assertDecl(T, "textureReference", fn (texture: *dgpu.Texture) callconv(.Inline) void);
    // assertDecl(T, "textureRelease", fn (texture: *dgpu.Texture) callconv(.Inline) void);
    // assertDecl(T, "textureViewSetLabel", fn (texture_view: *dgpu.TextureView, label: [:0]const u8) callconv(.Inline) void);
    // assertDecl(T, "textureViewReference", fn (texture_view: *dgpu.TextureView) callconv(.Inline) void);
    // assertDecl(T, "textureViewRelease", fn (texture_view: *dgpu.TextureView) callconv(.Inline) void);
    return T;
}

fn assertDecl(comptime T: anytype, comptime name: []const u8, comptime Decl: type) void {
    if (!@hasDecl(T, name)) @compileError("dgpu.Interface missing declaration: " ++ @typeName(Decl));
    const FoundDecl = @TypeOf(@field(T, name));
    if (FoundDecl != Decl) @compileError("dgpu.Interface field '" ++ name ++ "'\n\texpected type: " ++ @typeName(Decl) ++ "\n\t   found type: " ++ @typeName(FoundDecl));
}

/// Exports C ABI function declarations for the given dgpu.Interface implementation.
pub fn Export(comptime T: type) type {
    _ = Interface(T); // verify implementation is a valid interface
    return struct {
        // // DGPU_EXPORT WGPUInstance dgpuCreateInstance(WGPUInstanceDescriptor const * descriptor);
        // export fn dgpuCreateInstance(descriptor: dgpu.Instance.Descriptor) ?*dgpu.Instance {
        //     return T.createInstance(descriptor);
        // }

        // // DGPU_EXPORT WGPUProc dgpuGetProcAddress(WGPUDevice device, char const * procName);
        // export fn dgpuGetProcAddress(device: *dgpu.Device, proc_name: [*:0]const u8) ?dgpu.Proc {
        //     return T.getProcAddress(device, proc_name);
        // }

        // // DGPU_EXPORT WGPUDevice dgpuAdapterCreateDevice(WGPUAdapter adapter, WGPUDeviceDescriptor const * descriptor /* nullable */);
        // export fn dgpuAdapterCreateDevice(adapter: *dgpu.Adapter, descriptor: dgpu.Device.Descriptor) ?*dgpu.Device {
        //     return T.adapterCreateDevice(adapter, descriptor);
        // }

        // // DGPU_EXPORT size_t dgpuAdapterEnumerateFeatures(WGPUAdapter adapter, WGPUFeatureName * features);
        // export fn dgpuAdapterEnumerateFeatures(adapter: *dgpu.Adapter, features: ?[*]dgpu.FeatureName) usize {
        //     return T.adapterEnumerateFeatures(adapter, features);
        // }

        // // DGPU_EXPORT WGPUInstance dgpuAdapterGetInstance(WGPUAdapter adapter);
        // export fn dgpuAdapterGetInstance(adapter: *dgpu.Adapter) *dgpu.Instance {
        //     return T.adapterGetInstance(adapter);
        // }

        // // DGPU_EXPORT WGPUBool dgpuAdapterGetLimits(WGPUAdapter adapter, WGPUSupportedLimits * limits);
        // export fn dgpuAdapterGetLimits(adapter: *dgpu.Adapter, limits: *dgpu.Limits) u32 {
        //     return T.adapterGetLimits(adapter, limits);
        // }

        // // DGPU_EXPORT void dgpuAdapterGetProperties(WGPUAdapter adapter, WGPUAdapterProperties * properties);
        // export fn dgpuAdapterGetProperties(adapter: *dgpu.Adapter, properties: *dgpu.Adapter.Properties) void {
        //     return T.adapterGetProperties(adapter, properties);
        // }

        // // DGPU_EXPORT WGPUBool dgpuAdapterHasFeature(WGPUAdapter adapter, WGPUFeatureName feature);
        // export fn dgpuAdapterHasFeature(adapter: *dgpu.Adapter, feature: dgpu.FeatureName) u32 {
        //     return T.adapterHasFeature(adapter, feature);
        // }

        // // DGPU_EXPORT void dgpuAdapterPropertiesFreeMembers(WGPUAdapterProperties value);
        // export fn dgpuAdapterPropertiesFreeMembers(value: dgpu.Adapter.Properties) void {
        //     T.adapterPropertiesFreeMembers(value);
        // }

        // // DGPU_EXPORT void dgpuAdapterRequestDevice(WGPUAdapter adapter, WGPUDeviceDescriptor const * descriptor /* nullable */, WGPURequestDeviceCallback callback, void * userdata);
        // export fn dgpuAdapterRequestDevice(adapter: *dgpu.Adapter, descriptor: dgpu.Device.Descriptor, callback: dgpu.RequestDeviceCallback, userdata: ?*anyopaque) void {
        //     T.adapterRequestDevice(adapter, descriptor, callback, userdata);
        // }

        // // DGPU_EXPORT void dgpuAdapterReference(WGPUAdapter adapter);
        // export fn dgpuAdapterReference(adapter: *dgpu.Adapter) void {
        //     T.adapterReference(adapter);
        // }

        // // DGPU_EXPORT void dgpuAdapterRelease(WGPUAdapter adapter);
        // export fn dgpuAdapterRelease(adapter: *dgpu.Adapter) void {
        //     T.adapterRelease(adapter);
        // }

        // // DGPU_EXPORT void dgpuBindGroupSetLabel(WGPUBindGroup bindGroup, char const * label);
        // export fn dgpuBindGroupSetLabel(bind_group: *dgpu.BindGroup, label: [:0]const u8) void {
        //     T.bindGroupSetLabel(bind_group, label);
        // }

        // // DGPU_EXPORT void dgpuBindGroupReference(WGPUBindGroup bindGroup);
        // export fn dgpuBindGroupReference(bind_group: *dgpu.BindGroup) void {
        //     T.bindGroupReference(bind_group);
        // }

        // // DGPU_EXPORT void dgpuBindGroupRelease(WGPUBindGroup bindGroup);
        // export fn dgpuBindGroupRelease(bind_group: *dgpu.BindGroup) void {
        //     T.bindGroupRelease(bind_group);
        // }

        // // DGPU_EXPORT void dgpuBindGroupLayoutSetLabel(WGPUBindGroupLayout bindGroupLayout, char const * label);
        // export fn dgpuBindGroupLayoutSetLabel(bind_group_layout: *dgpu.BindGroupLayout, label: [:0]const u8) void {
        //     T.bindGroupLayoutSetLabel(bind_group_layout, label);
        // }

        // // DGPU_EXPORT void dgpuBindGroupLayoutReference(WGPUBindGroupLayout bindGroupLayout);
        // export fn dgpuBindGroupLayoutReference(bind_group_layout: *dgpu.BindGroupLayout) void {
        //     T.bindGroupLayoutReference(bind_group_layout);
        // }

        // // DGPU_EXPORT void dgpuBindGroupLayoutRelease(WGPUBindGroupLayout bindGroupLayout);
        // export fn dgpuBindGroupLayoutRelease(bind_group_layout: *dgpu.BindGroupLayout) void {
        //     T.bindGroupLayoutRelease(bind_group_layout);
        // }

        // // DGPU_EXPORT void dgpuBufferDestroy(WGPUBuffer buffer);
        // export fn dgpuBufferDestroy(buffer: *dgpu.Buffer) void {
        //     T.bufferDestroy(buffer);
        // }

        // // DGPU_EXPORT void const * dgpuBufferGetConstMappedRange(WGPUBuffer buffer, size_t offset, size_t size);
        // export fn dgpuBufferGetConstMappedRange(buffer: *dgpu.Buffer, offset: usize, size: usize) ?*const anyopaque {
        //     return T.bufferGetConstMappedRange(buffer, offset, size);
        // }

        // // DGPU_EXPORT void * dgpuBufferGetMappedRange(WGPUBuffer buffer, size_t offset, size_t size);
        // export fn dgpuBufferGetMappedRange(buffer: *dgpu.Buffer, offset: usize, size: usize) ?*anyopaque {
        //     return T.bufferGetMappedRange(buffer, offset, size);
        // }

        // // DGPU_EXPORT uint64_t dgpuBufferGetSize(WGPUBuffer buffer);
        // export fn dgpuBufferGetSize(buffer: *dgpu.Buffer) u64 {
        //     return T.bufferGetSize(buffer);
        // }

        // // DGPU_EXPORT WGPUBufferUsage dgpuBufferGetUsage(WGPUBuffer buffer);
        // export fn dgpuBufferGetUsage(buffer: *dgpu.Buffer) dgpu.Buffer.UsageFlags {
        //     return T.bufferGetUsage(buffer);
        // }

        // // DGPU_EXPORT void dgpuBufferMapAsync(WGPUBuffer buffer, WGPUMapModeFlags mode, size_t offset, size_t size, WGPUBufferMapCallback callback, void * userdata);
        // export fn dgpuBufferMapAsync(buffer: *dgpu.Buffer, mode: u32, offset: usize, size: usize, callback: dgpu.Buffer.MapCallback, userdata: ?*anyopaque) void {
        //     T.bufferMapAsync(buffer, @as(dgpu.MapModeFlags, @bitCast(mode)), offset, size, callback, userdata);
        // }

        // // DGPU_EXPORT void dgpuBufferSetLabel(WGPUBuffer buffer, char const * label);
        // export fn dgpuBufferSetLabel(buffer: *dgpu.Buffer, label: [:0]const u8) void {
        //     T.bufferSetLabel(buffer, label);
        // }

        // // DGPU_EXPORT void dgpuBufferUnmap(WGPUBuffer buffer);
        // export fn dgpuBufferUnmap(buffer: *dgpu.Buffer) void {
        //     T.bufferUnmap(buffer);
        // }

        // // DGPU_EXPORT void dgpuBufferReference(WGPUBuffer buffer);
        // export fn dgpuBufferReference(buffer: *dgpu.Buffer) void {
        //     T.bufferReference(buffer);
        // }

        // // DGPU_EXPORT void dgpuBufferRelease(WGPUBuffer buffer);
        // export fn dgpuBufferRelease(buffer: *dgpu.Buffer) void {
        //     T.bufferRelease(buffer);
        // }

        // // DGPU_EXPORT void dgpuCommandBufferSetLabel(WGPUCommandBuffer commandBuffer, char const * label);
        // export fn dgpuCommandBufferSetLabel(command_buffer: *dgpu.CommandBuffer, label: [:0]const u8) void {
        //     T.commandBufferSetLabel(command_buffer, label);
        // }

        // // DGPU_EXPORT void dgpuCommandBufferReference(WGPUCommandBuffer commandBuffer);
        // export fn dgpuCommandBufferReference(command_buffer: *dgpu.CommandBuffer) void {
        //     T.commandBufferReference(command_buffer);
        // }

        // // DGPU_EXPORT void dgpuCommandBufferRelease(WGPUCommandBuffer commandBuffer);
        // export fn dgpuCommandBufferRelease(command_buffer: *dgpu.CommandBuffer) void {
        //     T.commandBufferRelease(command_buffer);
        // }

        // // DGPU_EXPORT WGPUComputePassEncoder dgpuCommandEncoderBeginComputePass(WGPUCommandEncoder commandEncoder, WGPUComputePassDescriptor const * descriptor /* nullable */);
        // export fn dgpuCommandEncoderBeginComputePass(command_encoder: *dgpu.CommandEncoder, descriptor: dgpu.ComputePassDescriptor) *dgpu.ComputePassEncoder {
        //     return T.commandEncoderBeginComputePass(command_encoder, descriptor);
        // }

        // // DGPU_EXPORT WGPURenderPassEncoder dgpuCommandEncoderBeginRenderPass(WGPUCommandEncoder commandEncoder, WGPURenderPassDescriptor const * descriptor);
        // export fn dgpuCommandEncoderBeginRenderPass(command_encoder: *dgpu.CommandEncoder, descriptor: dgpu.RenderPassDescriptor) *dgpu.RenderPassEncoder {
        //     return T.commandEncoderBeginRenderPass(command_encoder, descriptor);
        // }

        // // DGPU_EXPORT void dgpuCommandEncoderClearBuffer(WGPUCommandEncoder commandEncoder, WGPUBuffer buffer, uint64_t offset, uint64_t size);
        // export fn dgpuCommandEncoderClearBuffer(command_encoder: *dgpu.CommandEncoder, buffer: *dgpu.Buffer, offset: u64, size: u64) void {
        //     T.commandEncoderClearBuffer(command_encoder, buffer, offset, size);
        // }

        // // DGPU_EXPORT void dgpuCommandEncoderCopyBufferToBuffer(WGPUCommandEncoder commandEncoder, WGPUBuffer source, uint64_t sourceOffset, WGPUBuffer destination, uint64_t destinationOffset, uint64_t size);
        // export fn dgpuCommandEncoderCopyBufferToBuffer(command_encoder: *dgpu.CommandEncoder, source: *dgpu.Buffer, source_offset: u64, destination: *dgpu.Buffer, destination_offset: u64, size: u64) void {
        //     T.commandEncoderCopyBufferToBuffer(command_encoder, source, source_offset, destination, destination_offset, size);
        // }

        // // DGPU_EXPORT void dgpuCommandEncoderCopyBufferToTexture(WGPUCommandEncoder commandEncoder, WGPUImageCopyBuffer const * source, WGPUImageCopyTexture const * destination, WGPUExtent3D const * copySize);
        // export fn dgpuCommandEncoderCopyBufferToTexture(command_encoder: *dgpu.CommandEncoder, source: *const dgpu.ImageCopyBuffer, destination: *const dgpu.ImageCopyTexture, copy_size: *const dgpu.Extent3D) void {
        //     T.commandEncoderCopyBufferToTexture(command_encoder, source, destination, copy_size);
        // }

        // // DGPU_EXPORT void dgpuCommandEncoderCopyTextureToBuffer(WGPUCommandEncoder commandEncoder, WGPUImageCopyTexture const * source, WGPUImageCopyBuffer const * destination, WGPUExtent3D const * copySize);
        // export fn dgpuCommandEncoderCopyTextureToBuffer(command_encoder: *dgpu.CommandEncoder, source: *const dgpu.ImageCopyTexture, destination: *const dgpu.ImageCopyBuffer, copy_size: *const dgpu.Extent3D) void {
        //     T.commandEncoderCopyTextureToBuffer(command_encoder, source, destination, copy_size);
        // }

        // // DGPU_EXPORT void dgpuCommandEncoderCopyTextureToTexture(WGPUCommandEncoder commandEncoder, WGPUImageCopyTexture const * source, WGPUImageCopyTexture const * destination, WGPUExtent3D const * copySize);
        // export fn dgpuCommandEncoderCopyTextureToTexture(command_encoder: *dgpu.CommandEncoder, source: *const dgpu.ImageCopyTexture, destination: *const dgpu.ImageCopyTexture, copy_size: *const dgpu.Extent3D) void {
        //     T.commandEncoderCopyTextureToTexture(command_encoder, source, destination, copy_size);
        // }

        // // DGPU_EXPORT WGPUCommandBuffer dgpuCommandEncoderFinish(WGPUCommandEncoder commandEncoder, WGPUCommandBufferDescriptor const * descriptor /* nullable */);
        // export fn dgpuCommandEncoderFinish(command_encoder: *dgpu.CommandEncoder, descriptor: dgpu.CommandBuffer.Descriptor) *dgpu.CommandBuffer {
        //     return T.commandEncoderFinish(command_encoder, descriptor);
        // }

        // // DGPU_EXPORT void dgpuCommandEncoderInjectValidationError(WGPUCommandEncoder commandEncoder, char const * message);
        // export fn dgpuCommandEncoderInjectValidationError(command_encoder: *dgpu.CommandEncoder, message: [*:0]const u8) void {
        //     T.commandEncoderInjectValidationError(command_encoder, message);
        // }

        // // DGPU_EXPORT void dgpuCommandEncoderInsertDebugMarker(WGPUCommandEncoder commandEncoder, char const * markerLabel);
        // export fn dgpuCommandEncoderInsertDebugMarker(command_encoder: *dgpu.CommandEncoder, marker_label: [*:0]const u8) void {
        //     T.commandEncoderInsertDebugMarker(command_encoder, marker_label);
        // }

        // // DGPU_EXPORT void dgpuCommandEncoderPopDebugGroup(WGPUCommandEncoder commandEncoder);
        // export fn dgpuCommandEncoderPopDebugGroup(command_encoder: *dgpu.CommandEncoder) void {
        //     T.commandEncoderPopDebugGroup(command_encoder);
        // }

        // // DGPU_EXPORT void dgpuCommandEncoderPushDebugGroup(WGPUCommandEncoder commandEncoder, char const * groupLabel);
        // export fn dgpuCommandEncoderPushDebugGroup(command_encoder: *dgpu.CommandEncoder, group_label: [*:0]const u8) void {
        //     T.commandEncoderPushDebugGroup(command_encoder, group_label);
        // }

        // // DGPU_EXPORT void dgpuCommandEncoderResolveQuerySet(WGPUCommandEncoder commandEncoder, WGPUQuerySet querySet, uint32_t firstQuery, uint32_t queryCount, WGPUBuffer destination, uint64_t destinationOffset);
        // export fn dgpuCommandEncoderResolveQuerySet(command_encoder: *dgpu.CommandEncoder, query_set: *dgpu.QuerySet, first_query: u32, query_count: u32, destination: *dgpu.Buffer, destination_offset: u64) void {
        //     T.commandEncoderResolveQuerySet(command_encoder, query_set, first_query, query_count, destination, destination_offset);
        // }

        // // DGPU_EXPORT void dgpuCommandEncoderSetLabel(WGPUCommandEncoder commandEncoder, char const * label);
        // export fn dgpuCommandEncoderSetLabel(command_encoder: *dgpu.CommandEncoder, label: [:0]const u8) void {
        //     T.commandEncoderSetLabel(command_encoder, label);
        // }

        // // DGPU_EXPORT void dgpuCommandEncoderWriteBuffer(WGPUCommandEncoder commandEncoder, WGPUBuffer buffer, uint64_t bufferOffset, uint8_t const * data, uint64_t size);
        // export fn dgpuCommandEncoderWriteBuffer(command_encoder: *dgpu.CommandEncoder, buffer: *dgpu.Buffer, buffer_offset: u64, data: [*]const u8, size: u64) void {
        //     T.commandEncoderWriteBuffer(command_encoder, buffer, buffer_offset, data, size);
        // }

        // // DGPU_EXPORT void dgpuCommandEncoderWriteTimestamp(WGPUCommandEncoder commandEncoder, WGPUQuerySet querySet, uint32_t queryIndex);
        // export fn dgpuCommandEncoderWriteTimestamp(command_encoder: *dgpu.CommandEncoder, query_set: *dgpu.QuerySet, query_index: u32) void {
        //     T.commandEncoderWriteTimestamp(command_encoder, query_set, query_index);
        // }

        // // DGPU_EXPORT void dgpuCommandEncoderReference(WGPUCommandEncoder commandEncoder);
        // export fn dgpuCommandEncoderReference(command_encoder: *dgpu.CommandEncoder) void {
        //     T.commandEncoderReference(command_encoder);
        // }

        // // DGPU_EXPORT void dgpuCommandEncoderRelease(WGPUCommandEncoder commandEncoder);
        // export fn dgpuCommandEncoderRelease(command_encoder: *dgpu.CommandEncoder) void {
        //     T.commandEncoderRelease(command_encoder);
        // }

        // // DGPU_EXPORT void dgpuComputePassEncoderDispatchWorkgroups(WGPUComputePassEncoder computePassEncoder, uint32_t workgroupCountX, uint32_t workgroupCountY, uint32_t workgroupCountZ);
        // export fn dgpuComputePassEncoderDispatchWorkgroups(compute_pass_encoder: *dgpu.ComputePassEncoder, workgroup_count_x: u32, workgroup_count_y: u32, workgroup_count_z: u32) void {
        //     T.computePassEncoderDispatchWorkgroups(compute_pass_encoder, workgroup_count_x, workgroup_count_y, workgroup_count_z);
        // }

        // // DGPU_EXPORT void dgpuComputePassEncoderDispatchWorkgroupsIndirect(WGPUComputePassEncoder computePassEncoder, WGPUBuffer indirectBuffer, uint64_t indirectOffset);
        // export fn dgpuComputePassEncoderDispatchWorkgroupsIndirect(compute_pass_encoder: *dgpu.ComputePassEncoder, indirect_buffer: *dgpu.Buffer, indirect_offset: u64) void {
        //     T.computePassEncoderDispatchWorkgroupsIndirect(compute_pass_encoder, indirect_buffer, indirect_offset);
        // }

        // // DGPU_EXPORT void dgpuComputePassEncoderEnd(WGPUComputePassEncoder computePassEncoder);
        // export fn dgpuComputePassEncoderEnd(compute_pass_encoder: *dgpu.ComputePassEncoder) void {
        //     T.computePassEncoderEnd(compute_pass_encoder);
        // }

        // // DGPU_EXPORT void dgpuComputePassEncoderInsertDebugMarker(WGPUComputePassEncoder computePassEncoder, char const * markerLabel);
        // export fn dgpuComputePassEncoderInsertDebugMarker(compute_pass_encoder: *dgpu.ComputePassEncoder, marker_label: [*:0]const u8) void {
        //     T.computePassEncoderInsertDebugMarker(compute_pass_encoder, marker_label);
        // }

        // // DGPU_EXPORT void dgpuComputePassEncoderPopDebugGroup(WGPUComputePassEncoder computePassEncoder);
        // export fn dgpuComputePassEncoderPopDebugGroup(compute_pass_encoder: *dgpu.ComputePassEncoder) void {
        //     T.computePassEncoderPopDebugGroup(compute_pass_encoder);
        // }

        // // DGPU_EXPORT void dgpuComputePassEncoderPushDebugGroup(WGPUComputePassEncoder computePassEncoder, char const * groupLabel);
        // export fn dgpuComputePassEncoderPushDebugGroup(compute_pass_encoder: *dgpu.ComputePassEncoder, group_label: [*:0]const u8) void {
        //     T.computePassEncoderPushDebugGroup(compute_pass_encoder, group_label);
        // }

        // // DGPU_EXPORT void dgpuComputePassEncoderSetBindGroup(WGPUComputePassEncoder computePassEncoder, uint32_t groupIndex, WGPUBindGroup group, size_t dynamicOffsetCount, uint32_t const * dynamicOffsets);
        // export fn dgpuComputePassEncoderSetBindGroup(compute_pass_encoder: *dgpu.ComputePassEncoder, group_index: u32, group: *dgpu.BindGroup, dynamic_offset_count: usize, dynamic_offsets: ?[*]const u32) void {
        //     T.computePassEncoderSetBindGroup(compute_pass_encoder, group_index, group, dynamic_offset_count, dynamic_offsets);
        // }

        // // DGPU_EXPORT void dgpuComputePassEncoderSetLabel(WGPUComputePassEncoder computePassEncoder, char const * label);
        // export fn dgpuComputePassEncoderSetLabel(compute_pass_encoder: *dgpu.ComputePassEncoder, label: [:0]const u8) void {
        //     T.computePassEncoderSetLabel(compute_pass_encoder, label);
        // }

        // // DGPU_EXPORT void dgpuComputePassEncoderSetPipeline(WGPUComputePassEncoder computePassEncoder, WGPUComputePipeline pipeline);
        // export fn dgpuComputePassEncoderSetPipeline(compute_pass_encoder: *dgpu.ComputePassEncoder, pipeline: *dgpu.ComputePipeline) void {
        //     T.computePassEncoderSetPipeline(compute_pass_encoder, pipeline);
        // }

        // // DGPU_EXPORT void dgpuComputePassEncoderWriteTimestamp(WGPUComputePassEncoder computePassEncoder, WGPUQuerySet querySet, uint32_t queryIndex);
        // export fn dgpuComputePassEncoderWriteTimestamp(compute_pass_encoder: *dgpu.ComputePassEncoder, query_set: *dgpu.QuerySet, query_index: u32) void {
        //     T.computePassEncoderWriteTimestamp(compute_pass_encoder, query_set, query_index);
        // }

        // // DGPU_EXPORT void dgpuComputePassEncoderReference(WGPUComputePassEncoder computePassEncoder);
        // export fn dgpuComputePassEncoderReference(compute_pass_encoder: *dgpu.ComputePassEncoder) void {
        //     T.computePassEncoderReference(compute_pass_encoder);
        // }

        // // DGPU_EXPORT void dgpuComputePassEncoderRelease(WGPUComputePassEncoder computePassEncoder);
        // export fn dgpuComputePassEncoderRelease(compute_pass_encoder: *dgpu.ComputePassEncoder) void {
        //     T.computePassEncoderRelease(compute_pass_encoder);
        // }

        // // DGPU_EXPORT WGPUBindGroupLayout dgpuComputePipelineGetBindGroupLayout(WGPUComputePipeline computePipeline, uint32_t groupIndex);
        // export fn dgpuComputePipelineGetBindGroupLayout(compute_pipeline: *dgpu.ComputePipeline, group_index: u32) *dgpu.BindGroupLayout {
        //     return T.computePipelineGetBindGroupLayout(compute_pipeline, group_index);
        // }

        // // DGPU_EXPORT void dgpuComputePipelineSetLabel(WGPUComputePipeline computePipeline, char const * label);
        // export fn dgpuComputePipelineSetLabel(compute_pipeline: *dgpu.ComputePipeline, label: [:0]const u8) void {
        //     T.computePipelineSetLabel(compute_pipeline, label);
        // }

        // // DGPU_EXPORT void dgpuComputePipelineReference(WGPUComputePipeline computePipeline);
        // export fn dgpuComputePipelineReference(compute_pipeline: *dgpu.ComputePipeline) void {
        //     T.computePipelineReference(compute_pipeline);
        // }

        // // DGPU_EXPORT void dgpuComputePipelineRelease(WGPUComputePipeline computePipeline);
        // export fn dgpuComputePipelineRelease(compute_pipeline: *dgpu.ComputePipeline) void {
        //     T.computePipelineRelease(compute_pipeline);
        // }

        // // DGPU_EXPORT WGPUBindGroup dgpuDeviceCreateBindGroup(WGPUDevice device, WGPUBindGroupDescriptor const * descriptor);
        // export fn dgpuDeviceCreateBindGroup(device: *dgpu.Device, descriptor: dgpu.BindGroup.Descriptor) *dgpu.BindGroup {
        //     return T.deviceCreateBindGroup(device, descriptor);
        // }

        // // DGPU_EXPORT WGPUBindGroupLayout dgpuDeviceCreateBindGroupLayout(WGPUDevice device, WGPUBindGroupLayout.Descriptor const * descriptor);
        // export fn dgpuDeviceCreateBindGroupLayout(device: *dgpu.Device, descriptor: dgpu.BindGroupLayout.Descriptor) *dgpu.BindGroupLayout {
        //     return T.deviceCreateBindGroupLayout(device, descriptor);
        // }

        // // DGPU_EXPORT WGPUBuffer dgpuDeviceCreateBuffer(WGPUDevice device, WGPUBuffer.Descriptor const * descriptor);
        // export fn dgpuDeviceCreateBuffer(device: *dgpu.Device, descriptor: dgpu.Buffer.Descriptor) *dgpu.Buffer {
        //     return T.deviceCreateBuffer(device, descriptor);
        // }

        // // DGPU_EXPORT WGPUCommandEncoder dgpuDeviceCreateCommandEncoder(WGPUDevice device, WGPUCommandEncoderDescriptor const * descriptor /* nullable */);
        // export fn dgpuDeviceCreateCommandEncoder(device: *dgpu.Device, descriptor: dgpu.CommandEncoder.Descriptor) *dgpu.CommandEncoder {
        //     return T.deviceCreateCommandEncoder(device, descriptor);
        // }

        // // DGPU_EXPORT WGPUComputePipeline dgpuDeviceCreateComputePipeline(WGPUDevice device, WGPUComputePipelineDescriptor const * descriptor);
        // export fn dgpuDeviceCreateComputePipeline(device: *dgpu.Device, descriptor: dgpu.ComputePipeline.Descriptor) *dgpu.ComputePipeline {
        //     return T.deviceCreateComputePipeline(device, descriptor);
        // }

        // // DGPU_EXPORT void dgpuDeviceCreateComputePipelineAsync(WGPUDevice device, WGPUComputePipelineDescriptor const * descriptor, WGPUCreateComputePipelineAsyncCallback callback, void * userdata);
        // export fn dgpuDeviceCreateComputePipelineAsync(device: *dgpu.Device, descriptor: dgpu.ComputePipeline.Descriptor, callback: dgpu.CreateComputePipelineAsyncCallback, userdata: ?*anyopaque) void {
        //     T.deviceCreateComputePipelineAsync(device, descriptor, callback, userdata);
        // }

        // // DGPU_EXPORT WGPUBuffer dgpuDeviceCreateErrorBuffer(WGPUDevice device, WGPUBufferDescriptor const * descriptor);
        // export fn dgpuDeviceCreateErrorBuffer(device: *dgpu.Device, descriptor: dgpu.Buffer.Descriptor) *dgpu.Buffer {
        //     return T.deviceCreateErrorBuffer(device, descriptor);
        // }

        // // DGPU_EXPORT WGPUExternalTexture dgpuDeviceCreateErrorExternalTexture(WGPUDevice device);
        // export fn dgpuDeviceCreateErrorExternalTexture(device: *dgpu.Device) *dgpu.ExternalTexture {
        //     return T.deviceCreateErrorExternalTexture(device);
        // }

        // // DGPU_EXPORT WGPUTexture dgpuDeviceCreateErrorTexture(WGPUDevice device, WGPUTextureDescriptor const * descriptor);
        // export fn dgpuDeviceCreateErrorTexture(device: *dgpu.Device, descriptor: dgpu.Texture.Descriptor) *dgpu.Texture {
        //     return T.deviceCreateErrorTexture(device, descriptor);
        // }

        // // DGPU_EXPORT WGPUExternalTexture dgpuDeviceCreateExternalTexture(WGPUDevice device, WGPUExternalTextureDescriptor const * externalTextureDescriptor);
        // export fn dgpuDeviceCreateExternalTexture(device: *dgpu.Device, external_texture_descriptor: *const dgpu.ExternalTexture.Descriptor) *dgpu.ExternalTexture {
        //     return T.deviceCreateExternalTexture(device, external_texture_descriptor);
        // }

        // // DGPU_EXPORT WGPUPipelineLayout dgpuDeviceCreatePipelineLayout(WGPUDevice device, WGPUPipelineLayoutDescriptor const * descriptor);
        // export fn dgpuDeviceCreatePipelineLayout(device: *dgpu.Device, pipeline_layout_descriptor: *const dgpu.PipelineLayout.Descriptor) *dgpu.PipelineLayout {
        //     return T.deviceCreatePipelineLayout(device, pipeline_layout_descriptor);
        // }

        // // DGPU_EXPORT WGPUQuerySet dgpuDeviceCreateQuerySet(WGPUDevice device, WGPUQuerySetDescriptor const * descriptor);
        // export fn dgpuDeviceCreateQuerySet(device: *dgpu.Device, descriptor: dgpu.QuerySet.Descriptor) *dgpu.QuerySet {
        //     return T.deviceCreateQuerySet(device, descriptor);
        // }

        // // DGPU_EXPORT WGPURenderBundleEncoder dgpuDeviceCreateRenderBundleEncoder(WGPUDevice device, WGPURenderBundleEncoderDescriptor const * descriptor);
        // export fn dgpuDeviceCreateRenderBundleEncoder(device: *dgpu.Device, descriptor: dgpu.RenderBundleEncoder.Descriptor) *dgpu.RenderBundleEncoder {
        //     return T.deviceCreateRenderBundleEncoder(device, descriptor);
        // }

        // // DGPU_EXPORT WGPURenderPipeline dgpuDeviceCreateRenderPipeline(WGPUDevice device, WGPURenderPipelineDescriptor const * descriptor);
        // export fn dgpuDeviceCreateRenderPipeline(device: *dgpu.Device, descriptor: dgpu.RenderPipeline.Descriptor) *dgpu.RenderPipeline {
        //     return T.deviceCreateRenderPipeline(device, descriptor);
        // }

        // // DGPU_EXPORT void dgpuDeviceCreateRenderPipelineAsync(WGPUDevice device, WGPURenderPipelineDescriptor const * descriptor, WGPUCreateRenderPipelineAsyncCallback callback, void * userdata);
        // export fn dgpuDeviceCreateRenderPipelineAsync(device: *dgpu.Device, descriptor: dgpu.RenderPipeline.Descriptor, callback: dgpu.CreateRenderPipelineAsyncCallback, userdata: ?*anyopaque) void {
        //     T.deviceCreateRenderPipelineAsync(device, descriptor, callback, userdata);
        // }

        // // DGPU_EXPORT WGPUSampler dgpuDeviceCreateSampler(WGPUDevice device, WGPUSamplerDescriptor const * descriptor /* nullable */);
        // export fn dgpuDeviceCreateSampler(device: *dgpu.Device, descriptor: dgpu.Sampler.Descriptor) *dgpu.Sampler {
        //     return T.deviceCreateSampler(device, descriptor);
        // }

        // // DGPU_EXPORT WGPUShaderModule dgpuDeviceCreateShaderModule(WGPUDevice device, WGPUShaderModuleDescriptor const * descriptor);
        // export fn dgpuDeviceCreateShaderModule(device: *dgpu.Device, descriptor: dgpu.ShaderModule.Descriptor) *dgpu.ShaderModule {
        //     return T.deviceCreateShaderModule(device, descriptor);
        // }

        // // DGPU_EXPORT WGPUSwapChain dgpuDeviceCreateSwapChain(WGPUDevice device, WGPUSurface surface /* nullable */, WGPUSwapChainDescriptor const * descriptor);
        // export fn dgpuDeviceCreateSwapChain(device: *dgpu.Device, surface: ?*dgpu.Surface, descriptor: dgpu.SwapChain.Descriptor) *dgpu.SwapChain {
        //     return T.deviceCreateSwapChain(device, surface, descriptor);
        // }

        // // DGPU_EXPORT WGPUTexture dgpuDeviceCreateTexture(WGPUDevice device, WGPUTextureDescriptor const * descriptor);
        // export fn dgpuDeviceCreateTexture(device: *dgpu.Device, descriptor: dgpu.Texture.Descriptor) *dgpu.Texture {
        //     return T.deviceCreateTexture(device, descriptor);
        // }

        // // DGPU_EXPORT void dgpuDeviceDestroy(WGPUDevice device);
        // export fn dgpuDeviceDestroy(device: *dgpu.Device) void {
        //     T.deviceDestroy(device);
        // }

        // // DGPU_EXPORT size_t dgpuDeviceEnumerateFeatures(WGPUDevice device, WGPUFeatureName * features);
        // export fn dgpuDeviceEnumerateFeatures(device: *dgpu.Device, features: ?[*]dgpu.FeatureName) usize {
        //     return T.deviceEnumerateFeatures(device, features);
        // }

        // // DGPU_EXPORT WGPUBool dgpuDeviceGetLimits(WGPUDevice device, WGPUSupportedLimits * limits);
        // export fn dgpuDeviceGetLimits(device: *dgpu.Device, limits: *dgpu.Limits) u32 {
        //     return T.deviceGetLimits(device, limits);
        // }

        // // DGPU_EXPORT WGPUSharedFence dgpuDeviceImportSharedFence(WGPUDevice device, WGPUSharedFenceDescriptor const * descriptor);
        // export fn dgpuDeviceImportSharedFence(device: *dgpu.Device, descriptor: dgpu.SharedFence.Descriptor) *dgpu.SharedFence {
        //     return T.deviceImportSharedFence(device, descriptor);
        // }

        // // DGPU_EXPORT WGPUSharedTextureMemory dgpuDeviceImportSharedTextureMemory(WGPUDevice device, WGPUSharedTextureMemoryDescriptor const * descriptor);
        // export fn dgpuDeviceImportSharedTextureMemory(device: *dgpu.Device, descriptor: dgpu.SharedTextureMemory.Descriptor) *dgpu.SharedTextureMemory {
        //     return T.deviceImportSharedTextureMemory(device, descriptor);
        // }

        // // DGPU_EXPORT WGPUQueue dgpuDeviceGetQueue(WGPUDevice device);
        // export fn dgpuDeviceGetQueue(device: *dgpu.Device) *dgpu.Queue {
        //     return T.deviceGetQueue(device);
        // }

        // // DGPU_EXPORT bool dgpuDeviceHasFeature(WGPUDevice device, WGPUFeatureName feature);
        // export fn dgpuDeviceHasFeature(device: *dgpu.Device, feature: dgpu.FeatureName) u32 {
        //     return T.deviceHasFeature(device, feature);
        // }

        // // DGPU_EXPORT void dgpuDeviceInjectError(WGPUDevice device, WGPUErrorType type, char const * message);
        // export fn dgpuDeviceInjectError(device: *dgpu.Device, typ: dgpu.ErrorType, message: [*:0]const u8) void {
        //     T.deviceInjectError(device, typ, message);
        // }

        // // DGPU_EXPORT void dgpuDevicePopErrorScope(WGPUDevice device, WGPUErrorCallback callback, void * userdata);
        // export fn dgpuDevicePopErrorScope(device: *dgpu.Device, callback: dgpu.ErrorCallback, userdata: ?*anyopaque) void {
        //     T.devicePopErrorScope(device, callback, userdata);
        // }

        // // DGPU_EXPORT void dgpuDevicePushErrorScope(WGPUDevice device, WGPUErrorFilter filter);
        // export fn dgpuDevicePushErrorScope(device: *dgpu.Device, filter: dgpu.ErrorFilter) void {
        //     T.devicePushErrorScope(device, filter);
        // }

        // // TODO: dawn: callback not marked as nullable in dawn.json but in fact is.
        // // DGPU_EXPORT void dgpuDeviceSetDeviceLostCallback(WGPUDevice device, WGPUDeviceLostCallback callback, void * userdata);
        // export fn dgpuDeviceSetDeviceLostCallback(device: *dgpu.Device, callback: ?dgpu.Device.LostCallback, userdata: ?*anyopaque) void {
        //     T.deviceSetDeviceLostCallback(device, callback, userdata);
        // }

        // // DGPU_EXPORT void dgpuDeviceSetLabel(WGPUDevice device, char const * label);
        // export fn dgpuDeviceSetLabel(device: *dgpu.Device, label: [:0]const u8) void {
        //     T.deviceSetLabel(device, label);
        // }

        // // TODO: dawn: callback not marked as nullable in dawn.json but in fact is.
        // // DGPU_EXPORT void dgpuDeviceSetLoggingCallback(WGPUDevice device, WGPULoggingCallback callback, void * userdata);
        // export fn dgpuDeviceSetLoggingCallback(device: *dgpu.Device, callback: ?dgpu.LoggingCallback, userdata: ?*anyopaque) void {
        //     T.deviceSetLoggingCallback(device, callback, userdata);
        // }

        // // TODO: dawn: callback not marked as nullable in dawn.json but in fact is.
        // // DGPU_EXPORT void dgpuDeviceSetUncapturedErrorCallback(WGPUDevice device, WGPUErrorCallback callback, void * userdata);
        // export fn dgpuDeviceSetUncapturedErrorCallback(device: *dgpu.Device, callback: ?dgpu.ErrorCallback, userdata: ?*anyopaque) void {
        //     T.deviceSetUncapturedErrorCallback(device, callback, userdata);
        // }

        // // DGPU_EXPORT void dgpuDeviceTick(WGPUDevice device);
        // export fn dgpuDeviceTick(device: *dgpu.Device) void {
        //     T.deviceTick(device);
        // }

        // // DGPU_EXPORT void dgpuMachDeviceWaitForCommandsToBeScheduled(WGPUDevice device);
        // export fn dgpuMachDeviceWaitForCommandsToBeScheduled(device: *dgpu.Device) void {
        //     T.machDeviceWaitForCommandsToBeScheduled(device);
        // }

        // // DGPU_EXPORT void dgpuDeviceReference(WGPUDevice device);
        // export fn dgpuDeviceReference(device: *dgpu.Device) void {
        //     T.deviceReference(device);
        // }

        // // DGPU_EXPORT void dgpuDeviceRelease(WGPUDevice device);
        // export fn dgpuDeviceRelease(device: *dgpu.Device) void {
        //     T.deviceRelease(device);
        // }

        // // DGPU_EXPORT void dgpuExternalTextureDestroy(WGPUExternalTexture externalTexture);
        // export fn dgpuExternalTextureDestroy(external_texture: *dgpu.ExternalTexture) void {
        //     T.externalTextureDestroy(external_texture);
        // }

        // // DGPU_EXPORT void dgpuExternalTextureSetLabel(WGPUExternalTexture externalTexture, char const * label);
        // export fn dgpuExternalTextureSetLabel(external_texture: *dgpu.ExternalTexture, label: [:0]const u8) void {
        //     T.externalTextureSetLabel(external_texture, label);
        // }

        // // DGPU_EXPORT void dgpuExternalTextureReference(WGPUExternalTexture externalTexture);
        // export fn dgpuExternalTextureReference(external_texture: *dgpu.ExternalTexture) void {
        //     T.externalTextureReference(external_texture);
        // }

        // // DGPU_EXPORT void dgpuExternalTextureRelease(WGPUExternalTexture externalTexture);
        // export fn dgpuExternalTextureRelease(external_texture: *dgpu.ExternalTexture) void {
        //     T.externalTextureRelease(external_texture);
        // }

        // // DGPU_EXPORT WGPUSurface dgpuInstanceCreateSurface(WGPUInstance instance, WGPUSurfaceDescriptor const * descriptor);
        // export fn dgpuInstanceCreateSurface(instance: *dgpu.Instance, descriptor: dgpu.Surface.Descriptor) *dgpu.Surface {
        //     return T.instanceCreateSurface(instance, descriptor);
        // }

        // // DGPU_EXPORT void instanceProcessEvents(WGPUInstance instance);
        // export fn dgpuInstanceProcessEvents(instance: *dgpu.Instance) void {
        //     T.instanceProcessEvents(instance);
        // }

        // // DGPU_EXPORT void dgpuInstanceRequestAdapter(WGPUInstance instance, WGPURequestAdapterOptions const * options /* nullable */, WGPURequestAdapterCallback callback, void * userdata);
        // export fn dgpuInstanceRequestAdapter(instance: *dgpu.Instance, options: ?*const dgpu.RequestAdapterOptions, callback: dgpu.RequestAdapterCallback, userdata: ?*anyopaque) void {
        //     T.instanceRequestAdapter(instance, options, callback, userdata);
        // }

        // // DGPU_EXPORT void dgpuInstanceReference(WGPUInstance instance);
        // export fn dgpuInstanceReference(instance: *dgpu.Instance) void {
        //     T.instanceReference(instance);
        // }

        // // DGPU_EXPORT void dgpuInstanceRelease(WGPUInstance instance);
        // export fn dgpuInstanceRelease(instance: *dgpu.Instance) void {
        //     T.instanceRelease(instance);
        // }

        // // DGPU_EXPORT void dgpuPipelineLayoutSetLabel(WGPUPipelineLayout pipelineLayout, char const * label);
        // export fn dgpuPipelineLayoutSetLabel(pipeline_layout: *dgpu.PipelineLayout, label: [:0]const u8) void {
        //     T.pipelineLayoutSetLabel(pipeline_layout, label);
        // }

        // // DGPU_EXPORT void dgpuPipelineLayoutReference(WGPUPipelineLayout pipelineLayout);
        // export fn dgpuPipelineLayoutReference(pipeline_layout: *dgpu.PipelineLayout) void {
        //     T.pipelineLayoutReference(pipeline_layout);
        // }

        // // DGPU_EXPORT void dgpuPipelineLayoutRelease(WGPUPipelineLayout pipelineLayout);
        // export fn dgpuPipelineLayoutRelease(pipeline_layout: *dgpu.PipelineLayout) void {
        //     T.pipelineLayoutRelease(pipeline_layout);
        // }

        // // DGPU_EXPORT void dgpuQuerySetDestroy(WGPUQuerySet querySet);
        // export fn dgpuQuerySetDestroy(query_set: *dgpu.QuerySet) void {
        //     T.querySetDestroy(query_set);
        // }

        // // DGPU_EXPORT uint32_t dgpuQuerySetGetCount(WGPUQuerySet querySet);
        // export fn dgpuQuerySetGetCount(query_set: *dgpu.QuerySet) u32 {
        //     return T.querySetGetCount(query_set);
        // }

        // // DGPU_EXPORT WGPUQueryType dgpuQuerySetGetType(WGPUQuerySet querySet);
        // export fn dgpuQuerySetGetType(query_set: *dgpu.QuerySet) dgpu.QueryType {
        //     return T.querySetGetType(query_set);
        // }

        // // DGPU_EXPORT void dgpuQuerySetSetLabel(WGPUQuerySet querySet, char const * label);
        // export fn dgpuQuerySetSetLabel(query_set: *dgpu.QuerySet, label: [:0]const u8) void {
        //     T.querySetSetLabel(query_set, label);
        // }

        // // DGPU_EXPORT void dgpuQuerySetReference(WGPUQuerySet querySet);
        // export fn dgpuQuerySetReference(query_set: *dgpu.QuerySet) void {
        //     T.querySetReference(query_set);
        // }

        // // DGPU_EXPORT void dgpuQuerySetRelease(WGPUQuerySet querySet);
        // export fn dgpuQuerySetRelease(query_set: *dgpu.QuerySet) void {
        //     T.querySetRelease(query_set);
        // }

        // // DGPU_EXPORT void dgpuQueueCopyTextureForBrowser(WGPUQueue queue, WGPUImageCopyTexture const * source, WGPUImageCopyTexture const * destination, WGPUExtent3D const * copySize, WGPUCopyTextureForBrowserOptions const * options);
        // export fn dgpuQueueCopyTextureForBrowser(queue: *dgpu.Queue, source: *const dgpu.ImageCopyTexture, destination: *const dgpu.ImageCopyTexture, copy_size: *const dgpu.Extent3D, options: *const dgpu.CopyTextureForBrowserOptions) void {
        //     T.queueCopyTextureForBrowser(queue, source, destination, copy_size, options);
        // }

        // // DGPU_EXPORT void dgpuQueueOnSubmittedWorkDone(WGPUQueue queue, uint64_t signalValue, WGPUQueueWorkDoneCallback callback, void * userdata);
        // export fn dgpuQueueOnSubmittedWorkDone(queue: *dgpu.Queue, signal_value: u64, callback: dgpu.Queue.WorkDoneCallback, userdata: ?*anyopaque) void {
        //     T.queueOnSubmittedWorkDone(queue, signal_value, callback, userdata);
        // }

        // // DGPU_EXPORT void dgpuQueueSetLabel(WGPUQueue queue, char const * label);
        // export fn dgpuQueueSetLabel(queue: *dgpu.Queue, label: [:0]const u8) void {
        //     T.queueSetLabel(queue, label);
        // }

        // // DGPU_EXPORT void dgpuQueueSubmit(WGPUQueue queue, size_t commandCount, WGPUCommandBuffer const * commands);
        // export fn dgpuQueueSubmit(queue: *dgpu.Queue, command_count: usize, commands: [*]const *const dgpu.CommandBuffer) void {
        //     T.queueSubmit(queue, command_count, commands);
        // }

        // // DGPU_EXPORT void dgpuQueueWriteBuffer(WGPUQueue queue, WGPUBuffer buffer, uint64_t bufferOffset, void const * data, size_t size);
        // export fn dgpuQueueWriteBuffer(queue: *dgpu.Queue, buffer: *dgpu.Buffer, buffer_offset: u64, data: *const anyopaque, size: usize) void {
        //     T.queueWriteBuffer(queue, buffer, buffer_offset, data, size);
        // }

        // // DGPU_EXPORT void dgpuQueueWriteTexture(WGPUQueue queue, WGPUImageCopyTexture const * destination, void const * data, size_t dataSize, WGPUTextureDataLayout const * dataLayout, WGPUExtent3D const * writeSize);
        // export fn dgpuQueueWriteTexture(queue: *dgpu.Queue, destination: *const dgpu.ImageCopyTexture, data: *const anyopaque, data_size: usize, data_layout: *const dgpu.Texture.DataLayout, write_size: *const dgpu.Extent3D) void {
        //     T.queueWriteTexture(queue, destination, data, data_size, data_layout, write_size);
        // }

        // // DGPU_EXPORT void dgpuQueueReference(WGPUQueue queue);
        // export fn dgpuQueueReference(queue: *dgpu.Queue) void {
        //     T.queueReference(queue);
        // }

        // // DGPU_EXPORT void dgpuQueueRelease(WGPUQueue queue);
        // export fn dgpuQueueRelease(queue: *dgpu.Queue) void {
        //     T.queueRelease(queue);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleSetLabel(WGPURenderBundle renderBundle, char const * label);
        // export fn dgpuRenderBundleSetLabel(render_bundle: *dgpu.RenderBundle, label: [:0]const u8) void {
        //     T.renderBundleSetLabel(render_bundle, label);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleReference(WGPURenderBundle renderBundle);
        // export fn dgpuRenderBundleReference(render_bundle: *dgpu.RenderBundle) void {
        //     T.renderBundleReference(render_bundle);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleRelease(WGPURenderBundle renderBundle);
        // export fn dgpuRenderBundleRelease(render_bundle: *dgpu.RenderBundle) void {
        //     T.renderBundleRelease(render_bundle);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleEncoderDraw(WGPURenderBundleEncoder renderBundleEncoder, uint32_t vertexCount, uint32_t instanceCount, uint32_t firstVertex, uint32_t firstInstance);
        // export fn dgpuRenderBundleEncoderDraw(render_bundle_encoder: *dgpu.RenderBundleEncoder, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void {
        //     T.renderBundleEncoderDraw(render_bundle_encoder, vertex_count, instance_count, first_vertex, first_instance);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleEncoderDrawIndexed(WGPURenderBundleEncoder renderBundleEncoder, uint32_t indexCount, uint32_t instanceCount, uint32_t firstIndex, int32_t baseVertex, uint32_t firstInstance);
        // export fn dgpuRenderBundleEncoderDrawIndexed(render_bundle_encoder: *dgpu.RenderBundleEncoder, index_count: u32, instance_count: u32, first_index: u32, base_vertex: i32, first_instance: u32) void {
        //     T.renderBundleEncoderDrawIndexed(render_bundle_encoder, index_count, instance_count, first_index, base_vertex, first_instance);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleEncoderDrawIndexedIndirect(WGPURenderBundleEncoder renderBundleEncoder, WGPUBuffer indirectBuffer, uint64_t indirectOffset);
        // export fn dgpuRenderBundleEncoderDrawIndexedIndirect(render_bundle_encoder: *dgpu.RenderBundleEncoder, indirect_buffer: *dgpu.Buffer, indirect_offset: u64) void {
        //     T.renderBundleEncoderDrawIndexedIndirect(render_bundle_encoder, indirect_buffer, indirect_offset);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleEncoderDrawIndirect(WGPURenderBundleEncoder renderBundleEncoder, WGPUBuffer indirectBuffer, uint64_t indirectOffset);
        // export fn dgpuRenderBundleEncoderDrawIndirect(render_bundle_encoder: *dgpu.RenderBundleEncoder, indirect_buffer: *dgpu.Buffer, indirect_offset: u64) void {
        //     T.renderBundleEncoderDrawIndirect(render_bundle_encoder, indirect_buffer, indirect_offset);
        // }

        // // DGPU_EXPORT WGPURenderBundle dgpuRenderBundleEncoderFinish(WGPURenderBundleEncoder renderBundleEncoder, WGPURenderBundleDescriptor const * descriptor /* nullable */);
        // export fn dgpuRenderBundleEncoderFinish(render_bundle_encoder: *dgpu.RenderBundleEncoder, descriptor: dgpu.RenderBundle.Descriptor) *dgpu.RenderBundle {
        //     return T.renderBundleEncoderFinish(render_bundle_encoder, descriptor);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleEncoderInsertDebugMarker(WGPURenderBundleEncoder renderBundleEncoder, char const * markerLabel);
        // export fn dgpuRenderBundleEncoderInsertDebugMarker(render_bundle_encoder: *dgpu.RenderBundleEncoder, marker_label: [*:0]const u8) void {
        //     T.renderBundleEncoderInsertDebugMarker(render_bundle_encoder, marker_label);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleEncoderPopDebugGroup(WGPURenderBundleEncoder renderBundleEncoder);
        // export fn dgpuRenderBundleEncoderPopDebugGroup(render_bundle_encoder: *dgpu.RenderBundleEncoder) void {
        //     T.renderBundleEncoderPopDebugGroup(render_bundle_encoder);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleEncoderPushDebugGroup(WGPURenderBundleEncoder renderBundleEncoder, char const * groupLabel);
        // export fn dgpuRenderBundleEncoderPushDebugGroup(render_bundle_encoder: *dgpu.RenderBundleEncoder, group_label: [*:0]const u8) void {
        //     T.renderBundleEncoderPushDebugGroup(render_bundle_encoder, group_label);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleEncoderSetBindGroup(WGPURenderBundleEncoder renderBundleEncoder, uint32_t groupIndex, WGPUBindGroup group, size_t dynamicOffsetCount, uint32_t const * dynamicOffsets);
        // export fn dgpuRenderBundleEncoderSetBindGroup(render_bundle_encoder: *dgpu.RenderBundleEncoder, group_index: u32, group: *dgpu.BindGroup, dynamic_offset_count: usize, dynamic_offsets: ?[*]const u32) void {
        //     T.renderBundleEncoderSetBindGroup(render_bundle_encoder, group_index, group, dynamic_offset_count, dynamic_offsets);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleEncoderSetIndexBuffer(WGPURenderBundleEncoder renderBundleEncoder, WGPUBuffer buffer, WGPUIndexFormat format, uint64_t offset, uint64_t size);
        // export fn dgpuRenderBundleEncoderSetIndexBuffer(render_bundle_encoder: *dgpu.RenderBundleEncoder, buffer: *dgpu.Buffer, format: dgpu.IndexFormat, offset: u64, size: u64) void {
        //     T.renderBundleEncoderSetIndexBuffer(render_bundle_encoder, buffer, format, offset, size);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleEncoderSetLabel(WGPURenderBundleEncoder renderBundleEncoder, char const * label);
        // export fn dgpuRenderBundleEncoderSetLabel(render_bundle_encoder: *dgpu.RenderBundleEncoder, label: [:0]const u8) void {
        //     T.renderBundleEncoderSetLabel(render_bundle_encoder, label);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleEncoderSetPipeline(WGPURenderBundleEncoder renderBundleEncoder, WGPURenderPipeline pipeline);
        // export fn dgpuRenderBundleEncoderSetPipeline(render_bundle_encoder: *dgpu.RenderBundleEncoder, pipeline: *dgpu.RenderPipeline) void {
        //     T.renderBundleEncoderSetPipeline(render_bundle_encoder, pipeline);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleEncoderSetVertexBuffer(WGPURenderBundleEncoder renderBundleEncoder, uint32_t slot, WGPUBuffer buffer, uint64_t offset, uint64_t size);
        // export fn dgpuRenderBundleEncoderSetVertexBuffer(render_bundle_encoder: *dgpu.RenderBundleEncoder, slot: u32, buffer: *dgpu.Buffer, offset: u64, size: u64) void {
        //     T.renderBundleEncoderSetVertexBuffer(render_bundle_encoder, slot, buffer, offset, size);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleEncoderReference(WGPURenderBundleEncoder renderBundleEncoder);
        // export fn dgpuRenderBundleEncoderReference(render_bundle_encoder: *dgpu.RenderBundleEncoder) void {
        //     T.renderBundleEncoderReference(render_bundle_encoder);
        // }

        // // DGPU_EXPORT void dgpuRenderBundleEncoderRelease(WGPURenderBundleEncoder renderBundleEncoder);
        // export fn dgpuRenderBundleEncoderRelease(render_bundle_encoder: *dgpu.RenderBundleEncoder) void {
        //     T.renderBundleEncoderRelease(render_bundle_encoder);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderBeginOcclusionQuery(WGPURenderPassEncoder renderPassEncoder, uint32_t queryIndex);
        // export fn dgpuRenderPassEncoderBeginOcclusionQuery(render_pass_encoder: *dgpu.RenderPassEncoder, query_index: u32) void {
        //     T.renderPassEncoderBeginOcclusionQuery(render_pass_encoder, query_index);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderDraw(WGPURenderPassEncoder renderPassEncoder, uint32_t vertexCount, uint32_t instanceCount, uint32_t firstVertex, uint32_t firstInstance);
        // export fn dgpuRenderPassEncoderDraw(render_pass_encoder: *dgpu.RenderPassEncoder, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void {
        //     T.renderPassEncoderDraw(render_pass_encoder, vertex_count, instance_count, first_vertex, first_instance);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderDrawIndexed(WGPURenderPassEncoder renderPassEncoder, uint32_t indexCount, uint32_t instanceCount, uint32_t firstIndex, int32_t baseVertex, uint32_t firstInstance);
        // export fn dgpuRenderPassEncoderDrawIndexed(render_pass_encoder: *dgpu.RenderPassEncoder, index_count: u32, instance_count: u32, first_index: u32, base_vertex: i32, first_instance: u32) void {
        //     T.renderPassEncoderDrawIndexed(render_pass_encoder, index_count, instance_count, first_index, base_vertex, first_instance);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderDrawIndexedIndirect(WGPURenderPassEncoder renderPassEncoder, WGPUBuffer indirectBuffer, uint64_t indirectOffset);
        // export fn dgpuRenderPassEncoderDrawIndexedIndirect(render_pass_encoder: *dgpu.RenderPassEncoder, indirect_buffer: *dgpu.Buffer, indirect_offset: u64) void {
        //     T.renderPassEncoderDrawIndexedIndirect(render_pass_encoder, indirect_buffer, indirect_offset);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderDrawIndirect(WGPURenderPassEncoder renderPassEncoder, WGPUBuffer indirectBuffer, uint64_t indirectOffset);
        // export fn dgpuRenderPassEncoderDrawIndirect(render_pass_encoder: *dgpu.RenderPassEncoder, indirect_buffer: *dgpu.Buffer, indirect_offset: u64) void {
        //     T.renderPassEncoderDrawIndirect(render_pass_encoder, indirect_buffer, indirect_offset);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderEnd(WGPURenderPassEncoder renderPassEncoder);
        // export fn dgpuRenderPassEncoderEnd(render_pass_encoder: *dgpu.RenderPassEncoder) void {
        //     T.renderPassEncoderEnd(render_pass_encoder);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderEndOcclusionQuery(WGPURenderPassEncoder renderPassEncoder);
        // export fn dgpuRenderPassEncoderEndOcclusionQuery(render_pass_encoder: *dgpu.RenderPassEncoder) void {
        //     T.renderPassEncoderEndOcclusionQuery(render_pass_encoder);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderExecuteBundles(WGPURenderPassEncoder renderPassEncoder, size_t bundleCount, WGPURenderBundle const * bundles);
        // export fn dgpuRenderPassEncoderExecuteBundles(render_pass_encoder: *dgpu.RenderPassEncoder, bundles_count: usize, bundles: [*]const *const dgpu.RenderBundle) void {
        //     T.renderPassEncoderExecuteBundles(render_pass_encoder, bundles_count, bundles);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderInsertDebugMarker(WGPURenderPassEncoder renderPassEncoder, char const * markerLabel);
        // export fn dgpuRenderPassEncoderInsertDebugMarker(render_pass_encoder: *dgpu.RenderPassEncoder, marker_label: [*:0]const u8) void {
        //     T.renderPassEncoderInsertDebugMarker(render_pass_encoder, marker_label);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderPopDebugGroup(WGPURenderPassEncoder renderPassEncoder);
        // export fn dgpuRenderPassEncoderPopDebugGroup(render_pass_encoder: *dgpu.RenderPassEncoder) void {
        //     T.renderPassEncoderPopDebugGroup(render_pass_encoder);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderPushDebugGroup(WGPURenderPassEncoder renderPassEncoder, char const * groupLabel);
        // export fn dgpuRenderPassEncoderPushDebugGroup(render_pass_encoder: *dgpu.RenderPassEncoder, group_label: [*:0]const u8) void {
        //     T.renderPassEncoderPushDebugGroup(render_pass_encoder, group_label);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderSetBindGroup(WGPURenderPassEncoder renderPassEncoder, uint32_t groupIndex, WGPUBindGroup group, size_t dynamicOffsetCount, uint32_t const * dynamicOffsets);
        // export fn dgpuRenderPassEncoderSetBindGroup(render_pass_encoder: *dgpu.RenderPassEncoder, group_index: u32, group: *dgpu.BindGroup, dynamic_offset_count: usize, dynamic_offsets: ?[*]const u32) void {
        //     T.renderPassEncoderSetBindGroup(render_pass_encoder, group_index, group, dynamic_offset_count, dynamic_offsets);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderSetBlendConstant(WGPURenderPassEncoder renderPassEncoder, WGPUColor const * color);
        // export fn dgpuRenderPassEncoderSetBlendConstant(render_pass_encoder: *dgpu.RenderPassEncoder, color: *const dgpu.Color) void {
        //     T.renderPassEncoderSetBlendConstant(render_pass_encoder, color);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderSetIndexBuffer(WGPURenderPassEncoder renderPassEncoder, WGPUBuffer buffer, WGPUIndexFormat format, uint64_t offset, uint64_t size);
        // export fn dgpuRenderPassEncoderSetIndexBuffer(render_pass_encoder: *dgpu.RenderPassEncoder, buffer: *dgpu.Buffer, format: dgpu.IndexFormat, offset: u64, size: u64) void {
        //     T.renderPassEncoderSetIndexBuffer(render_pass_encoder, buffer, format, offset, size);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderSetLabel(WGPURenderPassEncoder renderPassEncoder, char const * label);
        // export fn dgpuRenderPassEncoderSetLabel(render_pass_encoder: *dgpu.RenderPassEncoder, label: [:0]const u8) void {
        //     T.renderPassEncoderSetLabel(render_pass_encoder, label);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderSetPipeline(WGPURenderPassEncoder renderPassEncoder, WGPURenderPipeline pipeline);
        // export fn dgpuRenderPassEncoderSetPipeline(render_pass_encoder: *dgpu.RenderPassEncoder, pipeline: *dgpu.RenderPipeline) void {
        //     T.renderPassEncoderSetPipeline(render_pass_encoder, pipeline);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderSetScissorRect(WGPURenderPassEncoder renderPassEncoder, uint32_t x, uint32_t y, uint32_t width, uint32_t height);
        // export fn dgpuRenderPassEncoderSetScissorRect(render_pass_encoder: *dgpu.RenderPassEncoder, x: u32, y: u32, width: u32, height: u32) void {
        //     T.renderPassEncoderSetScissorRect(render_pass_encoder, x, y, width, height);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderSetStencilReference(WGPURenderPassEncoder renderPassEncoder, uint32_t reference);
        // export fn dgpuRenderPassEncoderSetStencilReference(render_pass_encoder: *dgpu.RenderPassEncoder, reference: u32) void {
        //     T.renderPassEncoderSetStencilReference(render_pass_encoder, reference);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderSetVertexBuffer(WGPURenderPassEncoder renderPassEncoder, uint32_t slot, WGPUBuffer buffer, uint64_t offset, uint64_t size);
        // export fn dgpuRenderPassEncoderSetVertexBuffer(render_pass_encoder: *dgpu.RenderPassEncoder, slot: u32, buffer: *dgpu.Buffer, offset: u64, size: u64) void {
        //     T.renderPassEncoderSetVertexBuffer(render_pass_encoder, slot, buffer, offset, size);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderSetViewport(WGPURenderPassEncoder renderPassEncoder, float x, float y, float width, float height, float minDepth, float maxDepth);
        // export fn dgpuRenderPassEncoderSetViewport(render_pass_encoder: *dgpu.RenderPassEncoder, x: f32, y: f32, width: f32, height: f32, min_depth: f32, max_depth: f32) void {
        //     T.renderPassEncoderSetViewport(render_pass_encoder, x, y, width, height, min_depth, max_depth);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderWriteTimestamp(WGPURenderPassEncoder renderPassEncoder, WGPUQuerySet querySet, uint32_t queryIndex);
        // export fn dgpuRenderPassEncoderWriteTimestamp(render_pass_encoder: *dgpu.RenderPassEncoder, query_set: *dgpu.QuerySet, query_index: u32) void {
        //     T.renderPassEncoderWriteTimestamp(render_pass_encoder, query_set, query_index);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderReference(WGPURenderPassEncoder renderPassEncoder);
        // export fn dgpuRenderPassEncoderReference(render_pass_encoder: *dgpu.RenderPassEncoder) void {
        //     T.renderPassEncoderReference(render_pass_encoder);
        // }

        // // DGPU_EXPORT void dgpuRenderPassEncoderRelease(WGPURenderPassEncoder renderPassEncoder);
        // export fn dgpuRenderPassEncoderRelease(render_pass_encoder: *dgpu.RenderPassEncoder) void {
        //     T.renderPassEncoderRelease(render_pass_encoder);
        // }

        // // DGPU_EXPORT WGPUBindGroupLayout dgpuRenderPipelineGetBindGroupLayout(WGPURenderPipeline renderPipeline, uint32_t groupIndex);
        // export fn dgpuRenderPipelineGetBindGroupLayout(render_pipeline: *dgpu.RenderPipeline, group_index: u32) *dgpu.BindGroupLayout {
        //     return T.renderPipelineGetBindGroupLayout(render_pipeline, group_index);
        // }

        // // DGPU_EXPORT void dgpuRenderPipelineSetLabel(WGPURenderPipeline renderPipeline, char const * label);
        // export fn dgpuRenderPipelineSetLabel(render_pipeline: *dgpu.RenderPipeline, label: [:0]const u8) void {
        //     T.renderPipelineSetLabel(render_pipeline, label);
        // }

        // // DGPU_EXPORT void dgpuRenderPipelineReference(WGPURenderPipeline renderPipeline);
        // export fn dgpuRenderPipelineReference(render_pipeline: *dgpu.RenderPipeline) void {
        //     T.renderPipelineReference(render_pipeline);
        // }

        // // DGPU_EXPORT void dgpuRenderPipelineRelease(WGPURenderPipeline renderPipeline);
        // export fn dgpuRenderPipelineRelease(render_pipeline: *dgpu.RenderPipeline) void {
        //     T.renderPipelineRelease(render_pipeline);
        // }

        // // DGPU_EXPORT void dgpuSamplerSetLabel(WGPUSampler sampler, char const * label);
        // export fn dgpuSamplerSetLabel(sampler: *dgpu.Sampler, label: [:0]const u8) void {
        //     T.samplerSetLabel(sampler, label);
        // }

        // // DGPU_EXPORT void dgpuSamplerReference(WGPUSampler sampler);
        // export fn dgpuSamplerReference(sampler: *dgpu.Sampler) void {
        //     T.samplerReference(sampler);
        // }

        // // DGPU_EXPORT void dgpuSamplerRelease(WGPUSampler sampler);
        // export fn dgpuSamplerRelease(sampler: *dgpu.Sampler) void {
        //     T.samplerRelease(sampler);
        // }

        // // DGPU_EXPORT void dgpuShaderModuleGetCompilationInfo(WGPUShaderModule shaderModule, WGPUCompilationInfoCallback callback, void * userdata);
        // export fn dgpuShaderModuleGetCompilationInfo(shader_module: *dgpu.ShaderModule, callback: dgpu.CompilationInfoCallback, userdata: ?*anyopaque) void {
        //     T.shaderModuleGetCompilationInfo(shader_module, callback, userdata);
        // }

        // // DGPU_EXPORT void dgpuShaderModuleSetLabel(WGPUShaderModule shaderModule, char const * label);
        // export fn dgpuShaderModuleSetLabel(shader_module: *dgpu.ShaderModule, label: [:0]const u8) void {
        //     T.shaderModuleSetLabel(shader_module, label);
        // }

        // // DGPU_EXPORT void dgpuShaderModuleReference(WGPUShaderModule shaderModule);
        // export fn dgpuShaderModuleReference(shader_module: *dgpu.ShaderModule) void {
        //     T.shaderModuleReference(shader_module);
        // }

        // // DGPU_EXPORT void dgpuShaderModuleRelease(WGPUShaderModule shaderModule);
        // export fn dgpuShaderModuleRelease(shader_module: *dgpu.ShaderModule) void {
        //     T.shaderModuleRelease(shader_module);
        // }

        // // DGPU_EXPORT void dgpuSharedFenceExportInfo(WGPUSharedFence sharedFence, WGPUSharedFenceExportInfo * info);
        // export fn dgpuSharedFenceExportInfo(shared_fence: *dgpu.SharedFence, info: *dgpu.SharedFence.ExportInfo) void {
        //     T.sharedFenceExportInfo(shared_fence, info);
        // }

        // // DGPU_EXPORT void dgpuSharedFenceReference(WGPUSharedFence sharedFence);
        // export fn dgpuSharedFenceReference(shared_fence: *dgpu.SharedFence) void {
        //     T.sharedFenceReference(shared_fence);
        // }

        // // DGPU_EXPORT void dgpuSharedFenceRelease(WGPUSharedFence sharedFence);
        // export fn dgpuSharedFenceRelease(shared_fence: *dgpu.SharedFence) void {
        //     T.sharedFenceRelease(shared_fence);
        // }

        // // DGPU_EXPORT void dgpuSharedTextureMemoryBeginAccess(WGPUSharedTextureMemory sharedTextureMemory, WGPUTexture texture, WGPUSharedTextureMemoryBeginAccessDescriptor const * descriptor);
        // export fn dgpuSharedTextureMemoryBeginAccess(shared_texture_memory: *dgpu.SharedTextureMemory, texture: *dgpu.Texture, descriptor: dgpu.SharedTextureMemory.BeginAccessDescriptor) void {
        //     T.sharedTextureMemoryBeginAccess(shared_texture_memory, texture, descriptor);
        // }

        // // DGPU_EXPORT WGPUTexture dgpuSharedTextureMemoryCreateTexture(WGPUSharedTextureMemory sharedTextureMemory, WGPUTextureDescriptor const * descriptor);
        // export fn dgpuSharedTextureMemoryCreateTexture(shared_texture_memory: *dgpu.SharedTextureMemory, descriptor: dgpu.Texture.Descriptor) *dgpu.Texture {
        //     return T.sharedTextureMemoryCreateTexture(shared_texture_memory, descriptor);
        // }

        // // DGPU_EXPORT void dgpuSharedTextureMemoryEndAccess(WGPUSharedTextureMemory sharedTextureMemory, WGPUTexture texture, WGPUSharedTextureMemoryEndAccessState * descriptor);
        // export fn dgpuSharedTextureMemoryEndAccess(shared_texture_memory: *dgpu.SharedTextureMemory, texture: *dgpu.Texture, descriptor: *dgpu.SharedTextureMemory.EndAccessState) void {
        //     T.sharedTextureMemoryEndAccess(shared_texture_memory, texture, descriptor);
        // }

        // // DGPU_EXPORT void dgpuSharedTextureMemoryEndAccessStateFreeMembers(WGPUSharedTextureMemoryEndAccessState value);
        // export fn dgpuSharedTextureMemoryEndAccessStateFreeMembers(value: dgpu.SharedTextureMemory.EndAccessState) void {
        //     T.sharedTextureMemoryEndAccessStateFreeMembers(value);
        // }

        // // DGPU_EXPORT void dgpuSharedTextureMemoryGetProperties(WGPUSharedTextureMemory sharedTextureMemory, WGPUSharedTextureMemoryProperties * properties);
        // export fn dgpuSharedTextureMemoryGetProperties(shared_texture_memory: *dgpu.SharedTextureMemory, properties: *dgpu.SharedTextureMemory.Properties) void {
        //     T.sharedTextureMemoryGetProperties(shared_texture_memory, properties);
        // }

        // // DGPU_EXPORT void dgpuSharedTextureMemorySetLabel(WGPUSharedTextureMemory sharedTextureMemory, char const * label);
        // export fn dgpuSharedTextureMemorySetLabel(shared_texture_memory: *dgpu.SharedTextureMemory, label: [:0]const u8) void {
        //     T.sharedTextureMemorySetLabel(shared_texture_memory, label);
        // }

        // // DGPU_EXPORT void dgpuSharedTextureMemoryReference(WGPUSharedTextureMemory sharedTextureMemory);
        // export fn dgpuSharedTextureMemoryReference(shared_texture_memory: *dgpu.SharedTextureMemory) void {
        //     T.sharedTextureMemoryReference(shared_texture_memory);
        // }

        // // DGPU_EXPORT void dgpuSharedTextureMemoryRelease(WGPUSharedTextureMemory sharedTextureMemory);
        // export fn dgpuSharedTextureMemoryRelease(shared_texture_memory: *dgpu.SharedTextureMemory) void {
        //     T.sharedTextureMemoryRelease(shared_texture_memory);
        // }

        // // DGPU_EXPORT void dgpuSurfaceReference(WGPUSurface surface);
        // export fn dgpuSurfaceReference(surface: *dgpu.Surface) void {
        //     T.surfaceReference(surface);
        // }

        // // DGPU_EXPORT void dgpuSurfaceRelease(WGPUSurface surface);
        // export fn dgpuSurfaceRelease(surface: *dgpu.Surface) void {
        //     T.surfaceRelease(surface);
        // }

        // // DGPU_EXPORT WGPUTexture dgpuSwapChainGetCurrentTexture(WGPUSwapChain swapChain);
        // export fn dgpuSwapChainGetCurrentTexture(swap_chain: *dgpu.SwapChain) ?*dgpu.Texture {
        //     return T.swapChainGetCurrentTexture(swap_chain);
        // }

        // // DGPU_EXPORT WGPUTextureView dgpuSwapChainGetCurrentTextureView(WGPUSwapChain swapChain);
        // export fn dgpuSwapChainGetCurrentTextureView(swap_chain: *dgpu.SwapChain) ?*dgpu.TextureView {
        //     return T.swapChainGetCurrentTextureView(swap_chain);
        // }

        // // DGPU_EXPORT void dgpuSwapChainPresent(WGPUSwapChain swapChain);
        // export fn dgpuSwapChainPresent(swap_chain: *dgpu.SwapChain) void {
        //     T.swapChainPresent(swap_chain);
        // }

        // // DGPU_EXPORT void dgpuSwapChainReference(WGPUSwapChain swapChain);
        // export fn dgpuSwapChainReference(swap_chain: *dgpu.SwapChain) void {
        //     T.swapChainReference(swap_chain);
        // }

        // // DGPU_EXPORT void dgpuSwapChainRelease(WGPUSwapChain swapChain);
        // export fn dgpuSwapChainRelease(swap_chain: *dgpu.SwapChain) void {
        //     T.swapChainRelease(swap_chain);
        // }

        // // DGPU_EXPORT WGPUTextureView dgpuTextureCreateView(WGPUTexture texture, WGPUTextureViewDescriptor const * descriptor /* nullable */);
        // export fn dgpuTextureCreateView(texture: *dgpu.Texture, descriptor: dgpu.TextureView.Descriptor) *dgpu.TextureView {
        //     return T.textureCreateView(texture, descriptor);
        // }

        // // DGPU_EXPORT void dgpuTextureDestroy(WGPUTexture texture);
        // export fn dgpuTextureDestroy(texture: *dgpu.Texture) void {
        //     T.textureDestroy(texture);
        // }

        // // DGPU_EXPORT uint32_t dgpuTextureGetDepthOrArrayLayers(WGPUTexture texture);
        // export fn dgpuTextureGetDepthOrArrayLayers(texture: *dgpu.Texture) u32 {
        //     return T.textureGetDepthOrArrayLayers(texture);
        // }

        // // DGPU_EXPORT WGPUTextureDimension dgpuTextureGetDimension(WGPUTexture texture);
        // export fn dgpuTextureGetDimension(texture: *dgpu.Texture) dgpu.Texture.Dimension {
        //     return T.textureGetDimension(texture);
        // }

        // // DGPU_EXPORT WGPUTextureFormat dgpuTextureGetFormat(WGPUTexture texture);
        // export fn dgpuTextureGetFormat(texture: *dgpu.Texture) dgpu.Texture.Format {
        //     return T.textureGetFormat(texture);
        // }

        // // DGPU_EXPORT uint32_t dgpuTextureGetHeight(WGPUTexture texture);
        // export fn dgpuTextureGetHeight(texture: *dgpu.Texture) u32 {
        //     return T.textureGetHeight(texture);
        // }

        // // DGPU_EXPORT uint32_t dgpuTextureGetMipLevelCount(WGPUTexture texture);
        // export fn dgpuTextureGetMipLevelCount(texture: *dgpu.Texture) u32 {
        //     return T.textureGetMipLevelCount(texture);
        // }

        // // DGPU_EXPORT uint32_t dgpuTextureGetSampleCount(WGPUTexture texture);
        // export fn dgpuTextureGetSampleCount(texture: *dgpu.Texture) u32 {
        //     return T.textureGetSampleCount(texture);
        // }

        // // DGPU_EXPORT WGPUTextureUsage dgpuTextureGetUsage(WGPUTexture texture);
        // export fn dgpuTextureGetUsage(texture: *dgpu.Texture) dgpu.Texture.UsageFlags {
        //     return T.textureGetUsage(texture);
        // }

        // // DGPU_EXPORT uint32_t dgpuTextureGetWidth(WGPUTexture texture);
        // export fn dgpuTextureGetWidth(texture: *dgpu.Texture) u32 {
        //     return T.textureGetWidth(texture);
        // }

        // // DGPU_EXPORT void dgpuTextureSetLabel(WGPUTexture texture, char const * label);
        // export fn dgpuTextureSetLabel(texture: *dgpu.Texture, label: [:0]const u8) void {
        //     T.textureSetLabel(texture, label);
        // }

        // // DGPU_EXPORT void dgpuTextureReference(WGPUTexture texture);
        // export fn dgpuTextureReference(texture: *dgpu.Texture) void {
        //     T.textureReference(texture);
        // }

        // // DGPU_EXPORT void dgpuTextureRelease(WGPUTexture texture);
        // export fn dgpuTextureRelease(texture: *dgpu.Texture) void {
        //     T.textureRelease(texture);
        // }

        // // DGPU_EXPORT void dgpuTextureViewSetLabel(WGPUTextureView textureView, char const * label);
        // export fn dgpuTextureViewSetLabel(texture_view: *dgpu.TextureView, label: [:0]const u8) void {
        //     T.textureViewSetLabel(texture_view, label);
        // }

        // // DGPU_EXPORT void dgpuTextureViewReference(WGPUTextureView textureView);
        // export fn dgpuTextureViewReference(texture_view: *dgpu.TextureView) void {
        //     T.textureViewReference(texture_view);
        // }

        // // DGPU_EXPORT void dgpuTextureViewRelease(WGPUTextureView textureView);
        // export fn dgpuTextureViewRelease(texture_view: *dgpu.TextureView) void {
        //     T.textureViewRelease(texture_view);
        // }
    };
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

    // pub inline fn adapterRequestDevice(adapter: *dgpu.Adapter, descriptor: dgpu.Device.Descriptor, callback: dgpu.RequestDeviceCallback, userdata: ?*anyopaque) void {
    //     _ = adapter;
    //     _ = descriptor;
    //     _ = callback;
    //     _ = userdata;
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

    // pub inline fn bufferMapAsync(buffer: *dgpu.Buffer, mode: dgpu.MapModeFlags, offset: usize, size: usize, callback: dgpu.Buffer.MapCallback, userdata: ?*anyopaque) void {
    //     _ = buffer;
    //     _ = mode;
    //     _ = offset;
    //     _ = size;
    //     _ = callback;
    //     _ = userdata;
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

    // pub inline fn deviceCreateComputePipelineAsync(device: *dgpu.Device, descriptor: dgpu.ComputePipeline.Descriptor, callback: dgpu.CreateComputePipelineAsyncCallback, userdata: ?*anyopaque) void {
    //     _ = device;
    //     _ = descriptor;
    //     _ = callback;
    //     _ = userdata;
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

    // pub inline fn deviceCreateExternalTexture(device: *dgpu.Device, external_texture_descriptor: *const dgpu.ExternalTexture.Descriptor) *dgpu.ExternalTexture {
    //     _ = device;
    //     _ = external_texture_descriptor;
    //     unreachable;
    // }

    // pub inline fn deviceCreatePipelineLayout(device: *dgpu.Device, pipeline_layout_descriptor: *const dgpu.PipelineLayout.Descriptor) *dgpu.PipelineLayout {
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

    // pub inline fn deviceCreateRenderPipelineAsync(device: *dgpu.Device, descriptor: dgpu.RenderPipeline.Descriptor, callback: dgpu.CreateRenderPipelineAsyncCallback, userdata: ?*anyopaque) void {
    //     _ = device;
    //     _ = descriptor;
    //     _ = callback;
    //     _ = userdata;
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

    // pub inline fn instanceRequestAdapter(instance: *dgpu.Instance, options: ?*const dgpu.RequestAdapterOptions, callback: dgpu.RequestAdapterCallback, userdata: ?*anyopaque) void {
    //     _ = instance;
    //     _ = options;
    //     _ = callback;
    //     _ = userdata;
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
