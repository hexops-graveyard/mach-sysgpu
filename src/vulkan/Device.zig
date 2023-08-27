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
    .cmdPipelineBarrier = true,
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
    .destroyImage = true,
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
    .resetCommandBuffer = true,
    .resetFences = true,
    .waitForFences = true,
});

const max_frames_in_flight = 2;

const Sync = struct {
    available: vk.Semaphore,
    finished: vk.Semaphore,
    fence: vk.Fence,
    cmd_buffer: CommandBuffer,
};

manager: Manager(Device) = .{},
allocator: std.mem.Allocator,
adapter: *Adapter,
dispatch: Dispatch,
device: vk.Device,
cmd_pool: vk.CommandPool,
render_passes: std.AutoHashMapUnmanaged(RenderPassKey, vk.RenderPass) = .{},
framebuffer: vk.Framebuffer = .null_handle,
syncs: [max_frames_in_flight]Sync,
sync_index: u8 = 0,
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

    const device = try adapter.instance.dispatch.createDevice(adapter.physical_device, &create_info, null);
    const dispatch = try Dispatch.load(device, adapter.instance.dispatch.dispatch.vkGetDeviceProcAddr);
    const cmd_pool = try dispatch.createCommandPool(
        device,
        &.{
            .queue_family_index = adapter.queue_family,
            .flags = .{ .reset_command_buffer_bit = true },
        },
        null,
    );

    var syncs: [max_frames_in_flight]Sync = undefined;
    for (&syncs) |*sync| {
        sync.* = .{
            .available = try dispatch.createSemaphore(device, &.{}, null),
            .finished = try dispatch.createSemaphore(device, &.{}, null),
            .fence = try dispatch.createFence(device, &.{ .flags = .{ .signaled_bit = true } }, null),
            .cmd_buffer = blk: {
                var buffer: vk.CommandBuffer = undefined;
                try dispatch.allocateCommandBuffers(device, &.{
                    .command_pool = cmd_pool,
                    .level = .primary,
                    .command_buffer_count = 1,
                }, @ptrCast(&buffer));
                break :blk .{ .buffer = buffer };
            },
        };
    }

    return .{
        .allocator = adapter.allocator,
        .adapter = adapter,
        .dispatch = dispatch,
        .device = device,
        .cmd_pool = cmd_pool,
        .syncs = syncs,
    };
}

pub fn deinit(device: *Device) void {
    for (device.syncs) |sync| {
        device.dispatch.destroySemaphore(device.device, sync.available, null);
        device.dispatch.destroySemaphore(device.device, sync.finished, null);
        device.dispatch.destroyFence(device.device, sync.fence, null);
        device.dispatch.freeCommandBuffers(device.device, device.cmd_pool, 1, &[_]vk.CommandBuffer{sync.cmd_buffer.buffer});
    }

    var render_pass_iter = device.render_passes.valueIterator();
    while (render_pass_iter.next()) |pass| {
        device.dispatch.destroyRenderPass(device.device, pass.*, null);
    }
    device.render_passes.deinit(device.allocator);

    device.dispatch.destroyFramebuffer(device.device, device.framebuffer, null);
    device.dispatch.destroyCommandPool(device.device, device.cmd_pool, null);
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

pub fn tick(device: *Device) void {
    device.sync_index = (device.sync_index + 1) % max_frames_in_flight;
}

pub const required_layers = &[_][*:0]const u8{};
pub const optional_layers = if (builtin.mode == .Debug and false)
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

pub const ColorAttachmentKey = struct {
    format: vk.Format, // TODO: gpu.TextureFormat instead?
    load_op: gpu.LoadOp,
    store_op: gpu.StoreOp,
    resolve_format: ?vk.Format,
};

pub const DepthStencilAttachmentKey = struct {
    format: vk.Format,
    depth_load_op: gpu.LoadOp,
    depth_store_op: gpu.StoreOp,
    stencil_load_op: gpu.LoadOp,
    stencil_store_op: gpu.StoreOp,
    read_only: bool,
};

pub const RenderPassKey = struct {
    colors: std.BoundedArray(ColorAttachmentKey, 8),
    depth_stencil: ?DepthStencilAttachmentKey,
    samples: vk.SampleCountFlags,

    pub fn init() RenderPassKey {
        return .{
            .colors = .{},
            .depth_stencil = null,
            .samples = .{ .@"1_bit" = true },
        };
    }
};

pub fn queryRenderPass(device: *Device, key: RenderPassKey) !vk.RenderPass {
    if (device.render_passes.get(key)) |pass| return pass;

    var attachments = std.BoundedArray(vk.AttachmentDescription, 8){};
    var color_refs = std.BoundedArray(vk.AttachmentReference, 8){};
    var resolve_refs = std.BoundedArray(vk.AttachmentReference, 8){};
    for (key.colors.slice()) |attach| {
        attachments.appendAssumeCapacity(.{
            .format = attach.format,
            .samples = key.samples,
            .load_op = getLoadOp(attach.load_op),
            .store_op = getStoreOp(attach.store_op),
            .stencil_load_op = .dont_care,
            .stencil_store_op = .dont_care,
            .initial_layout = .color_attachment_optimal,
            .final_layout = .color_attachment_optimal,
        });
        color_refs.appendAssumeCapacity(.{
            .attachment = @intCast(attachments.len - 1),
            .layout = .color_attachment_optimal,
        });

        if (attach.resolve_format) |resolve_format| {
            attachments.appendAssumeCapacity(.{
                .format = resolve_format,
                .samples = key.samples,
                .load_op = .dont_care,
                .store_op = .store,
                .stencil_load_op = .dont_care,
                .stencil_store_op = .dont_care,
                .initial_layout = .color_attachment_optimal,
                .final_layout = .color_attachment_optimal,
            });
            resolve_refs.appendAssumeCapacity(.{
                .attachment = @intCast(attachments.len - 1),
                .layout = .color_attachment_optimal,
            });
        }
    }

    const depth_stencil_ref = if (key.depth_stencil) |depth_stencil| blk: {
        const layout: vk.ImageLayout = if (depth_stencil.read_only)
            .depth_stencil_read_only_optimal
        else
            .depth_stencil_attachment_optimal;

        attachments.appendAssumeCapacity(.{
            .format = depth_stencil.format,
            .samples = key.samples,
            .load_op = getLoadOp(depth_stencil.depth_load_op),
            .store_op = getStoreOp(depth_stencil.depth_store_op),
            .stencil_load_op = getLoadOp(depth_stencil.stencil_load_op),
            .stencil_store_op = getStoreOp(depth_stencil.stencil_store_op),
            .initial_layout = layout,
            .final_layout = layout,
        });

        break :blk &vk.AttachmentReference{
            .attachment = @intCast(attachments.len - 1),
            .layout = layout,
        };
    } else null;

    const render_pass = try device.dispatch.createRenderPass(device.device, &vk.RenderPassCreateInfo{
        .attachment_count = @intCast(attachments.len),
        .p_attachments = attachments.slice().ptr,
        .subpass_count = 1,
        .p_subpasses = &[_]vk.SubpassDescription{
            .{
                .pipeline_bind_point = .graphics,
                .color_attachment_count = @intCast(color_refs.len),
                .p_color_attachments = color_refs.slice().ptr,
                .p_resolve_attachments = if (resolve_refs.len != 0) resolve_refs.slice().ptr else null,
                .p_depth_stencil_attachment = depth_stencil_ref,
            },
        },
    }, null);
    try device.render_passes.put(device.allocator, key, render_pass);

    // if (device.render_passes.count() > 1) {
    //     std.debug.assert(device.render_passes.count() == 2);
    //     var iter = device.render_passes.keyIterator();
    //     var k0: RenderPassKey = undefined;
    //     var k1: RenderPassKey = undefined;
    //     k0 = iter.next().?.*;
    //     k1 = iter.next().?.*;
    //     try std.testing.expectEqualDeep(k0, k1);
    // }

    return render_pass;
}

fn getLoadOp(op: gpu.LoadOp) vk.AttachmentLoadOp {
    return switch (op) {
        .load => .load,
        .clear => .clear,
        .undefined => unreachable,
    };
}

fn getStoreOp(op: gpu.StoreOp) vk.AttachmentStoreOp {
    return switch (op) {
        .store => .store,
        .discard => .dont_care,
        .undefined => unreachable,
    };
}
