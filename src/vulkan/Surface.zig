const gpu = @import("mach-gpu");
const vk = @import("vulkan");
const Instance = @import("Instance.zig");

const Surface = @This();

surface: vk.SurfaceKHR,

pub fn init(instance: Instance, descriptor: *const gpu.Surface.Descriptor) !Surface {
    const window_type = @as(*const gpu.ChainedStruct, @ptrCast(&descriptor.next_in_chain)).next.?.s_type;
    switch (window_type) {
        .surface_descriptor_from_xlib_window => {
            const xlib_descriptor: *const gpu.Surface.DescriptorFromXlibWindow = @ptrCast(&descriptor.next_in_chain);
            return .{
                .surface = try instance.dispatch.createXlibSurfaceKHR(
                    instance.instance,
                    &vk.XlibSurfaceCreateInfoKHR{
                        .dpy = @ptrCast(xlib_descriptor.display),
                        .window = xlib_descriptor.window,
                    },
                    null,
                ),
            };
        },
        else => unreachable,
    }
}
