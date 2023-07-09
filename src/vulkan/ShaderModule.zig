const vk = @import("vulkan");
const Device = @import("Device.zig");
const Manager = @import("../helper.zig").Manager;

const ShaderModule = @This();

manager: Manager(ShaderModule) = .{},
shader_module: vk.ShaderModule,
device: *Device,

pub fn init(device: *Device, code: []const u8) !ShaderModule {
    const shader_module = try device.dispatch.createShaderModule(
        device.device,
        &vk.ShaderModuleCreateInfo{
            .code_size = code.len,
            .p_code = @ptrCast(@alignCast(code.ptr)),
        },
        null,
    );

    return .{
        .device = device,
        .shader_module = shader_module,
    };
}

pub fn deinit(shader_module: *ShaderModule) void {
    shader_module.device.dispatch.destroyShaderModule(
        shader_module.device.device,
        shader_module.shader_module,
        null,
    );
}
