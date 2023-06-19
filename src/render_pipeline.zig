const ChainedStruct = @import("gpu.zig").ChainedStruct;
const DepthStencilState = @import("gpu.zig").DepthStencilState;
const MultisampleState = @import("gpu.zig").MultisampleState;
const VertexState = @import("gpu.zig").VertexState;
const PrimitiveState = @import("gpu.zig").PrimitiveState;
const FragmentState = @import("gpu.zig").FragmentState;
const PipelineLayout = @import("pipeline_layout.zig").PipelineLayout;
const BindGroupLayout = @import("bind_group_layout.zig").BindGroupLayout;
const Impl = @import("interface.zig").Impl;

pub const RenderPipeline = opaque {
    pub const Descriptor = extern struct {
        next_in_chain: ?*const ChainedStruct = null,
        label: ?[*:0]const u8 = null,
        layout: ?*PipelineLayout = null,
        vertex: VertexState,
        primitive: PrimitiveState = .{},
        depth_stencil: ?*const DepthStencilState = null,
        multisample: MultisampleState = .{},
        fragment: ?*const FragmentState = null,
    };
};
