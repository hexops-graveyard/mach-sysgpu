const std = @import("std");
const gpu = @import("gpu");
const ca = @import("objc/ca.zig");
const mtl = @import("objc/mtl.zig");
const ns = @import("objc/ns.zig");
const utils = @import("../utils.zig");
const Device = @import("device.zig").Device;

pub const Instance = struct {
    manager: utils.Manager(Instance) = .{},

    pub fn init(desc: *const gpu.Instance.Descriptor) !Instance {
        // TODO
        _ = desc;

        ns.init();
        ca.init();
        mtl.init();
        return .{};
    }

    pub fn deinit(instance: *Instance) void {
        _ = instance;
    }

    pub fn createSurface(instance: *Instance, desc: *const gpu.Surface.Descriptor) !Surface {
        return Surface.init(instance, desc);
    }
};

pub const Adapter = struct {
    manager: utils.Manager(Adapter) = .{},
    device: *mtl.Device,

    pub fn init(instance: *Instance, options: *const gpu.RequestAdapterOptions) !Adapter {
        _ = instance;
        _ = options;

        // TODO - choose appropriate device from options
        const device = mtl.createSystemDefaultDevice() orelse {
            return error.NoAdapterFound;
        };

        return .{ .device = device };
    }

    pub fn deinit(adapter: *Adapter) void {
        adapter.device.release();
    }

    pub fn createDevice(adapter: *Adapter, desc: *const gpu.Device.Descriptor) !Device {
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

    pub fn init(instance: *Instance, desc: *const gpu.Surface.Descriptor) !Surface {
        _ = instance;

        if (utils.findChained(gpu.Surface.DescriptorFromMetalLayer, desc.next_in_chain.generic)) |mtl_desc| {
            return .{ .layer = @ptrCast(mtl_desc.layer) };
        } else {
            return error.InvalidDescriptor;
        }
    }

    pub fn deinit(surface: *Surface) void {
        _ = surface;
    }
};
