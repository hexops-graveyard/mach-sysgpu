const std = @import("std");
const builtin = @import("builtin");
const vk = @import("vulkan");
const Device = @import("Device.zig");
const RenderPassEncoder = @import("RenderPassEncoder.zig");
const Manager = @import("../helper.zig").Manager;

const CommandBuffer = @This();

manager: Manager(CommandBuffer) = .{},
buffer: vk.CommandBuffer,

pub fn deinit(cmd_buffer: *CommandBuffer) void {
    _ = cmd_buffer;
}
