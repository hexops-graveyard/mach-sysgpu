const PipelineStatisticName = @import("main.zig").PipelineStatisticName;
const QueryType = @import("main.zig").QueryType;
const Impl = @import("interface.zig").Impl;

pub const QuerySet = opaque {
    pub const Descriptor = struct {
        label: ?[:0]const u8 = null,
        type: QueryType,
        count: u32,
        pipeline_statistics: []const PipelineStatisticName = &.{},
    };

    pub inline fn destroy(query_set: *QuerySet) void {
        Impl.querySetDestroy(query_set);
    }

    pub inline fn getCount(query_set: *QuerySet) u32 {
        return Impl.querySetGetCount(query_set);
    }

    pub inline fn getType(query_set: *QuerySet) QueryType {
        return Impl.querySetGetType(query_set);
    }

    pub inline fn setLabel(query_set: *QuerySet, label: [:0]const u8) void {
        Impl.querySetSetLabel(query_set, label);
    }

    pub inline fn reference(query_set: *QuerySet) void {
        Impl.querySetReference(query_set);
    }

    pub inline fn release(query_set: *QuerySet) void {
        Impl.querySetRelease(query_set);
    }
};
