const Impl = @import("interface.zig").Impl;

pub const Surface = opaque {
    pub const Descriptor = struct {
        handle: Handle,
        label: ?[:0]const u8 = null,
    };

    pub const Handle = union(enum) {
        android_native_window: *anyopaque,
        canvas_html_selector: [:0]const u8,
        metal_layer: *anyopaque,
        wayland_surface: WaylandSurface,
        windows_core_window: *anyopaque,
        windows_hwnd: WindowsHWND,
        windows_swap_chain_panel: *anyopaque,
        xlib_window: XlibWindow,
    };

    pub const WaylandSurface = struct {
        display: *anyopaque,
        surface: *anyopaque,
    };

    pub const WindowsHWND = struct {
        hinstance: *anyopaque,
        hwnd: *anyopaque,
    };

    pub const XlibWindow = struct {
        display: *anyopaque,
        window: u32,
    };

    pub inline fn reference(surface: *Surface) void {
        Impl.surfaceReference(surface);
    }

    pub inline fn release(surface: *Surface) void {
        Impl.surfaceRelease(surface);
    }
};
