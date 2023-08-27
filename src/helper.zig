const std = @import("std");
const gpu = @import("gpu");

pub fn findChained(comptime T: type, next_in_chain: ?*const gpu.ChainedStruct) ?*const T {
    const search = @as(*align(1) const gpu.ChainedStruct, @ptrCast(std.meta.fieldInfo(T, .chain).default_value.?));
    var chain = next_in_chain;
    while (chain) |c| {
        if (c.s_type == search.s_type) {
            return @as(*const T, @ptrCast(c));
        }
        chain = c.next;
    }
    return null;
}

pub fn Manager(comptime T: type) type {
    return struct {
        count: u32 = 1,

        pub fn reference(manager: *@This()) void {
            _ = @atomicRmw(u32, &manager.count, .Add, 1, .Monotonic);
        }

        pub fn release(manager: *@This()) void {
            if (@atomicRmw(u32, &manager.count, .Sub, 1, .Release) == 1) {
                @fence(.Acquire);
                const parent = @fieldParentPtr(T, "manager", manager);
                parent.deinit();
            }
        }
    };
}
