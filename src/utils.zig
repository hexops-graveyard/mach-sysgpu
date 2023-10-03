const std = @import("std");
const dgpu = @import("dgpu/main.zig");

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
