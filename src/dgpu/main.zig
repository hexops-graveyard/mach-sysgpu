pub const wgpu = @import("gpu");

// mach-core and mach-core/examples/dusk/triangle depend on these symbols. We just re-export them
// for right now, but we could improve/change their APIs as we see fit.
pub const RenderPipeline = wgpu.RenderPipeline;
pub const PowerPreference = wgpu.PowerPreference;
pub const FeatureName = wgpu.FeatureName;
pub const Limits = wgpu.Limits;
pub const BackendType = wgpu.BackendType;
pub const Instance = wgpu.Instance;
pub const Surface = wgpu.Surface;
pub const Adapter = wgpu.Adapter;
pub const Device = wgpu.Device;
pub const SwapChain = wgpu.SwapChain;
pub const RequestAdapterStatus = wgpu.RequestAdapterStatus;
pub const RequestAdapterOptions = wgpu.RequestAdapterOptions;
pub const RequiredLimits = wgpu.RequiredLimits;
pub const ErrorType = wgpu.ErrorType;
pub const Queue = wgpu.Queue;
pub const BlendState = wgpu.BlendState;
pub const ColorTargetState = wgpu.ColorTargetState;
pub const ColorWriteMaskFlags = wgpu.ColorWriteMaskFlags;
pub const FragmentState = wgpu.FragmentState;
pub const VertexState = wgpu.VertexState;
pub const RenderPassColorAttachment = wgpu.RenderPassColorAttachment;
pub const RenderPassDescriptor = wgpu.RenderPassDescriptor;
pub const Color = wgpu.Color;
pub const CommandBuffer = wgpu.CommandBuffer;

// TODO: this should be cleaned up
pub const createInstance = @import("../main.zig").Impl.createInstance;

pub const Interface = @import("interface.zig").Interface;
pub const Export = @import("interface.zig").Export;
pub const StubInterface = @import("interface.zig").StubInterface;
