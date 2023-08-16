const std = @import("std");
const builtin = @import("builtin");
const vk = @import("vulkan");
const gpu = @import("gpu");
const Adapter = @import("Adapter.zig");
const ShaderModule = @import("ShaderModule.zig");
const Surface = @import("Surface.zig");
const RenderPipeline = @import("RenderPipeline.zig");
const SwapChain = @import("SwapChain.zig");
const CommandBuffer = @import("CommandBuffer.zig");
const CommandEncoder = @import("CommandEncoder.zig");
const Queue = @import("Queue.zig");
const Manager = @import("../helper.zig").Manager;

const Device = @This();

pub const Dispatch = vk.DeviceWrapper(.{
    .acquireNextImageKHR = true,
    .allocateCommandBuffers = true,
    .beginCommandBuffer = true,
    .cmdBeginRenderPass = true,
    .cmdBindPipeline = true,
    .cmdDraw = true,
    .cmdEndRenderPass = true,
    .cmdSetScissor = true,
    .cmdSetViewport = true,
    .createCommandPool = true,
    .createFence = true,
    .createFramebuffer = true,
    .createGraphicsPipelines = true,
    .createImageView = true,
    .createPipelineLayout = true,
    .createRenderPass = true,
    .createSemaphore = true,
    .createShaderModule = true,
    .createSwapchainKHR = true,
    .destroyCommandPool = true,
    .destroyDevice = true,
    .destroyFence = true,
    .destroyFramebuffer = true,
    .destroyImageView = true,
    .destroyPipeline = true,
    .destroyPipelineLayout = true,
    .destroyRenderPass = true,
    .destroySemaphore = true,
    .destroyShaderModule = true,
    .destroySwapchainKHR = true,
    .endCommandBuffer = true,
    .freeCommandBuffers = true,
    .getDeviceQueue = true,
    .getSwapchainImagesKHR = true,
    .queuePresentKHR = true,
    .queueSubmit = true,
    .queueWaitIdle = true,
    .resetFences = true,
    .waitForFences = true,
});

manager: Manager(Device) = .{},
allocator: std.mem.Allocator,
adapter: *Adapter,
dispatch: Dispatch,
device: vk.Device,
cmd_pool: vk.CommandPool,
queue: ?Queue = null,
err_cb: ?gpu.ErrorCallback = null,
err_cb_userdata: ?*anyopaque = null,

pub fn init(adapter: *Adapter, desc: *const gpu.Device.Descriptor) !Device {
    const queue_infos = &[_]vk.DeviceQueueCreateInfo{.{
        .queue_family_index = adapter.queue_family,
        .queue_count = 1,
        .p_queue_priorities = &[_]f32{1.0},
    }};

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
                    var next_feature = vk.PhysicalDeviceShaderFloat16Int8FeaturesKHR{
                        .s_type = .physical_device_shader_float16_int8_features_khr,
                        .shader_float_16 = vk.TRUE,
                    };
                    feature_chain.p_next = @ptrCast(&next_feature);
                },
                else => std.log.warn("unimplement feature: {s}", .{@tagName(req_feature)}),
            }
        }
    }

    const layers = try getLayers(adapter);
    defer adapter.allocator.free(layers);

    const extensions = try getExtensions(adapter);
    defer adapter.allocator.free(extensions);

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

    const device_raw = try adapter.instance.dispatch.createDevice(adapter.physical_device, &create_info, null);
    const dispatch = try Dispatch.load(device_raw, adapter.instance.dispatch.dispatch.vkGetDeviceProcAddr);
    const cmd_pool = try dispatch.createCommandPool(device_raw, &.{ .queue_family_index = adapter.queue_family }, null);

    return .{
        .allocator = adapter.allocator,
        .adapter = adapter,
        .dispatch = dispatch,
        .device = device_raw,
        .cmd_pool = cmd_pool,
    };
}

pub fn deinit(device: *Device) void {
    device.dispatch.destroyDevice(device.device, null);
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

pub fn createCommandEncoder(device: *Device, desc: *const gpu.CommandEncoder.Descriptor) !CommandEncoder {
    return CommandEncoder.init(device, desc);
}

pub fn getQueue(device: *Device) !*Queue {
    if (device.queue == null) {
        device.queue = try Queue.init(device);
    }
    return &device.queue.?;
}

pub const required_layers = &[_][*:0]const u8{};
pub const optional_layers = if (builtin.mode == .Debug)
    &[_][*:0]const u8{"VK_LAYER_KHRONOS_validation"}
else
    &.{};

fn getLayers(adapter: *Adapter) ![]const [*:0]const u8 {
    var layers = try std.ArrayList([*:0]const u8).initCapacity(
        adapter.allocator,
        required_layers.len + optional_layers.len,
    );
    errdefer layers.deinit();

    var count: u32 = 0;
    _ = try adapter.instance.dispatch.enumerateDeviceLayerProperties(adapter.physical_device, &count, null);

    var available_layers = try adapter.allocator.alloc(vk.LayerProperties, count);
    defer adapter.allocator.free(available_layers);
    _ = try adapter.instance.dispatch.enumerateDeviceLayerProperties(adapter.physical_device, &count, available_layers.ptr);

    for (required_layers) |required| {
        for (available_layers[0..count]) |available| {
            if (std.mem.eql(u8, std.mem.sliceTo(required, 0), std.mem.sliceTo(&available.layer_name, 0))) {
                layers.appendAssumeCapacity(required);
                break;
            }
        } else {
            std.log.warn("unable to find required layer: {s}", .{required});
        }
    }

    for (optional_layers) |optional| {
        for (available_layers[0..count]) |available| {
            if (std.mem.eql(u8, std.mem.sliceTo(optional, 0), std.mem.sliceTo(&available.layer_name, 0))) {
                layers.appendAssumeCapacity(optional);
                break;
            }
        }
    }

    return layers.toOwnedSlice();
}

pub const required_extensions = &[_][*:0]const u8{vk.extension_info.khr_swapchain.name};
pub const optional_extensions = &[_][*:0]const u8{};

fn getExtensions(adapter: *Adapter) ![]const [*:0]const u8 {
    var extensions = try std.ArrayList([*:0]const u8).initCapacity(
        adapter.allocator,
        required_extensions.len + optional_extensions.len,
    );
    errdefer extensions.deinit();

    var count: u32 = 0;
    _ = try adapter.instance.dispatch.enumerateDeviceExtensionProperties(adapter.physical_device, null, &count, null);

    var available_extensions = try adapter.allocator.alloc(vk.ExtensionProperties, count);
    defer adapter.allocator.free(available_extensions);
    _ = try adapter.instance.dispatch.enumerateDeviceExtensionProperties(adapter.physical_device, null, &count, available_extensions.ptr);

    for (required_extensions) |required| {
        for (available_extensions[0..count]) |available| {
            if (std.mem.eql(u8, std.mem.sliceTo(required, 0), std.mem.sliceTo(&available.extension_name, 0))) {
                extensions.appendAssumeCapacity(required);
                break;
            }
        } else {
            std.log.warn("unable to find required extension: {s}", .{required});
        }
    }

    for (optional_extensions) |optional| {
        for (available_extensions[0..count]) |available| {
            if (std.mem.eql(u8, std.mem.sliceTo(optional, 0), std.mem.sliceTo(&available.extension_name, 0))) {
                extensions.appendAssumeCapacity(optional);
                break;
            }
        }
    }

    return extensions.toOwnedSlice();
}
