const std = @import("std");
const MapModeFlags = @import("main.zig").MapModeFlags;
const Impl = @import("interface.zig").Impl;

pub const Buffer = opaque {
    pub const MapCallback = *const fn (status: MapAsyncStatus, userdata: ?*anyopaque) void;

    pub const BindingType = enum {
        undefined,
        uniform,
        storage,
        read_only_storage,
    };

    pub const MapState = enum {
        unmapped,
        pending,
        mapped,
    };

    pub const MapAsyncStatus = enum {
        success,
        validation_error,
        unknown,
        device_lost,
        destroyed_before_callback,
        unmapped_before_callback,
        mapping_already_pending,
        offset_out_of_range,
        size_out_of_range,
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

        pub fn equal(a: UsageFlags, b: UsageFlags) bool {
            return @as(u10, @truncate(@as(u32, @bitCast(a)))) == @as(u10, @truncate(@as(u32, @bitCast(b))));
        }
    };

    pub const BindingLayout = struct {
        type: BindingType = .undefined,
        has_dynamic_offset: bool = false,
        min_binding_size: u64 = 0,
    };

    pub const Descriptor = struct {
        label: ?[:0]const u8 = null,
        usage: UsageFlags,
        size: u64,
        mapped_at_creation: bool = false,
    };

    pub inline fn destroy(buffer: *Buffer) void {
        Impl.bufferDestroy(buffer);
    }

    pub inline fn getMapState(buffer: *Buffer) MapState {
        return Impl.bufferGetMapState(buffer);
    }

    /// Default `offset_bytes`: 0
    /// Default `len`: `gpu.whole_map_size` / `std.math.maxint(usize)` (whole range)
    pub inline fn getConstMappedRange(
        buffer: *Buffer,
        comptime T: type,
        offset_bytes: usize,
        len: usize,
    ) ?[]const T {
        const size = @sizeOf(T) * len;
        const data = Impl.bufferGetConstMappedRange(
            buffer,
            offset_bytes,
            size + size % 4,
        );
        return if (data) |d| @as([*]const T, @ptrCast(@alignCast(d)))[0..len] else null;
    }

    /// Default `offset_bytes`: 0
    /// Default `len`: `gpu.whole_map_size` / `std.math.maxint(usize)` (whole range)
    pub inline fn getMappedRange(
        buffer: *Buffer,
        comptime T: type,
        offset_bytes: usize,
        len: usize,
    ) ?[]T {
        const size = @sizeOf(T) * len;
        const data = Impl.bufferGetMappedRange(
            buffer,
            offset_bytes,
            size + size % 4,
        );
        return if (data) |d| @as([*]T, @ptrCast(@alignCast(d)))[0..len] else null;
    }

    pub inline fn getSize(buffer: *Buffer) u64 {
        return Impl.bufferGetSize(buffer);
    }

    pub inline fn getUsage(buffer: *Buffer) Buffer.UsageFlags {
        return Impl.bufferGetUsage(buffer);
    }

    pub inline fn mapAsync(
        buffer: *Buffer,
        mode: MapModeFlags,
        offset: usize,
        size: usize,
        context: anytype,
        comptime callback: fn (ctx: @TypeOf(context), status: MapAsyncStatus) callconv(.Inline) void,
    ) void {
        Impl.bufferMapAsync(buffer, mode, offset, size, context, callback);
    }

    pub inline fn setLabel(buffer: *Buffer, label: [:0]const u8) void {
        Impl.bufferSetLabel(buffer, label);
    }

    pub inline fn unmap(buffer: *Buffer) void {
        Impl.bufferUnmap(buffer);
    }

    pub inline fn reference(buffer: *Buffer) void {
        Impl.bufferReference(buffer);
    }

    pub inline fn release(buffer: *Buffer) void {
        Impl.bufferRelease(buffer);
    }
};
