const Texture = @import("texture.zig").Texture;
const Extent3D = @import("main.zig").Extent3D;
const SharedFence = @import("shared_fence.zig").SharedFence;

pub const SharedTextureMemory = opaque {
    pub const Properties = struct {
        usage: Texture.UsageFlags,
        size: Extent3D,
        format: Texture.Format,
    };

    pub const VkImageDescriptor = struct {
        vk_format: i32,
        vk_usage_flags: Texture.UsageFlags,
        vk_extent3d: Extent3D,
    };

    pub const BeginAccessDescriptor = struct {
        initialized: bool,
        fence_count: usize,
        fences: *const SharedFence,
        signaled_values: *const u64,
        vk_image_layout_begin_state: ?VkImageLayoutBeginState = null,
    };

    pub const Descriptor = struct {
        label: ?[:0]const u8,
        backend_handle: ?BackendHandle = null,
        vk_dedicated_allocation: bool,
    };

    pub const BackendHandle = union(enum) {
        a_hardware_buffer_descriptor: *anyopaque,
        dma_buf_descriptor: DmaBufDescriptor,
        dxgi_shared_handle_descriptor: *anyopaque,
        egl_image_descriptor: *anyopaque,
        io_surface_descriptor: *anyopaque,
        opaque_fd_descriptor: OpaqueFDDescriptor,
        zircon_handle_descriptor: ZirconHandleDescriptor,
    };

    pub const DmaBufDescriptor = struct {
        memory_fd: c_int,
        allocation_size: u64,
        drm_modifier: u64,
        plane_count: usize,
        plane_offsets: *const u64,
        plane_strides: *const u32,
    };

    pub const EndAccessState = struct {
        initialized: bool,
        fence_count: usize,
        fences: *const SharedFence,
        signaled_values: *const u64,
        vk_image_layout_end_state: ?VkImageLayoutEndState = null,
    };

    pub const OpaqueFDDescriptor = struct {
        memory_fd: c_int,
        allocation_size: u64,
    };

    pub const ZirconHandleDescriptor = struct {
        memory_fd: u32,
        allocation_size: u64,
    };

    pub const VkImageLayoutBeginState = struct {
        old_layout: i32,
        new_layout: i32,
    };

    pub const VkImageLayoutEndState = struct {
        old_layout: i32,
        new_layout: i32,
    };
};
