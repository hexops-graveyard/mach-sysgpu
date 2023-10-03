const Surface = @import("surface.zig").Surface;
const Adapter = @import("adapter.zig").Adapter;
const Impl = @import("interface.zig").Impl;

pub const Instance = opaque {
    pub const Descriptor = struct {};

    pub inline fn createSurface(instance: *Instance, descriptor: Surface.Descriptor) *Surface {
        return Impl.instanceCreateSurface(instance, descriptor);
    }

    pub inline fn processEvents(instance: *Instance) void {
        Impl.instanceProcessEvents(instance);
    }

    pub inline fn createAdapter(instance: *Instance, descriptor: Adapter.Descriptor) *Adapter {
        return Impl.instanceCreateAdapter(instance, descriptor);
    }

    pub inline fn reference(instance: *Instance) void {
        Impl.instanceReference(instance);
    }

    pub inline fn release(instance: *Instance) void {
        Impl.instanceRelease(instance);
    }
};
