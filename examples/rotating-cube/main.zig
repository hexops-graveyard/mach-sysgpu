const std = @import("std");
const builtin = @import("builtin");
const glfw = @import("glfw");
const gpu = @import("gpu");
const dusk = @import("dusk");
const objc = @import("../objc.zig");
const zm = @import("../zmath.zig");
const shader = @embedFile("shader.wgsl");
const Vertex = @import("cube_mesh.zig").Vertex;
const vertices = @import("cube_mesh.zig").vertices;

pub const GPUInterface = dusk.Interface;
// pub const GPUInterface = gpu.dawn.Interface;

fn baseLoader(_: u32, name: [*:0]const u8) ?*const fn () callconv(.C) void {
    return glfw.getInstanceProcAddress(null, name);
}

const UniformBufferObject = struct {
    mat: zm.Mat,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 10 }){};
    defer _ = gpa.deinit();

    // Initialize GLFW
    if (!glfw.init(.{})) {
        std.log.err("failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    }
    defer glfw.terminate();

    const hints = glfw.Window.Hints{ .client_api = .no_api, .cocoa_retina_framebuffer = true };
    const window = glfw.Window.create(640, 480, "Dusk Triangle", null, null, hints) orelse {
        std.log.err("failed to create GLFW window: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    };
    defer window.destroy();

    if (builtin.target.os.tag == .linux) try gpu.Impl.init(gpa.allocator(), .{ .baseLoader = @ptrCast(&baseLoader) });
    if (builtin.target.isDarwin()) try gpu.Impl.init(gpa.allocator(), .{});
    if (builtin.target.os.tag == .windows) try gpu.Impl.init(gpa.allocator(), .{});

    const instance = gpu.createInstance(null) orelse {
        std.log.err("failed to create GPU instance", .{});
        std.process.exit(1);
    };
    defer instance.release();

    const surface = createSurfaceForWindow(instance, window);
    defer surface.release();

    var response: RequestAdapterResponse = undefined;
    instance.requestAdapter(&gpu.RequestAdapterOptions{
        .compatible_surface = surface,
        .power_preference = .undefined,
        .force_fallback_adapter = .false,
    }, &response, requestAdapterCallback);
    if (response.status != .success) {
        std.log.err("failed to create GPU adapter: {s}", .{response.message.?});
        std.process.exit(1);
    }
    const adapter = response.adapter.?;
    defer adapter.release();

    var props = std.mem.zeroes(gpu.Adapter.Properties);
    adapter.getProperties(&props);
    std.log.info("found {s} backend on {s} adapter: {s}, {s}", .{
        props.backend_type.name(),
        props.adapter_type.name(),
        props.name,
        props.driver_description,
    });

    const device = adapter.createDevice(&.{
        .device_lost_callback = deviceLostCallback,
        .device_lost_userdata = null,
    }) orelse {
        std.log.err("failed to create GPU device", .{});
        std.process.exit(1);
    };
    defer device.release();
    defer device.setDeviceLostCallback(null, null);
    device.setUncapturedErrorCallback({}, uncapturedErrorCallback);

    const framebuffer_size = window.getFramebufferSize();
    var swapchain_desc = gpu.SwapChain.Descriptor{
        .label = "swap chain",
        .usage = .{ .render_attachment = true },
        .format = .bgra8_unorm,
        .width = framebuffer_size.width,
        .height = framebuffer_size.height,
        .present_mode = .mailbox,
    };
    var swap_chain = device.createSwapChain(surface, &swapchain_desc);
    defer swap_chain.release();

    var next_swapchain_desc = swapchain_desc;
    window.setUserPointer(&next_swapchain_desc);
    window.setFramebufferSizeCallback((struct {
        fn callback(win: glfw.Window, width: u32, height: u32) void {
            const next_descriptor = win.getUserPointer(gpu.SwapChain.Descriptor).?;
            next_descriptor.width = width;
            next_descriptor.height = height;
        }
    }).callback);

    const shader_module = device.createShaderModuleWGSL("shader", shader);
    defer shader_module.release();

    const vertex_attributes = [_]gpu.VertexAttribute{
        .{ .format = .float32x4, .offset = @offsetOf(Vertex, "pos"), .shader_location = 0 },
        .{ .format = .float32x2, .offset = @offsetOf(Vertex, "uv"), .shader_location = 1 },
    };
    const vertex_buffer_layout = gpu.VertexBufferLayout.init(.{
        .array_stride = @sizeOf(Vertex),
        .step_mode = .vertex,
        .attributes = &vertex_attributes,
    });

    const blend = gpu.BlendState{
        .color = .{ .dst_factor = .one },
        .alpha = .{ .dst_factor = .one },
    };
    const color_target = gpu.ColorTargetState{
        .format = swapchain_desc.format,
        .blend = &blend,
        .write_mask = gpu.ColorWriteMaskFlags.all,
    };
    const fragment = gpu.FragmentState.init(.{
        .module = shader_module,
        .entry_point = "fragment_main",
        .targets = &.{color_target},
    });

    const bgl = device.createBindGroupLayout(&gpu.BindGroupLayout.Descriptor.init(.{
        .entries = &.{
            gpu.BindGroupLayout.Entry.buffer(0, .{ .vertex = true }, .uniform, true, 0),
        },
    }));
    defer bgl.release();

    const bind_group_layouts = [_]*gpu.BindGroupLayout{bgl};
    const pipeline_layout = device.createPipelineLayout(&gpu.PipelineLayout.Descriptor.init(.{
        .bind_group_layouts = &bind_group_layouts,
    }));
    defer pipeline_layout.release();

    const pipeline_descriptor = gpu.RenderPipeline.Descriptor{
        .fragment = &fragment,
        .layout = pipeline_layout,
        .vertex = gpu.VertexState.init(.{
            .module = shader_module,
            .entry_point = "vertex_main",
            .buffers = &.{vertex_buffer_layout},
        }),
        .primitive = .{
            .cull_mode = .back,
        },
    };

    const vertex_buffer = device.createBuffer(&.{
        .usage = .{ .vertex = true },
        .size = @sizeOf(Vertex) * vertices.len,
        .mapped_at_creation = .true,
    });
    defer vertex_buffer.release();
    var vertex_mapped = vertex_buffer.getMappedRange(Vertex, 0, vertices.len);
    @memcpy(vertex_mapped.?, vertices[0..]);
    vertex_buffer.unmap();

    const uniform_buffer = device.createBuffer(&.{
        .usage = .{ .copy_dst = true, .uniform = true },
        .size = @sizeOf(UniformBufferObject),
        .mapped_at_creation = .false,
    });
    defer uniform_buffer.release();

    const bind_group = device.createBindGroup(
        &gpu.BindGroup.Descriptor.init(.{
            .layout = bgl,
            .entries = &.{
                gpu.BindGroup.Entry.buffer(0, uniform_buffer, 0, @sizeOf(UniformBufferObject)),
            },
        }),
    );
    defer bind_group.release();

    const pipeline = device.createRenderPipeline(&pipeline_descriptor);
    defer pipeline.release();

    const queue = device.getQueue();
    defer queue.release();

    var timer = try std.time.Timer.start();
    var rotate_timer = try std.time.Timer.start();
    var frames: u32 = 0;
    var seconds: u32 = 0;

    while (!window.shouldClose()) {
        const pool = if (comptime builtin.target.isDarwin()) try objc.AutoReleasePool.init() else undefined;
        defer if (comptime builtin.target.isDarwin()) objc.AutoReleasePool.release(pool);

        if (swapchain_desc.width != next_swapchain_desc.width or
            swapchain_desc.height != next_swapchain_desc.height)
        {
            swap_chain.release();
            swap_chain = device.createSwapChain(surface, &next_swapchain_desc);
            swapchain_desc = next_swapchain_desc;
        }

        const back_buffer_view = swap_chain.getCurrentTextureView().?;
        const color_attachment = gpu.RenderPassColorAttachment{
            .view = back_buffer_view,
            .resolve_target = null,
            .clear_value = .{ .r = 0, .g = 0, .b = 0, .a = 0 },
            .load_op = .clear,
            .store_op = .store,
        };

        {
            const time = @as(f32, @floatFromInt(rotate_timer.read())) / @as(f32, @floatFromInt(std.time.ns_per_s));
            const model = zm.mul(zm.rotationX(time * (std.math.pi / 2.0)), zm.rotationZ(time * (std.math.pi / 2.0)));
            const view = zm.lookAtRh(
                zm.Vec{ 0, 4, 2, 1 },
                zm.Vec{ 0, 0, 0, 1 },
                zm.Vec{ 0, 0, 1, 0 },
            );
            const proj = zm.perspectiveFovRh(
                (std.math.pi / 4.0),
                @as(f32, @floatFromInt(swapchain_desc.width)) / @as(f32, @floatFromInt(swapchain_desc.height)),
                0.1,
                10,
            );
            const mvp = zm.mul(zm.mul(model, view), proj);
            const ubo = UniformBufferObject{
                .mat = zm.transpose(mvp),
            };
            queue.writeBuffer(uniform_buffer, 0, &[_]UniformBufferObject{ubo});
        }

        const encoder = device.createCommandEncoder(null);
        const render_pass_info = gpu.RenderPassDescriptor.init(.{ .color_attachments = &.{color_attachment} });
        const pass = encoder.beginRenderPass(&render_pass_info);
        pass.setPipeline(pipeline);
        pass.setVertexBuffer(0, vertex_buffer, 0, @sizeOf(Vertex) * vertices.len);
        pass.setBindGroup(0, bind_group, &.{0});
        pass.draw(vertices.len, 1, 0, 0);
        pass.end();
        pass.release();

        var command = encoder.finish(null);
        encoder.release();

        queue.submit(&[_]*gpu.CommandBuffer{command});
        command.release();
        swap_chain.present();
        back_buffer_view.release();

        glfw.pollEvents();
        window.swapBuffers();

        if (timer.read() >= std.time.ns_per_s) {
            timer.reset();
            var buf: [12]u8 = undefined;
            const title = try std.fmt.bufPrintZ(&buf, "FPS: {d}", .{frames});
            window.setTitle(title);
            frames = 0;
            seconds += 1;
            if (seconds >= 30) break;
        }
        frames += 1;
    }
}

pub fn createSurfaceForWindow(instance: *gpu.Instance, window: glfw.Window) *gpu.Surface {
    const glfw_options: glfw.BackendOptions = switch (builtin.target.os.tag) {
        .windows => .{ .win32 = true },
        .linux => .{ .x11 = true, .wayland = true },
        else => if (comptime builtin.target.isDarwin()) .{ .cocoa = true } else .{},
    };
    const glfw_native = glfw.Native(glfw_options);

    const extension = if (glfw_options.win32) gpu.Surface.Descriptor.NextInChain{
        .from_windows_hwnd = &.{
            .hinstance = std.os.windows.kernel32.GetModuleHandleW(null).?,
            .hwnd = glfw_native.getWin32Window(window),
        },
    } else if (glfw_options.x11) gpu.Surface.Descriptor.NextInChain{
        .from_xlib_window = &.{
            .display = glfw_native.getX11Display(),
            .window = glfw_native.getX11Window(window),
        },
    } else if (glfw_options.wayland) gpu.Surface.Descriptor.NextInChain{
        .from_wayland_window = &.{
            .display = glfw_native.getWaylandDisplay(),
            .surface = glfw_native.getWaylandWindow(window),
        },
    } else if (glfw_options.cocoa) blk: {
        const ns_window = glfw_native.getCocoaWindow(window);
        const ns_view = objc.msgSend(ns_window, "contentView", .{}, *anyopaque); // [nsWindow contentView]

        // Create a CAMetalLayer that covers the whole window that will be passed to CreateSurface.
        objc.msgSend(ns_view, "setWantsLayer:", .{true}, void); // [view setWantsLayer:YES]
        const layer = objc.msgSend(objc.objc_getClass("CAMetalLayer"), "layer", .{}, ?*anyopaque); // [CAMetalLayer layer]
        if (layer == null) @panic("failed to create Metal layer");
        objc.msgSend(ns_view, "setLayer:", .{layer.?}, void); // [view setLayer:layer]

        // Use retina if the window was created with retina support.
        const scale_factor = objc.msgSend(ns_window, "backingScaleFactor", .{}, f64); // [ns_window backingScaleFactor]
        objc.msgSend(layer.?, "setContentsScale:", .{scale_factor}, void); // [layer setContentsScale:scale_factor]

        break :blk gpu.Surface.Descriptor.NextInChain{ .from_metal_layer = &.{ .layer = layer.? } };
    } else unreachable;

    return instance.createSurface(&gpu.Surface.Descriptor{ .next_in_chain = extension });
}

const RequestAdapterResponse = struct {
    status: gpu.RequestAdapterStatus,
    adapter: ?*gpu.Adapter,
    message: ?[*:0]const u8,
};

inline fn requestAdapterCallback(
    context: *RequestAdapterResponse,
    status: gpu.RequestAdapterStatus,
    adapter: ?*gpu.Adapter,
    message: ?[*:0]const u8,
) void {
    context.* = RequestAdapterResponse{
        .status = status,
        .adapter = adapter,
        .message = message,
    };
}

inline fn uncapturedErrorCallback(_: void, typ: gpu.ErrorType, message: [*:0]const u8) void {
    switch (typ) {
        .validation => std.log.err("gpu: validation error: {s}\n", .{message}),
        .out_of_memory => std.log.err("gpu: out of memory: {s}\n", .{message}),
        .device_lost => std.log.err("gpu: device lost: {s}\n", .{message}),
        .unknown => std.log.err("gpu: unknown error: {s}\n", .{message}),
        else => unreachable,
    }
    std.process.exit(1);
}

fn deviceLostCallback(reason: gpu.Device.LostReason, message: [*:0]const u8, userdata: ?*anyopaque) callconv(.C) void {
    _ = userdata;
    std.log.err("device lost: {} - {s}", .{ reason, message });
}
