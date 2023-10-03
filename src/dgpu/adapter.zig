const std = @import("std");
const testing = std.testing;
const Device = @import("device.zig").Device;
const Instance = @import("instance.zig").Instance;
const FeatureName = @import("main.zig").FeatureName;
const Limits = @import("main.zig").Limits;
const Surface = @import("surface.zig").Surface;
const BackendType = @import("main.zig").BackendType;
const Impl = @import("interface.zig").Impl;

pub const Adapter = opaque {
    pub const Descriptor = struct {
        compatible_surface: ?*Surface = null,
        power_preference: PowerPreference = .undefined,
        backend_type: BackendType = .undefined,
        force_fallback_adapter: bool = false,
        compatibility_mode: bool = false,
    };

    pub const PowerPreference = enum {
        undefined,
        low_power,
        high_performance,
    };

    pub const Type = enum {
        discrete_gpu,
        integrated_gpu,
        cpu,
        unknown,

        pub fn name(t: Type) []const u8 {
            return switch (t) {
                .discrete_gpu => "Discrete GPU",
                .integrated_gpu => "Integrated GPU",
                .cpu => "CPU",
                .unknown => "Unknown",
            };
        }
    };

    pub const Properties = struct {
        vendor_id: u32,
        vendor_name: []const u8,
        architecture: []const u8,
        device_id: u32,
        name: []const u8,
        driver_description: []const u8,
        adapter_type: Type,
        backend_type: BackendType,
        compatibility_mode: bool = false,
    };

    pub inline fn createDevice(adapter: *Adapter, descriptor: Device.Descriptor) ?*Device {
        return Impl.adapterCreateDevice(adapter, descriptor);
    }

    /// Call once with null to determine the array length, and again to fetch the feature list.
    ///
    /// Consider using the enumerateFeaturesOwned helper.
    pub inline fn enumerateFeatures(adapter: *Adapter, features: ?[*]FeatureName) usize {
        return Impl.adapterEnumerateFeatures(adapter, features);
    }

    /// Enumerates the adapter features, storing the result in an allocated slice which is owned by
    /// the caller.
    pub inline fn enumerateFeaturesOwned(adapter: *Adapter, allocator: std.mem.Allocator) ![]FeatureName {
        const count = adapter.enumerateFeatures(null);
        var data = try allocator.alloc(FeatureName, count);
        _ = adapter.enumerateFeatures(data.ptr);
        return data;
    }

    pub inline fn getInstance(adapter: *Adapter) *Instance {
        return Impl.adapterGetInstance(adapter);
    }

    pub inline fn getLimits(adapter: *Adapter) Limits {
        return Impl.adapterGetLimits(adapter);
    }

    pub inline fn getProperties(adapter: *Adapter) Adapter.Properties {
        return Impl.adapterGetProperties(adapter);
    }

    pub inline fn hasFeature(adapter: *Adapter, feature: FeatureName) bool {
        return Impl.adapterHasFeature(adapter, feature);
    }

    pub inline fn reference(adapter: *Adapter) void {
        Impl.adapterReference(adapter);
    }

    pub inline fn release(adapter: *Adapter) void {
        Impl.adapterRelease(adapter);
    }
};
