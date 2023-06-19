const std = @import("std");
const testing = std.testing;
const dawn = @import("dawn.zig");
const ChainedStructOut = @import("gpu.zig").ChainedStructOut;
const Device = @import("device.zig").Device;
const FeatureName = @import("gpu.zig").FeatureName;
const SupportedLimits = @import("gpu.zig").SupportedLimits;
const RequestDeviceStatus = @import("gpu.zig").RequestDeviceStatus;
const BackendType = @import("gpu.zig").BackendType;
const RequestDeviceCallback = @import("gpu.zig").RequestDeviceCallback;
const Impl = @import("interface.zig").Impl;

pub const Adapter = opaque {
    pub const Type = enum(u32) {
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

    pub const Properties = extern struct {
        pub const NextInChain = extern union {
            generic: ?*const ChainedStructOut,
            dawn_adapter_properties_power_preference: *const dawn.AdapterPropertiesPowerPreference,
        };

        next_in_chain: NextInChain = .{ .generic = null },
        vendor_id: u32,
        vendor_name: [*:0]const u8,
        architecture: [*:0]const u8,
        device_id: u32,
        name: [*:0]const u8,
        driver_description: [*:0]const u8,
        adapter_type: Type,
        backend_type: BackendType,
    };
};

test "Adapter.Type name" {
    try testing.expectEqualStrings("Discrete GPU", Adapter.Type.discrete_gpu.name());
}
