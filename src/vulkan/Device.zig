const std = @import("std");
const builtin = @import("builtin");
const vk = @import("vulkan");
const gpu = @import("mach-gpu");
const Adapter = @import("Adapter.zig");
const ShaderModule = @import("ShaderModule.zig");
const Surface = @import("Surface.zig");
const RenderPipeline = @import("RenderPipeline.zig");
const SwapChain = @import("SwapChain.zig");
const Queue = @import("Queue.zig");
const global = @import("global.zig");
const RefCounter = @import("../helper.zig").RefCounter;

const Device = @This();

const Dispatch = vk.DeviceWrapper(.{
    .createShaderModule = true,
    .createCommandPool = true,
    .createSwapchainKHR = true,
    .createFence = true,
    .createSemaphore = true,
    .createImageView = true,
    .getDeviceQueue = true,
    .resetFences = true,
    .queueSubmit = true,
    .getSwapchainImagesKHR = true,
    .acquireNextImageKHR = true,
    .destroyShaderModule = true,
    .destroySwapchainKHR = true,
    .destroyDevice = true,
    .destroyFence = true,
    .destroySemaphore = true,
});

ref_counter: RefCounter(Device) = .{},
device: vk.Device,
adapter: *Adapter,
dispatch: Dispatch,
pool: vk.CommandPool,
queue: ?Queue = null,
err_cb: ?gpu.ErrorCallback = null,
err_cb_userdata: ?*anyopaque = null,

pub fn init(adapter: *Adapter, desc: *const gpu.Device.Descriptor) !Device {
    const queue_infos = &[_]vk.DeviceQueueCreateInfo{
        .{
            .queue_family_index = adapter.queue_family,
            .queue_count = 1,
            .p_queue_priorities = &[_]f32{1.0},
        },
    };

    var features = vk.PhysicalDeviceFeatures2{ .features = .{ .geometry_shader = vk.TRUE } };
    var feature_chain: *vk.BaseOutStructure = @ptrCast(&features);

    if (desc.required_features) |required_features| {
        for (required_features[0..desc.required_features_count]) |req_feature| {
            switch (req_feature) {
                .undefined => break,
                .depth_clip_control => features.features.depth_clamp = vk.TRUE,
                .pipeline_statistics_query => features.features.pipeline_statistics_query = vk.TRUE,
                .texture_compression_bc => features.features.texture_compression_bc = vk.TRUE,
                .texture_compression_etc2 => features.features.texture_compression_etc2 = vk.TRUE,
                .texture_compression_astc => features.features.texture_compression_astc_ldr = vk.TRUE,
                .indirect_first_instance => features.features.draw_indirect_first_instance = vk.TRUE,
                .shader_f16 => {
                    var next_feature = try adapter.instance.allocator.create(vk.PhysicalDeviceShaderFloat16Int8FeaturesKHR);
                    next_feature.s_type = .physical_device_shader_float16_int8_features_khr;
                    next_feature.shader_float_16 = vk.TRUE;
                    feature_chain.p_next = @ptrCast(next_feature);
                },
                else => @panic("TODO: implement required feature"),
            }
        }
    }

    const supported_layers = try getSupportedLayers(adapter);
    defer adapter.instance.allocator.free(supported_layers);

    var create_info = vk.DeviceCreateInfo{
        .queue_create_info_count = @intCast(queue_infos.len),
        .p_queue_create_infos = queue_infos.ptr,
        .enabled_layer_count = @intCast(supported_layers.len),
        .pp_enabled_layer_names = supported_layers.ptr,
        .enabled_extension_count = @intCast(required_extensions.len),
        .pp_enabled_extension_names = required_extensions.ptr,
    };

    if (adapter.hasExtension("GetPhysicalDeviceProperties2")) {
        create_info.p_next = &features;
    } else {
        create_info.p_enabled_features = &features.features;
    }

    const device = try adapter.instance.dispatch.createDevice(adapter.device, &create_info, null);
    const dispatch = try Dispatch.load(device, adapter.instance.dispatch.dispatch.vkGetDeviceProcAddr);
    const pool = try dispatch.createCommandPool(device, &.{ .queue_family_index = adapter.queue_family }, null);

    return .{
        .device = device,
        .adapter = adapter,
        .dispatch = dispatch,
        .pool = pool,
    };
}

pub fn deinit(device: *Device) void {
    device.dispatch.destroyDevice(device.device);
}

pub fn createShaderModule(device: *Device, code: []const u8) !ShaderModule {
    return ShaderModule.init(device, code);
}

pub fn createRenderPipeline(device: *Device, desc: *const gpu.RenderPipeline.Descriptor) !RenderPipeline {
    return RenderPipeline.init(device, desc);
}

pub fn createSwapChain(device: *Device, surface: *Surface, desc: *const gpu.SwapChain.Descriptor) !SwapChain {
    return SwapChain.init(device, surface, desc);
}

pub fn getQueue(device: *Device) !*Queue {
    if (device.queue) |queue| return @constCast(&queue);
    device.queue = try Queue.init(device, device.adapter.queue_family);
    return @constCast(&device.queue.?);
}

const optional_layers = &[_][*:0]const u8{global.validation_layer};
const required_extensions = &[_][*:0]const u8{vk.extension_info.khr_swapchain.name};

fn getSupportedLayers(adapter: *Adapter) ![]const [*:0]const u8 {
    var supported_layers = std.ArrayList([*:0]const u8).init(adapter.instance.allocator);
    errdefer supported_layers.deinit();

    var layer_count: u32 = 0;
    _ = try adapter.instance.dispatch.enumerateDeviceLayerProperties(adapter.device, &layer_count, null);

    var available_layers = try adapter.instance.allocator.alloc(vk.LayerProperties, layer_count);
    defer adapter.instance.allocator.free(available_layers);

    _ = try adapter.instance.dispatch.enumerateDeviceLayerProperties(adapter.device, &layer_count, available_layers.ptr);

    for (available_layers[0..layer_count]) |available| {
        for (optional_layers) |wanted| {
            if (std.mem.eql(u8, std.mem.sliceTo(wanted, 0), std.mem.sliceTo(&available.layer_name, 0))) {
                try supported_layers.append(global.validation_layer);
            }
        }
    }

    return supported_layers.toOwnedSlice();
}
