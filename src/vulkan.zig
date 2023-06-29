const std = @import("std");
const builtin = @import("builtin");
const vk = @import("vulkan");
const gpu = @import("mach-gpu");

const BaseDispatch = vk.BaseWrapper(.{
    .createInstance = true,
    .enumerateInstanceExtensionProperties = true,
    .getInstanceProcAddr = true,
});

const InstanceDispatch = vk.InstanceWrapper(.{
    .destroyInstance = true,
    .enumeratePhysicalDevices = true,
    .getPhysicalDeviceProperties = true,
    .getPhysicalDeviceSurfacePresentModesKHR = true,
    .getPhysicalDeviceSurfaceFormatsKHR = true,
    .enumerateDeviceExtensionProperties = true,
    .getPhysicalDeviceSurfaceSupportKHR = true,
    .getPhysicalDeviceQueueFamilyProperties = true,
});

pub const Instance = struct {
    vulkan_loader: std.DynLib,
    vulkan_instance: vk.Instance,
    vkb: BaseDispatch,
    vki: InstanceDispatch,

    pub fn create(descriptor: ?*const gpu.Instance.Descriptor) !Instance {
        if (descriptor != null) @panic("TODO");

        // NOTE: ElfDynLib is unable to find vulkan, so forcing libc means we always use DlDynlib even on Linux
        if (!builtin.link_libc) @compileError("You must link libc!");

        var vulkan_loader = try std.DynLib.open(switch (builtin.os.tag) {
            .windows => "vulkan-1.dll",
            .linux => "libvulkan.so.1",
            .macos => "libvulkan.1.dylib",
            else => @compileError("Unknown OS!"),
        });

        var vkb = try BaseDispatch.load(vulkan_loader.lookup(vk.PfnGetInstanceProcAddr, "vkGetInstanceProcAddr").?);

        const app_info = vk.ApplicationInfo{
            .p_application_name = "Dusk",
            .application_version = vk.makeApiVersion(0, 0, 0, 0),
            .p_engine_name = "Dusk",
            .engine_version = vk.makeApiVersion(0, 0, 0, 0),
            .api_version = vk.makeApiVersion(0, 0, 0, 0),
        };

        //NOTE: Theoretically we dont always need KHR_surface, but for loading simplicity, lets assume we will always be using vulkan drivers with it
        const instance_extensions: []const [*:0]const u8 = &.{
            vk.extension_info.khr_surface.name,
        };

        const vulkan_instance = try vkb.createInstance(&vk.InstanceCreateInfo{
            .p_application_info = &app_info,
            .enabled_extension_count = instance_extensions.len,
            .pp_enabled_extension_names = instance_extensions.ptr,
        }, null);

        const vki = try InstanceDispatch.load(vulkan_instance, vkb.dispatch.vkGetInstanceProcAddr);

        return Instance{
            .vulkan_loader = vulkan_loader,
            .vulkan_instance = vulkan_instance,
            .vkb = vkb,
            .vki = vki,
        };
    }

    pub fn deinit(self: *Instance) void {
        self.vki.destroyInstance(self.vulkan_instance, null);
        self.vulkan_loader.close();
    }
};

pub const Adapter = struct {
    instance: *Instance,
    vulkan_physical_device: vk.PhysicalDevice,
    queues: QueueAllocation,
    properties: vk.PhysicalDeviceProperties,

    pub fn create(instance: *Instance, options: gpu.RequestAdapterOptions, allocator: std.mem.Allocator) !Adapter {
        const device_candidate = try pickPhysicalDevice(instance, options, allocator);

        var adapter: Adapter = Adapter{
            .vulkan_physical_device = device_candidate.physical_device,
            .queues = device_candidate.queues,
            .properties = device_candidate.properties,
            .instance = instance,
        };

        return adapter;
    }

    pub fn deinit(self: *Adapter) void {
        _ = self;
    }
};

pub const Surface = struct {
    vulkan_surface: vk.SurfaceKHR,
};

const QueueAllocation = struct {
    graphics_family: u32,
    compute_family: u32,
    present_family: ?u32,
};

const DeviceCandidate = struct {
    physical_device: vk.PhysicalDevice,
    properties: vk.PhysicalDeviceProperties,
    queues: QueueAllocation,
};

fn pickPhysicalDevice(instance: *Instance, options: gpu.RequestAdapterOptions, allocator: std.mem.Allocator) !DeviceCandidate {
    var device_count: u32 = undefined;
    _ = try instance.vki.enumeratePhysicalDevices(instance.vulkan_instance, &device_count, null);

    const physical_devices = try allocator.alloc(vk.PhysicalDevice, device_count);
    defer allocator.free(physical_devices);

    _ = try instance.vki.enumeratePhysicalDevices(instance.vulkan_instance, &device_count, physical_devices.ptr);

    for (physical_devices) |physical_device| {
        if (try isSuitable(instance.vki, physical_device, options, allocator)) |candidate| {
            return candidate;
        }
    }

    @panic("NO SUITABLE DEVICE");
}

fn isSuitable(vki: InstanceDispatch, physical_device: vk.PhysicalDevice, options: gpu.RequestAdapterOptions, allocator: std.mem.Allocator) !?DeviceCandidate {
    const props = vki.getPhysicalDeviceProperties(physical_device);

    std.debug.print("trying physical device {s}\n", .{std.mem.sliceTo(&props.device_name, 0)});

    if (!try checkExtensionSupport(vki, physical_device, allocator)) {
        std.debug.print("no extension support\n", .{});

        return null;
    }

    if (options.compatible_surface) |surface| {
        var surface_impl: *Surface = @ptrCast(@alignCast(surface));

        if (!try checkSurfaceSupport(vki, physical_device, surface_impl.vulkan_surface)) {
            std.debug.print("no surface support\n", .{});
            return null;
        }
    }

    if (try allocateQueues(vki, physical_device, allocator, options)) |allocation| {
        return DeviceCandidate{
            .physical_device = physical_device,
            .properties = props,
            .queues = allocation,
        };
    }

    std.debug.print("failed to allocate queues\n", .{});

    return null;
}

fn allocateQueues(vki: InstanceDispatch, pdev: vk.PhysicalDevice, allocator: std.mem.Allocator, options: gpu.RequestAdapterOptions) !?QueueAllocation {
    var family_count: u32 = undefined;
    vki.getPhysicalDeviceQueueFamilyProperties(pdev, &family_count, null);

    const families = try allocator.alloc(vk.QueueFamilyProperties, family_count);
    defer allocator.free(families);
    vki.getPhysicalDeviceQueueFamilyProperties(pdev, &family_count, families.ptr);

    var graphics_family: ?u32 = null;
    var compute_family: ?u32 = null;
    var present_family: ?u32 = null;

    for (families, 0..) |properties, i| {
        const family: u32 = @intCast(i);

        if (graphics_family == null and properties.queue_flags.graphics_bit) {
            graphics_family = family;
        }

        if (compute_family == null and properties.queue_flags.compute_bit) {
            compute_family = family;
        }

        if (options.compatible_surface) |surface| {
            var surface_impl: *Surface = @ptrCast(@alignCast(surface));

            if (present_family == null and (try vki.getPhysicalDeviceSurfaceSupportKHR(pdev, family, surface_impl.vulkan_surface)) == vk.TRUE) {
                present_family = family;
            }
        }
    }

    if (graphics_family != null and compute_family != null) {
        return QueueAllocation{
            .graphics_family = graphics_family.?,
            .present_family = present_family,
            .compute_family = compute_family.?,
        };
    }

    return null;
}

fn checkExtensionSupport(vki: InstanceDispatch, physical_device: vk.PhysicalDevice, allocator: std.mem.Allocator) !bool {
    var count: u32 = undefined;
    _ = try vki.enumerateDeviceExtensionProperties(physical_device, null, &count, null);

    const properties = try allocator.alloc(vk.ExtensionProperties, count);
    defer allocator.free(properties);

    _ = try vki.enumerateDeviceExtensionProperties(physical_device, null, &count, properties.ptr);

    //TODO: only check for KHR_swapchain if compatible_surface is non-null!!
    const required_device_extensions = [_][*:0]const u8{
        vk.extension_info.khr_swapchain.name,
    };

    for (required_device_extensions) |ext| {
        for (properties) |props| {
            const len = std.mem.indexOfScalar(u8, &props.extension_name, 0).?;
            const prop_ext_name = props.extension_name[0..len];
            if (std.mem.eql(u8, std.mem.span(ext), prop_ext_name)) {
                break;
            }
        } else {
            return false;
        }
    }

    return true;
}

fn checkSurfaceSupport(vki: InstanceDispatch, physical_device: vk.PhysicalDevice, surface: vk.SurfaceKHR) !bool {
    var format_count: u32 = undefined;
    _ = try vki.getPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &format_count, null);

    var present_mode_count: u32 = undefined;
    _ = try vki.getPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &present_mode_count, null);

    return format_count > 0 and present_mode_count > 0;
}
