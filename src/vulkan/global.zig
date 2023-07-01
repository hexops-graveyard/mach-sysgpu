const vk = @import("vulkan");

pub const vulkan_version = vk.makeApiVersion(0, 1, 1, 0);
pub const validation_layer = "VK_LAYER_KHRONOS_validation";
