const std = @import("std");
const testing = std.testing;

pub const Adapter = @import("adapter.zig").Adapter;
pub const BindGroup = @import("bind_group.zig").BindGroup;
pub const BindGroupLayout = @import("bind_group_layout.zig").BindGroupLayout;
pub const Buffer = @import("buffer.zig").Buffer;
pub const CommandBuffer = @import("command_buffer.zig").CommandBuffer;
pub const CommandEncoder = @import("command_encoder.zig").CommandEncoder;
pub const ComputePassEncoder = @import("compute_pass_encoder.zig").ComputePassEncoder;
pub const ComputePipeline = @import("compute_pipeline.zig").ComputePipeline;
pub const Device = @import("device.zig").Device;
pub const ExternalTexture = @import("external_texture.zig").ExternalTexture;
pub const Instance = @import("instance.zig").Instance;
pub const PipelineLayout = @import("pipeline_layout.zig").PipelineLayout;
pub const QuerySet = @import("query_set.zig").QuerySet;
pub const Queue = @import("queue.zig").Queue;
pub const RenderBundle = @import("render_bundle.zig").RenderBundle;
pub const RenderBundleEncoder = @import("render_bundle_encoder.zig").RenderBundleEncoder;
pub const RenderPassEncoder = @import("render_pass_encoder.zig").RenderPassEncoder;
pub const RenderPipeline = @import("render_pipeline.zig").RenderPipeline;
pub const Sampler = @import("sampler.zig").Sampler;
pub const ShaderModule = @import("shader_module.zig").ShaderModule;
pub const SharedTextureMemory = @import("shared_texture_memory.zig").SharedTextureMemory;
pub const SharedFence = @import("shared_fence.zig").SharedFence;
pub const Surface = @import("surface.zig").Surface;
pub const SwapChain = @import("swap_chain.zig").SwapChain;
pub const Texture = @import("texture.zig").Texture;
pub const TextureView = @import("texture_view.zig").TextureView;

const instance = @import("instance.zig");
const device = @import("device.zig");
const interface = @import("interface.zig");

pub const Impl = interface.Impl;
pub const StubInterface = interface.StubInterface;
pub const Export = interface.Export;
pub const Interface = interface.Interface;

pub inline fn createInstance(descriptor: instance.Instance.Descriptor) ?*instance.Instance {
    return Impl.createInstance(descriptor);
}

pub inline fn getProcAddress(_device: *device.Device, proc_name: [*:0]const u8) ?Proc {
    return Impl.getProcAddress(_device, proc_name);
}

/// Generic function pointer type, used for returning API function pointers. Must be
/// cast to the right `fn (...) callconv(.C) T` type before use.
pub const Proc = *const fn () callconv(.C) void;

pub const ComputePassTimestampWrite = struct {
    query_set: *QuerySet,
    query_index: u32,
    location: ComputePassTimestampLocation,
};

pub const RenderPassDepthStencilAttachment = struct {
    view: *TextureView,
    depth_load_op: LoadOp = .undefined,
    depth_store_op: StoreOp = .undefined,
    depth_clear_value: f32 = 0,
    depth_read_only: bool = false,
    stencil_load_op: LoadOp = .undefined,
    stencil_store_op: StoreOp = .undefined,
    stencil_clear_value: u32 = 0,
    stencil_read_only: bool = false,
};

pub const RenderPassTimestampWrite = struct {
    query_set: *QuerySet,
    query_index: u32,
    location: RenderPassTimestampLocation,
};

pub const ComputePassDescriptor = struct {
    label: ?[:0]const u8 = null,
    timestamp_writes: []const ComputePassTimestampWrite = &.{},
};

pub const RenderPassDescriptor = struct {
    label: ?[:0]const u8 = null,
    color_attachments: []const RenderPassColorAttachment = &.{},
    depth_stencil_attachment: ?RenderPassDepthStencilAttachment = null,
    occlusion_query_set: ?*QuerySet = null,
    timestamp_writes: []const RenderPassTimestampWrite = &.{},
    max_draw_count: u64 = 50_000_000,
};

pub const AlphaMode = enum {
    premultiplied,
    unpremultiplied,
    opaq,
};

pub const BackendType = enum {
    undefined,
    null,
    webgpu,
    d3d11,
    d3d12,
    metal,
    vulkan,
    opengl,
    opengles,

    pub fn name(t: BackendType) []const u8 {
        return switch (t) {
            .undefined => "Undefined",
            .null => "Null",
            .webgpu => "WebGPU",
            .d3d11 => "D3D11",
            .d3d12 => "D3D12",
            .metal => "Metal",
            .vulkan => "Vulkan",
            .opengl => "OpenGL",
            .opengles => "OpenGLES",
        };
    }
};

pub const BlendFactor = enum {
    zero,
    one,
    src,
    one_minus_src,
    src_alpha,
    one_minus_src_alpha,
    dst,
    one_minus_dst,
    dst_alpha,
    one_minus_dst_alpha,
    src_alpha_saturated,
    constant,
    one_minus_constant,
    src1,
    one_minus_src1,
    src1_alpha,
    one_minus_src1_alpha,
};

pub const BlendOperation = enum {
    add,
    subtract,
    reverse_subtract,
    min,
    max,
};

pub const CompareFunction = enum {
    undefined,
    never,
    less,
    less_equal,
    greater,
    greater_equal,
    equal,
    not_equal,
    always,
};

pub const CompilationInfoRequestStatus = enum {
    success,
    err,
    device_lost,
    unknown,
};

pub const CompilationMessageType = enum {
    err,
    warning,
    info,
};

pub const ComputePassTimestampLocation = enum {
    beginning,
    end,
};

pub const CreatePipelineAsyncStatus = enum {
    success,
    validation_error,
    internal_error,
    device_lost,
    device_destroyed,
    unknown,
};

pub const CullMode = enum {
    none,
    front,
    back,
};

pub const ErrorFilter = enum {
    validation,
    out_of_memory,
    internal,
};

pub const ErrorType = enum {
    no_error,
    validation,
    out_of_memory,
    internal,
    unknown,
    device_lost,
};

pub const FeatureName = enum {
    undefined,
    depth_clip_control,
    depth32_float_stencil8,
    timestamp_query,
    pipeline_statistics_query,
    texture_compression_bc,
    texture_compression_etc2,
    texture_compression_astc,
    indirect_first_instance,
    shader_f16,
    rg11_b10_ufloat_renderable,
    bgra8_unorm_storage,
    float32_filterable,
    chromium_experimental_dp4a,
    timestamp_query_inside_passes,
    implicit_device_synchronization,
    surface_capabilities,
    transient_attachments,
    msaa_render_to_single_sampled,
    dual_source_blending,
    d3d11_multithread_protected,
    anglet_exture_sharing,
    shared_texture_memory_vk_image_descriptor,
    shared_texture_memory_vk_dedicated_allocation_descriptor,
    shared_texture_memory_a_hardware_buffer_descriptor,
    shared_texture_memory_dma_buf_descriptor,
    shared_texture_memory_opaque_fd_descriptor,
    shared_texture_memory_zircon_handle_descriptor,
    shared_texture_memory_dxgi_shared_handle_descriptor,
    shared_texture_memory_d3_d11_texture2_d_descriptor,
    shared_texture_memory_io_surface_descriptor,
    shared_texture_memory_egl_image_descriptor,
    shared_texture_memory_initialized_begin_state,
    shared_texture_memory_initialized_end_state,
    shared_texture_memory_vk_image_layout_begin_state,
    shared_texture_memory_vk_image_layout_end_state,
    shared_fence_vk_semaphore_opaque_fd_descriptor,
    shared_fence_vk_semaphore_opaque_fd_export_info,
    shared_fence_vk_semaphore_sync_fd_descriptor,
    shared_fence_vk_semaphore_sync_fd_export_info,
    shared_fence_vk_semaphore_zircon_handle_descriptor,
    shared_fence_vk_semaphore_zircon_handle_export_info,
    shared_fence_dxgi_shared_handle_descriptor,
    shared_fence_dxgi_shared_handle_export_info,
    shared_fence_mtl_shared_event_descriptor,
    shared_fence_mtl_shared_event_export_info,
};

pub const FilterMode = enum {
    nearest,
    linear,
};

pub const MipmapFilterMode = enum {
    nearest,
    linear,
};

pub const FrontFace = enum {
    ccw,
    cw,
};

pub const IndexFormat = enum {
    undefined,
    uint16,
    uint32,
};

pub const LoadOp = enum {
    undefined,
    clear,
    load,
};

pub const LoggingType = enum {
    verbose,
    info,
    warning,
    err,
};

pub const PipelineStatisticName = enum {
    vertex_shader_invocations,
    clipper_invocations,
    clipper_primitives_out,
    fragment_shader_invocations,
    compute_shader_invocations,
};

pub const PresentMode = enum {
    immediate,
    mailbox,
    fifo,
};

pub const PrimitiveTopology = enum {
    point_list,
    line_list,
    line_strip,
    triangle_list,
    triangle_strip,
};

pub const QueryType = enum {
    occlusion,
    pipeline_statistics,
    timestamp,
};

pub const RenderPassTimestampLocation = enum {
    beginning,
    end,
};

pub const SType = enum {
    invalid,
    surface_descriptor_from_metal_layer,
    surface_descriptor_from_windows_hwnd,
    surface_descriptor_from_xlib_window,
    surface_descriptor_from_canvas_html_selector,
    shader_module_spirv_descriptor,
    shader_module_wgsl_descriptor,
    primitive_depth_clip_control,
    surface_descriptor_from_wayland_surface,
    surface_descriptor_from_android_native_window,
    surface_descriptor_from_windows_core_window,
    external_texture_binding_entry,
    external_texture_binding_layout,
    surface_descriptor_from_windows_swap_chain_panel,
    render_pass_descriptor_max_draw_count,
    request_adapter_options_luid,
    request_adapter_options_get_gl_proc,
    shared_texture_memory_vk_image_descriptor,
    shared_texture_memory_vk_dedicated_allocation_descriptor,
    shared_texture_memory_a_hardware_buffer_descriptor,
    shared_texture_memory_dma_buf_descriptor,
    shared_texture_memory_opaque_fd_descriptor,
    shared_texture_memory_zircon_handle_descriptor,
    shared_texture_memory_dxgi_shared_handle_descriptor,
    shared_texture_memory_d3d11_texture_2d_descriptor,
    shared_texture_memory_io_surface_descriptor,
    shared_texture_memory_egl_image_descriptor,
    shared_texture_memory_initialized_begin_state,
    shared_texture_memory_initialized_end_state,
    shared_texture_memory_vk_image_layout_begin_state,
    shared_texture_memory_vk_image_layout_end_state,
    shared_fence_vk_semaphore_opaque_fd_descriptor,
    shared_fence_vk_semaphore_opaque_fd_export_info,
    shared_fence_vk_semaphore_syncfd_descriptor,
    shared_fence_vk_semaphore_sync_fd_export_info,
    shared_fence_vk_semaphore_zircon_handle_descriptor,
    shared_fence_vk_semaphore_zircon_handle_export_info,
    shared_fence_dxgi_shared_handle_descriptor,
    shared_fence_dxgi_shared_handle_export_info,
    shared_fence_mtl_shared_event_descriptor,
    shared_fence_mtl_shared_event_export_info,
};

pub const StencilOperation = enum {
    keep,
    zero,
    replace,
    invert,
    increment_clamp,
    decrement_clamp,
    increment_wrap,
    decrement_wrap,
};

pub const StorageTextureAccess = enum {
    undefined,
    write_only,
};

pub const StoreOp = enum {
    undefined,
    store,
    discard,
};

pub const VertexFormat = enum {
    undefined,
    uint8x2,
    uint8x4,
    sint8x2,
    sint8x4,
    unorm8x2,
    unorm8x4,
    snorm8x2,
    snorm8x4,
    uint16x2,
    uint16x4,
    sint16x2,
    sint16x4,
    unorm16x2,
    unorm16x4,
    snorm16x2,
    snorm16x4,
    float16x2,
    float16x4,
    float32,
    float32x2,
    float32x3,
    float32x4,
    uint32,
    uint32x2,
    uint32x3,
    uint32x4,
    sint32,
    sint32x2,
    sint32x3,
    sint32x4,
};

pub const VertexStepMode = enum {
    vertex,
    instance,
    vertex_buffer_not_used,
};

pub const ColorWriteMaskFlags = packed struct(u32) {
    red: bool = false,
    green: bool = false,
    blue: bool = false,
    alpha: bool = false,

    _padding: u28 = 0,

    pub const all = ColorWriteMaskFlags{
        .red = true,
        .green = true,
        .blue = true,
        .alpha = true,
    };

    pub fn equal(a: ColorWriteMaskFlags, b: ColorWriteMaskFlags) bool {
        return @as(u4, @truncate(@as(u32, @bitCast(a)))) == @as(u4, @truncate(@as(u32, @bitCast(b))));
    }
};

pub const MapModeFlags = packed struct(u32) {
    read: bool = false,
    write: bool = false,

    _padding: u30 = 0,

    pub const undef = MapModeFlags{};

    pub fn equal(a: MapModeFlags, b: MapModeFlags) bool {
        return @as(u2, @truncate(@as(u32, @bitCast(a)))) == @as(u2, @truncate(@as(u32, @bitCast(b))));
    }
};

pub const ShaderStageFlags = packed struct(u32) {
    vertex: bool = false,
    fragment: bool = false,
    compute: bool = false,

    _padding: u29 = 0,

    pub const none = ShaderStageFlags{};

    pub fn equal(a: ShaderStageFlags, b: ShaderStageFlags) bool {
        return @as(u3, @truncate(@as(u32, @bitCast(a)))) == @as(u3, @truncate(@as(u32, @bitCast(b))));
    }
};

pub const BlendComponent = struct {
    operation: BlendOperation = .add,
    src_factor: BlendFactor = .one,
    dst_factor: BlendFactor = .zero,
};

pub const Color = struct {
    r: f64,
    g: f64,
    b: f64,
    a: f64,
};

pub const Extent2D = struct {
    width: u32,
    height: u32,
};

pub const Extent3D = struct {
    width: u32,
    height: u32 = 1,
    depth_or_array_layers: u32 = 1,
};

pub const Limits = struct {
    max_texture_dimension_1d: u32 = std.math.maxInt(u32),
    max_texture_dimension_2d: u32 = std.math.maxInt(u32),
    max_texture_dimension_3d: u32 = std.math.maxInt(u32),
    max_texture_array_layers: u32 = std.math.maxInt(u32),
    max_bind_groups: u32 = std.math.maxInt(u32),
    max_bind_groups_plus_vertex_buffers: u32 = std.math.maxInt(u32),
    max_bindings_per_bind_group: u32 = std.math.maxInt(u32),
    max_dynamic_uniform_buffers_per_pipeline_layout: u32 = std.math.maxInt(u32),
    max_dynamic_storage_buffers_per_pipeline_layout: u32 = std.math.maxInt(u32),
    max_sampled_textures_per_shader_stage: u32 = std.math.maxInt(u32),
    max_samplers_per_shader_stage: u32 = std.math.maxInt(u32),
    max_storage_buffers_per_shader_stage: u32 = std.math.maxInt(u32),
    max_storage_textures_per_shader_stage: u32 = std.math.maxInt(u32),
    max_uniform_buffers_per_shader_stage: u32 = std.math.maxInt(u32),
    max_uniform_buffer_binding_size: u64 = std.math.maxInt(u64),
    max_storage_buffer_binding_size: u64 = std.math.maxInt(u64),
    min_uniform_buffer_offset_alignment: u32 = std.math.maxInt(u32),
    min_storage_buffer_offset_alignment: u32 = std.math.maxInt(u32),
    max_vertex_buffers: u32 = std.math.maxInt(u32),
    max_buffer_size: u64 = std.math.maxInt(u64),
    max_vertex_attributes: u32 = std.math.maxInt(u32),
    max_vertex_buffer_array_stride: u32 = std.math.maxInt(u32),
    max_inter_stage_shader_components: u32 = std.math.maxInt(u32),
    max_inter_stage_shader_variables: u32 = std.math.maxInt(u32),
    max_color_attachments: u32 = std.math.maxInt(u32),
    max_color_attachment_bytes_per_sample: u32 = std.math.maxInt(u32),
    max_compute_workgroup_storage_size: u32 = std.math.maxInt(u32),
    max_compute_invocations_per_workgroup: u32 = std.math.maxInt(u32),
    max_compute_workgroup_size_x: u32 = std.math.maxInt(u32),
    max_compute_workgroup_size_y: u32 = std.math.maxInt(u32),
    max_compute_workgroup_size_z: u32 = std.math.maxInt(u32),
    max_compute_workgroups_per_dimension: u32 = std.math.maxInt(u32),
};

pub const Origin2D = struct {
    x: u32 = 0,
    y: u32 = 0,
};

pub const Origin3D = struct {
    x: u32 = 0,
    y: u32 = 0,
    z: u32 = 0,
};

pub const CompilationMessage = struct {
    message: ?[]const u8 = null,
    type: CompilationMessageType,
    line_num: u64,
    line_pos: u64,
    offset: u64,
    length: u64,
    utf16_line_pos: u64,
    utf16_offset: u64,
    utf16_length: u64,
};

pub const ConstantEntry = struct {
    key: [:0]const u8,
    value: f64,
};

pub const CopyTextureForBrowserOptions = struct {
    flip_y: bool = false,
    needs_color_space_conversion: bool = false,
    src_alpha_mode: AlphaMode = .unpremultiplied,
    src_transfer_function_parameters: ?*const [7]f32 = null,
    conversion_matrix: ?*const [9]f32 = null,
    dst_transfer_function_parameters: ?*const [7]f32 = null,
    dst_alpha_mode: AlphaMode = .unpremultiplied,
    internal_usage: bool = false,
};

pub const MultisampleState = struct {
    count: u32 = 1,
    mask: u32 = std.math.maxInt(u32),
    alpha_to_coverage_enabled: bool = false,
};

pub const PrimitiveDepthClipControl = struct {
    unclipped_depth: bool = false,
};

pub const PrimitiveState = struct {
    topology: PrimitiveTopology = .triangle_list,
    strip_index_format: IndexFormat = .undefined,
    front_face: FrontFace = .ccw,
    cull_mode: CullMode = .none,
    primitive_depth_clip_control: PrimitiveDepthClipControl = .{},
};

pub const StencilFaceState = struct {
    compare: CompareFunction = .always,
    fail_op: StencilOperation = .keep,
    depth_fail_op: StencilOperation = .keep,
    pass_op: StencilOperation = .keep,
};

pub const StorageTextureBindingLayout = struct {
    access: StorageTextureAccess = .undefined,
    format: Texture.Format = .undefined,
    view_dimension: TextureView.Dimension = .dimension_undefined,
};

pub const VertexAttribute = struct {
    format: VertexFormat,
    offset: u64,
    shader_location: u32,
};

pub const BlendState = struct {
    color: BlendComponent = .{},
    alpha: BlendComponent = .{},
};

pub const CompilationInfo = struct {
    messages: []const CompilationMessage = &.{},
};

pub const DepthStencilState = struct {
    format: Texture.Format,
    depth_write_enabled: bool = false,
    depth_compare: CompareFunction = .always,
    stencil_front: StencilFaceState = .{},
    stencil_back: StencilFaceState = .{},
    stencil_read_mask: u32,
    stencil_write_mask: u32,
    depth_bias: i32 = 0,
    depth_bias_slope_scale: f32 = 0.0,
    depth_bias_clamp: f32 = 0.0,
};

pub const ImageCopyBuffer = struct {
    layout: Texture.DataLayout,
    buffer: *Buffer,
};

pub const ImageCopyExternalTexture = struct {
    external_texture: *ExternalTexture,
    origin: Origin3D,
    natural_size: Extent2D,
};

pub const ImageCopyTexture = struct {
    texture: *Texture,
    mip_level: u32 = 0,
    origin: Origin3D = .{},
    aspect: Texture.Aspect = .all,
};

pub const ProgrammableStageDescriptor = struct {
    module: *ShaderModule,
    entry_point: [:0]const u8,
    constants: []const ConstantEntry = &.{},
};

pub const RenderPassColorAttachment = struct {
    view: ?*TextureView = null,
    resolve_target: ?*TextureView = null,
    load_op: LoadOp,
    store_op: StoreOp,
    clear_value: Color,
};

pub const VertexBufferLayout = struct {
    array_stride: u64,
    step_mode: VertexStepMode = .vertex,
    attributes: []const VertexAttribute = &.{},
};

pub const ColorTargetState = struct {
    format: Texture.Format,
    blend: ?*const BlendState = null,
    write_mask: ColorWriteMaskFlags = ColorWriteMaskFlags.all,
};

pub const VertexState = struct {
    module: *ShaderModule,
    entry_point: [:0]const u8,
    constants: []const ConstantEntry = &.{},
    buffers: []const VertexBufferLayout = &.{},
};

pub const FragmentState = struct {
    module: *ShaderModule,
    entry_point: [:0]const u8,
    constants: []const ConstantEntry = &.{},
    targets: []const ColorTargetState = &.{},
};

test "BackendType name" {
    try testing.expectEqualStrings("Vulkan", BackendType.vulkan.name());
}

test "enum name" {
    try testing.expectEqualStrings("front", @tagName(CullMode.front));
}

pub const CompilationInfoCallback = *const fn (
    userdata: ?*anyopaque,
    status: CompilationInfoRequestStatus,
    compilation_info: *const CompilationInfo,
) void;

pub const ErrorCallback = *const fn (
    userdata: ?*anyopaque,
    typ: ErrorType,
    message: []const u8,
) void;

pub const LoggingCallback = *const fn (
    userdata: ?*anyopaque,
    typ: LoggingType,
    message: []const u8,
) void;

test {
    std.testing.refAllDeclsRecursive(@This());
}
