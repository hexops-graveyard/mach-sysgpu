const gpu = @import("gpu");
const vk = @import("vulkan");
const Instance = @import("Instance.zig");
const Manager = @import("../helper.zig").Manager;
const findChained = @import("../helper.zig").findChained;

const Surface = @This();

manager: Manager(Surface) = .{},
surface: vk.SurfaceKHR,

pub fn init(instance: *Instance, desc: *const gpu.Surface.Descriptor) !Surface {
    if (findChained(gpu.Surface.DescriptorFromXlibWindow, desc.next_in_chain.generic)) |xlib_descriptor| {
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
    } else if (findChained(gpu.Surface.DescriptorFromWindowsHWND, desc.next_in_chain.generic)) |win_descriptor| {
        return .{
            .surface = try instance.dispatch.createWin32SurfaceKHR(
                instance.instance,
                &vk.Win32SurfaceCreateInfoKHR{
                    .hinstance = @ptrCast(win_descriptor.hinstance),
                    .hwnd = @ptrCast(win_descriptor.hwnd),
                },
                null,
            ),
        };
    }

    unreachable;
}
