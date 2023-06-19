const ChainedStruct = @import("gpu.zig").ChainedStruct;
const ProgrammableStageDescriptor = @import("gpu.zig").ProgrammableStageDescriptor;
const PipelineLayout = @import("pipeline_layout.zig").PipelineLayout;
const BindGroupLayout = @import("bind_group_layout.zig").BindGroupLayout;
const Impl = @import("interface.zig").Impl;

pub const ComputePipeline = opaque {
    pub const Descriptor = extern struct {
        next_in_chain: ?*const ChainedStruct = null,
        label: ?[*:0]const u8 = null,
        layout: ?*PipelineLayout = null,
        compute: ProgrammableStageDescriptor,
    };
};
