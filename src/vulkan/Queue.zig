const std = @import("std");
const vk = @import("vulkan");
const Device = @import("Device.zig");
const CommandBuffer = @import("CommandBuffer.zig");
const Manager = @import("../helper.zig").Manager;

const Queue = @This();

manager: Manager(Queue) = .{},
device: *Device,
queue: vk.Queue,
image_available_semaphore: vk.Semaphore,
render_finished_semaphore: vk.Semaphore,
fence: vk.Fence,

pub fn init(device: *Device) !Queue {
    const queue = device.dispatch.getDeviceQueue(device.device, device.adapter.queue_family, 0);
    const image_available_semaphore = try device.dispatch.createSemaphore(device.device, &.{}, null);
    const render_finished_semaphore = try device.dispatch.createSemaphore(device.device, &.{}, null);
    const fence = try device.dispatch.createFence(device.device, &.{ .flags = .{ .signaled_bit = true } }, null);
    return .{
        .device = device,
        .queue = queue,
        .image_available_semaphore = image_available_semaphore,
        .render_finished_semaphore = render_finished_semaphore,
        .fence = fence,
    };
}

pub fn deinit(queue: *Queue) void {
    queue.device.dispatch.destroyFence(queue.device.device, queue.fence, null);
    queue.device.dispatch.destroySemaphore(queue.device.device, queue.image_available_semaphore, null);
    queue.device.dispatch.destroySemaphore(queue.device.device, queue.render_finished_semaphore, null);
}

pub fn submit(queue: *Queue, commands: []const *CommandBuffer) !void {
    _ = try queue.device.dispatch.waitForFences(queue.device.device, 1, &[_]vk.Fence{queue.fence}, vk.TRUE, std.math.maxInt(u64));
    try queue.device.dispatch.resetFences(queue.device.device, 1, &[_]vk.Fence{queue.fence});

    const dst_stage_masks = vk.PipelineStageFlags{ .all_commands_bit = true };
    const submits = try queue.device.allocator.alloc(vk.SubmitInfo, commands.len);
    defer queue.device.allocator.free(submits);

    for (commands, 0..) |buf, i| {
        submits[i] = .{
            .command_buffer_count = 1,
            .p_command_buffers = &[_]vk.CommandBuffer{buf.buffer},
            .wait_semaphore_count = 1,
            .p_wait_semaphores = &[_]vk.Semaphore{queue.image_available_semaphore},
            .p_wait_dst_stage_mask = @ptrCast(&dst_stage_masks),
            .signal_semaphore_count = 1,
            .p_signal_semaphores = &[_]vk.Semaphore{queue.render_finished_semaphore},
        };
    }

    try queue.device.dispatch.queueSubmit(queue.queue, @intCast(submits.len), submits.ptr, queue.fence);
    try queue.device.dispatch.queueWaitIdle(queue.queue);
}
