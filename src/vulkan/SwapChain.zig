const std = @import("std");
const gpu = @import("mach-gpu");
const vk = @import("vulkan");
const Device = @import("Device.zig");
const Surface = @import("Surface.zig");
const Texture = @import("Texture.zig");
const TextureView = @import("TextureView.zig");
const RefCounter = @import("../helper.zig").RefCounter;
const global = @import("global.zig");

const SwapChain = @This();

ref_counter: RefCounter(SwapChain) = .{},
swapchain: vk.SwapchainKHR,
device: *Device,
textures: []Texture,
texture_index: u32 = 0,
format: gpu.Texture.Format,

pub fn init(device: *Device, surface: *Surface, desc: *const gpu.SwapChain.Descriptor) !SwapChain {
    const capabilities = try device.adapter.instance.dispatch.getPhysicalDeviceSurfaceCapabilitiesKHR(
        device.adapter.device,
        surface.surface,
    );

    // var format_count: usize = 0;
    // _ = try device.adapter.instance.dispatch.getPhysicalDeviceSurfaceFormatsKHR(
    //     device.adapter.device,
    //     surface.surface,
    //     &format_count,
    //     null,
    // );
    // var formats = device.adapter.instance.allocator.alloc(vk.SurfaceFormatKHR, format_count);
    // defer device.adapter.instance.allocator.free(formats);
    // _ = try device.adapter.instance.dispatch.getPhysicalDeviceSurfaceFormatsKHR(
    //     device.adapter.device,
    //     surface.surface,
    //     &format_count,
    //     formats,
    // );

    const extent = vk.Extent2D{
        .width = desc.width,
        .height = desc.height,
    };
    const format = global.vkFormatFromTextureFormat(desc.format);
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
        .composite_alpha = .{
            .opaque_bit_khr = capabilities.supported_composite_alpha.opaque_bit_khr,
            .pre_multiplied_bit_khr = capabilities.supported_composite_alpha.pre_multiplied_bit_khr,
            .post_multiplied_bit_khr = capabilities.supported_composite_alpha.post_multiplied_bit_khr,
            .inherit_bit_khr = capabilities.supported_composite_alpha.inherit_bit_khr,
        },
        .present_mode = switch (desc.present_mode) {
            .immediate => vk.PresentModeKHR.immediate_khr,
            .mailbox => .mailbox_khr,
            .fifo => .fifo_khr,
        },
        .clipped = vk.FALSE,
    }, null);

    var image_count: u32 = 0;
    _ = try device.dispatch.getSwapchainImagesKHR(device.device, swapchain, &image_count, null);
    var images = try device.adapter.instance.allocator.alloc(vk.Image, image_count);
    defer device.adapter.instance.allocator.free(images);
    _ = try device.dispatch.getSwapchainImagesKHR(device.device, swapchain, &image_count, images.ptr);

    const textures = try device.adapter.instance.allocator.alloc(Texture, image_count);
    for (images, 0..) |image, i| {
        textures[i] = .{
            .image = image,
            .extent = extent,
            .samples = 1,
            .device = device,
        };
    }

    return .{
        .swapchain = swapchain,
        .device = device,
        .format = desc.format,
        .textures = textures,
    };
}

pub fn deinit(swapchain: *SwapChain) void {
    for (swapchain.semaphores) |semaphore| {
        swapchain.device.dispatch.destroySemaphore(swapchain.device.device, semaphore, null);
    }
    swapchain.device.adapter.instance.allocator.free(swapchain.semaphores);
    swapchain.device.dispatch.destroySwapchainKHR(swapchain.device.device, swapchain.swapchain);
}

pub fn getCurrentTextureView(swapchain: *SwapChain) !TextureView {
    const semaphore = try swapchain.device.dispatch.createSemaphore(swapchain.device.device, &.{}, null);
    defer swapchain.device.dispatch.destroySemaphore(swapchain.device.device, semaphore, null);

    const result = try swapchain.device.dispatch.acquireNextImageKHR(
        swapchain.device.device,
        swapchain.swapchain,
        std.math.maxInt(u64),
        semaphore,
        .null_handle,
    );
    switch (result.result) {
        .success => {},
        .suboptimal_khr => {},
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

pub fn present(self: *SwapChain) !void {
    try self.device.queue.waitUncapped();

    _ = try self.device.dispatch.queuePresentKHR(self.device.queue.graphics, &.{
        .wait_semaphore_count = 0,
        .p_wait_semaphores = undefined,
        .swapchain_count = 1,
        .p_swapchains = &[_]vk.SwapchainKHR{self.swapchain},
        .p_image_indices = &[_]u32{self.current_tex},
        .p_results = null,
    });
    self.current_tex = undefined;
}
