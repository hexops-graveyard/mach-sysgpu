const std = @import("std");
const builtin = @import("builtin");
const vk = @import("vulkan");

const BaseDispatch = vk.BaseWrapper(.{
    .createInstance = true,
    .enumerateInstanceExtensionProperties = true,
    .enumerateInstanceLayerProperties = true,
    .getInstanceProcAddr = true,
});

const InstanceDispatch = vk.InstanceWrapper(.{
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

const DeviceDispatch = vk.DeviceWrapper(.{
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

pub var base: BaseDispatch = undefined;
pub var instance: InstanceDispatch = undefined;
pub var device: DeviceDispatch = undefined;

var lib: std.DynLib = undefined;
var loaded = false;

pub fn init() !void {
    // ElfDynLib is unable to find vulkan, so forcing libc means we always use DlDynlib even on Linux
    if (!builtin.link_libc) @compileError("libc not linked");

    std.debug.assert(!loaded);
    lib = try std.DynLib.openZ(switch (builtin.target.os.tag) {
        .windows => "vulkan-1.dll",
        .linux => "libvulkan.so.1",
        .macos => "libvulkan.1.dylib",
        else => @compileError("Unknown OS!"),
    });
    loaded = true;
}

pub fn close() void {
    lib.close();
    loaded = false;
}

pub fn loadBase() !void {
    std.debug.assert(loaded);
    base = try BaseDispatch.load(getBaseProcAddress);
}

pub fn loadInstance(vki: vk.Instance) !void {
    std.debug.assert(loaded);
    instance = try InstanceDispatch.load(vki, base.dispatch.vkGetInstanceProcAddr);
}

pub fn loadDevice(vkd: vk.Device) !void {
    std.debug.assert(loaded);
    device = try DeviceDispatch.load(vkd, instance.dispatch.vkGetDeviceProcAddr);
}

fn getBaseProcAddress(_: vk.Instance, name_ptr: [*:0]const u8) vk.PfnVoidFunction {
    var name = std.mem.span(name_ptr);
    return lib.lookup(vk.PfnVoidFunction, name) orelse null;
}
