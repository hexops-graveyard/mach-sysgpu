const std = @import("std");
const gpu = @import("gpu");
const ca = @import("objc").quartz_core.ca;
const mtl = @import("objc").metal.mtl;
const ns = @import("objc").foundation.ns;
const utils = @import("utils.zig");
const conv = @import("metal/conv.zig");

const log = std.log.scoped(.metal);

var allocator: std.mem.Allocator = undefined;

pub const InitOptions = struct {};

pub fn init(alloc: std.mem.Allocator, options: InitOptions) !void {
    _ = options;
    allocator = alloc;
}

pub fn isDepthFormat(format: mtl.PixelFormat) bool {
    return switch (format) {
        mtl.PixelFormatDepth16Unorm => true,
        mtl.PixelFormatDepth24Unorm_Stencil8 => true,
        mtl.PixelFormatDepth32Float => true,
        mtl.PixelFormatDepth32Float_Stencil8 => true,
        else => false,
    };
}

pub fn isStencilFormat(format: mtl.PixelFormat) bool {
    return switch (format) {
        mtl.PixelFormatStencil8 => true,
        mtl.PixelFormatDepth24Unorm_Stencil8 => true,
        mtl.PixelFormatDepth32Float_Stencil8 => true,
        else => false,
    };
}

pub const Instance = struct {
    manager: utils.Manager(Instance) = .{},

    pub fn init(desc: *const gpu.Instance.Descriptor) !*Instance {
        // TODO
        _ = desc;

        ns.init();
        ca.init();
        mtl.init();

        var instance = try allocator.create(Instance);
        instance.* = .{};
        return instance;
    }

    pub fn deinit(instance: *Instance) void {
        allocator.destroy(instance);
    }

    pub fn createSurface(instance: *Instance, desc: *const gpu.Surface.Descriptor) !*Surface {
        return Surface.init(instance, desc);
    }
};

pub const Adapter = struct {
    manager: utils.Manager(Adapter) = .{},
    device: *mtl.Device,

    pub fn init(instance: *Instance, options: *const gpu.RequestAdapterOptions) !*Adapter {
        _ = instance;
        _ = options;

        // TODO - choose appropriate device from options
        const device = mtl.createSystemDefaultDevice() orelse {
            return error.NoAdapterFound;
        };

        var adapter = try allocator.create(Adapter);
        adapter.* = .{ .device = device };
        return adapter;
    }

    pub fn deinit(adapter: *Adapter) void {
        adapter.device.release();
        allocator.destroy(adapter);
    }

    pub fn createDevice(adapter: *Adapter, desc: ?*const gpu.Device.Descriptor) !*Device {
        return Device.init(adapter, desc);
    }

    pub fn getProperties(adapter: *Adapter) gpu.Adapter.Properties {
        return .{
            .vendor_id = 0, // TODO
            .vendor_name = "", // TODO
            .architecture = "", // TODO
            .device_id = 0, // TODO
            .name = adapter.device.name().utf8String(),
            .driver_description = "", // TODO
            .adapter_type = if (adapter.device.isLowPower()) .integrated_gpu else .discrete_gpu,
            .backend_type = .metal,
            .compatibility_mode = .false,
        };
    }
};

pub const Surface = struct {
    manager: utils.Manager(Surface) = .{},
    layer: *ca.MetalLayer,

    pub fn init(instance: *Instance, desc: *const gpu.Surface.Descriptor) !*Surface {
        _ = instance;

        if (utils.findChained(gpu.Surface.DescriptorFromMetalLayer, desc.next_in_chain.generic)) |mtl_desc| {
            var surface = try allocator.create(Surface);
            surface.* = .{ .layer = @ptrCast(mtl_desc.layer) };
            return surface;
        } else {
            return error.InvalidDescriptor;
        }
    }

    pub fn deinit(surface: *Surface) void {
        allocator.destroy(surface);
    }
};

pub const Device = struct {
    manager: utils.Manager(Device) = .{},
    device: *mtl.Device,
    queue: ?*Queue = null,
    err_cb: ?gpu.ErrorCallback = null,
    err_cb_userdata: ?*anyopaque = null,

    pub fn init(adapter: *Adapter, desc: ?*const gpu.Device.Descriptor) !*Device {
        // TODO
        _ = desc;

        var device = try allocator.create(Device);
        device.* = .{ .device = adapter.device };
        return device;
    }

    pub fn deinit(device: *Device) void {
        if (device.queue) |queue| queue.manager.release();
        allocator.destroy(device);
    }

    pub fn createCommandEncoder(device: *Device, desc: *const gpu.CommandEncoder.Descriptor) !*CommandEncoder {
        return CommandEncoder.init(device, desc);
    }

    pub fn createRenderPipeline(device: *Device, desc: *const gpu.RenderPipeline.Descriptor) !*RenderPipeline {
        return RenderPipeline.init(device, desc);
    }

    pub fn createShaderModule(device: *Device, code: []const u8) !*ShaderModule {
        return ShaderModule.init(device, code);
    }

    pub fn createSwapChain(device: *Device, surface: *Surface, desc: *const gpu.SwapChain.Descriptor) !*SwapChain {
        return SwapChain.init(device, surface, desc);
    }

    pub fn createTexture(device: *Device, desc: *const gpu.Texture.Descriptor) !*Texture {
        return Texture.init(device, desc);
    }

    pub fn getQueue(device: *Device) !*Queue {
        if (device.queue == null) {
            device.queue = try Queue.init(device);
        }
        return device.queue.?;
    }
};

pub const SwapChain = struct {
    manager: utils.Manager(SwapChain) = .{},
    device: *Device,
    surface: *Surface,
    current_drawable: ?*ca.MetalDrawable = null,

    pub fn init(device: *Device, surface: *Surface, desc: *const gpu.SwapChain.Descriptor) !*SwapChain {
        // TODO
        _ = desc;

        surface.layer.setDevice(device.device);

        var swapchain = try allocator.create(SwapChain);
        swapchain.* = .{ .device = device, .surface = surface };
        return swapchain;
    }

    pub fn deinit(swapchain: *SwapChain) void {
        allocator.destroy(swapchain);
    }

    pub fn getCurrentTextureView(swapchain: *SwapChain) !*TextureView {
        swapchain.current_drawable = swapchain.surface.layer.nextDrawable();
        if (swapchain.current_drawable) |drawable| {
            return TextureView.initFromMtlTexture(drawable.texture().retain());
        } else {
            // TODO - handle no drawable
            unreachable;
        }
    }

    pub fn present(swapchain: *SwapChain) !void {
        if (swapchain.current_drawable) |_| {
            const queue = try swapchain.device.getQueue();
            const command_buffer = queue.command_queue.commandBuffer().?; // TODO
            command_buffer.presentDrawable(@ptrCast(swapchain.current_drawable)); // TODO - objc casting?
            command_buffer.commit();
        }
    }
};

pub const Texture = struct {
    manager: utils.Manager(Texture) = .{},
    mtl_texture: *mtl.Texture,

    pub fn init(device: *Device, desc: *const gpu.Texture.Descriptor) !*Texture {
        var mtl_desc = mtl.TextureDescriptor.alloc().init();
        mtl_desc.setTextureType(conv.metalTextureType(desc.dimension, desc.size, desc.sample_count));
        mtl_desc.setPixelFormat(conv.metalPixelFormat(desc.format));
        mtl_desc.setWidth(desc.size.width);
        mtl_desc.setHeight(desc.size.height);
        mtl_desc.setDepth(if (desc.dimension == .dimension_3d) desc.size.depth_or_array_layers else 1);
        mtl_desc.setMipmapLevelCount(desc.mip_level_count);
        mtl_desc.setSampleCount(desc.sample_count);
        mtl_desc.setArrayLength(if (desc.dimension == .dimension_3d) 1 else desc.size.depth_or_array_layers);
        mtl_desc.setStorageMode(conv.metalStorageModeForTexture(desc.usage));
        mtl_desc.setUsage(conv.metalTextureUsage(desc.usage, desc.view_format_count));

        const mtl_texture = device.device.newTextureWithDescriptor(mtl_desc) orelse {
            return error.newTextureFailed;
        };
        if (desc.label) |label| {
            mtl_texture.setLabel(ns.String.stringWithUTF8String(label));
        }

        var texture = try allocator.create(Texture);
        texture.* = .{
            .mtl_texture = mtl_texture,
        };
        return texture;
    }

    pub fn deinit(texture: *Texture) void {
        texture.mtl_texture.release();
        allocator.destroy(texture);
    }

    pub fn createView(texture: *Texture, desc: ?*const gpu.TextureView.Descriptor) !*TextureView {
        return TextureView.init(texture, desc);
    }
};

pub const TextureView = struct {
    manager: utils.Manager(TextureView) = .{},
    mtl_texture: *mtl.Texture,

    pub fn init(texture: *Texture, opt_desc: ?*const gpu.TextureView.Descriptor) !*TextureView {
        var mtl_texture = texture.mtl_texture;
        if (opt_desc) |desc| {
            // TODO - analyze desc to see if we need to create a new view

            mtl_texture = mtl_texture.newTextureViewWithPixelFormat_textureType_levels_slices(
                conv.metalPixelFormatForView(desc.format, mtl_texture.pixelFormat(), desc.aspect),
                conv.metalTextureTypeForView(desc.dimension),
                ns.Range.init(desc.base_mip_level, desc.mip_level_count),
                ns.Range.init(desc.base_array_layer, desc.array_layer_count),
            ) orelse {
                return error.newTextureViewFailed;
            };
            if (desc.label) |label| {
                mtl_texture.setLabel(ns.String.stringWithUTF8String(label));
            }
        }

        var view = try allocator.create(TextureView);
        view.* = .{
            .mtl_texture = mtl_texture,
        };
        return view;
    }

    pub fn initFromMtlTexture(mtl_texture: *mtl.Texture) !*TextureView {
        var view = try allocator.create(TextureView);
        view.* = .{
            .mtl_texture = mtl_texture,
        };
        return view;
    }

    pub fn deinit(view: *TextureView) void {
        view.mtl_texture.release();
        allocator.destroy(view);
    }
};

pub const RenderPipeline = struct {
    manager: utils.Manager(RenderPipeline) = .{},
    pipeline: *mtl.RenderPipelineState,
    primitive_type: mtl.PrimitiveType,
    winding: mtl.Winding,
    cull_mode: mtl.CullMode,
    depth_stencil_state: ?*mtl.DepthStencilState,
    depth_bias: f32,
    depth_bias_slope_scale: f32,
    depth_bias_clamp: f32,

    pub fn init(device: *Device, desc: *const gpu.RenderPipeline.Descriptor) !*RenderPipeline {
        var mtl_desc = mtl.RenderPipelineDescriptor.alloc().init();
        defer mtl_desc.release();

        if (desc.label) |label| {
            mtl_desc.setLabel(ns.String.stringWithUTF8String(label));
        }

        // layout - TODO

        // vertex
        const vertex_module: *ShaderModule = @ptrCast(@alignCast(desc.vertex.module));
        const vertex_fn = vertex_module.library.newFunctionWithName(ns.String.stringWithUTF8String(desc.vertex.entry_point)) orelse {
            return error.InvalidDescriptor;
        };
        defer vertex_fn.release();
        mtl_desc.setVertexFunction(vertex_fn);

        // vertex constants - TODO
        // vertex buffers - TODO

        // primitive
        const primitive_type = conv.metalPrimitiveType(desc.primitive.topology);
        mtl_desc.setInputPrimitiveTopology(conv.metalPrimitiveTopologyClass(desc.primitive.topology));
        // strip_index_format
        const winding = conv.metalWinding(desc.primitive.front_face);
        const cull_mode = conv.metalCullMode(desc.primitive.cull_mode);

        // depth-stencil
        const depth_stencil_state = blk: {
            if (desc.depth_stencil) |ds| {
                var front_desc = mtl.StencilDescriptor.alloc().init();
                defer front_desc.release();

                front_desc.setStencilCompareFunction(conv.metalCompareFunction(ds.stencil_front.compare));
                front_desc.setStencilFailureOperation(conv.metalStencilOperation(ds.stencil_front.fail_op));
                front_desc.setDepthFailureOperation(conv.metalStencilOperation(ds.stencil_front.depth_fail_op));
                front_desc.setDepthStencilPassOperation(conv.metalStencilOperation(ds.stencil_front.pass_op));
                front_desc.setReadMask(ds.stencil_read_mask);
                front_desc.setWriteMask(ds.stencil_write_mask);

                var back_desc = mtl.StencilDescriptor.alloc().init();
                defer back_desc.release();

                back_desc.setStencilCompareFunction(conv.metalCompareFunction(ds.stencil_back.compare));
                back_desc.setStencilFailureOperation(conv.metalStencilOperation(ds.stencil_back.fail_op));
                back_desc.setDepthFailureOperation(conv.metalStencilOperation(ds.stencil_back.depth_fail_op));
                back_desc.setDepthStencilPassOperation(conv.metalStencilOperation(ds.stencil_back.pass_op));
                back_desc.setReadMask(ds.stencil_read_mask);
                back_desc.setWriteMask(ds.stencil_write_mask);

                var depth_stencil_desc = mtl.DepthStencilDescriptor.alloc().init();
                defer depth_stencil_desc.release();

                depth_stencil_desc.setDepthCompareFunction(conv.metalCompareFunction(ds.depth_compare));
                depth_stencil_desc.setDepthWriteEnabled(ds.depth_write_enabled == .true);
                depth_stencil_desc.setFrontFaceStencil(front_desc);
                depth_stencil_desc.setBackFaceStencil(back_desc);
                if (desc.label) |label| {
                    depth_stencil_desc.setLabel(ns.String.stringWithUTF8String(label));
                }

                break :blk device.device.newDepthStencilStateWithDescriptor(depth_stencil_desc);
            } else {
                break :blk null;
            }
        };
        const depth_bias = if (desc.depth_stencil != null) @as(f32, @floatFromInt(desc.depth_stencil.?.depth_bias)) else 0.0; // TODO - int to float conversion
        const depth_bias_slope_scale = if (desc.depth_stencil != null) desc.depth_stencil.?.depth_bias_slope_scale else 0.0;
        const depth_bias_clamp = if (desc.depth_stencil != null) desc.depth_stencil.?.depth_bias_clamp else 0.0;

        // multisample
        mtl_desc.setSampleCount(desc.multisample.count);
        // mask - TODO
        mtl_desc.setAlphaToCoverageEnabled(desc.multisample.alpha_to_coverage_enabled == .true);

        // fragment
        if (desc.fragment) |frag| {
            const frag_module: *ShaderModule = @ptrCast(@alignCast(frag.module));
            const frag_fn = frag_module.library.newFunctionWithName(ns.String.stringWithUTF8String(frag.entry_point)) orelse {
                return error.InvalidDescriptor;
            };
            defer frag_fn.release();
            mtl_desc.setFragmentFunction(frag_fn);
        }

        // attachments
        if (desc.fragment) |frag| {
            for (frag.targets.?[0..frag.target_count], 0..) |target, i| {
                var attach = mtl_desc.colorAttachments().objectAtIndexedSubscript(i);

                attach.setPixelFormat(conv.metalPixelFormat(target.format));
                attach.setWriteMask(conv.metalColorWriteMask(target.write_mask));
                if (target.blend) |blend| {
                    attach.setBlendingEnabled(true);
                    attach.setSourceRGBBlendFactor(conv.metalBlendFactor(blend.color.src_factor));
                    attach.setDestinationRGBBlendFactor(conv.metalBlendFactor(blend.color.dst_factor));
                    attach.setRgbBlendOperation(conv.metalBlendOperation(blend.color.operation));
                    attach.setSourceAlphaBlendFactor(conv.metalBlendFactor(blend.alpha.src_factor));
                    attach.setDestinationAlphaBlendFactor(conv.metalBlendFactor(blend.alpha.dst_factor));
                    attach.setAlphaBlendOperation(conv.metalBlendOperation(blend.alpha.operation));
                }
            }
        }
        if (desc.depth_stencil) |ds| {
            mtl_desc.setDepthAttachmentPixelFormat(conv.metalPixelFormat(ds.format));
            mtl_desc.setStencilAttachmentPixelFormat(conv.metalPixelFormat(ds.format));
        }

        // create
        var err: ?*ns.Error = undefined;
        const pipeline = device.device.newRenderPipelineStateWithDescriptor_error(mtl_desc, &err) orelse {
            // TODO
            std.log.err("{s}", .{err.?.localizedDescription().utf8String()});
            return error.InvalidDescriptor;
        };

        var render_pipeline = try allocator.create(RenderPipeline);
        render_pipeline.* = .{
            .pipeline = pipeline,
            .primitive_type = primitive_type,
            .winding = winding,
            .cull_mode = cull_mode,
            .depth_stencil_state = depth_stencil_state,
            .depth_bias = depth_bias,
            .depth_bias_slope_scale = depth_bias_slope_scale,
            .depth_bias_clamp = depth_bias_clamp,
        };
        return render_pipeline;
    }

    pub fn deinit(render_pipeline: *RenderPipeline) void {
        render_pipeline.pipeline.release();
        allocator.destroy(render_pipeline);
    }
};

pub const RenderPassEncoder = struct {
    manager: utils.Manager(RenderPassEncoder) = .{},
    encoder: *mtl.RenderCommandEncoder,
    primitive_type: mtl.PrimitiveType = mtl.PrimitiveTypeTriangle,

    pub fn init(cmd_encoder: *CommandEncoder, desc: *const gpu.RenderPassDescriptor) !*RenderPassEncoder {
        var mtl_desc = mtl.RenderPassDescriptor.new();
        defer mtl_desc.release();

        // color
        for (desc.color_attachments.?[0..desc.color_attachment_count], 0..) |attach, i| {
            var mtl_attach = mtl_desc.colorAttachments().objectAtIndexedSubscript(i);
            if (attach.view) |view| {
                const mtl_view: *TextureView = @ptrCast(@alignCast(view));
                mtl_attach.setTexture(mtl_view.mtl_texture);
            }
            if (attach.resolve_target) |view| {
                const mtl_view: *TextureView = @ptrCast(@alignCast(view));
                mtl_attach.setResolveTexture(mtl_view.mtl_texture);
            }
            mtl_attach.setLoadAction(conv.metalLoadAction(attach.load_op));
            mtl_attach.setStoreAction(conv.metalStoreAction(attach.store_op, attach.resolve_target != null));

            if (attach.load_op == .clear) {
                mtl_attach.setClearColor(mtl.ClearColor.init(
                    @floatCast(attach.clear_value.r),
                    @floatCast(attach.clear_value.g),
                    @floatCast(attach.clear_value.b),
                    @floatCast(attach.clear_value.a),
                ));
            }
        }

        // depth-stencil
        if (desc.depth_stencil_attachment) |attach| {
            const mtl_view: *TextureView = @ptrCast(@alignCast(attach.view));
            const format = mtl_view.mtl_texture.pixelFormat();

            if (isDepthFormat(format)) {
                var mtl_attach = mtl_desc.depthAttachment();

                mtl_attach.setTexture(mtl_view.mtl_texture);
                mtl_attach.setLoadAction(conv.metalLoadAction(attach.depth_load_op));
                mtl_attach.setStoreAction(conv.metalStoreAction(attach.depth_store_op, false));

                if (attach.depth_load_op == .clear) {
                    mtl_attach.setClearDepth(attach.depth_clear_value);
                }
            }

            if (isStencilFormat(format)) {
                var mtl_attach = mtl_desc.stencilAttachment();

                mtl_attach.setTexture(mtl_view.mtl_texture);
                mtl_attach.setLoadAction(conv.metalLoadAction(attach.stencil_load_op));
                mtl_attach.setStoreAction(conv.metalStoreAction(attach.stencil_store_op, false));

                if (attach.stencil_load_op == .clear) {
                    mtl_attach.setClearStencil(attach.stencil_clear_value);
                }
            }
        }

        // occlusion_query - TODO
        // timestamps - TODO

        const enc = cmd_encoder.cmd_buffer.command_buffer.renderCommandEncoderWithDescriptor(mtl_desc) orelse {
            return error.InvalidDescriptor;
        };

        if (desc.label) |label| {
            enc.setLabel(ns.String.stringWithUTF8String(label));
        }

        var encoder = try allocator.create(RenderPassEncoder);
        encoder.* = .{ .encoder = enc };
        return encoder;
    }

    pub fn deinit(encoder: *RenderPassEncoder) void {
        allocator.destroy(encoder);
    }

    pub fn setPipeline(encoder: *RenderPassEncoder, pipeline: *RenderPipeline) !void {
        encoder.encoder.setRenderPipelineState(pipeline.pipeline);
        encoder.encoder.setFrontFacingWinding(pipeline.winding);
        encoder.encoder.setCullMode(pipeline.cull_mode);
        if (pipeline.depth_stencil_state) |state| {
            encoder.encoder.setDepthStencilState(state);
            encoder.encoder.setDepthBias_slopeScale_clamp(
                pipeline.depth_bias,
                pipeline.depth_bias_slope_scale,
                pipeline.depth_bias_clamp,
            );
        }
        encoder.primitive_type = pipeline.primitive_type;
    }

    pub fn draw(encoder: *RenderPassEncoder, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void {
        encoder.encoder.drawPrimitives_vertexStart_vertexCount_instanceCount_baseInstance(
            encoder.primitive_type,
            first_vertex,
            vertex_count,
            instance_count,
            first_instance,
        );
    }

    pub fn end(encoder: *RenderPassEncoder) void {
        encoder.encoder.endEncoding();
    }
};

pub const CommandEncoder = struct {
    manager: utils.Manager(CommandEncoder) = .{},
    cmd_buffer: *CommandBuffer,

    pub fn init(device: *Device, desc: ?*const gpu.CommandEncoder.Descriptor) !*CommandEncoder {
        // TODO
        _ = desc;

        const cmd_buffer = try CommandBuffer.init(device);

        var encoder = try allocator.create(CommandEncoder);
        encoder.* = .{ .cmd_buffer = cmd_buffer };
        return encoder;
    }

    pub fn deinit(cmd_encoder: *CommandEncoder) void {
        allocator.destroy(cmd_encoder);
    }

    pub fn beginRenderPass(cmd_encoder: *CommandEncoder, desc: *const gpu.RenderPassDescriptor) !*RenderPassEncoder {
        return RenderPassEncoder.init(cmd_encoder, desc);
    }

    pub fn finish(cmd_encoder: *CommandEncoder, desc: *const gpu.CommandBuffer.Descriptor) !*CommandBuffer {
        // TODO
        _ = desc;
        return cmd_encoder.cmd_buffer;
    }
};

pub const CommandBuffer = struct {
    manager: utils.Manager(CommandBuffer) = .{},
    command_buffer: *mtl.CommandBuffer,

    pub fn init(device: *Device) !*CommandBuffer {
        const queue = try device.getQueue();
        var command_buffer = queue.command_queue.commandBuffer().?; // TODO

        var cmd_buffer = try allocator.create(CommandBuffer);
        cmd_buffer.* = .{ .command_buffer = command_buffer };
        return cmd_buffer;
    }

    pub fn deinit(cmd_buffer: *CommandBuffer) void {
        allocator.destroy(cmd_buffer);
    }
};

pub const Queue = struct {
    manager: utils.Manager(Queue) = .{},
    command_queue: *mtl.CommandQueue,

    pub fn init(device: *Device) !*Queue {
        const command_queue = device.device.newCommandQueue() orelse {
            return error.NoCommandQueue; // TODO
        };

        var queue = try allocator.create(Queue);
        queue.* = .{ .command_queue = command_queue };
        return queue;
    }

    pub fn deinit(queue: *Queue) void {
        queue.command_queue.release();
        allocator.destroy(queue);
    }

    pub fn submit(queue: *Queue, commands: []const *CommandBuffer) !void {
        _ = queue;
        for (commands) |commandBuffer| {
            commandBuffer.command_buffer.commit();
        }
    }
};

pub const ShaderModule = struct {
    manager: utils.Manager(ShaderModule) = .{},
    library: *mtl.Library,

    pub fn init(device: *Device, code: []const u8) !*ShaderModule {
        var err: ?*ns.Error = undefined;
        var source = ns.String.alloc().initWithBytesNoCopy_length_encoding_freeWhenDone(@constCast(code.ptr), code.len, ns.UTF8StringEncoding, false);
        var library = device.device.newLibraryWithSource_options_error(source, null, &err) orelse {
            std.log.err("{s}", .{err.?.localizedDescription().utf8String()});
            return error.InvalidDescriptor;
        };

        var module = try allocator.create(ShaderModule);
        module.* = .{ .library = library };
        return module;
    }

    pub fn deinit(shader_module: *ShaderModule) void {
        shader_module.library.release();
        allocator.destroy(shader_module);
    }
};

test "reference declarations" {
    std.testing.refAllDeclsRecursive(@This());
}
