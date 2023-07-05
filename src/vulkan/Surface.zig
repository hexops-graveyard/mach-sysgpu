const gpu = @import("mach-gpu");
const vk = @import("vulkan");
const Instance = @import("Instance.zig");
const RefCounter = @import("../helper.zig").RefCounter;
const findChained = @import("../helper.zig").findChained;

const Surface = @This();

ref_counter: RefCounter(Surface) = .{},
surface: vk.SurfaceKHR,

pub fn init(instance: *Instance, descriptor: *const gpu.Surface.Descriptor) !Surface {
    if (findChained(gpu.Surface.DescriptorFromXlibWindow, descriptor.next_in_chain.generic)) |xlib_descriptor| {
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
    }

    unreachable;
}
