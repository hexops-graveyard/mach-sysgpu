const vk = @import("vulkan");
const dgpu = @import("../dgpu/main.zig");

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

pub fn vulkanDepthBias(ds: ?dgpu.DepthStencilState) f32 {
    if (ds == null) return 0;
    return @floatFromInt(ds.?.depth_bias);
}

pub fn vulkanDepthBiasClamp(ds: ?dgpu.DepthStencilState) f32 {
    if (ds == null) return 0;
    return ds.?.depth_bias_clamp;
}

pub fn vulkanDepthBiasSlopeScale(ds: ?dgpu.DepthStencilState) f32 {
    if (ds == null) return 0;
    return ds.?.depth_bias_slope_scale;
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

pub fn vulkanLoadOp(op: dgpu.LoadOp) vk.AttachmentLoadOp {
    return switch (op) {
        .load => .load,
        .clear => .clear,
        .undefined => unreachable,
    };
}

pub fn vulkanStoreOp(op: dgpu.StoreOp) vk.AttachmentStoreOp {
    return switch (op) {
        .store => .store,
        .discard => .dont_care,
        .undefined => unreachable,
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

pub fn vulkanDescriptorType(entry: dgpu.BindGroupLayout.Entry) vk.DescriptorType {
    return switch (entry.resource_layout) {
        .buffer => |buf| if (buf.has_dynamic_offset) .uniform_buffer_dynamic else .uniform_buffer,
        .sampler => .sampler,
        .texture => .sampled_image,
        .storage_texture => .storage_image,
        .external_texture => unreachable, // TODO
    };
}

pub fn vulkanShaderStageFlags(flags: dgpu.ShaderStageFlags) vk.ShaderStageFlags {
    return .{
        .vertex_bit = flags.vertex,
        .fragment_bit = flags.fragment,
        .compute_bit = flags.compute,
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
