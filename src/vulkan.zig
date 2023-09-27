const std = @import("std");
const builtin = @import("builtin");
const gpu = @import("gpu");
const vk = @import("vulkan");
const dusk = @import("main.zig");
const utils = @import("utils.zig");
const shader = @import("shader.zig");
const conv = @import("vulkan/conv.zig");
const proc = @import("vulkan/proc.zig");

const log = std.log.scoped(.vulkan);
const api_version = vk.makeApiVersion(0, 1, 1, 0);
const frames_in_flight = 2;

var allocator: std.mem.Allocator = undefined;
var libvulkan: ?std.DynLib = null;
var vkb: proc.BaseFunctions = undefined;
var vki: proc.InstanceFunctions = undefined;
var vkd: proc.DeviceFunctions = undefined;

pub const InitOptions = struct {
    baseLoader: ?proc.BaseLoader = null,
};

pub fn init(alloc: std.mem.Allocator, options: InitOptions) !void {
    allocator = alloc;
    if (options.baseLoader) |baseLoader| {
        vkb = try proc.loadBase(baseLoader);
    } else {
        libvulkan = try std.DynLib.openZ(switch (builtin.target.os.tag) {
            .windows => "vulkan-1.dll",
            .linux => "libvulkan.so.1",
            .macos => "libvulkan.1.dylib",
            else => @compileError("Unknown OS!"),
        });
        vkb = try proc.loadBase(libVulkanBaseLoader);
    }
}

pub fn libVulkanBaseLoader(_: vk.Instance, name_ptr: [*:0]const u8) vk.PfnVoidFunction {
    var name = std.mem.span(name_ptr);
    return libvulkan.?.lookup(vk.PfnVoidFunction, name) orelse null;
}

pub const Instance = struct {
    manager: utils.Manager(Instance) = .{},
    instance: vk.Instance,

    pub fn init(desc: *const gpu.Instance.Descriptor) !*Instance {
        _ = desc;

        // Query layers
        var count: u32 = 0;
        _ = try vkb.enumerateInstanceLayerProperties(&count, null);

        var available_layers = try allocator.alloc(vk.LayerProperties, count);
        defer allocator.free(available_layers);
        _ = try vkb.enumerateInstanceLayerProperties(&count, available_layers.ptr);

        var layers = std.BoundedArray([*:0]const u8, instance_layers.len){};
        for (instance_layers) |optional| {
            for (available_layers) |available| {
                if (std.mem.eql(
                    u8,
                    std.mem.sliceTo(optional, 0),
                    std.mem.sliceTo(&available.layer_name, 0),
                )) {
                    layers.appendAssumeCapacity(optional);
                    break;
                }
            }
        }

        // Query extensions
        _ = try vkb.enumerateInstanceExtensionProperties(null, &count, null);

        var available_extensions = try allocator.alloc(vk.ExtensionProperties, count);
        defer allocator.free(available_extensions);
        _ = try vkb.enumerateInstanceExtensionProperties(null, &count, available_extensions.ptr);

        var extensions = std.BoundedArray([*:0]const u8, instance_extensions.len){};

        for (instance_extensions) |required| {
            for (available_extensions) |available| {
                if (std.mem.eql(
                    u8,
                    std.mem.sliceTo(required, 0),
                    std.mem.sliceTo(&available.extension_name, 0),
                )) {
                    extensions.appendAssumeCapacity(required);
                    break;
                }
            } else {
                log.warn("unable to find required instance extension: {s}", .{required});
            }
        }

        // Create instace
        const application_info = vk.ApplicationInfo{
            .p_engine_name = "Banana",
            .application_version = 0,
            .engine_version = vk.makeApiVersion(0, 0, 1, 0), // TODO: get this from build.zig.zon
            .api_version = api_version,
        };
        const instance_info = vk.InstanceCreateInfo{
            .p_application_info = &application_info,
            .enabled_layer_count = layers.len,
            .pp_enabled_layer_names = layers.slice().ptr,
            .enabled_extension_count = extensions.len,
            .pp_enabled_extension_names = extensions.slice().ptr,
        };
        const vk_instance = try vkb.createInstance(&instance_info, null);

        // Load instance functions
        vki = try proc.loadInstance(vk_instance, vkb.dispatch.vkGetInstanceProcAddr);

        var instance = try allocator.create(Instance);
        instance.* = .{ .instance = vk_instance };
        return instance;
    }

    const instance_layers = if (builtin.mode == .Debug)
        &[_][*:0]const u8{"VK_LAYER_KHRONOS_validation"}
    else
        &.{};
    const instance_extensions: []const [*:0]const u8 = switch (builtin.target.os.tag) {
        .linux => &.{
            vk.extension_info.khr_surface.name,
            vk.extension_info.khr_xlib_surface.name,
            vk.extension_info.khr_xcb_surface.name,
            // TODO: renderdoc will not work with this extension
            // vk.extension_info.khr_wayland_surface.name,
        },
        .windows => &.{
            vk.extension_info.khr_surface.name,
            vk.extension_info.khr_win_32_surface.name,
        },
        .macos, .ios => &.{
            vk.extension_info.khr_surface.name,
            vk.extension_info.ext_metal_surface.name,
        },
        else => |tag| if (builtin.target.abi == .android)
            &.{
                vk.extension_info.khr_surface.name,
                vk.extension_info.khr_android_surface.name,
            }
        else
            @compileError(std.fmt.comptimePrint("unsupported platform ({s})", .{@tagName(tag)})),
    };

    pub fn deinit(instance: *Instance) void {
        vki.destroyInstance(instance.instance, null);
        allocator.destroy(instance);
        if (libvulkan) |*lib| lib.close();
    }

    pub fn requestAdapter(
        instance: *Instance,
        options: ?*const gpu.RequestAdapterOptions,
        callback: gpu.RequestAdapterCallback,
        userdata: ?*anyopaque,
    ) !*Adapter {
        return Adapter.init(instance, options orelse &gpu.RequestAdapterOptions{}) catch |err| {
            callback(.err, undefined, @errorName(err), userdata);
            unreachable; // TODO - return dummy adapter
        };
    }

    pub fn createSurface(instance: *Instance, desc: *const gpu.Surface.Descriptor) !*Surface {
        return Surface.init(instance, desc);
    }
};

pub const Adapter = struct {
    manager: utils.Manager(Adapter) = .{},
    instance: *Instance,
    physical_device: vk.PhysicalDevice,
    props: vk.PhysicalDeviceProperties,
    queue_family: u32,
    extensions: []const vk.ExtensionProperties,
    driver_desc: [:0]const u8,
    vendor_id: VendorID,

    pub fn init(instance: *Instance, options: *const gpu.RequestAdapterOptions) !*Adapter {
        var count: u32 = 0;
        _ = try vki.enumeratePhysicalDevices(instance.instance, &count, null);

        var physical_devices = try allocator.alloc(vk.PhysicalDevice, count);
        defer allocator.free(physical_devices);
        _ = try vki.enumeratePhysicalDevices(instance.instance, &count, physical_devices.ptr);

        // Find best device based on power preference
        var physical_device_info: ?struct {
            physical_device: vk.PhysicalDevice,
            props: vk.PhysicalDeviceProperties,
            queue_family: u32,
            score: u32,
        } = null;
        for (physical_devices[0..count]) |physical_device| {
            const props = vki.getPhysicalDeviceProperties(physical_device);
            const features = vki.getPhysicalDeviceFeatures(physical_device);
            const queue_family = try findQueueFamily(physical_device) orelse continue;

            if (isDeviceSuitable(props, features)) {
                const score = rateDevice(props, features, options.power_preference);
                if (score == 0) continue;

                if (physical_device_info == null or score > physical_device_info.?.score) {
                    physical_device_info = .{
                        .physical_device = physical_device,
                        .props = props,
                        .queue_family = queue_family,
                        .score = score,
                    };
                }
            }
        }

        if (physical_device_info) |info| {
            _ = try vki.enumerateDeviceExtensionProperties(info.physical_device, null, &count, null);
            var extensions = try allocator.alloc(vk.ExtensionProperties, count);
            errdefer allocator.free(extensions);
            _ = try vki.enumerateDeviceExtensionProperties(info.physical_device, null, &count, extensions.ptr);

            const driver_desc = try std.fmt.allocPrintZ(
                allocator,
                "Vulkan driver version {}.{}.{}",
                .{
                    vk.apiVersionMajor(info.props.driver_version),
                    vk.apiVersionMinor(info.props.driver_version),
                    vk.apiVersionPatch(info.props.driver_version),
                },
            );

            var adapter = try allocator.create(Adapter);
            adapter.* = .{
                .instance = instance,
                .physical_device = info.physical_device,
                .props = info.props,
                .queue_family = info.queue_family,
                .extensions = extensions,
                .driver_desc = driver_desc,
                .vendor_id = @enumFromInt(info.props.vendor_id),
            };
            return adapter;
        }

        return error.NoAdapterFound;
    }

    pub fn deinit(adapter: *Adapter) void {
        allocator.free(adapter.extensions);
        allocator.free(adapter.driver_desc);
        allocator.destroy(adapter);
    }

    pub fn createDevice(adapter: *Adapter, desc: ?*const gpu.Device.Descriptor) !*Device {
        return Device.init(adapter, desc);
    }

    pub fn getProperties(adapter: *Adapter) gpu.Adapter.Properties {
        const adapter_type: gpu.Adapter.Type = switch (adapter.props.device_type) {
            .integrated_gpu => .integrated_gpu,
            .discrete_gpu => .discrete_gpu,
            .cpu => .cpu,
            else => .unknown,
        };

        return .{
            .vendor_id = @intFromEnum(adapter.vendor_id),
            .vendor_name = adapter.vendor_id.name(),
            .architecture = "", // TODO
            .device_id = adapter.props.device_id,
            .name = @ptrCast(&adapter.props.device_name),
            .driver_description = adapter.driver_desc,
            .adapter_type = adapter_type,
            .backend_type = .vulkan,
            .compatibility_mode = .false, // TODO
        };
    }

    pub fn hasExtension(adapter: *Adapter, name: []const u8) bool {
        for (adapter.extensions) |ext| {
            if (std.mem.eql(u8, name, std.mem.sliceTo(&ext.extension_name, 0))) {
                return true;
            }
        }
        return false;
    }

    fn isDeviceSuitable(props: vk.PhysicalDeviceProperties, features: vk.PhysicalDeviceFeatures) bool {
        return props.api_version >= api_version and
            // WebGPU features
            features.depth_bias_clamp == vk.TRUE and
            features.fragment_stores_and_atomics == vk.TRUE and
            features.full_draw_index_uint_32 == vk.TRUE and
            features.image_cube_array == vk.TRUE and
            features.independent_blend == vk.TRUE and
            features.sample_rate_shading == vk.TRUE and
            // At least one of the following texture compression forms
            (features.texture_compression_bc == vk.TRUE or
            features.texture_compression_etc2 == vk.TRUE or
            features.texture_compression_astc_ldr == vk.TRUE);
    }

    fn rateDevice(
        props: vk.PhysicalDeviceProperties,
        features: vk.PhysicalDeviceFeatures,
        power_preference: gpu.PowerPreference,
    ) u32 {
        // Can't function without geometry shaders
        if (features.geometry_shader == vk.FALSE) {
            return 0;
        }

        var score: u32 = 0;
        switch (props.device_type) {
            .integrated_gpu => if (power_preference == .low_power) {
                score += 1000;
            },
            .discrete_gpu => if (power_preference == .high_performance) {
                score += 1000;
            },
            else => {},
        }

        score += props.limits.max_image_dimension_2d;

        return score;
    }

    fn findQueueFamily(device: vk.PhysicalDevice) !?u32 {
        var count: u32 = 0;
        _ = vki.getPhysicalDeviceQueueFamilyProperties(device, &count, null);

        var queue_families = try allocator.alloc(vk.QueueFamilyProperties, count);
        defer allocator.free(queue_families);
        _ = vki.getPhysicalDeviceQueueFamilyProperties(device, &count, queue_families.ptr);

        for (queue_families, 0..) |family, i| {
            if (family.queue_flags.graphics_bit and family.queue_flags.compute_bit) {
                return @intCast(i);
            }
        }

        return null;
    }

    const VendorID = enum(u32) {
        amd = 0x1002,
        apple = 0x106b,
        arm = 0x13B5,
        google = 0x1AE0,
        img_tec = 0x1010,
        intel = 0x8086,
        mesa = 0x10005,
        microsoft = 0x1414,
        nvidia = 0x10DE,
        qualcomm = 0x5143,
        samsung = 0x144d,
        _,

        pub fn name(vendor_id: VendorID) [:0]const u8 {
            return switch (vendor_id) {
                .amd => "AMD",
                .apple => "Apple",
                .arm => "ARM",
                .google => "Google",
                .img_tec => "Img Tec",
                .intel => "Intel",
                .mesa => "Mesa",
                .microsoft => "Microsoft",
                .nvidia => "Nvidia",
                .qualcomm => "Qualcomm",
                .samsung => "Samsung",
                _ => "Unknown",
            };
        }
    };
};

pub const Surface = struct {
    manager: utils.Manager(Surface) = .{},
    instance: *Instance,
    surface: vk.SurfaceKHR,

    pub fn init(instance: *Instance, desc: *const gpu.Surface.Descriptor) !*Surface {
        const vk_surface = switch (builtin.target.os.tag) {
            .linux => blk: {
                if (utils.findChained(gpu.Surface.DescriptorFromXlibWindow, desc.next_in_chain.generic)) |x_desc| {
                    break :blk try vki.createXlibSurfaceKHR(
                        instance.instance,
                        &vk.XlibSurfaceCreateInfoKHR{
                            .dpy = @ptrCast(x_desc.display),
                            .window = x_desc.window,
                        },
                        null,
                    );
                } else if (utils.findChained(gpu.Surface.DescriptorFromWaylandSurface, desc.next_in_chain.generic)) |wayland_desc| {
                    _ = wayland_desc;
                    unreachable;
                    // TODO: renderdoc will not work with wayland
                    // break :blk try vki.createWaylandSurfaceKHR(
                    //     instance.instance,
                    //     &vk.WaylandSurfaceCreateInfoKHR{
                    //         .display = @ptrCast(wayland_desc.display),
                    //         .surface = @ptrCast(wayland_desc.surface),
                    //     },
                    //     null,
                    // );
                }

                return error.InvalidDescriptor;
            },
            .windows => blk: {
                if (utils.findChained(gpu.Surface.DescriptorFromWindowsHWND, desc.next_in_chain.generic)) |win_desc| {
                    break :blk try vki.createWin32SurfaceKHR(
                        instance.instance,
                        &vk.Win32SurfaceCreateInfoKHR{
                            .hinstance = @ptrCast(win_desc.hinstance),
                            .hwnd = @ptrCast(win_desc.hwnd),
                        },
                        null,
                    );
                }

                return error.InvalidDescriptor;
            },
            else => unreachable,
        };

        var surface = try allocator.create(Surface);
        surface.* = .{
            .instance = instance,
            .surface = vk_surface,
        };

        return surface;
    }

    pub fn deinit(surface: *Surface) void {
        vki.destroySurfaceKHR(surface.instance.instance, surface.surface, null);
        allocator.destroy(surface);
    }
};

pub const Device = struct {
    const FrameObject = union(enum) {
        cmd_encoder: *CommandEncoder,
        render_pass_encoder: *RenderPassEncoder,

        pub fn destroy(obj: FrameObject, device: *Device) void {
            switch (obj) {
                .cmd_encoder => |ce| {
                    vkd.freeCommandBuffers(device.device, device.cmd_pool, 1, @ptrCast(&ce.buffer.buffer));
                    allocator.destroy(ce);
                },
                .render_pass_encoder => |rpe| {
                    allocator.free(rpe.clear_values);
                    vkd.destroyFramebuffer(device.device, rpe.framebuffer, null);
                    allocator.destroy(rpe);
                },
            }
        }
    };

    const FrameResource = struct {
        destruction_queue: std.ArrayListUnmanaged(FrameObject),
        render_fence: vk.Fence,
        render_semaphore: vk.Semaphore,
        present_semaphore: vk.Semaphore,
    };

    manager: utils.Manager(Device) = .{},
    adapter: *Adapter,
    device: vk.Device,
    frames_res: [frames_in_flight]FrameResource,
    frame_index: u32 = 0,
    render_passes: std.AutoHashMapUnmanaged(RenderPassKey, vk.RenderPass) = .{},
    cmd_pool: vk.CommandPool,
    memory_allocator: MemoryAllocator,
    queue: ?Queue = null,
    lost_cb: ?gpu.Device.LostCallback = null,
    lost_cb_userdata: ?*anyopaque = null,
    log_cb: ?gpu.LoggingCallback = null,
    log_cb_userdata: ?*anyopaque = null,
    err_cb: ?gpu.ErrorCallback = null,
    err_cb_userdata: ?*anyopaque = null,

    pub fn init(adapter: *Adapter, descriptor: ?*const gpu.Device.Descriptor) !*Device {
        const queue_infos = &[_]vk.DeviceQueueCreateInfo{.{
            .queue_family_index = adapter.queue_family,
            .queue_count = 1,
            .p_queue_priorities = &[_]f32{1.0},
        }};

        var features = vk.PhysicalDeviceFeatures2{ .features = .{ .geometry_shader = vk.TRUE } };
        if (descriptor) |desc| {
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
                        else => log.warn("unimplement feature: {s}", .{@tagName(req_feature)}),
                    }
                }
            }
        }

        // Query layers
        var count: u32 = 0;
        _ = try vki.enumerateDeviceLayerProperties(adapter.physical_device, &count, null);

        var available_layers = try allocator.alloc(vk.LayerProperties, count);
        defer allocator.free(available_layers);
        _ = try vki.enumerateDeviceLayerProperties(adapter.physical_device, &count, available_layers.ptr);

        var layers = std.BoundedArray([*:0]const u8, device_layers.len){};
        for (device_layers) |optional| {
            for (available_layers) |available| {
                if (std.mem.eql(
                    u8,
                    std.mem.sliceTo(optional, 0),
                    std.mem.sliceTo(&available.layer_name, 0),
                )) {
                    layers.appendAssumeCapacity(optional);
                    break;
                }
            }
        }

        // Query extensions
        _ = try vki.enumerateDeviceExtensionProperties(adapter.physical_device, null, &count, null);

        var available_extensions = try allocator.alloc(vk.ExtensionProperties, count);
        defer allocator.free(available_extensions);
        _ = try vki.enumerateDeviceExtensionProperties(adapter.physical_device, null, &count, available_extensions.ptr);

        var extensions = std.BoundedArray([*:0]const u8, device_extensions.len){};
        for (device_extensions) |required| {
            for (available_extensions) |available| {
                if (std.mem.eql(
                    u8,
                    std.mem.sliceTo(required, 0),
                    std.mem.sliceTo(&available.extension_name, 0),
                )) {
                    extensions.appendAssumeCapacity(required);
                    break;
                }
            } else {
                log.warn("unable to find required device extension: {s}", .{required});
            }
        }

        var create_info = vk.DeviceCreateInfo{
            .queue_create_info_count = @intCast(queue_infos.len),
            .p_queue_create_infos = queue_infos.ptr,
            .enabled_layer_count = @intCast(layers.len),
            .pp_enabled_layer_names = layers.slice().ptr,
            .enabled_extension_count = @intCast(extensions.len),
            .pp_enabled_extension_names = extensions.slice().ptr,
        };
        if (adapter.hasExtension("GetPhysicalDeviceProperties2")) {
            create_info.p_next = &features;
        } else {
            create_info.p_enabled_features = &features.features;
        }

        const vk_device = try vki.createDevice(adapter.physical_device, &create_info, null);
        vkd = try proc.loadDevice(vk_device, vki.dispatch.vkGetDeviceProcAddr);

        const cmd_pool = try vkd.createCommandPool(
            vk_device,
            &.{
                .queue_family_index = adapter.queue_family,
                .flags = .{ .reset_command_buffer_bit = true },
            },
            null,
        );

        var frames_res: [frames_in_flight]FrameResource = undefined;
        for (&frames_res) |*fr| {
            fr.* = .{
                .destruction_queue = .{},
                .render_fence = try vkd.createFence(vk_device, &.{ .flags = .{ .signaled_bit = true } }, null),
                .render_semaphore = try vkd.createSemaphore(vk_device, &.{}, null),
                .present_semaphore = try vkd.createSemaphore(vk_device, &.{}, null),
            };
        }

        const memory_allocator = MemoryAllocator.init(adapter.physical_device);

        var device = try allocator.create(Device);
        device.* = .{
            .adapter = adapter,
            .device = vk_device,
            .cmd_pool = cmd_pool,
            .frames_res = frames_res,
            .memory_allocator = memory_allocator,
        };
        return device;
    }

    pub fn deinit(device: *Device) void {
        if (device.lost_cb) |lost_cb| {
            lost_cb(.destroyed, "Device was destroyed.", device.lost_cb_userdata);
        }

        device.waitAll() catch {};

        for (&device.frames_res) |*fr| {
            while (fr.destruction_queue.popOrNull()) |obj| obj.destroy(device);
            fr.destruction_queue.deinit(allocator);
            vkd.destroySemaphore(device.device, fr.render_semaphore, null);
            vkd.destroySemaphore(device.device, fr.present_semaphore, null);
            vkd.destroyFence(device.device, fr.render_fence, null);
        }

        var rp_iter = device.render_passes.valueIterator();
        while (rp_iter.next()) |render_pass| {
            vkd.destroyRenderPass(device.device, render_pass.*, null);
        }
        device.render_passes.deinit(allocator);

        vkd.destroyCommandPool(device.device, device.cmd_pool, null);
        vkd.destroyDevice(device.device, null);
        allocator.destroy(device);
    }

    fn frameRes(device: *Device) *FrameResource {
        return &device.frames_res[device.frame_index];
    }

    fn wait(device: *Device) !void {
        _ = try vkd.waitForFences(
            device.device,
            1,
            &[_]vk.Fence{device.frameRes().render_fence},
            vk.TRUE,
            std.math.maxInt(u64),
        );
    }

    fn reset(device: *Device) !void {
        try vkd.resetFences(device.device, 1, &[_]vk.Fence{device.frameRes().render_fence});
    }

    fn waitAll(device: *Device) !void {
        for (device.frames_res) |fr| {
            _ = try vkd.waitForFences(
                device.device,
                1,
                &[_]vk.Fence{fr.render_fence},
                vk.TRUE,
                std.math.maxInt(u64),
            );
        }
    }

    pub fn createBindGroup(device: *Device, desc: *const gpu.BindGroup.Descriptor) !*BindGroup {
        return BindGroup.init(device, desc);
    }

    pub fn createBindGroupLayout(device: *Device, desc: *const gpu.BindGroupLayout.Descriptor) !*BindGroupLayout {
        return BindGroupLayout.init(device, desc);
    }

    pub fn createBuffer(device: *Device, desc: *const gpu.Buffer.Descriptor) !*Buffer {
        return Buffer.init(device, desc);
    }

    pub fn createCommandEncoder(device: *Device, desc: *const gpu.CommandEncoder.Descriptor) !*CommandEncoder {
        return CommandEncoder.init(device, desc);
    }

    pub fn createComputePipeline(device: *Device, desc: *const gpu.ComputePipeline.Descriptor) !*ComputePipeline {
        _ = desc;
        _ = device;
        unreachable;
    }

    pub fn createPipelineLayout(device: *Device, desc: *const gpu.PipelineLayout.Descriptor) !*PipelineLayout {
        return PipelineLayout.init(device, desc);
    }

    pub fn createRenderPipeline(device: *Device, desc: *const gpu.RenderPipeline.Descriptor) !*RenderPipeline {
        return RenderPipeline.init(device, desc);
    }

    pub fn createShaderModuleAir(device: *Device, air: *const shader.Air) !*ShaderModule {
        return ShaderModule.initAir(device, air);
    }

    pub fn createShaderModuleSpirv(device: *Device, code: []const u8) !*ShaderModule {
        return ShaderModule.initSpirv(device, code);
    }

    pub fn createSwapChain(device: *Device, surface: *Surface, desc: *const gpu.SwapChain.Descriptor) !*SwapChain {
        return SwapChain.init(device, surface, desc);
    }

    pub fn createTexture(device: *Device, desc: *const gpu.Texture.Descriptor) !*Texture {
        _ = desc;
        _ = device;
        unreachable;
    }

    pub fn getQueue(device: *Device) !*Queue {
        if (device.queue == null) {
            device.queue = try Queue.init(device);
        }
        return &device.queue.?;
    }

    pub fn tick(device: *Device) !void {
        _ = device;
    }

    const device_layers = if (builtin.mode == .Debug)
        &[_][*:0]const u8{"VK_LAYER_KHRONOS_validation"}
    else
        &.{};
    const device_extensions = &[_][*:0]const u8{vk.extension_info.khr_swapchain.name};

    pub const ColorAttachmentKey = struct {
        format: vk.Format,
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

    fn createRenderPass(device: *Device, key: RenderPassKey) !vk.RenderPass {
        if (device.render_passes.get(key)) |render_pass| return render_pass;

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

        const render_pass = try vkd.createRenderPass(device.device, &vk.RenderPassCreateInfo{
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

        try device.render_passes.put(allocator, key, render_pass);

        return render_pass;
    }
};

pub const SwapChain = struct {
    manager: utils.Manager(SwapChain) = .{},
    device: *Device,
    swapchain: vk.SwapchainKHR,
    textures: []*Texture,
    texture_views: []*TextureView,
    texture_index: u32 = 0,
    format: gpu.Texture.Format,

    pub fn init(device: *Device, surface: *Surface, desc: *const gpu.SwapChain.Descriptor) !*SwapChain {
        const capabilities = try vki.getPhysicalDeviceSurfaceCapabilitiesKHR(
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

        const swapchain = try vkd.createSwapchainKHR(device.device, &.{
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
        _ = try vkd.getSwapchainImagesKHR(device.device, swapchain, &images_len, null);
        var images = try allocator.alloc(vk.Image, images_len);
        defer allocator.free(images);
        _ = try vkd.getSwapchainImagesKHR(device.device, swapchain, &images_len, images.ptr);

        const textures = try allocator.alloc(*Texture, images_len);
        errdefer allocator.free(textures);
        const texture_views = try allocator.alloc(*TextureView, images_len);
        errdefer allocator.free(texture_views);

        for (0..images_len) |i| {
            const texture = try Texture.init(device, images[i], extent);
            textures[i] = texture;
            texture_views[i] = try texture.createView(&.{
                .format = desc.format,
                .dimension = .dimension_2d,
            });
        }

        var sc = try allocator.create(SwapChain);
        sc.* = .{
            .device = device,
            .swapchain = swapchain,
            .format = desc.format,
            .textures = textures,
            .texture_views = texture_views,
        };

        return sc;
    }

    pub fn deinit(sc: *SwapChain) void {
        for (sc.texture_views) |view| view.manager.release();
        for (sc.textures) |texture| texture.manager.release();
        vkd.destroySwapchainKHR(sc.device.device, sc.swapchain, null);
        allocator.free(sc.textures);
        allocator.free(sc.texture_views);
        allocator.destroy(sc);
    }

    pub fn getCurrentTextureView(sc: *SwapChain) !*TextureView {
        try sc.device.wait();
        try sc.device.reset();
        while (sc.device.frameRes().destruction_queue.popOrNull()) |obj| {
            obj.destroy(sc.device);
        }

        const result = try vkd.acquireNextImageKHR(
            sc.device.device,
            sc.swapchain,
            std.math.maxInt(u64),
            sc.device.frameRes().present_semaphore,
            .null_handle,
        );

        sc.texture_index = result.image_index;
        const view = sc.texture_views[sc.texture_index];
        view.manager.reference();

        return view;
    }

    pub fn present(sc: *SwapChain) !void {
        const queue = try sc.device.getQueue();
        _ = try vkd.queuePresentKHR(queue.queue, &.{
            .wait_semaphore_count = 1,
            .p_wait_semaphores = &[_]vk.Semaphore{sc.device.frameRes().render_semaphore},
            .swapchain_count = 1,
            .p_swapchains = &[_]vk.SwapchainKHR{sc.swapchain},
            .p_image_indices = &[_]u32{sc.texture_index},
        });
        queue.device.frame_index = (queue.device.frame_index + 1) % frames_in_flight;
    }
};

pub const Buffer = struct {
    manager: utils.Manager(Buffer) = .{},
    device: *Device,
    buffer: vk.Buffer,
    memory: vk.DeviceMemory,
    stage_buffer: ?*Buffer,
    size: usize,
    map: ?[*]u8,

    pub fn init(device: *Device, desc: *const gpu.Buffer.Descriptor) !*Buffer {
        const size = @max(4, desc.size);

        var usage = desc.usage;
        if (desc.mapped_at_creation == .true and !desc.usage.map_write)
            usage.copy_dst = true;

        const vk_buffer = try vkd.createBuffer(device.device, &.{
            .size = size,
            .usage = conv.vulkanBufferUsageFlags(usage),
            .sharing_mode = .exclusive,
        }, null);
        const requirements = vkd.getBufferMemoryRequirements(device.device, vk_buffer);

        const mem_type: MemoryAllocator.MemoryKind = blk: {
            if (desc.usage.map_read) break :blk .linear_read_mappable;
            if (desc.usage.map_write) break :blk .linear_write_mappable;
            break :blk .linear;
        };
        const mem_type_index = device.memory_allocator.findBestAllocator(requirements, mem_type) orelse unreachable; // TODO

        const memory = try vkd.allocateMemory(device.device, &.{
            .allocation_size = size,
            .memory_type_index = mem_type_index,
        }, null);

        try vkd.bindBufferMemory(device.device, vk_buffer, memory, 0);

        // upload buffer
        var stage_buffer: ?*Buffer = null;
        var map: ?*anyopaque = null;
        if (desc.mapped_at_creation == .true) {
            if (!desc.usage.map_write) {
                stage_buffer = try Buffer.init(device, &.{
                    .usage = .{
                        .copy_src = true,
                        .map_write = true,
                    },
                    .size = size,
                });
                map = try vkd.mapMemory(device.device, stage_buffer.?.memory, 0, size, .{});
            } else {
                map = try vkd.mapMemory(device.device, memory, 0, size, .{});
            }
        }

        var buffer = try allocator.create(Buffer);
        buffer.* = .{
            .device = device,
            .buffer = vk_buffer,
            .memory = memory,
            .stage_buffer = stage_buffer,
            .size = size,
            .map = @ptrCast(map),
        };

        return buffer;
    }

    pub fn deinit(buffer: *Buffer) void {
        if (buffer.stage_buffer) |stage_buffer| {
            stage_buffer.manager.release();
        }
        vkd.destroyBuffer(buffer.device.device, buffer.buffer, null);
        vkd.freeMemory(buffer.device.device, buffer.memory, null);
    }

    pub fn getConstMappedRange(buffer: *Buffer, offset: usize, size: usize) !?*anyopaque {
        return @ptrCast(buffer.map.?[offset .. offset + size]);
    }

    pub fn mapAsync(buffer: *Buffer, mode: gpu.MapModeFlags, offset: usize, size: usize, callback: gpu.Buffer.MapCallback, userdata: ?*anyopaque) !void {
        _ = userdata;
        _ = callback;
        _ = size;
        _ = offset;
        _ = mode;
        _ = buffer;
        unreachable;
    }

    pub fn unmap(buffer: *Buffer) !void {
        if (buffer.stage_buffer) |stage_buffer| {
            vkd.unmapMemory(buffer.device.device, stage_buffer.memory);

            var cmd_encoder = try CommandEncoder.init(buffer.device, null);
            try cmd_encoder.copyBufferToBuffer(stage_buffer, 0, buffer, 0, buffer.size);
            const cmd_buffer = try cmd_encoder.finish(&.{});

            const queue = try buffer.device.getQueue();
            try vkd.queueSubmit(
                queue.queue,
                1,
                @ptrCast(&vk.SubmitInfo{
                    .command_buffer_count = 1,
                    .p_command_buffers = @ptrCast(&cmd_buffer.buffer),
                }),
                .null_handle,
            );
            try vkd.queueWaitIdle(queue.queue);

            stage_buffer.manager.release();
            buffer.stage_buffer = null;
        } else {
            vkd.unmapMemory(buffer.device.device, buffer.memory);
        }
    }
};

pub const Texture = struct {
    manager: utils.Manager(Texture) = .{},
    device: *Device,
    extent: vk.Extent2D,
    image: vk.Image,

    pub fn init(device: *Device, image: vk.Image, extent: vk.Extent2D) !*Texture {
        var texture = try allocator.create(Texture);
        texture.* = .{
            .device = device,
            .extent = extent,
            .image = image,
        };
        return texture;
    }

    pub fn deinit(texture: *Texture) void {
        allocator.destroy(texture);
    }

    pub fn createView(texture: *Texture, desc: ?*const gpu.TextureView.Descriptor) !*TextureView {
        return TextureView.init(texture, desc orelse &gpu.TextureView.Descriptor{}, texture.extent);
    }
};

pub const TextureView = struct {
    manager: utils.Manager(TextureView) = .{},
    device: *Device,
    view: vk.ImageView,
    format: vk.Format,
    extent: vk.Extent2D,

    pub fn init(texture: *Texture, desc: *const gpu.TextureView.Descriptor, extent: vk.Extent2D) !*TextureView {
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

        const vk_view = try vkd.createImageView(texture.device.device, &.{
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

        var view = try allocator.create(TextureView);
        view.* = .{
            .device = texture.device,
            .view = vk_view,
            .format = format,
            .extent = extent,
        };
        return view;
    }

    pub fn deinit(view: *TextureView) void {
        vkd.destroyImageView(view.device.device, view.view, null);
        allocator.destroy(view);
    }
};

pub const BindGroupLayout = struct {
    manager: utils.Manager(BindGroupLayout) = .{},
    device: *Device,
    layout: vk.DescriptorSetLayout,
    desc_types: std.AutoArrayHashMap(vk.DescriptorType, u32),
    bindings: []const vk.DescriptorSetLayoutBinding,

    pub fn init(device: *Device, descriptor: *const gpu.BindGroupLayout.Descriptor) !*BindGroupLayout {
        var bindings = try std.ArrayList(vk.DescriptorSetLayoutBinding).initCapacity(allocator, descriptor.entry_count);
        defer bindings.deinit();

        var desc_types = std.AutoArrayHashMap(vk.DescriptorType, u32).init(allocator);
        errdefer desc_types.deinit();

        if (descriptor.entries) |entries| {
            for (entries[0..descriptor.entry_count]) |entry| {
                const descriptor_type = conv.vulkanDescriptorType(entry);
                if (desc_types.getPtr(descriptor_type)) |count| {
                    count.* += 1;
                } else {
                    try desc_types.put(descriptor_type, 1);
                }

                bindings.appendAssumeCapacity(.{
                    .binding = entry.binding,
                    .descriptor_type = descriptor_type,
                    .descriptor_count = 1,
                    .stage_flags = conv.vulkanShaderStageFlags(entry.visibility),
                });
            }
        }

        const layout = try vkd.createDescriptorSetLayout(device.device, &vk.DescriptorSetLayoutCreateInfo{
            .binding_count = @intCast(bindings.items.len),
            .p_bindings = bindings.items.ptr,
        }, null);

        var bind_group_layout = try allocator.create(BindGroupLayout);
        bind_group_layout.* = .{
            .device = device,
            .layout = layout,
            .desc_types = desc_types,
            .bindings = try bindings.toOwnedSlice(),
        };
        return bind_group_layout;
    }

    pub fn deinit(layout: *BindGroupLayout) void {
        allocator.free(layout.bindings);
        layout.desc_types.deinit();
        vkd.destroyDescriptorSetLayout(layout.device.device, layout.layout, null);
        allocator.destroy(layout);
    }
};

pub const BindGroup = struct {
    manager: utils.Manager(BindGroup) = .{},
    device: *Device,
    desc_set: vk.DescriptorSet,
    desc_pool: vk.DescriptorPool,

    const max_sets = 512;

    pub fn init(device: *Device, desc: *const gpu.BindGroup.Descriptor) !*BindGroup {
        const layout: *BindGroupLayout = @ptrCast(@alignCast(desc.layout));

        var pool_sizes = try std.ArrayList(vk.DescriptorPoolSize).initCapacity(allocator, layout.desc_types.count());
        defer pool_sizes.deinit();

        var desc_types_iter = layout.desc_types.iterator();
        while (desc_types_iter.next()) |entry| {
            pool_sizes.appendAssumeCapacity(.{
                .type = entry.key_ptr.*,
                .descriptor_count = max_sets * entry.value_ptr.*,
            });
        }

        const desc_pool = try vkd.createDescriptorPool(device.device, &vk.DescriptorPoolCreateInfo{
            .max_sets = max_sets,
            .pool_size_count = @intCast(pool_sizes.items.len),
            .p_pool_sizes = pool_sizes.items.ptr,
        }, null);

        var desc_set: vk.DescriptorSet = undefined;
        try vkd.allocateDescriptorSets(device.device, &vk.DescriptorSetAllocateInfo{
            .descriptor_pool = desc_pool,
            .descriptor_set_count = 1,
            .p_set_layouts = @ptrCast(&layout.layout),
        }, @ptrCast(&desc_set));

        var writes = try allocator.alloc(vk.WriteDescriptorSet, layout.bindings.len);
        defer allocator.free(writes);
        var write_buffer_info = try allocator.alloc(vk.DescriptorBufferInfo, layout.bindings.len);
        defer allocator.free(write_buffer_info);
        // var write_image_info = try allocator.alloc(vk.DescriptorImageInfo, layout.bindings.len);

        for (layout.bindings, 0..) |binding, i| {
            writes[i] = .{
                .dst_set = desc_set,
                .dst_binding = binding.binding,
                .dst_array_element = 0,
                .descriptor_count = 1,
                .descriptor_type = binding.descriptor_type,
                .p_image_info = undefined,
                .p_buffer_info = undefined,
                .p_texel_buffer_view = undefined,
            };

            switch (binding.descriptor_type) {
                .uniform_buffer, .uniform_buffer_dynamic => {
                    write_buffer_info[i] = .{
                        .buffer = @as(*Buffer, @ptrCast(@alignCast(desc.entries.?[i].buffer.?))).buffer,
                        .offset = desc.entries.?[i].offset,
                        .range = desc.entries.?[i].size,
                    };
                    writes[i].p_buffer_info = @ptrCast(&write_buffer_info[i]);
                },
                else => unreachable, // TODO
            }
        }

        vkd.updateDescriptorSets(device.device, @intCast(writes.len), writes.ptr, 0, undefined);

        var bind_group = try allocator.create(BindGroup);
        bind_group.* = .{
            .device = device,
            .desc_pool = desc_pool,
            .desc_set = desc_set,
        };
        return bind_group;
    }

    pub fn deinit(group: *BindGroup) void {
        vkd.destroyDescriptorPool(group.device.device, group.desc_pool, null);
        vkd.freeDescriptorSets(
            group.device.device,
            group.desc_pool,
            1,
            @ptrCast(&group.desc_set),
        ) catch unreachable;
    }
};

pub const PipelineLayout = struct {
    manager: utils.Manager(PipelineLayout) = .{},
    device: *Device,
    layout: vk.PipelineLayout,

    pub fn init(device: *Device, descriptor: *const gpu.PipelineLayout.Descriptor) !*PipelineLayout {
        const groups = try allocator.alloc(vk.DescriptorSetLayout, descriptor.bind_group_layout_count);
        defer allocator.free(groups);
        for (groups, 0..) |*layout, i| {
            layout.* = @as(*BindGroupLayout, @ptrCast(@alignCast(descriptor.bind_group_layouts.?[i]))).layout;
        }

        const vk_layout = try vkd.createPipelineLayout(device.device, &.{
            .set_layout_count = @as(u32, @intCast(groups.len)),
            .p_set_layouts = groups.ptr,
        }, null);

        var layout = try allocator.create(PipelineLayout);
        layout.* = .{
            .device = device,
            .layout = vk_layout,
        };
        return layout;
    }

    pub fn deinit(layout: *PipelineLayout) void {
        vkd.destroyPipelineLayout(layout.device.device, layout.layout, null);
        allocator.destroy(layout);
    }
};

pub const ShaderModule = struct {
    manager: utils.Manager(ShaderModule) = .{},
    shader_module: vk.ShaderModule,
    device: *Device,

    pub fn initAir(device: *Device, air: *const shader.Air) !*ShaderModule {
        const code = shader.CodeGen.generate(allocator, air, .spirv, .{ .emit_source_file = "" }) catch unreachable;
        defer allocator.free(code);

        return ShaderModule.initSpirv(device, code);
    }

    pub fn initSpirv(device: *Device, code: []const u8) !*ShaderModule {
        const vk_shader_module = try vkd.createShaderModule(
            device.device,
            &vk.ShaderModuleCreateInfo{
                .code_size = code.len,
                .p_code = @ptrCast(@alignCast(code.ptr)),
            },
            null,
        );

        var shader_module = try allocator.create(ShaderModule);
        shader_module.* = .{
            .device = device,
            .shader_module = vk_shader_module,
        };

        return shader_module;
    }

    pub fn deinit(shader_module: *ShaderModule) void {
        vkd.destroyShaderModule(
            shader_module.device.device,
            shader_module.shader_module,
            null,
        );
        allocator.destroy(shader_module);
    }
};

pub const ComputePipeline = struct {
    manager: utils.Manager(ComputePipeline) = .{},

    pub fn init(device: *Device, desc: *const gpu.ComputePipeline.Descriptor) !*ComputePipeline {
        _ = desc;
        _ = device;
        unreachable;
    }

    pub fn deinit(pipeline: *ComputePipeline) void {
        _ = pipeline;
    }

    pub fn getBindGroupLayout(pipeline: *ComputePipeline, group_index: u32) *BindGroupLayout {
        _ = group_index;
        _ = pipeline;
        unreachable;
    }
};

pub const RenderPipeline = struct {
    manager: utils.Manager(RenderPipeline) = .{},
    device: *Device,
    pipeline: vk.Pipeline,
    layout: *PipelineLayout,

    pub fn init(device: *Device, desc: *const gpu.RenderPipeline.Descriptor) !*RenderPipeline {
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

        var vertex_bindings = try std.ArrayList(vk.VertexInputBindingDescription).initCapacity(allocator, desc.vertex.buffer_count);
        var vertex_attrs = try std.ArrayList(vk.VertexInputAttributeDescription).initCapacity(allocator, desc.vertex.buffer_count);
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

        var pipeline_layout: *PipelineLayout = if (desc.layout) |layout_raw| blk: {
            const layout: *PipelineLayout = @ptrCast(@alignCast(layout_raw));
            layout.manager.reference();
            break :blk layout;
        } else try PipelineLayout.init(device, &.{});

        var blend_attachments: []vk.PipelineColorBlendAttachmentState = &.{};
        defer if (desc.fragment != null) allocator.free(blend_attachments);

        var rp_key = Device.RenderPassKey.init();
        rp_key.samples = sample_count;

        if (desc.fragment) |frag| {
            blend_attachments = try allocator.alloc(vk.PipelineColorBlendAttachmentState, frag.target_count);

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

        const render_pass = try device.createRenderPass(rp_key);

        var pipeline: vk.Pipeline = undefined;
        _ = try vkd.createGraphicsPipelines(device.device, .null_handle, 1, &[_]vk.GraphicsPipelineCreateInfo{.{
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

        var render_pipeline = try allocator.create(RenderPipeline);
        render_pipeline.* = .{
            .device = device,
            .pipeline = pipeline,
            .layout = pipeline_layout,
        };

        return render_pipeline;
    }

    pub fn deinit(render_pipeline: *RenderPipeline) void {
        render_pipeline.device.waitAll() catch {};
        render_pipeline.layout.manager.release();
        vkd.destroyPipeline(render_pipeline.device.device, render_pipeline.pipeline, null);
        allocator.destroy(render_pipeline);
    }

    pub fn getBindGroupLayout(pipeline: *RenderPipeline, group_index: u32) *BindGroupLayout {
        _ = group_index;
        _ = pipeline;
        unreachable;
    }

    fn isDepthBiasEnabled(ds: ?*const gpu.DepthStencilState) vk.Bool32 {
        if (ds == null) return vk.FALSE;
        return @intFromBool(ds.?.depth_bias != 0 or ds.?.depth_bias_slope_scale != 0);
    }
};

pub const CommandBuffer = struct {
    manager: utils.Manager(CommandBuffer) = .{},
    buffer: vk.CommandBuffer,

    pub fn deinit(cmd_buffer: *CommandBuffer) void {
        _ = cmd_buffer;
    }
};

pub const CommandEncoder = struct {
    manager: utils.Manager(CommandEncoder) = .{},
    device: *Device,
    buffer: CommandBuffer,

    pub fn init(device: *Device, desc: ?*const gpu.CommandEncoder.Descriptor) !*CommandEncoder {
        _ = desc;

        var buffer = CommandBuffer{ .buffer = undefined };
        try vkd.allocateCommandBuffers(device.device, &.{
            .command_pool = device.cmd_pool,
            .level = .primary,
            .command_buffer_count = 1,
        }, @ptrCast(&buffer));
        try vkd.beginCommandBuffer(buffer.buffer, &.{ .flags = .{ .one_time_submit_bit = true } });

        var cmd_encoder = try allocator.create(CommandEncoder);
        errdefer allocator.destroy(cmd_encoder);
        cmd_encoder.* = .{
            .device = device,
            .buffer = buffer,
        };

        try device.frameRes().destruction_queue.append(allocator, .{ .cmd_encoder = cmd_encoder });
        return cmd_encoder;
    }

    pub fn deinit(cmd_encoder: *CommandEncoder) void {
        _ = cmd_encoder;
    }

    pub fn beginComputePass(encoder: *CommandEncoder, desc: *const gpu.ComputePassDescriptor) !*ComputePassEncoder {
        _ = desc;
        _ = encoder;
        unreachable;
    }

    pub fn beginRenderPass(cmd_encoder: *CommandEncoder, desc: *const gpu.RenderPassDescriptor) !*RenderPassEncoder {
        return RenderPassEncoder.init(cmd_encoder.device, cmd_encoder, desc);
    }

    pub fn copyBufferToBuffer(encoder: *CommandEncoder, source: *Buffer, source_offset: u64, destination: *Buffer, destination_offset: u64, size: u64) !void {
        const region = vk.BufferCopy{
            .src_offset = source_offset,
            .dst_offset = destination_offset,
            .size = size,
        };
        vkd.cmdCopyBuffer(encoder.buffer.buffer, source.buffer, destination.buffer, 1, @ptrCast(&region));
    }

    pub fn finish(cmd_encoder: *CommandEncoder, desc: *const gpu.CommandBuffer.Descriptor) !*CommandBuffer {
        _ = desc;
        try vkd.endCommandBuffer(cmd_encoder.buffer.buffer);
        return &cmd_encoder.buffer;
    }
};

pub const ComputePassEncoder = struct {
    manager: utils.Manager(ComputePassEncoder) = .{},

    pub fn init(command_encoder: *CommandEncoder, desc: *const gpu.ComputePassDescriptor) !*ComputePassEncoder {
        _ = desc;
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
    device: *Device,
    encoder: *CommandEncoder,
    render_pass: vk.RenderPass,
    framebuffer: vk.Framebuffer,
    extent: vk.Extent2D,
    clear_values: []const vk.ClearValue,
    pipeline: ?*RenderPipeline = null,

    pub fn init(device: *Device, encoder: *CommandEncoder, descriptor: *const gpu.RenderPassDescriptor) !*RenderPassEncoder {
        const depth_stencil_attachment_count = @intFromBool(descriptor.depth_stencil_attachment != null);
        const attachment_count = descriptor.color_attachment_count + depth_stencil_attachment_count;

        var image_views = try std.ArrayList(vk.ImageView).initCapacity(allocator, attachment_count);
        defer image_views.deinit();

        var clear_values = std.ArrayList(vk.ClearValue).init(allocator);
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

        const render_pass = try device.createRenderPass(rp_key);
        const framebuffer = try vkd.createFramebuffer(
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

        var rpe = try allocator.create(RenderPassEncoder);
        errdefer allocator.destroy(rpe);
        rpe.* = .{
            .device = device,
            .encoder = encoder,
            .render_pass = render_pass,
            .framebuffer = framebuffer,
            .extent = extent.?,
            .clear_values = try clear_values.toOwnedSlice(),
        };
        try device.frameRes().destruction_queue.append(allocator, .{ .render_pass_encoder = rpe });

        return rpe;
    }

    pub fn deinit(encoder: *RenderPassEncoder) void {
        _ = encoder;
    }

    pub fn setBindGroup(
        encoder: *RenderPassEncoder,
        group_index: u32,
        group: *BindGroup,
        dynamic_offset_count: usize,
        dynamic_offsets: ?[*]const u32,
    ) !void {
        vkd.cmdBindDescriptorSets(
            encoder.encoder.buffer.buffer,
            .graphics,
            encoder.pipeline.?.layout.layout,
            group_index,
            1,
            @ptrCast(&group.desc_set),
            @intCast(dynamic_offset_count),
            if (dynamic_offsets) |offsets| offsets else &[_]u32{},
        );
    }

    pub fn setPipeline(encoder: *RenderPassEncoder, pipeline: *RenderPipeline) !void {
        const rect = vk.Rect2D{
            .offset = .{ .x = 0, .y = 0 },
            .extent = encoder.extent,
        };

        vkd.cmdBeginRenderPass(encoder.encoder.buffer.buffer, &vk.RenderPassBeginInfo{
            .render_pass = encoder.render_pass,
            .framebuffer = encoder.framebuffer,
            .render_area = rect,
            .clear_value_count = @as(u32, @intCast(encoder.clear_values.len)),
            .p_clear_values = encoder.clear_values.ptr,
        }, .@"inline");
        vkd.cmdBindPipeline(
            encoder.encoder.buffer.buffer,
            .graphics,
            pipeline.pipeline,
        );
        vkd.cmdSetViewport(
            encoder.encoder.buffer.buffer,
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
        vkd.cmdSetScissor(encoder.encoder.buffer.buffer, 0, 1, @as(*const [1]vk.Rect2D, &rect));

        encoder.pipeline = pipeline;
    }

    pub fn setVertexBuffer(encoder: *RenderPassEncoder, slot: u32, buffer: *Buffer, offset: u64, size: u64) !void {
        _ = size;
        vkd.cmdBindVertexBuffers(encoder.encoder.buffer.buffer, slot, 1, @ptrCast(&.{buffer.buffer}), @ptrCast(&offset));
    }

    pub fn draw(encoder: *RenderPassEncoder, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void {
        vkd.cmdDraw(encoder.encoder.buffer.buffer, vertex_count, instance_count, first_vertex, first_instance);
    }

    pub fn end(encoder: *RenderPassEncoder) void {
        vkd.cmdEndRenderPass(encoder.encoder.buffer.buffer);
    }
};

pub const Queue = struct {
    manager: utils.Manager(Queue) = .{},
    device: *Device,
    queue: vk.Queue,

    pub fn init(device: *Device) !Queue {
        const queue = vkd.getDeviceQueue(device.device, device.adapter.queue_family, 0);

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
        const submits = try allocator.alloc(vk.SubmitInfo, commands.len);
        defer allocator.free(submits);

        for (commands, 0..) |buf, i| {
            submits[i] = .{
                .command_buffer_count = 1,
                .p_command_buffers = @ptrCast(&buf.buffer),
                .wait_semaphore_count = 1,
                .p_wait_semaphores = @ptrCast(&queue.device.frameRes().present_semaphore),
                .p_wait_dst_stage_mask = @ptrCast(&dst_stage_masks),
                .signal_semaphore_count = 1,
                .p_signal_semaphores = @ptrCast(&queue.device.frameRes().render_semaphore),
            };
        }

        try vkd.queueSubmit(
            queue.queue,
            @intCast(submits.len),
            submits.ptr,
            queue.device.frameRes().render_fence,
        );
    }

    pub fn writeBuffer(queue: *Queue, buffer: *Buffer, offset: u64, data: [*]const u8, size: u64) !void {
        const stage_buffer = try Buffer.init(queue.device, &.{
            .usage = .{
                .copy_src = true,
                .map_write = true,
            },
            .size = size,
            .mapped_at_creation = .true,
        });
        defer stage_buffer.manager.release();

        @memcpy(stage_buffer.map.?[0..size], data[0..size]);
        var cmd_encoder = try CommandEncoder.init(queue.device, null);
        defer cmd_encoder.manager.release();

        try cmd_encoder.copyBufferToBuffer(stage_buffer, offset, buffer, offset, size);
        const cmd_buffer = try cmd_encoder.finish(&.{});
        defer cmd_buffer.manager.release();

        try vkd.queueSubmit(
            queue.queue,
            1,
            @ptrCast(&vk.SubmitInfo{
                .command_buffer_count = 1,
                .p_command_buffers = @ptrCast(&cmd_buffer.buffer),
            }),
            .null_handle,
        );
        try vkd.queueWaitIdle(queue.queue);
    }
};

const MemoryAllocator = struct {
    info: vk.PhysicalDeviceMemoryProperties,

    const MemoryKind = enum {
        lazily_allocated,
        linear,
        linear_read_mappable,
        linear_write_mappable,
    };

    fn init(physical_device: vk.PhysicalDevice) MemoryAllocator {
        const mem_info = vki.getPhysicalDeviceMemoryProperties(physical_device);
        return .{ .info = mem_info };
    }

    fn findBestAllocator(
        mem_alloc: *MemoryAllocator,
        requirements: vk.MemoryRequirements,
        mem_kind: MemoryKind,
    ) ?u32 {
        const mem_types = mem_alloc.info.memory_types[0..mem_alloc.info.memory_type_count];
        const mem_heaps = mem_alloc.info.memory_heaps[0..mem_alloc.info.memory_heap_count];

        var best_type: ?u32 = null;
        for (mem_types, 0..) |mem_type, i| {
            if (requirements.memory_type_bits & (@as(u32, @intCast(1)) << @intCast(i)) == 0) continue;

            const flags = mem_type.property_flags;
            const heap_size = mem_heaps[mem_type.heap_index].size;
            const candidate = switch (mem_kind) {
                .lazily_allocated => flags.lazily_allocated_bit,
                .linear_write_mappable => flags.host_visible_bit and flags.host_coherent_bit,
                .linear_read_mappable => blk: {
                    if (flags.host_visible_bit and flags.host_coherent_bit) {
                        if (best_type) |best| {
                            if (mem_types[best].property_flags.host_cached_bit) {
                                if (flags.host_cached_bit) {
                                    const best_heap_size = mem_heaps[mem_types[best].heap_index].size;
                                    if (heap_size > best_heap_size) {
                                        break :blk true;
                                    }
                                }

                                break :blk false;
                            }
                        }

                        break :blk true;
                    }

                    break :blk false;
                },
                .linear => blk: {
                    if (best_type) |best| {
                        if (mem_types[best].property_flags.device_local_bit) {
                            if (flags.device_local_bit) {
                                const best_heap_size = mem_heaps[mem_types[best].heap_index].size;
                                if (heap_size > best_heap_size or flags.host_visible_bit) {
                                    break :blk true;
                                }
                            }

                            break :blk false;
                        }
                    }

                    break :blk true;
                },
            };

            if (candidate) best_type = @intCast(i);
        }

        return best_type;
    }
};

test "reference declarations" {
    std.testing.refAllDeclsRecursive(@This());
}
