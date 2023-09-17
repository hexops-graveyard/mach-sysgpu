pub const Instance = @import("metal/instance.zig").Instance;
pub const Adapter = @import("metal/instance.zig").Adapter;
pub const Surface = @import("metal/instance.zig").Surface;
pub const Device = @import("metal/device.zig").Device;
pub const ShaderModule = @import("metal/device.zig").ShaderModule;
pub const RenderPipeline = @import("metal/device.zig").RenderPipeline;
pub const CommandEncoder = @import("metal/device.zig").CommandEncoder;
pub const CommandBuffer = @import("metal/device.zig").CommandBuffer;
pub const RenderPassEncoder = @import("metal/device.zig").RenderPassEncoder;
pub const SwapChain = @import("metal/device.zig").SwapChain;
pub const Texture = @import("metal/device.zig").Texture;
pub const TextureView = @import("metal/device.zig").TextureView;
pub const Queue = @import("metal/device.zig").Queue;

const std = @import("std");

pub var allocator: std.mem.Allocator = undefined;

pub const InitOptions = struct {};

pub fn init(alloc: std.mem.Allocator, options: InitOptions) !void {
    _ = options;
    allocator = alloc;
}

test "reference declarations" {
    std.testing.refAllDecls(Instance);
    std.testing.refAllDecls(Adapter);
    std.testing.refAllDecls(Surface);
    std.testing.refAllDecls(Device);
    std.testing.refAllDecls(ShaderModule);
    std.testing.refAllDecls(RenderPipeline);
    std.testing.refAllDecls(CommandEncoder);
    std.testing.refAllDecls(CommandBuffer);
    std.testing.refAllDecls(RenderPassEncoder);
    std.testing.refAllDecls(SwapChain);
    std.testing.refAllDecls(Texture);
    std.testing.refAllDecls(TextureView);
    std.testing.refAllDecls(Queue);
}
