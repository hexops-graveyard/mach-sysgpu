const std = @import("std");
const vk = @import("vulkan");
const gpu = @import("gpu");
const Instance = @import("Instance.zig");
const Device = @import("Device.zig");
const Manager = @import("../helper.zig").Manager;
const api_version = @import("../vulkan.zig").api_version;

const Adapter = @This();

manager: Manager(Adapter) = .{},
allocator: std.mem.Allocator,
instance: *Instance,
physical_device: vk.PhysicalDevice,
props: vk.PhysicalDeviceProperties,
queue_family: u32,
extensions: []const vk.ExtensionProperties,
driver_desc: [:0]const u8,
vendor_id: VendorID,

pub fn init(instance: *Instance, options: *const gpu.RequestAdapterOptions) !Adapter {
    var device_count: u32 = 0;
    _ = try instance.dispatch.enumeratePhysicalDevices(instance.instance, &device_count, null);

    var physical_devices = try instance.allocator.alloc(vk.PhysicalDevice, device_count);
    defer instance.allocator.free(physical_devices);
    _ = try instance.dispatch.enumeratePhysicalDevices(instance.instance, &device_count, physical_devices.ptr);

    var physical_device_info: ?struct {
        physical_device: vk.PhysicalDevice,
        props: vk.PhysicalDeviceProperties,
        queue_family: u32,
        score: u32,
    } = null;
    for (physical_devices[0..device_count]) |physical_device| {
        const props = instance.dispatch.getPhysicalDeviceProperties(physical_device);
        const features = instance.dispatch.getPhysicalDeviceFeatures(physical_device);
        const queue_family = try findQueueFamily(instance, physical_device) orelse continue;

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
        _ = try instance.dispatch.enumerateDeviceExtensionProperties(info.physical_device, null, &extensions_count, null);

        var extensions = try instance.allocator.alloc(vk.ExtensionProperties, extensions_count);
        errdefer instance.allocator.free(extensions);
        _ = try instance.dispatch.enumerateDeviceExtensionProperties(info.physical_device, null, &extensions_count, extensions.ptr);

        const driver_desc = try std.fmt.allocPrintZ(
            instance.allocator,
            "Vulkan driver version {}.{}.{}",
            .{
                vk.apiVersionMajor(info.props.driver_version),
                vk.apiVersionMinor(info.props.driver_version),
                vk.apiVersionPatch(info.props.driver_version),
            },
        );

        return .{
            .allocator = instance.allocator,
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
    adapter.allocator.free(adapter.extensions);
    adapter.allocator.free(adapter.driver_desc);
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
        .compatibility_mode = false, // TODO
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

fn findQueueFamily(instance: *Instance, device: vk.PhysicalDevice) !?u32 {
    var queue_family_count: u32 = 0;
    _ = instance.dispatch.getPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, null);

    var queue_families = try instance.allocator.alloc(vk.QueueFamilyProperties, queue_family_count);
    defer instance.allocator.free(queue_families);
    _ = instance.dispatch.getPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, queue_families.ptr);

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
