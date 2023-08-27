const std = @import("std");
const gpu = @import("gpu");
const vk = @import("vulkan");
const Device = @import("Device.zig");
const Surface = @import("Surface.zig");
const Texture = @import("Texture.zig");
const TextureView = @import("TextureView.zig");
const Manager = @import("../helper.zig").Manager;
const getTextureFormat = @import("../vulkan.zig").getTextureFormat;

const SwapChain = @This();

manager: Manager(SwapChain) = .{},
device: *Device,
swapchain: vk.SwapchainKHR,
textures: []Texture,
texture_index: u32 = 0,
format: gpu.Texture.Format,

pub fn init(device: *Device, surface: *Surface, desc: *const gpu.SwapChain.Descriptor) !SwapChain {
    const capabilities = try device.adapter.instance.dispatch.getPhysicalDeviceSurfaceCapabilitiesKHR(
        device.adapter.physical_device,
        surface.surface,
    );

    // TODO: query surface formats
    // TODO: query surface present modes

    const composite_alpha = blk: {
        const composite_alpha_flags = [_]vk.CompositeAlphaFlagsKHR{
            .{ .opaque_bit_khr = true },
            .{ .pre_multiplied_bit_khr = true },
            .{ .post_multiplied_bit_khr = true },
            .{ .inherit_bit_khr = true },
        };
        for (composite_alpha_flags) |flag| {
            if (@as(vk.Flags, @bitCast(flag)) & @as(vk.Flags, @bitCast(capabilities.supported_composite_alpha)) != 0) {
                break :blk flag;
            }
        }
        break :blk vk.CompositeAlphaFlagsKHR{};
    };
    const image_count = @max(capabilities.min_image_count + 1, capabilities.max_image_count);
    const format = getTextureFormat(desc.format);
    const extent = vk.Extent2D{ .width = desc.width, .height = desc.height };
    const image_usage = vk.ImageUsageFlags{
        .transfer_src_bit = desc.usage.copy_src,
        .transfer_dst_bit = desc.usage.copy_dst,
        .sampled_bit = desc.usage.texture_binding,
        .storage_bit = desc.usage.storage_binding,
        .color_attachment_bit = desc.usage.render_attachment,
        .transient_attachment_bit = desc.usage.transient_attachment,
        .depth_stencil_attachment_bit = switch (desc.format) {
            .stencil8,
            .depth16_unorm,
            .depth24_plus,
            .depth24_plus_stencil8,
            .depth32_float,
            .depth32_float_stencil8,
            => true,
            else => false,
        },
    };
    const present_mode = switch (desc.present_mode) {
        .immediate => vk.PresentModeKHR.immediate_khr,
        .fifo => vk.PresentModeKHR.fifo_khr,
        .mailbox => vk.PresentModeKHR.mailbox_khr,
    };

    const swapchain = try device.dispatch.createSwapchainKHR(device.device, &.{
        .surface = surface.surface,
        .min_image_count = image_count,
        .image_format = format,
        .image_color_space = .srgb_nonlinear_khr,
        .image_extent = extent,
        .image_array_layers = 1,
        .image_usage = image_usage,
        .image_sharing_mode = .exclusive,
        .pre_transform = .{ .identity_bit_khr = true },
        .composite_alpha = composite_alpha,
        .present_mode = present_mode,
        .clipped = vk.FALSE,
    }, null);

    var images_len: u32 = 0;
    _ = try device.dispatch.getSwapchainImagesKHR(device.device, swapchain, &images_len, null);
    var images = try device.allocator.alloc(vk.Image, images_len);
    defer device.allocator.free(images);
    _ = try device.dispatch.getSwapchainImagesKHR(device.device, swapchain, &images_len, images.ptr);

    const textures = try device.allocator.alloc(Texture, images_len);
    for (images, 0..) |image, i| {
        textures[i] = try Texture.init(device, image, extent);
    }

    return .{
        .device = device,
        .swapchain = swapchain,
        .format = desc.format,
        .textures = textures,
    };
}

pub fn deinit(swapchain: *SwapChain) void {
    swapchain.device.allocator.free(swapchain.textures);
    swapchain.device.dispatch.destroySwapchainKHR(swapchain.device.device, swapchain.swapchain, null);
}

pub fn getCurrentTextureView(swapchain: *SwapChain) !*TextureView {
    const semaphore = swapchain.device.syncs[swapchain.device.sync_index].available;
    const fence = swapchain.device.syncs[swapchain.device.sync_index].fence;

    _ = try swapchain.device.dispatch.waitForFences(
        swapchain.device.device,
        1,
        &[_]vk.Fence{fence},
        vk.TRUE,
        std.math.maxInt(u64),
    );

    const result = try swapchain.device.dispatch.acquireNextImageKHR(
        swapchain.device.device,
        swapchain.swapchain,
        std.math.maxInt(u64),
        semaphore,
        .null_handle,
    );
    swapchain.texture_index = result.image_index;

    return swapchain.textures[swapchain.texture_index].createView(&.{
        .format = swapchain.format,
        .dimension = .dimension_2d,
    });
}

pub fn present(swapchain: *SwapChain) !void {
    {
        var cmd_buffer: vk.CommandBuffer = undefined;
        try swapchain.device.dispatch.allocateCommandBuffers(swapchain.device.device, &.{
            .command_pool = swapchain.device.cmd_pool,
            .level = .primary,
            .command_buffer_count = 1,
        }, @ptrCast(&cmd_buffer));
        try swapchain.device.dispatch.beginCommandBuffer(
            cmd_buffer,
            &.{
                .flags = .{ .one_time_submit_bit = true },
            },
        );

        swapchain.device.dispatch.cmdPipelineBarrier(
            cmd_buffer,
            .{ .top_of_pipe_bit = true },
            .{ .color_attachment_output_bit = true },
            .{},
            0,
            &[_]vk.MemoryBarrier{},
            0,
            &[_]vk.BufferMemoryBarrier{},
            1,
            &[_]vk.ImageMemoryBarrier{
                .{
                    .src_access_mask = .{},
                    .dst_access_mask = .{},
                    .old_layout = .color_attachment_optimal,
                    .new_layout = .present_src_khr,
                    .src_queue_family_index = 0,
                    .dst_queue_family_index = 0,
                    .image = swapchain.textures[swapchain.texture_index].image,
                    .subresource_range = .{
                        .aspect_mask = .{ .color_bit = true },
                        .base_mip_level = 0,
                        .level_count = 1,
                        .base_array_layer = 0,
                        .layer_count = 1,
                    },
                },
            },
        );

        try swapchain.device.dispatch.endCommandBuffer(cmd_buffer);
        const queue = try swapchain.device.getQueue();
        try swapchain.device.dispatch.queueSubmit(queue.queue, 1, &[_]vk.SubmitInfo{
            .{
                .command_buffer_count = 1,
                .p_command_buffers = &[_]vk.CommandBuffer{cmd_buffer},
            },
        }, .null_handle);
        try swapchain.device.dispatch.queueWaitIdle(queue.queue);
        swapchain.device.dispatch.freeCommandBuffers(swapchain.device.device, swapchain.device.cmd_pool, 1, &[_]vk.CommandBuffer{cmd_buffer});
    }

    _ = try swapchain.device.dispatch.queuePresentKHR(swapchain.device.queue.?.queue, &.{
        .wait_semaphore_count = 1,
        .p_wait_semaphores = &[_]vk.Semaphore{swapchain.device.syncs[swapchain.device.sync_index].finished},
        .swapchain_count = 1,
        .p_swapchains = &[_]vk.SwapchainKHR{swapchain.swapchain},
        .p_image_indices = &[_]u32{swapchain.texture_index},
    });

    {
        var cmd_buffer: vk.CommandBuffer = undefined;
        try swapchain.device.dispatch.allocateCommandBuffers(swapchain.device.device, &.{
            .command_pool = swapchain.device.cmd_pool,
            .level = .primary,
            .command_buffer_count = 1,
        }, @ptrCast(&cmd_buffer));
        try swapchain.device.dispatch.beginCommandBuffer(
            cmd_buffer,
            &.{
                .flags = .{ .one_time_submit_bit = true },
            },
        );

        swapchain.device.dispatch.cmdPipelineBarrier(
            cmd_buffer,
            .{ .top_of_pipe_bit = true },
            .{ .color_attachment_output_bit = true },
            .{},
            0,
            &[_]vk.MemoryBarrier{},
            0,
            &[_]vk.BufferMemoryBarrier{},
            1,
            &[_]vk.ImageMemoryBarrier{
                .{
                    .src_access_mask = .{},
                    .dst_access_mask = .{},
                    .old_layout = .present_src_khr,
                    .new_layout = .color_attachment_optimal,
                    .src_queue_family_index = 0,
                    .dst_queue_family_index = 0,
                    .image = swapchain.textures[swapchain.texture_index].image,
                    .subresource_range = .{
                        .aspect_mask = .{ .color_bit = true },
                        .base_mip_level = 0,
                        .level_count = 1,
                        .base_array_layer = 0,
                        .layer_count = 1,
                    },
                },
            },
        );

        try swapchain.device.dispatch.endCommandBuffer(cmd_buffer);
        const queue = try swapchain.device.getQueue();
        try swapchain.device.dispatch.queueSubmit(queue.queue, 1, &[_]vk.SubmitInfo{
            .{
                .command_buffer_count = 1,
                .p_command_buffers = &[_]vk.CommandBuffer{cmd_buffer},
            },
        }, .null_handle);
        try swapchain.device.dispatch.queueWaitIdle(queue.queue);
        swapchain.device.dispatch.freeCommandBuffers(swapchain.device.device, swapchain.device.cmd_pool, 1, &[_]vk.CommandBuffer{cmd_buffer});
    }
}
