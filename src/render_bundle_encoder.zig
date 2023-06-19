const Texture = @import("texture.zig").Texture;
const Buffer = @import("buffer.zig").Buffer;
const BindGroup = @import("bind_group.zig").BindGroup;
const RenderPipeline = @import("render_pipeline.zig").RenderPipeline;
const RenderBundle = @import("render_bundle.zig").RenderBundle;
const ChainedStruct = @import("gpu.zig").ChainedStruct;
const IndexFormat = @import("gpu.zig").IndexFormat;
const Impl = @import("interface.zig").Impl;

pub const RenderBundleEncoder = opaque {
    pub const Descriptor = extern struct {
        next_in_chain: ?*const ChainedStruct = null,
        label: ?[*:0]const u8 = null,
        color_formats_count: u32 = 0,
        color_formats: ?[*]const Texture.Format = null,
        depth_stencil_format: Texture.Format = .undefined,
        sample_count: u32 = 1,
        depth_read_only: bool = false,
        stencil_read_only: bool = false,

        /// Provides a slightly friendlier Zig API to initialize this structure.
        pub inline fn init(v: struct {
            next_in_chain: ?*const ChainedStruct = null,
            label: ?[*:0]const u8 = null,
            color_formats: ?[]const Texture.Format = null,
            depth_stencil_format: Texture.Format = .undefined,
            sample_count: u32 = 1,
            depth_read_only: bool = false,
            stencil_read_only: bool = false,
        }) Descriptor {
            return .{
                .next_in_chain = v.next_in_chain,
                .label = v.label,
                .color_formats_count = if (v.color_formats) |e| @intCast(u32, e.len) else 0,
                .color_formats = if (v.color_formats) |e| e.ptr else null,
                .depth_stencil_format = v.depth_stencil_format,
                .sample_count = v.sample_count,
                .depth_read_only = v.depth_read_only,
                .stencil_read_only = v.stencil_read_only,
            };
        }
    };
};
