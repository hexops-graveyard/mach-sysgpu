const std = @import("std");
const gpu = @import("mach-gpu");

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

pub fn RefCounter(comptime T: type) type {
    return struct {
        ref_count: u32 = 0,

        pub fn reference(self: *@This()) void {
            _ = @atomicRmw(u32, &self.ref_count, .Add, 1, .AcqRel);
        }

        pub fn release(self: *@This()) void {
            if (@atomicRmw(u32, &self.ref_count, .Sub, 1, .AcqRel) == 1) {
                const parent = @fieldParentPtr(T, "ref_counter", self);
                parent.deinit();
            }
        }
    };
}
