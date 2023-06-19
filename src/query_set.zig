const ChainedStruct = @import("gpu.zig").ChainedStruct;
const PipelineStatisticName = @import("gpu.zig").PipelineStatisticName;
const QueryType = @import("gpu.zig").QueryType;
const Impl = @import("interface.zig").Impl;

pub const QuerySet = opaque {
    pub const Descriptor = extern struct {
        next_in_chain: ?*const ChainedStruct = null,
        label: ?[*:0]const u8 = null,
        type: QueryType,
        count: u32,
        pipeline_statistics: ?[*]const PipelineStatisticName = null,
        pipeline_statistics_count: u32 = 0,

        /// Provides a slightly friendlier Zig API to initialize this structure.
        pub inline fn init(v: struct {
            next_in_chain: ?*const ChainedStruct = null,
            label: ?[*:0]const u8 = null,
            type: QueryType,
            count: u32,
            pipeline_statistics: ?[]const PipelineStatisticName = null,
        }) Descriptor {
            return .{
                .next_in_chain = v.next_in_chain,
                .label = v.label,
                .type = v.type,
                .count = v.count,
                .pipeline_statistics_count = if (v.pipeline_statistics) |e| @intCast(u32, e.len) else 0,
                .pipeline_statistics = if (v.pipeline_statistics) |e| e.ptr else null,
            };
        }
    };
};
