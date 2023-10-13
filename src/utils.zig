const std = @import("std");
const limits = @import("limits.zig");
const shader = @import("shader.zig");
const dgpu = @import("dgpu/main.zig");

pub fn Manager(comptime T: type) type {
    return struct {
        count: u32 = 1,

        pub fn reference(manager: *@This()) void {
            _ = @atomicRmw(u32, &manager.count, .Add, 1, .Monotonic);
        }

        pub fn release(manager: *@This()) void {
            if (@atomicRmw(u32, &manager.count, .Sub, 1, .Release) == 1) {
                @fence(.Acquire);
                const parent = @fieldParentPtr(T, "manager", manager);
                parent.deinit();
            }
        }
    };
}

pub fn findChained(comptime T: type, next_in_chain: ?*const dgpu.ChainedStruct) ?*const T {
    const search = @as(*align(1) const dgpu.ChainedStruct, @ptrCast(std.meta.fieldInfo(T, .chain).default_value.?));
    var chain = next_in_chain;
    while (chain) |c| {
        if (c.s_type == search.s_type) {
            return @as(*const T, @ptrCast(c));
        }
        chain = c.next;
    }
    return null;
}

pub fn alignUp(x: usize, a: usize) usize {
    return (x + a - 1) / a * a;
}

pub const DefaultPipelineLayoutDescriptor = struct {
    pub const Group = std.ArrayListUnmanaged(dgpu.BindGroupLayout.Entry);

    allocator: std.mem.Allocator,
    groups: std.BoundedArray(Group, limits.max_bind_groups) = .{},

    pub fn init(allocator: std.mem.Allocator) DefaultPipelineLayoutDescriptor {
        return .{ .allocator = allocator };
    }

    pub fn deinit(desc: *DefaultPipelineLayoutDescriptor) void {
        for (desc.groups.slice()) |*group| {
            group.deinit(desc.allocator);
        }
    }

    pub fn addFunction(
        desc: *DefaultPipelineLayoutDescriptor,
        air: *const shader.Air,
        stage: dgpu.ShaderStageFlags,
        entry_point: [*:0]const u8,
    ) !void {
        if (air.findFunction(std.mem.span(entry_point))) |fn_inst| {
            const global_var_ref_list = air.refToList(fn_inst.global_var_refs);
            for (global_var_ref_list) |global_var_inst_idx| {
                const var_inst = air.getInst(global_var_inst_idx).@"var";
                if (var_inst.addr_space == .workgroup)
                    continue;

                const var_type = air.getInst(var_inst.type);
                const group: u32 = @intCast(air.resolveInt(var_inst.group) orelse return error.constExpr);
                const binding: u32 = @intCast(air.resolveInt(var_inst.binding) orelse return error.constExpr);

                var entry: dgpu.BindGroupLayout.Entry = .{ .binding = binding, .visibility = stage };
                switch (var_type) {
                    .sampler_type => entry.sampler.type = .filtering,
                    .comparison_sampler_type => entry.sampler.type = .comparison,
                    .texture_type => |texture| {
                        switch (texture.kind) {
                            .storage_1d,
                            .storage_2d,
                            .storage_2d_array,
                            .storage_3d,
                            => {
                                entry.storage_texture.access = .undefined; // TODO - write_only
                                entry.storage_texture.format = switch (texture.texel_format) {
                                    .none => unreachable,
                                    .rgba8unorm => .rgba8_unorm,
                                    .rgba8snorm => .rgba8_snorm,
                                    .bgra8unorm => .bgra8_unorm,
                                    .rgba16float => .rgba16_float,
                                    .r32float => .r32_float,
                                    .rg32float => .rg32_float,
                                    .rgba32float => .rgba32_float,
                                    .rgba8uint => .rgba8_uint,
                                    .rgba16uint => .rgba16_uint,
                                    .r32uint => .r32_uint,
                                    .rg32uint => .rg32_uint,
                                    .rgba32uint => .rgba32_uint,
                                    .rgba8sint => .rgba8_sint,
                                    .rgba16sint => .rgba16_sint,
                                    .r32sint => .r32_sint,
                                    .rg32sint => .rg32_sint,
                                    .rgba32sint => .rgba32_sint,
                                };
                                entry.storage_texture.view_dimension = switch (texture.kind) {
                                    .storage_1d => .dimension_1d,
                                    .storage_2d => .dimension_2d,
                                    .storage_2d_array => .dimension_2d_array,
                                    .storage_3d => .dimension_3d,
                                    else => unreachable,
                                };
                            },
                            else => {
                                // sample_type
                                entry.texture.sample_type =
                                    switch (texture.kind) {
                                    .depth_2d,
                                    .depth_2d_array,
                                    .depth_cube,
                                    .depth_cube_array,
                                    => .depth,
                                    else => switch (texture.texel_format) {
                                        .none => .float, // TODO - is this right?
                                        .rgba8unorm,
                                        .rgba8snorm,
                                        .bgra8unorm,
                                        .rgba16float,
                                        .r32float,
                                        .rg32float,
                                        .rgba32float,
                                        => .float, // TODO - unfilterable
                                        .rgba8uint,
                                        .rgba16uint,
                                        .r32uint,
                                        .rg32uint,
                                        .rgba32uint,
                                        => .uint,
                                        .rgba8sint,
                                        .rgba16sint,
                                        .r32sint,
                                        .rg32sint,
                                        .rgba32sint,
                                        => .sint,
                                    },
                                };
                                entry.texture.view_dimension = switch (texture.kind) {
                                    .sampled_1d,
                                    .storage_1d,
                                    => .dimension_1d,
                                    .sampled_2d,
                                    .multisampled_2d,
                                    .multisampled_depth_2d,
                                    .storage_2d,
                                    .depth_2d,
                                    => .dimension_2d,
                                    .sampled_2d_array,
                                    .storage_2d_array,
                                    .depth_2d_array,
                                    => .dimension_2d_array,
                                    .sampled_3d,
                                    .storage_3d,
                                    => .dimension_3d,
                                    .sampled_cube,
                                    .depth_cube,
                                    => .dimension_cube,
                                    .sampled_cube_array,
                                    .depth_cube_array,
                                    => .dimension_cube_array,
                                };
                                entry.texture.multisampled = switch (texture.kind) {
                                    .multisampled_2d,
                                    .multisampled_depth_2d,
                                    => .true,
                                    else => .false,
                                };
                            },
                        }
                    },
                    else => {
                        switch (var_inst.addr_space) {
                            .uniform => entry.buffer.type = .uniform,
                            .storage => {
                                if (var_inst.access_mode == .read) {
                                    entry.buffer.type = .read_only_storage;
                                } else {
                                    entry.buffer.type = .storage;
                                }
                            },
                            else => std.debug.panic("unhandled addr_space\n", .{}),
                        }
                    },
                }

                while (desc.groups.len <= group) {
                    desc.groups.appendAssumeCapacity(.{});
                }

                var append = true;
                var group_entries = &desc.groups.buffer[group];
                for (group_entries.items) |*previous_entry| {
                    if (previous_entry.binding == binding) {
                        // TODO - bitfield or?
                        if (entry.visibility.vertex)
                            previous_entry.visibility.vertex = true;
                        if (entry.visibility.fragment)
                            previous_entry.visibility.fragment = true;
                        if (entry.visibility.compute)
                            previous_entry.visibility.compute = true;

                        if (previous_entry.buffer.min_binding_size < entry.buffer.min_binding_size) {
                            previous_entry.buffer.min_binding_size = entry.buffer.min_binding_size;
                        }
                        if (previous_entry.texture.sample_type != entry.texture.sample_type) {
                            if (previous_entry.texture.sample_type == .unfilterable_float and entry.texture.sample_type == .float) {
                                previous_entry.texture.sample_type = .float;
                            } else if (previous_entry.texture.sample_type == .float and entry.texture.sample_type == .unfilterable_float) {
                                // ignore
                            } else {
                                return error.incompatibleEntries;
                            }
                        }

                        // TODO - any other differences return error

                        append = false;
                        break;
                    }
                }

                if (append)
                    try group_entries.append(desc.allocator, entry);
            }
        }
    }
};
