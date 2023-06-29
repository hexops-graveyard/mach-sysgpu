const std = @import("std");
const gpu = @import("mach-gpu");
const dusk = @import("mach-dusk");

pub const GPUInterface = dusk.Interface;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();

    gpu.Impl.init(allocator);

    var instance = gpu.Impl.createInstance(null).?;
    defer gpu.Impl.instanceRelease(instance);

    std.debug.print("got instance {*}\n", .{instance});

    var adapter: *gpu.Adapter = undefined;
    gpu.Impl.instanceRequestAdapter(
        instance,
        null,
        adapterCallback,
        @as(*anyopaque, @ptrCast(&adapter)),
    );
    defer gpu.Impl.adapterRelease(adapter);

    std.debug.print("got adapter {*}\n", .{adapter});
}

fn adapterCallback(
    status: gpu.RequestAdapterStatus,
    adapter: *gpu.Adapter,
    message: ?[*:0]const u8,
    userdata: ?*anyopaque,
) callconv(.C) void {
    _ = message;
    _ = status;

    var adapter_ptr: **gpu.Adapter = @ptrCast(@alignCast(userdata.?));

    //Set the adapter
    adapter_ptr.* = adapter;
}
