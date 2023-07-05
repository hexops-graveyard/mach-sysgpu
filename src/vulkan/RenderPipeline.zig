const std = @import("std");
const builtin = @import("builtin");
const vk = @import("vulkan");
const gpu = @import("mach-gpu");
const Device = @import("Device.zig");
const global = @import("global.zig");
const RefCounter = @import("../helper.zig").RefCounter;

const RenderPipeline = @This();

ref_counter: RefCounter(RenderPipeline) = .{},

// TODO
pub fn init(device: *Device, descriptor: *const gpu.RenderPipeline.Descriptor) !RenderPipeline {
    _ = device;
    _ = descriptor;

    return .{};
}

pub fn deinit(render_pipeline: *RenderPipeline) void {
    _ = render_pipeline;
}
