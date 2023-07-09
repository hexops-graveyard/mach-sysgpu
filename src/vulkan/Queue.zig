const std = @import("std");
const vk = @import("vulkan");
const Device = @import("Device.zig");
const CommandBuffer = @import("CommandBuffer.zig");
const Manager = @import("../helper.zig").Manager;

const Queue = @This();

manager: Manager(Queue) = .{},
allocator: std.mem.Allocator,
device_dispatch: Device.Dispatch,
device_raw: vk.Device,
queue: vk.Queue,
image_available_semaphore: vk.Semaphore,
render_finished_semaphore: vk.Semaphore,
fence: vk.Fence,

pub fn init(allocator: std.mem.Allocator, device_dispatch: Device.Dispatch, device_raw: vk.Device, queue_family: u32) !Queue {
    const queue = device_dispatch.getDeviceQueue(device_raw, queue_family, 0);
    const image_available_semaphore = try device_dispatch.createSemaphore(device_raw, &.{}, null);
    const render_finished_semaphore = try device_dispatch.createSemaphore(device_raw, &.{}, null);
    const fence = try device_dispatch.createFence(device_raw, &.{ .flags = .{ .signaled_bit = true } }, null);
    return .{
        .allocator = allocator,
        .device_dispatch = device_dispatch,
        .device_raw = device_raw,
        .queue = queue,
        .image_available_semaphore = image_available_semaphore,
        .render_finished_semaphore = render_finished_semaphore,
        .fence = fence,
    };
}

pub fn deinit(queue: *Queue) void {
    queue.device_dispatch.destroyFence(queue.device_raw, queue.fence, null);
    queue.device_dispatch.destroySemaphore(queue.device_raw, queue.image_available_semaphore, null);
    queue.device_dispatch.destroySemaphore(queue.device_raw, queue.render_finished_semaphore, null);
}

pub fn submit(queue: *Queue, commands: []const *CommandBuffer) !void {
    _ = try queue.device_dispatch.waitForFences(queue.device_raw, 1, &[_]vk.Fence{queue.fence}, vk.TRUE, std.math.maxInt(u64));
    try queue.device_dispatch.resetFences(queue.device_raw, 1, &[_]vk.Fence{queue.fence});

    const submits = try queue.allocator.alloc(vk.SubmitInfo, commands.len);
    defer queue.allocator.free(submits);
    for (commands, 0..) |buf, i| {
        submits[i] = .{
            .command_buffer_count = 1,
            .p_command_buffers = &[_]vk.CommandBuffer{buf.buffer},
            .wait_semaphore_count = 1,
            .p_wait_semaphores = &[_]vk.Semaphore{queue.image_available_semaphore},
            .signal_semaphore_count = 1,
            .p_signal_semaphores = &[_]vk.Semaphore{queue.render_finished_semaphore},
        };
    }

    try queue.device_dispatch.queueSubmit(queue.queue, @intCast(submits.len), submits.ptr, queue.fence);
}
