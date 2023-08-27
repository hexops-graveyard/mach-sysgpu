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
const getTextureFormat = @import("../vulkan.zig").getTextureFormat;
const getSampleCountFlags = @import("../vulkan.zig").getSampleCountFlags;

const RenderPassEncoder = @This();

manager: Manager(RenderPassEncoder) = .{},
device: *Device,
extent: vk.Extent2D,
clear_values: []const vk.ClearValue,

pub fn init(device: *Device, descriptor: *const gpu.RenderPassDescriptor) !RenderPassEncoder {
    const depth_stencil_attachment_count = @intFromBool(descriptor.depth_stencil_attachment != null);
    const attachment_count = descriptor.color_attachment_count + depth_stencil_attachment_count;

    var image_views = try std.ArrayList(vk.ImageView).initCapacity(device.allocator, attachment_count);
    defer image_views.deinit();

    var clear_values = std.ArrayList(vk.ClearValue).init(device.allocator);
    errdefer clear_values.deinit();

    var rp_key = Device.RenderPassKey.init();
    var extent: ?vk.Extent2D = null;

    for (descriptor.color_attachments.?[0..descriptor.color_attachment_count]) |attach| {
        const view: *TextureView = @ptrCast(@alignCast(attach.view.?));
        const resolve_view: ?*TextureView = @ptrCast(@alignCast(attach.resolve_target));
        image_views.appendAssumeCapacity(view.view);

        rp_key.colors.appendAssumeCapacity(.{
            .format = view.format,
            .load_op = attach.load_op,
            .store_op = attach.store_op,
            .resolve_format = if (resolve_view) |rv| rv.format else null,
        });

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
        image_views.appendAssumeCapacity(view.view);

        rp_key.depth_stencil = .{
            .format = view.format,
            .depth_load_op = attach.depth_load_op,
            .depth_store_op = attach.depth_store_op,
            .stencil_load_op = attach.stencil_load_op,
            .stencil_store_op = attach.stencil_store_op,
            .read_only = attach.depth_read_only == .true or attach.stencil_read_only == .true,
        };

        if (attach.stencil_load_op == .clear) {
            try clear_values.append(.{
                .depth_stencil = .{
                    .depth = attach.depth_clear_value,
                    .stencil = attach.stencil_clear_value,
                },
            });
        }
    }

    const render_pass = try device.queryRenderPass(rp_key);

    if (device.framebuffer != .null_handle) {
        device.dispatch.destroyFramebuffer(device.device, device.framebuffer, null);
    }

    device.framebuffer = try device.dispatch.createFramebuffer(
        device.device,
        &.{
            .render_pass = render_pass,
            .attachment_count = @as(u32, @intCast(image_views.items.len)),
            .p_attachments = image_views.items.ptr,
            .width = extent.?.width,
            .height = extent.?.height,
            .layers = 1,
        },
        null,
    );

    return .{
        .device = device,
        .extent = extent.?,
        .clear_values = try clear_values.toOwnedSlice(),
    };
}

pub fn deinit(encoder: *RenderPassEncoder) void {
    encoder.device.allocator.free(encoder.clear_values);
}

pub fn setPipeline(encoder: *RenderPassEncoder, pipeline: *RenderPipeline) !void {
    const rect = vk.Rect2D{
        .offset = .{ .x = 0, .y = 0 },
        .extent = encoder.extent,
    };

    const cmd_buffer = encoder.device.syncs[encoder.device.sync_index].cmd_buffer;
    encoder.device.dispatch.cmdBeginRenderPass(cmd_buffer.buffer, &vk.RenderPassBeginInfo{
        .render_pass = pipeline.render_pass,
        .framebuffer = encoder.device.framebuffer,
        .render_area = rect,
        .clear_value_count = @as(u32, @intCast(encoder.clear_values.len)),
        .p_clear_values = encoder.clear_values.ptr,
    }, .@"inline");
    encoder.device.dispatch.cmdBindPipeline(
        cmd_buffer.buffer,
        .graphics,
        pipeline.pipeline,
    );
    encoder.device.dispatch.cmdSetViewport(
        cmd_buffer.buffer,
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
    encoder.device.dispatch.cmdSetScissor(cmd_buffer.buffer, 0, 1, @as(*const [1]vk.Rect2D, &rect));
}

pub fn draw(encoder: *RenderPassEncoder, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void {
    const cmd_buffer = encoder.device.syncs[encoder.device.sync_index].cmd_buffer;
    encoder.device.dispatch.cmdDraw(cmd_buffer.buffer, vertex_count, instance_count, first_vertex, first_instance);
}

pub fn end(encoder: *RenderPassEncoder) void {
    const cmd_buffer = encoder.device.syncs[encoder.device.sync_index].cmd_buffer;
    encoder.device.dispatch.cmdEndRenderPass(cmd_buffer.buffer);
}
