const ChainedStruct = @import("gpu.zig").ChainedStruct;
const CompilationInfoCallback = @import("gpu.zig").CompilationInfoCallback;
const CompilationInfoRequestStatus = @import("gpu.zig").CompilationInfoRequestStatus;
const CompilationInfo = @import("gpu.zig").CompilationInfo;
const Impl = @import("interface.zig").Impl;

pub const ShaderModule = opaque {
    pub const Descriptor = extern struct {
        pub const NextInChain = extern union {
            generic: ?*const ChainedStruct,
            spirv_descriptor: ?*const SPIRVDescriptor,
            wgsl_descriptor: ?*const WGSLDescriptor,
        };

        next_in_chain: NextInChain = .{ .generic = null },
        label: ?[*:0]const u8 = null,
    };

    pub const SPIRVDescriptor = extern struct {
        chain: ChainedStruct = .{ .next = null, .s_type = .shader_module_spirv_descriptor },
        code_size: u32,
        code: [*]const u32,
    };

    pub const WGSLDescriptor = extern struct {
        chain: ChainedStruct = .{ .next = null, .s_type = .shader_module_wgsl_descriptor },
        source: [*:0]const u8,
    };
};
