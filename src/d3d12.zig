const std = @import("std");
const dgpu = @import("dgpu/main.zig");
const limits = @import("limits.zig");
const shader = @import("shader.zig");
const utils = @import("utils.zig");
const c = @import("d3d12/c.zig");
const conv = @import("d3d12/conv.zig");

const log = std.log.scoped(.d3d12);

// TODO - need to tweak all these sizes and make a better allocator
const general_heap_size = 1024;
const general_block_size = 16;
const sampler_heap_size = 1024;
const sampler_block_size = 16;
const rtv_heap_size = 1024;
const rtv_block_size = 16;
const dsv_heap_size = 1024;
const dsv_block_size = 1;
const upload_page_size = 64 * 1024 * 1024; // TODO - split writes and/or support large uploads
const max_back_buffer_count = 3;

var allocator: std.mem.Allocator = undefined;
var debug_enabled: bool = undefined;
var gpu_validation_enabled: bool = undefined;

// workaround issues with @alignCast panicking as these aren't real pointers
extern fn hwndCast(*anyopaque) c.HWND;

// workaround c-translation errors
const DXGI_PRESENT_ALLOW_TEARING: c.UINT = 0x00000200;

pub const InitOptions = struct {
    debug_enabled: bool = true,
    gpu_validation_enabled: bool = true,
};

pub fn init(alloc: std.mem.Allocator, options: InitOptions) !void {
    allocator = alloc;
    debug_enabled = options.debug_enabled;
    gpu_validation_enabled = options.gpu_validation_enabled;
}

const QueuedOperation = struct {
    fence_value: u64,
    payload: Payload,

    pub const Payload = union(enum) {
        release: *c.IUnknown,
        map_callback: struct {
            buffer: *Buffer,
            callback: dgpu.Buffer.MapCallback,
            userdata: ?*anyopaque,
        },
        free_command_allocator: *c.ID3D12CommandAllocator,
        free_descriptor_block: struct {
            heap: *DescriptorHeap,
            allocation: DescriptorAllocation,
        },
    };

    pub fn exec(op: QueuedOperation, device: *Device) void {
        switch (op.payload) {
            .release => |obj| {
                _ = obj.lpVtbl.*.Release.?(obj);
            },
            .map_callback => |map_callback| {
                map_callback.buffer.mapBeforeCallback() catch {
                    map_callback.callback(.unknown, map_callback.userdata);
                    return;
                };
                map_callback.callback(.success, map_callback.userdata);
            },
            .free_command_allocator => |command_allocator| {
                device.command_manager.free_allocators.append(allocator, command_allocator) catch {
                    std.debug.panic("OutOfMemory", .{});
                };
            },
            .free_descriptor_block => |block| {
                block.heap.free_blocks.append(allocator, block.allocation) catch {
                    std.debug.panic("OutOfMemory", .{});
                };
            },
        }
    }
};

pub const Instance = struct {
    manager: utils.Manager(Instance) = .{},
    dxgi_factory: *c.IDXGIFactory4,
    allow_tearing: bool,

    pub fn init(desc: *const dgpu.Instance.Descriptor) !*Instance {
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

        var opt_dxgi_factory5: ?*c.IDXGIFactory5 = null;
        _ = dxgi_factory.lpVtbl.*.QueryInterface.?(
            dxgi_factory,
            &c.IID_IDXGIFactory5,
            @ptrCast(&opt_dxgi_factory5),
        );
        defer _ = if (opt_dxgi_factory5) |dxgi_factory5| dxgi_factory5.lpVtbl.*.Release.?(dxgi_factory5);

        // Feature support
        var allow_tearing: c.BOOL = c.FALSE;
        if (opt_dxgi_factory5) |dxgi_factory5| {
            hr = dxgi_factory5.lpVtbl.*.CheckFeatureSupport.?(
                dxgi_factory5,
                c.DXGI_FEATURE_PRESENT_ALLOW_TEARING,
                &allow_tearing,
                @sizeOf(@TypeOf(allow_tearing)),
            );
        }

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
            .allow_tearing = allow_tearing == c.TRUE,
        };
        return instance;
    }

    pub fn deinit(instance: *Instance) void {
        const dxgi_factory = instance.dxgi_factory;

        _ = dxgi_factory.lpVtbl.*.Release.?(dxgi_factory);
        Instance.reportLiveObjects();
        allocator.destroy(instance);
    }

    pub fn createSurface(instance: *Instance, desc: *const dgpu.Surface.Descriptor) !*Surface {
        return Surface.init(instance, desc);
    }

    // Internal
    pub fn reportLiveObjects() void {
        var hr: c.HRESULT = undefined;

        var dxgi_debug: *c.IDXGIDebug = undefined;
        hr = c.DXGIGetDebugInterface1(0, &c.IID_IDXGIDebug, @ptrCast(&dxgi_debug));
        if (hr == c.S_OK) {
            defer _ = dxgi_debug.lpVtbl.*.Release.?(dxgi_debug);

            _ = dxgi_debug.lpVtbl.*.ReportLiveObjects.?(
                dxgi_debug,
                c.DXGI_DEBUG_ALL,
                c.DXGI_DEBUG_RLO_ALL,
            );
        }
    }
};

pub const Adapter = struct {
    manager: utils.Manager(Adapter) = .{},
    instance: *Instance,
    dxgi_adapter: *c.IDXGIAdapter1,
    d3d_device: *c.ID3D12Device,
    dxgi_desc: c.DXGI_ADAPTER_DESC1,

    pub fn init(instance: *Instance, options: *const dgpu.RequestAdapterOptions) !*Adapter {
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

    pub fn createDevice(adapter: *Adapter, desc: ?*const dgpu.Device.Descriptor) !*Device {
        return Device.init(adapter, desc);
    }

    pub fn getProperties(adapter: *Adapter) dgpu.Adapter.Properties {
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

    pub fn init(instance: *Instance, desc: *const dgpu.Surface.Descriptor) !*Surface {
        _ = instance;

        if (utils.findChained(dgpu.Surface.DescriptorFromWindowsHWND, desc.next_in_chain.generic)) |win_desc| {
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
    queue: *Queue,
    general_heap: DescriptorHeap = undefined,
    sampler_heap: DescriptorHeap = undefined,
    rtv_heap: DescriptorHeap = undefined,
    dsv_heap: DescriptorHeap = undefined,
    command_manager: CommandManager = undefined,
    streaming_manager: StreamingManager = undefined,
    queued_operations: std.ArrayListUnmanaged(QueuedOperation) = .{},

    lost_cb: ?dgpu.Device.LostCallback = null,
    lost_cb_userdata: ?*anyopaque = null,
    log_cb: ?dgpu.LoggingCallback = null,
    log_cb_userdata: ?*anyopaque = null,
    err_cb: ?dgpu.ErrorCallback = null,
    err_cb_userdata: ?*anyopaque = null,

    pub fn init(adapter: *Adapter, desc: ?*const dgpu.Device.Descriptor) !*Device {
        const d3d_device = adapter.d3d_device;
        var hr: c.HRESULT = undefined;

        // TODO
        _ = desc;

        // Debug Configuration
        if (debug_enabled) {
            var info_queue: *c.ID3D12InfoQueue = undefined;

            hr = d3d_device.lpVtbl.*.QueryInterface.?(
                d3d_device,
                &c.IID_ID3D12InfoQueue,
                @ptrCast(&info_queue),
            );
            if (hr == c.S_OK) {
                defer _ = info_queue.lpVtbl.*.Release.?(info_queue);

                var deny_ids = [_]c.D3D12_MESSAGE_ID{
                    c.D3D12_MESSAGE_ID_CLEARRENDERTARGETVIEW_MISMATCHINGCLEARVALUE,
                    c.D3D12_MESSAGE_ID_CLEARDEPTHSTENCILVIEW_MISMATCHINGCLEARVALUE,
                };
                var severities = [_]c.D3D12_MESSAGE_SEVERITY{
                    c.D3D12_MESSAGE_SEVERITY_INFO,
                    c.D3D12_MESSAGE_SEVERITY_MESSAGE,
                };
                var filter = c.D3D12_INFO_QUEUE_FILTER{
                    .AllowList = .{
                        .NumCategories = 0,
                        .pCategoryList = null,
                        .NumSeverities = 0,
                        .pSeverityList = null,
                        .NumIDs = 0,
                        .pIDList = null,
                    },
                    .DenyList = .{
                        .NumCategories = 0,
                        .pCategoryList = null,
                        .NumSeverities = severities.len,
                        .pSeverityList = &severities,
                        .NumIDs = deny_ids.len,
                        .pIDList = &deny_ids,
                    },
                };

                hr = info_queue.lpVtbl.*.PushStorageFilter.?(
                    info_queue,
                    &filter,
                );
                std.debug.assert(hr == c.S_OK);
            }
        }

        // Result
        const queue = try allocator.create(Queue);
        errdefer allocator.destroy(queue);

        var device = try allocator.create(Device);
        device.* = .{
            .adapter = adapter,
            .d3d_device = d3d_device,
            .queue = queue,
        };
        // TODO - how to deal with errors?
        device.queue.* = try Queue.init(device);
        device.general_heap = try DescriptorHeap.init(
            device,
            c.D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV,
            c.D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE,
            general_heap_size,
            general_block_size,
        );
        device.sampler_heap = try DescriptorHeap.init(
            device,
            c.D3D12_DESCRIPTOR_HEAP_TYPE_SAMPLER,
            c.D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE,
            sampler_heap_size,
            sampler_block_size,
        );
        device.rtv_heap = try DescriptorHeap.init(
            device,
            c.D3D12_DESCRIPTOR_HEAP_TYPE_RTV,
            c.D3D12_DESCRIPTOR_HEAP_FLAG_NONE,
            rtv_heap_size,
            rtv_block_size,
        );
        device.dsv_heap = try DescriptorHeap.init(
            device,
            c.D3D12_DESCRIPTOR_HEAP_TYPE_DSV,
            c.D3D12_DESCRIPTOR_HEAP_FLAG_NONE,
            dsv_heap_size,
            dsv_block_size,
        );
        device.command_manager = CommandManager.init(device);
        device.streaming_manager = try StreamingManager.init(device);
        return device;
    }

    pub fn deinit(device: *Device) void {
        if (device.lost_cb) |lost_cb| {
            lost_cb(.destroyed, "Device was destroyed.", device.lost_cb_userdata);
        }

        device.queue.waitUntil(device.queue.fence_value);
        device.processQueuedOperations();

        device.queued_operations.deinit(allocator);
        device.streaming_manager.deinit();
        device.command_manager.deinit();
        device.dsv_heap.deinit();
        device.rtv_heap.deinit();
        device.sampler_heap.deinit();
        device.general_heap.deinit();
        device.queue.manager.release();
        allocator.destroy(device.queue);
        allocator.destroy(device);
    }

    pub fn createBindGroup(device: *Device, desc: *const dgpu.BindGroup.Descriptor) !*BindGroup {
        return BindGroup.init(device, desc);
    }

    pub fn createBindGroupLayout(device: *Device, desc: *const dgpu.BindGroupLayout.Descriptor) !*BindGroupLayout {
        return BindGroupLayout.init(device, desc);
    }

    pub fn createBuffer(device: *Device, desc: *const dgpu.Buffer.Descriptor) !*Buffer {
        return Buffer.init(device, desc);
    }

    pub fn createCommandEncoder(device: *Device, desc: *const dgpu.CommandEncoder.Descriptor) !*CommandEncoder {
        return CommandEncoder.init(device, desc);
    }

    pub fn createComputePipeline(device: *Device, desc: *const dgpu.ComputePipeline.Descriptor) !*ComputePipeline {
        return ComputePipeline.init(device, desc);
    }

    pub fn createPipelineLayout(device: *Device, desc: *const dgpu.PipelineLayout.Descriptor) !*PipelineLayout {
        return PipelineLayout.init(device, desc);
    }

    pub fn createRenderPipeline(device: *Device, desc: *const dgpu.RenderPipeline.Descriptor) !*RenderPipeline {
        return RenderPipeline.init(device, desc);
    }

    pub fn createSampler(device: *Device, desc: *const dgpu.Sampler.Descriptor) !*Sampler {
        _ = desc;
        _ = device;
        unreachable;
    }

    pub fn createShaderModuleAir(device: *Device, air: *shader.Air) !*ShaderModule {
        return ShaderModule.initAir(device, air);
    }

    pub fn createShaderModuleSpirv(device: *Device, code: []const u8) !*ShaderModule {
        _ = code;
        _ = device;
        return error.unsupported;
    }

    pub fn createSwapChain(device: *Device, surface: *Surface, desc: *const dgpu.SwapChain.Descriptor) !*SwapChain {
        return SwapChain.init(device, surface, desc);
    }

    pub fn createTexture(device: *Device, desc: *const dgpu.Texture.Descriptor) !*Texture {
        return Texture.init(device, desc);
    }

    pub fn getQueue(device: *Device) !*Queue {
        return device.queue;
    }

    pub fn tick(device: *Device) !void {
        device.processQueuedOperations();
    }

    // Internal
    pub fn queueOperation(device: *Device, fence_value: u64, payload: QueuedOperation.Payload) void {
        device.queued_operations.append(
            allocator,
            .{ .fence_value = fence_value, .payload = payload },
        ) catch std.debug.panic("OutOfMemory", .{});
    }

    pub fn processQueuedOperations(device: *Device) void {
        const fence = device.queue.fence;
        const completed_value = fence.lpVtbl.*.GetCompletedValue.?(fence);

        var i: usize = 0;
        while (i < device.queued_operations.items.len) {
            const queued_operation = device.queued_operations.items[i];

            if (queued_operation.fence_value <= completed_value) {
                queued_operation.exec(device);
                _ = device.queued_operations.swapRemove(i);
            } else {
                i += 1;
            }
        }
    }

    pub fn createD3dBuffer(device: *Device, usage: dgpu.Buffer.UsageFlags, size: u64) !Resource {
        const d3d_device = device.d3d_device;
        var hr: c.HRESULT = undefined;

        const resource_size = conv.d3d12ResourceSizeForBuffer(size, usage);

        const heap_type = conv.d3d12HeapType(usage);
        const heap_properties = c.D3D12_HEAP_PROPERTIES{
            .Type = heap_type,
            .CPUPageProperty = c.D3D12_CPU_PAGE_PROPERTY_UNKNOWN,
            .MemoryPoolPreference = c.D3D12_MEMORY_POOL_UNKNOWN,
            .CreationNodeMask = 1,
            .VisibleNodeMask = 1,
        };
        const resource_desc = c.D3D12_RESOURCE_DESC{
            .Dimension = c.D3D12_RESOURCE_DIMENSION_BUFFER,
            .Alignment = 0,
            .Width = resource_size,
            .Height = 1,
            .DepthOrArraySize = 1,
            .MipLevels = 1,
            .Format = c.DXGI_FORMAT_UNKNOWN,
            .SampleDesc = .{ .Count = 1, .Quality = 0 },
            .Layout = c.D3D12_TEXTURE_LAYOUT_ROW_MAJOR,
            .Flags = conv.d3d12ResourceFlagsForBuffer(usage),
        };
        const read_state = conv.d3d12ResourceStatesForBufferRead(usage);
        const initial_state = conv.d3d12ResourceStatesInitial(heap_type);

        var d3d_resource: *c.ID3D12Resource = undefined;
        hr = d3d_device.lpVtbl.*.CreateCommittedResource.?(
            d3d_device,
            &heap_properties,
            c.D3D12_HEAP_FLAG_CREATE_NOT_ZEROED,
            &resource_desc,
            initial_state,
            null,
            &c.IID_ID3D12Resource,
            @ptrCast(&d3d_resource),
        );
        if (hr != c.S_OK) {
            return error.CreateFailed;
        }

        return Resource.init(d3d_resource, read_state, initial_state);
    }
};

const DescriptorAllocation = struct {
    index: u32,
};

const DescriptorHeap = struct {
    // Initial version supports fixed-block size allocation only
    device: *Device,
    d3d_heap: *c.ID3D12DescriptorHeap,
    cpu_base: c.D3D12_CPU_DESCRIPTOR_HANDLE,
    gpu_base: c.D3D12_GPU_DESCRIPTOR_HANDLE,
    descriptor_size: u32,
    descriptor_count: u32,
    block_size: u32,
    next_alloc: u32,
    free_blocks: std.ArrayListUnmanaged(DescriptorAllocation) = .{},

    pub fn init(
        device: *Device,
        heap_type: c.D3D12_DESCRIPTOR_HEAP_TYPE,
        flags: c.D3D12_DESCRIPTOR_HEAP_FLAGS,
        descriptor_count: u32,
        block_size: u32,
    ) !DescriptorHeap {
        const d3d_device = device.d3d_device;
        var hr: c.HRESULT = undefined;

        var d3d_heap: *c.ID3D12DescriptorHeap = undefined;
        hr = d3d_device.lpVtbl.*.CreateDescriptorHeap.?(
            d3d_device,
            &c.D3D12_DESCRIPTOR_HEAP_DESC{
                .Type = heap_type,
                .NumDescriptors = descriptor_count,
                .Flags = flags,
                .NodeMask = 0,
            },
            &c.IID_ID3D12DescriptorHeap,
            @ptrCast(&d3d_heap),
        );
        if (hr != c.S_OK) {
            return error.CreateFailed;
        }
        errdefer _ = d3d_heap.lpVtbl.*.Release.?(d3d_heap);

        const descriptor_size = d3d_device.lpVtbl.*.GetDescriptorHandleIncrementSize.?(
            d3d_device,
            heap_type,
        );

        var cpu_base: c.D3D12_CPU_DESCRIPTOR_HANDLE = undefined;
        _ = d3d_heap.lpVtbl.*.GetCPUDescriptorHandleForHeapStart.?(
            d3d_heap,
            &cpu_base,
        );

        var gpu_base: c.D3D12_GPU_DESCRIPTOR_HANDLE = undefined;
        if ((flags & c.D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE) != 0) {
            _ = d3d_heap.lpVtbl.*.GetGPUDescriptorHandleForHeapStart.?(
                d3d_heap,
                &gpu_base,
            );
        } else {
            gpu_base = .{ .ptr = 0 };
        }

        return .{
            .device = device,
            .d3d_heap = d3d_heap,
            .cpu_base = cpu_base,
            .gpu_base = gpu_base,
            .descriptor_size = descriptor_size,
            .descriptor_count = descriptor_count,
            .block_size = block_size,
            .next_alloc = 0,
        };
    }

    pub fn deinit(heap: *DescriptorHeap) void {
        const d3d_heap = heap.d3d_heap;

        heap.free_blocks.deinit(allocator);
        _ = d3d_heap.lpVtbl.*.Release.?(d3d_heap);
    }

    pub fn alloc(heap: *DescriptorHeap) !DescriptorAllocation {
        // Recycle finished blocks
        if (heap.free_blocks.items.len == 0) {
            heap.device.processQueuedOperations();
        }

        // Create new block
        if (heap.free_blocks.items.len == 0) {
            if (heap.next_alloc == heap.descriptor_count)
                return error.OutOfMemory;

            const index = heap.next_alloc;
            heap.next_alloc += heap.block_size;
            try heap.free_blocks.append(allocator, .{ .index = index });
        }

        // Result
        return heap.free_blocks.pop();
    }

    pub fn free(heap: *DescriptorHeap, allocation: DescriptorAllocation, fence_value: u64) void {
        heap.device.queueOperation(
            fence_value,
            .{ .free_descriptor_block = .{ .heap = heap, .allocation = allocation } },
        );
    }

    pub fn cpuDescriptor(heap: *DescriptorHeap, index: u32) c.D3D12_CPU_DESCRIPTOR_HANDLE {
        return .{ .ptr = heap.cpu_base.ptr + index * heap.descriptor_size };
    }

    pub fn gpuDescriptor(heap: *DescriptorHeap, index: u32) c.D3D12_GPU_DESCRIPTOR_HANDLE {
        return .{ .ptr = heap.gpu_base.ptr + index * heap.descriptor_size };
    }
};

const CommandManager = struct {
    device: *Device,
    free_allocators: std.ArrayListUnmanaged(*c.ID3D12CommandAllocator) = .{},
    free_command_lists: std.ArrayListUnmanaged(*c.ID3D12GraphicsCommandList) = .{},

    pub fn init(device: *Device) CommandManager {
        return .{
            .device = device,
        };
    }

    pub fn deinit(manager: *CommandManager) void {
        for (manager.free_allocators.items) |command_allocator| {
            _ = command_allocator.lpVtbl.*.Release.?(command_allocator);
        }
        for (manager.free_command_lists.items) |command_list| {
            _ = command_list.lpVtbl.*.Release.?(command_list);
        }

        manager.free_allocators.deinit(allocator);
        manager.free_command_lists.deinit(allocator);
    }

    pub fn createCommandAllocator(manager: *CommandManager) !*c.ID3D12CommandAllocator {
        const d3d_device = manager.device.d3d_device;
        var hr: c.HRESULT = undefined;

        // Recycle finished allocators
        if (manager.free_allocators.items.len == 0) {
            manager.device.processQueuedOperations();
        }

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

            try manager.free_allocators.append(allocator, command_allocator);
        }

        // Reset
        const command_allocator = manager.free_allocators.pop();
        hr = command_allocator.lpVtbl.*.Reset.?(command_allocator);
        if (hr != c.S_OK) {
            return error.ResetFailed;
        }
        return command_allocator;
    }

    pub fn destroyCommandAllocator(
        manager: *CommandManager,
        command_allocator: *c.ID3D12CommandAllocator,
        fence_value: u64,
    ) void {
        manager.device.queueOperation(
            fence_value,
            .{ .free_command_allocator = command_allocator },
        );
    }

    pub fn createCommandList(
        manager: *CommandManager,
        command_allocator: *c.ID3D12CommandAllocator,
    ) !*c.ID3D12GraphicsCommandList {
        const d3d_device = manager.device.d3d_device;
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

    pub fn destroyCommandList(manager: *CommandManager, command_list: *c.ID3D12GraphicsCommandList) void {
        manager.free_command_lists.append(allocator, command_list) catch std.debug.panic("OutOfMemory", .{});
    }
};

pub const StreamingManager = struct {
    device: *Device,
    free_buffers: std.ArrayListUnmanaged(*c.ID3D12Resource) = .{},

    pub fn init(device: *Device) !StreamingManager {
        return .{
            .device = device,
        };
    }

    pub fn deinit(manager: *StreamingManager) void {
        for (manager.free_buffers.items) |d3d_resource| {
            _ = d3d_resource.lpVtbl.*.Release.?(d3d_resource);
        }
        manager.free_buffers.deinit(allocator);
    }

    pub fn acquire(manager: *StreamingManager) !*c.ID3D12Resource {
        const device = manager.device;

        // Recycle finished buffers
        if (manager.free_buffers.items.len == 0) {
            device.processQueuedOperations();
        }

        // Create new buffer
        if (manager.free_buffers.items.len == 0) {
            var resource = try device.createD3dBuffer(.{ .map_write = true }, upload_page_size);
            errdefer _ = resource.deinit(device, null);

            try manager.free_buffers.append(allocator, resource.d3d_resource);
        }

        // Result
        return manager.free_buffers.pop();
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
    back_buffer_count: u32,
    sync_interval: c.UINT,
    present_flags: c.UINT,
    textures: [max_back_buffer_count]*Texture,
    views: [max_back_buffer_count]*TextureView,
    fence_values: [max_back_buffer_count]u64,
    buffer_index: u32 = 0,

    pub fn init(device: *Device, surface: *Surface, desc: *const dgpu.SwapChain.Descriptor) !*SwapChain {
        const instance = device.adapter.instance;
        const dxgi_factory = instance.dxgi_factory;
        var hr: c.HRESULT = undefined;

        device.processQueuedOperations();

        // Swap Chain
        const back_buffer_count: u32 = if (desc.present_mode == .mailbox) 3 else 2;
        var swap_chain_desc = c.DXGI_SWAP_CHAIN_DESC1{
            .Width = desc.width,
            .Height = desc.height,
            .Format = conv.dxgiFormatForTexture(desc.format),
            .Stereo = c.FALSE,
            .SampleDesc = .{ .Count = 1, .Quality = 0 },
            .BufferUsage = conv.dxgiUsage(desc.usage),
            .BufferCount = back_buffer_count,
            .Scaling = c.DXGI_MODE_SCALING_UNSPECIFIED,
            .SwapEffect = c.DXGI_SWAP_EFFECT_FLIP_DISCARD,
            .AlphaMode = c.DXGI_ALPHA_MODE_UNSPECIFIED,
            .Flags = if (instance.allow_tearing) c.DXGI_SWAP_CHAIN_FLAG_ALLOW_TEARING else 0,
        };

        var dxgi_swap_chain: *c.IDXGISwapChain3 = undefined;
        hr = dxgi_factory.lpVtbl.*.CreateSwapChainForHwnd.?(
            dxgi_factory,
            @ptrCast(device.queue.d3d_command_queue),
            surface.hwnd,
            &swap_chain_desc,
            null,
            null,
            @ptrCast(&dxgi_swap_chain),
        );
        if (hr != c.S_OK) {
            return error.CreateFailed;
        }
        errdefer _ = dxgi_swap_chain.lpVtbl.*.Release.?(dxgi_swap_chain);

        // Views
        var textures = std.BoundedArray(*Texture, max_back_buffer_count){};
        var views = std.BoundedArray(*TextureView, max_back_buffer_count){};
        var fence_values = std.BoundedArray(u64, max_back_buffer_count){};
        errdefer {
            for (views.slice()) |view| view.manager.release();
            for (textures.slice()) |texture| texture.manager.release();
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

            const texture = try Texture.initForSwapChain(device, buffer);
            const view = try texture.createView(null);

            textures.appendAssumeCapacity(texture);
            views.appendAssumeCapacity(view);
            fence_values.appendAssumeCapacity(0);
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
            .back_buffer_count = back_buffer_count,
            .sync_interval = if (desc.present_mode == .immediate) 0 else 1,
            .present_flags = if (desc.present_mode == .immediate and instance.allow_tearing) DXGI_PRESENT_ALLOW_TEARING else 0,
            .textures = textures.buffer,
            .views = views.buffer,
            .fence_values = fence_values.buffer,
        };
        return swapchain;
    }

    pub fn deinit(swapchain: *SwapChain) void {
        const dxgi_swap_chain = swapchain.dxgi_swap_chain;
        const queue = swapchain.queue;

        queue.waitUntil(queue.fence_value);

        for (swapchain.views[0..swapchain.back_buffer_count]) |view| view.manager.release();
        for (swapchain.textures[0..swapchain.back_buffer_count]) |texture| texture.manager.release();
        _ = dxgi_swap_chain.lpVtbl.*.Release.?(dxgi_swap_chain);
        allocator.destroy(swapchain);
    }

    pub fn getCurrentTextureView(swapchain: *SwapChain) !*TextureView {
        const dxgi_swap_chain = swapchain.dxgi_swap_chain;

        const fence_value = swapchain.fence_values[swapchain.buffer_index];
        swapchain.queue.waitUntil(fence_value);

        const index = dxgi_swap_chain.lpVtbl.*.GetCurrentBackBufferIndex.?(dxgi_swap_chain);
        swapchain.buffer_index = index;
        // TEMP - resolve reference tracking in main.zig
        swapchain.views[index].manager.reference();
        return swapchain.views[index];
    }

    pub fn present(swapchain: *SwapChain) !void {
        const dxgi_swap_chain = swapchain.dxgi_swap_chain;
        const queue = swapchain.queue;
        var hr: c.HRESULT = undefined;

        hr = dxgi_swap_chain.lpVtbl.*.Present.?(
            dxgi_swap_chain,
            swapchain.sync_interval,
            swapchain.present_flags,
        );
        if (hr != c.S_OK) {
            return error.PresentFailed;
        }

        queue.fence_value += 1;
        try queue.signal();
        swapchain.fence_values[swapchain.buffer_index] = queue.fence_value;
    }
};

pub const Resource = struct {
    // NOTE - this is a naive sync solution as a placeholder until render graphs are implemented
    d3d_resource: *c.ID3D12Resource,
    read_state: c.D3D12_RESOURCE_STATES,
    current_state: c.D3D12_RESOURCE_STATES,

    pub fn init(
        d3d_resource: *c.ID3D12Resource,
        read_state: c.D3D12_RESOURCE_STATES,
        current_state: c.D3D12_RESOURCE_STATES,
    ) Resource {
        return .{
            .d3d_resource = d3d_resource,
            .read_state = read_state,
            .current_state = current_state,
        };
    }

    pub fn deinit(resource: *Resource, device: *Device, opt_last_used_fence_value: ?u64) void {
        if (opt_last_used_fence_value) |last_used_fence_value| {
            device.queueOperation(
                last_used_fence_value,
                .{ .release = @ptrCast(resource.d3d_resource) },
            );
        } else {
            const d3d_resource = resource.d3d_resource;
            _ = d3d_resource.lpVtbl.*.Release.?(d3d_resource);
        }
    }
};

pub const Buffer = struct {
    manager: utils.Manager(Buffer) = .{},
    last_used_fence_value: u64 = 0,
    device: *Device,
    resource: Resource,
    stage_buffer: ?*Buffer,
    size: usize,
    map: ?[*]u8,

    pub fn init(device: *Device, desc: *const dgpu.Buffer.Descriptor) !*Buffer {
        var hr: c.HRESULT = undefined;

        var resource = try device.createD3dBuffer(desc.usage, desc.size);
        errdefer resource.deinit(device, null);

        // Mapped at Creation
        var stage_buffer: ?*Buffer = null;
        var map: ?*anyopaque = null;
        if (desc.mapped_at_creation == .true) {
            var map_resource: *c.ID3D12Resource = undefined;
            if (!desc.usage.map_write) {
                stage_buffer = try Buffer.init(device, &.{
                    .usage = .{ .copy_src = true, .map_write = true },
                    .size = desc.size,
                });
                map_resource = stage_buffer.?.resource.d3d_resource;
            } else {
                map_resource = resource.d3d_resource;
            }

            // TODO - map status in callback instead of failure
            hr = map_resource.lpVtbl.*.Map.?(map_resource, 0, null, &map);
            if (hr != c.S_OK) {
                return error.MapFailed;
            }
        }

        // Result
        var buffer = try allocator.create(Buffer);
        buffer.* = .{
            .device = device,
            .resource = resource,
            .stage_buffer = stage_buffer,
            .size = desc.size,
            .map = @ptrCast(map),
        };
        return buffer;
    }

    pub fn deinit(buffer: *Buffer) void {
        if (buffer.stage_buffer) |stage_buffer| stage_buffer.manager.release();
        buffer.resource.deinit(buffer.device, buffer.last_used_fence_value);
        allocator.destroy(buffer);
    }

    pub fn getMappedRange(buffer: *Buffer, offset: usize, size: usize) !?*anyopaque {
        return @ptrCast(buffer.map.?[offset .. offset + size]);
    }

    pub fn mapAsync(
        buffer: *Buffer,
        mode: dgpu.MapModeFlags,
        offset: usize,
        size: usize,
        callback: dgpu.Buffer.MapCallback,
        userdata: ?*anyopaque,
    ) !void {
        _ = size;
        _ = offset;
        _ = mode;

        buffer.device.queueOperation(
            buffer.last_used_fence_value,
            .{ .map_callback = .{ .buffer = buffer, .callback = callback, .userdata = userdata } },
        );
    }

    pub fn unmap(buffer: *Buffer) !void {
        var map_resource: *c.ID3D12Resource = undefined;
        if (buffer.stage_buffer) |stage_buffer| {
            map_resource = stage_buffer.resource.d3d_resource;
            const encoder = try buffer.device.queue.getCommandEncoder();
            try encoder.copyBufferToBuffer(stage_buffer, 0, buffer, 0, buffer.size);
            stage_buffer.manager.release();
            buffer.stage_buffer = null;
        } else {
            map_resource = buffer.resource.d3d_resource;
        }
        map_resource.lpVtbl.*.Unmap.?(map_resource, 0, null);
    }

    pub fn mapBeforeCallback(buffer: *Buffer) !void {
        const d3d_resource = buffer.resource.d3d_resource;
        var hr: c.HRESULT = undefined;

        var map: ?*anyopaque = null;
        hr = d3d_resource.lpVtbl.*.Map.?(d3d_resource, 0, null, &map);
        if (hr != c.S_OK) {
            return error.MapFailed;
        }

        buffer.map = @ptrCast(map);
    }
};

pub const Texture = struct {
    manager: utils.Manager(Texture) = .{},
    last_used_fence_value: u64 = 0,
    device: *Device,
    resource: Resource,

    pub fn init(device: *Device, desc: *const dgpu.Texture.Descriptor) !*Texture {
        const d3d_device = device.d3d_device;
        var hr: c.HRESULT = undefined;

        const heap_properties = c.D3D12_HEAP_PROPERTIES{
            .Type = c.D3D12_HEAP_TYPE_DEFAULT,
            .CPUPageProperty = c.D3D12_CPU_PAGE_PROPERTY_UNKNOWN,
            .MemoryPoolPreference = c.D3D12_MEMORY_POOL_UNKNOWN,
            .CreationNodeMask = 1,
            .VisibleNodeMask = 1,
        };
        const resource_desc = c.D3D12_RESOURCE_DESC{
            .Dimension = conv.d3d12ResourceDimension(desc.dimension),
            .Alignment = 0,
            .Width = desc.size.width,
            .Height = desc.size.height,
            .DepthOrArraySize = @intCast(desc.size.depth_or_array_layers),
            .MipLevels = @intCast(desc.mip_level_count),
            .Format = conv.dxgiFormatForTextureResource(desc.format, desc.usage, desc.view_format_count),
            .SampleDesc = .{ .Count = desc.sample_count, .Quality = 0 },
            .Layout = c.D3D12_TEXTURE_LAYOUT_UNKNOWN,
            .Flags = conv.d3d12ResourceFlagsForTexture(desc.usage, desc.format),
        };
        const read_state = conv.d3d12ResourceStatesForTextureRead(desc.usage);
        const initial_state = c.D3D12_RESOURCE_STATE_COMMON;

        const clear_value = c.D3D12_CLEAR_VALUE{ .Format = resource_desc.Format };

        var d3d_resource: *c.ID3D12Resource = undefined;
        hr = d3d_device.lpVtbl.*.CreateCommittedResource.?(
            d3d_device,
            &heap_properties,
            c.D3D12_HEAP_FLAG_CREATE_NOT_ZEROED,
            &resource_desc,
            initial_state,
            &clear_value,
            &c.IID_ID3D12Resource,
            @ptrCast(&d3d_resource),
        );
        if (hr != c.S_OK) {
            return error.CreateFailed;
        }
        errdefer _ = d3d_resource.lpVtbl.*.Release.?(d3d_resource);

        // Result
        var texture = try allocator.create(Texture);
        texture.* = .{
            .device = device,
            .resource = Resource.init(d3d_resource, read_state, initial_state),
        };
        return texture;
    }

    pub fn initForSwapChain(device: *Device, d3d_resource: *c.ID3D12Resource) !*Texture {
        const read_state = c.D3D12_RESOURCE_STATE_PRESENT;
        const initial_state = c.D3D12_RESOURCE_STATE_COMMON;

        var texture = try allocator.create(Texture);
        texture.* = .{
            .device = device,
            .resource = Resource.init(d3d_resource, read_state, initial_state),
        };
        return texture;
    }

    pub fn deinit(texture: *Texture) void {
        texture.resource.deinit(texture.device, texture.last_used_fence_value);
        allocator.destroy(texture);
    }

    pub fn createView(texture: *Texture, desc: ?*const dgpu.TextureView.Descriptor) !*TextureView {
        return TextureView.init(texture, desc);
    }
};

pub const TextureView = struct {
    manager: utils.Manager(TextureView) = .{},
    texture: *Texture,
    width: u32,
    height: u32,
    subresource: u32 = 0, // base subresource index for MSAA resolves

    pub fn init(texture: *Texture, opt_desc: ?*const dgpu.TextureView.Descriptor) !*TextureView {
        // TODO
        _ = opt_desc;

        const d3d_resource = texture.resource.d3d_resource;
        var d3d_desc: c.D3D12_RESOURCE_DESC = undefined;
        _ = d3d_resource.lpVtbl.*.GetDesc.?(d3d_resource, &d3d_desc);

        texture.manager.reference();

        var view = try allocator.create(TextureView);
        view.* = .{
            .texture = texture,
            .width = @intCast(d3d_desc.Width),
            .height = @intCast(d3d_desc.Height),
        };
        return view;
    }

    pub fn deinit(view: *TextureView) void {
        view.texture.manager.release();
        allocator.destroy(view);
    }
};

pub const Sampler = struct {
    manager: utils.Manager(Sampler) = .{},
    d3d_desc: c.D3D12_SAMPLER_DESC,

    pub fn init(device: *Device, desc: *const dgpu.Sampler.Descriptor) !*Sampler {
        _ = desc;
        _ = device;
        unreachable;
    }

    pub fn deinit(sampler: *Sampler) void {
        _ = sampler;
        unreachable;
    }
};

pub const BindGroupLayout = struct {
    const Entry = struct {
        binding: u32,
        visibility: dgpu.ShaderStageFlags,
        buffer: dgpu.Buffer.BindingLayout = .{},
        sampler: dgpu.Sampler.BindingLayout = .{},
        texture: dgpu.Texture.BindingLayout = .{},
        storage_texture: dgpu.StorageTextureBindingLayout = .{},
        range_type: c.D3D12_DESCRIPTOR_RANGE_TYPE,
        table_index: u32,
    };

    manager: utils.Manager(BindGroupLayout) = .{},
    entries: std.ArrayListUnmanaged(Entry),

    pub fn init(device: *Device, descriptor: *const dgpu.BindGroupLayout.Descriptor) !*BindGroupLayout {
        _ = device;

        var entries = std.ArrayListUnmanaged(Entry){};
        errdefer entries.deinit(allocator);

        for (0..descriptor.entry_count) |entry_index| {
            const entry = descriptor.entries.?[entry_index];

            try entries.append(allocator, .{
                .binding = entry.binding,
                .visibility = entry.visibility,
                .buffer = entry.buffer,
                .sampler = entry.sampler,
                .texture = entry.texture,
                .storage_texture = entry.storage_texture,
                .range_type = conv.d3d12DescriptorRangeType(entry),
                .table_index = @intCast(entry_index),
            });
        }

        var layout = try allocator.create(BindGroupLayout);
        layout.* = .{
            .entries = entries,
        };
        return layout;
    }

    pub fn deinit(layout: *BindGroupLayout) void {
        layout.entries.deinit(allocator);
        allocator.destroy(layout);
    }

    // Internal
    pub fn getEntry(layout: *BindGroupLayout, binding: u32) ?*const Entry {
        for (layout.entries.items) |*entry| {
            if (entry.binding == binding)
                return entry;
        }

        return null;
    }
};

pub const BindGroup = struct {
    const ResourceAccess = struct {
        resource: *Resource,
        uav: bool,
    };

    manager: utils.Manager(BindGroup) = .{},
    last_used_fence_value: u64 = 0,
    device: *Device,
    allocation: DescriptorAllocation,
    table: c.D3D12_GPU_DESCRIPTOR_HANDLE,
    buffers: std.ArrayListUnmanaged(*Buffer),
    textures: std.ArrayListUnmanaged(*Texture),
    accesses: std.ArrayListUnmanaged(ResourceAccess),

    pub fn init(device: *Device, desc: *const dgpu.BindGroup.Descriptor) !*BindGroup {
        const d3d_device = device.d3d_device;

        const layout: *BindGroupLayout = @ptrCast(@alignCast(desc.layout));

        const allocation = try device.general_heap.alloc();
        const table = device.general_heap.gpuDescriptor(allocation.index);

        var buffers = std.ArrayListUnmanaged(*Buffer){};
        errdefer buffers.deinit(allocator);

        var textures = std.ArrayListUnmanaged(*Texture){};
        errdefer textures.deinit(allocator);

        var accesses = std.ArrayListUnmanaged(ResourceAccess){};
        errdefer accesses.deinit(allocator);

        for (0..desc.entry_count) |i| {
            const entry = desc.entries.?[i];
            const layout_entry = layout.getEntry(entry.binding) orelse return error.UnknownBinding;
            var dest_descriptor = device.general_heap.cpuDescriptor(allocation.index + layout_entry.table_index);

            if (layout_entry.buffer.type != .undefined) {
                const buffer: *Buffer = @ptrCast(@alignCast(entry.buffer.?));
                const d3d_resource = buffer.resource.d3d_resource;

                try buffers.append(allocator, buffer);

                switch (layout_entry.buffer.type) {
                    .undefined => unreachable,
                    .uniform => {
                        try accesses.append(allocator, .{ .resource = &buffer.resource, .uav = false });

                        const cbv_desc: c.D3D12_CONSTANT_BUFFER_VIEW_DESC = .{
                            .BufferLocation = d3d_resource.lpVtbl.*.GetGPUVirtualAddress.?(d3d_resource) + entry.offset,
                            .SizeInBytes = @intCast(utils.alignUp(entry.size, 256)),
                        };

                        d3d_device.lpVtbl.*.CreateConstantBufferView.?(
                            d3d_device,
                            &cbv_desc,
                            dest_descriptor,
                        );
                    },
                    .storage => {
                        try accesses.append(allocator, .{ .resource = &buffer.resource, .uav = true });

                        // TODO - switch to RWByteAddressBuffer after using DXC
                        const stride = entry.elem_size;
                        const uav_desc: c.D3D12_UNORDERED_ACCESS_VIEW_DESC = .{
                            .Format = c.DXGI_FORMAT_UNKNOWN,
                            .ViewDimension = c.D3D12_UAV_DIMENSION_BUFFER,
                            .unnamed_0 = .{
                                .Buffer = .{
                                    .FirstElement = @intCast(entry.offset / stride),
                                    .NumElements = @intCast(entry.size / stride),
                                    .StructureByteStride = stride,
                                    .CounterOffsetInBytes = 0,
                                    .Flags = 0,
                                },
                            },
                        };

                        d3d_device.lpVtbl.*.CreateUnorderedAccessView.?(
                            d3d_device,
                            d3d_resource,
                            null,
                            &uav_desc,
                            dest_descriptor,
                        );
                    },
                    .read_only_storage => {
                        try accesses.append(allocator, .{ .resource = &buffer.resource, .uav = false });

                        // TODO - switch to ByteAddressBuffer after using DXC
                        const stride = entry.elem_size;
                        const srv_desc: c.D3D12_SHADER_RESOURCE_VIEW_DESC = .{
                            .Format = c.DXGI_FORMAT_UNKNOWN,
                            .ViewDimension = c.D3D12_SRV_DIMENSION_BUFFER,
                            .Shader4ComponentMapping = c.D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING,
                            .unnamed_0 = .{
                                .Buffer = .{
                                    .FirstElement = @intCast(entry.offset / stride),
                                    .NumElements = @intCast(entry.size / stride),
                                    .StructureByteStride = stride,
                                    .Flags = 0,
                                },
                            },
                        };

                        d3d_device.lpVtbl.*.CreateShaderResourceView.?(
                            d3d_device,
                            d3d_resource,
                            &srv_desc,
                            dest_descriptor,
                        );
                    },
                }
            } else if (layout_entry.sampler.type != .undefined) {
                const sampler: *Sampler = @ptrCast(@alignCast(entry.sampler.?));

                d3d_device.lpVtbl.*.CreateSampler.?(
                    d3d_device,
                    &sampler.d3d_desc,
                    dest_descriptor,
                );
            } else if (layout_entry.texture.sample_type != .undefined) {
                const texture_view: *TextureView = @ptrCast(@alignCast(entry.texture_view.?));
                const d3d_resource = texture_view.texture.resource.d3d_resource;

                try textures.append(allocator, texture_view.texture);
                try accesses.append(allocator, .{ .resource = &texture_view.texture.resource, .uav = false });

                const srv_desc: c.D3D12_SHADER_RESOURCE_VIEW_DESC = .{}; // TODO

                d3d_device.lpVtbl.*.CreateShaderResourceView.?(
                    d3d_device,
                    d3d_resource,
                    &srv_desc,
                    dest_descriptor,
                );
            } else if (layout_entry.storage_texture.access != .undefined) {
                const texture_view: *TextureView = @ptrCast(@alignCast(entry.texture_view.?));
                const d3d_resource = texture_view.texture.resource.d3d_resource;

                try textures.append(allocator, texture_view.texture);
                try accesses.append(allocator, .{ .resource = &texture_view.texture.resource, .uav = true });

                const uav_desc: c.D3D12_UNORDERED_ACCESS_VIEW_DESC = .{}; // TODO

                d3d_device.lpVtbl.*.CreateUnorderedAccessView.?(
                    d3d_device,
                    d3d_resource,
                    null,
                    &uav_desc,
                    dest_descriptor,
                );
            }
        }

        var group = try allocator.create(BindGroup);
        group.* = .{
            .device = device,
            .allocation = allocation,
            .table = table,
            .buffers = buffers,
            .textures = textures,
            .accesses = accesses,
        };
        return group;
    }

    pub fn deinit(group: *BindGroup) void {
        group.device.general_heap.free(group.allocation, group.last_used_fence_value);
        for (group.buffers.items) |buffer| buffer.manager.release();
        for (group.textures.items) |texture| texture.manager.release();

        group.buffers.deinit(allocator);
        group.textures.deinit(allocator);
        group.accesses.deinit(allocator);
        allocator.destroy(group);
    }
};

pub const PipelineLayout = struct {
    pub const Function = struct {
        stage: dgpu.ShaderStageFlags,
        shader_module: *ShaderModule,
        entry_point: [*:0]const u8,
    };

    manager: utils.Manager(PipelineLayout) = .{},
    root_signature: *c.ID3D12RootSignature,
    group_layouts: []*BindGroupLayout,
    group_parameter_indices: std.BoundedArray(u32, limits.max_bind_groups),

    pub fn init(device: *Device, desc: *const dgpu.PipelineLayout.Descriptor) !*PipelineLayout {
        const d3d_device = device.d3d_device;
        var hr: c.HRESULT = undefined;

        // Strategy:
        // - dynamic offsets are not supported yet (will move resources to root descriptors)
        // - bind group is 1 descriptor table
        // - root signature 1.1 hints not supported yet

        var group_layouts = try allocator.alloc(*BindGroupLayout, desc.bind_group_layout_count);
        errdefer allocator.free(group_layouts);

        var group_parameter_indices = std.BoundedArray(u32, limits.max_bind_groups){};

        var parameter_count: u32 = 0;
        var range_count: u32 = 0;
        for (0..desc.bind_group_layout_count) |i| {
            const layout: *BindGroupLayout = @ptrCast(@alignCast(desc.bind_group_layouts.?[i]));
            layout.manager.reference();
            group_layouts[i] = layout;
            group_parameter_indices.appendAssumeCapacity(parameter_count);

            var layout_range_count = layout.entries.items.len;
            if (layout_range_count > 0) {
                parameter_count += 1;
                range_count += @intCast(layout_range_count);
            }
        }

        var parameters = try std.ArrayListUnmanaged(c.D3D12_ROOT_PARAMETER).initCapacity(allocator, parameter_count);
        defer parameters.deinit(allocator);

        var ranges = try std.ArrayListUnmanaged(c.D3D12_DESCRIPTOR_RANGE).initCapacity(allocator, range_count);
        defer ranges.deinit(allocator);

        for (0..desc.bind_group_layout_count) |i| {
            const layout: *BindGroupLayout = group_layouts[i];
            const layout_range_base = ranges.items.len;
            for (layout.entries.items) |entry| {
                ranges.appendAssumeCapacity(.{
                    .RangeType = entry.range_type,
                    .NumDescriptors = 1,
                    .BaseShaderRegister = entry.binding,
                    .RegisterSpace = 0,
                    .OffsetInDescriptorsFromTableStart = c.D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND,
                });
            }
            const layout_range_count = ranges.items.len - layout_range_base;
            if (layout_range_count > 0) {
                parameters.appendAssumeCapacity(.{
                    .ParameterType = c.D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE,
                    .unnamed_0 = .{
                        .DescriptorTable = .{
                            .NumDescriptorRanges = @intCast(layout_range_count),
                            .pDescriptorRanges = &ranges.items[layout_range_base],
                        },
                    },
                    .ShaderVisibility = c.D3D12_SHADER_VISIBILITY_ALL,
                });
            }
        }

        var root_signature_blob: *c.ID3DBlob = undefined;
        hr = c.D3D12SerializeRootSignature(
            &c.D3D12_ROOT_SIGNATURE_DESC{
                .NumParameters = @intCast(parameters.items.len),
                .pParameters = parameters.items.ptr,
                .NumStaticSamplers = 0,
                .pStaticSamplers = null,
                .Flags = c.D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT, // TODO - would like a flag for this
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

        // Result
        var layout = try allocator.create(PipelineLayout);
        layout.* = .{
            .root_signature = root_signature,
            .group_layouts = group_layouts,
            .group_parameter_indices = group_parameter_indices,
        };
        return layout;
    }

    pub fn initDefault(device: *Device, default_pipeline_layout: utils.DefaultPipelineLayoutDescriptor) !*PipelineLayout {
        const groups = default_pipeline_layout.groups;
        var bind_group_layouts = std.BoundedArray(*dgpu.BindGroupLayout, limits.max_bind_groups){};
        defer {
            for (bind_group_layouts.slice()) |bind_group_layout| bind_group_layout.release();
        }

        for (groups.slice()) |entries| {
            const bind_group_layout = try device.createBindGroupLayout(
                &dgpu.BindGroupLayout.Descriptor.init(.{ .entries = entries.items }),
            );
            bind_group_layouts.appendAssumeCapacity(@ptrCast(bind_group_layout));
        }

        return device.createPipelineLayout(
            &dgpu.PipelineLayout.Descriptor.init(.{ .bind_group_layouts = bind_group_layouts.slice() }),
        );
    }

    pub fn deinit(layout: *PipelineLayout) void {
        const root_signature = layout.root_signature;

        for (layout.group_layouts) |group_layout| group_layout.manager.release();

        _ = root_signature.lpVtbl.*.Release.?(root_signature);
        allocator.free(layout.group_layouts);
        allocator.destroy(layout);
    }
};

pub const ShaderModule = struct {
    manager: utils.Manager(ShaderModule) = .{},
    air: *shader.Air,
    code: []const u8,

    pub fn initAir(device: *Device, air: *shader.Air) !*ShaderModule {
        _ = device;

        const code = shader.CodeGen.generate(allocator, air, .hlsl, .{ .emit_source_file = "" }) catch unreachable;

        var module = try allocator.create(ShaderModule);
        module.* = .{
            .air = air,
            .code = code,
        };
        return module;
    }

    pub fn deinit(shader_module: *ShaderModule) void {
        shader_module.air.deinit(allocator);
        allocator.free(shader_module.code);
        allocator.destroy(shader_module.air);
        allocator.destroy(shader_module);
    }

    // Internal
    pub fn compile(module: *ShaderModule, entrypoint: [*:0]const u8, target: [*:0]const u8) !*c.ID3DBlob {
        var hr: c.HRESULT = undefined;

        var flags: u32 = 0;
        if (debug_enabled)
            flags |= c.D3DCOMPILE_DEBUG | c.D3DCOMPILE_SKIP_OPTIMIZATION;

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
            flags,
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
};

pub const ComputePipeline = struct {
    manager: utils.Manager(ComputePipeline) = .{},
    last_used_fence_value: u64 = 0,
    device: *Device,
    d3d_pipeline: *c.ID3D12PipelineState,
    layout: *PipelineLayout,

    pub fn init(device: *Device, desc: *const dgpu.ComputePipeline.Descriptor) !*ComputePipeline {
        const d3d_device = device.d3d_device;
        var hr: c.HRESULT = undefined;

        // Shaders
        const compute_module: *ShaderModule = @ptrCast(@alignCast(desc.compute.module));
        const compute_shader = try compute_module.compile(desc.compute.entry_point, "cs_5_1");
        defer _ = compute_shader.lpVtbl.*.Release.?(compute_shader);

        // Pipeline Layout
        var layout: *PipelineLayout = undefined;
        if (desc.layout) |l| {
            layout = @ptrCast(@alignCast(l));
            layout.manager.reference();
        } else {
            var layout_desc = utils.DefaultPipelineLayoutDescriptor.init(allocator);
            defer layout_desc.deinit();

            try layout_desc.addFunction(compute_module.air, .{ .compute = true }, desc.compute.entry_point);
            layout = try PipelineLayout.initDefault(device, layout_desc);
        }

        // PSO
        var d3d_pipeline: *c.ID3D12PipelineState = undefined;
        hr = d3d_device.lpVtbl.*.CreateComputePipelineState.?(
            d3d_device,
            &c.D3D12_COMPUTE_PIPELINE_STATE_DESC{
                .pRootSignature = layout.root_signature,
                .CS = conv.d3d12ShaderBytecode(compute_shader),
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
        var pipeline = try allocator.create(ComputePipeline);
        pipeline.* = .{
            .device = device,
            .d3d_pipeline = d3d_pipeline,
            .layout = layout,
        };
        return pipeline;
    }

    pub fn deinit(pipeline: *ComputePipeline) void {
        const d3d_pipeline = pipeline.d3d_pipeline;

        pipeline.layout.manager.release();
        pipeline.device.queueOperation(
            pipeline.last_used_fence_value,
            .{ .release = @ptrCast(d3d_pipeline) },
        );
        allocator.destroy(pipeline);
    }

    pub fn getBindGroupLayout(pipeline: *ComputePipeline, group_index: u32) *BindGroupLayout {
        return @ptrCast(pipeline.layout.group_layouts[group_index]);
    }
};

pub const RenderPipeline = struct {
    manager: utils.Manager(RenderPipeline) = .{},
    last_used_fence_value: u64 = 0,
    device: *Device,
    d3d_pipeline: *c.ID3D12PipelineState,
    layout: *PipelineLayout,
    topology: c.D3D12_PRIMITIVE_TOPOLOGY_TYPE,
    vertex_strides: std.BoundedArray(c.UINT, limits.max_vertex_buffers),

    pub fn init(device: *Device, desc: *const dgpu.RenderPipeline.Descriptor) !*RenderPipeline {
        const d3d_device = device.d3d_device;
        var hr: c.HRESULT = undefined;

        // Shaders
        const vertex_module: *ShaderModule = @ptrCast(@alignCast(desc.vertex.module));
        const vertex_shader = try vertex_module.compile(desc.vertex.entry_point, "vs_5_1");
        defer _ = vertex_shader.lpVtbl.*.Release.?(vertex_shader);

        var opt_pixel_shader: ?*c.ID3DBlob = null;
        if (desc.fragment) |frag| {
            const frag_module: *ShaderModule = @ptrCast(@alignCast(frag.module));
            opt_pixel_shader = try frag_module.compile(frag.entry_point, "ps_5_1");
        }
        defer if (opt_pixel_shader) |pixel_shader| {
            _ = pixel_shader.lpVtbl.*.Release.?(pixel_shader);
        };

        // Pipeline Layout
        var layout: *PipelineLayout = undefined;
        if (desc.layout) |l| {
            layout = @ptrCast(@alignCast(l));
            layout.manager.reference();
        } else {
            var layout_desc = utils.DefaultPipelineLayoutDescriptor.init(allocator);
            defer layout_desc.deinit();

            try layout_desc.addFunction(vertex_module.air, .{ .vertex = true }, desc.vertex.entry_point);
            if (desc.fragment) |frag| {
                const frag_module: *ShaderModule = @ptrCast(@alignCast(frag.module));
                try layout_desc.addFunction(frag_module.air, .{ .fragment = true }, frag.entry_point);
            }
            layout = try PipelineLayout.initDefault(device, layout_desc);
        }

        // PSO
        var input_elements = std.BoundedArray(c.D3D12_INPUT_ELEMENT_DESC, limits.max_vertex_buffers){};
        var vertex_strides = std.BoundedArray(c.UINT, limits.max_vertex_buffers){};
        for (0..desc.vertex.buffer_count) |i| {
            const buffer = desc.vertex.buffers.?[i];
            for (0..buffer.attribute_count) |j| {
                const attr = buffer.attributes.?[j];
                input_elements.appendAssumeCapacity(conv.d3d12InputElementDesc(i, buffer, attr));
            }
            vertex_strides.appendAssumeCapacity(@intCast(buffer.array_stride));
        }

        var num_render_targets: usize = 0;
        var rtv_formats = [_]c.DXGI_FORMAT{c.DXGI_FORMAT_UNKNOWN} ** limits.max_color_attachments;
        if (desc.fragment) |frag| {
            num_render_targets = frag.target_count;
            for (0..frag.target_count) |i| {
                const target = frag.targets.?[i];
                rtv_formats[i] = conv.dxgiFormatForTexture(target.format);
            }
        }

        var d3d_pipeline: *c.ID3D12PipelineState = undefined;
        hr = d3d_device.lpVtbl.*.CreateGraphicsPipelineState.?(
            d3d_device,
            &c.D3D12_GRAPHICS_PIPELINE_STATE_DESC{
                .pRootSignature = layout.root_signature,
                .VS = conv.d3d12ShaderBytecode(vertex_shader),
                .PS = conv.d3d12ShaderBytecode(opt_pixel_shader),
                .DS = conv.d3d12ShaderBytecode(null),
                .HS = conv.d3d12ShaderBytecode(null),
                .GS = conv.d3d12ShaderBytecode(null),
                .StreamOutput = conv.d3d12StreamOutputDesc(),
                .BlendState = conv.d3d12BlendDesc(desc),
                .SampleMask = desc.multisample.mask,
                .RasterizerState = conv.d3d12RasterizerDesc(desc),
                .DepthStencilState = conv.d3d12DepthStencilDesc(desc.depth_stencil),
                .InputLayout = .{
                    .pInputElementDescs = if (desc.vertex.buffer_count > 0) &input_elements.buffer else null,
                    .NumElements = @intCast(input_elements.len),
                },
                .IBStripCutValue = conv.d3d12IndexBufferStripCutValue(desc.primitive.strip_index_format),
                .PrimitiveTopologyType = conv.d3d12PrimitiveTopologyType(desc.primitive.topology),
                .NumRenderTargets = @intCast(num_render_targets),
                .RTVFormats = rtv_formats,
                .DSVFormat = if (desc.depth_stencil) |ds| conv.dxgiFormatForTexture(ds.format) else c.DXGI_FORMAT_UNKNOWN,
                .SampleDesc = .{ .Count = desc.multisample.count, .Quality = 0 },
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
        var pipeline = try allocator.create(RenderPipeline);
        pipeline.* = .{
            .d3d_pipeline = d3d_pipeline,
            .device = device,
            .layout = layout,
            .topology = conv.d3d12PrimitiveTopology(desc.primitive.topology),
            .vertex_strides = vertex_strides,
        };
        return pipeline;
    }

    pub fn deinit(pipeline: *RenderPipeline) void {
        const d3d_pipeline = pipeline.d3d_pipeline;

        pipeline.layout.manager.release();
        pipeline.device.queueOperation(
            pipeline.last_used_fence_value,
            .{ .release = @ptrCast(d3d_pipeline) },
        );
        allocator.destroy(pipeline);
    }

    pub fn getBindGroupLayout(pipeline: *RenderPipeline, group_index: u32) *BindGroupLayout {
        return @ptrCast(pipeline.layout.group_layouts[group_index]);
    }
};

pub const CommandBuffer = struct {
    pub const StreamingResult = struct {
        d3d_resource: *c.ID3D12Resource,
        map: [*]u8,
        offset: u32,
    };

    manager: utils.Manager(CommandBuffer) = .{},
    device: *Device,
    command_allocator: *c.ID3D12CommandAllocator,
    command_list: *c.ID3D12GraphicsCommandList,
    reference_tracker: ReferenceTracker = .{},
    rtv_allocation: DescriptorAllocation = .{ .index = 0 },
    rtv_next_index: u32 = rtv_block_size,
    upload_buffer: ?*c.ID3D12Resource = null,
    upload_map: ?[*]u8 = null,
    upload_next_offset: u32 = upload_page_size,

    pub fn init(device: *Device) !*CommandBuffer {
        const command_allocator = try device.command_manager.createCommandAllocator();
        const command_list = try device.command_manager.createCommandList(command_allocator);

        const heaps = [2]*c.ID3D12DescriptorHeap{ device.general_heap.d3d_heap, device.sampler_heap.d3d_heap };
        command_list.lpVtbl.*.SetDescriptorHeaps.?(
            command_list,
            2,
            &heaps,
        );

        var command_buffer = try allocator.create(CommandBuffer);
        command_buffer.* = .{
            .device = device,
            .command_allocator = command_allocator,
            .command_list = command_list,
        };
        return command_buffer;
    }

    pub fn deinit(command_buffer: *CommandBuffer) void {
        command_buffer.reference_tracker.deinit();
        allocator.destroy(command_buffer);
    }

    // Internal
    pub fn upload(command_buffer: *CommandBuffer, size: u64) !StreamingResult {
        if (command_buffer.upload_next_offset + size > upload_page_size) {
            const streaming_manager = &command_buffer.device.streaming_manager;
            var hr: c.HRESULT = undefined;

            std.debug.assert(size <= upload_page_size); // TODO - support large uploads
            const d3d_resource = try streaming_manager.acquire();

            try command_buffer.reference_tracker.referenceUploadPage(d3d_resource);
            command_buffer.upload_buffer = d3d_resource;

            var map: ?*anyopaque = null;
            hr = d3d_resource.lpVtbl.*.Map.?(d3d_resource, 0, null, &map);
            if (hr != c.S_OK) {
                return error.MapFailed;
            }

            command_buffer.upload_map = @ptrCast(map);
            command_buffer.upload_next_offset = 0;
        }

        const offset = command_buffer.upload_next_offset;
        command_buffer.upload_next_offset = @intCast(utils.alignUp(offset + size, 256));
        return StreamingResult{
            .d3d_resource = command_buffer.upload_buffer.?,
            .map = command_buffer.upload_map.? + offset,
            .offset = offset,
        };
    }

    pub fn allocateRtvDescriptors(command_buffer: *CommandBuffer, count: usize) !c.D3D12_CPU_DESCRIPTOR_HANDLE {
        if (count == 0) return .{ .ptr = 0 };

        var rtv_heap = &command_buffer.device.rtv_heap;

        if (command_buffer.rtv_next_index + count > rtv_block_size) {
            command_buffer.rtv_allocation = try rtv_heap.alloc();

            try command_buffer.reference_tracker.referenceRtvDescriptorBlock(command_buffer.rtv_allocation);
            command_buffer.rtv_next_index = 0;
        }

        const index = command_buffer.rtv_next_index;
        command_buffer.rtv_next_index = @intCast(index + count);
        return rtv_heap.cpuDescriptor(command_buffer.rtv_allocation.index + index);
    }

    pub fn allocateDsvDescriptor(command_buffer: *CommandBuffer) !c.D3D12_CPU_DESCRIPTOR_HANDLE {
        var dsv_heap = &command_buffer.device.dsv_heap;

        const allocation = try dsv_heap.alloc();
        try command_buffer.reference_tracker.referenceDsvDescriptorBlock(allocation);

        return dsv_heap.cpuDescriptor(allocation.index);
    }
};

pub const ReferenceTracker = struct {
    buffers: std.ArrayListUnmanaged(*Buffer) = .{},
    textures: std.ArrayListUnmanaged(*Texture) = .{},
    bind_groups: std.ArrayListUnmanaged(*BindGroup) = .{},
    compute_pipelines: std.ArrayListUnmanaged(*ComputePipeline) = .{},
    render_pipelines: std.ArrayListUnmanaged(*RenderPipeline) = .{},
    rtv_descriptor_blocks: std.ArrayListUnmanaged(DescriptorAllocation) = .{},
    dsv_descriptor_blocks: std.ArrayListUnmanaged(DescriptorAllocation) = .{},
    upload_pages: std.ArrayListUnmanaged(*c.ID3D12Resource) = .{},

    pub fn deinit(tracker: *ReferenceTracker) void {
        tracker.buffers.deinit(allocator);
        tracker.textures.deinit(allocator);
        tracker.bind_groups.deinit(allocator);
        tracker.compute_pipelines.deinit(allocator);
        tracker.render_pipelines.deinit(allocator);
        tracker.rtv_descriptor_blocks.deinit(allocator);
        tracker.dsv_descriptor_blocks.deinit(allocator);
        tracker.upload_pages.deinit(allocator);
    }

    pub fn referenceBuffer(tracker: *ReferenceTracker, buffer: *Buffer) !void {
        buffer.manager.reference();
        try tracker.buffers.append(allocator, buffer);
    }

    pub fn referenceTexture(tracker: *ReferenceTracker, texture: *Texture) !void {
        texture.manager.reference();
        try tracker.textures.append(allocator, texture);
    }

    pub fn referenceBindGroup(tracker: *ReferenceTracker, group: *BindGroup) !void {
        group.manager.reference();
        try tracker.bind_groups.append(allocator, group);
    }

    pub fn referenceComputePipeline(tracker: *ReferenceTracker, pipeline: *ComputePipeline) !void {
        pipeline.manager.reference();
        try tracker.compute_pipelines.append(allocator, pipeline);
    }

    pub fn referenceRenderPipeline(tracker: *ReferenceTracker, pipeline: *RenderPipeline) !void {
        pipeline.manager.reference();
        try tracker.render_pipelines.append(allocator, pipeline);
    }

    pub fn referenceRtvDescriptorBlock(tracker: *ReferenceTracker, block: DescriptorAllocation) !void {
        try tracker.rtv_descriptor_blocks.append(allocator, block);
    }

    pub fn referenceDsvDescriptorBlock(tracker: *ReferenceTracker, block: DescriptorAllocation) !void {
        try tracker.dsv_descriptor_blocks.append(allocator, block);
    }

    pub fn referenceUploadPage(tracker: *ReferenceTracker, upload_page: *c.ID3D12Resource) !void {
        try tracker.upload_pages.append(allocator, upload_page);
    }

    pub fn submit(tracker: *ReferenceTracker, queue: *Queue) void {
        const fence_value = queue.fence_value;

        for (tracker.buffers.items) |buffer| {
            buffer.last_used_fence_value = fence_value;
            buffer.manager.release();
        }

        for (tracker.textures.items) |texture| {
            texture.last_used_fence_value = fence_value;
            texture.manager.release();
        }

        for (tracker.bind_groups.items) |group| {
            group.last_used_fence_value = fence_value;
            for (group.buffers.items) |buffer| buffer.last_used_fence_value = fence_value;
            for (group.textures.items) |texture| texture.last_used_fence_value = fence_value;
            group.manager.release();
        }

        for (tracker.compute_pipelines.items) |pipeline| {
            pipeline.last_used_fence_value = fence_value;
            pipeline.manager.release();
        }

        for (tracker.render_pipelines.items) |pipeline| {
            pipeline.last_used_fence_value = fence_value;
            pipeline.manager.release();
        }

        for (tracker.rtv_descriptor_blocks.items) |block| {
            queue.device.rtv_heap.free(block, fence_value);
        }

        for (tracker.dsv_descriptor_blocks.items) |block| {
            queue.device.dsv_heap.free(block, fence_value);
        }

        for (tracker.upload_pages.items) |d3d_resource| {
            queue.device.queueOperation(
                queue.fence_value,
                .{ .release = @ptrCast(d3d_resource) },
            );
        }
    }
};

pub const CommandEncoder = struct {
    manager: utils.Manager(CommandEncoder) = .{},
    device: *Device,
    command_buffer: *CommandBuffer,
    reference_tracker: *ReferenceTracker,
    state_tracker: StateTracker = .{},

    pub fn init(device: *Device, desc: ?*const dgpu.CommandEncoder.Descriptor) !*CommandEncoder {
        // TODO
        _ = desc;

        const command_buffer = try CommandBuffer.init(device);

        var encoder = try allocator.create(CommandEncoder);
        encoder.* = .{
            .device = device,
            .command_buffer = command_buffer,
            .reference_tracker = &command_buffer.reference_tracker,
        };
        return encoder;
    }

    pub fn deinit(encoder: *CommandEncoder) void {
        encoder.state_tracker.deinit();
        encoder.command_buffer.manager.release();
        allocator.destroy(encoder);
    }

    pub fn beginComputePass(encoder: *CommandEncoder, desc: *const dgpu.ComputePassDescriptor) !*ComputePassEncoder {
        return ComputePassEncoder.init(encoder, desc);
    }

    pub fn beginRenderPass(encoder: *CommandEncoder, desc: *const dgpu.RenderPassDescriptor) !*RenderPassEncoder {
        try encoder.state_tracker.endPass();
        return RenderPassEncoder.init(encoder, desc);
    }

    pub fn copyBufferToBuffer(
        encoder: *CommandEncoder,
        source: *Buffer,
        source_offset: u64,
        destination: *Buffer,
        destination_offset: u64,
        size: u64,
    ) !void {
        const command_list = encoder.command_buffer.command_list;

        try encoder.reference_tracker.referenceBuffer(source);
        try encoder.reference_tracker.referenceBuffer(destination);
        try encoder.state_tracker.transition(&source.resource, source.resource.read_state);
        try encoder.state_tracker.transition(&destination.resource, c.D3D12_RESOURCE_STATE_COPY_DEST);
        encoder.state_tracker.flush(command_list);

        command_list.lpVtbl.*.CopyBufferRegion.?(
            command_list,
            destination.resource.d3d_resource,
            destination_offset,
            source.resource.d3d_resource,
            source_offset,
            size,
        );
    }

    pub fn copyBufferToTexture(
        encoder: *CommandEncoder,
        source: *const dgpu.ImageCopyBuffer,
        destination: *const dgpu.ImageCopyTexture,
        copy_size: *const dgpu.Extent3D,
    ) !void {
        _ = copy_size;
        _ = destination;
        _ = source;
        _ = encoder;
        unreachable;
    }

    pub fn copyTextureToTexture(
        encoder: *CommandEncoder,
        source: *const dgpu.ImageCopyTexture,
        destination: *const dgpu.ImageCopyTexture,
        copy_size: *const dgpu.Extent3D,
    ) !void {
        _ = copy_size;
        _ = destination;
        _ = source;
        _ = encoder;
    }

    pub fn finish(encoder: *CommandEncoder, desc: *const dgpu.CommandBuffer.Descriptor) !*CommandBuffer {
        // TODO
        _ = desc;

        const command_list = encoder.command_buffer.command_list;
        var hr: c.HRESULT = undefined;

        try encoder.state_tracker.endPass();
        encoder.state_tracker.flush(command_list);

        hr = command_list.lpVtbl.*.Close.?(command_list);
        if (hr != c.S_OK) {
            return error.CommandEncoderFinish;
        }

        return encoder.command_buffer;
    }

    pub fn writeBuffer(encoder: *CommandEncoder, buffer: *Buffer, offset: u64, data: [*]const u8, size: u64) !void {
        const command_list = encoder.command_buffer.command_list;

        const stream = try encoder.command_buffer.upload(size);
        @memcpy(stream.map[0..size], data[0..size]);

        try encoder.reference_tracker.referenceBuffer(buffer);
        try encoder.state_tracker.transition(&buffer.resource, c.D3D12_RESOURCE_STATE_COPY_DEST);
        encoder.state_tracker.flush(command_list);

        command_list.lpVtbl.*.CopyBufferRegion.?(
            command_list,
            buffer.resource.d3d_resource,
            offset,
            stream.d3d_resource,
            stream.offset,
            size,
        );
    }
};

pub const StateTracker = struct {
    written_set: std.AutoArrayHashMapUnmanaged(*Resource, void) = .{},
    barriers: std.ArrayListUnmanaged(c.D3D12_RESOURCE_BARRIER) = .{},

    pub fn deinit(tracker: *StateTracker) void {
        tracker.written_set.deinit(allocator);
        tracker.barriers.deinit(allocator);
    }

    pub fn transition(tracker: *StateTracker, resource: *Resource, new_state: c.D3D12_RESOURCE_STATES) !void {
        if (resource.current_state == c.D3D12_RESOURCE_STATE_UNORDERED_ACCESS and
            new_state == c.D3D12_RESOURCE_STATE_UNORDERED_ACCESS)
        {
            try tracker.barriers.append(allocator, .{
                .Type = c.D3D12_RESOURCE_BARRIER_TYPE_UAV,
                .Flags = c.D3D12_RESOURCE_BARRIER_FLAG_NONE,
                .unnamed_0 = .{
                    .UAV = .{
                        .pResource = resource.d3d_resource,
                    },
                },
            });
            return;
        }

        if (resource.current_state == new_state)
            return;

        if (new_state != resource.read_state) {
            try tracker.written_set.put(allocator, resource, {});
        }

        try tracker.barriers.append(allocator, .{
            .Type = c.D3D12_RESOURCE_BARRIER_TYPE_TRANSITION,
            .Flags = c.D3D12_RESOURCE_BARRIER_FLAG_NONE,
            .unnamed_0 = .{
                .Transition = .{
                    .pResource = resource.d3d_resource,
                    .Subresource = c.D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES,
                    .StateBefore = resource.current_state,
                    .StateAfter = new_state,
                },
            },
        });
        resource.current_state = new_state;
    }

    pub fn flush(tracker: *StateTracker, command_list: *c.ID3D12GraphicsCommandList) void {
        if (tracker.barriers.items.len > 0) {
            command_list.lpVtbl.*.ResourceBarrier.?(
                command_list,
                @intCast(tracker.barriers.items.len),
                tracker.barriers.items.ptr,
            );

            tracker.barriers.clearRetainingCapacity();
        }
    }

    pub fn endPass(tracker: *StateTracker) !void {
        for (tracker.written_set.keys()) |resource| {
            try tracker.transition(resource, resource.read_state);
        }
        tracker.written_set.clearRetainingCapacity();
    }
};

pub const ComputePassEncoder = struct {
    manager: utils.Manager(ComputePassEncoder) = .{},
    command_list: *c.ID3D12GraphicsCommandList,
    reference_tracker: *ReferenceTracker,
    state_tracker: *StateTracker,
    bind_groups: [limits.max_bind_groups]*BindGroup = undefined,
    group_parameter_indices: []u32 = undefined,

    pub fn init(cmd_encoder: *CommandEncoder, desc: *const dgpu.ComputePassDescriptor) !*ComputePassEncoder {
        _ = desc;
        const command_list = cmd_encoder.command_buffer.command_list;

        var encoder = try allocator.create(ComputePassEncoder);
        encoder.* = .{
            .command_list = command_list,
            .reference_tracker = cmd_encoder.reference_tracker,
            .state_tracker = &cmd_encoder.state_tracker,
        };
        return encoder;
    }

    pub fn deinit(encoder: *ComputePassEncoder) void {
        allocator.destroy(encoder);
    }

    pub fn dispatchWorkgroups(
        encoder: *ComputePassEncoder,
        workgroup_count_x: u32,
        workgroup_count_y: u32,
        workgroup_count_z: u32,
    ) !void {
        const command_list = encoder.command_list;

        const bind_group_count = encoder.group_parameter_indices.len;
        for (encoder.bind_groups[0..bind_group_count]) |group| {
            for (group.accesses.items) |access| {
                if (access.uav) {
                    try encoder.state_tracker.transition(access.resource, c.D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
                } else {
                    try encoder.state_tracker.transition(access.resource, access.resource.read_state);
                }
            }
        }
        encoder.state_tracker.flush(command_list);

        command_list.lpVtbl.*.Dispatch.?(
            command_list,
            workgroup_count_x,
            workgroup_count_y,
            workgroup_count_z,
        );
    }

    pub fn end(encoder: *ComputePassEncoder) void {
        _ = encoder;
    }

    pub fn setBindGroup(
        encoder: *ComputePassEncoder,
        group_index: u32,
        group: *BindGroup,
        dynamic_offset_count: usize,
        dynamic_offsets: ?[*]const u32,
    ) !void {
        _ = dynamic_offsets;
        _ = dynamic_offset_count;

        const command_list = encoder.command_list;

        try encoder.reference_tracker.referenceBindGroup(group);
        encoder.bind_groups[group_index] = group;

        const group_parameter_index = encoder.group_parameter_indices[group_index];
        command_list.lpVtbl.*.SetComputeRootDescriptorTable.?(
            command_list,
            @intCast(group_parameter_index),
            group.table,
        );
    }

    pub fn setPipeline(encoder: *ComputePassEncoder, pipeline: *ComputePipeline) !void {
        const command_list = encoder.command_list;

        try encoder.reference_tracker.referenceComputePipeline(pipeline);

        encoder.group_parameter_indices = pipeline.layout.group_parameter_indices.slice();

        command_list.lpVtbl.*.SetComputeRootSignature.?(
            command_list,
            pipeline.layout.root_signature,
        );

        command_list.lpVtbl.*.SetPipelineState.?(
            command_list,
            pipeline.d3d_pipeline,
        );
    }
};

pub const RenderPassEncoder = struct {
    manager: utils.Manager(RenderPassEncoder) = .{},
    command_list: *c.ID3D12GraphicsCommandList,
    reference_tracker: *ReferenceTracker,
    state_tracker: *StateTracker,
    color_attachments: std.BoundedArray(dgpu.RenderPassColorAttachment, limits.max_color_attachments) = .{},
    depth_attachment: ?dgpu.RenderPassDepthStencilAttachment,
    group_parameter_indices: []u32 = undefined,
    vertex_apply_count: u32 = 0,
    vertex_buffer_views: [limits.max_vertex_buffers]c.D3D12_VERTEX_BUFFER_VIEW,
    vertex_strides: []c.UINT = undefined,

    pub fn init(cmd_encoder: *CommandEncoder, desc: *const dgpu.RenderPassDescriptor) !*RenderPassEncoder {
        const d3d_device = cmd_encoder.device.d3d_device;
        const command_list = cmd_encoder.command_buffer.command_list;

        var width: u32 = 0;
        var height: u32 = 0;
        var color_attachments: std.BoundedArray(dgpu.RenderPassColorAttachment, limits.max_color_attachments) = .{};
        var rtv_handles = try cmd_encoder.command_buffer.allocateRtvDescriptors(desc.color_attachment_count);
        var descriptor_size = cmd_encoder.device.rtv_heap.descriptor_size;

        var rtv_handle = rtv_handles;
        for (0..desc.color_attachment_count) |i| {
            const attach = desc.color_attachments.?[i];
            const view: *TextureView = @ptrCast(@alignCast(attach.view.?));
            const texture = view.texture;

            try cmd_encoder.reference_tracker.referenceTexture(texture);
            try cmd_encoder.state_tracker.transition(&texture.resource, c.D3D12_RESOURCE_STATE_RENDER_TARGET);

            width = view.width;
            height = view.height;
            color_attachments.appendAssumeCapacity(attach);

            d3d_device.lpVtbl.*.CreateRenderTargetView.?(
                d3d_device,
                texture.resource.d3d_resource,
                null,
                rtv_handle,
            );

            rtv_handle.ptr += descriptor_size;
        }

        var depth_attachment: ?dgpu.RenderPassDepthStencilAttachment = null;
        var dsv_handle: c.D3D12_CPU_DESCRIPTOR_HANDLE = .{ .ptr = 0 };

        if (desc.depth_stencil_attachment) |attach| {
            const view: *TextureView = @ptrCast(@alignCast(attach.view));
            const texture = view.texture;

            try cmd_encoder.reference_tracker.referenceTexture(texture);
            try cmd_encoder.state_tracker.transition(&texture.resource, c.D3D12_RESOURCE_STATE_DEPTH_WRITE);

            width = view.width;
            height = view.height;
            depth_attachment = attach.*;

            dsv_handle = try cmd_encoder.command_buffer.allocateDsvDescriptor();

            d3d_device.lpVtbl.*.CreateDepthStencilView.?(
                d3d_device,
                texture.resource.d3d_resource,
                null,
                dsv_handle,
            );
        }

        cmd_encoder.state_tracker.flush(command_list);

        command_list.lpVtbl.*.OMSetRenderTargets.?(
            command_list,
            @intCast(desc.color_attachment_count),
            &rtv_handles,
            c.TRUE,
            if (desc.depth_stencil_attachment != null) &dsv_handle else null,
        );

        rtv_handle = rtv_handles;
        for (0..desc.color_attachment_count) |i| {
            const attach = desc.color_attachments.?[i];

            if (attach.load_op == .clear) {
                const clear_color = [4]f32{
                    @floatCast(attach.clear_value.r),
                    @floatCast(attach.clear_value.g),
                    @floatCast(attach.clear_value.b),
                    @floatCast(attach.clear_value.a),
                };
                command_list.lpVtbl.*.ClearRenderTargetView.?(
                    command_list,
                    rtv_handle,
                    &clear_color,
                    0,
                    null,
                );
            }

            rtv_handle.ptr += descriptor_size;
        }

        if (desc.depth_stencil_attachment) |attach| {
            var clear_flags: c.D3D12_CLEAR_FLAGS = 0;

            if (attach.depth_load_op == .clear)
                clear_flags |= c.D3D12_CLEAR_FLAG_DEPTH;
            if (attach.stencil_load_op == .clear)
                clear_flags |= c.D3D12_CLEAR_FLAG_STENCIL;

            if (clear_flags != 0) {
                command_list.lpVtbl.*.ClearDepthStencilView.?(
                    command_list,
                    dsv_handle,
                    clear_flags,
                    attach.depth_clear_value,
                    @intCast(attach.stencil_clear_value),
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
            .color_attachments = color_attachments,
            .depth_attachment = depth_attachment,
            .reference_tracker = cmd_encoder.reference_tracker,
            .state_tracker = &cmd_encoder.state_tracker,
            .vertex_buffer_views = std.mem.zeroes([limits.max_vertex_buffers]c.D3D12_VERTEX_BUFFER_VIEW),
        };
        return encoder;
    }

    pub fn deinit(encoder: *RenderPassEncoder) void {
        allocator.destroy(encoder);
    }

    pub fn draw(
        encoder: *RenderPassEncoder,
        vertex_count: u32,
        instance_count: u32,
        first_vertex: u32,
        first_instance: u32,
    ) void {
        const command_list = encoder.command_list;

        encoder.applyVertexBuffers();

        command_list.lpVtbl.*.DrawInstanced.?(
            command_list,
            vertex_count,
            instance_count,
            first_vertex,
            first_instance,
        );
    }

    pub fn drawIndexed(
        encoder: *RenderPassEncoder,
        index_count: u32,
        instance_count: u32,
        first_index: u32,
        base_vertex: i32,
        first_instance: u32,
    ) void {
        const command_list = encoder.command_list;

        encoder.applyVertexBuffers();

        command_list.lpVtbl.*.DrawIndexedInstanced.?(
            command_list,
            index_count,
            instance_count,
            first_index,
            base_vertex,
            first_instance,
        );
    }

    pub fn end(encoder: *RenderPassEncoder) !void {
        const command_list = encoder.command_list;

        for (encoder.color_attachments.slice()) |attach| {
            const view: *TextureView = @ptrCast(@alignCast(attach.view.?));

            if (attach.resolve_target) |resolve_target_raw| {
                const resolve_target: *TextureView = @ptrCast(@alignCast(resolve_target_raw));
                try encoder.state_tracker.transition(&view.texture.resource, c.D3D12_RESOURCE_STATE_RESOLVE_SOURCE);
                try encoder.state_tracker.transition(&resolve_target.texture.resource, c.D3D12_RESOURCE_STATE_RESOLVE_DEST);

                encoder.state_tracker.flush(command_list);

                // Format
                const resolve_d3d_resource = resolve_target.texture.resource.d3d_resource;
                const view_d3d_resource = view.texture.resource.d3d_resource;
                var d3d_desc: c.D3D12_RESOURCE_DESC = undefined;

                var format: c.DXGI_FORMAT = undefined;
                _ = resolve_d3d_resource.lpVtbl.*.GetDesc.?(resolve_d3d_resource, &d3d_desc);
                format = d3d_desc.Format;
                if (conv.dxgiFormatIsTypeless(format)) {
                    _ = view_d3d_resource.lpVtbl.*.GetDesc.?(view_d3d_resource, &d3d_desc);
                    format = d3d_desc.Format;
                    if (conv.dxgiFormatIsTypeless(format)) {
                        return error.NoTypedFormat;
                    }
                }

                command_list.lpVtbl.*.ResolveSubresource.?(
                    command_list,
                    resolve_target.texture.resource.d3d_resource,
                    resolve_target.subresource,
                    view.texture.resource.d3d_resource,
                    view.subresource,
                    format,
                );

                try encoder.state_tracker.transition(&resolve_target.texture.resource, resolve_target.texture.resource.read_state);
            }

            try encoder.state_tracker.transition(&view.texture.resource, view.texture.resource.read_state);
        }

        if (encoder.depth_attachment) |attach| {
            const view: *TextureView = @ptrCast(@alignCast(attach.view));

            try encoder.state_tracker.transition(&view.texture.resource, view.texture.resource.read_state);
        }
    }

    pub fn setBindGroup(
        encoder: *RenderPassEncoder,
        group_index: u32,
        group: *BindGroup,
        dynamic_offset_count: usize,
        dynamic_offsets: ?[*]const u32,
    ) !void {
        _ = dynamic_offsets;
        _ = dynamic_offset_count;

        const command_list = encoder.command_list;

        try encoder.reference_tracker.referenceBindGroup(group);

        const group_parameter_index = encoder.group_parameter_indices[group_index];
        command_list.lpVtbl.*.SetGraphicsRootDescriptorTable.?(
            command_list,
            group_parameter_index,
            group.table,
        );
    }

    pub fn setIndexBuffer(
        encoder: *RenderPassEncoder,
        buffer: *Buffer,
        format: dgpu.IndexFormat,
        offset: u64,
        size: u64,
    ) !void {
        const command_list = encoder.command_list;
        const d3d_resource = buffer.resource.d3d_resource;

        try encoder.reference_tracker.referenceBuffer(buffer);

        command_list.lpVtbl.*.IASetIndexBuffer.?(
            command_list,
            &c.D3D12_INDEX_BUFFER_VIEW{
                .BufferLocation = d3d_resource.lpVtbl.*.GetGPUVirtualAddress.?(d3d_resource) + offset,
                .SizeInBytes = @intCast(size),
                .Format = conv.dxgiFormatForIndex(format),
            },
        );
    }

    pub fn setPipeline(encoder: *RenderPassEncoder, pipeline: *RenderPipeline) !void {
        const command_list = encoder.command_list;

        try encoder.reference_tracker.referenceRenderPipeline(pipeline);

        encoder.group_parameter_indices = pipeline.layout.group_parameter_indices.slice();
        encoder.vertex_strides = pipeline.vertex_strides.slice();

        command_list.lpVtbl.*.SetGraphicsRootSignature.?(
            command_list,
            pipeline.layout.root_signature,
        );

        command_list.lpVtbl.*.SetPipelineState.?(
            command_list,
            pipeline.d3d_pipeline,
        );

        command_list.lpVtbl.*.IASetPrimitiveTopology.?(
            command_list,
            pipeline.topology,
        );
    }

    pub fn setScissorRect(encoder: *RenderPassEncoder, x: u32, y: u32, width: u32, height: u32) void {
        _ = height;
        _ = width;
        _ = y;
        _ = x;
        _ = encoder;
        unreachable;
    }

    pub fn setVertexBuffer(encoder: *RenderPassEncoder, slot: u32, buffer: *Buffer, offset: u64, size: u64) !void {
        const d3d_resource = buffer.resource.d3d_resource;
        try encoder.reference_tracker.referenceBuffer(buffer);

        var view = &encoder.vertex_buffer_views[slot];
        view.BufferLocation = d3d_resource.lpVtbl.*.GetGPUVirtualAddress.?(d3d_resource) + offset;
        view.SizeInBytes = @intCast(size);
        // StrideInBytes deferred until draw()

        encoder.vertex_apply_count = @max(encoder.vertex_apply_count, slot + 1);
    }

    pub fn setViewport(encoder: *RenderPassEncoder, x: f32, y: f32, width: f32, height: f32, min_depth: f32, max_depth: f32) void {
        _ = max_depth;
        _ = min_depth;
        _ = height;
        _ = width;
        _ = y;
        _ = x;
        _ = encoder;
        unreachable;
    }

    // Private
    fn applyVertexBuffers(encoder: *RenderPassEncoder) void {
        if (encoder.vertex_apply_count > 0) {
            const command_list = encoder.command_list;

            for (0..encoder.vertex_apply_count) |i| {
                var view = &encoder.vertex_buffer_views[i];
                view.StrideInBytes = encoder.vertex_strides[i];
            }

            command_list.lpVtbl.*.IASetVertexBuffers.?(
                command_list,
                0,
                encoder.vertex_apply_count,
                &encoder.vertex_buffer_views,
            );

            encoder.vertex_apply_count = 0;
        }
    }
};

pub const Queue = struct {
    manager: utils.Manager(Queue) = .{},
    device: *Device,
    d3d_command_queue: *c.ID3D12CommandQueue,
    fence: *c.ID3D12Fence,
    fence_value: u64 = 0,
    fence_event: c.HANDLE,
    command_encoder: ?*CommandEncoder = null,

    pub fn init(device: *Device) !Queue {
        const d3d_device = device.d3d_device;
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
        return .{
            .device = device,
            .d3d_command_queue = d3d_command_queue,
            .fence = fence,
            .fence_event = fence_event,
        };
    }

    pub fn deinit(queue: *Queue) void {
        const d3d_command_queue = queue.d3d_command_queue;
        const fence = queue.fence;

        queue.waitUntil(queue.fence_value);

        if (queue.command_encoder) |command_encoder| command_encoder.manager.release();
        _ = d3d_command_queue.lpVtbl.*.Release.?(d3d_command_queue);
        _ = fence.lpVtbl.*.Release.?(fence);
        _ = c.CloseHandle(queue.fence_event);
    }

    pub fn submit(queue: *Queue, command_buffers: []const *CommandBuffer) !void {
        var command_manager = &queue.device.command_manager;
        const d3d_command_queue = queue.d3d_command_queue;

        var command_lists = try std.ArrayListUnmanaged(*c.ID3D12GraphicsCommandList).initCapacity(
            allocator,
            command_buffers.len + 1,
        );
        defer command_lists.deinit(allocator);

        queue.fence_value += 1;

        if (queue.command_encoder) |command_encoder| {
            const command_buffer = try command_encoder.finish(&.{});
            command_buffer.manager.reference(); // handled in main.zig
            defer command_buffer.manager.release();

            command_lists.appendAssumeCapacity(command_buffer.command_list);
            command_buffer.reference_tracker.submit(queue);
            command_manager.destroyCommandAllocator(command_buffer.command_allocator, queue.fence_value);

            command_encoder.manager.release();
            queue.command_encoder = null;
        }

        for (command_buffers) |command_buffer| {
            command_lists.appendAssumeCapacity(command_buffer.command_list);
            command_buffer.reference_tracker.submit(queue);
            command_manager.destroyCommandAllocator(command_buffer.command_allocator, queue.fence_value);
        }

        d3d_command_queue.lpVtbl.*.ExecuteCommandLists.?(
            d3d_command_queue,
            @intCast(command_lists.items.len),
            @ptrCast(command_lists.items.ptr),
        );

        for (command_lists.items) |command_list| {
            command_manager.destroyCommandList(command_list);
        }

        try queue.signal();
    }

    pub fn writeBuffer(queue: *Queue, buffer: *Buffer, offset: u64, data: [*]const u8, size: u64) !void {
        const encoder = try queue.getCommandEncoder();
        try encoder.writeBuffer(buffer, offset, data, size);
    }

    pub fn writeTexture(
        queue: *Queue,
        destination: *const dgpu.ImageCopyTexture,
        data: [*]const u8,
        data_size: usize,
        data_layout: *const dgpu.Texture.DataLayout,
        write_size: *const dgpu.Extent3D,
    ) !void {
        _ = write_size;
        _ = data_layout;
        _ = data_size;
        _ = data;
        _ = destination;
        _ = queue;
        unreachable;
    }

    // Internal
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

    // Private
    fn getCommandEncoder(queue: *Queue) !*CommandEncoder {
        if (queue.command_encoder) |command_encoder| return command_encoder;

        const command_encoder = try CommandEncoder.init(queue.device, &.{});
        queue.command_encoder = command_encoder;
        return command_encoder;
    }
};
