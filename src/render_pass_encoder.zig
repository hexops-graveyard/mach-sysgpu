const Buffer = @import("buffer.zig").Buffer;
const RenderBundle = @import("render_bundle.zig").RenderBundle;
const BindGroup = @import("bind_group.zig").BindGroup;
const RenderPipeline = @import("render_pipeline.zig").RenderPipeline;
const QuerySet = @import("query_set.zig").QuerySet;
const Color = @import("gpu.zig").Color;
const IndexFormat = @import("gpu.zig").IndexFormat;
const Impl = @import("interface.zig").Impl;

pub const RenderPassEncoder = opaque {};
