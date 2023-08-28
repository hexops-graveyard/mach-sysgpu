pub const Instance = @import("vulkan/instance.zig").Instance;
pub const Adapter = @import("vulkan/instance.zig").Adapter;
pub const Surface = @import("vulkan/instance.zig").Surface;
pub const Device = @import("vulkan/device.zig").Device;
pub const ShaderModule = @import("vulkan/device.zig").ShaderModule;
pub const RenderPipeline = @import("vulkan/device.zig").RenderPipeline;
pub const CommandEncoder = @import("vulkan/device.zig").CommandEncoder;
pub const CommandBuffer = @import("vulkan/device.zig").CommandBuffer;
pub const RenderPassEncoder = @import("vulkan/device.zig").RenderPassEncoder;
pub const SwapChain = @import("vulkan/device.zig").SwapChain;
pub const Texture = @import("vulkan/device.zig").Texture;
pub const TextureView = @import("vulkan/device.zig").TextureView;
pub const Queue = @import("vulkan/device.zig").Queue;

const std = @import("std");

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
