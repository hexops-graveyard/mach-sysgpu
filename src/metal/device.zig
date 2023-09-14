const std = @import("std");
const gpu = @import("gpu");
const ca = @import("objc/ca.zig");
const mtl = @import("objc/mtl.zig");
const ns = @import("objc/ns.zig");
const conv = @import("conv.zig");
const utils = @import("../utils.zig");
const metal = @import("../metal.zig");
const Adapter = @import("instance.zig").Adapter;
const Surface = @import("instance.zig").Surface;

pub const Device = struct {
    manager: utils.Manager(Device) = .{},
    device: *mtl.Device,
    queue: ?*Queue = null,
    err_cb: ?gpu.ErrorCallback = null,
    err_cb_userdata: ?*anyopaque = null,

    pub fn init(adapter: *Adapter, desc: ?*const gpu.Device.Descriptor) !*Device {
        // TODO
        _ = desc;

        var device = try metal.allocator.create(Device);
        device.* = .{ .device = adapter.device };
        return device;
    }

    pub fn deinit(device: *Device) void {
        metal.allocator.destroy(device);
    }

    pub fn createShaderModule(device: *Device, code: []const u8) !*ShaderModule {
        return ShaderModule.init(device, code);
    }

    pub fn createRenderPipeline(device: *Device, desc: *const gpu.RenderPipeline.Descriptor) !*RenderPipeline {
        return RenderPipeline.init(device, desc);
    }

    pub fn createSwapChain(device: *Device, surface: *Surface, desc: *const gpu.SwapChain.Descriptor) !*SwapChain {
        return SwapChain.init(device, surface, desc);
    }

    pub fn createCommandEncoder(device: *Device, desc: *const gpu.CommandEncoder.Descriptor) !*CommandEncoder {
        return CommandEncoder.init(device, desc);
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
    texture_view: TextureView = .{ .texture = null },
    current_drawable: ?*ca.MetalDrawable = null,

    pub fn init(device: *Device, surface: *Surface, desc: *const gpu.SwapChain.Descriptor) !*SwapChain {
        // TODO
        _ = desc;

        surface.layer.setDevice(device.device);

        var swapchain = try metal.allocator.create(SwapChain);
        swapchain.* = .{ .device = device, .surface = surface };
        return swapchain;
    }

    pub fn deinit(swapchain: *SwapChain) void {
        metal.allocator.destroy(swapchain);
    }

    pub fn getCurrentTextureView(swapchain: *SwapChain) !*TextureView {
        swapchain.current_drawable = swapchain.surface.layer.nextDrawable();
        if (swapchain.current_drawable) |drawable| {
            swapchain.texture_view.texture = drawable.texture();
        } else {
            // TODO - handle no drawable
        }

        return &swapchain.texture_view;
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

pub const TextureView = struct {
    manager: utils.Manager(TextureView) = .{},
    texture: ?*mtl.Texture,

    pub fn deinit(view: *TextureView) void {
        metal.allocator.destroy(view);
    }
};

pub const RenderPipeline = struct {
    manager: utils.Manager(RenderPipeline) = .{},
    pipeline: *mtl.RenderPipelineState,

    pub fn init(device: *Device, desc: *const gpu.RenderPipeline.Descriptor) !*RenderPipeline {
        var mtl_desc = mtl.RenderPipelineDescriptor.alloc().init();
        defer mtl_desc.release();

        const vertex_module: *ShaderModule = @ptrCast(@alignCast(desc.vertex.module));
        const vertex_fn = vertex_module.library.newFunctionWithName(ns.String.stringWithUTF8String(desc.vertex.entry_point)) orelse {
            return error.InvalidDescriptor;
        };
        defer vertex_fn.release();
        mtl_desc.setVertexFunction(vertex_fn);

        if (desc.fragment) |frag| {
            const frag_module: *ShaderModule = @ptrCast(@alignCast(frag.module));
            const frag_fn = frag_module.library.newFunctionWithName(ns.String.stringWithUTF8String(frag.entry_point)) orelse {
                return error.InvalidDescriptor;
            };
            defer frag_fn.release();
            mtl_desc.setFragmentFunction(frag_fn);
        }

        mtl_desc.colorAttachments().objectAtIndexedSubscript(0).setPixelFormat(mtl.PixelFormatBGRA8Unorm_sRGB);

        var err: ?*ns.Error = undefined;
        const pipeline = device.device.newRenderPipelineStateWithDescriptor_error(mtl_desc, &err) orelse {
            // TODO
            std.log.err("{s}", .{err.?.localizedDescription().utf8String()});
            return error.InvalidDescriptor;
        };

        var render_pipeline = try metal.allocator.create(RenderPipeline);
        render_pipeline.* = .{ .pipeline = pipeline };
        return render_pipeline;
    }

    pub fn deinit(render_pipeline: *RenderPipeline) void {
        render_pipeline.pipeline.release();
        metal.allocator.destroy(render_pipeline);
    }
};

pub const RenderPassEncoder = struct {
    manager: utils.Manager(RenderPassEncoder) = .{},
    encoder: *mtl.RenderCommandEncoder,

    pub fn init(cmd_encoder: *CommandEncoder, descriptor: *const gpu.RenderPassDescriptor) !*RenderPassEncoder {
        const mtl_descriptor = mtl.RenderPassDescriptor.new();
        defer mtl_descriptor.release();

        for (descriptor.color_attachments.?[0..descriptor.color_attachment_count], 0..) |attach, i| {
            const view: *TextureView = @ptrCast(@alignCast(attach.view.?));
            const mtl_attach = mtl_descriptor.colorAttachments().objectAtIndexedSubscript(i);
            mtl_attach.setLoadAction(conv.metalLoadAction(attach.load_op));
            mtl_attach.setStoreAction(conv.metalStoreAction(attach.store_op));
            mtl_attach.setTexture(view.texture);

            if (attach.load_op == .clear) {
                mtl_attach.setClearColor(mtl.ClearColor.init(
                    @floatCast(attach.clear_value.r),
                    @floatCast(attach.clear_value.g),
                    @floatCast(attach.clear_value.b),
                    @floatCast(attach.clear_value.a),
                ));
            }
        }

        const enc = cmd_encoder.cmd_buffer.command_buffer.renderCommandEncoderWithDescriptor(mtl_descriptor) orelse {
            return error.InvalidDescriptor;
        };
        var encoder = try metal.allocator.create(RenderPassEncoder);
        encoder.* = .{ .encoder = enc };
        return encoder;
    }

    pub fn deinit(encoder: *RenderPassEncoder) void {
        metal.allocator.destroy(encoder);
    }

    pub fn setPipeline(encoder: *RenderPassEncoder, pipeline: *RenderPipeline) !void {
        encoder.encoder.setRenderPipelineState(pipeline.pipeline);
    }

    pub fn draw(encoder: *RenderPassEncoder, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void {
        encoder.encoder.drawPrimitives_vertexStart_vertexCount_instanceCount_baseInstance(mtl.PrimitiveTypeTriangle, first_vertex, vertex_count, instance_count, first_instance);
    }

    pub fn end(encoder: *RenderPassEncoder) void {
        encoder.encoder.endEncoding();
    }
};

pub const CommandEncoder = struct {
    manager: utils.Manager(CommandEncoder) = .{},
    cmd_buffer: CommandBuffer,

    pub fn init(device: *Device, desc: ?*const gpu.CommandEncoder.Descriptor) !*CommandEncoder {
        // TODO
        _ = desc;

        const queue = try device.getQueue();
        var command_buffer = queue.command_queue.commandBuffer().?; // TODO

        var encoder = try metal.allocator.create(CommandEncoder);
        encoder.* = .{ .cmd_buffer = .{ .command_buffer = command_buffer } };
        return encoder;
    }

    pub fn deinit(cmd_encoder: *CommandEncoder) void {
        metal.allocator.destroy(cmd_encoder);
    }

    pub fn beginRenderPass(cmd_encoder: *CommandEncoder, desc: *const gpu.RenderPassDescriptor) !*RenderPassEncoder {
        return RenderPassEncoder.init(cmd_encoder, desc);
    }

    pub fn finish(cmd_encoder: *CommandEncoder, desc: *const gpu.CommandBuffer.Descriptor) !*CommandBuffer {
        // TODO
        _ = desc;
        return &cmd_encoder.cmd_buffer;
    }
};

pub const CommandBuffer = struct {
    manager: utils.Manager(CommandBuffer) = .{},
    command_buffer: *mtl.CommandBuffer,

    pub fn deinit(cmd_buffer: *CommandBuffer) void {
        metal.allocator.destroy(cmd_buffer);
    }
};

pub const Queue = struct {
    manager: utils.Manager(Queue) = .{},
    command_queue: *mtl.CommandQueue,

    pub fn init(device: *Device) !*Queue {
        const command_queue = device.device.newCommandQueue() orelse {
            return error.NoCommandQueue; // TODO
        };

        var queue = try metal.allocator.create(Queue);
        queue.* = .{ .command_queue = command_queue };
        return queue;
    }

    pub fn deinit(queue: *Queue) void {
        queue.command_queue.release();
        metal.allocator.destroy(queue);
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
        var source = ns.String.alloc().initWithBytesNoCopy_length_encoding_freeWhenDone(code.ptr, code.len, ns.UTF8StringEncoding, false);
        var library = device.device.newLibraryWithSource_options_error(source, null, &err) orelse {
            std.log.err("{s}", .{err.?.localizedDescription().utf8String()});
            return error.InvalidDescriptor;
        };

        var module = try metal.allocator.create(ShaderModule);
        module.* = .{ .library = library };
        return module;
    }

    pub fn deinit(shader_module: *ShaderModule) void {
        shader_module.library.release();
        metal.allocator.destroy(shader_module);
    }
};
