const std = @import("std");
const vk = @import("vulkan");
const gpu = @import("mach-gpu");
const Instance = @import("Instance.zig");
const Device = @import("Device.zig");
const global = @import("global.zig");
const RefCounter = @import("../helper.zig").RefCounter;

const Adapter = @This();

ref_counter: RefCounter(Adapter) = .{},
instance: *Instance,
device: vk.PhysicalDevice,
props: vk.PhysicalDeviceProperties,
queue_families: QueueFamilies,
extensions: []const vk.ExtensionProperties,
vendor_id: VendorID,
driver_descriptor: [:0]const u8,

pub fn init(instance: *Instance, options: *const gpu.RequestAdapterOptions) !Adapter {
    var device_count: u32 = 0;
    _ = try instance.dispatch.enumeratePhysicalDevices(instance.instance, &device_count, null);

    var device_list = try instance.allocator.alloc(vk.PhysicalDevice, device_count);
    defer instance.allocator.free(device_list);
    _ = try instance.dispatch.enumeratePhysicalDevices(instance.instance, &device_count, device_list.ptr);

    var device_info: ?struct {
        dev: vk.PhysicalDevice,
        props: vk.PhysicalDeviceProperties,
        queue_families: QueueFamilies,
        score: u32,
    } = null;
    for (device_list[0..device_count]) |dev| {
        const props = instance.dispatch.getPhysicalDeviceProperties(dev);
        const features = instance.dispatch.getPhysicalDeviceFeatures(dev);
        const queue_families = try findQueueFamilies(instance, dev) orelse continue;

        if (isDeviceSuitable(props, features)) {
            const score = rateDevice(props, features, options.power_preference);
            if (score == 0) continue;

            if (device_info == null or score > device_info.?.score) {
                device_info = .{
                    .dev = dev,
                    .props = props,
                    .queue_families = queue_families,
                    .score = score,
                };
            }
        }
    }

    if (device_info) |dev_info| {
        var extensions_count: u32 = 0;
        _ = try instance.dispatch.enumerateDeviceExtensionProperties(dev_info.dev, null, &extensions_count, null);

        var extensions = try instance.allocator.alloc(vk.ExtensionProperties, extensions_count);
        errdefer instance.allocator.free(extensions);
        _ = try instance.dispatch.enumerateDeviceExtensionProperties(dev_info.dev, null, &extensions_count, extensions.ptr);

        const driver_descriptor = try std.fmt.allocPrintZ(
            instance.allocator,
            "Vulkan driver version {}.{}.{}",
            .{
                vk.apiVersionMajor(dev_info.props.driver_version),
                vk.apiVersionMinor(dev_info.props.driver_version),
                vk.apiVersionPatch(dev_info.props.driver_version),
            },
        );

        return .{
            .instance = instance,
            .device = dev_info.dev,
            .props = dev_info.props,
            .queue_families = dev_info.queue_families,
            .extensions = extensions,
            .vendor_id = @enumFromInt(dev_info.props.vendor_id),
            .driver_descriptor = driver_descriptor,
        };
    }

    return error.NoAdapterFound;
}

pub fn deinit(adapter: *Adapter) void {
    adapter.instance.allocator.free(adapter.extensions);
    adapter.instance.allocator.free(adapter.driver_descriptor);
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
        .driver_description = adapter.driver_descriptor,
        .adapter_type = adapter_type,
        .backend_type = .vulkan,
        .compatibility_mode = false, // TODO
    };
}

fn isDeviceSuitable(props: vk.PhysicalDeviceProperties, features: vk.PhysicalDeviceFeatures) bool {
    return props.api_version >= global.vulkan_version and
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

const QueueFamilies = struct {
    graphics: u32,
    compute: u32,
};

fn findQueueFamilies(instance: *Instance, device: vk.PhysicalDevice) !?QueueFamilies {
    var queue_family_count: u32 = 0;
    _ = instance.dispatch.getPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, null);

    var queue_families = try instance.allocator.alloc(vk.QueueFamilyProperties, queue_family_count);
    defer instance.allocator.free(queue_families);
    _ = instance.dispatch.getPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, queue_families.ptr);

    var graphics: ?u32 = null;
    var compute: ?u32 = null;

    for (queue_families, 0..) |family, i| {
        if (family.queue_flags.graphics_bit and family.queue_flags.compute_bit) {
            graphics = @intCast(i);
            compute = @intCast(i);
            break;
        }

        if (family.queue_flags.graphics_bit) {
            graphics = @intCast(i);
        }

        if (family.queue_flags.compute_bit) {
            compute = @intCast(i);
        }

        if (graphics != null and compute != null) {
            break;
        }
    } else {
        return null;
    }

    return .{
        .graphics = graphics.?,
        .compute = compute.?,
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

pub fn createDevice(adapter: *Adapter, descriptor: *const gpu.Device.Descriptor) !Device {
    return Device.init(adapter, descriptor);
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
