const std = @import("std");
const c = @import("c.zig");

pub const UInteger = usize;

pub const StringEncoding = UInteger;
pub const UTF8StringEncoding: StringEncoding = 4;

pub const ObjectProtocol = opaque {
    pub usingnamespace Methods(ObjectProtocol);

    pub fn Methods(comptime T: type) type {
        return struct {
            pub fn retain(self_: *T) *T {
                const func: *const fn (*T, *c.objc_selector) callconv(.C) *T = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_retain);
            }
            pub fn release(self_: *T) void {
                const func: *const fn (*T, *c.objc_selector) callconv(.C) void = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_release);
            }
        };
    }
};

pub const ObjectInterface = opaque {
    pub fn class() *c.objc_class {
        return class_Object;
    }
    pub usingnamespace Methods(ObjectInterface);

    pub fn Methods(comptime T: type) type {
        return struct {
            pub usingnamespace ObjectProtocol.Methods(T);

            pub fn init(self_: *T) *T {
                const func: *const fn (*T, *c.objc_selector) callconv(.C) *T = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_init);
            }
            pub fn new() *T {
                const func: *const fn (*c.objc_class, *c.objc_selector) callconv(.C) *T = @ptrCast(&c.objc_msgSend);
                return func(T.class(), sel_new);
            }
            pub fn alloc() *T {
                const func: *const fn (*c.objc_class, *c.objc_selector) callconv(.C) *T = @ptrCast(&c.objc_msgSend);
                return func(T.class(), sel_alloc);
            }
        };
    }
};

pub const Error = opaque {
    pub fn class() *c.objc_class {
        return class_Error;
    }
    pub usingnamespace Methods(Error);

    pub fn Methods(comptime T: type) type {
        return struct {
            pub usingnamespace ObjectInterface.Methods(T);

            pub fn localizedDescription(self_: *T) *String {
                const func: *const fn (*T, *c.objc_selector) callconv(.C) *String = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_localizedDescription);
            }
        };
    }
};

pub const String = opaque {
    pub fn class() *c.objc_class {
        return class_String;
    }
    pub usingnamespace Methods(String);

    pub fn Methods(comptime T: type) type {
        return struct {
            pub usingnamespace ObjectInterface.Methods(T);

            pub fn stringWithUTF8String(cString_: [*:0]const u8) *T {
                const func: *const fn (*c.objc_class, *c.objc_selector, [*:0]const u8) callconv(.C) *T = @ptrCast(&c.objc_msgSend);
                return func(T.class(), sel_stringWithUTF8String_, cString_);
            }
            pub fn initWithBytesNoCopy_length_encoding_freeWhenDone(self_: *T, bytes_: *const anyopaque, len_: UInteger, encoding_: StringEncoding, freeBuffer_: bool) *T {
                const func: *const fn (*T, *c.objc_selector, *const anyopaque, UInteger, StringEncoding, bool) callconv(.C) *T = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_initWithBytesNoCopy_length_encoding_freeWhenDone_, bytes_, len_, encoding_, freeBuffer_);
            }
            pub fn utf8String(self_: *T) [*:0]const u8 {
                const func: *const fn (*T, *c.objc_selector) callconv(.C) [*:0]const u8 = @ptrCast(&c.objc_msgSend);
                return func(self_, sel_UTF8String);
            }
        };
    }
};

var class_Error: *c.objc_class = undefined;
var class_Object: *c.objc_class = undefined;
var class_String: *c.objc_class = undefined;

var sel_alloc: *c.objc_selector = undefined;
var sel_init: *c.objc_selector = undefined;
var sel_initWithBytesNoCopy_length_encoding_freeWhenDone_: *c.objc_selector = undefined;
var sel_localizedDescription: *c.objc_selector = undefined;
var sel_new: *c.objc_selector = undefined;
var sel_release: *c.objc_selector = undefined;
var sel_retain: *c.objc_selector = undefined;
var sel_stringWithUTF8String_: *c.objc_selector = undefined;
var sel_UTF8String: *c.objc_selector = undefined;

pub fn init() void {
    class_Error = c.objc_getClass("NSError").?;
    class_Object = c.objc_getClass("NSObject").?;
    class_String = c.objc_getClass("NSString").?;

    sel_alloc = c.sel_registerName("alloc").?;
    sel_init = c.sel_registerName("init").?;
    sel_initWithBytesNoCopy_length_encoding_freeWhenDone_ = c.sel_registerName("initWithBytesNoCopy:length:encoding:freeWhenDone:").?;
    sel_localizedDescription = c.sel_registerName("localizedDescription").?;
    sel_new = c.sel_registerName("new").?;
    sel_release = c.sel_registerName("release").?;
    sel_retain = c.sel_registerName("retain").?;
    sel_stringWithUTF8String_ = c.sel_registerName("stringWithUTF8String:").?;
    sel_UTF8String = c.sel_registerName("UTF8String").?;
}
