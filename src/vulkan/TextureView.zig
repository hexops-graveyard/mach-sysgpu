const std = @import("std");
const builtin = @import("builtin");
const vk = @import("vulkan");
const gpu = @import("mach-gpu");
const Device = @import("Device.zig");
const Texture = @import("Texture.zig");
const global = @import("global.zig");
const RefCounter = @import("../helper.zig").RefCounter;

const TextureView = @This();

ref_counter: RefCounter(TextureView) = .{},
view: vk.ImageView,
format: vk.Format,
texture: *Texture,

pub fn init(texture: *Texture, desc: *const gpu.TextureView.Descriptor) !TextureView {
    const format = global.vkFormatFromTextureFormat(desc.format);
    const aspect: vk.ImageAspectFlags = if (desc.aspect == .all)
        switch (desc.format) {
            .stencil8 => .{ .stencil_bit = true },
            .depth16_unorm, .depth24_plus, .depth32_float => .{ .depth_bit = true },
            .depth24_plus_stencil8, .depth32_float_stencil8 => .{ .depth_bit = true, .stencil_bit = true },
            .r8_bg8_biplanar420_unorm => .{ .plane_0_bit = true, .plane_1_bit = true },
            else => .{ .color_bit = true },
        }
    else
        .{
            .stencil_bit = desc.aspect == .stencil_only,
            .depth_bit = desc.aspect == .depth_only,
            .plane_0_bit = desc.aspect == .plane0_only,
            .plane_1_bit = desc.aspect == .plane1_only,
        };
    const view = try texture.device.dispatch.createImageView(texture.device.device, &.{
        .image = texture.image,
        .view_type = @as(vk.ImageViewType, switch (desc.dimension) {
            .dimension_undefined => unreachable,
            .dimension_1d => .@"1d",
            .dimension_2d => .@"2d",
            .dimension_2d_array => .@"2d_array",
            .dimension_cube => .cube,
            .dimension_cube_array => .cube_array,
            .dimension_3d => .@"3d",
        }),
        .format = format,
        .components = .{
            .r = .identity,
            .g = .identity,
            .b = .identity,
            .a = .identity,
        },
        .subresource_range = .{
            .aspect_mask = aspect,
            .base_mip_level = desc.base_mip_level,
            .level_count = desc.mip_level_count,
            .base_array_layer = desc.base_array_layer,
            .layer_count = desc.array_layer_count,
        },
    }, null);
    return .{
        .view = view,
        .format = format,
        .texture = texture,
    };
}

pub fn deinit(self: *TextureView) void {
    self.texture.device.dispatch.destroyImageView(self.texture.device.device, self.view, null);
}
