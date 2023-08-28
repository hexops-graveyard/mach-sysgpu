const std = @import("std");
const builtin = @import("builtin");
const gpu = @import("gpu");
const vk = @import("vulkan");
const dusk = @import("../main.zig");
const utils = @import("../utils.zig");
const proc = @import("proc.zig");
const Device = @import("device.zig").Device;

const api_version = vk.makeApiVersion(0, 1, 1, 0);

pub const Instance = struct {
    manager: utils.Manager(Instance) = .{},
    instance: vk.Instance,

    pub fn init(desc: *const gpu.Instance.Descriptor) !Instance {
        _ = desc;

        try proc.init();
        try proc.loadBase();

        const app_info = vk.ApplicationInfo{
            .application_version = 0,
            .engine_version = 0,
            .api_version = api_version,
        };

        const layers = try queryLayers();
        defer dusk.allocator.free(layers);

        const extensions = try queryExtensions();
        defer dusk.allocator.free(extensions);

        const instance = try proc.base.createInstance(&vk.InstanceCreateInfo{
            .p_application_info = &app_info,
            .enabled_layer_count = @intCast(layers.len),
            .pp_enabled_layer_names = layers.ptr,
            .enabled_extension_count = @intCast(extensions.len),
            .pp_enabled_extension_names = extensions.ptr,
        }, null);

        try proc.loadInstance(instance);

        return .{ .instance = instance };
    }

    pub fn deinit(instance: *Instance) void {
        proc.instance.destroyInstance(instance.instance, null);
    }

    pub fn requestAdapter(
        instance: *Instance,
        options: ?*const gpu.RequestAdapterOptions,
        callback: gpu.RequestAdapterCallback,
        userdata: ?*anyopaque,
    ) !Adapter {
        return Adapter.init(instance.instance, options orelse &gpu.RequestAdapterOptions{}) catch |err| {
            return callback(.err, undefined, @errorName(err), userdata);
        };
    }

    pub fn createSurface(instance: *Instance, desc: *const gpu.Surface.Descriptor) !Surface {
        return Surface.init(instance, desc);
    }

    pub const required_layers = &[_][*:0]const u8{};
    pub const optional_layers = if (builtin.mode == .Debug and false)
        &[_][*:0]const u8{"VK_LAYER_KHRONOS_validation"}
    else
        &.{};

    fn queryLayers() ![]const [*:0]const u8 {
        var layers = try std.ArrayList([*:0]const u8).initCapacity(
            dusk.allocator,
            required_layers.len + optional_layers.len,
        );
        errdefer layers.deinit();

        var count: u32 = 0;
        _ = try proc.base.enumerateInstanceLayerProperties(&count, null);

        var available_layers = try dusk.allocator.alloc(vk.LayerProperties, count);
        defer dusk.allocator.free(available_layers);
        _ = try proc.base.enumerateInstanceLayerProperties(&count, available_layers.ptr);

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

    pub const required_extensions: []const [*:0]const u8 = switch (builtin.target.os.tag) {
        .linux => &.{
            vk.extension_info.khr_surface.name,
            vk.extension_info.khr_xlib_surface.name,
            vk.extension_info.khr_xcb_surface.name,
            vk.extension_info.khr_wayland_surface.name,
        },
        .windows => &.{
            vk.extension_info.khr_surface.name,
            vk.extension_info.khr_win_32_surface.name,
        },
        .macos, .ios => &.{
            vk.extension_info.khr_surface.name,
            vk.extension_info.ext_metal_surface.name,
        },
        else => if (builtin.target.abi == .android)
            &.{
                vk.extension_info.khr_surface.name,
                vk.extension_info.khr_android_surface.name,
            }
        else
            @compileError("unsupported platform"),
    };
    pub const optional_extensions = &[_][*:0]const u8{};

    fn queryExtensions() ![]const [*:0]const u8 {
        var extensions = try std.ArrayList([*:0]const u8).initCapacity(
            dusk.allocator,
            required_extensions.len + optional_extensions.len,
        );
        errdefer extensions.deinit();

        var count: u32 = 0;
        _ = try proc.base.enumerateInstanceExtensionProperties(null, &count, null);

        var available_extensions = try dusk.allocator.alloc(vk.ExtensionProperties, count);
        defer dusk.allocator.free(available_extensions);
        _ = try proc.base.enumerateInstanceExtensionProperties(null, &count, available_extensions.ptr);

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

    pub fn init(instance: *Instance, options: *const gpu.RequestAdapterOptions) !Adapter {
        var device_count: u32 = 0;
        _ = try proc.instance.enumeratePhysicalDevices(instance.instance, &device_count, null);

        var physical_devices = try dusk.allocator.alloc(vk.PhysicalDevice, device_count);
        defer dusk.allocator.free(physical_devices);
        _ = try proc.instance.enumeratePhysicalDevices(instance.instance, &device_count, physical_devices.ptr);

        var physical_device_info: ?struct {
            physical_device: vk.PhysicalDevice,
            props: vk.PhysicalDeviceProperties,
            queue_family: u32,
            score: u32,
        } = null;
        for (physical_devices[0..device_count]) |physical_device| {
            const props = proc.instance.getPhysicalDeviceProperties(physical_device);
            const features = proc.instance.getPhysicalDeviceFeatures(physical_device);
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
            var extensions_count: u32 = 0;
            _ = try proc.instance.enumerateDeviceExtensionProperties(info.physical_device, null, &extensions_count, null);

            var extensions = try dusk.allocator.alloc(vk.ExtensionProperties, extensions_count);
            errdefer dusk.allocator.free(extensions);
            _ = try proc.instance.enumerateDeviceExtensionProperties(info.physical_device, null, &extensions_count, extensions.ptr);

            const driver_desc = try std.fmt.allocPrintZ(
                dusk.allocator,
                "Vulkan driver version {}.{}.{}",
                .{
                    vk.apiVersionMajor(info.props.driver_version),
                    vk.apiVersionMinor(info.props.driver_version),
                    vk.apiVersionPatch(info.props.driver_version),
                },
            );

            return .{
                .instance = instance,
                .physical_device = info.physical_device,
                .props = info.props,
                .queue_family = info.queue_family,
                .extensions = extensions,
                .driver_desc = driver_desc,
                .vendor_id = @enumFromInt(info.props.vendor_id),
            };
        }

        return error.NoAdapterFound;
    }

    pub fn deinit(adapter: *Adapter) void {
        dusk.allocator.free(adapter.extensions);
        dusk.allocator.free(adapter.driver_desc);
    }

    pub fn createDevice(adapter: *Adapter, desc: *const gpu.Device.Descriptor) !Device {
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
        var queue_family_count: u32 = 0;
        _ = proc.instance.getPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, null);

        var queue_families = try dusk.allocator.alloc(vk.QueueFamilyProperties, queue_family_count);
        defer dusk.allocator.free(queue_families);
        _ = proc.instance.getPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, queue_families.ptr);

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

    pub fn init(instance: *Instance, desc: *const gpu.Surface.Descriptor) !Surface {
        const surface = switch (builtin.target.os.tag) {
            .linux => blk: {
                if (utils.findChained(gpu.Surface.DescriptorFromXlibWindow, desc.next_in_chain.generic)) |x_desc| {
                    break :blk try proc.instance.createXlibSurfaceKHR(
                        instance.instance,
                        &vk.XlibSurfaceCreateInfoKHR{
                            .dpy = @ptrCast(x_desc.display),
                            .window = x_desc.window,
                        },
                        null,
                    );
                } else if (utils.findChained(gpu.Surface.DescriptorFromWaylandSurface, desc.next_in_chain.generic)) |wayland_desc| {
                    break :blk try proc.instance.createWaylandSurfaceKHR(
                        instance.instance,
                        &vk.WaylandSurfaceCreateInfoKHR{
                            .display = @ptrCast(wayland_desc.display),
                            .surface = @ptrCast(wayland_desc.surface),
                        },
                        null,
                    );
                }

                return error.InvalidDescriptor;
            },
            .windows => blk: {
                if (utils.findChained(gpu.Surface.DescriptorFromWindowsHWND, desc.next_in_chain.generic)) |win_desc| {
                    break :blk try proc.instance.createWin32SurfaceKHR(
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

        return .{
            .instance = instance,
            .surface = surface,
        };
    }

    pub fn deinit(surface: *Surface) void {
        proc.instance.destroySurfaceKHR(surface.instance.instance, surface.surface, null);
    }
};
