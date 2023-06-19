const vk = @import("vk.zig");

const gpu = @import("../gpu.zig");

const BaseDispatch = vk.BaseWrapper(.{
    .createInstance = true,
    .enumerateInstanceExtensionProperties = true,
    .getInstanceProcAddr = true,
});

const InstanceDispatch = vk.InstanceWrapper(.{
    .destroyInstance = true,
});

const c = @cImport({
    @cInclude("vulkan/vulkan.h");
});

pub const Instance = struct {
    vulkan_instance: vk.Instance,
    vkb: BaseDispatch,
    vki: InstanceDispatch,

    pub fn create(descriptor: ?*const gpu.Instance.Descriptor) !Instance {
        if (descriptor != null) @panic("TODO");

        var vkb = try BaseDispatch.load(@ptrCast(vk.PfnGetInstanceProcAddr, &c.vkGetInstanceProcAddr));

        const app_info = vk.ApplicationInfo{
            .p_application_name = "Dusk",
            .application_version = vk.makeApiVersion(0, 0, 0, 0),
            .p_engine_name = "Dusk",
            .engine_version = vk.makeApiVersion(0, 0, 0, 0),
            .api_version = vk.API_VERSION_1_2,
        };

        const vulkan_instance = try vkb.createInstance(&vk.InstanceCreateInfo{
            .p_application_info = &app_info,
        }, null);

        const vki = try InstanceDispatch.load(vulkan_instance, vkb.dispatch.vkGetInstanceProcAddr);

        return Instance{
            .vulkan_instance = vulkan_instance,
            .vkb = vkb,
            .vki = vki,
        };
    }

    pub fn deinit(self: *Instance) void {
        self.vki.destroyInstance(self.vulkan_instance, null);
    }
};
