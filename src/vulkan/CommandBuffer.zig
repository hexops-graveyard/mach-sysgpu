const std = @import("std");
const builtin = @import("builtin");
const vk = @import("vulkan");
const Device = @import("Device.zig");
const RenderPassEncoder = @import("RenderPassEncoder.zig");
const Manager = @import("../helper.zig").Manager;

const CommandBuffer = @This();

manager: Manager(CommandBuffer) = .{},
buffer: vk.CommandBuffer,
device: *Device,
render_passes: std.ArrayListUnmanaged(*RenderPassEncoder) = .{},

pub fn init(device: *Device) !CommandBuffer {
    var buffer: vk.CommandBuffer = undefined;
    try device.dispatch.allocateCommandBuffers(device.device, &.{
        .command_pool = device.cmd_pool,
        .level = .primary,
        .command_buffer_count = 1,
    }, @ptrCast(&buffer));
    try device.dispatch.beginCommandBuffer(buffer, &.{});
    return .{
        .buffer = buffer,
        .device = device,
    };
}

pub fn deinit(cmd_buffer: *CommandBuffer) void {
    cmd_buffer.device.dispatch.freeCommandBuffers(
        cmd_buffer.device.device,
        cmd_buffer.device.cmd_pool,
        1,
        @ptrCast(&cmd_buffer.buffer),
    );
    cmd_buffer.render_passes.deinit(cmd_buffer.device.allocator);
}
