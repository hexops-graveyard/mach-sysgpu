const std = @import("std");
const CommandBuffer = @import("command_buffer.zig").CommandBuffer;
const Buffer = @import("buffer.zig").Buffer;
const Texture = @import("texture.zig").Texture;
const ImageCopyTexture = @import("gpu.zig").ImageCopyTexture;
const ImageCopyExternalTexture = @import("gpu.zig").ImageCopyExternalTexture;
const ChainedStruct = @import("gpu.zig").ChainedStruct;
const Extent3D = @import("gpu.zig").Extent3D;
const CopyTextureForBrowserOptions = @import("gpu.zig").CopyTextureForBrowserOptions;
const Impl = @import("interface.zig").Impl;

pub const Queue = opaque {
    pub const WorkDoneCallback = *const fn (
        status: WorkDoneStatus,
        userdata: ?*anyopaque,
    ) callconv(.C) void;

    pub const WorkDoneStatus = enum(u32) {
        success = 0x00000000,
        err = 0x00000001,
        unknown = 0x00000002,
        device_lost = 0x00000003,
    };

    pub const Descriptor = extern struct {
        next_in_chain: ?*const ChainedStruct = null,
        label: ?[*:0]const u8 = null,
    };
};
