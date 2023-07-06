const std = @import("std");
const builtin = @import("builtin");
const vk = @import("vulkan");
const gpu = @import("mach-gpu");
const Adapter = @import("Adapter.zig");
const ShaderModule = @import("ShaderModule.zig");
const RenderPipeline = @import("RenderPipeline.zig");
const global = @import("global.zig");
const RefCounter = @import("../helper.zig").RefCounter;

const Device = @This();

const Dispatch = vk.DeviceWrapper(.{
    .createShaderModule = true,
    .createCommandPool = true,
    .destroyShaderModule = true,
    .destroyDevice = true,
});

ref_counter: RefCounter(Device) = .{},
device: vk.Device,
dispatch: Dispatch,
pool: vk.CommandPool,
err_cb: ?gpu.ErrorCallback = null,
err_cb_userdata: ?*anyopaque = null,

pub fn init(adapter: *Adapter, descriptor: *const gpu.Device.Descriptor) !Device {
    const queue_infos = &[_]vk.DeviceQueueCreateInfo{
        .{
            .queue_family_index = adapter.queue_family,
            .queue_count = 1,
            .p_queue_priorities = &[_]f32{1.0},
        },
    };

    var features = vk.PhysicalDeviceFeatures2{ .features = .{ .geometry_shader = vk.TRUE } };
    var feature_chain: *vk.BaseOutStructure = @ptrCast(&features);

    if (descriptor.required_features) |required_features| {
        for (required_features[0..descriptor.required_features_count]) |req_feature| {
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

    const layers = try getLayers(adapter);
    const extensions = try getExtensions(adapter);

    var create_info = vk.DeviceCreateInfo{
        .queue_create_info_count = @intCast(queue_infos.len),
        .p_queue_create_infos = queue_infos.ptr,
        .enabled_layer_count = @intCast(layers.len),
        .pp_enabled_layer_names = layers.ptr,
        .enabled_extension_count = @intCast(extensions.len),
        .pp_enabled_extension_names = extensions.ptr,
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

pub fn createRenderPipeline(device: *Device, descriptor: *const gpu.RenderPipeline.Descriptor) !RenderPipeline {
    return RenderPipeline.init(device, descriptor);
}

fn getLayers(adapter: *Adapter) ![]const [*:0]const u8 {
    var layer_count: u32 = 0;
    _ = try adapter.instance.dispatch.enumerateDeviceLayerProperties(adapter.device, &layer_count, null);

    var available_layers = try adapter.instance.allocator.alloc(vk.LayerProperties, layer_count);
    defer adapter.instance.allocator.free(available_layers);

    _ = try adapter.instance.dispatch.enumerateDeviceLayerProperties(adapter.device, &layer_count, available_layers.ptr);

    for (available_layers[0..layer_count]) |available| {
        if (std.mem.eql(u8, global.validation_layer, std.mem.sliceTo(&available.layer_name, 0))) {
            return &.{global.validation_layer};
        }
    }

    return &.{};
}

fn getExtensions(adapter: *Adapter) ![]const [*:0]const u8 {
    var ext_count: u32 = 0;
    _ = try adapter.instance.dispatch.enumerateDeviceExtensionProperties(adapter.device, null, &ext_count, null);

    var available_ext = try adapter.instance.allocator.alloc(vk.ExtensionProperties, ext_count);
    defer adapter.instance.allocator.free(available_ext);

    _ = try adapter.instance.dispatch.enumerateDeviceExtensionProperties(adapter.device, null, &ext_count, available_ext.ptr);

    for (available_ext[0..ext_count]) |available| {
        if (std.mem.eql(u8, vk.extension_info.khr_swapchain.name, std.mem.sliceTo(&available.extension_name, 0))) {
            return &.{vk.extension_info.khr_swapchain.name};
        }
    }

    return &.{};
}
