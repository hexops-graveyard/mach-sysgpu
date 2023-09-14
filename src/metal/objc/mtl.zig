const std = @import("std");
const c = @import("c.zig");
const ns = @import("ns.zig");

pub const LoadAction = ns.UInteger;
pub const LoadActionDontCare: LoadAction = 0;
pub const LoadActionLoad: LoadAction = 1;
pub const LoadActionClear: LoadAction = 2;

pub const PixelFormat = ns.UInteger;
pub const PixelFormatBGRA8Unorm_sRGB: PixelFormat = 81;

pub const PrimitiveType = ns.UInteger;
pub const PrimitiveTypePoint: PrimitiveType = 0;
pub const PrimitiveTypeLine: PrimitiveType = 1;
pub const PrimitiveTypeLineStrip: PrimitiveType = 2;
pub const PrimitiveTypeTriangle: PrimitiveType = 3;
pub const PrimitiveTypeTriangleStrip: PrimitiveType = 4;

pub const StoreAction = ns.UInteger;
pub const StoreActionDontCare: StoreAction = 0;
pub const StoreActionStore: StoreAction = 1;
pub const StoreActionMultisampleResolve: StoreAction = 2;
pub const StoreActionStoreAndMultisampleResolve: StoreAction = 3;
pub const StoreActionUnknown: StoreAction = 4;
pub const StoreActionCustomSampleDepthStore: StoreAction = 5;

extern fn MTLCreateSystemDefaultDevice() ?*Device;
pub const createSystemDefaultDevice = MTLCreateSystemDefaultDevice;

pub const ClearColor = extern struct {
    red: f64,
    green: f64,
    blue: f64,
    alpha: f64,

    pub fn init(red: f64, green: f64, blue: f64, alpha: f64) ClearColor {
        return ClearColor{ .red = red, .green = green, .blue = blue, .alpha = alpha };
    }
};

pub const CommandBuffer = opaque {
    pub usingnamespace Methods(CommandBuffer);

    pub fn Methods(comptime T: type) type {
        return struct {
            pub usingnamespace ns.ObjectProtocol.Methods(T);

            pub fn commit(self_: *T) void {
                const func: *const fn (*T, *c.objc_selector) callconv(.C) void = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_commit);
            }
            pub fn presentDrawable(self_: *T, drawable_: *Drawable) void {
                const func: *const fn (*T, *c.objc_selector, *Drawable) callconv(.C) void = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_presentDrawable_, drawable_);
            }
            pub fn renderCommandEncoderWithDescriptor(self_: *T, renderPassDescriptor_: *RenderPassDescriptor) ?*RenderCommandEncoder {
                const func: *const fn (*T, *c.objc_selector, *RenderPassDescriptor) callconv(.C) ?*RenderCommandEncoder = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_renderCommandEncoderWithDescriptor_, renderPassDescriptor_);
            }
        };
    }
};

pub const CommandEncoder = opaque {
    pub usingnamespace Methods(CommandEncoder);

    pub fn Methods(comptime T: type) type {
        return struct {
            pub usingnamespace ns.ObjectProtocol.Methods(T);

            pub fn endEncoding(self_: *T) void {
                const func: *const fn (*T, *c.objc_selector) callconv(.C) void = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_endEncoding);
            }
        };
    }
};

pub const CommandQueue = opaque {
    pub usingnamespace Methods(CommandQueue);

    pub fn Methods(comptime T: type) type {
        return struct {
            pub usingnamespace ns.ObjectProtocol.Methods(T);

            pub fn commandBuffer(self_: *T) ?*CommandBuffer {
                const func: *const fn (*T, *c.objc_selector) callconv(.C) ?*CommandBuffer = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_commandBuffer);
            }
        };
    }
};

pub const CompileOptions = opaque {
    pub fn class() *c.objc_class {
        return class_CompileOptions;
    }
    pub usingnamespace Methods(CompileOptions);

    pub fn Methods(comptime T: type) type {
        return struct {
            pub usingnamespace ns.ObjectInterface.Methods(T);
        };
    }
};

pub const Device = opaque {
    pub usingnamespace Methods(Device);

    pub fn Methods(comptime T: type) type {
        return struct {
            pub usingnamespace ns.ObjectProtocol.Methods(T);

            pub fn newCommandQueue(self_: *T) ?*CommandQueue {
                const func: *const fn (*T, *c.objc_selector) callconv(.C) ?*CommandQueue = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_newCommandQueue);
            }
            pub fn newLibraryWithSource_options_error(self_: *T, source_: *ns.String, options_: ?*CompileOptions, error_: ?*?*ns.Error) ?*Library {
                const func: *const fn (*T, *c.objc_selector, *ns.String, ?*CompileOptions, ?*?*ns.Error) callconv(.C) ?*Library = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_newLibraryWithSource_options_error_, source_, options_, error_);
            }
            pub fn newRenderPipelineStateWithDescriptor_error(self_: *T, descriptor_: *RenderPipelineDescriptor, error_: ?*?*ns.Error) ?*RenderPipelineState {
                const func: *const fn (*T, *c.objc_selector, *RenderPipelineDescriptor, ?*?*ns.Error) callconv(.C) ?*RenderPipelineState = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_newRenderPipelineStateWithDescriptor_error_, descriptor_, error_);
            }
            pub fn name(self_: *T) *ns.String {
                const func: *const fn (*T, *c.objc_selector) callconv(.C) *ns.String = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_name);
            }
            pub fn isLowPower(self_: *T) bool {
                const func: *const fn (*T, *c.objc_selector) callconv(.C) bool = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_isLowPower);
            }
        };
    }
};

pub const Drawable = opaque {
    pub usingnamespace Methods(Drawable);

    pub fn Methods(comptime T: type) type {
        return struct {
            pub usingnamespace ns.ObjectProtocol.Methods(T);
        };
    }
};

pub const Function = opaque {
    pub usingnamespace Methods(Function);

    pub fn Methods(comptime T: type) type {
        return struct {
            pub usingnamespace ns.ObjectProtocol.Methods(T);
        };
    }
};

pub const Library = opaque {
    pub usingnamespace Methods(Library);

    pub fn Methods(comptime T: type) type {
        return struct {
            pub usingnamespace ns.ObjectProtocol.Methods(T);

            pub fn newFunctionWithName(self_: *T, functionName_: *ns.String) ?*Function {
                const func: *const fn (*T, *c.objc_selector, *ns.String) callconv(.C) ?*Function = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_newFunctionWithName_, functionName_);
            }
        };
    }
};

pub const RenderCommandEncoder = opaque {
    pub usingnamespace Methods(RenderCommandEncoder);

    pub fn Methods(comptime T: type) type {
        return struct {
            pub usingnamespace CommandEncoder.Methods(T);

            pub fn setRenderPipelineState(self_: *T, pipelineState_: *RenderPipelineState) void {
                const func: *const fn (*T, *c.objc_selector, *RenderPipelineState) callconv(.C) void = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_setRenderPipelineState_, pipelineState_);
            }
            pub fn drawPrimitives_vertexStart_vertexCount_instanceCount_baseInstance(self_: *T, primitiveType_: PrimitiveType, vertexStart_: ns.UInteger, vertexCount_: ns.UInteger, instanceCount_: ns.UInteger, baseInstance_: ns.UInteger) void {
                const func: *const fn (*T, *c.objc_selector, PrimitiveType, ns.UInteger, ns.UInteger, ns.UInteger, ns.UInteger) callconv(.C) void = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_drawPrimitives_vertexStart_vertexCount_instanceCount_baseInstance_, primitiveType_, vertexStart_, vertexCount_, instanceCount_, baseInstance_);
            }
        };
    }
};

pub const RenderPassAttachmentDescriptor = opaque {
    pub fn class() *c.objc_class {
        return class_RenderPassAttachmentDescriptor;
    }
    pub usingnamespace Methods(RenderPassAttachmentDescriptor);

    pub fn Methods(comptime T: type) type {
        return struct {
            pub usingnamespace ns.ObjectInterface.Methods(T);

            pub fn setTexture(self_: *T, texture_: ?*Texture) void {
                const func: *const fn (*T, *c.objc_selector, ?*Texture) callconv(.C) void = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_setTexture_, texture_);
            }
            pub fn setLoadAction(self_: *T, loadAction_: LoadAction) void {
                const func: *const fn (*T, *c.objc_selector, LoadAction) callconv(.C) void = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_setLoadAction_, loadAction_);
            }
            pub fn setStoreAction(self_: *T, storeAction_: StoreAction) void {
                const func: *const fn (*T, *c.objc_selector, StoreAction) callconv(.C) void = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_setStoreAction_, storeAction_);
            }
        };
    }
};

pub const RenderPassColorAttachmentDescriptorArray = opaque {
    pub fn class() *c.objc_class {
        return class_RenderPassColorAttachmentDescriptorArray;
    }
    pub usingnamespace Methods(RenderPassColorAttachmentDescriptorArray);

    pub fn Methods(comptime T: type) type {
        return struct {
            pub usingnamespace ns.ObjectInterface.Methods(T);

            pub fn objectAtIndexedSubscript(self_: *T, attachmentIndex_: ns.UInteger) *RenderPassColorAttachmentDescriptor {
                const func: *const fn (*T, *c.objc_selector, ns.UInteger) callconv(.C) *RenderPassColorAttachmentDescriptor = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_objectAtIndexedSubscript_, attachmentIndex_);
            }
        };
    }
};

pub const RenderPassDescriptor = opaque {
    pub fn class() *c.objc_class {
        return class_RenderPassDescriptor;
    }
    pub usingnamespace Methods(RenderPassDescriptor);

    pub fn Methods(comptime T: type) type {
        return struct {
            pub usingnamespace ns.ObjectInterface.Methods(T);

            pub fn colorAttachments(self_: *T) *RenderPassColorAttachmentDescriptorArray {
                const func: *const fn (*T, *c.objc_selector) callconv(.C) *RenderPassColorAttachmentDescriptorArray = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_colorAttachments);
            }
        };
    }
};

pub const RenderPipelineColorAttachmentDescriptor = opaque {
    pub fn class() *c.objc_class {
        return class_RenderPipelineColorAttachmentDescriptor;
    }
    pub usingnamespace Methods(RenderPipelineColorAttachmentDescriptor);

    pub fn Methods(comptime T: type) type {
        return struct {
            pub usingnamespace ns.ObjectInterface.Methods(T);

            pub fn setPixelFormat(self_: *T, pixelFormat_: PixelFormat) void {
                const func: *const fn (*T, *c.objc_selector, PixelFormat) callconv(.C) void = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_setPixelFormat_, pixelFormat_);
            }
        };
    }
};

pub const RenderPassColorAttachmentDescriptor = opaque {
    pub fn class() *c.objc_class {
        return class_RenderPassColorAttachmentDescriptor;
    }
    pub usingnamespace Methods(RenderPassColorAttachmentDescriptor);

    pub fn Methods(comptime T: type) type {
        return struct {
            pub usingnamespace RenderPassAttachmentDescriptor.Methods(T);

            pub fn setClearColor(self_: *T, clearColor_: ClearColor) void {
                const func: *const fn (*T, *c.objc_selector, ClearColor) callconv(.C) void = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_setClearColor_, clearColor_);
            }
        };
    }
};

pub const RenderPipelineColorAttachmentDescriptorArray = opaque {
    pub fn class() *c.objc_class {
        return class_RenderPipelineColorAttachmentDescriptorArray;
    }
    pub usingnamespace Methods(RenderPipelineColorAttachmentDescriptorArray);

    pub fn Methods(comptime T: type) type {
        return struct {
            pub usingnamespace ns.ObjectInterface.Methods(T);

            pub fn objectAtIndexedSubscript(self_: *T, attachmentIndex_: ns.UInteger) *RenderPipelineColorAttachmentDescriptor {
                const func: *const fn (*T, *c.objc_selector, ns.UInteger) callconv(.C) *RenderPipelineColorAttachmentDescriptor = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_objectAtIndexedSubscript_, attachmentIndex_);
            }
        };
    }
};

pub const RenderPipelineDescriptor = opaque {
    pub fn class() *c.objc_class {
        return class_RenderPipelineDescriptor;
    }
    pub usingnamespace Methods(RenderPipelineDescriptor);

    pub fn Methods(comptime T: type) type {
        return struct {
            pub usingnamespace ns.ObjectInterface.Methods(T);

            pub fn setVertexFunction(self_: *T, vertexFunction_: ?*Function) void {
                const func: *const fn (*T, *c.objc_selector, ?*Function) callconv(.C) void = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_setVertexFunction_, vertexFunction_);
            }
            pub fn setFragmentFunction(self_: *T, fragmentFunction_: ?*Function) void {
                const func: *const fn (*T, *c.objc_selector, ?*Function) callconv(.C) void = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_setFragmentFunction_, fragmentFunction_);
            }
            pub fn colorAttachments(self_: *T) *RenderPipelineColorAttachmentDescriptorArray {
                const func: *const fn (*T, *c.objc_selector) callconv(.C) *RenderPipelineColorAttachmentDescriptorArray = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_colorAttachments);
            }
        };
    }
};

pub const RenderPipelineState = opaque {
    pub usingnamespace Methods(RenderPipelineState);

    pub fn Methods(comptime T: type) type {
        return struct {
            pub usingnamespace ns.ObjectProtocol.Methods(T);
        };
    }
};

pub const Resource = opaque {
    pub usingnamespace Methods(Resource);

    pub fn Methods(comptime T: type) type {
        return struct {
            pub usingnamespace ns.ObjectProtocol.Methods(T);
        };
    }
};

pub const Texture = opaque {
    pub usingnamespace Methods(Texture);

    pub fn Methods(comptime T: type) type {
        return struct {
            pub usingnamespace Resource.Methods(T);
        };
    }
};

var class_CompileOptions: *c.objc_class = undefined;
var class_RenderPassAttachmentDescriptor: *c.objc_class = undefined;
var class_RenderPassColorAttachmentDescriptor: *c.objc_class = undefined;
var class_RenderPassColorAttachmentDescriptorArray: *c.objc_class = undefined;
var class_RenderPassDescriptor: *c.objc_class = undefined;
var class_RenderPipelineColorAttachmentDescriptor: *c.objc_class = undefined;
var class_RenderPipelineColorAttachmentDescriptorArray: *c.objc_class = undefined;
var class_RenderPipelineDescriptor: *c.objc_class = undefined;

var sel_colorAttachments: *c.objc_selector = undefined;
var sel_commandBuffer: *c.objc_selector = undefined;
var sel_commit: *c.objc_selector = undefined;
var sel_drawPrimitives_vertexStart_vertexCount_instanceCount_baseInstance_: *c.objc_selector = undefined;
var sel_endEncoding: *c.objc_selector = undefined;
var sel_isLowPower: *c.objc_selector = undefined;
var sel_name: *c.objc_selector = undefined;
var sel_newCommandQueue: *c.objc_selector = undefined;
var sel_newFunctionWithName_: *c.objc_selector = undefined;
var sel_newLibraryWithSource_options_error_: *c.objc_selector = undefined;
var sel_newRenderPipelineStateWithDescriptor_error_: *c.objc_selector = undefined;
var sel_objectAtIndexedSubscript_: *c.objc_selector = undefined;
var sel_presentDrawable_: *c.objc_selector = undefined;
var sel_renderCommandEncoderWithDescriptor_: *c.objc_selector = undefined;
var sel_setClearColor_: *c.objc_selector = undefined;
var sel_setFragmentFunction_: *c.objc_selector = undefined;
var sel_setLoadAction_: *c.objc_selector = undefined;
var sel_setPixelFormat_: *c.objc_selector = undefined;
var sel_setRenderPipelineState_: *c.objc_selector = undefined;
var sel_setStoreAction_: *c.objc_selector = undefined;
var sel_setTexture_: *c.objc_selector = undefined;
var sel_setVertexFunction_: *c.objc_selector = undefined;

pub fn init() void {
    class_CompileOptions = c.objc_getClass("MTLCompileOptions").?;
    class_RenderPassAttachmentDescriptor = c.objc_getClass("MTLRenderPassAttachmentDescriptor").?;
    class_RenderPassColorAttachmentDescriptor = c.objc_getClass("MTLRenderPassColorAttachmentDescriptor").?;
    class_RenderPassColorAttachmentDescriptorArray = c.objc_getClass("MTLRenderPassColorAttachmentDescriptorArray").?;
    class_RenderPassDescriptor = c.objc_getClass("MTLRenderPassDescriptor").?;
    class_RenderPipelineColorAttachmentDescriptor = c.objc_getClass("MTLRenderPipelineColorAttachmentDescriptor").?;
    class_RenderPipelineColorAttachmentDescriptorArray = c.objc_getClass("MTLRenderPipelineColorAttachmentDescriptorArray").?;
    class_RenderPipelineDescriptor = c.objc_getClass("MTLRenderPipelineDescriptor").?;

    sel_colorAttachments = c.sel_registerName("colorAttachments").?;
    sel_commandBuffer = c.sel_registerName("commandBuffer").?;
    sel_commit = c.sel_registerName("commit").?;
    sel_drawPrimitives_vertexStart_vertexCount_instanceCount_baseInstance_ = c.sel_registerName("drawPrimitives:vertexStart:vertexCount:instanceCount:baseInstance:").?;
    sel_endEncoding = c.sel_registerName("endEncoding").?;
    sel_isLowPower = c.sel_registerName("isLowPower").?;
    sel_name = c.sel_registerName("name").?;
    sel_newCommandQueue = c.sel_registerName("newCommandQueue").?;
    sel_newFunctionWithName_ = c.sel_registerName("newFunctionWithName:").?;
    sel_newLibraryWithSource_options_error_ = c.sel_registerName("newLibraryWithSource:options:error:").?;
    sel_newRenderPipelineStateWithDescriptor_error_ = c.sel_registerName("newRenderPipelineStateWithDescriptor:error:").?;
    sel_objectAtIndexedSubscript_ = c.sel_registerName("objectAtIndexedSubscript:").?;
    sel_presentDrawable_ = c.sel_registerName("presentDrawable:").?;
    sel_renderCommandEncoderWithDescriptor_ = c.sel_registerName("renderCommandEncoderWithDescriptor:").?;
    sel_setClearColor_ = c.sel_registerName("setClearColor:").?;
    sel_setFragmentFunction_ = c.sel_registerName("setFragmentFunction:").?;
    sel_setLoadAction_ = c.sel_registerName("setLoadAction:").?;
    sel_setPixelFormat_ = c.sel_registerName("setPixelFormat:").?;
    sel_setRenderPipelineState_ = c.sel_registerName("setRenderPipelineState:").?;
    sel_setStoreAction_ = c.sel_registerName("setStoreAction:").?;
    sel_setTexture_ = c.sel_registerName("setTexture:").?;
    sel_setVertexFunction_ = c.sel_registerName("setVertexFunction:").?;
}
