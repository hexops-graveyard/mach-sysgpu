const std = @import("std");
const builtin = @import("builtin");
const vk = @import("vulkan");
const gpu = @import("gpu");
const Device = @import("Device.zig");
const CommandEncoder = @import("CommandEncoder.zig");
const CommandBuffer = @import("CommandBuffer.zig");
const RenderPipeline = @import("RenderPipeline.zig");
const TextureView = @import("TextureView.zig");
const Manager = @import("../helper.zig").Manager;

const RenderPassEncoder = @This();

manager: Manager(RenderPassEncoder) = .{},
device: *Device,
cmd_encoder: *CommandEncoder,
framebuffer: vk.Framebuffer = .null_handle,
extent: vk.Extent2D,
attachments: []const vk.ImageView,
clear_values: []const vk.ClearValue,

pub fn init(cmd_encoder: *CommandEncoder, descriptor: *const gpu.RenderPassDescriptor) !RenderPassEncoder {
    const depth_stencil_attachment_count = @intFromBool(descriptor.depth_stencil_attachment != null);
    const attachment_count = descriptor.color_attachment_count + depth_stencil_attachment_count;

    var attachments = try std.ArrayList(vk.ImageView).initCapacity(cmd_encoder.device.allocator, attachment_count);
    errdefer attachments.deinit();

    var clear_values = std.ArrayList(vk.ClearValue).init(cmd_encoder.device.allocator);
    errdefer clear_values.deinit();

    var extent: ?vk.Extent2D = null;

    for (0..attachment_count - depth_stencil_attachment_count) |i| {
        const attach = descriptor.color_attachments.?[i];
        const view: *TextureView = @ptrCast(@alignCast(attach.view));
        attachments.appendAssumeCapacity(view.view);

        if (attach.load_op == .clear) {
            try clear_values.append(.{
                .color = .{
                    .float_32 = [4]f32{
                        @floatCast(attach.clear_value.r),
                        @floatCast(attach.clear_value.g),
                        @floatCast(attach.clear_value.b),
                        @floatCast(attach.clear_value.a),
                    },
                },
            });
        }

        if (extent == null) {
            extent = view.texture.extent;
        }
    }

    if (descriptor.depth_stencil_attachment) |attach| {
        const view: *TextureView = @ptrCast(@alignCast(attach.view));
        attachments.appendAssumeCapacity(view.view);

        if (attach.stencil_load_op == .clear) {
            try clear_values.append(.{
                .depth_stencil = .{
                    .depth = attach.depth_clear_value,
                    .stencil = attach.stencil_clear_value,
                },
            });
        }
    }

    return .{
        .device = cmd_encoder.device,
        .cmd_encoder = cmd_encoder,
        .extent = extent.?,
        .attachments = try attachments.toOwnedSlice(),
        .clear_values = try clear_values.toOwnedSlice(),
    };
}

pub fn deinit(encoder: *RenderPassEncoder) void {
    encoder.cmd_encoder.device.allocator.free(encoder.attachments);
    encoder.cmd_encoder.device.allocator.free(encoder.clear_values);
}

pub fn setPipeline(encoder: *RenderPassEncoder, pipeline: *RenderPipeline) !void {
    if (encoder.framebuffer != .null_handle) {
        encoder.device.dispatch.destroyFramebuffer(
            encoder.device.device,
            encoder.framebuffer,
            null,
        );
    }

    encoder.framebuffer = try encoder.device.dispatch.createFramebuffer(
        encoder.device.device,
        &.{
            .render_pass = pipeline.render_pass_raw,
            .attachment_count = @as(u32, @intCast(encoder.attachments.len)),
            .p_attachments = encoder.attachments.ptr,
            .width = encoder.extent.width,
            .height = encoder.extent.height,
            .layers = 1,
        },
        null,
    );
    errdefer encoder.device.dispatch.destroyFramebuffer(
        encoder.device.device,
        encoder.framebuffer,
        null,
    );

    const rect = vk.Rect2D{
        .offset = .{ .x = 0, .y = 0 },
        .extent = encoder.extent,
    };

    encoder.device.dispatch.cmdBeginRenderPass(encoder.cmd_encoder.cmd_buffer.buffer, &vk.RenderPassBeginInfo{
        .render_pass = pipeline.render_pass_raw,
        .framebuffer = encoder.framebuffer,
        .render_area = rect,
        .clear_value_count = @as(u32, @intCast(encoder.clear_values.len)),
        .p_clear_values = encoder.clear_values.ptr,
    }, .@"inline");
    encoder.device.dispatch.cmdBindPipeline(
        encoder.cmd_encoder.cmd_buffer.buffer,
        .graphics,
        pipeline.pipeline,
    );
    encoder.device.dispatch.cmdSetViewport(
        encoder.cmd_encoder.cmd_buffer.buffer,
        0,
        1,
        @as(*const [1]vk.Viewport, &vk.Viewport{
            .x = 0,
            .y = @as(f32, @floatFromInt(encoder.extent.height)),
            .width = @as(f32, @floatFromInt(encoder.extent.width)),
            .height = -@as(f32, @floatFromInt(encoder.extent.height)),
            .min_depth = 0,
            .max_depth = 1,
        }),
    );
    encoder.device.dispatch.cmdSetScissor(encoder.cmd_encoder.cmd_buffer.buffer, 0, 1, @as(*const [1]vk.Rect2D, &rect));
}

pub fn draw(encoder: *RenderPassEncoder, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void {
    encoder.device.dispatch.cmdDraw(encoder.cmd_encoder.cmd_buffer.buffer, vertex_count, instance_count, first_vertex, first_instance);
}

pub fn end(encoder: *RenderPassEncoder) void {
    encoder.device.dispatch.cmdEndRenderPass(encoder.cmd_encoder.cmd_buffer.buffer);
}
