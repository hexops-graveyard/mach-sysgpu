const std = @import("std");
const gpu = @import("mach-gpu");
const vk = @import("vulkan");
const Base = @import("Base.zig");
const Surface = @import("Surface.zig");
const global = @import("global.zig");
const RefCounter = @import("../helper.zig").RefCounter;

const Dispatch = vk.InstanceWrapper(.{
    .destroyInstance = true,
    .createXlibSurfaceKHR = true,
    .createDevice = true,
    .enumeratePhysicalDevices = true,
    .enumerateDeviceExtensionProperties = true,
    .enumerateDeviceLayerProperties = true,
    .getDeviceProcAddr = true,
    .getPhysicalDeviceProperties = true,
    .getPhysicalDeviceFeatures = true,
    .getPhysicalDeviceQueueFamilyProperties = true,
});

const Instance = @This();

allocator: std.mem.Allocator,
ref_counter: RefCounter(Instance) = .{},
base: Base,
dispatch: Dispatch,
instance: vk.Instance,

pub fn init(descriptor: *const gpu.Instance.Descriptor, allocator: std.mem.Allocator) !Instance {
    _ = descriptor;

    const base = try Base.init(allocator);

    const app_info = vk.ApplicationInfo{
        .p_application_name = "Dusk WebGPU",
        .application_version = vk.makeApiVersion(0, 0, 0, 0),
        .p_engine_name = "Mach Engine",
        .engine_version = vk.makeApiVersion(0, 0, 0, 0),
        .api_version = global.vulkan_version,
    };
    const layers = try getLayers(base);
    const extensions: []const [*:0]const u8 = &.{
        vk.extension_info.khr_surface.name,
        vk.extension_info.khr_xlib_surface.name,
    };

    const instance = try base.createInstance(.{
        .p_application_info = &app_info,
        .enabled_layer_count = @intCast(layers.len),
        .pp_enabled_layer_names = layers.ptr,
        .enabled_extension_count = @intCast(extensions.len),
        .pp_enabled_extension_names = extensions.ptr,
    });

    const dispatch = try Dispatch.load(instance, base.getInstanceProcAddr());

    return .{
        .allocator = allocator,
        .base = base,
        .dispatch = dispatch,
        .instance = instance,
    };
}

pub fn deinit(instance: *Instance) void {
    instance.dispatch.destroyInstance(instance.instance, null);
    instance.base.deinit();
}

pub fn createSurface(instance: *Instance, descriptor: *const gpu.Surface.Descriptor) !Surface {
    return Surface.init(instance, descriptor);
}

fn getLayers(base: Base) ![]const [*:0]const u8 {
    var layer_count: u32 = 0;
    _ = try base.dispatch.enumerateInstanceLayerProperties(&layer_count, null);

    var available_layers = try base.allocator.alloc(vk.LayerProperties, layer_count);
    defer base.allocator.free(available_layers);

    _ = try base.dispatch.enumerateInstanceLayerProperties(&layer_count, available_layers.ptr);

    for (available_layers[0..layer_count]) |available| {
        if (std.mem.eql(u8, global.validation_layer, std.mem.sliceTo(&available.layer_name, 0))) {
            return &.{global.validation_layer};
        }
    }

    return &.{};
}
