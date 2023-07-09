const vk = @import("vulkan");
const gpu = @import("gpu");
const Device = @import("Device.zig");
const BindGroupLayout = @import("BindGroupLayout.zig");
const Manager = @import("../helper.zig").Manager;

const PipelineLayout = @This();

manager: Manager(PipelineLayout) = .{},
layout: vk.PipelineLayout,
device: *Device,

pub fn init(device: *Device, descriptor: *const gpu.PipelineLayout.Descriptor) !PipelineLayout {
    const groups = try device.allocator.alloc(vk.DescriptorSetLayout, descriptor.bind_group_layout_count);
    defer device.allocator.free(groups);
    for (groups, 0..) |*l, i| {
        l.* = @as(*BindGroupLayout, @ptrCast(@alignCast(descriptor.bind_group_layouts.?[i]))).layout;
    }

    const layout = try device.dispatch.createPipelineLayout(device.device, &.{
        .flags = .{},
        .set_layout_count = @as(u32, @intCast(groups.len)),
        .p_set_layouts = groups.ptr,
        .push_constant_range_count = 0,
        .p_push_constant_ranges = undefined,
    }, null);

    return .{
        .layout = layout,
        .device = device,
    };
}

pub fn deinit(layout: *PipelineLayout) void {
    layout.device.dispatch.destroyPipelineLayout(layout.device.device, layout.layout, null);
}
