const std = @import("std");
const gpu = @import("gpu");
const utils = @import("utils.zig");
const shader = @import("shader.zig");
const c = @import("d3d12/c.zig");
const conv = @import("d3d12/conv.zig");

const log = std.log.scoped(.d3d12);
const back_buffer_count = 3;
const max_color_attachments = 8;
const rtv_heap_size = 64; // TODO

var allocator: std.mem.Allocator = undefined;
var debug_enabled: bool = true;
var gpu_validation_enabled: bool = true;

// workaround issues with @alignCast panicking as these aren't real pointers
extern fn hwndCast(*anyopaque) c.HWND;

pub const InitOptions = struct {
    debug_enabled: bool = true,
    gpu_validation_enabled: bool = true,
};

pub fn init(alloc: std.mem.Allocator, options: InitOptions) !void {
    allocator = alloc;
    debug_enabled = options.debug_enabled;
    gpu_validation_enabled = options.gpu_validation_enabled;
}

pub const Instance = struct {
    manager: utils.Manager(Instance) = .{},
    dxgi_factory: *c.IDXGIFactory4,

    pub fn init(desc: *const gpu.Instance.Descriptor) !*Instance {
        // TODO
        _ = desc;

        var hr: c.HRESULT = undefined;

        // DXGI Factory
        var dxgi_factory: *c.IDXGIFactory4 = undefined;
        hr = c.CreateDXGIFactory2(
            if (debug_enabled) c.DXGI_CREATE_FACTORY_DEBUG else 0,
            &c.IID_IDXGIFactory4,
            @ptrCast(&dxgi_factory),
        );
        if (hr != c.S_OK) {
            return error.CreateFailed;
        }
        errdefer _ = dxgi_factory.lpVtbl.*.Release.?(dxgi_factory);

        // D3D12 Debug Layer
        if (debug_enabled) {
            var debug_controller: *c.ID3D12Debug1 = undefined;
            hr = c.D3D12GetDebugInterface(&c.IID_ID3D12Debug1, @ptrCast(&debug_controller));
            if (hr == c.S_OK) {
                defer _ = debug_controller.lpVtbl.*.Release.?(debug_controller);
                debug_controller.lpVtbl.*.EnableDebugLayer.?(debug_controller);
                if (gpu_validation_enabled) {
                    debug_controller.lpVtbl.*.SetEnableGPUBasedValidation.?(
                        debug_controller,
                        c.TRUE,
                    );
                }
            }
        }

        // Result
        var instance = try allocator.create(Instance);
        instance.* = .{
            .dxgi_factory = dxgi_factory,
        };
        return instance;
    }

    pub fn deinit(instance: *Instance) void {
        const dxgi_factory = instance.dxgi_factory;
        _ = dxgi_factory.lpVtbl.*.Release.?(dxgi_factory);
        allocator.destroy(instance);
    }

    pub fn createSurface(instance: *Instance, desc: *const gpu.Surface.Descriptor) !*Surface {
        return Surface.init(instance, desc);
    }
};

pub const Adapter = struct {
    manager: utils.Manager(Adapter) = .{},
    instance: *Instance,
    dxgi_adapter: *c.IDXGIAdapter1,
    d3d_device: *c.ID3D12Device,
    dxgi_desc: c.DXGI_ADAPTER_DESC1,

    pub fn init(instance: *Instance, options: *const gpu.RequestAdapterOptions) !*Adapter {
        // TODO - choose appropriate device from options
        _ = options;

        const dxgi_factory = instance.dxgi_factory;
        var hr: c.HRESULT = undefined;

        var i: u32 = 0;
        var dxgi_adapter: *c.IDXGIAdapter1 = undefined;
        while (dxgi_factory.lpVtbl.*.EnumAdapters1.?(
            dxgi_factory,
            i,
            @ptrCast(&dxgi_adapter),
        ) != c.DXGI_ERROR_NOT_FOUND) : (i += 1) {
            defer _ = dxgi_adapter.lpVtbl.*.Release.?(dxgi_adapter);

            var dxgi_desc: c.DXGI_ADAPTER_DESC1 = undefined;
            hr = dxgi_adapter.lpVtbl.*.GetDesc1.?(
                dxgi_adapter,
                &dxgi_desc,
            );
            std.debug.assert(hr == c.S_OK);

            if ((dxgi_desc.Flags & c.DXGI_ADAPTER_FLAG_SOFTWARE) != 0)
                continue;

            var d3d_device: *c.ID3D12Device = undefined;
            hr = c.D3D12CreateDevice(
                @ptrCast(dxgi_adapter),
                c.D3D_FEATURE_LEVEL_11_0,
                &c.IID_ID3D12Device,
                @ptrCast(&d3d_device),
            );
            if (hr == c.S_OK) {
                _ = dxgi_adapter.lpVtbl.*.AddRef.?(dxgi_adapter);

                var adapter = try allocator.create(Adapter);
                adapter.* = .{
                    .instance = instance,
                    .dxgi_adapter = dxgi_adapter,
                    .d3d_device = d3d_device,
                    .dxgi_desc = dxgi_desc,
                };
                return adapter;
            }
        }

        return error.NoAdapterFound;
    }

    pub fn deinit(adapter: *Adapter) void {
        const dxgi_adapter = adapter.dxgi_adapter;
        const d3d_device = adapter.d3d_device;
        _ = dxgi_adapter.lpVtbl.*.Release.?(dxgi_adapter);
        _ = d3d_device.lpVtbl.*.Release.?(d3d_device);
        allocator.destroy(adapter);
    }

    pub fn createDevice(adapter: *Adapter, desc: ?*const gpu.Device.Descriptor) !*Device {
        return Device.init(adapter, desc);
    }

    pub fn getProperties(adapter: *Adapter) gpu.Adapter.Properties {
        const dxgi_desc = adapter.dxgi_desc;

        return .{
            .vendor_id = dxgi_desc.VendorId,
            .vendor_name = "", // TODO
            .architecture = "", // TODO
            .device_id = dxgi_desc.DeviceId,
            .name = "", // TODO - wide to ascii - dxgi_desc.Description
            .driver_description = "", // TODO
            .adapter_type = .unknown,
            .backend_type = .d3d12,
            .compatibility_mode = .false,
        };
    }
};

pub const Surface = struct {
    manager: utils.Manager(Surface) = .{},
    hwnd: c.HWND,

    pub fn init(instance: *Instance, desc: *const gpu.Surface.Descriptor) !*Surface {
        _ = instance;

        if (utils.findChained(gpu.Surface.DescriptorFromWindowsHWND, desc.next_in_chain.generic)) |win_desc| {
            var surface = try allocator.create(Surface);
            surface.* = .{ .hwnd = hwndCast(win_desc.hwnd) };
            return surface;
        } else {
            return error.InvalidDescriptor;
        }
    }

    pub fn deinit(surface: *Surface) void {
        allocator.destroy(surface);
    }
};

pub const Device = struct {
    manager: utils.Manager(Device) = .{},
    adapter: *Adapter,
    d3d_device: *c.ID3D12Device,
    rtv_descriptor_heap: *c.ID3D12DescriptorHeap,
    root_signature: *c.ID3D12RootSignature,
    command_manager: *CommandManager,
    queue: *Queue,
    lost_cb: ?gpu.Device.LostCallback = null,
    lost_cb_userdata: ?*anyopaque = null,
    log_cb: ?gpu.LoggingCallback = null,
    log_cb_userdata: ?*anyopaque = null,
    err_cb: ?gpu.ErrorCallback = null,
    err_cb_userdata: ?*anyopaque = null,

    pub fn init(adapter: *Adapter, desc: ?*const gpu.Device.Descriptor) !*Device {
        // TODO
        _ = desc;

        const d3d_device = adapter.d3d_device;
        var hr: c.HRESULT = undefined;

        // RTV Descriptor Heap
        var rtv_descriptor_heap: *c.ID3D12DescriptorHeap = undefined;
        hr = d3d_device.lpVtbl.*.CreateDescriptorHeap.?(
            d3d_device,
            &c.D3D12_DESCRIPTOR_HEAP_DESC{
                .Type = c.D3D12_DESCRIPTOR_HEAP_TYPE_RTV,
                .NumDescriptors = rtv_heap_size,
                .Flags = c.D3D12_DESCRIPTOR_HEAP_FLAG_NONE,
                .NodeMask = 0,
            },
            &c.IID_ID3D12DescriptorHeap,
            @ptrCast(&rtv_descriptor_heap),
        );
        if (hr != c.S_OK) {
            return error.CreateFailed;
        }
        errdefer _ = rtv_descriptor_heap.lpVtbl.*.Release.?(rtv_descriptor_heap);

        // Root Signature
        var root_signature_blob: *c.ID3DBlob = undefined;
        hr = c.D3D12SerializeRootSignature(
            &c.D3D12_ROOT_SIGNATURE_DESC{
                .NumParameters = 0,
                .pParameters = null,
                .NumStaticSamplers = 0,
                .pStaticSamplers = null,
                .Flags = 0,
            },
            c.D3D_ROOT_SIGNATURE_VERSION_1,
            @ptrCast(&root_signature_blob),
            null,
        );
        if (hr != c.S_OK) {
            return error.SerializeFailed;
        }
        defer _ = root_signature_blob.lpVtbl.*.Release.?(root_signature_blob);

        var root_signature: *c.ID3D12RootSignature = undefined;
        hr = d3d_device.lpVtbl.*.CreateRootSignature.?(
            d3d_device,
            0,
            root_signature_blob.lpVtbl.*.GetBufferPointer.?(root_signature_blob),
            root_signature_blob.lpVtbl.*.GetBufferSize.?(root_signature_blob),
            &c.IID_ID3D12RootSignature,
            @ptrCast(&root_signature),
        );
        errdefer _ = root_signature.lpVtbl.*.Release.?(root_signature);

        // Command Manager
        var command_manager = try CommandManager.init(d3d_device);

        // Queue
        var queue = try Queue.init(d3d_device, command_manager);

        // Result
        var device = try allocator.create(Device);
        device.* = .{
            .adapter = adapter,
            .d3d_device = d3d_device,
            .rtv_descriptor_heap = rtv_descriptor_heap,
            .root_signature = root_signature,
            .command_manager = command_manager,
            .queue = queue,
        };
        return device;
    }

    pub fn deinit(device: *Device) void {
        const rtv_descriptor_heap = device.rtv_descriptor_heap;
        const root_signature = device.root_signature;

        if (device.lost_cb) |lost_cb| {
            lost_cb(.destroyed, "Device was destroyed.", device.lost_cb_userdata);
        }

        device.queue.waitUntil(device.queue.fence_value);

        _ = rtv_descriptor_heap.lpVtbl.*.Release.?(rtv_descriptor_heap);
        _ = root_signature.lpVtbl.*.Release.?(root_signature);
        device.command_manager.deinit();
        device.queue.manager.release();
        allocator.destroy(device);
    }

    pub fn createBindGroup(device: *Device, desc: *const gpu.BindGroup.Descriptor) !*BindGroup {
        _ = desc;
        _ = device;
        unreachable;
    }

    pub fn createBindGroupLayout(device: *Device, desc: *const gpu.BindGroupLayout.Descriptor) !*BindGroupLayout {
        _ = device;
        _ = desc;
        unreachable;
    }

    pub fn createBuffer(device: *Device, desc: *const gpu.Buffer.Descriptor) !*Buffer {
        _ = desc;
        _ = device;
        unreachable;
    }

    pub fn createCommandEncoder(device: *Device, desc: *const gpu.CommandEncoder.Descriptor) !*CommandEncoder {
        return CommandEncoder.init(device, desc);
    }

    pub fn createComputePipeline(device: *Device, desc: *const gpu.ComputePipeline.Descriptor) !*ComputePipeline {
        _ = desc;
        _ = device;
        unreachable;
    }

    pub fn createPipelineLayout(device: *Device, desc: *const gpu.PipelineLayout.Descriptor) !*PipelineLayout {
        _ = device;
        _ = desc;
        unreachable;
    }

    pub fn createRenderPipeline(device: *Device, desc: *const gpu.RenderPipeline.Descriptor) !*RenderPipeline {
        return RenderPipeline.init(device, desc);
    }

    pub fn createShaderModuleAir(device: *Device, air: *const shader.Air) !*ShaderModule {
        return ShaderModule.initAir(device, air);
    }

    pub fn createShaderModuleSpirv(device: *Device, code: []const u8) !*ShaderModule {
        _ = code;
        _ = device;
        return error.unsupported;
    }

    pub fn createSwapChain(device: *Device, surface: *Surface, desc: *const gpu.SwapChain.Descriptor) !*SwapChain {
        return SwapChain.init(device, surface, desc);
    }

    pub fn createTexture(device: *Device, desc: *const gpu.Texture.Descriptor) !*Texture {
        _ = desc;
        _ = device;
        unreachable;
    }

    pub fn getQueue(device: *Device) !*Queue {
        return device.queue;
    }

    pub fn tick(device: *Device) !void {
        _ = device;
        unreachable;
    }
};

const CommandManager = struct {
    const InflightAllocator = struct {
        command_allocator: *c.ID3D12CommandAllocator,
        queue: *Queue,
        fence_value: u64,
    };

    d3d_device: *c.ID3D12Device,
    inflight_allocators: std.ArrayList(InflightAllocator),
    free_allocators: std.ArrayList(*c.ID3D12CommandAllocator),
    free_command_lists: std.ArrayList(*c.ID3D12GraphicsCommandList),

    pub fn init(d3d_device: *c.ID3D12Device) !*CommandManager {
        var manager = try allocator.create(CommandManager);
        manager.* = .{
            .d3d_device = d3d_device,
            .inflight_allocators = std.ArrayList(InflightAllocator).init(allocator),
            .free_allocators = std.ArrayList(*c.ID3D12CommandAllocator).init(allocator),
            .free_command_lists = std.ArrayList(*c.ID3D12GraphicsCommandList).init(allocator),
        };
        return manager;
    }

    pub fn deinit(manager: *CommandManager) void {
        for (manager.inflight_allocators.items) |inflight_allocator| {
            const command_allocator = inflight_allocator.command_allocator;
            _ = command_allocator.lpVtbl.*.Release.?(command_allocator);
        }
        for (manager.free_allocators.items) |command_allocator| {
            _ = command_allocator.lpVtbl.*.Release.?(command_allocator);
        }
        for (manager.free_command_lists.items) |command_list| {
            _ = command_list.lpVtbl.*.Release.?(command_list);
        }

        manager.inflight_allocators.deinit();
        manager.free_allocators.deinit();
        manager.free_command_lists.deinit();
        allocator.destroy(manager);
    }

    pub fn getCommandAllocator(manager: *CommandManager) !*c.ID3D12CommandAllocator {
        const d3d_device = manager.d3d_device;
        var hr: c.HRESULT = undefined;

        // Recycle finished allocators
        if (manager.free_allocators.items.len == 0) {
            var i: u32 = 0;
            while (i < manager.inflight_allocators.items.len) {
                const inflight_allocator = manager.inflight_allocators.items[i];
                const fence = inflight_allocator.queue.fence;
                const completed_value = fence.lpVtbl.*.GetCompletedValue.?(fence);

                if (inflight_allocator.fence_value <= completed_value) {
                    try manager.free_allocators.append(inflight_allocator.command_allocator);
                    _ = manager.inflight_allocators.swapRemove(i);
                } else {
                    i += 1;
                }
            }
        }

        // Frame pacing is handled through SwapChain.getCurrentTextureView or queueOnSubmittedWorkDone.

        // Create new command allocator
        if (manager.free_allocators.items.len == 0) {
            var command_allocator: *c.ID3D12CommandAllocator = undefined;
            hr = d3d_device.lpVtbl.*.CreateCommandAllocator.?(
                d3d_device,
                c.D3D12_COMMAND_LIST_TYPE_DIRECT,
                &c.IID_ID3D12CommandAllocator,
                @ptrCast(&command_allocator),
            );
            if (hr != c.S_OK) {
                return error.CreateFailed;
            }

            try manager.free_allocators.append(command_allocator);
        }

        // Reset
        const command_allocator = manager.free_allocators.pop();
        hr = command_allocator.lpVtbl.*.Reset.?(command_allocator);
        if (hr != c.S_OK) {
            return error.ResetFailed;
        }
        return command_allocator;
    }

    pub fn enqueueCommandAllocator(
        manager: *CommandManager,
        command_allocator: *c.ID3D12CommandAllocator,
        queue: *Queue,
        fence_value: u64,
    ) !void {
        try manager.inflight_allocators.append(.{
            .command_allocator = command_allocator,
            .queue = queue,
            .fence_value = fence_value,
        });
    }

    pub fn createCommandList(manager: *CommandManager, command_allocator: *c.ID3D12CommandAllocator) !*c.ID3D12GraphicsCommandList {
        const d3d_device = manager.d3d_device;
        var hr: c.HRESULT = undefined;

        if (manager.free_command_lists.items.len == 0) {
            var command_list: *c.ID3D12GraphicsCommandList = undefined;
            hr = d3d_device.lpVtbl.*.CreateCommandList.?(
                d3d_device,
                0,
                c.D3D12_COMMAND_LIST_TYPE_DIRECT,
                command_allocator,
                null,
                &c.IID_ID3D12GraphicsCommandList,
                @ptrCast(&command_list),
            );
            if (hr != c.S_OK) {
                return error.CreateFailed;
            }

            return command_list;
        }

        const command_list = manager.free_command_lists.pop();
        hr = command_list.lpVtbl.*.Reset.?(
            command_list,
            command_allocator,
            null,
        );
        if (hr != c.S_OK) {
            return error.ResetFailed;
        }

        return command_list;
    }

    pub fn destroyCommandList(manager: *CommandManager, command_list: *c.ID3D12GraphicsCommandList) !void {
        try manager.free_command_lists.append(command_list);
    }
};

pub const SwapChain = struct {
    manager: utils.Manager(SwapChain) = .{},
    device: *Device,
    surface: *Surface,
    queue: *Queue,
    dxgi_swap_chain: *c.IDXGISwapChain3,
    width: u32,
    height: u32,
    buffers: [back_buffer_count]*c.ID3D12Resource,
    cpu_handles: [back_buffer_count]c.D3D12_CPU_DESCRIPTOR_HANDLE,
    fence_values: [back_buffer_count]u64,
    buffer_index: u32 = 0,
    texture_view: TextureView = undefined,

    pub fn init(device: *Device, surface: *Surface, desc: *const gpu.SwapChain.Descriptor) !*SwapChain {
        const dxgi_factory = device.adapter.instance.dxgi_factory;
        const d3d_device = device.d3d_device;
        const rtv_descriptor_heap = device.rtv_descriptor_heap;
        var hr: c.HRESULT = undefined;

        // Swap Chain
        var swap_chain_desc = c.DXGI_SWAP_CHAIN_DESC{
            .BufferDesc = .{
                .Width = desc.width,
                .Height = desc.height,
                .RefreshRate = .{ .Numerator = 0, .Denominator = 0 },
                .Format = c.DXGI_FORMAT_R8G8B8A8_UNORM, // TODO
                .ScanlineOrdering = c.DXGI_MODE_SCANLINE_ORDER_UNSPECIFIED,
                .Scaling = c.DXGI_MODE_SCALING_UNSPECIFIED,
            },
            .SampleDesc = .{ .Count = 1, .Quality = 0 },
            .BufferUsage = c.DXGI_USAGE_RENDER_TARGET_OUTPUT,
            .BufferCount = back_buffer_count,
            .OutputWindow = surface.hwnd,
            .Windowed = c.TRUE,
            .SwapEffect = c.DXGI_SWAP_EFFECT_FLIP_DISCARD,
            .Flags = 0,
        };

        var dxgi_swap_chain: *c.IDXGISwapChain3 = undefined;
        hr = dxgi_factory.lpVtbl.*.CreateSwapChain.?(
            dxgi_factory,
            @ptrCast(device.queue.d3d_command_queue),
            &swap_chain_desc,
            @ptrCast(&dxgi_swap_chain),
        );
        if (hr != c.S_OK) {
            return error.CreateFailed;
        }
        errdefer _ = dxgi_swap_chain.lpVtbl.*.Release.?(dxgi_swap_chain);

        // Views
        const descriptor_size = d3d_device.lpVtbl.*.GetDescriptorHandleIncrementSize.?(
            d3d_device,
            c.D3D12_DESCRIPTOR_HEAP_TYPE_RTV,
        );

        var cpu_handle: c.D3D12_CPU_DESCRIPTOR_HANDLE = undefined;
        _ = rtv_descriptor_heap.lpVtbl.*.GetCPUDescriptorHandleForHeapStart.?(
            rtv_descriptor_heap,
            &cpu_handle,
        );

        var buffers = std.BoundedArray(*c.ID3D12Resource, back_buffer_count){};
        var cpu_handles = std.BoundedArray(c.D3D12_CPU_DESCRIPTOR_HANDLE, back_buffer_count){};
        var fence_values = std.BoundedArray(u64, back_buffer_count){};
        errdefer {
            for (buffers.buffer) |buffer| {
                _ = buffer.lpVtbl.*.Release.?(buffer);
            }
        }

        for (0..back_buffer_count) |i| {
            var buffer: *c.ID3D12Resource = undefined;
            hr = dxgi_swap_chain.lpVtbl.*.GetBuffer.?(
                dxgi_swap_chain,
                @intCast(i),
                &c.IID_ID3D12Resource,
                @ptrCast(&buffer),
            );
            if (hr != c.S_OK) {
                return error.SwapChainGetBufferFailed;
            }

            buffers.appendAssumeCapacity(buffer);
            cpu_handles.appendAssumeCapacity(cpu_handle);
            fence_values.appendAssumeCapacity(0);

            d3d_device.lpVtbl.*.CreateRenderTargetView.?(
                d3d_device,
                buffer,
                null,
                cpu_handle,
            );

            cpu_handle.ptr += descriptor_size;
        }

        // Result
        var swapchain = try allocator.create(SwapChain);
        swapchain.* = .{
            .device = device,
            .surface = surface,
            .queue = device.queue,
            .dxgi_swap_chain = dxgi_swap_chain,
            .width = desc.width,
            .height = desc.height,
            .buffers = buffers.buffer,
            .cpu_handles = cpu_handles.buffer,
            .fence_values = fence_values.buffer,
        };
        return swapchain;
    }

    pub fn deinit(swapchain: *SwapChain) void {
        const dxgi_swap_chain = swapchain.dxgi_swap_chain;
        const queue = swapchain.queue;

        queue.waitUntil(queue.fence_value);

        for (swapchain.buffers) |buffer| {
            _ = buffer.lpVtbl.*.Release.?(buffer);
        }
        _ = dxgi_swap_chain.lpVtbl.*.Release.?(dxgi_swap_chain);
        allocator.destroy(swapchain);
    }

    pub fn getCurrentTextureView(swapchain: *SwapChain) !*TextureView {
        const dxgi_swap_chain = swapchain.dxgi_swap_chain;

        // Get current index
        const index = dxgi_swap_chain.lpVtbl.*.GetCurrentBackBufferIndex.?(dxgi_swap_chain);

        // Wait until previous work on this buffer completes
        swapchain.queue.waitUntil(swapchain.fence_values[swapchain.buffer_index]);

        // Update texture view
        swapchain.buffer_index = index;
        swapchain.texture_view.resource = swapchain.buffers[index];
        swapchain.texture_view.cpu_handle = swapchain.cpu_handles[index];
        swapchain.texture_view.width = swapchain.width;
        swapchain.texture_view.height = swapchain.height;
        return &swapchain.texture_view;
    }

    pub fn present(swapchain: *SwapChain) !void {
        const dxgi_swap_chain = swapchain.dxgi_swap_chain;
        const queue = swapchain.queue;
        var hr: c.HRESULT = undefined;

        hr = dxgi_swap_chain.lpVtbl.*.Present.?(
            dxgi_swap_chain,
            0,
            0,
        );
        if (hr != c.S_OK) {
            return error.PresentFailed;
        }

        queue.fence_value += 1;
        try queue.signal();
        swapchain.fence_values[swapchain.buffer_index] = queue.fence_value;
    }
};

pub const Buffer = struct {
    manager: utils.Manager(Buffer) = .{},

    pub fn init(device: *Device, desc: *const gpu.Buffer.Descriptor) !*Buffer {
        _ = desc;
        _ = device;
        unreachable;
    }

    pub fn deinit(buffer: *Buffer) void {
        _ = buffer;
    }

    pub fn getConstMappedRange(buffer: *Buffer, offset: usize, size: usize) !*anyopaque {
        _ = size;
        _ = offset;
        _ = buffer;
        unreachable;
    }

    pub fn mapAsync(buffer: *Buffer, mode: gpu.MapModeFlags, offset: usize, size: usize, callback: gpu.Buffer.MapCallback, userdata: ?*anyopaque) !void {
        _ = userdata;
        _ = callback;
        _ = size;
        _ = offset;
        _ = mode;
        _ = buffer;
        unreachable;
    }

    pub fn unmap(buffer: *Buffer) void {
        _ = buffer;
        unreachable;
    }
};

pub const Texture = struct {
    manager: utils.Manager(Texture) = .{},
    resource: *c.ID3D12Resource,

    pub fn deinit(view: *Texture) void {
        _ = view;
    }

    pub fn createView(texture: *Texture, desc: ?*const gpu.TextureView.Descriptor) !*TextureView {
        _ = desc;
        _ = texture;
        unreachable;
    }
};

pub const TextureView = struct {
    manager: utils.Manager(TextureView) = .{},
    resource: *c.ID3D12Resource,
    cpu_handle: c.D3D12_CPU_DESCRIPTOR_HANDLE,
    width: u32,
    height: u32,

    pub fn deinit(view: *TextureView) void {
        _ = view;
    }
};

pub const BindGroupLayout = struct {
    manager: utils.Manager(BindGroupLayout) = .{},

    pub fn deinit(layout: BindGroupLayout) void {
        _ = layout;
    }
};

pub const BindGroup = struct {
    manager: utils.Manager(BindGroup) = .{},

    pub fn init(device: *Device, desc: *const gpu.BindGroup.Descriptor) !*BindGroup {
        _ = desc;
        _ = device;
        unreachable;
    }

    pub fn deinit(group: *BindGroup) void {
        _ = group;
    }
};

pub const PipelineLayout = struct {
    manager: utils.Manager(PipelineLayout) = .{},

    pub fn init(device: *Device, desc: *const gpu.PipelineLayout.Descriptor) !*PipelineLayout {
        _ = desc;
        _ = device;
        unreachable;
    }

    pub fn deinit(group: *PipelineLayout) void {
        _ = group;
    }
};

pub const ShaderModule = struct {
    manager: utils.Manager(ShaderModule) = .{},
    code: []const u8,

    pub fn initAir(device: *Device, air: *const shader.Air) !*ShaderModule {
        _ = device;

        const code = shader.CodeGen.generate(allocator, air, .hlsl, .{ .emit_source_file = "" }) catch unreachable;
        defer allocator.free(code);

        var module = try allocator.create(ShaderModule);
        module.* = .{
            .code = try allocator.dupe(u8, code),
        };
        return module;
    }

    pub fn deinit(shader_module: *ShaderModule) void {
        allocator.free(shader_module.code);
        allocator.destroy(shader_module);
    }
};

pub const ComputePipeline = struct {
    manager: utils.Manager(ComputePipeline) = .{},

    pub fn init(device: *Device, desc: *const gpu.ComputePipeline.Descriptor) !*ComputePipeline {
        _ = desc;
        _ = device;
        unreachable;
    }

    pub fn deinit(pipeline: *ComputePipeline) void {
        _ = pipeline;
    }

    pub fn getBindGroupLayout(pipeline: *ComputePipeline, group_index: u32) *BindGroupLayout {
        _ = group_index;
        _ = pipeline;
        unreachable;
    }
};

pub const RenderPipeline = struct {
    manager: utils.Manager(RenderPipeline) = .{},
    d3d_pipeline: *c.ID3D12PipelineState,

    fn compileShader(module: *ShaderModule, entrypoint: [*:0]const u8, target: [*:0]const u8) !*c.ID3DBlob {
        var hr: c.HRESULT = undefined;

        var shader_blob: *c.ID3DBlob = undefined;
        var opt_errors: ?*c.ID3DBlob = null;
        hr = c.D3DCompile(
            module.code.ptr,
            module.code.len,
            null,
            null,
            null,
            entrypoint,
            target,
            c.D3DCOMPILE_DEBUG | c.D3DCOMPILE_SKIP_OPTIMIZATION,
            0,
            @ptrCast(&shader_blob),
            @ptrCast(&opt_errors),
        );
        if (opt_errors) |errors| {
            const message: [*:0]const u8 = @ptrCast(errors.lpVtbl.*.GetBufferPointer.?(errors).?);
            std.debug.print("{s}\n", .{message});
            _ = errors.lpVtbl.*.Release.?(errors);
        }
        if (hr != c.S_OK) {
            return error.CompileFailed;
        }

        return shader_blob;
    }

    pub fn init(device: *Device, desc: *const gpu.RenderPipeline.Descriptor) !*RenderPipeline {
        const d3d_device = device.d3d_device;
        var hr: c.HRESULT = undefined;

        // Shaders
        const vertex_module: *ShaderModule = @ptrCast(@alignCast(desc.vertex.module));
        const vertex_shader = try compileShader(vertex_module, desc.vertex.entry_point, "vs_5_0");
        defer _ = vertex_shader.lpVtbl.*.Release.?(vertex_shader);

        var opt_pixel_shader: ?*c.ID3DBlob = null;
        if (desc.fragment) |frag| {
            const frag_module: *ShaderModule = @ptrCast(@alignCast(frag.module));
            opt_pixel_shader = try compileShader(frag_module, frag.entry_point, "ps_5_0");
        }
        defer if (opt_pixel_shader) |pixel_shader| {
            _ = pixel_shader.lpVtbl.*.Release.?(pixel_shader);
        };

        // PSO
        const shader_default = .{ .pShaderBytecode = null, .BytecodeLength = 0 };
        const render_target_blend_default: c.D3D12_RENDER_TARGET_BLEND_DESC = .{
            .BlendEnable = c.FALSE,
            .LogicOpEnable = c.FALSE,
            .SrcBlend = c.D3D12_BLEND_ONE,
            .DestBlend = c.D3D12_BLEND_ZERO,
            .BlendOp = c.D3D12_BLEND_OP_ADD,
            .SrcBlendAlpha = c.D3D12_BLEND_ONE,
            .DestBlendAlpha = c.D3D12_BLEND_ZERO,
            .BlendOpAlpha = c.D3D12_BLEND_OP_ADD,
            .LogicOp = c.D3D12_LOGIC_OP_NOOP,
            .RenderTargetWriteMask = 0xf,
        };

        var d3d_pipeline: *c.ID3D12PipelineState = undefined;
        hr = d3d_device.lpVtbl.*.CreateGraphicsPipelineState.?(
            d3d_device,
            &c.D3D12_GRAPHICS_PIPELINE_STATE_DESC{
                .pRootSignature = device.root_signature,
                .VS = .{
                    .pShaderBytecode = vertex_shader.lpVtbl.*.GetBufferPointer.?(vertex_shader),
                    .BytecodeLength = vertex_shader.lpVtbl.*.GetBufferSize.?(vertex_shader),
                },
                .PS = if (opt_pixel_shader) |pixel_shader| .{
                    .pShaderBytecode = pixel_shader.lpVtbl.*.GetBufferPointer.?(pixel_shader),
                    .BytecodeLength = pixel_shader.lpVtbl.*.GetBufferSize.?(pixel_shader),
                } else shader_default,
                .DS = shader_default,
                .HS = shader_default,
                .GS = shader_default,
                .StreamOutput = .{
                    .pSODeclaration = null,
                    .NumEntries = 0,
                    .pBufferStrides = null,
                    .NumStrides = 0,
                    .RasterizedStream = 0,
                },
                .BlendState = .{
                    .AlphaToCoverageEnable = c.FALSE,
                    .IndependentBlendEnable = c.FALSE,
                    .RenderTarget = [8]c.D3D12_RENDER_TARGET_BLEND_DESC{
                        render_target_blend_default,
                        render_target_blend_default,
                        render_target_blend_default,
                        render_target_blend_default,
                        render_target_blend_default,
                        render_target_blend_default,
                        render_target_blend_default,
                        render_target_blend_default,
                    },
                },
                .SampleMask = 0xffffffff,
                .RasterizerState = .{
                    .FillMode = c.D3D12_FILL_MODE_SOLID,
                    .CullMode = c.D3D12_CULL_MODE_NONE,
                    .FrontCounterClockwise = c.FALSE,
                    .DepthBias = 0,
                    .DepthBiasClamp = 0.0,
                    .SlopeScaledDepthBias = 0.0,
                    .DepthClipEnable = c.TRUE,
                    .MultisampleEnable = c.FALSE,
                    .AntialiasedLineEnable = c.FALSE,
                    .ForcedSampleCount = 0,
                    .ConservativeRaster = c.D3D12_CONSERVATIVE_RASTERIZATION_MODE_OFF,
                },
                .DepthStencilState = .{
                    .DepthEnable = c.FALSE,
                    .DepthWriteMask = c.D3D12_DEPTH_WRITE_MASK_ZERO,
                    .DepthFunc = c.D3D12_COMPARISON_FUNC_LESS,
                    .StencilEnable = c.FALSE,
                    .StencilReadMask = 0xff,
                    .StencilWriteMask = 0xff,
                    .FrontFace = .{
                        .StencilFailOp = c.D3D12_STENCIL_OP_KEEP,
                        .StencilDepthFailOp = c.D3D12_STENCIL_OP_KEEP,
                        .StencilPassOp = c.D3D12_STENCIL_OP_KEEP,
                        .StencilFunc = c.D3D12_COMPARISON_FUNC_ALWAYS,
                    },
                    .BackFace = .{
                        .StencilFailOp = c.D3D12_STENCIL_OP_KEEP,
                        .StencilDepthFailOp = c.D3D12_STENCIL_OP_KEEP,
                        .StencilPassOp = c.D3D12_STENCIL_OP_KEEP,
                        .StencilFunc = c.D3D12_COMPARISON_FUNC_ALWAYS,
                    },
                },
                .InputLayout = .{ .pInputElementDescs = null, .NumElements = 0 },
                .IBStripCutValue = c.D3D12_INDEX_BUFFER_STRIP_CUT_VALUE_DISABLED,
                .PrimitiveTopologyType = c.D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE,
                .NumRenderTargets = 1,
                .RTVFormats = [8]c.DXGI_FORMAT{
                    c.DXGI_FORMAT_R8G8B8A8_UNORM,
                    c.DXGI_FORMAT_UNKNOWN,
                    c.DXGI_FORMAT_UNKNOWN,
                    c.DXGI_FORMAT_UNKNOWN,
                    c.DXGI_FORMAT_UNKNOWN,
                    c.DXGI_FORMAT_UNKNOWN,
                    c.DXGI_FORMAT_UNKNOWN,
                    c.DXGI_FORMAT_UNKNOWN,
                },
                .DSVFormat = c.DXGI_FORMAT_UNKNOWN,
                .SampleDesc = .{ .Count = 1, .Quality = 0 },
                .NodeMask = 0,
                .CachedPSO = .{ .pCachedBlob = null, .CachedBlobSizeInBytes = 0 },
                .Flags = c.D3D12_PIPELINE_STATE_FLAG_NONE,
            },
            &c.IID_ID3D12PipelineState,
            @ptrCast(&d3d_pipeline),
        );
        if (hr != c.S_OK) {
            return error.CreateFailed;
        }
        errdefer _ = d3d_pipeline.lpVtbl.*.Release.?(d3d_pipeline);

        // Result
        var render_pipeline = try allocator.create(RenderPipeline);
        render_pipeline.* = .{
            .d3d_pipeline = d3d_pipeline,
        };
        return render_pipeline;
    }

    pub fn deinit(render_pipeline: *RenderPipeline) void {
        allocator.destroy(render_pipeline);
    }

    pub fn getBindGroupLayout(pipeline: *RenderPipeline, group_index: u32) *BindGroupLayout {
        _ = group_index;
        _ = pipeline;
        unreachable;
    }
};

pub const CommandBuffer = struct {
    manager: utils.Manager(CommandBuffer) = .{},
    command_allocator: *c.ID3D12CommandAllocator,
    command_list: *c.ID3D12GraphicsCommandList,

    pub fn init(device: *Device) !*CommandBuffer {
        const command_allocator = try device.command_manager.getCommandAllocator();
        const command_list = try device.command_manager.createCommandList(command_allocator);

        command_list.lpVtbl.*.SetGraphicsRootSignature.?(
            command_list,
            device.root_signature,
        );

        var cmd_buffer = try allocator.create(CommandBuffer);
        cmd_buffer.* = .{
            .command_allocator = command_allocator,
            .command_list = command_list,
        };
        return cmd_buffer;
    }

    pub fn deinit(cmd_buffer: *CommandBuffer) void {
        allocator.destroy(cmd_buffer);
    }
};

pub const CommandEncoder = struct {
    manager: utils.Manager(CommandEncoder) = .{},
    cmd_buffer: *CommandBuffer,

    pub fn init(device: *Device, desc: ?*const gpu.CommandEncoder.Descriptor) !*CommandEncoder {
        // TODO
        _ = desc;

        const cmd_buffer = try CommandBuffer.init(device);

        var encoder = try allocator.create(CommandEncoder);
        encoder.* = .{ .cmd_buffer = cmd_buffer };
        return encoder;
    }

    pub fn deinit(cmd_encoder: *CommandEncoder) void {
        allocator.destroy(cmd_encoder);
    }

    pub fn beginComputePass(encoder: *CommandEncoder, desc: *const gpu.ComputePassDescriptor) !*ComputePassEncoder {
        _ = desc;
        _ = encoder;
        unreachable;
    }

    pub fn beginRenderPass(cmd_encoder: *CommandEncoder, desc: *const gpu.RenderPassDescriptor) !*RenderPassEncoder {
        return RenderPassEncoder.init(cmd_encoder, desc);
    }

    pub fn copyBufferToBuffer(encoder: *CommandEncoder, source: *Buffer, source_offset: u64, destination: *Buffer, destination_offset: u64, size: u64) !void {
        _ = size;
        _ = destination_offset;
        _ = destination;
        _ = source_offset;
        _ = source;
        _ = encoder;
        unreachable;
    }

    pub fn finish(cmd_encoder: *CommandEncoder, desc: *const gpu.CommandBuffer.Descriptor) !*CommandBuffer {
        // TODO
        _ = desc;

        const command_list = cmd_encoder.cmd_buffer.command_list;
        var hr: c.HRESULT = undefined;

        hr = command_list.lpVtbl.*.Close.?(command_list);
        if (hr != c.S_OK) {
            return error.CommandEncoderFinish;
        }

        return cmd_encoder.cmd_buffer;
    }
};

pub const ComputePassEncoder = struct {
    manager: utils.Manager(ComputePassEncoder) = .{},

    pub fn init(command_encoder: *CommandEncoder, desc: *const gpu.ComputePassDescriptor) !*ComputePassEncoder {
        _ = desc;
        _ = command_encoder;
        unreachable;
    }

    pub fn deinit(encoder: *ComputePassEncoder) void {
        _ = encoder;
    }

    pub fn dispatchWorkgroups(encoder: *ComputePassEncoder, workgroup_count_x: u32, workgroup_count_y: u32, workgroup_count_z: u32) void {
        _ = workgroup_count_z;
        _ = workgroup_count_y;
        _ = workgroup_count_x;
        _ = encoder;
        unreachable;
    }

    pub fn setBindGroup(encoder: *ComputePassEncoder, group_index: u32, group: *BindGroup, dynamic_offset_count: usize, dynamic_offsets: ?[*]const u32) !void {
        _ = dynamic_offsets;
        _ = dynamic_offset_count;
        _ = group;
        _ = group_index;
        _ = encoder;
        unreachable;
    }

    pub fn setPipeline(encoder: *ComputePassEncoder, pipeline: *ComputePipeline) !void {
        _ = pipeline;
        _ = encoder;
        unreachable;
    }

    pub fn end(encoder: *ComputePassEncoder) void {
        _ = encoder;
        unreachable;
    }
};

pub const RenderPassEncoder = struct {
    manager: utils.Manager(RenderPassEncoder) = .{},
    command_list: *c.ID3D12GraphicsCommandList,
    color_attachment_count: usize,
    color_resources: [max_color_attachments]*c.ID3D12Resource,

    pub fn init(cmd_encoder: *CommandEncoder, desc: *const gpu.RenderPassDescriptor) !*RenderPassEncoder {
        const command_list = cmd_encoder.cmd_buffer.command_list;

        var width: u32 = 0;
        var height: u32 = 0;
        var color_resources = std.BoundedArray(*c.ID3D12Resource, max_color_attachments){};
        var resource_barriers = std.BoundedArray(c.D3D12_RESOURCE_BARRIER, max_color_attachments + 1){};
        var rtv_handles = std.BoundedArray(c.D3D12_CPU_DESCRIPTOR_HANDLE, max_color_attachments){};

        for (desc.color_attachments.?[0..desc.color_attachment_count], 0..) |attach, i| {
            _ = i;
            const view: *TextureView = @ptrCast(@alignCast(attach.view.?));

            const resource_barrier: c.D3D12_RESOURCE_BARRIER = .{
                .Type = c.D3D12_RESOURCE_BARRIER_TYPE_TRANSITION,
                .Flags = c.D3D12_RESOURCE_BARRIER_FLAG_NONE,
                .unnamed_0 = .{
                    .Transition = .{
                        .pResource = view.resource,
                        .Subresource = c.D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES,
                        .StateBefore = c.D3D12_RESOURCE_STATE_PRESENT, // TODO
                        .StateAfter = c.D3D12_RESOURCE_STATE_RENDER_TARGET,
                    },
                },
            };

            width = view.width;
            height = view.height;
            color_resources.appendAssumeCapacity(view.resource);
            resource_barriers.appendAssumeCapacity(resource_barrier);
            rtv_handles.appendAssumeCapacity(view.cpu_handle);
        }

        command_list.lpVtbl.*.ResourceBarrier.?(
            command_list,
            @intCast(desc.color_attachment_count),
            &resource_barriers.buffer,
        );

        command_list.lpVtbl.*.OMSetRenderTargets.?(
            command_list,
            @intCast(desc.color_attachment_count),
            &rtv_handles.buffer,
            c.FALSE,
            null,
        );

        for (desc.color_attachments.?[0..desc.color_attachment_count], 0..) |attach, i| {
            _ = i;
            const view: *TextureView = @ptrCast(@alignCast(attach.view.?));

            if (attach.load_op == .clear) {
                const clear_color = [4]f32{
                    @floatCast(attach.clear_value.r),
                    @floatCast(attach.clear_value.g),
                    @floatCast(attach.clear_value.b),
                    @floatCast(attach.clear_value.a),
                };
                command_list.lpVtbl.*.ClearRenderTargetView.?(
                    command_list,
                    view.cpu_handle,
                    &clear_color,
                    0,
                    null,
                );
            }
        }

        const viewport = c.D3D12_VIEWPORT{
            .TopLeftX = 0,
            .TopLeftY = 0,
            .Width = @floatFromInt(width),
            .Height = @floatFromInt(height),
            .MinDepth = 0,
            .MaxDepth = 1,
        };
        const scissor_rect = c.D3D12_RECT{
            .left = 0,
            .top = 0,
            .right = @intCast(width),
            .bottom = @intCast(height),
        };

        command_list.lpVtbl.*.RSSetViewports.?(command_list, 1, &viewport);
        command_list.lpVtbl.*.RSSetScissorRects.?(command_list, 1, &scissor_rect);

        // Result
        var encoder = try allocator.create(RenderPassEncoder);
        encoder.* = .{
            .command_list = command_list,
            .color_attachment_count = desc.color_attachment_count,
            .color_resources = color_resources.buffer,
        };
        return encoder;
    }

    pub fn deinit(encoder: *RenderPassEncoder) void {
        allocator.destroy(encoder);
    }

    pub fn setBindGroup(encoder: *RenderPassEncoder, group_index: u32, group: *BindGroup, dynamic_offset_count: usize, dynamic_offsets: ?[*]const u32) !void {
        _ = dynamic_offsets;
        _ = dynamic_offset_count;
        _ = group;
        _ = group_index;
        _ = encoder;
        unreachable;
    }

    pub fn setPipeline(encoder: *RenderPassEncoder, pipeline: *RenderPipeline) !void {
        const command_list = encoder.command_list;

        command_list.lpVtbl.*.SetPipelineState.?(
            command_list,
            pipeline.d3d_pipeline,
        );

        command_list.lpVtbl.*.IASetPrimitiveTopology.?(
            command_list,
            c.D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST, // TODO
        );
    }

    pub fn setVertexBuffer(encoder: *RenderPassEncoder, slot: u32, buffer: *Buffer, offset: u64, size: u64) !void {
        _ = encoder;
        _ = slot;
        _ = buffer;
        _ = offset;
        _ = size;
        unreachable;
    }

    pub fn draw(encoder: *RenderPassEncoder, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void {
        const command_list = encoder.command_list;

        command_list.lpVtbl.*.DrawInstanced.?(
            command_list,
            vertex_count,
            instance_count,
            first_vertex,
            first_instance,
        );
    }

    pub fn end(encoder: *RenderPassEncoder) void {
        const command_list = encoder.command_list;

        var resource_barriers = std.BoundedArray(c.D3D12_RESOURCE_BARRIER, max_color_attachments + 1){};

        for (encoder.color_resources[0..encoder.color_attachment_count]) |resource| {
            const resource_barrier: c.D3D12_RESOURCE_BARRIER = .{
                .Type = c.D3D12_RESOURCE_BARRIER_TYPE_TRANSITION,
                .Flags = c.D3D12_RESOURCE_BARRIER_FLAG_NONE,
                .unnamed_0 = .{
                    .Transition = .{
                        .pResource = resource,
                        .Subresource = c.D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES,
                        .StateBefore = c.D3D12_RESOURCE_STATE_RENDER_TARGET,
                        .StateAfter = c.D3D12_RESOURCE_STATE_PRESENT, // TODO
                    },
                },
            };

            resource_barriers.appendAssumeCapacity(resource_barrier);
        }

        command_list.lpVtbl.*.ResourceBarrier.?(
            command_list,
            @intCast(encoder.color_attachment_count),
            &resource_barriers.buffer,
        );
    }
};

pub const Queue = struct {
    manager: utils.Manager(Queue) = .{},
    d3d_command_queue: *c.ID3D12CommandQueue,
    command_manager: *CommandManager,
    fence: *c.ID3D12Fence,
    fence_value: u64 = 0,
    fence_event: c.HANDLE,

    pub fn init(d3d_device: *c.ID3D12Device, command_manager: *CommandManager) !*Queue {
        var hr: c.HRESULT = undefined;

        // Command Queue
        var d3d_command_queue: *c.ID3D12CommandQueue = undefined;
        hr = d3d_device.lpVtbl.*.CreateCommandQueue.?(
            d3d_device,
            &c.D3D12_COMMAND_QUEUE_DESC{
                .Type = c.D3D12_COMMAND_LIST_TYPE_DIRECT,
                .Priority = c.D3D12_COMMAND_QUEUE_PRIORITY_NORMAL,
                .Flags = c.D3D12_COMMAND_QUEUE_FLAG_NONE,
                .NodeMask = 0,
            },
            &c.IID_ID3D12CommandQueue,
            @ptrCast(&d3d_command_queue),
        );
        if (hr != c.S_OK) {
            return error.CreateFailed;
        }
        errdefer _ = d3d_command_queue.lpVtbl.*.Release.?(d3d_command_queue);

        // Fence
        var fence: *c.ID3D12Fence = undefined;
        hr = d3d_device.lpVtbl.*.CreateFence.?(
            d3d_device,
            0,
            c.D3D12_FENCE_FLAG_NONE,
            &c.IID_ID3D12Fence,
            @ptrCast(&fence),
        );
        if (hr != c.S_OK) {
            return error.CreateFailed;
        }
        errdefer _ = fence.lpVtbl.*.Release.?(fence);

        // Fence Event
        var fence_event = c.CreateEventW(null, c.FALSE, c.FALSE, null);
        if (fence_event == null) {
            return error.CreateFailed;
        }
        errdefer _ = c.CloseHandle(fence_event);

        // Result
        var queue = try allocator.create(Queue);
        queue.* = .{
            .d3d_command_queue = d3d_command_queue,
            .command_manager = command_manager,
            .fence = fence,
            .fence_event = fence_event,
        };
        return queue;
    }

    pub fn deinit(queue: *Queue) void {
        const d3d_command_queue = queue.d3d_command_queue;
        const fence = queue.fence;

        _ = d3d_command_queue.lpVtbl.*.Release.?(d3d_command_queue);
        _ = fence.lpVtbl.*.Release.?(fence);
        _ = c.CloseHandle(queue.fence_event);
        allocator.destroy(queue);
    }

    pub fn submit(queue: *Queue, command_buffers: []const *CommandBuffer) !void {
        const command_manager = queue.command_manager;
        const d3d_command_queue = queue.d3d_command_queue;

        const command_lists = try allocator.alloc(*c.ID3D12GraphicsCommandList, command_buffers.len);
        defer allocator.free(command_lists);

        queue.fence_value += 1;

        for (command_buffers, 0..) |command_buffer, i| {
            command_lists[i] = command_buffer.command_list;
            try command_manager.enqueueCommandAllocator(
                command_buffer.command_allocator,
                queue,
                queue.fence_value,
            );
        }

        d3d_command_queue.lpVtbl.*.ExecuteCommandLists.?(
            d3d_command_queue,
            @intCast(command_buffers.len),
            @ptrCast(command_lists.ptr),
        );

        for (command_lists) |command_list| {
            try command_manager.destroyCommandList(command_list);
        }

        try queue.signal();
    }

    pub fn signal(queue: *Queue) !void {
        const d3d_command_queue = queue.d3d_command_queue;
        var hr: c.HRESULT = undefined;

        hr = d3d_command_queue.lpVtbl.*.Signal.?(
            d3d_command_queue,
            queue.fence,
            queue.fence_value,
        );
        if (hr != c.S_OK) {
            return error.SignalFailed;
        }
    }

    pub fn waitUntil(queue: *Queue, fence_value: u64) void {
        const fence = queue.fence;
        const fence_event = queue.fence_event;
        var hr: c.HRESULT = undefined;

        const completed_value = fence.lpVtbl.*.GetCompletedValue.?(fence);
        if (completed_value >= fence_value)
            return;

        hr = fence.lpVtbl.*.SetEventOnCompletion.?(
            fence,
            fence_value,
            fence_event,
        );
        std.debug.assert(hr == c.S_OK);

        const result = c.WaitForSingleObject(fence_event, c.INFINITE);
        std.debug.assert(result == c.WAIT_OBJECT_0);
    }

    pub fn writeBuffer(queue: *Queue, buffer: *Buffer, offset: u64, data: [*]const u8, size: u64) !void {
        _ = queue;
        _ = buffer;
        _ = offset;
        _ = data;
        _ = size;
        unreachable;
    }
};
