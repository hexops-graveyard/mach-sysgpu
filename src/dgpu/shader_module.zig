const CompilationInfoCallback = @import("main.zig").CompilationInfoCallback;
const CompilationInfoRequestStatus = @import("main.zig").CompilationInfoRequestStatus;
const CompilationInfo = @import("main.zig").CompilationInfo;
const Impl = @import("interface.zig").Impl;

pub const ShaderModule = opaque {
    pub const Descriptor = struct {
        code: Code,
        label: ?[:0]const u8 = null,
    };

    pub const Code = union(enum) {
        wgsl: [:0]const u8,
        spirv: []const u32,
    };

    pub inline fn getCompilationInfo(
        shader_module: *ShaderModule,
        context: anytype,
        comptime callback: fn (
            ctx: @TypeOf(context),
            status: CompilationInfoRequestStatus,
            compilation_info: *const CompilationInfo,
        ) callconv(.Inline) void,
    ) void {
        Impl.shaderModuleGetCompilationInfo(shader_module, context, callback);
    }

    pub inline fn setLabel(shader_module: *ShaderModule, label: [:0]const u8) void {
        Impl.shaderModuleSetLabel(shader_module, label);
    }

    pub inline fn reference(shader_module: *ShaderModule) void {
        Impl.shaderModuleReference(shader_module);
    }

    pub inline fn release(shader_module: *ShaderModule) void {
        Impl.shaderModuleRelease(shader_module);
    }
};
