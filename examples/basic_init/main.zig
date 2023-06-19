const std = @import("std");

const gpu = @import("gpu");

pub const GPUInterface = gpu.dusk;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();

    gpu.Impl.init(allocator);

    var instance = gpu.Impl.createInstance(null).?;
    defer gpu.Impl.instanceRelease(instance);

    std.debug.print("got instance {*}\n", .{instance});
}
