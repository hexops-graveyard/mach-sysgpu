const std = @import("std");

const gpu = @import("gpu");

pub const GPUInterface = gpu.dusk;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    _ = allocator;

    gpu.Impl.init();

    var instance = gpu.createInstance(null);
    defer gpu.Impl.instanceRelease(instance.?);
}
