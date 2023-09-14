const c = @import("c.zig");
const mtl = @import("mtl.zig");
const ns = @import("ns.zig");

pub const Layer = opaque {
    pub fn class() *c.objc_class {
        return class_Layer;
    }
    pub usingnamespace Methods(Layer);

    pub fn Methods(comptime T: type) type {
        return struct {
            pub usingnamespace ns.ObjectInterface.Methods(T);
        };
    }
};

pub const MetalDrawable = opaque {
    pub usingnamespace Methods(MetalDrawable);

    pub fn Methods(comptime T: type) type {
        return struct {
            pub usingnamespace mtl.Drawable.Methods(T);

            pub fn texture(self_: *T) *mtl.Texture {
                const func: *const fn (*T, *c.objc_selector) callconv(.C) *mtl.Texture = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_texture);
            }
        };
    }
};

pub const MetalLayer = opaque {
    pub fn class() *c.objc_class {
        return class_MetalLayer;
    }
    pub usingnamespace Methods(MetalLayer);

    pub fn Methods(comptime T: type) type {
        return struct {
            pub usingnamespace Layer.Methods(T);

            pub fn nextDrawable(self_: *T) *MetalDrawable {
                const func: *const fn (*T, *c.objc_selector) callconv(.C) *MetalDrawable = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_nextDrawable);
            }
            pub fn setDevice(self_: *T, device_: *mtl.Device) void {
                const func: *const fn (*T, *c.objc_selector, *mtl.Device) callconv(.C) void = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_setDevice_, device_);
            }
        };
    }
};

var class_Layer: *c.objc_class = undefined;
var class_MetalLayer: *c.objc_class = undefined;

var sel_nextDrawable: *c.objc_selector = undefined;
var sel_setDevice_: *c.objc_selector = undefined;
var sel_texture: *c.objc_selector = undefined;

pub fn init() void {
    class_Layer = c.objc_getClass("CALayer").?;
    class_MetalLayer = c.objc_getClass("CAMetalLayer").?;

    sel_nextDrawable = c.sel_registerName("nextDrawable").?;
    sel_setDevice_ = c.sel_registerName("setDevice:").?;
    sel_texture = c.sel_registerName("texture").?;
}
