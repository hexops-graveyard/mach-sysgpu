const std = @import("std");
const vk = @import("vulkan");
const gpu = @import("gpu");
const Device = @import("Device.zig");
const ShaderModule = @import("ShaderModule.zig");
const PipelineLayout = @import("PipelineLayout.zig");
const Manager = @import("../helper.zig").Manager;
const getTextureFormat = @import("../vulkan.zig").getTextureFormat;
const getSampleCountFlags = @import("../vulkan.zig").getSampleCountFlags;

const RenderPipeline = @This();

manager: Manager(RenderPipeline) = .{},
device: *Device,
pipeline: vk.Pipeline,
render_pass: vk.RenderPass,

pub fn init(device: *Device, desc: *const gpu.RenderPipeline.Descriptor) !RenderPipeline {
    var stages = std.BoundedArray(vk.PipelineShaderStageCreateInfo, 2){};

    const vertex_shader: *ShaderModule = @ptrCast(@alignCast(desc.vertex.module));
    stages.appendAssumeCapacity(.{
        .stage = .{ .vertex_bit = true },
        .module = vertex_shader.shader_module,
        .p_name = desc.vertex.entry_point,
        .p_specialization_info = null,
    });

    if (desc.fragment) |frag| {
        const frag_shader: *ShaderModule = @ptrCast(@alignCast(frag.module));
        stages.appendAssumeCapacity(.{
            .stage = .{ .fragment_bit = true },
            .module = frag_shader.shader_module,
            .p_name = frag.entry_point,
            .p_specialization_info = null,
        });
    }

    var vertex_bindings = try std.ArrayList(vk.VertexInputBindingDescription).initCapacity(device.allocator, desc.vertex.buffer_count);
    var vertex_attrs = try std.ArrayList(vk.VertexInputAttributeDescription).initCapacity(device.allocator, desc.vertex.buffer_count);
    defer {
        vertex_bindings.deinit();
        vertex_attrs.deinit();
    }

    for (0..desc.vertex.buffer_count) |i| {
        const buf = desc.vertex.buffers.?[i];
        const input_rate: vk.VertexInputRate = switch (buf.step_mode) {
            .vertex => .vertex,
            .instance => .instance,
            .vertex_buffer_not_used => unreachable,
        };

        vertex_bindings.appendAssumeCapacity(.{
            .binding = @intCast(i),
            .stride = @intCast(buf.array_stride),
            .input_rate = input_rate,
        });

        for (buf.attributes.?[0..buf.attribute_count]) |attr| {
            try vertex_attrs.append(.{
                .location = attr.shader_location,
                .binding = @intCast(i),
                .format = getVertexFormat(attr.format),
                .offset = @intCast(attr.offset),
            });
        }
    }

    const vertex_input = vk.PipelineVertexInputStateCreateInfo{
        .vertex_binding_description_count = @intCast(vertex_bindings.items.len),
        .p_vertex_binding_descriptions = vertex_bindings.items.ptr,
        .vertex_attribute_description_count = @intCast(vertex_attrs.items.len),
        .p_vertex_attribute_descriptions = vertex_attrs.items.ptr,
    };

    const input_assembly = vk.PipelineInputAssemblyStateCreateInfo{
        .topology = switch (desc.primitive.topology) {
            .point_list => .point_list,
            .line_list => .line_list,
            .line_strip => .line_strip,
            .triangle_list => .triangle_list,
            .triangle_strip => .triangle_strip,
        },
        .primitive_restart_enable = @intFromBool(desc.primitive.strip_index_format != .undefined),
    };

    const viewport = vk.PipelineViewportStateCreateInfo{
        .viewport_count = 1,
        .scissor_count = 1,
    };

    const rasterization = vk.PipelineRasterizationStateCreateInfo{
        .depth_clamp_enable = vk.FALSE,
        .rasterizer_discard_enable = vk.FALSE,
        .polygon_mode = .fill,
        .cull_mode = .{
            .front_bit = desc.primitive.cull_mode == .front,
            .back_bit = desc.primitive.cull_mode == .back,
        },
        .front_face = switch (desc.primitive.front_face) {
            .ccw => vk.FrontFace.counter_clockwise,
            .cw => vk.FrontFace.clockwise,
        },
        .depth_bias_enable = isDepthBiasEnabled(desc.depth_stencil),
        .depth_bias_constant_factor = getDepthBias(desc.depth_stencil),
        .depth_bias_clamp = getDepthBiasClamp(desc.depth_stencil),
        .depth_bias_slope_factor = getDepthBiasSlopeScale(desc.depth_stencil),
        .line_width = 1,
    };

    const sample_count = getSampleCountFlags(desc.multisample.count);
    const multisample = vk.PipelineMultisampleStateCreateInfo{
        .rasterization_samples = sample_count,
        .sample_shading_enable = vk.FALSE,
        .min_sample_shading = 0,
        .p_sample_mask = &[_]u32{desc.multisample.mask},
        .alpha_to_coverage_enable = @intFromEnum(desc.multisample.alpha_to_coverage_enabled),
        .alpha_to_one_enable = vk.FALSE,
    };

    var pipeline_layout = if (desc.layout) |layout|
        @as(*PipelineLayout, @ptrCast(@alignCast(layout))).*
    else
        try PipelineLayout.init(device, &.{});
    defer pipeline_layout.deinit();

    var blend_attachments: []vk.PipelineColorBlendAttachmentState = &.{};
    defer if (desc.fragment != null) device.allocator.free(blend_attachments);

    var rp_key = Device.RenderPassKey.init();
    rp_key.samples = sample_count;

    if (desc.fragment) |frag| {
        blend_attachments = try device.allocator.alloc(vk.PipelineColorBlendAttachmentState, frag.target_count);

        for (frag.targets.?[0..frag.target_count], 0..) |target, i| {
            const blend = target.blend orelse &gpu.BlendState{};
            blend_attachments[i] = .{
                .blend_enable = vk.FALSE,
                .src_color_blend_factor = getBlendFactor(blend.color.src_factor),
                .dst_color_blend_factor = getBlendFactor(blend.color.dst_factor),
                .color_blend_op = getBlendOp(blend.color.operation),
                .src_alpha_blend_factor = getBlendFactor(blend.alpha.src_factor),
                .dst_alpha_blend_factor = getBlendFactor(blend.alpha.dst_factor),
                .alpha_blend_op = getBlendOp(blend.alpha.operation),
                .color_write_mask = .{
                    .r_bit = target.write_mask.red,
                    .g_bit = target.write_mask.green,
                    .b_bit = target.write_mask.blue,
                    .a_bit = target.write_mask.alpha,
                },
            };
            rp_key.colors.appendAssumeCapacity(.{
                .format = getTextureFormat(target.format),
                .load_op = .clear,
                .store_op = .store,
                .resolve_format = null,
            });
        }
    }

    var depth_stencil_state = vk.PipelineDepthStencilStateCreateInfo{
        .depth_test_enable = vk.FALSE,
        .depth_write_enable = vk.FALSE,
        .depth_compare_op = .never,
        .depth_bounds_test_enable = vk.FALSE,
        .stencil_test_enable = vk.FALSE,
        .front = .{
            .fail_op = .keep,
            .depth_fail_op = .keep,
            .pass_op = .keep,
            .compare_op = .never,
            .compare_mask = 0,
            .write_mask = 0,
            .reference = 0,
        },
        .back = .{
            .fail_op = .keep,
            .depth_fail_op = .keep,
            .pass_op = .keep,
            .compare_op = .never,
            .compare_mask = 0,
            .write_mask = 0,
            .reference = 0,
        },
        .min_depth_bounds = 0,
        .max_depth_bounds = 1,
    };

    if (desc.depth_stencil) |ds| {
        depth_stencil_state.depth_test_enable = @intFromBool(ds.depth_compare == .always and ds.depth_write_enabled == .true);
        depth_stencil_state.depth_write_enable = @intFromBool(ds.depth_write_enabled == .true);
        depth_stencil_state.depth_compare_op = getCompareOp(ds.depth_compare);
        depth_stencil_state.stencil_test_enable = @intFromBool(ds.stencil_read_mask != 0 or ds.stencil_write_mask != 0);
        depth_stencil_state.front = .{
            .fail_op = getStencilOp(ds.stencil_front.fail_op),
            .depth_fail_op = getStencilOp(ds.stencil_front.depth_fail_op),
            .pass_op = getStencilOp(ds.stencil_front.pass_op),
            .compare_op = getCompareOp(ds.stencil_front.compare),
            .compare_mask = ds.stencil_read_mask,
            .write_mask = ds.stencil_write_mask,
            .reference = 0,
        };
        depth_stencil_state.back = .{
            .fail_op = getStencilOp(ds.stencil_back.fail_op),
            .depth_fail_op = getStencilOp(ds.stencil_back.depth_fail_op),
            .pass_op = getStencilOp(ds.stencil_back.pass_op),
            .compare_op = getCompareOp(ds.stencil_back.compare),
            .compare_mask = ds.stencil_read_mask,
            .write_mask = ds.stencil_write_mask,
            .reference = 0,
        };

        rp_key.depth_stencil = .{
            .format = getTextureFormat(ds.format),
            .depth_load_op = .load,
            .depth_store_op = .store,
            .stencil_load_op = .load,
            .stencil_store_op = .store,
            .read_only = ds.depth_write_enabled == .false and ds.stencil_write_mask == 0,
        };
    }

    const color_blend = vk.PipelineColorBlendStateCreateInfo{
        .logic_op_enable = vk.FALSE,
        .logic_op = .clear,
        .attachment_count = @intCast(blend_attachments.len),
        .p_attachments = blend_attachments.ptr,
        .blend_constants = .{ 0, 0, 0, 0 },
    };

    const dynamic_states = [_]vk.DynamicState{
        .viewport,        .scissor,      .line_width,
        .blend_constants, .depth_bounds, .stencil_reference,
    };
    const dynamic = vk.PipelineDynamicStateCreateInfo{
        .dynamic_state_count = dynamic_states.len,
        .p_dynamic_states = &dynamic_states,
    };

    const render_pass = try device.queryRenderPass(rp_key);

    var pipeline: vk.Pipeline = undefined;
    _ = try device.dispatch.createGraphicsPipelines(device.device, .null_handle, 1, &[_]vk.GraphicsPipelineCreateInfo{.{
        .stage_count = stages.len,
        .p_stages = stages.slice().ptr,
        .p_vertex_input_state = &vertex_input,
        .p_input_assembly_state = &input_assembly,
        .p_viewport_state = &viewport,
        .p_rasterization_state = &rasterization,
        .p_multisample_state = &multisample,
        .p_depth_stencil_state = &depth_stencil_state,
        .p_color_blend_state = &color_blend,
        .p_dynamic_state = &dynamic,
        .layout = pipeline_layout.layout,
        .render_pass = render_pass,
        .subpass = 0,
        .base_pipeline_index = -1,
    }}, null, @ptrCast(&pipeline));

    return .{
        .device = device,
        .pipeline = pipeline,
        .render_pass = render_pass,
    };
}

pub fn deinit(render_pipeline: *RenderPipeline) void {
    render_pipeline.device.dispatch.destroyPipeline(render_pipeline.device.device, render_pipeline.pipeline, null);
}

fn isDepthBiasEnabled(ds: ?*const gpu.DepthStencilState) vk.Bool32 {
    if (ds == null) return vk.FALSE;
    return @intFromBool(ds.?.depth_bias != 0 or ds.?.depth_bias_slope_scale != 0);
}

fn getDepthBias(ds: ?*const gpu.DepthStencilState) f32 {
    if (ds == null) return 0;
    return @floatFromInt(ds.?.depth_bias);
}

fn getDepthBiasClamp(ds: ?*const gpu.DepthStencilState) f32 {
    if (ds == null) return 0;
    return ds.?.depth_bias_clamp;
}

fn getDepthBiasSlopeScale(ds: ?*const gpu.DepthStencilState) f32 {
    if (ds == null) return 0;
    return ds.?.depth_bias_slope_scale;
}

fn getCompareOp(op: gpu.CompareFunction) vk.CompareOp {
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

fn getStencilOp(op: gpu.StencilOperation) vk.StencilOp {
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

fn getBlendOp(op: gpu.BlendOperation) vk.BlendOp {
    return switch (op) {
        .add => .add,
        .subtract => .subtract,
        .reverse_subtract => .reverse_subtract,
        .min => .min,
        .max => .max,
    };
}

fn getBlendFactor(op: gpu.BlendFactor) vk.BlendFactor {
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

fn getVertexFormat(format: gpu.VertexFormat) vk.Format {
    return switch (format) {
        .undefined => .undefined,
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
        .float32 => .r16_sfloat,
        .float32x2 => .r16g16_sfloat,
        .float32x3 => .r16g16b16_sfloat,
        .float32x4 => .r16g16b16a16_sfloat,
        .uint32 => .r32_uint,
        .uint32x2 => .r32g32_uint,
        .uint32x3 => .r32g32b32_uint,
        .uint32x4 => .r32g32b32a32_uint,
        .sint32 => .r32_sint,
        .sint32x2 => .r32g32_sint,
        .sint32x3 => .r32g32b32_sint,
        .sint32x4 => .r32g32b32a32_sint,
    };
}
