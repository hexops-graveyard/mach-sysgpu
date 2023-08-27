const vk = @import("vulkan");
const gpu = @import("gpu");
const Device = @import("Device.zig");
const TextureView = @import("TextureView.zig");
const Manager = @import("../helper.zig").Manager;

const Texture = @This();

manager: Manager(Texture) = .{},
device: *Device,
extent: vk.Extent2D,
image: vk.Image,
view: ?TextureView = null,

pub fn init(device: *Device, image: vk.Image, extent: vk.Extent2D) !Texture {
    var cmd_buffer: vk.CommandBuffer = undefined;
    try device.dispatch.allocateCommandBuffers(device.device, &.{
        .command_pool = device.cmd_pool,
        .level = .primary,
        .command_buffer_count = 1,
    }, @ptrCast(&cmd_buffer));
    try device.dispatch.beginCommandBuffer(
        cmd_buffer,
        &.{
            .flags = .{ .one_time_submit_bit = true },
        },
    );

    device.dispatch.cmdPipelineBarrier(
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
                .old_layout = .undefined,
                .new_layout = .color_attachment_optimal,
                .src_queue_family_index = 0,
                .dst_queue_family_index = 0,
                .image = image,
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

    try device.dispatch.endCommandBuffer(cmd_buffer);

    const queue = try device.getQueue();
    try device.dispatch.queueSubmit(queue.queue, 1, &[_]vk.SubmitInfo{
        .{
            .command_buffer_count = 1,
            .p_command_buffers = &[_]vk.CommandBuffer{cmd_buffer},
        },
    }, .null_handle);
    try device.dispatch.queueWaitIdle(queue.queue);
    device.dispatch.freeCommandBuffers(device.device, device.cmd_pool, 1, &[_]vk.CommandBuffer{cmd_buffer});

    return .{
        .device = device,
        .extent = extent,
        .image = image,
    };
}

pub fn deinit(texture: *Texture) void {
    _ = texture;
}

pub fn createView(texture: *Texture, desc: *const gpu.TextureView.Descriptor) !*TextureView {
    texture.view = try TextureView.init(texture, desc);
    return &texture.view.?;
}
