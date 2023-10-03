pub const SharedFence = opaque {
    pub const Descriptor = struct {
        backend_handle: ?BackendHandle = null,
        label: ?[:0]const u8,
    };

    pub const BackendHandle = union(enum) {
        vk_semaphore_opaque_fd_descriptor: c_int,
        vk_semaphore_sync_fd_descriptor: c_int,
        vk_semaphore_zircon_handle_descriptor: c_int,
        dxgi_shared_handle_descriptor: *anyopaque,
        mtl_shared_event_descriptor: *anyopaque,
    };
};
