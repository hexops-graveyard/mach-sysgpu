const vk = @import("vulkan");
const gpu = @import("mach").gpu;
const Device = @import("Device.zig");
const BindGroupLayout = @import("BindGroupLayout.zig");
const Manager = @import("../helper.zig").Manager;

const PipelineLayout = @This();

manager: Manager(PipelineLayout) = .{},
device: *Device,
layout: vk.PipelineLayout,

pub fn init(device: *Device, descriptor: *const gpu.PipelineLayout.Descriptor) !PipelineLayout {
    const groups = try device.allocator.alloc(vk.DescriptorSetLayout, descriptor.bind_group_layout_count);
    defer device.allocator.free(groups);
    for (groups, 0..) |*layout, i| {
        layout.* = @as(*BindGroupLayout, @ptrCast(@alignCast(descriptor.bind_group_layouts.?[i]))).layout;
    }

    const layout = try device.dispatch.createPipelineLayout(device.device, &.{
        .set_layout_count = @as(u32, @intCast(groups.len)),
        .p_set_layouts = groups.ptr,
    }, null);

    return .{
        .device = device,
        .layout = layout,
    };
}

pub fn deinit(layout: *PipelineLayout) void {
    layout.device.dispatch.destroyPipelineLayout(layout.device.device, layout.layout, null);
}
