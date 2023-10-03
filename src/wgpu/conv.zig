const wgpu = @import("webgpu");
const dusk = @import("../main.zig");
const dgpu = dusk.dgpu;

pub fn toWGPUPowerPreference(p: dgpu.Adapter.PowerPreference) wgpu.PowerPreference {
    return switch (p) {
        .undefined => .undefined,
        .low_power => .low_power,
        .high_performance => .high_performance,
    };
}

pub fn toWGPUBackendType(b: dgpu.BackendType) wgpu.BackendType {
    return switch (b) {
        .undefined => .undefined,
        .null => .null,
        .webgpu => .webgpu,
        .d3d11 => .d3d11,
        .d3d12 => .d3d12,
        .metal => .metal,
        .vulkan => .vulkan,
        .opengl => .opengl,
        .opengles => .opengles,
    };
}

pub fn toWGPUFeatureName(f: dgpu.FeatureName) wgpu.FeatureName {
    return switch (f) {
        .undefined => .undefined,
        .depth_clip_control => .depth_clip_control,
        .depth32_float_stencil8 => .depth32_float_stencil8,
        .timestamp_query => .timestamp_query,
        .pipeline_statistics_query => .pipeline_statistics_query,
        .texture_compression_bc => .texture_compression_bc,
        .texture_compression_etc2 => .texture_compression_etc2,
        .texture_compression_astc => .texture_compression_astc,
        .indirect_first_instance => .indirect_first_instance,
        .shader_f16 => .shader_f16,
        .rg11_b10_ufloat_renderable => .rg11_b10_ufloat_renderable,
        .bgra8_unorm_storage => .bgra8_unorm_storage,
        .float32_filterable => .float32_filterable,
        .chromium_experimental_dp4a => .chromium_experimental_dp4a,
        .timestamp_query_inside_passes => .timestamp_query_inside_passes,
        .implicit_device_synchronization => .implicit_device_synchronization,
        .surface_capabilities => .surface_capabilities,
        .transient_attachments => .transient_attachments,
        .msaa_render_to_single_sampled => .msaa_render_to_single_sampled,
        .dual_source_blending => .dual_source_blending,
        .d3d11_multithread_protected => .d3d11_multithread_protected,
        .anglet_exture_sharing => .anglet_exture_sharing,
        .shared_texture_memory_vk_image_descriptor => .shared_texture_memory_vk_image_descriptor,
        .shared_texture_memory_vk_dedicated_allocation_descriptor => .shared_texture_memory_vk_dedicated_allocation_descriptor,
        .shared_texture_memory_a_hardware_buffer_descriptor => .shared_texture_memory_a_hardware_buffer_descriptor,
        .shared_texture_memory_dma_buf_descriptor => .shared_texture_memory_dma_buf_descriptor,
        .shared_texture_memory_opaque_fd_descriptor => .shared_texture_memory_opaque_fd_descriptor,
        .shared_texture_memory_zircon_handle_descriptor => .shared_texture_memory_zircon_handle_descriptor,
        .shared_texture_memory_dxgi_shared_handle_descriptor => .shared_texture_memory_dxgi_shared_handle_descriptor,
        .shared_texture_memory_d3_d11_texture2_d_descriptor => .shared_texture_memory_d3_d11_texture2_d_descriptor,
        .shared_texture_memory_io_surface_descriptor => .shared_texture_memory_io_surface_descriptor,
        .shared_texture_memory_egl_image_descriptor => .shared_texture_memory_egl_image_descriptor,
        .shared_texture_memory_initialized_begin_state => .shared_texture_memory_initialized_begin_state,
        .shared_texture_memory_initialized_end_state => .shared_texture_memory_initialized_end_state,
        .shared_texture_memory_vk_image_layout_begin_state => .shared_texture_memory_vk_image_layout_begin_state,
        .shared_texture_memory_vk_image_layout_end_state => .shared_texture_memory_vk_image_layout_end_state,
        .shared_fence_vk_semaphore_opaque_fd_descriptor => .shared_fence_vk_semaphore_opaque_fd_descriptor,
        .shared_fence_vk_semaphore_opaque_fd_export_info => .shared_fence_vk_semaphore_opaque_fd_export_info,
        .shared_fence_vk_semaphore_sync_fd_descriptor => .shared_fence_vk_semaphore_sync_fd_descriptor,
        .shared_fence_vk_semaphore_sync_fd_export_info => .shared_fence_vk_semaphore_sync_fd_export_info,
        .shared_fence_vk_semaphore_zircon_handle_descriptor => .shared_fence_vk_semaphore_zircon_handle_descriptor,
        .shared_fence_vk_semaphore_zircon_handle_export_info => .shared_fence_vk_semaphore_zircon_handle_export_info,
        .shared_fence_dxgi_shared_handle_descriptor => .shared_fence_dxgi_shared_handle_descriptor,
        .shared_fence_dxgi_shared_handle_export_info => .shared_fence_dxgi_shared_handle_export_info,
        .shared_fence_mtl_shared_event_descriptor => .shared_fence_mtl_shared_event_descriptor,
        .shared_fence_mtl_shared_event_export_info => .shared_fence_mtl_shared_event_export_info,
    };
}

pub fn toWGPULimits(l: dgpu.Limits) wgpu.Limits {
    return .{
        .max_texture_dimension_1d = l.max_texture_dimension_1d,
        .max_texture_dimension_2d = l.max_texture_dimension_2d,
        .max_texture_dimension_3d = l.max_texture_dimension_3d,
        .max_texture_array_layers = l.max_texture_array_layers,
        .max_bind_groups = l.max_bind_groups,
        .max_bind_groups_plus_vertex_buffers = l.max_bind_groups_plus_vertex_buffers,
        .max_bindings_per_bind_group = l.max_bindings_per_bind_group,
        .max_dynamic_uniform_buffers_per_pipeline_layout = l.max_dynamic_uniform_buffers_per_pipeline_layout,
        .max_dynamic_storage_buffers_per_pipeline_layout = l.max_dynamic_storage_buffers_per_pipeline_layout,
        .max_sampled_textures_per_shader_stage = l.max_sampled_textures_per_shader_stage,
        .max_samplers_per_shader_stage = l.max_samplers_per_shader_stage,
        .max_storage_buffers_per_shader_stage = l.max_storage_buffers_per_shader_stage,
        .max_storage_textures_per_shader_stage = l.max_storage_textures_per_shader_stage,
        .max_uniform_buffers_per_shader_stage = l.max_uniform_buffers_per_shader_stage,
        .max_uniform_buffer_binding_size = l.max_uniform_buffer_binding_size,
        .max_storage_buffer_binding_size = l.max_storage_buffer_binding_size,
        .min_uniform_buffer_offset_alignment = l.min_uniform_buffer_offset_alignment,
        .min_storage_buffer_offset_alignment = l.min_storage_buffer_offset_alignment,
        .max_vertex_buffers = l.max_vertex_buffers,
        .max_buffer_size = l.max_buffer_size,
        .max_vertex_attributes = l.max_vertex_attributes,
        .max_vertex_buffer_array_stride = l.max_vertex_buffer_array_stride,
        .max_inter_stage_shader_components = l.max_inter_stage_shader_components,
        .max_inter_stage_shader_variables = l.max_inter_stage_shader_variables,
        .max_color_attachments = l.max_color_attachments,
        .max_color_attachment_bytes_per_sample = l.max_color_attachment_bytes_per_sample,
        .max_compute_workgroup_storage_size = l.max_compute_workgroup_storage_size,
        .max_compute_invocations_per_workgroup = l.max_compute_invocations_per_workgroup,
        .max_compute_workgroup_size_x = l.max_compute_workgroup_size_x,
        .max_compute_workgroup_size_y = l.max_compute_workgroup_size_y,
        .max_compute_workgroup_size_z = l.max_compute_workgroup_size_z,
        .max_compute_workgroups_per_dimension = l.max_compute_workgroups_per_dimension,
    };
}

pub fn toWGPUTextureUsageFlags(u: dgpu.Texture.UsageFlags) wgpu.Texture.UsageFlags {
    return .{
        .copy_src = u.copy_src,
        .copy_dst = u.copy_dst,
        .texture_binding = u.texture_binding,
        .storage_binding = u.storage_binding,
        .render_attachment = u.render_attachment,
        .transient_attachment = u.transient_attachment,
    };
}

pub fn toWGPUTextureFormat(f: dgpu.Texture.Format) wgpu.Texture.Format {
    return switch (f) {
        .undefined => .undefined,
        .r8_unorm => .r8_unorm,
        .r8_snorm => .r8_snorm,
        .r8_uint => .r8_uint,
        .r8_sint => .r8_sint,
        .r16_uint => .r16_uint,
        .r16_sint => .r16_sint,
        .r16_float => .r16_float,
        .rg8_unorm => .rg8_unorm,
        .rg8_snorm => .rg8_snorm,
        .rg8_uint => .rg8_uint,
        .rg8_sint => .rg8_sint,
        .r32_float => .r32_float,
        .r32_uint => .r32_uint,
        .r32_sint => .r32_sint,
        .rg16_uint => .rg16_uint,
        .rg16_sint => .rg16_sint,
        .rg16_float => .rg16_float,
        .rgba8_unorm => .rgba8_unorm,
        .rgba8_unorm_srgb => .rgba8_unorm_srgb,
        .rgba8_snorm => .rgba8_snorm,
        .rgba8_uint => .rgba8_uint,
        .rgba8_sint => .rgba8_sint,
        .bgra8_unorm => .bgra8_unorm,
        .bgra8_unorm_srgb => .bgra8_unorm_srgb,
        .rgb10_a2_unorm => .rgb10_a2_unorm,
        .rg11_b10_ufloat => .rg11_b10_ufloat,
        .rgb9_e5_ufloat => .rgb9_e5_ufloat,
        .rg32_float => .rg32_float,
        .rg32_uint => .rg32_uint,
        .rg32_sint => .rg32_sint,
        .rgba16_uint => .rgba16_uint,
        .rgba16_sint => .rgba16_sint,
        .rgba16_float => .rgba16_float,
        .rgba32_float => .rgba32_float,
        .rgba32_uint => .rgba32_uint,
        .rgba32_sint => .rgba32_sint,
        .stencil8 => .stencil8,
        .depth16_unorm => .depth16_unorm,
        .depth24_plus => .depth24_plus,
        .depth24_plus_stencil8 => .depth24_plus_stencil8,
        .depth32_float => .depth32_float,
        .depth32_float_stencil8 => .depth32_float_stencil8,
        .bc1_rgba_unorm => .bc1_rgba_unorm,
        .bc1_rgba_unorm_srgb => .bc1_rgba_unorm_srgb,
        .bc2_rgba_unorm => .bc2_rgba_unorm,
        .bc2_rgba_unorm_srgb => .bc2_rgba_unorm_srgb,
        .bc3_rgba_unorm => .bc3_rgba_unorm,
        .bc3_rgba_unorm_srgb => .bc3_rgba_unorm_srgb,
        .bc4_runorm => .bc4_runorm,
        .bc4_rsnorm => .bc4_rsnorm,
        .bc5_rg_unorm => .bc5_rg_unorm,
        .bc5_rg_snorm => .bc5_rg_snorm,
        .bc6_hrgb_ufloat => .bc6_hrgb_ufloat,
        .bc6_hrgb_float => .bc6_hrgb_float,
        .bc7_rgba_unorm => .bc7_rgba_unorm,
        .bc7_rgba_unorm_srgb => .bc7_rgba_unorm_srgb,
        .etc2_rgb8_unorm => .etc2_rgb8_unorm,
        .etc2_rgb8_unorm_srgb => .etc2_rgb8_unorm_srgb,
        .etc2_rgb8_a1_unorm => .etc2_rgb8_a1_unorm,
        .etc2_rgb8_a1_unorm_srgb => .etc2_rgb8_a1_unorm_srgb,
        .etc2_rgba8_unorm => .etc2_rgba8_unorm,
        .etc2_rgba8_unorm_srgb => .etc2_rgba8_unorm_srgb,
        .eacr11_unorm => .eacr11_unorm,
        .eacr11_snorm => .eacr11_snorm,
        .eacrg11_unorm => .eacrg11_unorm,
        .eacrg11_snorm => .eacrg11_snorm,
        .astc4x4_unorm => .astc4x4_unorm,
        .astc4x4_unorm_srgb => .astc4x4_unorm_srgb,
        .astc5x4_unorm => .astc5x4_unorm,
        .astc5x4_unorm_srgb => .astc5x4_unorm_srgb,
        .astc5x5_unorm => .astc5x5_unorm,
        .astc5x5_unorm_srgb => .astc5x5_unorm_srgb,
        .astc6x5_unorm => .astc6x5_unorm,
        .astc6x5_unorm_srgb => .astc6x5_unorm_srgb,
        .astc6x6_unorm => .astc6x6_unorm,
        .astc6x6_unorm_srgb => .astc6x6_unorm_srgb,
        .astc8x5_unorm => .astc8x5_unorm,
        .astc8x5_unorm_srgb => .astc8x5_unorm_srgb,
        .astc8x6_unorm => .astc8x6_unorm,
        .astc8x6_unorm_srgb => .astc8x6_unorm_srgb,
        .astc8x8_unorm => .astc8x8_unorm,
        .astc8x8_unorm_srgb => .astc8x8_unorm_srgb,
        .astc10x5_unorm => .astc10x5_unorm,
        .astc10x5_unorm_srgb => .astc10x5_unorm_srgb,
        .astc10x6_unorm => .astc10x6_unorm,
        .astc10x6_unorm_srgb => .astc10x6_unorm_srgb,
        .astc10x8_unorm => .astc10x8_unorm,
        .astc10x8_unorm_srgb => .astc10x8_unorm_srgb,
        .astc10x10_unorm => .astc10x10_unorm,
        .astc10x10_unorm_srgb => .astc10x10_unorm_srgb,
        .astc12x10_unorm => .astc12x10_unorm,
        .astc12x10_unorm_srgb => .astc12x10_unorm_srgb,
        .astc12x12_unorm => .astc12x12_unorm,
        .astc12x12_unorm_srgb => .astc12x12_unorm_srgb,
        .r8_bg8_biplanar420_unorm => .r8_bg8_biplanar420_unorm,
    };
}

pub fn toWGPUPresentMode(m: dgpu.PresentMode) wgpu.PresentMode {
    return switch (m) {
        .immediate => .immediate,
        .mailbox => .mailbox,
        .fifo => .fifo,
    };
}

pub fn toWGPUVertexFormat(f: dgpu.VertexFormat) wgpu.VertexFormat {
    return switch (f) {
        .undefined => .undefined,
        .uint8x2 => .uint8x2,
        .uint8x4 => .uint8x4,
        .sint8x2 => .sint8x2,
        .sint8x4 => .sint8x4,
        .unorm8x2 => .unorm8x2,
        .unorm8x4 => .unorm8x4,
        .snorm8x2 => .snorm8x2,
        .snorm8x4 => .snorm8x4,
        .uint16x2 => .uint16x2,
        .uint16x4 => .uint16x4,
        .sint16x2 => .sint16x2,
        .sint16x4 => .sint16x4,
        .unorm16x2 => .unorm16x2,
        .unorm16x4 => .unorm16x4,
        .snorm16x2 => .snorm16x2,
        .snorm16x4 => .snorm16x4,
        .float16x2 => .float16x2,
        .float16x4 => .float16x4,
        .float32 => .float32,
        .float32x2 => .float32x2,
        .float32x3 => .float32x3,
        .float32x4 => .float32x4,
        .uint32 => .uint32,
        .uint32x2 => .uint32x2,
        .uint32x3 => .uint32x3,
        .uint32x4 => .uint32x4,
        .sint32 => .sint32,
        .sint32x2 => .sint32x2,
        .sint32x3 => .sint32x3,
        .sint32x4 => .sint32x4,
    };
}

pub fn toWGPUVertexStepMode(m: dgpu.VertexStepMode) wgpu.VertexStepMode {
    return switch (m) {
        .vertex => .vertex,
        .instance => .instance,
        .vertex_buffer_not_used => .vertex_buffer_not_used,
    };
}

pub fn toWGPUPrimitiveTopology(t: dgpu.PrimitiveTopology) wgpu.PrimitiveTopology {
    return switch (t) {
        .point_list => .point_list,
        .line_list => .line_list,
        .line_strip => .line_strip,
        .triangle_list => .triangle_list,
        .triangle_strip => .triangle_strip,
    };
}

pub fn toWGPUIndexFormat(f: dgpu.IndexFormat) wgpu.IndexFormat {
    return switch (f) {
        .undefined => .undefined,
        .uint16 => .uint16,
        .uint32 => .uint32,
    };
}

pub fn toWGPUFrontFace(f: dgpu.FrontFace) wgpu.FrontFace {
    return switch (f) {
        .ccw => .ccw,
        .cw => .cw,
    };
}

pub fn toWGPUCullMode(m: dgpu.CullMode) wgpu.CullMode {
    return switch (m) {
        .none => .none,
        .front => .front,
        .back => .back,
    };
}

pub fn toWGPUCompareFunction(f: dgpu.CompareFunction) wgpu.CompareFunction {
    return switch (f) {
        .undefined => .undefined,
        .never => .never,
        .less => .less,
        .less_equal => .less_equal,
        .greater => .greater,
        .greater_equal => .greater_equal,
        .equal => .equal,
        .not_equal => .not_equal,
        .always => .always,
    };
}

pub fn toWGPUStencilOperation(o: dgpu.StencilOperation) wgpu.StencilOperation {
    return switch (o) {
        .keep => .keep,
        .zero => .zero,
        .replace => .replace,
        .invert => .invert,
        .increment_clamp => .increment_clamp,
        .decrement_clamp => .decrement_clamp,
        .increment_wrap => .increment_wrap,
        .decrement_wrap => .decrement_wrap,
    };
}

pub fn toWGPUBlendOperation(o: dgpu.BlendOperation) wgpu.BlendOperation {
    return switch (o) {
        .add => .add,
        .subtract => .subtract,
        .reverse_subtract => .reverse_subtract,
        .min => .min,
        .max => .max,
    };
}

pub fn toWGPUBlendFactor(f: dgpu.BlendFactor) wgpu.BlendFactor {
    return switch (f) {
        .zero => .zero,
        .one => .one,
        .src => .src,
        .one_minus_src => .one_minus_src,
        .src_alpha => .src_alpha,
        .one_minus_src_alpha => .one_minus_src_alpha,
        .dst => .dst,
        .one_minus_dst => .one_minus_dst,
        .dst_alpha => .dst_alpha,
        .one_minus_dst_alpha => .one_minus_dst_alpha,
        .src_alpha_saturated => .src_alpha_saturated,
        .constant => .constant,
        .one_minus_constant => .one_minus_constant,
        .src1 => .src1,
        .one_minus_src1 => .one_minus_src1,
        .src1_alpha => .src1_alpha,
        .one_minus_src1_alpha => .one_minus_src1_alpha,
    };
}

pub fn toWGPUColorWriteMaskFlags(f: dgpu.ColorWriteMaskFlags) wgpu.ColorWriteMaskFlags {
    return .{
        .red = f.red,
        .green = f.green,
        .blue = f.blue,
        .alpha = f.alpha,
    };
}

pub fn toWGPUTextureViewDimension(d: dgpu.TextureView.Dimension) wgpu.TextureView.Dimension {
    return switch (d) {
        .dimension_undefined => .dimension_undefined,
        .dimension_1d => .dimension_1d,
        .dimension_2d => .dimension_2d,
        .dimension_2d_array => .dimension_2d_array,
        .dimension_cube => .dimension_cube,
        .dimension_cube_array => .dimension_cube_array,
        .dimension_3d => .dimension_3d,
    };
}

pub fn toWGPUTextureAspect(a: dgpu.Texture.Aspect) wgpu.Texture.Aspect {
    return switch (a) {
        .all => .all,
        .stencil_only => .stencil_only,
        .depth_only => .depth_only,
        .plane0_only => .plane0_only,
        .plane1_only => .plane1_only,
    };
}

pub fn toWGPULoadOp(o: dgpu.LoadOp) wgpu.LoadOp {
    return switch (o) {
        .undefined => .undefined,
        .clear => .clear,
        .load => .load,
    };
}

pub fn toWGPUStoreOp(o: dgpu.StoreOp) wgpu.StoreOp {
    return switch (o) {
        .undefined => .undefined,
        .store => .store,
        .discard => .discard,
    };
}

pub fn toWGPUColor(c: dgpu.Color) wgpu.Color {
    return .{
        .r = c.r,
        .g = c.g,
        .b = c.b,
        .a = c.a,
    };
}

pub fn toWGPURenderPassTimestampLocation(l: dgpu.RenderPassTimestampLocation) wgpu.RenderPassTimestampLocation {
    return switch (l) {
        .beginning => .beginning,
        .end => .end,
    };
}

pub fn fromWGPUAdapterType(t: wgpu.Adapter.Type) dgpu.Adapter.Type {
    return switch (t) {
        .discrete_gpu => .discrete_gpu,
        .integrated_gpu => .integrated_gpu,
        .cpu => .cpu,
        .unknown => .unknown,
    };
}

pub fn fromWGPUBackendType(b: wgpu.BackendType) dgpu.BackendType {
    return switch (b) {
        .undefined => .undefined,
        .null => .null,
        .webgpu => .webgpu,
        .d3d11 => .d3d11,
        .d3d12 => .d3d12,
        .metal => .metal,
        .vulkan => .vulkan,
        .opengl => .opengl,
        .opengles => .opengles,
    };
}

pub fn fromWGPUBool(b: wgpu.Bool32) bool {
    return if (b == .true) true else false;
}
