const std = @import("std");
const builtin = @import("builtin");
const vk = @import("vulkan");

pub const Dispatch = vk.BaseWrapper(.{
    .createInstance = true,
    .enumerateInstanceExtensionProperties = true,
    .enumerateInstanceLayerProperties = true,
    .getInstanceProcAddr = true,
});

const Base = @This();

var lib: ?std.DynLib = null;

allocator: std.mem.Allocator,
dispatch: Dispatch,

pub fn init(allocator: std.mem.Allocator) !Base {
    // ElfDynLib is unable to find vulkan, so forcing libc means we always use DlDynlib even on Linux
    if (!builtin.link_libc) @compileError("libc not linked");
    if (lib == null) {
        lib = try std.DynLib.openZ(switch (builtin.target.os.tag) {
            .windows => "vulkan-1.dll",
            .linux => "libvulkan.so.1",
            .macos => "libvulkan.1.dylib",
            else => @compileError("Unknown OS!"),
        });
    }

    const dispatch = try Dispatch.load(getBaseProcAddress);

    return .{
        .allocator = allocator,
        .dispatch = dispatch,
    };
}

pub fn deinit(base: Base) void {
    _ = base;
    lib.?.close();
}

pub fn createInstance(base: Base, info: vk.InstanceCreateInfo) !vk.Instance {
    return base.dispatch.createInstance(&info, null);
}

fn getBaseProcAddress(_: vk.Instance, name_ptr: [*:0]const u8) vk.PfnVoidFunction {
    var name = std.mem.span(name_ptr);
    return lib.?.lookup(vk.PfnVoidFunction, name) orelse null;
}
