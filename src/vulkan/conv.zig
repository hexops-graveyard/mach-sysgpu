const vk = @import("vulkan");
const dgpu = @import("../dgpu/main.zig");
const utils = @import("../utils.zig");

pub fn stencilEnable(stencil: dgpu.StencilFaceState) bool {
    return stencil.compare != .always or stencil.fail_op != .keep or stencil.depth_fail_op != .keep or stencil.pass_op != .keep;
}

pub fn dgpuAdapterType(device_type: vk.PhysicalDeviceType) dgpu.Adapter.Type {
    return switch (device_type) {
        .integrated_gpu => .integrated_gpu,
        .discrete_gpu => .discrete_gpu,
        .cpu => .cpu,
        else => .unknown,
    };
}

pub fn vulkanAccessFlagsForBufferRead(usage: dgpu.Buffer.UsageFlags) vk.AccessFlags {
    return .{
        .indirect_command_read_bit = usage.indirect,
        .index_read_bit = usage.index,
        .vertex_attribute_read_bit = usage.vertex,
        .uniform_read_bit = usage.uniform,
        .shader_read_bit = usage.storage,
        .host_read_bit = usage.map_read,
    };
}

pub fn vulkanAccessFlagsForImageRead(usage: dgpu.Texture.UsageFlags, format: dgpu.Texture.Format) vk.AccessFlags {
    return .{
        .shader_read_bit = usage.texture_binding or usage.storage_binding,
        .color_attachment_read_bit = usage.render_attachment and !utils.hasDepthStencil(format),
        .depth_stencil_attachment_read_bit = usage.render_attachment and utils.hasDepthStencil(format),
    };
}

pub fn vulkanBlendOp(op: dgpu.BlendOperation) vk.BlendOp {
    return switch (op) {
        .add => .add,
        .subtract => .subtract,
        .reverse_subtract => .reverse_subtract,
        .min => .min,
        .max => .max,
    };
}

pub fn vulkanBlendFactor(op: dgpu.BlendFactor) vk.BlendFactor {
    return switch (op) {
        .zero => .zero,
        .one => .one,
        .src => .src_color,
        .one_minus_src => .one_minus_src_color,
        .src_alpha => .src_alpha,
        .one_minus_src_alpha => .one_minus_src_alpha,
        .dst => .dst_color,
        .one_minus_dst => .one_minus_dst_color,
        .dst_alpha => .dst_alpha,
        .one_minus_dst_alpha => .one_minus_dst_alpha,
        .src_alpha_saturated => .src_alpha_saturate,
        .constant => .constant_color,
        .one_minus_constant => .one_minus_constant_color,
        .src1 => .src1_color,
        .one_minus_src1 => .one_minus_src1_color,
        .src1_alpha => .src1_alpha,
        .one_minus_src1_alpha => .one_minus_src1_alpha,
    };
}

pub fn vulkanBufferUsageFlags(flags: dgpu.Buffer.UsageFlags) vk.BufferUsageFlags {
    return .{
        .transfer_src_bit = flags.copy_src,
        .transfer_dst_bit = flags.copy_dst or flags.query_resolve,
        .uniform_buffer_bit = flags.uniform,
        .storage_buffer_bit = flags.storage,
        .index_buffer_bit = flags.index,
        .vertex_buffer_bit = flags.vertex,
        .indirect_buffer_bit = flags.indirect,
    };
}

pub fn vulkanCompareOp(op: dgpu.CompareFunction) vk.CompareOp {
    return switch (op) {
        .never => .never,
        .less => .less,
        .less_equal => .less_or_equal,
        .greater => .greater,
        .greater_equal => .greater_or_equal,
        .equal => .equal,
        .not_equal => .not_equal,
        .always => .always,
        .undefined => unreachable,
    };
}

pub fn vulkanCullMode(cull_mode: dgpu.CullMode) vk.CullModeFlags {
    return .{
        .front_bit = cull_mode == .front,
        .back_bit = cull_mode == .back,
    };
}

pub fn vulkanDepthBias(ds: ?*const dgpu.DepthStencilState) f32 {
    if (ds == null) return 0;
    return @floatFromInt(ds.?.depth_bias);
}

pub fn vulkanDepthBiasClamp(ds: ?*const dgpu.DepthStencilState) f32 {
    if (ds == null) return 0;
    return ds.?.depth_bias_clamp;
}

pub fn vulkanDepthBiasSlopeScale(ds: ?*const dgpu.DepthStencilState) f32 {
    if (ds == null) return 0;
    return ds.?.depth_bias_slope_scale;
}

pub fn vulkanDescriptorType(entry: dgpu.BindGroupLayout.Entry) vk.DescriptorType {
    switch (entry.buffer.type) {
        .undefined => {},

        .uniform => if (entry.buffer.has_dynamic_offset == .true) {
            return .uniform_buffer_dynamic;
        } else {
            return .uniform_buffer;
        },

        .storage,
        .read_only_storage,
        => if (entry.buffer.has_dynamic_offset == .true) {
            return .storage_buffer_dynamic;
        } else {
            return .storage_buffer;
        },
    }

    switch (entry.sampler.type) {
        .undefined => {},
        else => return .sampler,
    }

    switch (entry.texture.sample_type) {
        .undefined => {},
        else => return .sampled_image,
    }

    switch (entry.storage_texture.format) {
        .undefined => {},
        else => return .storage_image,
    }

    unreachable;
}

pub fn vulkanFilter(filter: dgpu.FilterMode) vk.Filter {
    return switch (filter) {
        .nearest => .nearest,
        .linear => .linear,
    };
}

pub fn vulkanFormat(format: dgpu.Texture.Format) vk.Format {
    return switch (format) {
        .r8_unorm => .r8_unorm,
        .r8_snorm => .r8_snorm,
        .r8_uint => .r8_uint,
        .r8_sint => .r8_sint,
        .r16_uint => .r16_uint,
        .r16_sint => .r16_sint,
        .r16_float => .r16_sfloat,
        .rg8_unorm => .r8g8_unorm,
        .rg8_snorm => .r8g8_snorm,
        .rg8_uint => .r8g8_uint,
        .rg8_sint => .r8g8_sint,
        .r32_float => .r32_sfloat,
        .r32_uint => .r32_uint,
        .r32_sint => .r32_sint,
        .rg16_uint => .r16g16_uint,
        .rg16_sint => .r16g16_sint,
        .rg16_float => .r16g16_sfloat,
        .rgba8_unorm => .r8g8b8a8_unorm,
        .rgba8_unorm_srgb => .r8g8b8a8_srgb,
        .rgba8_snorm => .r8g8b8a8_snorm,
        .rgba8_uint => .r8g8b8a8_uint,
        .rgba8_sint => .r8g8b8a8_sint,
        .bgra8_unorm => .b8g8r8a8_unorm,
        .bgra8_unorm_srgb => .b8g8r8a8_srgb,
        .rgb10_a2_unorm => .a2r10g10b10_unorm_pack32,
        .rg11_b10_ufloat => .b10g11r11_ufloat_pack32,
        .rgb9_e5_ufloat => .e5b9g9r9_ufloat_pack32,
        .rg32_float => .r32g32_sfloat,
        .rg32_uint => .r32g32_uint,
        .rg32_sint => .r32g32_sint,
        .rgba16_uint => .r16g16b16a16_uint,
        .rgba16_sint => .r16g16b16a16_sint,
        .rgba16_float => .r16g16b16a16_sfloat,
        .rgba32_float => .r32g32b32a32_sfloat,
        .rgba32_uint => .r32g32b32a32_uint,
        .rgba32_sint => .r32g32b32a32_sint,
        .stencil8 => .s8_uint,
        .depth16_unorm => .d16_unorm,
        .depth24_plus => .x8_d24_unorm_pack32,
        .depth24_plus_stencil8 => .d24_unorm_s8_uint,
        .depth32_float => .d32_sfloat,
        .depth32_float_stencil8 => .d32_sfloat_s8_uint,
        .bc1_rgba_unorm => .bc1_rgba_unorm_block,
        .bc1_rgba_unorm_srgb => .bc1_rgba_srgb_block,
        .bc2_rgba_unorm => .bc2_unorm_block,
        .bc2_rgba_unorm_srgb => .bc2_srgb_block,
        .bc3_rgba_unorm => .bc3_unorm_block,
        .bc3_rgba_unorm_srgb => .bc3_srgb_block,
        .bc4_runorm => .bc4_unorm_block,
        .bc4_rsnorm => .bc4_snorm_block,
        .bc5_rg_unorm => .bc5_unorm_block,
        .bc5_rg_snorm => .bc5_snorm_block,
        .bc6_hrgb_ufloat => .bc6h_ufloat_block,
        .bc6_hrgb_float => .bc6h_sfloat_block,
        .bc7_rgba_unorm => .bc7_unorm_block,
        .bc7_rgba_unorm_srgb => .bc7_srgb_block,
        .etc2_rgb8_unorm => .etc2_r8g8b8_unorm_block,
        .etc2_rgb8_unorm_srgb => .etc2_r8g8b8_srgb_block,
        .etc2_rgb8_a1_unorm => .etc2_r8g8b8a1_unorm_block,
        .etc2_rgb8_a1_unorm_srgb => .etc2_r8g8b8a1_srgb_block,
        .etc2_rgba8_unorm => .etc2_r8g8b8a8_unorm_block,
        .etc2_rgba8_unorm_srgb => .etc2_r8g8b8a8_srgb_block,
        .eacr11_unorm => .eac_r11_unorm_block,
        .eacr11_snorm => .eac_r11_snorm_block,
        .eacrg11_unorm => .eac_r11g11_unorm_block,
        .eacrg11_snorm => .eac_r11g11_snorm_block,
        .astc4x4_unorm => .astc_4x_4_unorm_block,
        .astc4x4_unorm_srgb => .astc_4x_4_srgb_block,
        .astc5x4_unorm => .astc_5x_4_unorm_block,
        .astc5x4_unorm_srgb => .astc_5x_4_srgb_block,
        .astc5x5_unorm => .astc_5x_5_unorm_block,
        .astc5x5_unorm_srgb => .astc_5x_5_srgb_block,
        .astc6x5_unorm => .astc_6x_5_unorm_block,
        .astc6x5_unorm_srgb => .astc_6x_5_srgb_block,
        .astc6x6_unorm => .astc_6x_6_unorm_block,
        .astc6x6_unorm_srgb => .astc_6x_6_srgb_block,
        .astc8x5_unorm => .astc_8x_5_unorm_block,
        .astc8x5_unorm_srgb => .astc_8x_5_srgb_block,
        .astc8x6_unorm => .astc_8x_6_unorm_block,
        .astc8x6_unorm_srgb => .astc_8x_6_srgb_block,
        .astc8x8_unorm => .astc_8x_8_unorm_block,
        .astc8x8_unorm_srgb => .astc_8x_8_srgb_block,
        .astc10x5_unorm => .astc_1_0x_5_unorm_block,
        .astc10x5_unorm_srgb => .astc_1_0x_5_srgb_block,
        .astc10x6_unorm => .astc_1_0x_6_unorm_block,
        .astc10x6_unorm_srgb => .astc_1_0x_6_srgb_block,
        .astc10x8_unorm => .astc_1_0x_8_unorm_block,
        .astc10x8_unorm_srgb => .astc_1_0x_8_srgb_block,
        .astc10x10_unorm => .astc_1_0x_10_unorm_block,
        .astc10x10_unorm_srgb => .astc_1_0x_10_srgb_block,
        .astc12x10_unorm => .astc_1_2x_10_unorm_block,
        .astc12x10_unorm_srgb => .astc_1_2x_10_srgb_block,
        .astc12x12_unorm => .astc_1_2x_12_unorm_block,
        .astc12x12_unorm_srgb => .astc_1_2x_12_srgb_block,
        .r8_bg8_biplanar420_unorm => .g8_b8r8_2plane_420_unorm,
        .undefined => unreachable,
    };
}

pub fn vulkanFrontFace(front_face: dgpu.FrontFace) vk.FrontFace {
    return switch (front_face) {
        .ccw => vk.FrontFace.counter_clockwise,
        .cw => vk.FrontFace.clockwise,
    };
}

pub fn vulkanImageAspectFlags(aspect: dgpu.Texture.Aspect, format: dgpu.Texture.Format) vk.ImageAspectFlags {
    return switch (aspect) {
        .all => vulkanImageAspectFlagsForFormat(format),
        .stencil_only => .{ .stencil_bit = true },
        .depth_only => .{ .depth_bit = true },
        .plane0_only => .{ .plane_0_bit = true },
        .plane1_only => .{ .plane_1_bit = true },
    };
}

pub fn vulkanImageAspectFlagsForFormat(format: dgpu.Texture.Format) vk.ImageAspectFlags {
    return switch (format) {
        .stencil8 => .{ .stencil_bit = true },
        .depth16_unorm, .depth24_plus, .depth32_float => .{ .depth_bit = true },
        .depth24_plus_stencil8, .depth32_float_stencil8 => .{ .depth_bit = true, .stencil_bit = true },
        .r8_bg8_biplanar420_unorm => .{ .plane_0_bit = true, .plane_1_bit = true },
        else => .{ .color_bit = true },
    };
}

pub fn vulkanImageCreateFlags(cube_compatible: bool, view_format_count: usize) vk.ImageCreateFlags {
    return .{
        .mutable_format_bit = view_format_count > 0,
        .cube_compatible_bit = cube_compatible,
    };
}

pub fn vulkanImageLayoutForRead(usage: dgpu.Texture.UsageFlags, format: dgpu.Texture.Format) vk.ImageLayout {
    // In case where we do not read, use an appropriate write state to avoid unnecessary layout changes
    return if (usage.storage_binding)
        .general
    else if (usage.texture_binding and utils.hasDepthStencil(format))
        .depth_stencil_read_only_optimal
    else if (usage.texture_binding)
        .shader_read_only_optimal
    else if (usage.render_attachment and utils.hasDepthStencil(format))
        .depth_stencil_read_only_optimal
    else if (usage.render_attachment)
        .color_attachment_optimal
    else
        .general;
}

pub fn vulkanImageLayoutForTextureBinding(sample_type: dgpu.Texture.SampleType) vk.ImageLayout {
    return switch (sample_type) {
        .undefined => .general,
        .depth => .depth_stencil_read_only_optimal,
        else => .shader_read_only_optimal,
    };
}

pub fn vulkanImageType(dimension: dgpu.Texture.Dimension) vk.ImageType {
    return switch (dimension) {
        .dimension_1d => .@"1d",
        .dimension_2d => .@"2d",
        .dimension_3d => .@"3d",
    };
}

pub fn vulkanImageUsageFlags(usage: dgpu.Texture.UsageFlags, format: dgpu.Texture.Format) vk.ImageUsageFlags {
    return .{
        .transfer_src_bit = usage.copy_src,
        .transfer_dst_bit = usage.copy_dst,
        .sampled_bit = usage.texture_binding,
        .storage_bit = usage.storage_binding,
        .color_attachment_bit = usage.render_attachment and !utils.hasDepthStencil(format),
        .transient_attachment_bit = usage.transient_attachment,
        .depth_stencil_attachment_bit = usage.render_attachment and utils.hasDepthStencil(format),
    };
}

pub fn vulkanImageViewType(dimension: dgpu.TextureView.Dimension) vk.ImageViewType {
    return switch (dimension) {
        .dimension_undefined => unreachable,
        .dimension_1d => .@"1d",
        .dimension_2d => .@"2d",
        .dimension_2d_array => .@"2d_array",
        .dimension_cube => .cube,
        .dimension_cube_array => .cube_array,
        .dimension_3d => .@"3d",
    };
}

pub fn vulkanIndexType(format: dgpu.IndexFormat) vk.IndexType {
    return switch (format) {
        .undefined => unreachable,
        .uint16 => .uint16,
        .uint32 => .uint32,
    };
}

pub fn vulkanLoadOp(op: dgpu.LoadOp) vk.AttachmentLoadOp {
    return switch (op) {
        .load => .load,
        .clear => .clear,
        .undefined => .dont_care,
    };
}

pub fn vulkanPipelineStageFlagsForBufferRead(usage: dgpu.Buffer.UsageFlags) vk.PipelineStageFlags {
    return .{
        .draw_indirect_bit = usage.indirect,
        .vertex_input_bit = usage.index or usage.vertex,
        .vertex_shader_bit = usage.uniform or usage.storage,
        .fragment_shader_bit = usage.uniform or usage.storage,
        .compute_shader_bit = usage.uniform or usage.storage,
        .host_bit = usage.map_read,
    };
}

pub fn vulkanPipelineStageFlagsForImageRead(usage: dgpu.Texture.UsageFlags, format: dgpu.Texture.Format) vk.PipelineStageFlags {
    return .{
        .vertex_shader_bit = usage.texture_binding or usage.storage_binding,
        .fragment_shader_bit = usage.texture_binding or usage.storage_binding,
        .early_fragment_tests_bit = usage.render_attachment and utils.hasDepthStencil(format),
        .late_fragment_tests_bit = usage.render_attachment and utils.hasDepthStencil(format),
        .color_attachment_output_bit = usage.render_attachment and !utils.hasDepthStencil(format),
        .compute_shader_bit = usage.texture_binding or usage.storage_binding,
    };
}

pub fn vulkanPrimitiveTopology(topology: dgpu.PrimitiveTopology) vk.PrimitiveTopology {
    return switch (topology) {
        .point_list => .point_list,
        .line_list => .line_list,
        .line_strip => .line_strip,
        .triangle_list => .triangle_list,
        .triangle_strip => .triangle_strip,
    };
}

pub fn vulkanPresentMode(present_mode: dgpu.PresentMode) vk.PresentModeKHR {
    return switch (present_mode) {
        .immediate => .immediate_khr,
        .fifo => .fifo_khr,
        .mailbox => .mailbox_khr,
    };
}

pub fn vulkanSampleCount(samples: u32) vk.SampleCountFlags {
    // TODO: https://github.com/Snektron/vulkan-zig/issues/27
    return switch (samples) {
        1 => .{ .@"1_bit" = true },
        2 => .{ .@"2_bit" = true },
        4 => .{ .@"4_bit" = true },
        8 => .{ .@"8_bit" = true },
        16 => .{ .@"16_bit" = true },
        32 => .{ .@"32_bit" = true },
        else => unreachable,
    };
}

pub fn vulkanSamplerAddressMode(address_mode: dgpu.Sampler.AddressMode) vk.SamplerAddressMode {
    return switch (address_mode) {
        .repeat => .repeat,
        .mirror_repeat => .mirrored_repeat,
        .clamp_to_edge => .clamp_to_edge,
    };
}

pub fn vulkanSamplerMipmapMode(filter: dgpu.MipmapFilterMode) vk.SamplerMipmapMode {
    return switch (filter) {
        .nearest => .nearest,
        .linear => .linear,
    };
}

pub fn vulkanShaderStageFlags(flags: dgpu.ShaderStageFlags) vk.ShaderStageFlags {
    return .{
        .vertex_bit = flags.vertex,
        .fragment_bit = flags.fragment,
        .compute_bit = flags.compute,
    };
}

pub fn vulkanStencilOp(op: dgpu.StencilOperation) vk.StencilOp {
    return switch (op) {
        .keep => .keep,
        .zero => .zero,
        .replace => .replace,
        .invert => .invert,
        .increment_clamp => .increment_and_clamp,
        .decrement_clamp => .decrement_and_clamp,
        .increment_wrap => .increment_and_wrap,
        .decrement_wrap => .decrement_and_wrap,
    };
}

pub fn vulkanStoreOp(op: dgpu.StoreOp) vk.AttachmentStoreOp {
    return switch (op) {
        .store => .store,
        .discard => .dont_care,
        .undefined => .dont_care,
    };
}

pub fn vulkanVertexFormat(format: dgpu.VertexFormat) vk.Format {
    return switch (format) {
        .uint8x2 => .r8g8_uint,
        .uint8x4 => .r8g8b8a8_uint,
        .sint8x2 => .r8g8_sint,
        .sint8x4 => .r8g8b8a8_sint,
        .unorm8x2 => .r8g8_unorm,
        .unorm8x4 => .r8g8b8a8_unorm,
        .snorm8x2 => .r8g8_snorm,
        .snorm8x4 => .r8g8b8a8_snorm,
        .uint16x2 => .r16g16_uint,
        .uint16x4 => .r16g16b16a16_uint,
        .sint16x2 => .r16g16_sint,
        .sint16x4 => .r16g16b16a16_sint,
        .unorm16x2 => .r16g16_unorm,
        .unorm16x4 => .r16g16b16a16_unorm,
        .snorm16x2 => .r16g16_snorm,
        .snorm16x4 => .r16g16b16a16_snorm,
        .float16x2 => .r16g16_sfloat,
        .float16x4 => .r16g16b16a16_sfloat,
        .float32 => .r32_sfloat,
        .float32x2 => .r32g32_sfloat,
        .float32x3 => .r32g32b32_sfloat,
        .float32x4 => .r32g32b32a32_sfloat,
        .uint32 => .r32_uint,
        .uint32x2 => .r32g32_uint,
        .uint32x3 => .r32g32b32_uint,
        .uint32x4 => .r32g32b32a32_uint,
        .sint32 => .r32_sint,
        .sint32x2 => .r32g32_sint,
        .sint32x3 => .r32g32b32_sint,
        .sint32x4 => .r32g32b32a32_sint,
        .undefined => unreachable,
    };
}

pub fn vulkanVertexInputRate(step_mode: dgpu.VertexStepMode) vk.VertexInputRate {
    return switch (step_mode) {
        .vertex => .vertex,
        .instance => .instance,
        .vertex_buffer_not_used => unreachable,
    };
}
