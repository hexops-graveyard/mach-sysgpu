const std = @import("std");
const vk = @import("vulkan");
const gpu = @import("gpu");
const Device = @import("Device.zig");
const CommandBuffer = @import("CommandBuffer.zig");
const RenderPassEncoder = @import("RenderPassEncoder.zig");
const Manager = @import("../helper.zig").Manager;

const CommandEncoder = @This();

manager: Manager(CommandEncoder) = .{},
device: *Device,

pub fn init(device: *Device, desc: ?*const gpu.CommandEncoder.Descriptor) !CommandEncoder {
    _ = desc;
    const cmd_buffer = device.syncs[device.sync_index].cmd_buffer;
    try device.dispatch.beginCommandBuffer(cmd_buffer.buffer, &.{});
    return .{ .device = device };
}

pub fn deinit(cmd_encoder: *CommandEncoder) void {
    _ = cmd_encoder;
}

pub fn beginRenderPass(cmd_encoder: *CommandEncoder, desc: *const gpu.RenderPassDescriptor) !RenderPassEncoder {
    return RenderPassEncoder.init(cmd_encoder.device, desc);
}

pub fn finish(cmd_encoder: *CommandEncoder, desc: *const gpu.CommandBuffer.Descriptor) !*CommandBuffer {
    _ = desc;
    const cmd_buffer = &cmd_encoder.device.syncs[cmd_encoder.device.sync_index].cmd_buffer;
    try cmd_encoder.device.dispatch.endCommandBuffer(cmd_buffer.buffer);
    return cmd_buffer;
}
