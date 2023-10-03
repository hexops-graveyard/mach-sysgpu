const std = @import("std");
const wgpu = @import("webgpu");
const dusk = @import("main.zig");
const utils = @import("utils.zig");
const conv = @import("wgpu/conv.zig");
const shader = @import("shader.zig");
const dgpu = dusk.dgpu;

var allocator: std.mem.Allocator = undefined;

const log = std.log.scoped(.webgpu);

pub const InitOptions = struct {};

pub fn init(alloc: std.mem.Allocator, options: InitOptions) !void {
    _ = options;
    allocator = alloc;
    try wgpu.Impl.init(alloc, .{});
}

pub const Instance = struct {
    manager: utils.Manager(Instance) = .{},
    wgpu_instance: *wgpu.Instance,

    pub fn init(descriptor: dgpu.Instance.Descriptor) !*Instance {
        _ = descriptor;

        var instance = try allocator.create(Instance);
        instance.* = .{ .wgpu_instance = wgpu.createInstance(null) orelse unreachable };
        return instance;
    }

    pub fn deinit(instance: *Instance) void {
        instance.wgpu_instance.release();
        allocator.destroy(instance);
    }

    pub const RequestAdapterResponse = struct {
        status: wgpu.RequestAdapterStatus,
        adapter: ?*wgpu.Adapter,
        message: ?[*:0]const u8,
    };

    pub inline fn requestAdapterCallback(
        context: *RequestAdapterResponse,
        status: wgpu.RequestAdapterStatus,
        adapter: ?*wgpu.Adapter,
        message: ?[*:0]const u8,
    ) void {
        context.* = RequestAdapterResponse{
            .status = status,
            .adapter = adapter,
            .message = message,
        };
    }

    pub fn createAdapter(instance: *Instance, descriptor: dgpu.Adapter.Descriptor) !*Adapter {
        var response: RequestAdapterResponse = undefined;

        const compatible_surface = if (descriptor.compatible_surface) |surface|
            @as(*Surface, @ptrCast(@alignCast(surface))).wgpu_surface
        else
            null;

        instance.wgpu_instance.requestAdapter(&.{
            .compatible_surface = compatible_surface,
            .power_preference = conv.toWGPUPowerPreference(descriptor.power_preference),
            .backend_type = conv.toWGPUBackendType(descriptor.backend_type),
            .force_fallback_adapter = wgpu.Bool32.from(descriptor.force_fallback_adapter),
            .compatibility_mode = wgpu.Bool32.from(descriptor.compatibility_mode),
        }, &response, requestAdapterCallback);

        if (response.status != .success) {
            log.err("failed to create GPU adapter: {?s}", .{response.message});
            log.info("-> maybe try MACH_GPU_BACKEND=opengl ?", .{});
            unreachable;
        }

        var adapter = try allocator.create(Adapter);
        adapter.* = .{ .wgpu_adapter = response.adapter.? };
        return adapter;
    }

    pub fn createSurface(instance: *Instance, descriptor: dgpu.Surface.Descriptor) !*Surface {
        const next_in_chain: wgpu.Surface.Descriptor.NextInChain = switch (descriptor.handle) {
            .android_native_window => |h| .{ .from_android_native_window = &.{ .window = h } },
            .canvas_html_selector => |h| .{ .from_canvas_html_selector = &.{ .selector = h } },
            .metal_layer => |h| .{ .from_metal_layer = &.{ .layer = h } },
            .wayland_surface => |h| .{ .from_wayland_surface = &.{ .display = h.display, .surface = h.surface } },
            .windows_core_window => |h| .{ .from_windows_core_window = &.{ .core_window = h } },
            .windows_hwnd => |h| .{ .from_windows_hwnd = &.{ .hinstance = h.hinstance, .hwnd = h.hwnd } },
            .windows_swap_chain_panel => |h| .{ .from_windows_swap_chain_panel = &.{ .swap_chain_panel = h } },
            .xlib_window => |h| .{ .from_xlib_window = &.{ .display = h.display, .window = h.window } },
        };

        const wgpu_surface = instance.wgpu_instance.createSurface(&.{
            .next_in_chain = next_in_chain,
            .label = if (descriptor.label) |l| l.ptr else null,
        });

        var surface = try allocator.create(Surface);
        surface.* = .{ .wgpu_surface = wgpu_surface };
        return surface;
    }
};

pub const Adapter = struct {
    manager: utils.Manager(Adapter) = .{},
    wgpu_adapter: *wgpu.Adapter,

    pub fn deinit(adapter: *Adapter) void {
        allocator.destroy(adapter);
    }

    pub fn createDevice(adapter: *Adapter, descriptor: dgpu.Device.Descriptor) !*Device {
        var wgpu_features = try std.ArrayList(wgpu.FeatureName).initCapacity(allocator, descriptor.required_features.len);
        defer wgpu_features.deinit();

        for (descriptor.required_features) |feature| {
            wgpu_features.appendAssumeCapacity(conv.toWGPUFeatureName(feature));
        }

        var device = try allocator.create(Device);
        device.* = .{
            .wgpu_device = undefined,
            .lost_cb = descriptor.device_lost_callback,
            .lost_cb_userdata = descriptor.device_lost_userdata,
        };

        const wgpu_device = adapter.wgpu_adapter.createDevice(&.{
            .label = if (descriptor.label) |l| l.ptr else null,
            .required_features_count = wgpu_features.items.len,
            .required_features = wgpu_features.items.ptr,
            .required_limits = &.{ .limits = conv.toWGPULimits(descriptor.required_limits) },
            .default_queue = .{ .label = if (descriptor.default_queue.label) |l| l.ptr else null },
            .device_lost_callback = Device.lostCallback,
            .device_lost_userdata = device,
        });

        wgpu_device.?.setUncapturedErrorCallback({}, Device.errCallback);

        device.wgpu_device = wgpu_device.?;

        return device;
    }

    pub fn getProperties(adapter: *Adapter) dgpu.Adapter.Properties {
        var props = std.mem.zeroes(wgpu.Adapter.Properties);
        adapter.wgpu_adapter.getProperties(&props);
        return .{
            .vendor_id = props.vendor_id,
            .vendor_name = std.mem.span(props.vendor_name),
            .architecture = std.mem.span(props.architecture),
            .device_id = props.device_id,
            .name = std.mem.span(props.name),
            .driver_description = std.mem.span(props.driver_description),
            .adapter_type = conv.fromWGPUAdapterType(props.adapter_type),
            .backend_type = conv.fromWGPUBackendType(props.backend_type),
            .compatibility_mode = conv.fromWGPUBool(props.compatibility_mode),
        };
    }
};

pub const Surface = struct {
    manager: utils.Manager(Surface) = .{},
    wgpu_surface: *wgpu.Surface,

    pub fn deinit(surface: *Surface) void {
        surface.wgpu_surface.release();
        allocator.destroy(surface);
    }
};

pub const Device = struct {
    manager: utils.Manager(Device) = .{},
    wgpu_device: *wgpu.Device,
    queue: ?*Queue = null,
    log_cb: ?dgpu.LoggingCallback = null,
    log_cb_userdata: ?*anyopaque = null,
    err_cb: ?dgpu.ErrorCallback = null,
    err_cb_userdata: ?*anyopaque = null,
    lost_cb: ?dgpu.Device.LostCallback = null,
    lost_cb_userdata: ?*anyopaque = null,

    pub fn deinit(device: *Device) void {
        device.wgpu_device.release();
        allocator.destroy(device);
    }

    fn lostCallback(
        wgpu_reason: wgpu.Device.LostReason,
        msg: [*:0]const u8,
        device_opaque: ?*anyopaque,
    ) callconv(.C) void {
        const device: *Device = @ptrCast(@alignCast(device_opaque));
        const reason: dgpu.Device.LostReason = switch (wgpu_reason) {
            .undefined => .undefined,
            .destroyed => .destroyed,
        };
        if (device.lost_cb) |lostCb| {
            lostCb(reason, std.mem.span(msg), device.lost_cb_userdata);
        }
    }

    inline fn errCallback(
        _: void,
        _: wgpu.ErrorType,
        msg: [*:0]const u8,
    ) void {
        std.debug.print("MSG: {s}\n", .{msg});
    }

    pub fn createBindGroup(device: *Device, descriptor: dgpu.BindGroup.Descriptor) !*BindGroup {
        const layout: *BindGroupLayout = @ptrCast(@alignCast(descriptor.layout));

        var wgpu_entries = try std.ArrayList(wgpu.BindGroup.Entry).initCapacity(allocator, descriptor.wgpu_entries.len);
        defer wgpu_entries.deinit();

        for (descriptor.entries) |entry| {
            const buffer: *wgpu.Buffer, const sampler: *wgpu.Sampler, const texture_view: *wgpu.TextureView =
                switch (entry.resource) {
                .buffer => |buf| .{ @ptrCast(@alignCast(buf)), null, null },
                .sampler => |smp| .{ null, @ptrCast(@alignCast(smp)), null },
                .texture_view => |view| .{ null, null, @ptrCast(@alignCast(view)) },
                .storage_texture => unreachable, // TODO
            };

            wgpu_entries.appendAssumeCapacity(.{
                .binding = entry.binding,
                .offset = entry.offset,
                .size = entry.size,
                .buffer = buffer,
                .sampler = sampler,
                .texture_view = texture_view,
            });
        }

        const wgpu_bindgroup = device.wgpu_device.createBindGroup(&.{
            .label = if (descriptor.label) |l| l.ptr else null,
            .layout = layout.wgpu_layout,
            .entries = wgpu_entries,
        });

        var bindgroup = try allocator.create(BindGroup);
        bindgroup.* = .{ .wgpu_bindgroup = wgpu_bindgroup };
        return bindgroup;
    }

    pub fn createBindGroupLayout(device: *Device, descriptor: dgpu.BindGroupLayout.Descriptor) !*BindGroupLayout {
        var wgpu_entries = try std.ArrayList(wgpu.BindGroupLayout.Entry).initCapacity(allocator, descriptor.wgpu_entries.len);
        defer wgpu_entries.deinit();

        for (descriptor.entries) |entry| {
            const buffer: *wgpu.Buffer, const sampler: *wgpu.Sampler, const texture_view: *wgpu.TextureView =
                switch (entry.resource) {
                .buffer => |buf| .{ @ptrCast(@alignCast(buf)), null, null },
                .sampler => |smp| .{ null, @ptrCast(@alignCast(smp)), null },
                .texture_view => |view| .{ null, null, @ptrCast(@alignCast(view)) },
                .storage_texture => unreachable, // TODO
            };

            wgpu_entries.appendAssumeCapacity(.{
                .binding = entry.binding,
                .offset = entry.offset,
                .size = entry.size,
                .buffer = buffer,
                .sampler = sampler,
                .texture_view = texture_view,
            });
        }

        const wgpu_layout = device.wgpu_device.createBindGroupLayout(&.{
            .label = if (descriptor.label) |l| l.ptr else null,
            .entries_count = wgpu_entries.items.len,
            .entries = wgpu_entries.items.ptr,
        });

        var layout = try allocator.create(BindGroupLayout);
        layout.* = .{ .wgpu_layout = wgpu_layout };
        return layout;
    }

    // pub fn createBuffer(device: *Device, descriptor: dgpu.Buffer.Descriptor) !*Buffer {
    //     return Buffer.init(device, desc);
    // }

    pub fn createCommandEncoder(device: *Device, descriptor: dgpu.CommandEncoder.Descriptor) !*CommandEncoder {
        const wgpu_cmd_encoder = device.wgpu_device.createCommandEncoder(&.{ .label = if (descriptor.label) |l| l.ptr else null });
        var cmd_encoder = try allocator.create(CommandEncoder);
        cmd_encoder.* = .{ .wgpu_cmd_encoder = wgpu_cmd_encoder };
        return cmd_encoder;
    }

    // pub fn createComputePipeline(device: *Device, descriptor: dgpu.ComputePipeline.Descriptor) !*ComputePipeline {
    //     return ComputePipeline.init(device, desc);
    // }

    pub fn createPipelineLayout(device: *Device, descriptor: dgpu.PipelineLayout.Descriptor) !*PipelineLayout {
        var layouts = try std.ArrayList(*wgpu.BindGroupLayout).initCapacity(allocator, descriptor.bind_group_layouts.len);
        defer layouts.deinit();

        for (descriptor.bind_group_layouts) |layout| {
            const wgpu_layout: *BindGroupLayout = @ptrCast(@alignCast(layout));
            layouts.appendAssumeCapacity(wgpu_layout.wgpu_layout);
        }

        const wgpu_layout = device.wgpu_device.createRenderPipelineLayout(.{
            .label = if (descriptor.label) |l| l.ptr else null,
            .bind_group_layouts_count = layouts.items.len,
            .bind_group_layouts = layouts.items.ptr,
        });

        var layout = try allocator.create(PipelineLayout);
        layout.* = .{ .wgpu_layout = wgpu_layout };
        return layout;
    }

    pub fn createRenderPipeline(device: *Device, descriptor: dgpu.RenderPipeline.Descriptor) !*RenderPipeline {
        var wgpu_vertex_constants = try std.ArrayList(wgpu.ConstantEntry).initCapacity(allocator, descriptor.vertex.constants.len);
        defer wgpu_vertex_constants.deinit();
        var wgpu_fragment_constants = std.ArrayList(wgpu.ConstantEntry).init(allocator);
        defer wgpu_fragment_constants.deinit();
        var wgpu_vertex_buffers = try std.ArrayList(wgpu.VertexBufferLayout).initCapacity(allocator, descriptor.vertex.buffers.len);
        defer wgpu_vertex_buffers.deinit();
        var wgpu_color_targets = std.ArrayList(wgpu.ColorTargetState).init(allocator);
        defer wgpu_color_targets.deinit();
        var wgpu_attrs = std.ArrayList(wgpu.VertexAttribute).init(allocator);
        defer wgpu_attrs.deinit();

        for (descriptor.vertex.constants) |constant| {
            wgpu_vertex_constants.appendAssumeCapacity(.{ .key = constant.key, .value = constant.value });
        }

        for (descriptor.vertex.buffers) |buffer| {
            const attrs_index = wgpu_attrs.items.len;

            for (buffer.attributes) |attr| {
                try wgpu_attrs.append(.{
                    .format = conv.toWGPUVertexFormat(attr.format),
                    .offset = attr.offset,
                    .shader_location = attr.shader_location,
                });
            }

            wgpu_vertex_buffers.appendAssumeCapacity(.{
                .array_stride = buffer.array_stride,
                .step_mode = conv.toWGPUVertexStepMode(buffer.step_mode),
                .attribute_count = wgpu_attrs.items[attrs_index..].len,
                .attributes = wgpu_attrs.items[attrs_index..].ptr,
            });
        }

        const wgpu_pipeline = device.wgpu_device.createRenderPipeline(&.{
            .label = if (descriptor.label) |l| l.ptr else null,
            .layout = if (descriptor.layout) |l| @as(*PipelineLayout, @ptrCast(@alignCast(l))).wgpu_layout else null,
            .vertex = .{
                .module = @as(*ShaderModule, @ptrCast(@alignCast(descriptor.vertex.module))).wgpu_shader,
                .entry_point = descriptor.vertex.entry_point,
                .constant_count = wgpu_vertex_constants.items.len,
                .constants = wgpu_vertex_constants.items.ptr,
                .buffer_count = wgpu_vertex_buffers.items.len,
                .buffers = wgpu_vertex_buffers.items.ptr,
            },
            .primitive = .{
                .topology = conv.toWGPUPrimitiveTopology(descriptor.primitive.topology),
                .strip_index_format = conv.toWGPUIndexFormat(descriptor.primitive.strip_index_format),
                .front_face = conv.toWGPUFrontFace(descriptor.primitive.front_face),
                .cull_mode = conv.toWGPUCullMode(descriptor.primitive.cull_mode),
                // TODO
                // .primitive_depth_clip_control = .{
                //     .unclipped_depth = descriptor.primitive.primitive_depth_clip_control.unclipped_depth,
                // },
            },
            .depth_stencil = if (descriptor.depth_stencil) |ds| &.{
                .format = conv.toWGPUTextureFormat(ds.format),
                .depth_write_enabled = wgpu.Bool32.from(ds.depth_write_enabled),
                .depth_compare = conv.toWGPUCompareFunction(ds.depth_compare),
                .stencil_front = .{
                    .compare = conv.toWGPUCompareFunction(ds.stencil_front.compare),
                    .fail_op = conv.toWGPUStencilOperation(ds.stencil_front.fail_op),
                    .depth_fail_op = conv.toWGPUStencilOperation(ds.stencil_front.depth_fail_op),
                    .pass_op = conv.toWGPUStencilOperation(ds.stencil_front.pass_op),
                },
                .stencil_back = .{
                    .compare = conv.toWGPUCompareFunction(ds.stencil_back.compare),
                    .fail_op = conv.toWGPUStencilOperation(ds.stencil_back.fail_op),
                    .depth_fail_op = conv.toWGPUStencilOperation(ds.stencil_back.depth_fail_op),
                    .pass_op = conv.toWGPUStencilOperation(ds.stencil_back.pass_op),
                },
                .stencil_read_mask = ds.stencil_read_mask,
                .stencil_write_mask = ds.stencil_write_mask,
                .depth_bias = ds.depth_bias,
                .depth_bias_slope_scale = ds.depth_bias_slope_scale,
                .depth_bias_clamp = ds.depth_bias_clamp,
            } else null,
            .multisample = .{
                .count = descriptor.multisample.count,
                .mask = descriptor.multisample.mask,
                .alpha_to_coverage_enabled = wgpu.Bool32.from(descriptor.multisample.alpha_to_coverage_enabled),
            },
            .fragment = if (descriptor.fragment) |fragment| blk: {
                try wgpu_fragment_constants.ensureTotalCapacityPrecise(fragment.constants.len);
                try wgpu_color_targets.ensureTotalCapacityPrecise(fragment.targets.len);

                for (fragment.constants) |constant| {
                    wgpu_fragment_constants.appendAssumeCapacity(.{ .key = constant.key, .value = constant.value });
                }

                for (fragment.targets) |target| {
                    wgpu_color_targets.appendAssumeCapacity(.{
                        .format = conv.toWGPUTextureFormat(target.format),
                        .blend = if (target.blend) |blend| &.{
                            .color = .{
                                .operation = conv.toWGPUBlendOperation(blend.color.operation),
                                .src_factor = conv.toWGPUBlendFactor(blend.color.src_factor),
                                .dst_factor = conv.toWGPUBlendFactor(blend.color.dst_factor),
                            },
                            .alpha = .{
                                .operation = conv.toWGPUBlendOperation(blend.alpha.operation),
                                .src_factor = conv.toWGPUBlendFactor(blend.alpha.src_factor),
                                .dst_factor = conv.toWGPUBlendFactor(blend.alpha.dst_factor),
                            },
                        } else null,
                        .write_mask = conv.toWGPUColorWriteMaskFlags(target.write_mask),
                    });
                }

                break :blk &.{
                    .module = @as(*ShaderModule, @ptrCast(@alignCast(fragment.module))).wgpu_shader,
                    .entry_point = fragment.entry_point,
                    .constant_count = wgpu_fragment_constants.items.len,
                    .constants = wgpu_fragment_constants.items.ptr,
                    .target_count = wgpu_color_targets.items.len,
                    .targets = wgpu_color_targets.items.ptr,
                };
            } else null,
        });

        var pipeline = try allocator.create(RenderPipeline);
        pipeline.* = .{ .wgpu_pipeline = wgpu_pipeline };
        return pipeline;
    }

    pub fn createShaderModuleWGSLCode(device: *Device, code: [:0]const u8) !*ShaderModule {
        const wgpu_shader = device.wgpu_device.createShaderModule(&.{
            .next_in_chain = .{ .wgsl_descriptor = &.{ .code = code } },
        });

        var shader_module = try allocator.create(ShaderModule);
        shader_module.* = .{ .wgpu_shader = wgpu_shader };
        return shader_module;
    }

    pub fn createShaderModuleAir(device: *Device, air: *const shader.Air) !*ShaderModule {
        _ = device;
        _ = air;
        unreachable;
    }

    pub fn createShaderModuleSpirv(device: *Device, code: []const u32) !*ShaderModule {
        const next_in_chain = wgpu.ShaderModule.Descriptor.NextInChain{
            .spirv_descriptor = &.{
                .code = code.ptr,
                .code_size = @intCast(code.len * @sizeOf(u32)),
            },
        };
        const wgpu_shader = device.wgpu_device.createShaderModule(&.{ .next_in_chain = next_in_chain });

        var shader_module = try allocator.create(ShaderModule);
        shader_module.* = .{ .wgpu_shader = wgpu_shader };
        return shader_module;
    }

    pub fn createSwapChain(device: *Device, surface: *Surface, descriptor: dgpu.SwapChain.Descriptor) !*SwapChain {
        const wgpu_swapchain = device.wgpu_device.createSwapChain(surface.wgpu_surface, &.{
            .label = if (descriptor.label) |l| l.ptr else null,
            .usage = conv.toWGPUTextureUsageFlags(descriptor.usage),
            .format = conv.toWGPUTextureFormat(descriptor.format),
            .width = descriptor.width,
            .height = descriptor.height,
            .present_mode = conv.toWGPUPresentMode(descriptor.present_mode),
        });

        var swapchain = try allocator.create(SwapChain);
        swapchain.* = .{ .wgpu_swapchain = wgpu_swapchain };
        return swapchain;
    }

    pub fn createTexture(device: *Device, descriptor: dgpu.Texture.Descriptor) !*Texture {
        _ = descriptor;
        _ = device;
        unreachable;
    }

    pub fn getQueue(device: *Device) !*Queue {
        if (device.queue) |queue| {
            return queue;
        } else {
            device.queue = try allocator.create(Queue);
            device.queue.?.* = .{ .wgpu_queue = device.wgpu_device.getQueue() };
            return device.queue.?;
        }
    }

    pub fn tick(device: *Device) !void {
        device.wgpu_device.tick();
    }
};

pub const SwapChain = struct {
    manager: utils.Manager(SwapChain) = .{},
    wgpu_swapchain: *wgpu.SwapChain,

    pub fn deinit(sc: *SwapChain) void {
        sc.wgpu_swapchain.release();
        allocator.destroy(sc);
    }

    pub fn getCurrentTextureView(sc: *SwapChain) !*TextureView {
        var view = try allocator.create(TextureView);
        view.* = .{ .wgpu_view = sc.wgpu_swapchain.getCurrentTextureView() orelse unreachable };
        return view;
    }

    pub fn present(sc: *SwapChain) !void {
        return sc.wgpu_swapchain.present();
    }
};

pub const Buffer = struct {
    manager: utils.Manager(Buffer) = .{},
    wgpu_buffer: *wgpu.Buffer,

    pub fn deinit(buffer: *Buffer) void {
        buffer.wgpu_buffer.release();
        allocator.destroy(buffer);
    }

    pub fn getConstMappedRange(buffer: *Buffer, offset: usize, size: usize) !?*anyopaque {
        return @constCast(buffer.wgpu_buffer.getConstMappedRange(offset, size));
    }

    pub fn mapAsync(buffer: *Buffer, mode: dgpu.MapModeFlags, offset: usize, size: usize, callback: dgpu.Buffer.MapCallback, userdata: ?*anyopaque) !void {
        _ = userdata;
        _ = callback;
        _ = size;
        _ = offset;
        _ = mode;
        _ = buffer;
        unreachable;
    }

    pub fn unmap(buffer: *Buffer) !void {
        buffer.wgpu_buffer.unmap();
    }
};

pub const Texture = struct {
    manager: utils.Manager(Texture) = .{},
    wgpu_texture: *wgpu.Texture,

    pub fn deinit(texture: *Texture) void {
        texture.wgpu_texture.release();
        allocator.destroy(texture);
    }

    pub fn createView(texture: *Texture, descriptor: dgpu.TextureView.Descriptor) !*TextureView {
        var view = try allocator.create(TextureView);
        view.* = .{
            .wgpu_view = texture.wgpu_texture.createView(&.{
                .label = if (descriptor.label) |l| l.ptr else null,
                .format = conv.toWGPUTextureFormat(descriptor.format),
                .dimension = conv.toWGPUTextureViewDimension(descriptor.dimension),
                .base_mip_level = descriptor.base_mip_level,
                .mip_level_count = descriptor.mip_level_count,
                .base_array_layer = descriptor.base_array_layer,
                .array_layer_count = descriptor.array_layer_count,
                .aspect = conv.toWGPUTextureAspect(descriptor.aspect),
            }),
        };
        return view;
    }
};

pub const TextureView = struct {
    manager: utils.Manager(TextureView) = .{},
    wgpu_view: *wgpu.TextureView,

    pub fn deinit(view: *TextureView) void {
        view.wgpu_view.release();
        allocator.destroy(view);
    }
};

pub const BindGroupLayout = struct {
    manager: utils.Manager(BindGroupLayout) = .{},
    wgpu_layout: *wgpu.BindGroupLayout,

    pub fn deinit(layout: *BindGroupLayout) void {
        layout.wgpu_layout.release();
        allocator.destroy(layout);
    }
};

pub const BindGroup = struct {
    manager: utils.Manager(BindGroup) = .{},
    wgpu_bindgroup: *wgpu.BindGroup,

    pub fn deinit(group: *BindGroup) void {
        group.wgpu_bindgroup.release();
        allocator.destroy(group);
    }
};

pub const PipelineLayout = struct {
    manager: utils.Manager(PipelineLayout) = .{},
    wgpu_layout: *wgpu.PipelineLayout,

    pub fn deinit(layout: *PipelineLayout) void {
        layout.wgpu_layout.release();
        allocator.destroy(layout);
    }
};

pub const ShaderModule = struct {
    manager: utils.Manager(ShaderModule) = .{},
    wgpu_shader: *wgpu.ShaderModule,

    pub fn deinit(shader_module: *ShaderModule) void {
        shader_module.wgpu_shader.release();
        allocator.destroy(shader_module);
    }
};

pub const ComputePipeline = struct {
    manager: utils.Manager(ComputePipeline) = .{},
    wgpu_pipeline: *wgpu.ComputePipeline,

    pub fn deinit(pipeline: *ComputePipeline) void {
        pipeline.wgpu_pipeline.release();
        allocator.destroy(pipeline);
    }

    pub fn getBindGroupLayout(pipeline: *ComputePipeline, group_index: u32) *BindGroupLayout {
        _ = group_index;
        _ = pipeline;
        unreachable;
    }
};

pub const RenderPipeline = struct {
    manager: utils.Manager(RenderPipeline) = .{},
    wgpu_pipeline: *wgpu.RenderPipeline,

    pub fn deinit(render_pipeline: *RenderPipeline) void {
        render_pipeline.wgpu_pipeline.release();
        allocator.destroy(render_pipeline);
    }

    pub fn getBindGroupLayout(pipeline: *RenderPipeline, group_index: u32) *BindGroupLayout {
        _ = group_index;
        _ = pipeline;
        unreachable;
    }
};

pub const CommandBuffer = struct {
    manager: utils.Manager(CommandBuffer) = .{},
    wgpu_buffer: *wgpu.CommandBuffer,

    pub fn deinit(cmd_buffer: *CommandBuffer) void {
        cmd_buffer.wgpu_buffer.release();
        allocator.destroy(cmd_buffer);
    }
};

pub const CommandEncoder = struct {
    manager: utils.Manager(CommandEncoder) = .{},
    wgpu_cmd_encoder: *wgpu.CommandEncoder,

    pub fn deinit(cmd_encoder: *CommandEncoder) void {
        cmd_encoder.wgpu_cmd_encoder.release();
        allocator.destroy(cmd_encoder);
    }

    pub fn beginComputePass(encoder: *CommandEncoder, descriptor: dgpu.ComputePassDescriptor) !*ComputePassEncoder {
        _ = descriptor;
        _ = encoder;
        unreachable;
    }

    pub fn beginRenderPass(cmd_encoder: *CommandEncoder, descriptor: dgpu.RenderPassDescriptor) !*RenderPassEncoder {
        var color_attachments = try std.ArrayList(wgpu.RenderPassColorAttachment).initCapacity(allocator, descriptor.color_attachments.len);
        defer color_attachments.deinit();

        var wgpu_timestamp_writes = try std.ArrayList(wgpu.RenderPassTimestampWrite).initCapacity(allocator, descriptor.timestamp_writes.len);
        defer wgpu_timestamp_writes.deinit();

        for (descriptor.color_attachments) |attachment| {
            color_attachments.appendAssumeCapacity(.{
                .view = if (attachment.view) |view| @as(*TextureView, @ptrCast(@alignCast(view))).wgpu_view else null,
                .resolve_target = if (attachment.resolve_target) |view| @as(*TextureView, @ptrCast(@alignCast(view))).wgpu_view else null,
                .load_op = conv.toWGPULoadOp(attachment.load_op),
                .store_op = conv.toWGPUStoreOp(attachment.store_op),
                .clear_value = conv.toWGPUColor(attachment.clear_value),
            });
        }

        for (descriptor.timestamp_writes) |timestamp_write| {
            wgpu_timestamp_writes.appendAssumeCapacity(.{
                .query_set = @as(*QuerySet, @ptrCast(@alignCast(timestamp_write.query_set))).wgpu_query_set,
                .query_index = timestamp_write.query_index,
                .location = conv.toWGPURenderPassTimestampLocation(timestamp_write.location),
            });
        }

        const wgpu_rpe = cmd_encoder.wgpu_cmd_encoder.beginRenderPass(&.{
            .label = if (descriptor.label) |l| l.ptr else null,
            .color_attachment_count = color_attachments.items.len,
            .color_attachments = color_attachments.items.ptr,
            .depth_stencil_attachment = if (descriptor.depth_stencil_attachment) |ds| &.{
                .view = @as(*TextureView, @ptrCast(@alignCast(ds.view))).wgpu_view,
                .depth_load_op = conv.toWGPULoadOp(ds.depth_load_op),
                .depth_store_op = conv.toWGPUStoreOp(ds.depth_store_op),
                .depth_clear_value = ds.depth_clear_value,
                .depth_read_only = wgpu.Bool32.from(ds.depth_read_only),
                .stencil_load_op = conv.toWGPULoadOp(ds.stencil_load_op),
                .stencil_store_op = conv.toWGPUStoreOp(ds.stencil_store_op),
                .stencil_clear_value = ds.stencil_clear_value,
                .stencil_read_only = wgpu.Bool32.from(ds.stencil_read_only),
            } else null,
            .occlusion_query_set = if (descriptor.occlusion_query_set) |query_set| @as(*QuerySet, @ptrCast(@alignCast(query_set))).wgpu_query_set else null,
            .timestamp_write_count = wgpu_timestamp_writes.items.len,
            .timestamp_writes = wgpu_timestamp_writes.items.ptr,
            // TODO
            // .max_draw_count = .{ .max_draw_count = descriptor.max_draw_count },
        });

        var rpe = try allocator.create(RenderPassEncoder);
        rpe.* = .{ .wgpu_rpe = wgpu_rpe };
        return rpe;
    }

    pub fn copyBufferToBuffer(
        encoder: *CommandEncoder,
        source: *Buffer,
        source_offset: u64,
        destination: *Buffer,
        destination_offset: u64,
        size: u64,
    ) !void {
        encoder.wgpu_cmd_encoder.copyBufferToBuffer(
            source.wgpu_buffer,
            source_offset,
            destination.wgpu_buffer,
            destination_offset,
            size,
        );
    }

    pub fn finish(cmd_encoder: *CommandEncoder, descriptor: dgpu.CommandBuffer.Descriptor) !*CommandBuffer {
        const wgpu_buffer = cmd_encoder.wgpu_cmd_encoder.finish(&.{
            .label = if (descriptor.label) |l| l.ptr else null,
        });

        var buffer = try allocator.create(CommandBuffer);
        buffer.* = .{ .wgpu_buffer = wgpu_buffer };
        return buffer;
    }

    pub fn writeBuffer(encoder: *CommandEncoder, buffer: *Buffer, offset: u64, data: [*]const u8, size: u64) !void {
        _ = size;
        _ = data;
        _ = offset;
        _ = buffer;
        _ = encoder;
        unreachable;
    }
};

pub const ComputePassEncoder = struct {
    manager: utils.Manager(ComputePassEncoder) = .{},

    pub fn init(command_encoder: *CommandEncoder, descriptor: dgpu.ComputePassDescriptor) !*ComputePassEncoder {
        _ = descriptor;
        _ = command_encoder;
        unreachable;
    }

    pub fn deinit(encoder: *ComputePassEncoder) void {
        _ = encoder;
    }

    pub fn dispatchWorkgroups(encoder: *ComputePassEncoder, workgroup_count_x: u32, workgroup_count_y: u32, workgroup_count_z: u32) void {
        _ = workgroup_count_z;
        _ = workgroup_count_y;
        _ = workgroup_count_x;
        _ = encoder;
        unreachable;
    }

    pub fn setBindGroup(encoder: *ComputePassEncoder, group_index: u32, group: *BindGroup, dynamic_offset_count: usize, dynamic_offsets: ?[*]const u32) !void {
        _ = dynamic_offsets;
        _ = dynamic_offset_count;
        _ = group;
        _ = group_index;
        _ = encoder;
        unreachable;
    }

    pub fn setPipeline(encoder: *ComputePassEncoder, pipeline: *ComputePipeline) !void {
        _ = pipeline;
        _ = encoder;
        unreachable;
    }

    pub fn end(encoder: *ComputePassEncoder) void {
        _ = encoder;
        unreachable;
    }
};

pub const RenderPassEncoder = struct {
    manager: utils.Manager(RenderPassEncoder) = .{},
    wgpu_rpe: *wgpu.RenderPassEncoder,

    pub fn deinit(encoder: *RenderPassEncoder) void {
        encoder.wgpu_rpe.release();
        allocator.destroy(encoder);
    }

    pub fn setBindGroup(
        encoder: *RenderPassEncoder,
        group_index: u32,
        group: *BindGroup,
        dynamic_offsets: []const u32,
    ) !void {
        encoder.wgpu_rpe.setBindGroup(group_index, group.wgpu_bindgroup, dynamic_offsets.len, dynamic_offsets.ptr);
    }

    pub fn setPipeline(encoder: *RenderPassEncoder, pipeline: *RenderPipeline) !void {
        encoder.wgpu_rpe.setPipeline(pipeline.wgpu_pipeline);
    }

    pub fn setVertexBuffer(encoder: *RenderPassEncoder, slot: u32, buffer: *Buffer, offset: u64, size: u64) !void {
        encoder.wgpu_rpe.setVertexBuffer(slot, buffer.wgpu_buffer, offset, size);
    }

    pub fn draw(encoder: *RenderPassEncoder, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void {
        encoder.wgpu_rpe.draw(vertex_count, instance_count, first_vertex, first_instance);
    }

    pub fn end(encoder: *RenderPassEncoder) void {
        encoder.wgpu_rpe.end();
    }
};

pub const QuerySet = struct {
    manager: utils.Manager(QuerySet) = .{},
    wgpu_query_set: *wgpu.QuerySet,

    pub fn deinit(query_set: *QuerySet) void {
        query_set.wgpu_query_set.release();
        allocator.destroy(query_set);
    }
};

pub const Queue = struct {
    manager: utils.Manager(Queue) = .{},
    wgpu_queue: *wgpu.Queue,
    commands: std.ArrayListUnmanaged(*wgpu.CommandBuffer) = .{},

    pub fn deinit(queue: *Queue) void {
        queue.commands.deinit(allocator);
        queue.wgpu_queue.release();
        allocator.destroy(queue);
    }

    pub fn submit(queue: *Queue, commands: []const *CommandBuffer) !void {
        queue.commands.clearRetainingCapacity();
        for (commands) |cmd| try queue.commands.append(allocator, cmd.wgpu_buffer);
        queue.wgpu_queue.submit(queue.commands.items);
    }

    pub fn writeBuffer(queue: *Queue, buffer: *Buffer, offset: u64, data: [*]const u8, size: u64) !void {
        queue.wgpu_queue.submit(buffer.wgpu_buffer, offset, data, size);
    }
};

// test "reference declarations" {
//     std.testing.refAllDeclsRecursive(@This());
// }
