const vk = @import("vulkan");
const gpu = @import("gpu");
const Device = @import("Device.zig");
const TextureView = @import("TextureView.zig");
const Manager = @import("../helper.zig").Manager;

const Texture = @This();

manager: Manager(Texture) = .{},
device: *Device,
image: vk.Image,
extent: vk.Extent2D,

pub fn deinit(texture: *Texture) void {
    texture.device.dispatch.destroyImage(texture.device.device, texture.image, null);
    texture.device.allocator().destroy(texture);
}

pub fn createView(texture: *Texture, desc: *const gpu.TextureView.Descriptor) !TextureView {
    return TextureView.init(texture, desc);
}
