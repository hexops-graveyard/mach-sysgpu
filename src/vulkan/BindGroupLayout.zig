const std = @import("std");
const vk = @import("vulkan");
const Manager = @import("../helper.zig").Manager;

const BindGroupLayout = @This();

manager: Manager(BindGroupLayout) = .{},
layout: vk.DescriptorSetLayout,

pub fn deinit(layout: BindGroupLayout) void {
    _ = layout;
}
