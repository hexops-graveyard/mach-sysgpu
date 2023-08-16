const std = @import("std");
const vk = @import("vulkan");
const gpu = @import("mach").gpu;
const Device = @import("Device.zig");
const CommandBuffer = @import("CommandBuffer.zig");
const RenderPassEncoder = @import("RenderPassEncoder.zig");
const Manager = @import("../helper.zig").Manager;

const CommandEncoder = @This();

manager: Manager(CommandEncoder) = .{},
device: *Device,
cmd_buffer: CommandBuffer,

pub fn init(device: *Device, desc: ?*const gpu.CommandEncoder.Descriptor) !CommandEncoder {
    _ = desc;
    return .{
        .device = device,
        .cmd_buffer = try CommandBuffer.init(device),
    };
}

pub fn deinit(cmd_encoder: *CommandEncoder) void {
    _ = cmd_encoder;
}

pub fn beginRenderPass(cmd_encoder: *CommandEncoder, desc: *const gpu.RenderPassDescriptor) !RenderPassEncoder {
    return RenderPassEncoder.init(cmd_encoder, desc);
}

pub fn finish(cmd_encoder: *CommandEncoder, desc: *const gpu.CommandBuffer.Descriptor) !*CommandBuffer {
    _ = desc;
    try cmd_encoder.device.dispatch.endCommandBuffer(cmd_encoder.cmd_buffer.buffer);
    return &cmd_encoder.cmd_buffer;
}
