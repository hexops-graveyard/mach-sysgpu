const std = @import("std");
const builtin = @import("builtin");
const vk = @import("vulkan");
const gpu = @import("mach-gpu");
const Device = @import("Device.zig");
const TextureView = @import("TextureView.zig");
const global = @import("global.zig");
const RefCounter = @import("../helper.zig").RefCounter;

const Texture = @This();

ref_counter: RefCounter(Texture) = .{},
image: vk.Image,
extent: vk.Extent2D,
samples: u32,
device: *Device,

pub fn deinit(texture: *Texture) void {
    texture.device.dispatch.destroyImage(texture.device.device, texture.image, null);
    texture.device.allocator().destroy(texture);
}

pub fn createView(texture: *Texture, desc: *const gpu.TextureView.Descriptor) !TextureView {
    return TextureView.init(texture, desc);
}
