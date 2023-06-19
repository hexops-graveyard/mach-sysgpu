const std = @import("std");
const ChainedStruct = @import("gpu.zig").ChainedStruct;
const dawn = @import("dawn.zig");
const MapModeFlags = @import("gpu.zig").MapModeFlags;
const Impl = @import("interface.zig").Impl;

pub const Buffer = opaque {
    pub const MapCallback = *const fn (status: MapAsyncStatus, userdata: ?*anyopaque) callconv(.C) void;

    pub const BindingType = enum(u32) {
        undefined = 0x00000000,
        uniform = 0x00000001,
        storage = 0x00000002,
        read_only_storage = 0x00000003,
    };

    pub const MapState = enum(u32) {
        unmapped = 0x00000000,
        pending = 0x00000001,
        mapped = 0x00000002,
    };

    pub const MapAsyncStatus = enum(u32) {
        success = 0x00000000,
        err = 0x00000001,
        unknown = 0x00000002,
        device_lost = 0x00000003,
        destroyed_before_callback = 0x00000004,
        unmapped_before_callback = 0x00000005,
    };

    pub const UsageFlags = packed struct(u32) {
        map_read: bool = false,
        map_write: bool = false,
        copy_src: bool = false,
        copy_dst: bool = false,
        index: bool = false,
        vertex: bool = false,
        uniform: bool = false,
        storage: bool = false,
        indirect: bool = false,
        query_resolve: bool = false,

        _padding: u22 = 0,

        comptime {
            std.debug.assert(
                @sizeOf(@This()) == @sizeOf(u32) and
                    @bitSizeOf(@This()) == @bitSizeOf(u32),
            );
        }

        pub const none = UsageFlags{};

        pub fn equal(a: UsageFlags, b: UsageFlags) bool {
            return @truncate(u10, @bitCast(u32, a)) == @truncate(u10, @bitCast(u32, b));
        }
    };

    pub const BindingLayout = extern struct {
        next_in_chain: ?*const ChainedStruct = null,
        type: BindingType = .undefined,
        has_dynamic_offset: bool = false,
        min_binding_size: u64 = 0,
    };

    pub const Descriptor = extern struct {
        pub const NextInChain = extern union {
            generic: ?*const ChainedStruct,
            dawn_buffer_descriptor_error_info_from_wire_client: *const dawn.BufferDescriptorErrorInfoFromWireClient,
        };

        next_in_chain: NextInChain = .{ .generic = null },
        label: ?[*:0]const u8 = null,
        usage: UsageFlags,
        size: u64,
        mapped_at_creation: bool = false,
    };
};
