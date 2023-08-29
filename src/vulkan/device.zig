const std = @import("std");
const builtin = @import("builtin");
const gpu = @import("gpu");
const vk = @import("vulkan");
const dusk = @import("../main.zig");
const utils = @import("../utils.zig");
const conv = @import("conv.zig");
const proc = @import("proc.zig");
const Adapter = @import("instance.zig").Adapter;
const Surface = @import("instance.zig").Surface;

pub const Device = struct {
    const max_frames_in_flight = 2;

    const FrameRes = struct {
        available: [max_frames_in_flight]vk.Semaphore,
        finished: [max_frames_in_flight]vk.Semaphore,
        fence: [max_frames_in_flight]vk.Fence,
        buffer: [max_frames_in_flight]CommandBuffer,
    };

    manager: utils.Manager(Device) = .{},
    adapter: *Adapter,
    device: vk.Device,
    cmd_pool: vk.CommandPool,
    render_passes: std.AutoHashMapUnmanaged(RenderPassKey, vk.RenderPass) = .{},
    framebuffer: vk.Framebuffer = .null_handle,
    frame_res: FrameRes,
    frame_index: u8 = 0,
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
                        var feature = vk.PhysicalDeviceShaderFloat16Int8FeaturesKHR{
                            .s_type = .physical_device_shader_float16_int8_features_khr,
                            .shader_float_16 = vk.TRUE,
                        };
                        features.p_next = @ptrCast(&feature);
                    },
                    else => std.log.warn("unimplement feature: {s}", .{@tagName(req_feature)}),
                }
            }
        }

        const layers = try queryLayers(adapter);
        defer dusk.allocator.free(layers);

        const extensions = try queryExtensions(adapter);
        defer dusk.allocator.free(extensions);

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

        const device = try proc.instance.createDevice(adapter.physical_device, &create_info, null);
        try proc.loadDevice(device);

        const cmd_pool = try proc.device.createCommandPool(
            device,
            &.{
                .queue_family_index = adapter.queue_family,
                .flags = .{ .reset_command_buffer_bit = true },
            },
            null,
        );

        var frame_res: FrameRes = undefined;
        for (0..max_frames_in_flight) |i| {
            frame_res.available[i] = try proc.device.createSemaphore(device, &.{}, null);
            frame_res.finished[i] = try proc.device.createSemaphore(device, &.{}, null);
            frame_res.fence[i] = try proc.device.createFence(device, &.{ .flags = .{ .signaled_bit = true } }, null);
            try proc.device.allocateCommandBuffers(device, &.{
                .command_pool = cmd_pool,
                .level = .primary,
                .command_buffer_count = max_frames_in_flight,
            }, @ptrCast(&frame_res.buffer[i]));
        }

        return .{
            .adapter = adapter,
            .device = device,
            .cmd_pool = cmd_pool,
            .frame_res = frame_res,
        };
    }

    pub fn deinit(device: *Device) void {
        proc.device.deviceWaitIdle(device.device) catch {};

        for (0..max_frames_in_flight) |i| {
            proc.device.destroySemaphore(device.device, device.frame_res.available[i], null);
            proc.device.destroySemaphore(device.device, device.frame_res.finished[i], null);
            proc.device.destroyFence(device.device, device.frame_res.fence[i], null);
        }

        var render_pass_iter = device.render_passes.valueIterator();
        while (render_pass_iter.next()) |pass| {
            proc.device.destroyRenderPass(device.device, pass.*, null);
        }
        device.render_passes.deinit(dusk.allocator);

        proc.device.destroyCommandPool(device.device, device.cmd_pool, null);
        proc.device.destroyFramebuffer(device.device, device.framebuffer, null);
        proc.device.destroyDevice(device.device, null);
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
        device.frame_index = (device.frame_index + 1) % max_frames_in_flight;
    }

    pub const required_layers = &[_][*:0]const u8{};
    pub const optional_layers = if (builtin.mode == .Debug)
        &[_][*:0]const u8{"VK_LAYER_KHRONOS_validation"}
    else
        &.{};

    fn queryLayers(adapter: *Adapter) ![]const [*:0]const u8 {
        var layers = try std.ArrayList([*:0]const u8).initCapacity(
            dusk.allocator,
            required_layers.len + optional_layers.len,
        );
        errdefer layers.deinit();

        var count: u32 = 0;
        _ = try proc.instance.enumerateDeviceLayerProperties(adapter.physical_device, &count, null);

        var available_layers = try dusk.allocator.alloc(vk.LayerProperties, count);
        defer dusk.allocator.free(available_layers);
        _ = try proc.instance.enumerateDeviceLayerProperties(adapter.physical_device, &count, available_layers.ptr);

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

    fn queryExtensions(adapter: *Adapter) ![]const [*:0]const u8 {
        var extensions = try std.ArrayList([*:0]const u8).initCapacity(
            dusk.allocator,
            required_extensions.len + optional_extensions.len,
        );
        errdefer extensions.deinit();

        var count: u32 = 0;
        _ = try proc.instance.enumerateDeviceExtensionProperties(adapter.physical_device, null, &count, null);

        var available_extensions = try dusk.allocator.alloc(vk.ExtensionProperties, count);
        defer dusk.allocator.free(available_extensions);
        _ = try proc.instance.enumerateDeviceExtensionProperties(adapter.physical_device, null, &count, available_extensions.ptr);

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
            var colors = std.BoundedArray(ColorAttachmentKey, 8){};
            for (&colors.buffer) |*color| {
                color.* = .{
                    .format = .undefined,
                    .load_op = .load,
                    .store_op = .store,
                    .resolve_format = null,
                };
            }

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
                .load_op = conv.vulkanLoadOp(attach.load_op),
                .store_op = conv.vulkanStoreOp(attach.store_op),
                .stencil_load_op = .dont_care,
                .stencil_store_op = .dont_care,
                .initial_layout = .undefined,
                .final_layout = .present_src_khr,
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
                    .initial_layout = .undefined,
                    .final_layout = .present_src_khr,
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
                .load_op = conv.vulkanLoadOp(depth_stencil.depth_load_op),
                .store_op = conv.vulkanStoreOp(depth_stencil.depth_store_op),
                .stencil_load_op = conv.vulkanLoadOp(depth_stencil.stencil_load_op),
                .stencil_store_op = conv.vulkanStoreOp(depth_stencil.stencil_store_op),
                .initial_layout = layout,
                .final_layout = layout,
            });

            break :blk &vk.AttachmentReference{
                .attachment = @intCast(attachments.len - 1),
                .layout = layout,
            };
        } else null;

        const render_pass = try proc.device.createRenderPass(device.device, &vk.RenderPassCreateInfo{
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
        try device.render_passes.put(dusk.allocator, key, render_pass);

        return render_pass;
    }
};

pub const SwapChain = struct {
    manager: utils.Manager(SwapChain) = .{},
    device: *Device,
    swapchain: vk.SwapchainKHR,
    textures: []Texture,
    texture_views: []TextureView,
    texture_index: u32 = 0,
    format: gpu.Texture.Format,

    pub fn init(device: *Device, surface: *Surface, desc: *const gpu.SwapChain.Descriptor) !SwapChain {
        const capabilities = try proc.instance.getPhysicalDeviceSurfaceCapabilitiesKHR(
            device.adapter.physical_device,
            surface.surface,
        );

        // TODO: query surface formats
        // TODO: query surface present modes

        const composite_alpha = blk: {
            const composite_alpha_flags = [_]vk.CompositeAlphaFlagsKHR{
                .{ .opaque_bit_khr = true },
                .{ .pre_multiplied_bit_khr = true },
                .{ .post_multiplied_bit_khr = true },
                .{ .inherit_bit_khr = true },
            };
            for (composite_alpha_flags) |flag| {
                if (@as(vk.Flags, @bitCast(flag)) & @as(vk.Flags, @bitCast(capabilities.supported_composite_alpha)) != 0) {
                    break :blk flag;
                }
            }
            break :blk vk.CompositeAlphaFlagsKHR{};
        };
        const image_count = @max(capabilities.min_image_count + 1, capabilities.max_image_count);
        const format = conv.vulkanFormat(desc.format);
        const extent = vk.Extent2D{
            .width = std.math.clamp(
                desc.width,
                capabilities.min_image_extent.width,
                capabilities.max_image_extent.width,
            ),
            .height = std.math.clamp(
                desc.height,
                capabilities.min_image_extent.height,
                capabilities.max_image_extent.height,
            ),
        };
        const image_usage = vk.ImageUsageFlags{
            .transfer_src_bit = desc.usage.copy_src,
            .transfer_dst_bit = desc.usage.copy_dst,
            .sampled_bit = desc.usage.texture_binding,
            .storage_bit = desc.usage.storage_binding,
            .color_attachment_bit = desc.usage.render_attachment,
            .transient_attachment_bit = desc.usage.transient_attachment,
            .depth_stencil_attachment_bit = switch (desc.format) {
                .stencil8,
                .depth16_unorm,
                .depth24_plus,
                .depth24_plus_stencil8,
                .depth32_float,
                .depth32_float_stencil8,
                => true,
                else => false,
            },
        };
        const present_mode = switch (desc.present_mode) {
            .immediate => vk.PresentModeKHR.immediate_khr,
            .fifo => vk.PresentModeKHR.fifo_khr,
            .mailbox => vk.PresentModeKHR.mailbox_khr,
        };

        const swapchain = try proc.device.createSwapchainKHR(device.device, &.{
            .surface = surface.surface,
            .min_image_count = image_count,
            .image_format = format,
            .image_color_space = .srgb_nonlinear_khr,
            .image_extent = extent,
            .image_array_layers = 1,
            .image_usage = image_usage,
            .image_sharing_mode = .exclusive,
            .pre_transform = .{ .identity_bit_khr = true },
            .composite_alpha = composite_alpha,
            .present_mode = present_mode,
            .clipped = vk.FALSE,
        }, null);

        var images_len: u32 = 0;
        _ = try proc.device.getSwapchainImagesKHR(device.device, swapchain, &images_len, null);
        var images = try dusk.allocator.alloc(vk.Image, images_len);
        defer dusk.allocator.free(images);
        _ = try proc.device.getSwapchainImagesKHR(device.device, swapchain, &images_len, images.ptr);

        const textures = try dusk.allocator.alloc(Texture, images_len);
        errdefer dusk.allocator.free(textures);
        const texture_views = try dusk.allocator.alloc(TextureView, images_len);
        errdefer dusk.allocator.free(texture_views);

        for (textures, texture_views, 0..) |*texture, *view, i| {
            texture.* = try Texture.init(device, images[i], extent);
            view.* = try texture.createView(&.{
                .format = desc.format,
                .dimension = .dimension_2d,
            });
        }

        return .{
            .device = device,
            .swapchain = swapchain,
            .format = desc.format,
            .textures = textures,
            .texture_views = texture_views,
        };
    }

    pub fn deinit(swapchain: *SwapChain) void {
        proc.device.destroySwapchainKHR(swapchain.device.device, swapchain.swapchain, null);
        for (swapchain.texture_views) |*view| view.manager.release();
        dusk.allocator.free(swapchain.textures);
        dusk.allocator.free(swapchain.texture_views);
    }

    pub fn getCurrentTextureView(swapchain: *SwapChain) !*TextureView {
        const semaphore = swapchain.device.frame_res.available[swapchain.device.frame_index];
        const fence = swapchain.device.frame_res.fence[swapchain.device.frame_index];
        const buffer = swapchain.device.frame_res.buffer[swapchain.device.frame_index];

        _ = try proc.device.waitForFences(
            swapchain.device.device,
            1,
            &[_]vk.Fence{fence},
            vk.TRUE,
            std.math.maxInt(u64),
        );
        try proc.device.resetFences(swapchain.device.device, 1, &[_]vk.Fence{fence});
        try proc.device.resetCommandBuffer(buffer.buffer, .{});

        const result = try proc.device.acquireNextImageKHR(
            swapchain.device.device,
            swapchain.swapchain,
            std.math.maxInt(u64),
            semaphore,
            .null_handle,
        );
        swapchain.texture_index = result.image_index;

        const view = &swapchain.texture_views[swapchain.texture_index];
        view.manager.reference();

        return view;
    }

    pub fn present(swapchain: *SwapChain) !void {
        const queue = try swapchain.device.getQueue();
        _ = try proc.device.queuePresentKHR(queue.queue, &.{
            .wait_semaphore_count = 1,
            .p_wait_semaphores = &[_]vk.Semaphore{swapchain.device.frame_res.finished[swapchain.device.frame_index]},
            .swapchain_count = 1,
            .p_swapchains = &[_]vk.SwapchainKHR{swapchain.swapchain},
            .p_image_indices = &[_]u32{swapchain.texture_index},
        });
    }
};

pub const Texture = struct {
    manager: utils.Manager(Texture) = .{},
    device: *Device,
    extent: vk.Extent2D,
    image: vk.Image,

    pub fn init(device: *Device, image: vk.Image, extent: vk.Extent2D) !Texture {
        return .{
            .device = device,
            .extent = extent,
            .image = image,
        };
    }

    pub fn deinit(texture: *Texture) void {
        _ = texture;
    }

    pub fn createView(texture: *Texture, desc: *const gpu.TextureView.Descriptor) !TextureView {
        return TextureView.init(texture, desc, texture.extent);
    }
};

pub const TextureView = struct {
    manager: utils.Manager(TextureView) = .{},
    device: *Device,
    view: vk.ImageView,
    format: vk.Format,
    extent: vk.Extent2D,

    pub fn init(texture: *Texture, desc: *const gpu.TextureView.Descriptor, extent: vk.Extent2D) !TextureView {
        const format = conv.vulkanFormat(desc.format);
        const aspect: vk.ImageAspectFlags = blk: {
            if (desc.aspect == .all) {
                break :blk switch (desc.format) {
                    .stencil8 => .{ .stencil_bit = true },
                    .depth16_unorm, .depth24_plus, .depth32_float => .{ .depth_bit = true },
                    .depth24_plus_stencil8, .depth32_float_stencil8 => .{ .depth_bit = true, .stencil_bit = true },
                    .r8_bg8_biplanar420_unorm => .{ .plane_0_bit = true, .plane_1_bit = true },
                    else => .{ .color_bit = true },
                };
            }

            break :blk .{
                .stencil_bit = desc.aspect == .stencil_only,
                .depth_bit = desc.aspect == .depth_only,
                .plane_0_bit = desc.aspect == .plane0_only,
                .plane_1_bit = desc.aspect == .plane1_only,
            };
        };

        const view = try proc.device.createImageView(texture.device.device, &.{
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
            .device = texture.device,
            .view = view,
            .format = format,
            .extent = extent,
        };
    }

    pub fn deinit(view: *TextureView) void {
        proc.device.destroyImageView(view.device.device, view.view, null);
    }
};

pub const RenderPipeline = struct {
    manager: utils.Manager(RenderPipeline) = .{},
    device: *Device,
    pipeline: vk.Pipeline,

    pub fn init(device: *Device, desc: *const gpu.RenderPipeline.Descriptor) !RenderPipeline {
        var stages = std.BoundedArray(vk.PipelineShaderStageCreateInfo, 2){};

        const vertex_shader: *ShaderModule = @ptrCast(@alignCast(desc.vertex.module));
        stages.appendAssumeCapacity(.{
            .stage = .{ .vertex_bit = true },
            .module = vertex_shader.shader_module,
            .p_name = desc.vertex.entry_point,
            .p_specialization_info = null,
        });

        if (desc.fragment) |frag| {
            const frag_shader: *ShaderModule = @ptrCast(@alignCast(frag.module));
            stages.appendAssumeCapacity(.{
                .stage = .{ .fragment_bit = true },
                .module = frag_shader.shader_module,
                .p_name = frag.entry_point,
                .p_specialization_info = null,
            });
        }

        var vertex_bindings = try std.ArrayList(vk.VertexInputBindingDescription).initCapacity(dusk.allocator, desc.vertex.buffer_count);
        var vertex_attrs = try std.ArrayList(vk.VertexInputAttributeDescription).initCapacity(dusk.allocator, desc.vertex.buffer_count);
        defer {
            vertex_bindings.deinit();
            vertex_attrs.deinit();
        }

        for (0..desc.vertex.buffer_count) |i| {
            const buf = desc.vertex.buffers.?[i];
            const input_rate: vk.VertexInputRate = switch (buf.step_mode) {
                .vertex => .vertex,
                .instance => .instance,
                .vertex_buffer_not_used => unreachable,
            };

            vertex_bindings.appendAssumeCapacity(.{
                .binding = @intCast(i),
                .stride = @intCast(buf.array_stride),
                .input_rate = input_rate,
            });

            for (buf.attributes.?[0..buf.attribute_count]) |attr| {
                try vertex_attrs.append(.{
                    .location = attr.shader_location,
                    .binding = @intCast(i),
                    .format = conv.vulkanVertexFormat(attr.format),
                    .offset = @intCast(attr.offset),
                });
            }
        }

        const vertex_input = vk.PipelineVertexInputStateCreateInfo{
            .vertex_binding_description_count = @intCast(vertex_bindings.items.len),
            .p_vertex_binding_descriptions = vertex_bindings.items.ptr,
            .vertex_attribute_description_count = @intCast(vertex_attrs.items.len),
            .p_vertex_attribute_descriptions = vertex_attrs.items.ptr,
        };

        const input_assembly = vk.PipelineInputAssemblyStateCreateInfo{
            .topology = switch (desc.primitive.topology) {
                .point_list => .point_list,
                .line_list => .line_list,
                .line_strip => .line_strip,
                .triangle_list => .triangle_list,
                .triangle_strip => .triangle_strip,
            },
            .primitive_restart_enable = @intFromBool(desc.primitive.strip_index_format != .undefined),
        };

        const viewport = vk.PipelineViewportStateCreateInfo{
            .viewport_count = 1,
            .scissor_count = 1,
        };

        const rasterization = vk.PipelineRasterizationStateCreateInfo{
            .depth_clamp_enable = vk.FALSE,
            .rasterizer_discard_enable = vk.FALSE,
            .polygon_mode = .fill,
            .cull_mode = .{
                .front_bit = desc.primitive.cull_mode == .front,
                .back_bit = desc.primitive.cull_mode == .back,
            },
            .front_face = switch (desc.primitive.front_face) {
                .ccw => vk.FrontFace.counter_clockwise,
                .cw => vk.FrontFace.clockwise,
            },
            .depth_bias_enable = isDepthBiasEnabled(desc.depth_stencil),
            .depth_bias_constant_factor = conv.vulkanDepthBias(desc.depth_stencil),
            .depth_bias_clamp = conv.vulkanDepthBiasClamp(desc.depth_stencil),
            .depth_bias_slope_factor = conv.vulkanDepthBiasSlopeScale(desc.depth_stencil),
            .line_width = 1,
        };

        const sample_count = conv.vulkanSampleCount(desc.multisample.count);
        const multisample = vk.PipelineMultisampleStateCreateInfo{
            .rasterization_samples = sample_count,
            .sample_shading_enable = vk.FALSE,
            .min_sample_shading = 0,
            .p_sample_mask = &[_]u32{desc.multisample.mask},
            .alpha_to_coverage_enable = @intFromEnum(desc.multisample.alpha_to_coverage_enabled),
            .alpha_to_one_enable = vk.FALSE,
        };

        var pipeline_layout = if (desc.layout) |layout|
            @as(*PipelineLayout, @ptrCast(@alignCast(layout))).*
        else
            try PipelineLayout.init(device, &.{});
        defer pipeline_layout.deinit();

        var blend_attachments: []vk.PipelineColorBlendAttachmentState = &.{};
        defer if (desc.fragment != null) dusk.allocator.free(blend_attachments);

        var rp_key = Device.RenderPassKey.init();
        rp_key.samples = sample_count;

        if (desc.fragment) |frag| {
            blend_attachments = try dusk.allocator.alloc(vk.PipelineColorBlendAttachmentState, frag.target_count);

            for (frag.targets.?[0..frag.target_count], 0..) |target, i| {
                const blend = target.blend orelse &gpu.BlendState{};
                blend_attachments[i] = .{
                    .blend_enable = vk.FALSE,
                    .src_color_blend_factor = conv.vulkanBlendFactor(blend.color.src_factor),
                    .dst_color_blend_factor = conv.vulkanBlendFactor(blend.color.dst_factor),
                    .color_blend_op = conv.vulkanBlendOp(blend.color.operation),
                    .src_alpha_blend_factor = conv.vulkanBlendFactor(blend.alpha.src_factor),
                    .dst_alpha_blend_factor = conv.vulkanBlendFactor(blend.alpha.dst_factor),
                    .alpha_blend_op = conv.vulkanBlendOp(blend.alpha.operation),
                    .color_write_mask = .{
                        .r_bit = target.write_mask.red,
                        .g_bit = target.write_mask.green,
                        .b_bit = target.write_mask.blue,
                        .a_bit = target.write_mask.alpha,
                    },
                };
                rp_key.colors.appendAssumeCapacity(.{
                    .format = conv.vulkanFormat(target.format),
                    .load_op = .clear,
                    .store_op = .store,
                    .resolve_format = null,
                });
            }
        }

        var depth_stencil_state = vk.PipelineDepthStencilStateCreateInfo{
            .depth_test_enable = vk.FALSE,
            .depth_write_enable = vk.FALSE,
            .depth_compare_op = .never,
            .depth_bounds_test_enable = vk.FALSE,
            .stencil_test_enable = vk.FALSE,
            .front = .{
                .fail_op = .keep,
                .depth_fail_op = .keep,
                .pass_op = .keep,
                .compare_op = .never,
                .compare_mask = 0,
                .write_mask = 0,
                .reference = 0,
            },
            .back = .{
                .fail_op = .keep,
                .depth_fail_op = .keep,
                .pass_op = .keep,
                .compare_op = .never,
                .compare_mask = 0,
                .write_mask = 0,
                .reference = 0,
            },
            .min_depth_bounds = 0,
            .max_depth_bounds = 1,
        };

        if (desc.depth_stencil) |ds| {
            depth_stencil_state.depth_test_enable = @intFromBool(ds.depth_compare == .always and ds.depth_write_enabled == .true);
            depth_stencil_state.depth_write_enable = @intFromBool(ds.depth_write_enabled == .true);
            depth_stencil_state.depth_compare_op = conv.vulkanCompareOp(ds.depth_compare);
            depth_stencil_state.stencil_test_enable = @intFromBool(ds.stencil_read_mask != 0 or ds.stencil_write_mask != 0);
            depth_stencil_state.front = .{
                .fail_op = conv.vulkanStencilOp(ds.stencil_front.fail_op),
                .depth_fail_op = conv.vulkanStencilOp(ds.stencil_front.depth_fail_op),
                .pass_op = conv.vulkanStencilOp(ds.stencil_front.pass_op),
                .compare_op = conv.vulkanCompareOp(ds.stencil_front.compare),
                .compare_mask = ds.stencil_read_mask,
                .write_mask = ds.stencil_write_mask,
                .reference = 0,
            };
            depth_stencil_state.back = .{
                .fail_op = conv.vulkanStencilOp(ds.stencil_back.fail_op),
                .depth_fail_op = conv.vulkanStencilOp(ds.stencil_back.depth_fail_op),
                .pass_op = conv.vulkanStencilOp(ds.stencil_back.pass_op),
                .compare_op = conv.vulkanCompareOp(ds.stencil_back.compare),
                .compare_mask = ds.stencil_read_mask,
                .write_mask = ds.stencil_write_mask,
                .reference = 0,
            };

            rp_key.depth_stencil = .{
                .format = conv.vulkanFormat(ds.format),
                .depth_load_op = .load,
                .depth_store_op = .store,
                .stencil_load_op = .load,
                .stencil_store_op = .store,
                .read_only = ds.depth_write_enabled == .false and ds.stencil_write_mask == 0,
            };
        }

        const color_blend = vk.PipelineColorBlendStateCreateInfo{
            .logic_op_enable = vk.FALSE,
            .logic_op = .clear,
            .attachment_count = @intCast(blend_attachments.len),
            .p_attachments = blend_attachments.ptr,
            .blend_constants = .{ 0, 0, 0, 0 },
        };

        const dynamic_states = [_]vk.DynamicState{
            .viewport,        .scissor,      .line_width,
            .blend_constants, .depth_bounds, .stencil_reference,
        };
        const dynamic = vk.PipelineDynamicStateCreateInfo{
            .dynamic_state_count = dynamic_states.len,
            .p_dynamic_states = &dynamic_states,
        };

        const render_pass = try device.queryRenderPass(rp_key);

        var pipeline: vk.Pipeline = undefined;
        _ = try proc.device.createGraphicsPipelines(device.device, .null_handle, 1, &[_]vk.GraphicsPipelineCreateInfo{.{
            .stage_count = stages.len,
            .p_stages = stages.slice().ptr,
            .p_vertex_input_state = &vertex_input,
            .p_input_assembly_state = &input_assembly,
            .p_viewport_state = &viewport,
            .p_rasterization_state = &rasterization,
            .p_multisample_state = &multisample,
            .p_depth_stencil_state = &depth_stencil_state,
            .p_color_blend_state = &color_blend,
            .p_dynamic_state = &dynamic,
            .layout = pipeline_layout.layout,
            .render_pass = render_pass,
            .subpass = 0,
            .base_pipeline_index = -1,
        }}, null, @ptrCast(&pipeline));

        return .{
            .device = device,
            .pipeline = pipeline,
        };
    }

    pub fn deinit(render_pipeline: *RenderPipeline) void {
        // TODO(HACK): this should be removed. a DeletionQueue maybe?
        if (render_pipeline.device.queue) |queue| {
            proc.device.queueWaitIdle(queue.queue) catch {};
        }

        proc.device.destroyPipeline(render_pipeline.device.device, render_pipeline.pipeline, null);
    }

    fn isDepthBiasEnabled(ds: ?*const gpu.DepthStencilState) vk.Bool32 {
        if (ds == null) return vk.FALSE;
        return @intFromBool(ds.?.depth_bias != 0 or ds.?.depth_bias_slope_scale != 0);
    }
};

pub const PipelineLayout = struct {
    manager: utils.Manager(PipelineLayout) = .{},
    device: *Device,
    layout: vk.PipelineLayout,

    pub fn init(device: *Device, descriptor: *const gpu.PipelineLayout.Descriptor) !PipelineLayout {
        const groups = try dusk.allocator.alloc(vk.DescriptorSetLayout, descriptor.bind_group_layout_count);
        defer dusk.allocator.free(groups);
        for (groups, 0..) |*layout, i| {
            layout.* = @as(*BindGroupLayout, @ptrCast(@alignCast(descriptor.bind_group_layouts.?[i]))).layout;
        }

        const layout = try proc.device.createPipelineLayout(device.device, &.{
            .set_layout_count = @as(u32, @intCast(groups.len)),
            .p_set_layouts = groups.ptr,
        }, null);

        return .{
            .device = device,
            .layout = layout,
        };
    }

    pub fn deinit(layout: *PipelineLayout) void {
        proc.device.destroyPipelineLayout(layout.device.device, layout.layout, null);
    }
};

pub const RenderPassEncoder = struct {
    manager: utils.Manager(RenderPassEncoder) = .{},
    device: *Device,
    render_pass: vk.RenderPass,
    extent: vk.Extent2D,
    clear_values: []const vk.ClearValue,

    pub fn init(device: *Device, descriptor: *const gpu.RenderPassDescriptor) !RenderPassEncoder {
        const depth_stencil_attachment_count = @intFromBool(descriptor.depth_stencil_attachment != null);
        const attachment_count = descriptor.color_attachment_count + depth_stencil_attachment_count;

        var image_views = try std.ArrayList(vk.ImageView).initCapacity(dusk.allocator, attachment_count);
        defer image_views.deinit();

        var clear_values = std.ArrayList(vk.ClearValue).init(dusk.allocator);
        errdefer clear_values.deinit();

        var rp_key = Device.RenderPassKey.init();
        var extent: ?vk.Extent2D = null;

        for (descriptor.color_attachments.?[0..descriptor.color_attachment_count]) |attach| {
            const view: *TextureView = @ptrCast(@alignCast(attach.view.?));
            const resolve_view: ?*TextureView = @ptrCast(@alignCast(attach.resolve_target));
            image_views.appendAssumeCapacity(view.view);

            rp_key.colors.appendAssumeCapacity(.{
                .format = view.format,
                .load_op = attach.load_op,
                .store_op = attach.store_op,
                .resolve_format = if (resolve_view) |rv| rv.format else null,
            });

            if (attach.load_op == .clear) {
                try clear_values.append(.{
                    .color = .{
                        .float_32 = [4]f32{
                            @floatCast(attach.clear_value.r),
                            @floatCast(attach.clear_value.g),
                            @floatCast(attach.clear_value.b),
                            @floatCast(attach.clear_value.a),
                        },
                    },
                });
            }

            if (extent == null) {
                extent = view.extent;
            }
        }

        if (descriptor.depth_stencil_attachment) |attach| {
            const view: *TextureView = @ptrCast(@alignCast(attach.view));
            image_views.appendAssumeCapacity(view.view);

            rp_key.depth_stencil = .{
                .format = view.format,
                .depth_load_op = attach.depth_load_op,
                .depth_store_op = attach.depth_store_op,
                .stencil_load_op = attach.stencil_load_op,
                .stencil_store_op = attach.stencil_store_op,
                .read_only = attach.depth_read_only == .true or attach.stencil_read_only == .true,
            };

            if (attach.stencil_load_op == .clear) {
                try clear_values.append(.{
                    .depth_stencil = .{
                        .depth = attach.depth_clear_value,
                        .stencil = attach.stencil_clear_value,
                    },
                });
            }
        }

        const render_pass = try device.queryRenderPass(rp_key);

        if (device.framebuffer != .null_handle) {
            proc.device.destroyFramebuffer(device.device, device.framebuffer, null);
        }

        device.framebuffer = try proc.device.createFramebuffer(
            device.device,
            &.{
                .render_pass = render_pass,
                .attachment_count = @as(u32, @intCast(image_views.items.len)),
                .p_attachments = image_views.items.ptr,
                .width = extent.?.width,
                .height = extent.?.height,
                .layers = 1,
            },
            null,
        );

        return .{
            .device = device,
            .render_pass = render_pass,
            .extent = extent.?,
            .clear_values = try clear_values.toOwnedSlice(),
        };
    }

    pub fn deinit(encoder: *RenderPassEncoder) void {
        dusk.allocator.free(encoder.clear_values);
    }

    pub fn setPipeline(encoder: *RenderPassEncoder, pipeline: *RenderPipeline) !void {
        const rect = vk.Rect2D{
            .offset = .{ .x = 0, .y = 0 },
            .extent = encoder.extent,
        };

        const cmd_buffer = encoder.device.frame_res.buffer[encoder.device.frame_index];
        proc.device.cmdBeginRenderPass(cmd_buffer.buffer, &vk.RenderPassBeginInfo{
            .render_pass = encoder.render_pass,
            .framebuffer = encoder.device.framebuffer,
            .render_area = rect,
            .clear_value_count = @as(u32, @intCast(encoder.clear_values.len)),
            .p_clear_values = encoder.clear_values.ptr,
        }, .@"inline");
        proc.device.cmdBindPipeline(
            cmd_buffer.buffer,
            .graphics,
            pipeline.pipeline,
        );
        proc.device.cmdSetViewport(
            cmd_buffer.buffer,
            0,
            1,
            @as(*const [1]vk.Viewport, &vk.Viewport{
                .x = 0,
                .y = @as(f32, @floatFromInt(encoder.extent.height)),
                .width = @as(f32, @floatFromInt(encoder.extent.width)),
                .height = -@as(f32, @floatFromInt(encoder.extent.height)),
                .min_depth = 0,
                .max_depth = 1,
            }),
        );
        proc.device.cmdSetScissor(cmd_buffer.buffer, 0, 1, @as(*const [1]vk.Rect2D, &rect));
    }

    pub fn draw(encoder: *RenderPassEncoder, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void {
        const cmd_buffer = encoder.device.frame_res.buffer[encoder.device.frame_index];
        proc.device.cmdDraw(cmd_buffer.buffer, vertex_count, instance_count, first_vertex, first_instance);
    }

    pub fn end(encoder: *RenderPassEncoder) void {
        const cmd_buffer = encoder.device.frame_res.buffer[encoder.device.frame_index];
        proc.device.cmdEndRenderPass(cmd_buffer.buffer);
    }
};

pub const CommandEncoder = struct {
    manager: utils.Manager(CommandEncoder) = .{},
    device: *Device,

    pub fn init(device: *Device, desc: ?*const gpu.CommandEncoder.Descriptor) !CommandEncoder {
        _ = desc;
        const cmd_buffer = device.frame_res.buffer[device.frame_index];
        try proc.device.beginCommandBuffer(cmd_buffer.buffer, &.{});
        return .{ .device = device };
    }

    pub fn deinit(cmd_encoder: *CommandEncoder) void {
        _ = cmd_encoder;
    }

    pub fn beginRenderPass(cmd_encoder: *CommandEncoder, desc: *const gpu.RenderPassDescriptor) !RenderPassEncoder {
        return RenderPassEncoder.init(cmd_encoder.device, desc);
    }

    pub fn finish(cmd_encoder: *CommandEncoder, desc: *const gpu.CommandBuffer.Descriptor) !*CommandBuffer {
        _ = desc;
        const cmd_buffer = &cmd_encoder.device.frame_res.buffer[cmd_encoder.device.frame_index];
        try proc.device.endCommandBuffer(cmd_buffer.buffer);
        return cmd_buffer;
    }
};

pub const CommandBuffer = struct {
    manager: utils.Manager(CommandBuffer) = .{},
    buffer: vk.CommandBuffer,

    pub fn deinit(cmd_buffer: *CommandBuffer) void {
        _ = cmd_buffer;
    }
};

pub const Queue = struct {
    manager: utils.Manager(Queue) = .{},
    device: *Device,
    queue: vk.Queue,

    pub fn init(device: *Device) !Queue {
        const queue = proc.device.getDeviceQueue(device.device, device.adapter.queue_family, 0);

        return .{
            .device = device,
            .queue = queue,
        };
    }

    pub fn deinit(queue: *Queue) void {
        _ = queue;
    }

    pub fn submit(queue: *Queue, commands: []const *CommandBuffer) !void {
        const dst_stage_masks = vk.PipelineStageFlags{ .all_commands_bit = true };
        const submits = try dusk.allocator.alloc(vk.SubmitInfo, commands.len);
        defer dusk.allocator.free(submits);

        for (commands, 0..) |buf, i| {
            submits[i] = .{
                .command_buffer_count = 1,
                .p_command_buffers = &[_]vk.CommandBuffer{buf.buffer},
                .wait_semaphore_count = 1,
                .p_wait_semaphores = &[_]vk.Semaphore{queue.device.frame_res.available[queue.device.frame_index]},
                .p_wait_dst_stage_mask = @ptrCast(&dst_stage_masks),
                .signal_semaphore_count = 1,
                .p_signal_semaphores = &[_]vk.Semaphore{queue.device.frame_res.finished[queue.device.frame_index]},
            };
        }

        try proc.device.queueSubmit(
            queue.queue,
            @intCast(submits.len),
            submits.ptr,
            queue.device.frame_res.fence[queue.device.frame_index],
        );
    }
};

pub const ShaderModule = struct {
    manager: utils.Manager(ShaderModule) = .{},
    shader_module: vk.ShaderModule,
    device: *Device,

    pub fn init(device: *Device, code: []const u8) !ShaderModule {
        const shader_module = try proc.device.createShaderModule(
            device.device,
            &vk.ShaderModuleCreateInfo{
                .code_size = code.len,
                .p_code = @ptrCast(@alignCast(code.ptr)),
            },
            null,
        );

        return .{
            .device = device,
            .shader_module = shader_module,
        };
    }

    pub fn deinit(shader_module: *ShaderModule) void {
        proc.device.destroyShaderModule(
            shader_module.device.device,
            shader_module.shader_module,
            null,
        );
    }
};

pub const BindGroupLayout = struct {
    manager: utils.Manager(BindGroupLayout) = .{},
    layout: vk.DescriptorSetLayout,

    pub fn deinit(layout: BindGroupLayout) void {
        _ = layout;
    }
};
