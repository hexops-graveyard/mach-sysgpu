const std = @import("std");
const gpu = @import("gpu");
const vk = @import("vulkan");
const Device = @import("Device.zig");
const Surface = @import("Surface.zig");
const Texture = @import("Texture.zig");
const TextureView = @import("TextureView.zig");
const Manager = @import("../helper.zig").Manager;
const global = @import("global.zig");

const SwapChain = @This();

manager: Manager(SwapChain) = .{},
device: *Device,
swapchain: vk.SwapchainKHR,
textures: []Texture,
texture_index: u32 = 0,
format: gpu.Texture.Format,

pub fn init(device: *Device, surface: *Surface, desc: *const gpu.SwapChain.Descriptor) !SwapChain {
    const format = global.vulkanFormatFromTextureFormat(desc.format);
    const extent = vk.Extent2D{
        .width = desc.width,
        .height = desc.height,
    };
    const capabilities = try device.adapter.instance.dispatch.getPhysicalDeviceSurfaceCapabilitiesKHR(
        device.adapter.physical_device,
        surface.surface,
    );
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
    const swapchain = try device.dispatch.createSwapchainKHR(device.device, &.{
        .surface = surface.surface,
        .min_image_count = @max(2, capabilities.min_image_count),
        .image_format = format,
        .image_color_space = .srgb_nonlinear_khr,
        .image_extent = extent,
        .image_array_layers = 1,
        .image_usage = .{
            .transfer_src_bit = desc.usage.copy_src,
            .transfer_dst_bit = desc.usage.copy_dst,
            .sampled_bit = desc.usage.texture_binding,
            .storage_bit = desc.usage.storage_binding,
            .color_attachment_bit = desc.usage.render_attachment,
            .transient_attachment_bit = desc.usage.transient_attachment,
        },
        .image_sharing_mode = .exclusive,
        .pre_transform = .{ .identity_bit_khr = true },
        .composite_alpha = composite_alpha,
        .present_mode = switch (desc.present_mode) {
            .immediate => vk.PresentModeKHR.immediate_khr,
            .mailbox => vk.PresentModeKHR.mailbox_khr,
            .fifo => vk.PresentModeKHR.fifo_khr,
        },
        .clipped = vk.FALSE,
    }, null);

    var image_count: u32 = 0;
    _ = try device.dispatch.getSwapchainImagesKHR(device.device, swapchain, &image_count, null);
    var images = try device.allocator.alloc(vk.Image, image_count);
    defer device.allocator.free(images);
    _ = try device.dispatch.getSwapchainImagesKHR(device.device, swapchain, &image_count, images.ptr);

    const textures = try device.allocator.alloc(Texture, image_count);
    for (images, 0..) |image, i| {
        textures[i] = .{
            .device = device,
            .image = image,
            .extent = extent,
        };
    }

    return .{
        .device = device,
        .swapchain = swapchain,
        .format = desc.format,
        .textures = textures,
    };
}

pub fn deinit(swapchain: *SwapChain) void {
    swapchain.device.dispatch.destroySwapchainKHR(swapchain.device.device, swapchain.swapchain, null);
}

pub fn getCurrentTextureView(swapchain: *SwapChain) !TextureView {
    const result = try swapchain.device.dispatch.acquireNextImageKHR(
        swapchain.device.device,
        swapchain.swapchain,
        std.math.maxInt(u64),
        swapchain.device.queue.image_available_semaphore,
        .null_handle,
    );
    switch (result.result) {
        .success, .suboptimal_khr => {},
        .error_out_of_date_khr => return swapchain.getCurrentTextureView(),
        .not_ready => return error.NotReady,
        .timeout => unreachable,
        else => unreachable,
    }
    swapchain.texture_index = result.image_index;

    return swapchain.textures[swapchain.texture_index].createView(&.{
        .format = swapchain.format,
        .dimension = .dimension_2d,
    });
}

pub fn present(swapchain: *SwapChain) !void {
    _ = try swapchain.device.dispatch.queuePresentKHR(swapchain.device.queue.queue, &.{
        .wait_semaphore_count = 1,
        .p_wait_semaphores = &[_]vk.Semaphore{swapchain.device.queue.render_finished_semaphore},
        .swapchain_count = 1,
        .p_swapchains = &[_]vk.SwapchainKHR{swapchain.swapchain},
        .p_image_indices = &[_]u32{swapchain.texture_index},
    });
    swapchain.texture_index = undefined;
}
