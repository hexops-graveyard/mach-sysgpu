const std = @import("std");
const builtin = @import("builtin");
const vk = @import("vulkan");

pub const BaseFunctions = vk.BaseWrapper(.{
    .createInstance = true,
    .enumerateInstanceExtensionProperties = true,
    .enumerateInstanceLayerProperties = true,
    .getInstanceProcAddr = true,
});

pub const InstanceFunctions = vk.InstanceWrapper(.{
    .createDevice = true,
    .createWaylandSurfaceKHR = builtin.target.os.tag == .linux,
    .createWin32SurfaceKHR = builtin.target.os.tag == .windows,
    .createXlibSurfaceKHR = builtin.target.os.tag == .linux,
    .destroyInstance = true,
    .destroySurfaceKHR = true,
    .enumerateDeviceExtensionProperties = true,
    .enumerateDeviceLayerProperties = true,
    .enumeratePhysicalDevices = true,
    .getDeviceProcAddr = true,
    .getPhysicalDeviceFeatures = true,
    .getPhysicalDeviceProperties = true,
    .getPhysicalDeviceQueueFamilyProperties = true,
    .getPhysicalDeviceSurfaceCapabilitiesKHR = true,
    .getPhysicalDeviceSurfaceFormatsKHR = true,
});

pub const DeviceFunctions = vk.DeviceWrapper(.{
    .acquireNextImageKHR = true,
    .allocateCommandBuffers = true,
    .beginCommandBuffer = true,
    .cmdBeginRenderPass = true,
    .cmdBindPipeline = true,
    .cmdDraw = true,
    .cmdEndRenderPass = true,
    .cmdPipelineBarrier = true,
    .cmdSetScissor = true,
    .cmdSetViewport = true,
    .createCommandPool = true,
    .createFence = true,
    .createFramebuffer = true,
    .createGraphicsPipelines = true,
    .createImageView = true,
    .createPipelineLayout = true,
    .createRenderPass = true,
    .createSemaphore = true,
    .createShaderModule = true,
    .createSwapchainKHR = true,
    .destroyCommandPool = true,
    .destroyDevice = true,
    .destroyFence = true,
    .destroyFramebuffer = true,
    .destroyImage = true,
    .destroyImageView = true,
    .destroyPipeline = true,
    .destroyPipelineLayout = true,
    .destroyRenderPass = true,
    .destroySemaphore = true,
    .destroyShaderModule = true,
    .destroySwapchainKHR = true,
    .deviceWaitIdle = true,
    .endCommandBuffer = true,
    .freeCommandBuffers = true,
    .getDeviceQueue = true,
    .getSwapchainImagesKHR = true,
    .queuePresentKHR = true,
    .queueSubmit = true,
    .queueWaitIdle = true,
    .resetCommandBuffer = true,
    .resetFences = true,
    .waitForFences = true,
});

pub const BaseLoader = *const fn (vk.Instance, [*:0]const u8) vk.PfnVoidFunction;

pub fn loadBase(baseLoader: BaseLoader) !BaseFunctions {
    return BaseFunctions.load(baseLoader) catch return error.ProcLoadingFailed;
}

pub fn loadInstance(instance: vk.Instance, instanceLoader: vk.PfnGetInstanceProcAddr) !InstanceFunctions {
    return InstanceFunctions.load(instance, instanceLoader) catch return error.ProcLoadingFailed;
}

pub fn loadDevice(device: vk.Device, deviceLoader: vk.PfnGetDeviceProcAddr) !DeviceFunctions {
    return DeviceFunctions.load(device, deviceLoader) catch return error.ProcLoadingFailed;
}
