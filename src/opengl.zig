const std = @import("std");
const dgpu = @import("dgpu/main.zig");
const limits = @import("limits.zig");
const utils = @import("utils.zig");
const shader = @import("shader.zig");
const c = @import("opengl/c.zig");
const conv = @import("opengl/conv.zig");
const proc = @import("opengl/proc.zig");

const log = std.log.scoped(.opengl);

const instance_class_name = "sysgpu-hwnd";
const max_back_buffer_count = 3;

var allocator: std.mem.Allocator = undefined;

pub const InitOptions = struct {};

pub fn init(alloc: std.mem.Allocator, options: InitOptions) !void {
    _ = options;
    allocator = alloc;
}

const ActiveContext = struct {
    old_hdc: c.HDC,
    old_hglrc: c.HGLRC,

    pub fn init(hdc: c.HDC, hglrc: c.HGLRC) !ActiveContext {
        const old_hdc = c.wglGetCurrentDC();
        const old_hglrc = c.wglGetCurrentContext();

        if (c.wglMakeCurrent(hdc, hglrc) == c.FALSE)
            return error.wglMakeCurrentFailed;
        return .{ .old_hdc = old_hdc, .old_hglrc = old_hglrc };
    }

    pub fn deinit(ctx: *ActiveContext) void {
        _ = c.wglMakeCurrent(ctx.old_hdc, ctx.old_hglrc);
    }
};

fn createDummyWindow() c.HWND {
    const hinstance = c.GetModuleHandleA(null);
    const dwExStyle = c.WS_EX_OVERLAPPEDWINDOW;
    const dwStyle = c.WS_CLIPSIBLINGS | c.WS_CLIPCHILDREN;

    return c.CreateWindowExA(
        dwExStyle,
        instance_class_name,
        instance_class_name,
        dwStyle,
        0,
        0,
        640,
        480,
        null,
        null,
        hinstance,
        null,
    );
}

fn setPixelFormat(wgl: *proc.InstanceWGL, hwnd: c.HWND) !c_int {
    const hdc = c.GetDC(hwnd);

    const format_attribs = [_]c_int{
        c.WGL_DRAW_TO_WINDOW_ARB, c.GL_TRUE,
        c.WGL_SUPPORT_OPENGL_ARB, c.GL_TRUE,
        c.WGL_DOUBLE_BUFFER_ARB,  c.GL_TRUE,
        c.WGL_PIXEL_TYPE_ARB,     c.WGL_TYPE_RGBA_ARB,
        c.WGL_COLOR_BITS_ARB,     32,
        0,
    };

    var num_formats: c_uint = undefined;
    var pixel_format: c_int = undefined;
    if (wgl.ChoosePixelFormatARB(hdc, &format_attribs, null, 1, &pixel_format, &num_formats) == c.FALSE)
        return error.ChoosePixelFormatARBFailed;
    if (num_formats == 0)
        return error.NoFormatsAvailable;

    var pfd: c.PIXELFORMATDESCRIPTOR = undefined;
    if (c.DescribePixelFormat(hdc, pixel_format, @sizeOf(@TypeOf(pfd)), &pfd) == c.FALSE)
        return error.DescribePixelFormatFailed;

    if (c.SetPixelFormat(hdc, pixel_format, &pfd) == c.FALSE)
        return error.SetPixelFormatFailed;

    return pixel_format;
}

fn messageCallback(
    source: c.GLenum,
    message_type: c.GLenum,
    id: c.GLuint,
    severity: c.GLenum,
    length: c.GLsizei,
    message: [*c]const c.GLchar,
    user_data: ?*const anyopaque,
) callconv(.C) void {
    _ = source;
    _ = id;
    _ = length;
    _ = user_data;
    std.debug.print("GL CALLBACK: {s} type = 0x{x}, severity = 0x{x}, message = {s}\n", .{
        if (message_type == c.GL_DEBUG_TYPE_ERROR) "** GL ERROR **" else "",
        message_type,
        severity,
        message,
    });
}

fn checkError(gl: *proc.DeviceGL) void {
    const err = gl.GetError();
    if (err != c.GL_NO_ERROR) {
        std.debug.print("glGetError {x}\n", .{err});
    }
}

pub const Instance = struct {
    manager: utils.Manager(Instance) = .{},
    wgl: proc.InstanceWGL,

    pub fn init(desc: *const dgpu.Instance.Descriptor) !*Instance {
        // TODO
        _ = desc;

        // WNDCLASS
        const hinstance = c.GetModuleHandleA(null);
        const wc: c.WNDCLASSA = .{
            .lpfnWndProc = c.DefWindowProcA,
            .hInstance = hinstance,
            .lpszClassName = instance_class_name,
            .style = c.CS_OWNDC,
        };
        if (c.RegisterClassA(&wc) == 0)
            return error.RegisterClassFailed;

        // Dummy context
        const hwnd = createDummyWindow();
        const hdc = c.GetDC(hwnd);

        const pfd = c.PIXELFORMATDESCRIPTOR{
            .nSize = @sizeOf(c.PIXELFORMATDESCRIPTOR),
            .nVersion = 1,
            .dwFlags = c.PFD_DRAW_TO_WINDOW | c.PFD_SUPPORT_OPENGL | c.PFD_DOUBLEBUFFER,
            .iPixelType = c.PFD_TYPE_RGBA,
            .cColorBits = 32,
            .iLayerType = c.PFD_MAIN_PLANE,
        };
        const pixel_format = c.ChoosePixelFormat(hdc, &pfd);
        if (c.SetPixelFormat(hdc, pixel_format, &pfd) == c.FALSE)
            return error.SetPixelFormatFailed;

        const hglrc = c.wglCreateContext(hdc);
        if (hglrc == null)
            return error.wglCreateContextFailed;
        defer _ = c.wglDeleteContext(hglrc);

        // Extension procs
        try proc.init();

        var ctx = try ActiveContext.init(hdc, hglrc);
        defer ctx.deinit();

        var wgl: proc.InstanceWGL = undefined;
        wgl.load();

        // Result
        var instance = try allocator.create(Instance);
        instance.* = .{
            .wgl = wgl,
        };
        return instance;
    }

    pub fn deinit(instance: *Instance) void {
        const hinstance = c.GetModuleHandleA(null);

        proc.deinit();
        _ = c.UnregisterClassA(instance_class_name, hinstance);

        allocator.destroy(instance);
    }

    pub fn createSurface(instance: *Instance, desc: *const dgpu.Surface.Descriptor) !*Surface {
        return Surface.init(instance, desc);
    }
};

pub const Adapter = struct {
    manager: utils.Manager(Adapter) = .{},
    hwnd: ?c.HWND,
    hdc: c.HDC,
    hglrc: c.HGLRC,
    pixel_format: c_int,
    vendor: [*c]const c.GLubyte,
    renderer: [*c]const c.GLubyte,
    version: [*c]const c.GLubyte,

    pub fn init(instance: *Instance, options: *const dgpu.RequestAdapterOptions) !*Adapter {
        const wgl = &instance.wgl;

        // Use hwnd from surface is provided
        var hwnd: c.HWND = undefined;
        var pixel_format: c_int = undefined;
        if (options.compatible_surface) |surface_raw| {
            const surface: *Surface = @ptrCast(@alignCast(surface_raw));

            hwnd = surface.hwnd;
            pixel_format = surface.pixel_format;
        } else {
            hwnd = createDummyWindow();
            pixel_format = try setPixelFormat(wgl, hwnd);
        }

        // GL context
        const hdc = c.GetDC(hwnd);
        if (hdc == null)
            return error.GetDCFailed;

        const context_attribs = [_]c_int{
            c.WGL_CONTEXT_MAJOR_VERSION_ARB, 4,
            c.WGL_CONTEXT_MINOR_VERSION_ARB, 5,
            c.WGL_CONTEXT_FLAGS_ARB,         c.WGL_CONTEXT_DEBUG_BIT_ARB,
            c.WGL_CONTEXT_PROFILE_MASK_ARB,  c.WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
            0,
        };

        const hglrc = wgl.CreateContextAttribsARB(hdc, null, &context_attribs);
        if (hglrc == null)
            return error.wglCreateContextFailed;

        var ctx = try ActiveContext.init(hdc, hglrc);
        defer ctx.deinit();

        var gl: proc.AdapterGL = undefined;
        gl.load();

        const vendor = gl.GetString(c.GL_VENDOR);
        const renderer = gl.GetString(c.GL_RENDERER);
        const version = gl.GetString(c.GL_VERSION);

        // Result
        var adapter = try allocator.create(Adapter);
        adapter.* = .{
            .hwnd = if (options.compatible_surface == null) hwnd else null,
            .hdc = hdc,
            .pixel_format = pixel_format,
            .hglrc = hglrc,
            .vendor = vendor,
            .renderer = renderer,
            .version = version,
        };
        return adapter;
    }

    pub fn deinit(adapter: *Adapter) void {
        _ = c.wglDeleteContext(adapter.hglrc);
        if (adapter.hwnd) |hwnd| _ = c.DestroyWindow(hwnd);
        allocator.destroy(adapter);
    }

    pub fn createDevice(adapter: *Adapter, desc: ?*const dgpu.Device.Descriptor) !*Device {
        return Device.init(adapter, desc);
    }

    pub fn getProperties(adapter: *Adapter) dgpu.Adapter.Properties {
        return .{
            .vendor_id = 0, // TODO
            .vendor_name = adapter.vendor,
            .architecture = adapter.renderer,
            .device_id = 0, // TODO
            .name = adapter.vendor, // TODO
            .driver_description = adapter.version,
            .adapter_type = .unknown,
            .backend_type = .opengl,
            .compatibility_mode = .false,
        };
    }
};

pub const Surface = struct {
    manager: utils.Manager(Surface) = .{},
    hwnd: c.HWND,
    pixel_format: c_int,

    pub fn init(instance: *Instance, desc: *const dgpu.Surface.Descriptor) !*Surface {
        const wgl = &instance.wgl;

        if (utils.findChained(dgpu.Surface.DescriptorFromWindowsHWND, desc.next_in_chain.generic)) |win_desc| {
            // workaround issues with @alignCast panicking as HWND is not a real pointer
            var hwnd: c.HWND = undefined;
            @memcpy(std.mem.asBytes(&hwnd), std.mem.asBytes(&win_desc.hwnd));

            const pixel_format = try setPixelFormat(wgl, hwnd);

            var surface = try allocator.create(Surface);
            surface.* = .{
                .hwnd = hwnd,
                .pixel_format = pixel_format,
            };
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
    queue: *Queue,
    hdc: c.HDC,
    hglrc: c.HGLRC,
    pixel_format: c_int,
    gl: proc.DeviceGL,
    vao: c.GLuint,

    lost_cb: ?dgpu.Device.LostCallback = null,
    lost_cb_userdata: ?*anyopaque = null,
    log_cb: ?dgpu.LoggingCallback = null,
    log_cb_userdata: ?*anyopaque = null,
    err_cb: ?dgpu.ErrorCallback = null,
    err_cb_userdata: ?*anyopaque = null,

    pub fn init(adapter: *Adapter, desc: ?*const dgpu.Device.Descriptor) !*Device {
        // TODO
        _ = desc;

        var ctx = try ActiveContext.init(adapter.hdc, adapter.hglrc);
        defer ctx.deinit();

        var gl: proc.DeviceGL = undefined;
        gl.loadVersion(4, 5);

        gl.Enable(c.GL_DEBUG_OUTPUT);
        gl.DebugMessageCallback(messageCallback, null);

        var vao: c.GLuint = undefined;
        gl.GenVertexArrays(1, &vao);
        gl.BindVertexArray(vao);

        const queue = try allocator.create(Queue);
        errdefer allocator.destroy(queue);

        var device = try allocator.create(Device);
        device.* = .{
            .queue = queue,
            .hdc = adapter.hdc,
            .hglrc = adapter.hglrc,
            .pixel_format = adapter.pixel_format,
            .gl = gl,
            .vao = vao,
        };
        return device;
    }

    pub fn deinit(device: *Device) void {
        if (device.lost_cb) |lost_cb| {
            lost_cb(.destroyed, "Device was destroyed.", device.lost_cb_userdata);
        }

        const gl = &device.gl;
        var ctx = ActiveContext.init(device.hdc, device.hglrc) catch @panic("ActiveContext failed");
        defer ctx.deinit();

        gl.DeleteVertexArrays(1, &device.vao);

        device.queue.manager.release();
        allocator.destroy(device.queue);
        allocator.destroy(device);
    }

    pub fn createBindGroup(device: *Device, desc: *const dgpu.BindGroup.Descriptor) !*BindGroup {
        return BindGroup.init(device, desc);
    }

    pub fn createBindGroupLayout(device: *Device, desc: *const dgpu.BindGroupLayout.Descriptor) !*BindGroupLayout {
        return BindGroupLayout.init(device, desc);
    }

    pub fn createBuffer(device: *Device, desc: *const dgpu.Buffer.Descriptor) !*Buffer {
        return Buffer.init(device, desc);
    }

    pub fn createCommandEncoder(device: *Device, desc: *const dgpu.CommandEncoder.Descriptor) !*CommandEncoder {
        return CommandEncoder.init(device, desc);
    }

    pub fn createComputePipeline(device: *Device, desc: *const dgpu.ComputePipeline.Descriptor) !*ComputePipeline {
        return ComputePipeline.init(device, desc);
    }

    pub fn createPipelineLayout(device: *Device, desc: *const dgpu.PipelineLayout.Descriptor) !*PipelineLayout {
        return PipelineLayout.init(device, desc);
    }

    pub fn createRenderPipeline(device: *Device, desc: *const dgpu.RenderPipeline.Descriptor) !*RenderPipeline {
        return RenderPipeline.init(device, desc);
    }

    pub fn createSampler(device: *Device, desc: *const dgpu.Sampler.Descriptor) !*Sampler {
        return Sampler.init(device, desc);
    }

    pub fn createShaderModuleAir(device: *Device, air: *shader.Air) !*ShaderModule {
        return ShaderModule.initAir(device, air);
    }

    pub fn createShaderModuleSpirv(device: *Device, code: []const u8) !*ShaderModule {
        _ = code;
        _ = device;
        return error.unsupported;
    }

    pub fn createSwapChain(device: *Device, surface: *Surface, desc: *const dgpu.SwapChain.Descriptor) !*SwapChain {
        return SwapChain.init(device, surface, desc);
    }

    pub fn createTexture(device: *Device, desc: *const dgpu.Texture.Descriptor) !*Texture {
        return Texture.init(device, desc);
    }

    pub fn getQueue(device: *Device) !*Queue {
        return device.queue;
    }

    pub fn tick(device: *Device) !void {
        device.processQueuedOperations();
    }

    // Internal
    pub fn processQueuedOperations(device: *Device) void {
        _ = device;
    }
};

pub const SwapChain = struct {
    manager: utils.Manager(SwapChain) = .{},
    device: *Device,
    hdc: c.HDC,
    pixel_format: c_int,
    back_buffer_count: u32,
    textures: [max_back_buffer_count]*Texture,
    views: [max_back_buffer_count]*TextureView,

    pub fn init(device: *Device, surface: *Surface, desc: *const dgpu.SwapChain.Descriptor) !*SwapChain {
        var swapchain = try allocator.create(SwapChain);

        const back_buffer_count: u32 = if (desc.present_mode == .mailbox) 3 else 2;

        var textures = std.BoundedArray(*Texture, max_back_buffer_count){};
        var views = std.BoundedArray(*TextureView, max_back_buffer_count){};
        errdefer {
            for (views.slice()) |view| view.manager.release();
            for (textures.slice()) |texture| texture.manager.release();
        }

        for (0..back_buffer_count) |_| {
            const texture = try Texture.initForSwapChain(device, desc, swapchain);
            const view = try texture.createView(&dgpu.TextureView.Descriptor{});

            textures.appendAssumeCapacity(texture);
            views.appendAssumeCapacity(view);
        }

        swapchain.* = .{
            .device = device,
            .hdc = c.GetDC(surface.hwnd),
            .pixel_format = surface.pixel_format,
            .back_buffer_count = back_buffer_count,
            .textures = textures.buffer,
            .views = views.buffer,
        };
        return swapchain;
    }

    pub fn deinit(swapchain: *SwapChain) void {
        for (swapchain.views[0..swapchain.back_buffer_count]) |view| view.manager.release();
        for (swapchain.textures[0..swapchain.back_buffer_count]) |texture| texture.manager.release();
        allocator.destroy(swapchain);
    }

    pub fn getCurrentTextureView(swapchain: *SwapChain) !*TextureView {
        const index = 0;
        // TEMP - resolve reference tracking in main.zig
        swapchain.views[index].manager.reference();
        return swapchain.views[index];
    }

    pub fn present(swapchain: *SwapChain) !void {
        const device = swapchain.device;
        var ctx = try ActiveContext.init(swapchain.hdc, device.hglrc);
        defer ctx.deinit();

        if (c.SwapBuffers(swapchain.hdc) == c.FALSE)
            return error.SwapBuffersFailed;
    }
};

pub const Buffer = struct {
    manager: utils.Manager(Buffer) = .{},
    // TODO - packed buffer descriptor struct
    size: u64,
    usage: dgpu.Buffer.UsageFlags,

    pub fn init(device: *Device, desc: *const dgpu.Buffer.Descriptor) !*Buffer {
        _ = device;
        var buffer = try allocator.create(Buffer);
        buffer.* = .{
            .size = desc.size,
            .usage = desc.usage,
        };
        return buffer;
    }

    pub fn deinit(buffer: *Buffer) void {
        allocator.destroy(buffer);
    }

    pub fn getMappedRange(buffer: *Buffer, offset: usize, size: usize) !?*anyopaque {
        _ = size;
        _ = offset;
        _ = buffer;
        return null;
    }

    pub fn getSize(buffer: *Buffer) u64 {
        return buffer.size;
    }

    pub fn getUsage(buffer: *Buffer) dgpu.Buffer.UsageFlags {
        return buffer.usage;
    }

    pub fn mapAsync(buffer: *Buffer, mode: dgpu.MapModeFlags, offset: usize, size: usize, callback: dgpu.Buffer.MapCallback, userdata: ?*anyopaque) !void {
        _ = userdata;
        _ = callback;
        _ = buffer;
        _ = size;
        _ = offset;
        _ = mode;
    }

    pub fn setLabel(buffer: *Buffer, label: [*:0]const u8) void {
        _ = label;
        _ = buffer;
    }

    pub fn unmap(buffer: *Buffer) !void {
        _ = buffer;
    }
};

pub const Texture = struct {
    manager: utils.Manager(Texture) = .{},
    swapchain: ?*SwapChain = null,

    pub fn init(device: *Device, desc: *const dgpu.Texture.Descriptor) !*Texture {
        _ = desc;
        _ = device;

        var texture = try allocator.create(Texture);
        texture.* = .{
            .swapchain = null,
        };
        return texture;
    }

    pub fn initForSwapChain(device: *Device, desc: *const dgpu.SwapChain.Descriptor, swapchain: *SwapChain) !*Texture {
        _ = desc;
        _ = device;

        var texture = try allocator.create(Texture);
        texture.* = .{
            .swapchain = swapchain,
        };
        return texture;
    }

    pub fn deinit(texture: *Texture) void {
        allocator.destroy(texture);
    }

    pub fn createView(texture: *Texture, desc: *const dgpu.TextureView.Descriptor) !*TextureView {
        return TextureView.init(texture, desc);
    }
};

pub const TextureView = struct {
    manager: utils.Manager(TextureView) = .{},
    texture: *Texture,

    pub fn init(texture: *Texture, desc: *const dgpu.TextureView.Descriptor) !*TextureView {
        _ = desc;

        texture.manager.reference();

        var view = try allocator.create(TextureView);
        view.* = .{
            .texture = texture,
        };
        return view;
    }

    pub fn deinit(view: *TextureView) void {
        view.texture.manager.release();
        allocator.destroy(view);
    }
};

pub const Sampler = struct {
    manager: utils.Manager(TextureView) = .{},

    pub fn init(device: *Device, desc: *const dgpu.Sampler.Descriptor) !*Sampler {
        _ = desc;
        _ = device;

        var sampler = try allocator.create(Sampler);
        sampler.* = .{};
        return sampler;
    }

    pub fn deinit(sampler: *Sampler) void {
        allocator.destroy(sampler);
    }
};

pub const BindGroupLayout = struct {
    manager: utils.Manager(BindGroupLayout) = .{},

    pub fn init(device: *Device, descriptor: *const dgpu.BindGroupLayout.Descriptor) !*BindGroupLayout {
        _ = descriptor;
        _ = device;

        var layout = try allocator.create(BindGroupLayout);
        layout.* = .{};
        return layout;
    }

    pub fn deinit(layout: *BindGroupLayout) void {
        allocator.destroy(layout);
    }
};

pub const BindGroup = struct {
    manager: utils.Manager(BindGroup) = .{},

    pub fn init(device: *Device, desc: *const dgpu.BindGroup.Descriptor) !*BindGroup {
        _ = desc;
        _ = device;

        var group = try allocator.create(BindGroup);
        group.* = .{};
        return group;
    }

    pub fn deinit(group: *BindGroup) void {
        allocator.destroy(group);
    }
};

pub const PipelineLayout = struct {
    manager: utils.Manager(PipelineLayout) = .{},
    group_layouts: []*BindGroupLayout,

    pub fn init(device: *Device, desc: *const dgpu.PipelineLayout.Descriptor) !*PipelineLayout {
        _ = device;

        var group_layouts = try allocator.alloc(*BindGroupLayout, desc.bind_group_layout_count);
        errdefer allocator.free(group_layouts);

        for (0..desc.bind_group_layout_count) |i| {
            const layout: *BindGroupLayout = @ptrCast(@alignCast(desc.bind_group_layouts.?[i]));
            layout.manager.reference();
            group_layouts[i] = layout;
        }

        var layout = try allocator.create(PipelineLayout);
        layout.* = .{
            .group_layouts = group_layouts,
        };
        return layout;
    }

    pub fn initDefault(device: *Device, default_pipeline_layout: utils.DefaultPipelineLayoutDescriptor) !*PipelineLayout {
        const groups = default_pipeline_layout.groups;
        var bind_group_layouts = std.BoundedArray(*dgpu.BindGroupLayout, limits.max_bind_groups){};
        defer {
            for (bind_group_layouts.slice()) |bind_group_layout_raw| {
                const bind_group_layout: *BindGroupLayout = @ptrCast(@alignCast(bind_group_layout_raw));
                bind_group_layout.manager.release();
            }
        }

        for (groups.slice()) |entries| {
            const bind_group_layout = try device.createBindGroupLayout(
                &dgpu.BindGroupLayout.Descriptor.init(.{ .entries = entries.items }),
            );
            bind_group_layouts.appendAssumeCapacity(@ptrCast(bind_group_layout));
        }

        return device.createPipelineLayout(
            &dgpu.PipelineLayout.Descriptor.init(.{ .bind_group_layouts = bind_group_layouts.slice() }),
        );
    }

    pub fn deinit(layout: *PipelineLayout) void {
        for (layout.group_layouts) |group_layout| group_layout.manager.release();

        allocator.free(layout.group_layouts);
        allocator.destroy(layout);
    }
};

pub const ShaderModule = struct {
    manager: utils.Manager(ShaderModule) = .{},
    device: *Device,
    air: *shader.Air,

    pub fn initAir(device: *Device, air: *shader.Air) !*ShaderModule {
        var module = try allocator.create(ShaderModule);
        module.* = .{
            .device = device,
            .air = air,
        };
        return module;
    }

    pub fn deinit(shader_module: *ShaderModule) void {
        shader_module.air.deinit(allocator);
        allocator.destroy(shader_module.air);
        allocator.destroy(shader_module);
    }

    pub fn compile(module: *ShaderModule, entrypoint: [*:0]const u8, shader_type: c.GLenum) !c.GLuint {
        const gl = &module.device.gl;

        const code_span = try shader.CodeGen.generate(allocator, module.air, .glsl, .{ .emit_source_file = "" }, entrypoint);
        defer allocator.free(code_span);
        const code_ptr = try allocator.dupeZ(u8, code_span);
        defer allocator.free(code_ptr);

        //std.debug.print("{s}\n", .{code_span});

        const gl_shader = gl.CreateShader(shader_type);
        if (gl_shader == 0)
            return error.CreateShaderFailed;

        gl.ShaderSource(gl_shader, 1, @ptrCast(&code_ptr), null);
        gl.CompileShader(gl_shader);

        var success: c.GLint = undefined;
        gl.GetShaderiv(gl_shader, c.GL_COMPILE_STATUS, &success);
        if (success == c.GL_FALSE) {
            var info_log: [512]c.GLchar = undefined;
            gl.GetShaderInfoLog(gl_shader, @sizeOf(@TypeOf(info_log)), null, &info_log);
            std.debug.print("Compilation Failed {s}\n", .{@as([*:0]u8, @ptrCast(&info_log))});
            return error.CompilationFailed;
        }

        return gl_shader;
    }
};

pub const ComputePipeline = struct {
    manager: utils.Manager(ComputePipeline) = .{},
    layout: *PipelineLayout,

    pub fn init(device: *Device, desc: *const dgpu.ComputePipeline.Descriptor) !*ComputePipeline {
        // Shaders
        const compute_module: *ShaderModule = @ptrCast(@alignCast(desc.compute.module));

        // Pipeline Layout
        var layout: *PipelineLayout = undefined;
        if (desc.layout) |l| {
            layout = @ptrCast(@alignCast(l));
            layout.manager.reference();
        } else {
            var layout_desc = utils.DefaultPipelineLayoutDescriptor.init(allocator);
            defer layout_desc.deinit();

            try layout_desc.addFunction(compute_module.air, .{ .compute = true }, desc.compute.entry_point);
            layout = try PipelineLayout.initDefault(device, layout_desc);
        }

        // Result
        var pipeline = try allocator.create(ComputePipeline);
        pipeline.* = .{
            .layout = layout,
        };
        return pipeline;
    }

    pub fn deinit(pipeline: *ComputePipeline) void {
        pipeline.layout.manager.release();
        allocator.destroy(pipeline);
    }

    pub fn getBindGroupLayout(pipeline: *ComputePipeline, group_index: u32) *BindGroupLayout {
        return @ptrCast(pipeline.layout.group_layouts[group_index]);
    }
};

pub const RenderPipeline = struct {
    manager: utils.Manager(RenderPipeline) = .{},
    device: *Device,
    program: c.GLuint,
    layout: *PipelineLayout,

    pub fn init(device: *Device, desc: *const dgpu.RenderPipeline.Descriptor) !*RenderPipeline {
        const gl = &device.gl;
        var ctx = try ActiveContext.init(device.hdc, device.hglrc);
        defer ctx.deinit();

        // Shaders
        const vertex_module: *ShaderModule = @ptrCast(@alignCast(desc.vertex.module));
        const vertex_shader = try vertex_module.compile(desc.vertex.entry_point, c.GL_VERTEX_SHADER);
        defer gl.DeleteShader(vertex_shader);

        var opt_fragment_shader: ?c.GLuint = null;
        if (desc.fragment) |frag| {
            const frag_module: *ShaderModule = @ptrCast(@alignCast(frag.module));
            opt_fragment_shader = try frag_module.compile(frag.entry_point, c.GL_FRAGMENT_SHADER);
        }
        defer if (opt_fragment_shader) |fragment_shader| gl.DeleteShader(fragment_shader);

        // Pipeline Layout
        var layout: *PipelineLayout = undefined;
        if (desc.layout) |l| {
            layout = @ptrCast(@alignCast(l));
            layout.manager.reference();
        } else {
            var layout_desc = utils.DefaultPipelineLayoutDescriptor.init(allocator);
            defer layout_desc.deinit();

            try layout_desc.addFunction(vertex_module.air, .{ .vertex = true }, desc.vertex.entry_point);
            if (desc.fragment) |frag| {
                const frag_module: *ShaderModule = @ptrCast(@alignCast(frag.module));
                try layout_desc.addFunction(frag_module.air, .{ .fragment = true }, frag.entry_point);
            }
            layout = try PipelineLayout.initDefault(device, layout_desc);
        }

        // Program
        const program = gl.CreateProgram();
        errdefer gl.DeleteProgram(program);

        gl.AttachShader(program, vertex_shader);
        if (opt_fragment_shader) |fragment_shader|
            gl.AttachShader(program, fragment_shader);
        gl.LinkProgram(program);

        var success: c.GLint = undefined;
        gl.GetProgramiv(program, c.GL_LINK_STATUS, &success);
        if (success == c.GL_FALSE) {
            var info_log: [512]c.GLchar = undefined;
            gl.GetProgramInfoLog(program, @sizeOf(@TypeOf(info_log)), null, &info_log);
            std.debug.print("Link Failed {s}\n", .{@as([*:0]u8, @ptrCast(&info_log))});
            return error.LinkFailed;
        }

        // Result
        var pipeline = try allocator.create(RenderPipeline);
        pipeline.* = .{
            .device = device,
            .program = program,
            .layout = layout,
        };
        return pipeline;
    }

    pub fn deinit(pipeline: *RenderPipeline) void {
        const device = pipeline.device;
        const gl = &device.gl;
        var ctx = ActiveContext.init(device.hdc, device.hglrc) catch @panic("ActiveContext failed");
        defer ctx.deinit();

        gl.DeleteProgram(pipeline.program);

        pipeline.layout.manager.release();
        allocator.destroy(pipeline);
    }

    pub fn getBindGroupLayout(pipeline: *RenderPipeline, group_index: u32) *BindGroupLayout {
        return @ptrCast(pipeline.layout.group_layouts[group_index]);
    }
};

pub const CommandBuffer = struct {
    manager: utils.Manager(CommandBuffer) = .{},

    pub fn init(device: *Device) !*CommandBuffer {
        _ = device;

        var command_buffer = try allocator.create(CommandBuffer);
        command_buffer.* = .{};
        return command_buffer;
    }

    pub fn deinit(command_buffer: *CommandBuffer) void {
        allocator.destroy(command_buffer);
    }
};

pub const CommandEncoder = struct {
    manager: utils.Manager(CommandEncoder) = .{},
    device: *Device,
    command_buffer: *CommandBuffer,

    pub fn init(device: *Device, desc: ?*const dgpu.CommandEncoder.Descriptor) !*CommandEncoder {
        _ = desc;

        const command_buffer = try CommandBuffer.init(device);

        var encoder = try allocator.create(CommandEncoder);
        encoder.* = .{
            .device = device,
            .command_buffer = command_buffer,
        };
        return encoder;
    }

    pub fn deinit(encoder: *CommandEncoder) void {
        encoder.command_buffer.manager.release();
        allocator.destroy(encoder);
    }

    pub fn beginComputePass(encoder: *CommandEncoder, desc: *const dgpu.ComputePassDescriptor) !*ComputePassEncoder {
        return ComputePassEncoder.init(encoder, desc);
    }

    pub fn beginRenderPass(encoder: *CommandEncoder, desc: *const dgpu.RenderPassDescriptor) !*RenderPassEncoder {
        return RenderPassEncoder.init(encoder, desc);
    }

    pub fn copyBufferToBuffer(
        encoder: *CommandEncoder,
        source: *Buffer,
        source_offset: u64,
        destination: *Buffer,
        destination_offset: u64,
        size: u64,
    ) !void {
        _ = size;
        _ = destination_offset;
        _ = destination;
        _ = source_offset;
        _ = source;
        _ = encoder;
    }

    pub fn copyBufferToTexture(
        encoder: *CommandEncoder,
        source: *const dgpu.ImageCopyBuffer,
        destination: *const dgpu.ImageCopyTexture,
        copy_size: *const dgpu.Extent3D,
    ) !void {
        _ = copy_size;
        _ = destination;
        _ = source;
        _ = encoder;
    }

    pub fn copyTextureToTexture(
        encoder: *CommandEncoder,
        source: *const dgpu.ImageCopyTexture,
        destination: *const dgpu.ImageCopyTexture,
        copy_size: *const dgpu.Extent3D,
    ) !void {
        _ = copy_size;
        _ = destination;
        _ = source;
        _ = encoder;
    }

    pub fn finish(encoder: *CommandEncoder, desc: *const dgpu.CommandBuffer.Descriptor) !*CommandBuffer {
        _ = desc;
        const command_buffer = encoder.command_buffer;

        return command_buffer;
    }

    pub fn writeBuffer(encoder: *CommandEncoder, buffer: *Buffer, offset: u64, data: [*]const u8, size: u64) !void {
        _ = size;
        _ = data;
        _ = offset;
        _ = buffer;
        _ = encoder;
    }

    pub fn writeTexture(
        encoder: *CommandEncoder,
        destination: *const dgpu.ImageCopyTexture,
        data: [*]const u8,
        data_size: usize,
        data_layout: *const dgpu.Texture.DataLayout,
        write_size: *const dgpu.Extent3D,
    ) !void {
        _ = write_size;
        _ = data_layout;
        _ = data_size;
        _ = data;
        _ = destination;
        _ = encoder;
    }
};

pub const ComputePassEncoder = struct {
    manager: utils.Manager(ComputePassEncoder) = .{},

    pub fn init(cmd_encoder: *CommandEncoder, desc: *const dgpu.ComputePassDescriptor) !*ComputePassEncoder {
        _ = desc;
        _ = cmd_encoder;

        var encoder = try allocator.create(ComputePassEncoder);
        encoder.* = .{};
        return encoder;
    }

    pub fn deinit(encoder: *ComputePassEncoder) void {
        allocator.destroy(encoder);
    }

    pub fn dispatchWorkgroups(
        encoder: *ComputePassEncoder,
        workgroup_count_x: u32,
        workgroup_count_y: u32,
        workgroup_count_z: u32,
    ) !void {
        _ = workgroup_count_z;
        _ = workgroup_count_y;
        _ = workgroup_count_x;
        _ = encoder;
    }

    pub fn end(encoder: *ComputePassEncoder) void {
        _ = encoder;
    }

    pub fn setBindGroup(
        encoder: *ComputePassEncoder,
        group_index: u32,
        group: *BindGroup,
        dynamic_offset_count: usize,
        dynamic_offsets: ?[*]const u32,
    ) !void {
        _ = dynamic_offsets;
        _ = dynamic_offset_count;
        _ = group;
        _ = group_index;
        _ = encoder;
    }

    pub fn setPipeline(encoder: *ComputePassEncoder, pipeline: *ComputePipeline) !void {
        _ = pipeline;
        _ = encoder;
    }
};

pub const RenderPassEncoder = struct {
    manager: utils.Manager(RenderPassEncoder) = .{},
    ctx: ActiveContext,
    gl: *proc.DeviceGL,

    pub fn init(cmd_encoder: *CommandEncoder, desc: *const dgpu.RenderPassDescriptor) !*RenderPassEncoder {
        const device = cmd_encoder.device;
        const gl = &device.gl;

        // Set context to the HWND.  Offscreen rendering support will come later and may be used
        // universally to simplify coordinate space transformations.
        var hdc = device.hdc;
        for (0..desc.color_attachment_count) |i| {
            const attach = desc.color_attachments.?[i];
            const view: *TextureView = @ptrCast(@alignCast(attach.view.?));

            // TODO - offscreen render support (which we may always want to do)
            if (view.texture.swapchain) |swapchain|
                hdc = swapchain.hdc;
        }

        var ctx = try ActiveContext.init(hdc, device.hglrc);

        for (0..desc.color_attachment_count) |i| {
            const attach = desc.color_attachments.?[i];

            if (attach.load_op == .clear) {
                gl.ClearColor(
                    @floatCast(attach.clear_value.r),
                    @floatCast(attach.clear_value.g),
                    @floatCast(attach.clear_value.b),
                    @floatCast(attach.clear_value.a),
                );

                gl.Clear(c.GL_COLOR_BUFFER_BIT);
            }
        }

        // Result
        var encoder = try allocator.create(RenderPassEncoder);
        encoder.* = .{
            .ctx = ctx,
            .gl = gl,
        };
        return encoder;
    }

    pub fn deinit(encoder: *RenderPassEncoder) void {
        encoder.ctx.deinit();
        allocator.destroy(encoder);
    }

    pub fn draw(
        encoder: *RenderPassEncoder,
        vertex_count: u32,
        instance_count: u32,
        first_vertex: u32,
        first_instance: u32,
    ) void {
        _ = first_instance;
        _ = instance_count;
        const gl = encoder.gl;

        gl.DrawArrays(c.GL_TRIANGLES, @intCast(first_vertex), @intCast(vertex_count));
    }

    pub fn drawIndexed(
        encoder: *RenderPassEncoder,
        index_count: u32,
        instance_count: u32,
        first_index: u32,
        base_vertex: i32,
        first_instance: u32,
    ) void {
        _ = first_instance;
        _ = base_vertex;
        _ = first_index;
        _ = instance_count;
        _ = index_count;
        _ = encoder;
    }

    pub fn end(encoder: *RenderPassEncoder) !void {
        const gl = encoder.gl;

        checkError(gl);
    }

    pub fn setBindGroup(
        encoder: *RenderPassEncoder,
        group_index: u32,
        group: *BindGroup,
        dynamic_offset_count: usize,
        dynamic_offsets: ?[*]const u32,
    ) !void {
        _ = dynamic_offsets;
        _ = dynamic_offset_count;
        _ = group;
        _ = group_index;
        _ = encoder;
    }

    pub fn setIndexBuffer(
        encoder: *RenderPassEncoder,
        buffer: *Buffer,
        format: dgpu.IndexFormat,
        offset: u64,
        size: u64,
    ) !void {
        _ = size;
        _ = offset;
        _ = format;
        _ = buffer;
        _ = encoder;
    }

    pub fn setPipeline(encoder: *RenderPassEncoder, pipeline: *RenderPipeline) !void {
        const gl = encoder.gl;

        gl.UseProgram(pipeline.program);
    }

    pub fn setScissorRect(encoder: *RenderPassEncoder, x: u32, y: u32, width: u32, height: u32) void {
        _ = height;
        _ = width;
        _ = y;
        _ = x;
        _ = encoder;
    }

    pub fn setVertexBuffer(encoder: *RenderPassEncoder, slot: u32, buffer: *Buffer, offset: u64, size: u64) !void {
        _ = size;
        _ = offset;
        _ = buffer;
        _ = slot;
        _ = encoder;
    }

    pub fn setViewport(encoder: *RenderPassEncoder, x: f32, y: f32, width: f32, height: f32, min_depth: f32, max_depth: f32) void {
        _ = max_depth;
        _ = min_depth;
        _ = height;
        _ = width;
        _ = y;
        _ = x;
        _ = encoder;
    }
};

pub const Queue = struct {
    manager: utils.Manager(Queue) = .{},

    pub fn init(device: *Device) !*Queue {
        _ = device;

        var queue = try allocator.create(Queue);
        queue.* = .{};
        return queue;
    }

    pub fn deinit(queue: *Queue) void {
        allocator.destroy(queue);
    }

    pub fn submit(queue: *Queue, commands: []const *CommandBuffer) !void {
        _ = commands;
        _ = queue;
    }

    pub fn writeBuffer(queue: *Queue, buffer: *Buffer, offset: u64, data: [*]const u8, size: u64) !void {
        _ = size;
        _ = data;
        _ = offset;
        _ = buffer;
        _ = queue;
    }

    pub fn writeTexture(
        queue: *Queue,
        destination: *const dgpu.ImageCopyTexture,
        data: [*]const u8,
        data_size: usize,
        data_layout: *const dgpu.Texture.DataLayout,
        write_size: *const dgpu.Extent3D,
    ) !void {
        _ = write_size;
        _ = data_layout;
        _ = data_size;
        _ = data;
        _ = destination;
        _ = queue;
    }
};

test "reference declarations" {
    std.testing.refAllDeclsRecursive(@This());
}
