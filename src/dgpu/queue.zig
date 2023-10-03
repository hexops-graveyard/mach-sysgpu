const std = @import("std");
const CommandBuffer = @import("command_buffer.zig").CommandBuffer;
const Buffer = @import("buffer.zig").Buffer;
const Texture = @import("texture.zig").Texture;
const ImageCopyTexture = @import("main.zig").ImageCopyTexture;
const ImageCopyExternalTexture = @import("main.zig").ImageCopyExternalTexture;
const Extent3D = @import("main.zig").Extent3D;
const CopyTextureForBrowserOptions = @import("main.zig").CopyTextureForBrowserOptions;
const Impl = @import("interface.zig").Impl;

pub const Queue = opaque {
    pub const WorkDoneCallback = *const fn (
        status: WorkDoneStatus,
        userdata: ?*anyopaque,
    ) void;

    pub const WorkDoneStatus = enum {
        success,
        err,
        unknown,
        device_lost,
    };

    pub const Descriptor = struct {
        label: ?[:0]const u8 = null,
    };

    pub inline fn copyExternalTextureForBrowser(
        queue: *Queue,
        source: ImageCopyExternalTexture,
        destination: ImageCopyTexture,
        copy_size: Extent3D,
        options: CopyTextureForBrowserOptions,
    ) void {
        Impl.queueCopyExternalTextureForBrowser(queue, source, destination, copy_size, options);
    }

    pub inline fn copyTextureForBrowser(
        queue: *Queue,
        source: ImageCopyTexture,
        destination: ImageCopyTexture,
        copy_size: Extent3D,
        options: CopyTextureForBrowserOptions,
    ) void {
        Impl.queueCopyTextureForBrowser(queue, source, destination, copy_size, options);
    }

    pub inline fn onSubmittedWorkDone(
        queue: *Queue,
        signal_value: u64,
        context: anytype,
        comptime callback: fn (ctx: @TypeOf(context), status: WorkDoneStatus) callconv(.Inline) void,
    ) void {
        Impl.queueOnSubmittedWorkDone(queue, signal_value, context, callback);
    }

    pub inline fn setLabel(queue: *Queue, label: [:0]const u8) void {
        Impl.queueSetLabel(queue, label);
    }

    pub inline fn submit(queue: *Queue, commands: []const *const CommandBuffer) void {
        Impl.queueSubmit(queue, commands.len, commands.ptr);
    }

    pub inline fn writeBuffer(
        queue: *Queue,
        buffer: *Buffer,
        buffer_offset_bytes: u64,
        data_slice: anytype,
    ) void {
        Impl.queueWriteBuffer(
            queue,
            buffer,
            buffer_offset_bytes,
            data_slice,
        );
    }

    pub inline fn writeTexture(
        queue: *Queue,
        destination: ImageCopyTexture,
        data_layout: Texture.DataLayout,
        write_size: Extent3D,
        data_slice: anytype,
    ) void {
        Impl.queueWriteTexture(
            queue,
            destination,
            data_layout,
            write_size,
            data_slice,
        );
    }

    pub inline fn reference(queue: *Queue) void {
        Impl.queueReference(queue);
    }

    pub inline fn release(queue: *Queue) void {
        Impl.queueRelease(queue);
    }
};
