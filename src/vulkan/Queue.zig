const std = @import("std");
const vk = @import("vulkan");
const Device = @import("Device.zig");
const CommandBuffer = @import("CommandBuffer.zig");
const Manager = @import("../helper.zig").Manager;

const Queue = @This();

manager: Manager(Queue) = .{},
device: *Device,
queue: vk.Queue,

pub fn init(device: *Device) !Queue {
    const queue = device.dispatch.getDeviceQueue(device.device, device.adapter.queue_family, 0);

    return .{
        .device = device,
        .queue = queue,
    };
}

pub fn deinit(queue: *Queue) void {
    _ = queue;
}

pub fn submit(queue: *Queue, commands: []const *CommandBuffer) !void {
    const dst_stage_masks = vk.PipelineStageFlags{ .all_commands_bit = true };
    const submits = try queue.device.allocator.alloc(vk.SubmitInfo, commands.len);
    defer queue.device.allocator.free(submits);

    for (commands, 0..) |buf, i| {
        submits[i] = .{
            .command_buffer_count = 1,
            .p_command_buffers = &[_]vk.CommandBuffer{buf.buffer},
            .wait_semaphore_count = 1,
            .p_wait_semaphores = &[_]vk.Semaphore{queue.device.syncs[queue.device.sync_index].available},
            .p_wait_dst_stage_mask = @ptrCast(&dst_stage_masks),
            .signal_semaphore_count = 1,
            .p_signal_semaphores = &[_]vk.Semaphore{queue.device.syncs[queue.device.sync_index].finished},
        };
    }

    try queue.device.dispatch.resetFences(
        queue.device.device,
        1,
        &[_]vk.Fence{queue.device.syncs[queue.device.sync_index].fence},
    );

    try queue.device.dispatch.queueSubmit(
        queue.queue,
        @intCast(submits.len),
        submits.ptr,
        queue.device.syncs[queue.device.sync_index].fence,
    );
}
