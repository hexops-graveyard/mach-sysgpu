const std = @import("std");
const gpu = @import("gpu");
const vk = @import("vulkan");
const Device = @import("Device.zig");
const CommandBuffer = @import("CommandBuffer.zig");
const RefCounter = @import("../helper.zig").RefCounter;

const Queue = @This();

ref_counter: RefCounter(Queue) = .{},
device: *Device,
queue: vk.Queue,
fence: vk.Fence,
commands: std.ArrayListUnmanaged(*CommandBuffer) = .{},

pub fn init(device: *Device, queue_family: u32) !Queue {
    const fence = try device.dispatch.createFence(device.device, &.{ .flags = .{ .signaled_bit = true } }, null);
    return .{
        .device = device,
        .queue = device.dispatch.getDeviceQueue(device.device, queue_family, 0),
        .fence = fence,
    };
}

pub fn deinit(queue: *Queue) void {
    for (queue.commands.items) |buf| {
        buf.ref_counter.release();
    }
    queue.commands.deinit(queue.device.adapter.instance.allocator);
    queue.device.dispatch.destroyFence(queue.device.device, queue.fence, null);
}

pub fn submit(queue: *Queue, commands: []const *CommandBuffer) !void {
    try queue.waitUncapped();
    for (queue.commands.items) |buf| {
        buf.manager.release();
    }
    errdefer queue.commands.clearRetainingCapacity();

    try queue.commands.resize(queue.device.adapter.instance.allocator, commands.len);
    std.mem.copy(*CommandBuffer, queue.commands.items, commands);

    const submits = try queue.adapter.instance.allocator.alloc(vk.SubmitInfo, commands.len);
    defer queue.adapter.instance.allocator.free(submits);
    for (commands, 0..) |buf, i| {
        buf.manager.reference();
        submits[i] = .{
            .command_buffer_count = 1,
            .p_command_buffers = @as(*const [1]vk.CommandBuffer, &buf.buffer),
        };
    }

    try queue.device.dispatch.resetFences(queue.device.device, 1, &[1]vk.Fence{queue.fence});
    try queue.device.dispatch.queueSubmit(queue.queue, @intCast(submits.len), submits.ptr, queue.fence);
}

pub fn waitUncapped(self: *Queue) !void {
    while (!try self.waitTimeout(std.math.maxInt(u64))) {}
}

pub fn waitTimeout(queue: *Queue, timeout: u64) !bool {
    const res = try queue.device.dispatch.waitForFences(
        queue.device.device,
        1,
        &[_]vk.Fence{queue.fence},
        vk.TRUE,
        timeout,
    );
    return res == .success;
}
