const std = @import("std");
const Air = @import("../Air.zig");
const DebugInfo = @import("../CodeGen.zig").DebugInfo;
const Section = @import("spirv/Section.zig");
const spec = @import("spirv/spec.zig");
const Inst = Air.Inst;
const InstIndex = Air.InstIndex;
const RefIndex = Air.RefIndex;
const Word = spec.Word;
const Opcode = spec.Opcode;
const Operand = spec.Operand;
const IdResult = spec.IdResult;
const IdRef = spec.IdRef;

const SpirV = @This();

air: *const Air,
allocator: std.mem.Allocator,
/// Debug Information
debug_section: Section,
/// Annotations
annotations_section: Section,
/// Types, variables and constants
global_section: Section,
/// Functions
main_section: Section,
/// Cache type and constants
type_value_map: std.ArrayHashMapUnmanaged(Key, IdRef, Key.Adapter, true) = .{},
/// Map Air Instruction Index to IdRefs to prevent duplicated declarations
decl_map: std.AutoHashMapUnmanaged(InstIndex, Decl) = .{},
/// Map Air Struct Instruction Index to IdRefs to prevent duplicated declarations
struct_map: std.AutoHashMapUnmanaged(InstIndex, IdRef) = .{},
decorated: std.AutoHashMapUnmanaged(IdRef, void) = .{},
extended_instructions: ?IdRef = null,
emit_debug_names: bool,
next_result_id: Word = 1,
compute_stage: ?ComputeStage = null,
vertex_stage: ?VertexStage = null,
fragment_stage: ?FragmentStage = null,
store_return: StoreReturn = .none,
loop_merge_label: ?IdRef = null,
loop_continue_label: ?IdRef = null,
branched: std.AutoHashMapUnmanaged(RefIndex, void) = .{},
current_block: RefIndex,

const Decl = struct {
    id: IdRef,
    type_id: IdRef,
    is_ptr: bool,
    storage_class: spec.StorageClass,
    faked_struct: bool,
};

const StoreReturn = union(enum) {
    none,
    single: IdRef,
    many: []const Item,

    const Item = struct { ptr: IdRef, type: IdRef };
};

const ComputeStage = struct {
    id: IdResult,
    name: []const u8,
    interface: []const IdRef,
    workgroup_size: struct {
        x: spec.LiteralInteger,
        y: spec.LiteralInteger,
        z: spec.LiteralInteger,
    },
};

const VertexStage = struct {
    id: IdResult,
    name: []const u8,
    interface: []const IdRef,
};

const FragmentStage = struct {
    id: IdResult,
    name: []const u8,
    interface: []const IdRef,
};

pub fn gen(allocator: std.mem.Allocator, air: *const Air, debug_info: DebugInfo) ![]const u8 {
    var spv = SpirV{
        .air = air,
        .allocator = allocator,
        .debug_section = .{ .allocator = allocator },
        .annotations_section = .{ .allocator = allocator },
        .global_section = .{ .allocator = allocator },
        .main_section = .{ .allocator = allocator },
        .emit_debug_names = debug_info.emit_names,
        .current_block = undefined,
    };
    defer {
        spv.debug_section.deinit();
        spv.annotations_section.deinit();
        spv.global_section.deinit();
        spv.main_section.deinit();
        spv.type_value_map.deinit(allocator);
        spv.decl_map.deinit(allocator);
        spv.struct_map.deinit(allocator);
        spv.decorated.deinit(allocator);
        spv.branched.deinit(allocator);
        if (spv.compute_stage) |stage| allocator.free(stage.interface);
        if (spv.vertex_stage) |stage| allocator.free(stage.interface);
        if (spv.fragment_stage) |stage| allocator.free(stage.interface);
    }

    var module_section = Section{ .allocator = allocator };
    defer module_section.deinit();

    if (debug_info.emit_source_file) |source_file_path| {
        try spv.emitSourceInfo(source_file_path);
    }

    for (air.refToList(air.globals_index)) |inst_idx| {
        switch (spv.air.getInst(inst_idx)) {
            .@"fn" => _ = try spv.emitFn(inst_idx),
            .@"const" => _ = try spv.emitConst(inst_idx),
            .@"var" => _ = try spv.emitVarProto(&spv.global_section, inst_idx),
            .@"struct" => _ = try spv.emitStruct(inst_idx),
            else => unreachable,
        }
    }

    try spv.emitModule(&module_section);
    try module_section.append(spv.debug_section);
    try module_section.append(spv.annotations_section);
    try module_section.append(spv.global_section);
    try module_section.append(spv.main_section);

    return allocator.dupe(u8, std.mem.sliceAsBytes(module_section.words.items));
}

fn emitSourceInfo(spv: *SpirV, file_path: []const u8) !void {
    const file_path_id = spv.allocId();
    try spv.debug_section.emit(.OpString, .{
        .id_result = file_path_id,
        .string = file_path,
    });

    try spv.debug_section.emit(.OpSource, .{
        .source_language = .Unknown,
        .version = 0,
        .file = file_path_id,
        .source = spv.air.tree.source,
    });
}

fn emitModule(spv: *SpirV, section: *Section) !void {
    const header = &[_]Word{
        // Magic number
        spec.magic_number,
        // Spir-V 1.3
        spec.Version.toWord(.{ .major = 1, .minor = 3 }),
        // Generator magic number
        // TODO: register dusk compiler
        0,
        // Id's bound
        spv.next_result_id,
        // Reserved for instruction schema, if needed
        0,
    };
    try section.ensureUnusedCapacity(header.len);
    section.writeWords(header);

    try section.emit(.OpCapability, .{ .capability = .Shader });
    if (spv.air.extensions.f16) try section.emit(.OpCapability, .{ .capability = .Float16 });
    if (spv.extended_instructions) |id| try section.emit(
        .OpExtInstImport,
        .{ .id_result = id, .name = "GLSL.std.450" },
    );
    try section.emit(.OpMemoryModel, .{ .addressing_model = .Logical, .memory_model = .GLSL450 });

    if (spv.compute_stage) |compute_stage| {
        try section.emit(.OpEntryPoint, .{
            .execution_model = .GLCompute,
            .entry_point = compute_stage.id,
            .name = compute_stage.name,
            .interface = compute_stage.interface,
        });
        try section.emit(.OpExecutionMode, .{
            .entry_point = compute_stage.id,
            .mode = .{ .LocalSize = .{
                .x_size = compute_stage.workgroup_size.x,
                .y_size = compute_stage.workgroup_size.y,
                .z_size = compute_stage.workgroup_size.z,
            } },
        });
    }

    if (spv.vertex_stage) |vertex_stage| {
        try section.emit(.OpEntryPoint, .{
            .execution_model = .Vertex,
            .entry_point = vertex_stage.id,
            .name = vertex_stage.name,
            .interface = vertex_stage.interface,
        });
    }

    if (spv.fragment_stage) |fragment_stage| {
        try section.emit(.OpEntryPoint, .{
            .execution_model = .Fragment,
            .entry_point = fragment_stage.id,
            .name = fragment_stage.name,
            .interface = fragment_stage.interface,
        });
        try section.emit(.OpExecutionMode, .{
            .entry_point = fragment_stage.id,
            .mode = .OriginUpperLeft,
        });
    }
}

fn emitFn(spv: *SpirV, inst_idx: InstIndex) error{OutOfMemory}!IdRef {
    const inst = spv.air.getInst(inst_idx).@"fn";

    var section = Section{ .allocator = spv.allocator };
    var params_section = Section{ .allocator = spv.allocator };
    defer {
        section.deinit();
        params_section.deinit();
    }

    const fn_id = spv.allocId();
    const raw_return_type_id = blk: {
        if (inst.return_type == .none) {
            break :blk try spv.resolve(.void_type);
        } else {
            break :blk try spv.emitType(inst.return_type);
        }
    };
    const return_type_id = blk: {
        if (inst.stage != .none) {
            break :blk try spv.resolve(.void_type);
        } else {
            break :blk raw_return_type_id;
        }
    };

    const name_slice = spv.air.getStr(inst.name);
    try spv.debugName(fn_id, name_slice);

    var interface = std.ArrayList(IdRef).init(spv.allocator);
    errdefer interface.deinit();

    if (inst.stage != .none and inst.return_type != .none) {

        // TODO: eliminate duplicate code
        if (spv.air.getInst(inst.return_type) == .@"struct") {
            const struct_members = spv.air.refToList(spv.air.getInst(inst.return_type).@"struct".members);

            var store_returns = try std.ArrayList(StoreReturn.Item).initCapacity(spv.allocator, struct_members.len);
            defer store_returns.deinit();

            for (struct_members) |member_index| {
                const return_var_id = spv.allocId();

                const member = spv.air.getInst(member_index).struct_member;
                const member_type_id = try spv.emitType(member.type);

                const return_var_name_slice = try std.mem.concat(
                    spv.allocator,
                    u8,
                    &.{ name_slice, spv.air.getStr(member.name), "_return_output" },
                );
                defer spv.allocator.free(return_var_name_slice);
                try spv.debugName(return_var_id, return_var_name_slice);

                const return_var_type_id = try spv.resolve(.{ .ptr_type = .{
                    .storage_class = .Output,
                    .elem_type = member_type_id,
                } });
                try spv.global_section.emit(.OpVariable, .{
                    .id_result_type = return_var_type_id,
                    .id_result = return_var_id,
                    .storage_class = .Output,
                });

                if (member.builtin) |builtin| {
                    try spv.annotations_section.emit(.OpDecorate, .{
                        .target = return_var_id,
                        .decoration = .{ .BuiltIn = .{ .built_in = spirvBuiltin(builtin) } },
                    });
                }

                if (member.location) |location| {
                    try spv.annotations_section.emit(.OpDecorate, .{
                        .target = return_var_id,
                        .decoration = .{ .Location = .{ .location = location } },
                    });
                }

                try interface.append(return_var_id);
                try store_returns.append(.{ .ptr = return_var_id, .type = member_type_id });
            }

            spv.store_return = .{ .many = try store_returns.toOwnedSlice() };
        } else {
            const return_var_id = spv.allocId();

            const return_var_name_slice = try std.mem.concat(
                spv.allocator,
                u8,
                &.{ name_slice, "_return_output" },
            );
            defer spv.allocator.free(return_var_name_slice);
            try spv.debugName(return_var_id, return_var_name_slice);

            const return_var_type_id = try spv.resolve(.{ .ptr_type = .{
                .storage_class = .Output,
                .elem_type = raw_return_type_id,
            } });
            try spv.global_section.emit(.OpVariable, .{
                .id_result_type = return_var_type_id,
                .id_result = return_var_id,
                .storage_class = .Output,
            });

            if (inst.return_attrs.builtin) |builtin| {
                try spv.annotations_section.emit(.OpDecorate, .{
                    .target = return_var_id,
                    .decoration = .{ .BuiltIn = .{ .built_in = spirvBuiltin(builtin) } },
                });
            }

            if (inst.return_attrs.location) |location| {
                try spv.annotations_section.emit(.OpDecorate, .{
                    .target = return_var_id,
                    .decoration = .{ .Location = .{ .location = location } },
                });
            }

            spv.store_return = .{ .single = return_var_id };
            try interface.append(return_var_id);
        }
    }

    var params_type = std.ArrayList(IdRef).init(spv.allocator);
    defer params_type.deinit();

    if (inst.params != .none) {
        const param_list = spv.air.refToList(inst.params);

        for (param_list) |param_inst_idx| {
            const param_inst = spv.air.getInst(param_inst_idx).fn_param;
            const param_id = spv.allocId();

            try spv.debugName(param_id, spv.air.getStr(param_inst.name));

            if (inst.stage != .none) {
                const elem_type_id = try spv.emitType(param_inst.type);
                const param_type_id = try spv.resolve(.{ .ptr_type = .{
                    .storage_class = .Input,
                    .elem_type = elem_type_id,
                } });

                const param_var_name_slice = try std.mem.concat(
                    spv.allocator,
                    u8,
                    &.{ name_slice, "_", spv.air.getStr(param_inst.name), "_input" },
                );
                defer spv.allocator.free(param_var_name_slice);

                try spv.global_section.emit(.OpVariable, .{
                    .id_result_type = param_type_id,
                    .id_result = param_id,
                    .storage_class = .Input,
                });

                if (param_inst.builtin) |builtin| {
                    try spv.annotations_section.emit(.OpDecorate, .{
                        .target = param_id,
                        .decoration = .{ .BuiltIn = .{
                            .built_in = spirvBuiltin(builtin),
                        } },
                    });
                }

                if (param_inst.location) |location| {
                    try spv.annotations_section.emit(.OpDecorate, .{
                        .target = param_id,
                        .decoration = .{ .Location = .{ .location = location } },
                    });
                }

                try interface.append(param_id);
                try spv.decl_map.put(spv.allocator, param_inst_idx, .{
                    .id = param_id,
                    .type_id = elem_type_id,
                    .is_ptr = true,
                    .storage_class = .Input,
                    .faked_struct = false,
                });
            } else {
                const param_type_id = try spv.emitType(param_inst.type);
                try params_section.emit(.OpFunctionParameter, .{
                    .id_result_type = param_type_id,
                    .id_result = param_id,
                });
                try params_type.append(param_type_id);
                try spv.decl_map.put(spv.allocator, param_inst_idx, .{
                    .id = param_id,
                    .type_id = param_type_id,
                    .is_ptr = false,
                    .storage_class = .Function,
                    .faked_struct = false,
                });
            }
        }
    }

    const fn_type_id = try spv.resolve(.{
        .fn_type = .{
            .return_type = return_type_id,
            .params_type = params_type.items,
        },
    });

    try section.emit(.OpFunction, .{
        .id_result_type = return_type_id,
        .id_result = fn_id,
        .function_control = .{ .Const = inst.is_const },
        .function_type = fn_type_id,
    });

    try section.append(params_section);

    const body_id = spv.allocId();
    const body = spv.air.getInst(inst.block).block;
    try section.emit(.OpLabel, .{ .id_result = body_id });

    if (body != .none) {
        try spv.emitFnVars(&section, body);
    }

    if (body != .none) {
        try spv.emitBlock(&section, body);
        const statements = spv.air.refToList(body);
        if (spv.air.getInst(statements[statements.len - 1]) != .@"return") {
            try spv.emitReturn(&section, .none);
        }
    } else {
        try spv.emitReturn(&section, .none);
    }

    try section.emit(.OpFunctionEnd, {});

    switch (inst.stage) {
        .none => {},
        .compute => |compute| spv.compute_stage = .{
            .id = fn_id,
            .name = name_slice,
            .interface = try interface.toOwnedSlice(),
            .workgroup_size = .{
                .x = blk: {
                    const int = spv.air.getInst(compute.x).int;
                    const value = spv.air.getValue(Inst.Int.Value, int.value.?);
                    break :blk @intCast(value.literal);
                },
                .y = blk: {
                    if (compute.y == .none) break :blk 1;

                    const int = spv.air.getInst(compute.y).int;
                    const value = spv.air.getValue(Inst.Int.Value, int.value.?);
                    break :blk @intCast(value.literal);
                },
                .z = blk: {
                    if (compute.y == .none) break :blk 1;

                    const int = spv.air.getInst(compute.z).int;
                    const value = spv.air.getValue(Inst.Int.Value, int.value.?);
                    break :blk @intCast(value.literal);
                },
            },
        },
        .vertex => spv.vertex_stage = .{
            .id = fn_id,
            .name = name_slice,
            .interface = try interface.toOwnedSlice(),
        },
        .fragment => spv.fragment_stage = .{
            .id = fn_id,
            .name = name_slice,
            .interface = try interface.toOwnedSlice(),
        },
    }

    try spv.main_section.append(section);
    try spv.decl_map.put(spv.allocator, inst_idx, .{
        .id = fn_id,
        .type_id = fn_type_id,
        .is_ptr = false,
        .storage_class = .Function, // TODO
        .faked_struct = false,
    });
    return fn_id;
}

fn emitFnVars(spv: *SpirV, section: *Section, statements: RefIndex) !void {
    if (statements == .none) return;
    const list = spv.air.refToList(statements);
    for (list) |statement_idx| {
        switch (spv.air.getInst(statement_idx)) {
            .@"var" => _ = try spv.emitVarProto(section, statement_idx),
            .block => |block| try spv.emitFnVars(section, block),
            .@"if" => {
                var if_idx = statement_idx;
                while (true) {
                    const @"if" = spv.air.getInst(if_idx).@"if";
                    const if_body = spv.air.getInst(@"if".body).block;
                    try spv.emitFnVars(section, if_body);
                    if (@"if".@"else" != .none) {
                        switch (spv.air.getInst(@"if".@"else")) {
                            .@"if" => if_idx = @"if".@"else",
                            .block => |block| return spv.emitFnVars(section, block),
                            else => unreachable,
                        }
                    }
                    break;
                }
            },
            .@"while" => |@"while"| if (@"while".body != .none) {
                try spv.emitFnVars(section, spv.air.getInst(@"while".body).block);
            },
            .continuing => |continuing| if (continuing != .none) {
                try spv.emitFnVars(section, spv.air.getInst(continuing).block);
            },
            .@"switch" => |@"switch"| {
                const switch_cases_list = spv.air.refToList(@"switch".cases_list);
                for (switch_cases_list) |switch_case_idx| {
                    const switch_case = spv.air.getInst(switch_case_idx).switch_case;
                    try spv.emitFnVars(section, spv.air.getInst(switch_case.body).block);
                }
            },
            .@"for" => |@"for"| {
                _ = try spv.emitVarProto(section, @"for".init);
                if (@"for".body != .none) {
                    try spv.emitFnVars(section, spv.air.getInst(@"for".body).block);
                }
            },
            else => {},
        }
    }
}

fn emitVarProto(spv: *SpirV, section: *Section, inst_idx: InstIndex) !IdRef {
    if (spv.decl_map.get(inst_idx)) |decl| return decl.id;

    const inst = spv.air.getInst(inst_idx).@"var";
    const id = spv.allocId();
    try spv.debugName(id, spv.air.getStr(inst.name));

    const type_inst = spv.air.getInst(inst.type);
    const type_id = try spv.emitType(inst.type);
    const storage_class = storageClassFromAddrSpace(inst.addr_space);

    if (inst.binding != .none) {
        const binding = spv.air.resolveConstExpr(inst.binding).?.int;
        try spv.annotations_section.emit(.OpDecorate, .{
            .target = id,
            .decoration = spec.Decoration.Extended{
                .Binding = .{ .binding_point = @intCast(binding) },
            },
        });
    }

    if (inst.group != .none) {
        const group = spv.air.resolveConstExpr(inst.group).?.int;
        try spv.annotations_section.emit(.OpDecorate, .{
            .target = id,
            .decoration = spec.Decoration.Extended{
                .DescriptorSet = .{ .descriptor_set = @intCast(group) },
            },
        });
    }

    var faked_struct = false;
    const ptr_type_id = if (inst.addr_space == .uniform or inst.addr_space == .storage) blk: {
        // zig fmt: off
        // TODO
        faked_struct = spv.air.getInst(inst.type) != .@"struct";
        // zig fmt: on
        const struct_type_id = if (faked_struct) sti: {
            const struct_type_id = spv.allocId();
            try spv.global_section.emit(.OpTypeStruct, .{
                .id_result = struct_type_id,
                .id_ref = &.{type_id},
            });
            break :sti struct_type_id;
        } else type_id;

        if (spv.decorated.get(type_id) == null) {
            try spv.annotations_section.emit(.OpDecorate, .{
                .target = struct_type_id,
                .decoration = .Block,
            });

            if (!faked_struct) {
                try spv.decorateStruct(inst.type);
            } else {
                try spv.annotations_section.emit(.OpMemberDecorate, .{
                    .structure_type = struct_type_id,
                    .member = 0,
                    .decoration = .{ .Offset = .{ .byte_offset = 0 } },
                });
            }

            switch (inst.addr_space) {
                .uniform => {
                    try spv.annotations_section.emit(.OpMemberDecorate, .{
                        .structure_type = struct_type_id,
                        .member = 0,
                        .decoration = .ColMajor,
                    });

                    try spv.emitStride(inst.type, struct_type_id);
                },
                .storage => try spv.emitStride(inst.type, struct_type_id),
                else => {},
            }

            try spv.decorated.put(spv.allocator, type_id, {});
        }

        break :blk try spv.resolve(.{ .ptr_type = .{
            .elem_type = struct_type_id,
            .storage_class = storage_class,
        } });
    } else blk: {
        break :blk try spv.resolve(.{ .ptr_type = .{
            .elem_type = type_id,
            .storage_class = storage_class,
        } });
    };

    const initializer = blk: {
        if (inst.addr_space == .uniform or inst.addr_space == .storage) break :blk null;
        if (type_inst == .array and type_inst.array.len == .none) break :blk null;
        if (type_inst == .sampler_type or type_inst == .texture_type) break :blk null;
        break :blk try spv.resolve(.{ .null = type_id });
    };

    try section.emit(.OpVariable, .{
        .id_result_type = ptr_type_id,
        .id_result = id,
        .storage_class = storage_class,
        .initializer = initializer,
    });

    try spv.decl_map.put(spv.allocator, inst_idx, .{
        .id = id,
        .type_id = type_id,
        .is_ptr = true,
        .storage_class = storage_class,
        .faked_struct = faked_struct,
    });

    return id;
}

fn decorateStruct(spv: *SpirV, inst: InstIndex) !void {
    const id = try spv.emitType(inst);
    var offset: u32 = 0;
    const members = spv.air.refToList(spv.air.getInst(inst).@"struct".members);
    std.debug.print("\n\n", .{});
    for (members, 0..) |member, i| {
        const member_inst = spv.air.getInst(member).struct_member;
        switch (spv.air.getInst(member_inst.type)) {
            .@"struct" => try spv.decorateStruct(member_inst.type),
            .array => |arr| if (spv.air.getInst(arr.elem_type) == .@"struct") {
                try spv.decorateStruct(arr.elem_type);
            },
            else => {},
        }

        try spv.annotations_section.emit(.OpMemberDecorate, .{
            .structure_type = id,
            .member = @intCast(i),
            .decoration = .{ .Offset = .{ .byte_offset = offset } },
        });
        if (members.len > 1) offset += spv.getSize(member_inst.type);
    }
}

fn emitStride(spv: *SpirV, inst: InstIndex, id: IdRef) !void {
    switch (spv.air.getInst(inst)) {
        .@"struct" => |@"struct"| {
            for (spv.air.refToList(@"struct".members), 0..) |member, i| {
                const member_inst = spv.air.getInst(member).struct_member;
                switch (spv.air.getInst(member_inst.type)) {
                    .array => try spv.annotations_section.emit(.OpDecorate, .{
                        .target = try spv.emitType(member_inst.type),
                        .decoration = .{ .ArrayStride = .{ .array_stride = spv.getStride(member_inst.type, true) } },
                    }),
                    .matrix => try spv.annotations_section.emit(.OpMemberDecorate, .{
                        .structure_type = id,
                        .member = @intCast(i),
                        .decoration = .{ .MatrixStride = .{ .matrix_stride = spv.getStride(member_inst.type, true) } },
                    }),
                    else => {},
                }
            }
        },
        else => |inst_type| switch (inst_type) {
            .array => try spv.annotations_section.emit(.OpMemberDecorate, .{
                .structure_type = id,
                .member = 0,
                .decoration = .{ .ArrayStride = .{ .array_stride = spv.getStride(inst, true) } },
            }),
            .matrix => try spv.annotations_section.emit(.OpMemberDecorate, .{
                .structure_type = id,
                .member = 0,
                .decoration = .{ .MatrixStride = .{ .matrix_stride = spv.getStride(inst, true) } },
            }),
            else => {},
        },
    }
}

fn getStride(spv: *SpirV, inst: InstIndex, direct: bool) u8 {
    return switch (spv.air.getInst(inst)) {
        inline .int, .float => |num| num.type.width() / 8,
        .array => |arr| spv.getStride(arr.elem_type, false),
        .vector => |vec| return spv.getStride(vec.elem_type, false) *
            if (direct) 1 else @as(u8, @intCast(@intFromEnum(vec.size))),
        .matrix => |mat| return @as(u8, @intCast(@intFromEnum(mat.cols))) *
            spv.getStride(mat.elem_type, false) *
            if (direct) 1 else @as(u8, @intCast(@intFromEnum(mat.rows))),
        .@"struct" => |strct| {
            var total: u8 = 0;
            const members = spv.air.refToList(strct.members);
            for (members) |member| {
                const member_ty = spv.air.getInst(member).struct_member.type;
                total += spv.getStride(member_ty, false);
            }
            return total;
        },
        else => unreachable, // TODO
    };
}

fn getSize(spv: *SpirV, inst: InstIndex) u8 {
    return switch (spv.air.getInst(inst)) {
        inline .int, .float => |num| num.type.width() / 8,
        .array => |arr| return @intCast(spv.air.resolveInt(arr.len).? * spv.getSize(arr.elem_type)),
        .vector => |vec| return spv.getSize(vec.elem_type) * @intFromEnum(vec.size),
        .matrix => |mat| return @as(u8, @intCast(@intFromEnum(mat.cols))) * @intFromEnum(mat.rows) * spv.getSize(mat.elem_type),
        else => unreachable, // TODO
    };
}

fn emitConst(spv: *SpirV, inst_idx: InstIndex) !IdRef {
    if (spv.decl_map.get(inst_idx)) |decl| return decl.id;

    const inst = spv.air.getInst(inst_idx).@"const";
    const id = try spv.emitExpr(&spv.global_section, inst.expr);
    try spv.debugName(id, spv.air.getStr(inst.name));
    return id;
}

fn emitType(spv: *SpirV, inst: InstIndex) error{OutOfMemory}!IdRef {
    return switch (spv.air.getInst(inst)) {
        .bool => try spv.resolve(.bool_type),
        .int => |int| try spv.resolve(.{ .int_type = int.type }),
        .float => |float| try spv.resolve(.{ .float_type = float.type }),
        .vector => |vector| try spv.resolve(.{
            .vector_type = .{
                .size = vector.size,
                .elem_type = try spv.emitType(vector.elem_type),
            },
        }),
        .matrix => |matrix| try spv.resolve(.{
            .matrix_type = .{
                .cols = matrix.cols,
                .elem_type = try spv.resolve(.{
                    .vector_type = .{
                        .size = matrix.rows,
                        .elem_type = try spv.emitType(matrix.elem_type),
                    },
                }),
            },
        }),
        .array => |array| try spv.resolve(.{
            .array_type = .{
                .len = if (array.len != .none) try spv.emitExpr(&spv.global_section, array.len) else null,
                .elem_type = try spv.emitType(array.elem_type),
            },
        }),
        .ptr_type => |ptr| try spv.resolve(.{
            .ptr_type = .{
                .storage_class = storageClassFromAddrSpace(ptr.addr_space),
                .elem_type = try spv.emitType(ptr.elem_type),
            },
        }),
        .sampler_type => try spv.resolve(.sampler_type),
        .texture_type => |texture| {
            const sampled_type = try spv.emitType(texture.elem_type);
            return spv.resolve(.{ .texture_type = .{
                .sampled_type = sampled_type,
                .dim = spirvDim(texture.kind),
                .depth = spirvDepth(texture.kind),
                .arrayed = spirvArrayed(texture.kind),
                .multisampled = spirvMultisampled(texture.kind),
                .sampled = spirvSampled(texture.kind),
                .image_format = spirvImageFormat(texture.texel_format),
            } });
        },
        .atomic_type => |atomic| try spv.emitType(atomic.elem_type),
        .@"struct" => spv.struct_map.get(inst) orelse try spv.emitStruct(inst),
        else => std.debug.panic("TODO: implement Air tag {s}", .{@tagName(spv.air.getInst(inst))}),
    };
}

fn emitStruct(spv: *SpirV, inst_idx: InstIndex) !IdRef {
    const inst = spv.air.getInst(inst_idx).@"struct";

    const member_list = spv.air.refToList(inst.members);
    var members = std.ArrayList(IdRef).init(spv.allocator);
    defer members.deinit();
    try members.ensureTotalCapacityPrecise(member_list.len);

    const id = spv.allocId();

    try spv.debugName(id, spv.air.getStr(inst.name));
    for (member_list, 0..) |member_inst_idx, i| {
        const member_inst = spv.air.getInst(member_inst_idx).struct_member;
        const member = try spv.emitType(member_inst.type);
        try spv.debugMemberName(id, i, spv.air.getStr(member_inst.name));
        members.appendAssumeCapacity(member);
    }

    try spv.global_section.emit(.OpTypeStruct, .{
        .id_result = id,
        .id_ref = members.items,
    });

    try spv.struct_map.put(spv.allocator, inst_idx, id);

    return id;
}

fn emitStatement(spv: *SpirV, section: *Section, inst_idx: InstIndex) error{OutOfMemory}!void {
    switch (spv.air.getInst(inst_idx)) {
        .@"var" => |@"var"| {
            const var_id = spv.decl_map.get(inst_idx).?.id;
            if (@"var".expr != .none) {
                try section.emit(.OpStore, .{
                    .pointer = var_id,
                    .object = try spv.emitExpr(section, @"var".expr),
                });
            }
        },
        .@"return" => |inst| {
            switch (spv.store_return) {
                .none => try spv.emitReturn(section, inst),
                .single => |store_return| {
                    try section.emit(.OpStore, .{
                        .pointer = store_return,
                        .object = try spv.emitExpr(section, inst),
                    });
                    try spv.emitReturn(section, .none);
                },
                .many => |store_return_items| {
                    // assume functions returns an struct
                    const base = try spv.emitExpr(section, inst);
                    for (store_return_items, 0..) |store_item, i| {
                        const id = spv.allocId();

                        try section.emit(.OpCompositeExtract, .{
                            .id_result_type = store_item.type,
                            .id_result = id,
                            .composite = base,
                            .indexes = &[_]u32{@intCast(i)},
                        });

                        try section.emit(.OpStore, .{
                            .pointer = store_item.ptr,
                            .object = id,
                        });
                    }
                    try spv.emitReturn(section, .none);
                    spv.allocator.free(store_return_items);
                },
            }
        },
        .call => |inst| _ = try spv.emitCall(section, inst),
        .@"if" => |@"if"| try spv.emitIf(section, @"if"),
        .@"for" => |@"for"| try spv.emitFor(section, @"for"),
        .@"while" => |@"while"| try spv.emitWhile(section, @"while"),
        .loop => |loop| try spv.emitLoop(section, loop),
        .@"break" => try spv.emitBreak(section),
        .@"continue" => try spv.emitContinue(section),
        .assign => |assign| try spv.emitAssign(section, assign),
        .block => |block| if (block != .none) try spv.emitBlock(section, block),
        else => std.debug.panic("TODO: implement Air tag {s}", .{@tagName(spv.air.getInst(inst_idx))}),
    }
}

fn emitBlock(spv: *SpirV, section: *Section, block: RefIndex) !void {
    const parent_block = spv.current_block;
    spv.current_block = block;
    for (spv.air.refToList(block)) |statement| {
        try spv.emitStatement(section, statement);
    }
    spv.current_block = parent_block;
}

fn emitIf(spv: *SpirV, section: *Section, inst: Inst.If) !void {
    const if_label = spv.allocId();
    const true_label = spv.allocId();
    const false_label = spv.allocId();
    const merge_label = spv.allocId();

    try section.emit(.OpBranch, .{ .target_label = if_label });

    try section.emit(.OpLabel, .{ .id_result = if_label });
    const cond = try spv.emitExpr(section, inst.cond);
    try section.emit(.OpSelectionMerge, .{ .merge_block = merge_label, .selection_control = .{} });
    try section.emit(.OpBranchConditional, .{
        .condition = cond,
        .true_label = true_label,
        .false_label = false_label,
    });

    try section.emit(.OpLabel, .{ .id_result = true_label });
    if (inst.body != .none) {
        const body = spv.air.getInst(inst.body).block;
        try spv.emitBlock(section, body);
        if (spv.branched.get(body) == null) {
            try section.emit(.OpBranch, .{ .target_label = merge_label });
        }
    } else {
        try section.emit(.OpBranch, .{ .target_label = merge_label });
    }

    try section.emit(.OpLabel, .{ .id_result = false_label });
    if (inst.@"else" != .none) {
        switch (spv.air.getInst(inst.@"else")) {
            .@"if" => |else_if| try spv.emitIf(section, else_if),
            .block => |else_body| if (else_body != .none) {
                try spv.emitBlock(section, else_body);
            },
            else => unreachable,
        }
    }
    try section.emit(.OpBranch, .{ .target_label = merge_label });

    try section.emit(.OpLabel, .{ .id_result = merge_label });
}

fn emitFor(spv: *SpirV, section: *Section, inst: Inst.For) !void {
    const for_label = spv.allocId();
    const header_label = spv.allocId();
    const true_label = spv.allocId();
    const false_label = spv.allocId();
    const continue_label = spv.allocId();
    const merge_label = spv.allocId();

    const parent_loop_merge_label = spv.loop_merge_label;
    const parent_loop_continue_label = spv.loop_continue_label;
    spv.loop_merge_label = merge_label;
    spv.loop_continue_label = continue_label;
    defer {
        spv.loop_merge_label = parent_loop_merge_label;
        spv.loop_continue_label = parent_loop_continue_label;
    }

    try spv.emitStatement(section, inst.init);
    try section.emit(.OpBranch, .{ .target_label = for_label });

    try section.emit(.OpLabel, .{ .id_result = for_label });
    try section.emit(.OpLoopMerge, .{
        .merge_block = merge_label,
        .continue_target = continue_label,
        // TODO: this operand must not be 0. otherwise spirv tools will complain
        .loop_control = .{ .Unroll = true },
    });
    try section.emit(.OpBranch, .{ .target_label = header_label });

    try section.emit(.OpLabel, .{ .id_result = header_label });
    const cond = try spv.emitExpr(section, inst.cond);
    try section.emit(.OpSelectionMerge, .{ .merge_block = true_label, .selection_control = .{} });
    try section.emit(.OpBranchConditional, .{
        .condition = cond,
        .true_label = false_label,
        .false_label = true_label,
    });

    try section.emit(.OpLabel, .{ .id_result = true_label });
    if (inst.body != .none) {
        const body = spv.air.getInst(inst.body).block;
        try spv.emitBlock(section, body);
        if (spv.branched.get(body) == null) {
            try section.emit(.OpBranch, .{ .target_label = merge_label });
        }
    } else {
        try section.emit(.OpBranch, .{ .target_label = merge_label });
    }

    try section.emit(.OpLabel, .{ .id_result = false_label });
    try section.emit(.OpBranch, .{ .target_label = merge_label });

    try section.emit(.OpLabel, .{ .id_result = continue_label });
    try spv.emitStatement(section, inst.update);
    try section.emit(.OpBranch, .{ .target_label = for_label });

    try section.emit(.OpLabel, .{ .id_result = merge_label });
}

fn emitWhile(spv: *SpirV, section: *Section, inst: Inst.While) !void {
    const while_label = spv.allocId();
    const header_label = spv.allocId();
    const true_label = spv.allocId();
    const false_label = spv.allocId();
    const continue_label = spv.allocId();
    const merge_label = spv.allocId();

    const parent_loop_merge_label = spv.loop_merge_label;
    const parent_loop_continue_label = spv.loop_continue_label;
    spv.loop_merge_label = merge_label;
    spv.loop_continue_label = continue_label;
    defer {
        spv.loop_merge_label = parent_loop_merge_label;
        spv.loop_continue_label = parent_loop_continue_label;
    }

    try section.emit(.OpBranch, .{ .target_label = while_label });

    try section.emit(.OpLabel, .{ .id_result = while_label });
    try section.emit(.OpLoopMerge, .{
        .merge_block = merge_label,
        .continue_target = continue_label,
        // TODO: this operand must not be 0. otherwise spirv tools will complain
        .loop_control = .{ .Unroll = true },
    });
    try section.emit(.OpBranch, .{ .target_label = header_label });

    try section.emit(.OpLabel, .{ .id_result = header_label });
    const cond = try spv.emitExpr(section, inst.cond);
    try section.emit(.OpSelectionMerge, .{ .merge_block = true_label, .selection_control = .{} });
    try section.emit(.OpBranchConditional, .{
        .condition = cond,
        .true_label = false_label,
        .false_label = true_label,
    });

    try section.emit(.OpLabel, .{ .id_result = true_label });
    if (inst.body != .none) {
        const body = spv.air.getInst(inst.body).block;
        try spv.emitBlock(section, body);
        if (spv.branched.get(body) == null) {
            try section.emit(.OpBranch, .{ .target_label = merge_label });
        }
    } else {
        try section.emit(.OpBranch, .{ .target_label = merge_label });
    }

    try section.emit(.OpLabel, .{ .id_result = false_label });
    try section.emit(.OpBranch, .{ .target_label = merge_label });

    try section.emit(.OpLabel, .{ .id_result = continue_label });
    try section.emit(.OpBranch, .{ .target_label = while_label });

    try section.emit(.OpLabel, .{ .id_result = merge_label });
}

fn emitLoop(spv: *SpirV, section: *Section, body_inst: InstIndex) !void {
    if (body_inst == .none) return;

    const loop_label = spv.allocId();
    const body_label = spv.allocId();
    const continue_label = spv.allocId();
    const merge_label = spv.allocId();

    const parent_loop_merge_label = spv.loop_merge_label;
    const parent_loop_continue_label = spv.loop_continue_label;
    spv.loop_merge_label = merge_label;
    spv.loop_continue_label = continue_label;
    defer {
        spv.loop_merge_label = parent_loop_merge_label;
        spv.loop_continue_label = parent_loop_continue_label;
    }

    try section.emit(.OpBranch, .{ .target_label = loop_label });

    try section.emit(.OpLabel, .{ .id_result = loop_label });
    try section.emit(.OpLoopMerge, .{
        .merge_block = merge_label,
        .continue_target = continue_label,
        // TODO: this operand must not be 0. otherwise spirv tools will complain
        .loop_control = .{ .Unroll = true },
    });
    try section.emit(.OpBranch, .{ .target_label = body_label });

    try section.emit(.OpLabel, .{ .id_result = body_label });
    const body = spv.air.getInst(body_inst).block;
    try spv.emitBlock(section, body);
    if (spv.branched.get(body) == null) {
        try section.emit(.OpBranch, .{ .target_label = continue_label });
    }

    try section.emit(.OpLabel, .{ .id_result = continue_label });
    try section.emit(.OpBranch, .{ .target_label = loop_label });

    try section.emit(.OpLabel, .{ .id_result = merge_label });
}

fn emitBreak(spv: *SpirV, section: *Section) !void {
    try section.emit(.OpBranch, .{ .target_label = spv.loop_merge_label.? });
    try spv.branched.put(spv.allocator, spv.current_block, {});
}

fn emitContinue(spv: *SpirV, section: *Section) !void {
    try section.emit(.OpBranch, .{ .target_label = spv.loop_continue_label.? });
    try spv.branched.put(spv.allocator, spv.current_block, {});
}

fn emitAssign(spv: *SpirV, section: *Section, inst: Inst.Assign) !void {
    const decl = try spv.accessPtr(section, inst.lhs);

    const expr = blk: {
        const op: Inst.Binary.Op = switch (inst.mod) {
            .none => break :blk try spv.emitExpr(section, inst.rhs),
            .add => .add,
            .sub => .sub,
            .mul => .mul,
            .div => .div,
            .mod => .mod,
            .@"and" => .@"and",
            .@"or" => .@"or",
            .xor => .xor,
            .shl => .shl,
            .shr => .shr,
        };
        break :blk try spv.emitBinary(section, .{
            .op = op,
            .result_type = inst.type,
            .lhs_type = inst.type,
            .rhs_type = inst.type,
            .lhs = inst.lhs,
            .rhs = inst.rhs,
        });
    };

    try section.emit(.OpStore, .{
        .pointer = decl.id,
        .object = expr,
    });
}

fn emitReturn(spv: *SpirV, section: *Section, inst: InstIndex) !void {
    try spv.branched.put(spv.allocator, spv.current_block, {});
    if (inst == .none) return section.emit(.OpReturn, {});
    try section.emit(.OpReturnValue, .{ .value = try spv.emitExpr(section, inst) });
}

fn emitExpr(spv: *SpirV, section: *Section, inst: InstIndex) error{OutOfMemory}!IdRef {
    return switch (spv.air.getInst(inst)) {
        .bool => |boolean| spv.emitBool(section, boolean),
        .int => |int| spv.emitInt(section, int),
        .float => |float| spv.emitFloat(section, float),
        .vector => |vector| spv.emitVector(section, vector),
        .matrix => |matrix| spv.emitMatrix(section, matrix),
        .array => |array| spv.emitArray(section, array),
        .call => |call| spv.emitCall(section, call),
        .swizzle_access => |swizzle_access| spv.emitSwizzleAccess(section, swizzle_access),
        .var_ref => |var_ref| {
            const va = try spv.emitVarAccess(section, var_ref);
            const load_id = spv.allocId();
            try section.emit(.OpLoad, .{
                .id_result_type = va.type.elem_type,
                .id_result = load_id,
                .pointer = va.id,
            });
            return load_id;
        },
        .index_access => |index_access| {
            if (spv.air.resolveConstExpr(index_access.index)) |const_expr| {
                const composite = try spv.accessPtr(section, index_access.base);
                const type_id = try spv.emitType(index_access.type);
                const id = spv.allocId();
                try section.emit(.OpCompositeExtract, .{
                    .id_result_type = type_id,
                    .id_result = id,
                    .composite = composite.id,
                    .indexes = &[_]u32{@intCast(const_expr.int)},
                });
                return id;
            }

            const ia = try spv.emitIndexAccess(section, index_access);
            const load_id = spv.allocId();
            try section.emit(.OpLoad, .{
                .id_result_type = ia.type.elem_type,
                .id_result = load_id,
                .pointer = ia.id,
            });
            return load_id;
        },
        .field_access => |field_access| {
            const fa = try spv.emitFieldAccess(section, field_access);

            const load_id = spv.allocId();
            try section.emit(.OpLoad, .{
                .id_result_type = fa.type.elem_type,
                .id_result = load_id,
                .pointer = fa.id,
            });
            return load_id;
        },
        .binary => |bin| spv.emitBinary(section, bin),
        .unary => |un| spv.emitUnary(section, un),
        .unary_intrinsic => |un| spv.emitUnaryIntrinsic(section, un),
        .binary_intrinsic => |bin| spv.emitBinaryIntrinsic(section, bin),
        .triple_intrinsic => |bin| spv.emitTripleIntrinsic(section, bin),
        .texture_sample => |ts| spv.emitTextureSample(section, ts),
        else => std.debug.panic("TODO: implement Air tag {s}", .{@tagName(spv.air.getInst(inst))}),
    };
}

const PtrAccess = struct {
    id: IdRef,
    type: Key.PointerType,
};

fn emitVarAccess(spv: *SpirV, section: *Section, inst: InstIndex) !PtrAccess {
    const decl = spv.decl_map.get(inst).?;

    if (decl.faked_struct) {
        const id = spv.allocId();
        const index_id = try spv.resolve(.{ .int = .{ .type = .u32, .value = 0 } });
        const type_id = try spv.resolve(.{ .ptr_type = .{
            .storage_class = .Uniform,
            .elem_type = decl.type_id,
        } });
        try section.emit(.OpAccessChain, .{
            .id_result_type = type_id,
            .id_result = id,
            .base = decl.id,
            .indexes = &.{index_id},
        });

        return .{
            .id = id,
            .type = .{
                .elem_type = decl.type_id,
                .storage_class = decl.storage_class,
            },
        };
    }

    return .{
        .id = decl.id,
        .type = .{
            .elem_type = decl.type_id,
            .storage_class = decl.storage_class,
        },
    };
}

fn emitSwizzleAccess(spv: *SpirV, section: *Section, inst: Inst.SwizzleAccess) !IdRef {
    if (spv.air.resolveConstExpr(inst.base)) |_| {
        const swizzles = try spv.extractSwizzle(&spv.global_section, inst);
        defer spv.allocator.free(swizzles);

        if (inst.size == .one) {
            const single_swizzle = swizzles[0];
            return single_swizzle;
        }

        return spv.resolve(.{
            .vector = .{
                .type = try spv.resolve(.{
                    .vector_type = .{
                        .elem_type = try spv.emitType(inst.type),
                        .size = @enumFromInt(@intFromEnum(inst.size)),
                    },
                }),
                .value = swizzles,
            },
        });
    }

    const swizzles = try spv.extractSwizzle(section, inst);
    defer spv.allocator.free(swizzles);

    if (inst.size == .one) {
        const single_swizzle = swizzles[0];
        return single_swizzle;
    }

    const vec_ty = try spv.resolve(.{ .vector_type = .{
        .elem_type = try spv.emitType(inst.type),
        .size = @enumFromInt(@intFromEnum(inst.size)),
    } });

    const id = spv.allocId();
    try section.emit(.OpCompositeConstruct, .{
        .id_result_type = vec_ty,
        .id_result = id,
        .constituents = swizzles,
    });
    return id;
}

fn extractSwizzle(spv: *SpirV, section: *Section, inst: Inst.SwizzleAccess) ![]const IdRef {
    var swizzles = try spv.allocator.alloc(IdRef, @intFromEnum(inst.size));
    for (swizzles, 0..) |*id, i| {
        id.* = spv.allocId();
        try section.emit(.OpCompositeExtract, .{
            .id_result_type = try spv.emitType(inst.type),
            .id_result = id.*,
            .composite = try spv.emitExpr(section, inst.base),
            .indexes = &.{@intFromEnum(inst.pattern[i])},
        });
    }
    return swizzles;
}

fn emitIndexAccess(spv: *SpirV, section: *Section, inst: Inst.IndexAccess) !PtrAccess {
    const type_id = try spv.emitType(inst.type);
    const base_ptr = try spv.accessPtr(section, inst.base);

    const indexes: []const IdResult = blk: {
        const index = try spv.emitExpr(section, inst.index);

        if (spv.air.getInst(inst.base) == .var_ref) {
            if (base_ptr.type.storage_class == .StorageBuffer) {
                const uint0 = try spv.resolve(.{ .int = .{ .type = .u32, .value = 0 } });
                break :blk &.{ uint0, index };
            }
        }

        break :blk &.{index};
    };

    const id = spv.allocId();
    try section.emit(.OpAccessChain, .{
        .id_result_type = try spv.resolve(.{ .ptr_type = .{
            .elem_type = type_id,
            .storage_class = base_ptr.type.storage_class,
        } }),
        .id_result = id,
        .base = base_ptr.id,
        .indexes = indexes,
    });

    return .{
        .id = id,
        .type = .{
            .elem_type = type_id,
            .storage_class = base_ptr.type.storage_class,
        },
    };
}

fn emitFieldAccess(spv: *SpirV, section: *Section, inst: Inst.FieldAccess) !PtrAccess {
    const struct_member = spv.air.getInst(inst.field).struct_member;
    const type_id = try spv.emitType(struct_member.type);
    const base_decl = try spv.accessPtr(section, inst.base);

    const id = spv.allocId();
    const index_id = try spv.resolve(.{ .int = .{
        .type = .u32,
        .value = struct_member.index,
    } });
    try section.emit(.OpAccessChain, .{
        .id_result_type = try spv.resolve(.{
            .ptr_type = .{
                .elem_type = type_id,
                .storage_class = base_decl.type.storage_class,
            },
        }),
        .id_result = id,
        .base = base_decl.id,
        .indexes = &.{index_id},
    });

    return .{
        .id = id,
        .type = .{
            .elem_type = type_id,
            .storage_class = base_decl.type.storage_class,
        },
    };
}

fn emitBinary(spv: *SpirV, section: *Section, binary: Inst.Binary) !IdRef {
    const id = spv.allocId();
    const type_id = try spv.emitType(binary.result_type);
    const lhs_res = spv.air.getInst(binary.lhs_type);
    var rhs_res = spv.air.getInst(binary.rhs_type);
    const lhs = try spv.emitExpr(section, binary.lhs);
    const rhs = try spv.emitExpr(section, binary.rhs);

    switch (lhs_res) {
        .bool => switch (binary.op) {
            .equal => try section.emit(.OpLogicalEqual, .{
                .id_result = id,
                .id_result_type = type_id,
                .operand_1 = lhs,
                .operand_2 = rhs,
            }),
            .not_equal => try section.emit(.OpLogicalNotEqual, .{
                .id_result = id,
                .id_result_type = type_id,
                .operand_1 = lhs,
                .operand_2 = rhs,
            }),
            .logical_and => try section.emit(.OpLogicalAnd, .{
                .id_result = id,
                .id_result_type = type_id,
                .operand_1 = lhs,
                .operand_2 = rhs,
            }),
            .logical_or => try section.emit(.OpLogicalOr, .{
                .id_result = id,
                .id_result_type = type_id,
                .operand_1 = lhs,
                .operand_2 = rhs,
            }),
            else => unreachable,
        },
        .int => |int| switch (binary.op) {
            .mul => try section.emit(.OpIMul, .{
                .id_result = id,
                .id_result_type = type_id,
                .operand_1 = lhs,
                .operand_2 = rhs,
            }),
            .add => try section.emit(.OpIAdd, .{
                .id_result = id,
                .id_result_type = type_id,
                .operand_1 = lhs,
                .operand_2 = rhs,
            }),
            .sub => try section.emit(.OpISub, .{
                .id_result = id,
                .id_result_type = type_id,
                .operand_1 = lhs,
                .operand_2 = rhs,
            }),
            .shl => try section.emit(.OpShiftLeftLogical, .{
                .id_result = id,
                .id_result_type = type_id,
                .base = lhs,
                .shift = rhs,
            }),
            .shr => try section.emit(.OpShiftRightLogical, .{
                .id_result = id,
                .id_result_type = type_id,
                .base = lhs,
                .shift = rhs,
            }),
            .@"and" => try section.emit(.OpBitwiseAnd, .{
                .id_result = id,
                .id_result_type = type_id,
                .operand_1 = lhs,
                .operand_2 = rhs,
            }),
            .@"or" => try section.emit(.OpBitwiseOr, .{
                .id_result = id,
                .id_result_type = type_id,
                .operand_1 = lhs,
                .operand_2 = rhs,
            }),
            .xor => try section.emit(.OpBitwiseXor, .{
                .id_result = id,
                .id_result_type = type_id,
                .operand_1 = lhs,
                .operand_2 = rhs,
            }),
            .equal => try section.emit(.OpIEqual, .{
                .id_result = id,
                .id_result_type = type_id,
                .operand_1 = lhs,
                .operand_2 = rhs,
            }),
            .not_equal => try section.emit(.OpINotEqual, .{
                .id_result = id,
                .id_result_type = type_id,
                .operand_1 = lhs,
                .operand_2 = rhs,
            }),
            else => switch (int.type) {
                .i32 => switch (binary.op) {
                    .div => try section.emit(.OpSDiv, .{
                        .id_result = id,
                        .id_result_type = type_id,
                        .operand_1 = lhs,
                        .operand_2 = rhs,
                    }),
                    .mod => try section.emit(.OpSMod, .{
                        .id_result = id,
                        .id_result_type = type_id,
                        .operand_1 = lhs,
                        .operand_2 = rhs,
                    }),
                    .less_than => try section.emit(.OpSLessThan, .{
                        .id_result = id,
                        .id_result_type = type_id,
                        .operand_1 = lhs,
                        .operand_2 = rhs,
                    }),
                    .greater_than => try section.emit(.OpSGreaterThan, .{
                        .id_result = id,
                        .id_result_type = type_id,
                        .operand_1 = lhs,
                        .operand_2 = rhs,
                    }),
                    .greater_than_equal => try section.emit(.OpSGreaterThanEqual, .{
                        .id_result = id,
                        .id_result_type = type_id,
                        .operand_1 = lhs,
                        .operand_2 = rhs,
                    }),
                    else => unreachable,
                },
                .u32 => switch (binary.op) {
                    .div => try section.emit(.OpUDiv, .{
                        .id_result = id,
                        .id_result_type = type_id,
                        .operand_1 = lhs,
                        .operand_2 = rhs,
                    }),
                    .mod => try section.emit(.OpUMod, .{
                        .id_result = id,
                        .id_result_type = type_id,
                        .operand_1 = lhs,
                        .operand_2 = rhs,
                    }),
                    .less_than => try section.emit(.OpULessThan, .{
                        .id_result = id,
                        .id_result_type = type_id,
                        .operand_1 = lhs,
                        .operand_2 = rhs,
                    }),
                    .greater_than => try section.emit(.OpUGreaterThan, .{
                        .id_result = id,
                        .id_result_type = type_id,
                        .operand_1 = lhs,
                        .operand_2 = rhs,
                    }),
                    .greater_than_equal => try section.emit(.OpUGreaterThanEqual, .{
                        .id_result = id,
                        .id_result_type = type_id,
                        .operand_1 = lhs,
                        .operand_2 = rhs,
                    }),
                    else => unreachable,
                },
            },
        },
        .float => switch (binary.op) {
            .mul => switch (rhs_res) {
                .vector => try section.emit(.OpVectorTimesScalar, .{
                    .id_result = id,
                    .id_result_type = type_id,
                    .vector = rhs,
                    .scalar = lhs,
                }),
                .float => try section.emit(.OpFMul, .{
                    .id_result = id,
                    .id_result_type = type_id,
                    .operand_1 = lhs,
                    .operand_2 = rhs,
                }),
                else => unreachable,
            },
            .div => try section.emit(.OpFDiv, .{
                .id_result = id,
                .id_result_type = type_id,
                .operand_1 = lhs,
                .operand_2 = rhs,
            }),
            .mod => try section.emit(.OpFMod, .{
                .id_result = id,
                .id_result_type = type_id,
                .operand_1 = lhs,
                .operand_2 = rhs,
            }),
            .add => try section.emit(.OpFAdd, .{
                .id_result = id,
                .id_result_type = type_id,
                .operand_1 = lhs,
                .operand_2 = rhs,
            }),
            .sub => try section.emit(.OpFSub, .{
                .id_result = id,
                .id_result_type = type_id,
                .operand_1 = lhs,
                .operand_2 = rhs,
            }),
            .equal => try section.emit(.OpFOrdEqual, .{
                .id_result = id,
                .id_result_type = type_id,
                .operand_1 = lhs,
                .operand_2 = rhs,
            }),
            .not_equal => try section.emit(.OpFOrdNotEqual, .{
                .id_result = id,
                .id_result_type = type_id,
                .operand_1 = lhs,
                .operand_2 = rhs,
            }),
            .less_than => try section.emit(.OpFOrdLessThan, .{
                .id_result = id,
                .id_result_type = type_id,
                .operand_1 = lhs,
                .operand_2 = rhs,
            }),
            .greater_than => try section.emit(.OpFOrdGreaterThan, .{
                .id_result = id,
                .id_result_type = type_id,
                .operand_1 = lhs,
                .operand_2 = rhs,
            }),
            .greater_than_equal => try section.emit(.OpFOrdGreaterThanEqual, .{
                .id_result = id,
                .id_result_type = type_id,
                .operand_1 = lhs,
                .operand_2 = rhs,
            }),
            else => unreachable,
        },
        .vector => switch (binary.op) {
            .mul => switch (rhs_res) {
                .int, .float => try section.emit(.OpVectorTimesScalar, .{
                    .id_result = id,
                    .id_result_type = type_id,
                    .vector = lhs,
                    .scalar = rhs,
                }),
                .matrix => try section.emit(.OpVectorTimesMatrix, .{
                    .id_result = id,
                    .id_result_type = type_id,
                    .vector = lhs,
                    .matrix = rhs,
                }),
                else => unreachable,
            },
            .div => switch (rhs_res) {
                .float => {
                    const constructed_float_id = spv.allocId();
                    var constituents = std.BoundedArray(IdRef, 4).init(@intFromEnum(lhs_res.vector.size)) catch unreachable;
                    @memset(constituents.slice(), rhs);

                    try section.emit(.OpCompositeConstruct, .{
                        .id_result = constructed_float_id,
                        .id_result_type = type_id,
                        .constituents = constituents.slice(),
                    });

                    try section.emit(.OpFDiv, .{
                        .id_result = id,
                        .id_result_type = type_id,
                        .operand_1 = lhs,
                        .operand_2 = constructed_float_id,
                    });
                },
                .int => |int| {
                    const constructed_int_id = spv.allocId();
                    var constituents = std.BoundedArray(IdRef, 4).init(@intFromEnum(lhs_res.vector.size)) catch unreachable;
                    @memset(constituents.slice(), rhs);

                    try section.emit(.OpCompositeConstruct, .{
                        .id_result = constructed_int_id,
                        .id_result_type = type_id,
                        .constituents = constituents.slice(),
                    });

                    switch (int.type) {
                        .u32 => try section.emit(.OpUDiv, .{
                            .id_result = id,
                            .id_result_type = type_id,
                            .operand_1 = lhs,
                            .operand_2 = constructed_int_id,
                        }),
                        .i32 => try section.emit(.OpSDiv, .{
                            .id_result = id,
                            .id_result_type = type_id,
                            .operand_1 = lhs,
                            .operand_2 = constructed_int_id,
                        }),
                    }
                },
                .vector => |vec| switch (spv.air.getInst(vec.elem_type)) {
                    .int => |int| switch (int.type) {
                        .u32 => try section.emit(.OpUDiv, .{
                            .id_result = id,
                            .id_result_type = type_id,
                            .operand_1 = lhs,
                            .operand_2 = rhs,
                        }),
                        .i32 => try section.emit(.OpSDiv, .{
                            .id_result = id,
                            .id_result_type = type_id,
                            .operand_1 = lhs,
                            .operand_2 = rhs,
                        }),
                    },
                    .float => try section.emit(.OpFDiv, .{
                        .id_result = id,
                        .id_result_type = type_id,
                        .operand_1 = lhs,
                        .operand_2 = rhs,
                    }),
                    else => unreachable,
                },
                else => unreachable,
            },
            .add => switch (rhs_res) {
                .int => {
                    const constructed_float_id = spv.allocId();
                    var constituents = std.BoundedArray(IdRef, 4).init(@intFromEnum(lhs_res.vector.size)) catch unreachable;
                    @memset(constituents.slice(), rhs);

                    try section.emit(.OpCompositeConstruct, .{
                        .id_result = constructed_float_id,
                        .id_result_type = type_id,
                        .constituents = constituents.slice(),
                    });

                    try section.emit(.OpIAdd, .{
                        .id_result = id,
                        .id_result_type = type_id,
                        .operand_1 = lhs,
                        .operand_2 = constructed_float_id,
                    });
                },
                .float => {
                    const constructed_float_id = spv.allocId();
                    var constituents = std.BoundedArray(IdRef, 4).init(@intFromEnum(lhs_res.vector.size)) catch unreachable;
                    @memset(constituents.slice(), rhs);

                    try section.emit(.OpCompositeConstruct, .{
                        .id_result = constructed_float_id,
                        .id_result_type = type_id,
                        .constituents = constituents.slice(),
                    });

                    try section.emit(.OpFAdd, .{
                        .id_result = id,
                        .id_result_type = type_id,
                        .operand_1 = lhs,
                        .operand_2 = constructed_float_id,
                    });
                },
                .vector => |vec| switch (spv.air.getInst(vec.elem_type)) {
                    .int => try section.emit(.OpIAdd, .{
                        .id_result = id,
                        .id_result_type = type_id,
                        .operand_1 = lhs,
                        .operand_2 = rhs,
                    }),
                    .float => try section.emit(.OpFAdd, .{
                        .id_result = id,
                        .id_result_type = type_id,
                        .operand_1 = lhs,
                        .operand_2 = rhs,
                    }),
                    else => unreachable,
                },
                else => unreachable,
            },
            .sub => switch (rhs_res) {
                .int => {
                    const constructed_float_id = spv.allocId();
                    var constituents = std.BoundedArray(IdRef, 4).init(@intFromEnum(lhs_res.vector.size)) catch unreachable;
                    @memset(constituents.slice(), rhs);

                    try section.emit(.OpCompositeConstruct, .{
                        .id_result = constructed_float_id,
                        .id_result_type = type_id,
                        .constituents = constituents.slice(),
                    });

                    try section.emit(.OpISub, .{
                        .id_result = id,
                        .id_result_type = type_id,
                        .operand_1 = lhs,
                        .operand_2 = constructed_float_id,
                    });
                },
                .float => {
                    const constructed_float_id = spv.allocId();
                    var constituents = std.BoundedArray(IdRef, 4).init(@intFromEnum(lhs_res.vector.size)) catch unreachable;
                    @memset(constituents.slice(), rhs);

                    try section.emit(.OpCompositeConstruct, .{
                        .id_result = constructed_float_id,
                        .id_result_type = type_id,
                        .constituents = constituents.slice(),
                    });

                    try section.emit(.OpFSub, .{
                        .id_result = id,
                        .id_result_type = type_id,
                        .operand_1 = lhs,
                        .operand_2 = constructed_float_id,
                    });
                },
                .vector => try section.emit(.OpFSub, .{
                    .id_result = id,
                    .id_result_type = type_id,
                    .operand_1 = lhs,
                    .operand_2 = rhs,
                }),
                else => unreachable,
            },
            else => unreachable,
        },
        .matrix => switch (binary.op) {
            .mul => switch (rhs_res) {
                .matrix => try section.emit(.OpFMul, .{
                    .id_result = id,
                    .id_result_type = type_id,
                    .operand_1 = lhs,
                    .operand_2 = rhs,
                }),
                .vector => try section.emit(.OpMatrixTimesVector, .{
                    .id_result = id,
                    .id_result_type = type_id,
                    .matrix = lhs,
                    .vector = rhs,
                }),
                .float => {
                    const constructed_float_id = spv.allocId();
                    const size = @as(u8, @intCast(@intFromEnum(lhs_res.matrix.cols))) * @intFromEnum(lhs_res.matrix.rows);
                    var constituents = std.BoundedArray(IdRef, 16).init(size) catch unreachable;
                    @memset(constituents.slice(), rhs);

                    try section.emit(.OpCompositeConstruct, .{
                        .id_result = constructed_float_id,
                        .id_result_type = type_id,
                        .constituents = constituents.slice(),
                    });

                    try section.emit(.OpFMul, .{
                        .id_result = id,
                        .id_result_type = type_id,
                        .operand_1 = lhs,
                        .operand_2 = constructed_float_id,
                    });
                },
                else => unreachable,
            },
            .add => try section.emit(.OpFAdd, .{
                .id_result = id,
                .id_result_type = type_id,
                .operand_1 = lhs,
                .operand_2 = rhs,
            }),
            else => unreachable,
        },
        else => unreachable,
    }

    return id;
}

fn emitUnary(spv: *SpirV, section: *Section, unary: Inst.Unary) !IdRef {
    switch (unary.op) {
        .negate => {
            const id = spv.allocId();
            const expr = try spv.emitExpr(section, unary.expr);
            const result_type = try spv.emitType(unary.result_type);

            switch (spv.air.getInst(unary.result_type)) {
                .int => try section.emit(.OpSNegate, .{
                    .id_result_type = result_type,
                    .id_result = id,
                    .operand = expr,
                }),
                .float => try section.emit(.OpFNegate, .{
                    .id_result_type = result_type,
                    .id_result = id,
                    .operand = expr,
                }),
                else => unreachable,
            }

            return id;
        },
        .addr_of => return (try spv.accessPtr(section, unary.expr)).id,
        else => unreachable,
    }
}

fn emitUnaryIntrinsic(spv: *SpirV, section: *Section, unary: Inst.UnaryIntrinsic) !IdRef {
    const id = spv.allocId();
    const expr = try spv.emitExpr(section, unary.expr);
    const result_type = try spv.emitType(unary.result_type);

    const instruction: Word = switch (unary.op) {
        .array_length => {
            // TODO: this is hacky af
            var struct_ty_id: IdRef = undefined;
            var struct_map_iter = spv.struct_map.iterator();
            while (struct_map_iter.next()) |entry| {
                const struct_inst = spv.air.getInst(entry.key_ptr.*).@"struct";
                const members = spv.air.refToList(struct_inst.members);
                if (members.len == 1) {
                    const first_member = spv.air.getInst(members[0]).struct_member;
                    const first_member_ty = spv.air.getInst(first_member.type);
                    if (first_member_ty == .array and first_member_ty.array.len == .none) {
                        struct_ty_id = entry.value_ptr.*;
                        break;
                    }
                }
            } else unreachable;

            const struct_ptr_type_id = try spv.resolve(.{ .ptr_type = .{
                .storage_class = .Function,
                .elem_type = struct_ty_id,
            } });
            const struct_casted_id = spv.allocId();
            try section.emit(.OpBitcast, .{
                .id_result_type = struct_ptr_type_id,
                .id_result = struct_casted_id,
                .operand = expr,
            });
            try section.emit(.OpArrayLength, .{
                .id_result_type = result_type,
                .id_result = id,
                .structure = struct_casted_id,
                .array_member = 0,
            });
            return id;
        },
        .sin => 13,
        .cos => 14,
        .normalize => 69,
        .length => 66,
        else => std.debug.panic("TODO: implement Unary Intrinsic {s}", .{@tagName(unary.op)}),
    };

    try section.emit(.OpExtInst, .{
        .id_result_type = result_type,
        .id_result = id,
        .set = spv.importExtInst(),
        .instruction = .{ .inst = instruction },
        .id_ref_4 = &.{expr},
    });
    return id;
}

fn emitBinaryIntrinsic(spv: *SpirV, section: *Section, bin: Inst.BinaryIntrinsic) !IdRef {
    const id = spv.allocId();
    const lhs = try spv.emitExpr(section, bin.lhs);
    const rhs = try spv.emitExpr(section, bin.rhs);
    const result_type = try spv.emitType(bin.result_type);
    const result_type_inst = switch (spv.air.getInst(bin.result_type)) {
        .vector => |vec| spv.air.getInst(vec.elem_type),
        else => |ty| ty,
    };

    const instruction: Word = switch (bin.op) {
        .min => switch (result_type_inst) {
            .float => 37,
            .int => |int| switch (int.type) {
                .u32 => 38,
                .i32 => 39,
            },
            else => unreachable,
        },
        .max => switch (result_type_inst) {
            .float => 40,
            .int => |int| switch (int.type) {
                .u32 => 41,
                .i32 => 42,
            },
            else => unreachable,
        },
        .atan2 => 25,
        .distance => 67,
        else => std.debug.panic("TODO: implement Binary Intrinsic {s}", .{@tagName(bin.op)}),
    };

    try section.emit(.OpExtInst, .{
        .id_result_type = result_type,
        .id_result = id,
        .set = spv.importExtInst(),
        .instruction = .{ .inst = instruction },
        .id_ref_4 = &.{ lhs, rhs },
    });

    return id;
}

fn emitTripleIntrinsic(spv: *SpirV, section: *Section, bin: Inst.TripleIntrinsic) !IdRef {
    const id = spv.allocId();
    const a1 = try spv.emitExpr(section, bin.a1);
    const a2 = try spv.emitExpr(section, bin.a2);
    const a3 = try spv.emitExpr(section, bin.a3);
    const result_type = try spv.emitType(bin.result_type);
    const result_type_inst = switch (spv.air.getInst(bin.result_type)) {
        .vector => |vec| spv.air.getInst(vec.elem_type),
        else => |ty| ty,
    };

    const instruction: Word = switch (bin.op) {
        .mix => switch (result_type_inst) {
            .float => 46,
            .int => unreachable, // TODO
            else => unreachable,
        },
        .clamp => switch (result_type_inst) {
            .float => 43,
            .int => |int| switch (int.type) {
                .u32 => 44,
                .i32 => 45,
            },
            else => unreachable,
        },
        .smoothstep => 49,
    };

    try section.emit(.OpExtInst, .{
        .id_result_type = result_type,
        .id_result = id,
        .set = spv.importExtInst(),
        .instruction = .{ .inst = instruction },
        .id_ref_4 = &.{ a1, a2, a3 },
    });

    return id;
}

fn emitTextureSample(spv: *SpirV, section: *Section, ts: Inst.TextureSample) !IdRef {
    const image_id = spv.allocId();
    const loaded_image_id = spv.allocId();
    const texture = try spv.emitExpr(section, ts.texture);
    const sampler = try spv.emitExpr(section, ts.sampler);
    const coords = try spv.emitExpr(section, ts.coords);
    const result_type = try spv.emitType(ts.result_type);
    const texture_type = try spv.emitType(ts.texture_type);
    const sampled_image_ty = try spv.resolve(.{ .sampled_image_type = texture_type });

    try section.emit(.OpSampledImage, .{
        .id_result_type = sampled_image_ty,
        .id_result = image_id,
        .image = texture,
        .sampler = sampler,
    });

    try section.emit(.OpImageSampleImplicitLod, .{
        .id_result_type = result_type,
        .id_result = loaded_image_id,
        .sampled_image = image_id,
        .coordinate = coords,
    });

    return loaded_image_id;
}

fn importExtInst(spv: *SpirV) IdRef {
    if (spv.extended_instructions) |id| return id;
    spv.extended_instructions = spv.allocId();
    return spv.extended_instructions.?;
}

fn accessPtr(spv: *SpirV, section: *Section, decl: InstIndex) error{OutOfMemory}!PtrAccess {
    switch (spv.air.getInst(decl)) {
        .var_ref => |var_ref| return spv.emitVarAccess(section, var_ref),
        .index_access => |index_access| return spv.emitIndexAccess(section, index_access),
        .field_access => |field_access| return spv.emitFieldAccess(section, field_access),
        .swizzle_access => |swizzle_access| {
            std.debug.assert(swizzle_access.size == .one);

            const id = spv.allocId();
            const index_id = try spv.resolve(.{ .int = .{
                .type = .u32,
                .value = @intFromEnum(swizzle_access.pattern[0]),
            } });
            const type_id = try spv.emitType(swizzle_access.type);
            const base = try spv.accessPtr(section, swizzle_access.base);
            const ptr_type_id = try spv.resolve(.{ .ptr_type = .{
                .storage_class = base.type.storage_class,
                .elem_type = type_id,
            } });
            try section.emit(.OpAccessChain, .{
                .id_result_type = ptr_type_id,
                .id_result = id,
                .base = base.id,
                .indexes = &.{index_id},
            });
            return .{
                .id = id,
                .type = .{ .storage_class = base.type.storage_class, .elem_type = type_id },
            };
        },
        else => unreachable,
    }
}

fn emitCall(spv: *SpirV, section: *Section, inst: Inst.FnCall) !IdRef {
    var args = std.ArrayList(IdRef).init(spv.allocator);
    defer args.deinit();

    if (inst.args != .none) {
        for (spv.air.refToList(inst.args)) |arg_inst_idx| {
            try args.append(try spv.emitExpr(section, arg_inst_idx));
        }
    }

    const id = spv.allocId();
    const function = if (spv.decl_map.get(inst.@"fn")) |decl| decl.id else try spv.emitFn(inst.@"fn");
    try section.emit(.OpFunctionCall, .{
        .id_result_type = try spv.emitType(spv.air.getInst(inst.@"fn").@"fn".return_type),
        .id_result = id,
        .function = function,
        .id_ref_3 = args.items,
    });

    return id;
}

fn emitBool(spv: *SpirV, section: *Section, boolean: Inst.Bool) !IdRef {
    return switch (boolean.value.?) {
        .literal => |lit| spv.resolve(.{ .bool = lit }),
        .cast => |cast| spv.emitBoolCast(section, cast),
    };
}

fn emitInt(spv: *SpirV, section: *Section, int: Inst.Int) !IdRef {
    return switch (spv.air.getValue(Inst.Int.Value, int.value.?)) {
        .literal => |lit| spv.resolve(.{ .int = .{ .type = int.type, .value = @bitCast(lit) } }),
        .cast => |cast| spv.emitIntCast(section, int.type, cast),
    };
}

fn emitFloat(spv: *SpirV, section: *Section, float: Inst.Float) !IdRef {
    return switch (spv.air.getValue(Inst.Float.Value, float.value.?)) {
        .literal => |lit| spv.resolve(.{ .float = .{ .type = float.type, .value = @bitCast(lit) } }),
        .cast => |cast| spv.emitFloatCast(section, float.type, cast),
    };
}

fn emitBoolCast(spv: *SpirV, section: *Section, cast: Inst.ScalarCast) !IdRef {
    const id = spv.allocId();
    const dest_type_id = try spv.resolve(.bool_type);
    const source_type = spv.air.getInst(cast.type);
    const value_id = try spv.emitExpr(section, cast.value);
    switch (source_type) {
        .int => |int| try section.emit(.OpINotEqual, .{
            .id_result_type = dest_type_id,
            .id_result = id,
            .operand_1 = try spv.resolve(.{ .null = try spv.resolve(.{ .int_type = int.type }) }),
            .operand_2 = value_id,
        }),
        .float => |float| try section.emit(.OpFUnordNotEqual, .{
            .id_result_type = dest_type_id,
            .id_result = id,
            .operand_1 = try spv.resolve(.{ .null = try spv.resolve(.{ .float_type = float.type }) }),
            .operand_2 = value_id,
        }),
        else => unreachable,
    }
    return id;
}

fn emitIntCast(spv: *SpirV, section: *Section, dest_type: Inst.Int.Type, cast: Inst.ScalarCast) !IdRef {
    const id = spv.allocId();
    const source_type = spv.air.getInst(cast.type);
    const dest_type_id = try spv.resolve(.{ .int_type = dest_type });
    const value_id = try spv.emitExpr(section, cast.value);
    switch (dest_type) {
        .i32 => switch (source_type) {
            .int => try section.emit(.OpUConvert, .{
                .id_result_type = dest_type_id,
                .id_result = id,
                .unsigned_value = value_id,
            }),
            .float => try section.emit(.OpConvertFToS, .{
                .id_result_type = dest_type_id,
                .id_result = id,
                .float_value = value_id,
            }),
            else => unreachable,
        },
        .u32 => switch (source_type) {
            .int => try section.emit(.OpSConvert, .{
                .id_result_type = dest_type_id,
                .id_result = id,
                .signed_value = value_id,
            }),
            .float => try section.emit(.OpConvertFToU, .{
                .id_result_type = dest_type_id,
                .id_result = id,
                .float_value = value_id,
            }),
            else => unreachable,
        },
    }
    return id;
}

fn emitFloatCast(spv: *SpirV, section: *Section, dest_type: Inst.Float.Type, cast: Inst.ScalarCast) !IdRef {
    const id = spv.allocId();
    const source_type = spv.air.getInst(cast.type);
    const dest_type_id = try spv.resolve(.{ .float_type = dest_type });
    const value_id = try spv.emitExpr(section, cast.value);
    switch (dest_type) {
        .f32, .f16 => switch (source_type) {
            .float => try section.emit(.OpFConvert, .{
                .id_result_type = dest_type_id,
                .id_result = id,
                .float_value = value_id,
            }),
            .int => |int| switch (int.type) {
                .u32 => try section.emit(.OpConvertUToF, .{
                    .id_result_type = dest_type_id,
                    .id_result = id,
                    .unsigned_value = value_id,
                }),
                .i32 => try section.emit(.OpConvertSToF, .{
                    .id_result_type = dest_type_id,
                    .id_result = id,
                    .signed_value = value_id,
                }),
            },
            else => unreachable,
        },
    }
    return id;
}

fn emitVector(spv: *SpirV, section: *Section, inst: Inst.Vector) !IdRef {
    const elem_type_key: Key = switch (spv.air.getInst(inst.elem_type)) {
        .bool => .bool_type,
        .float => |float| .{ .float_type = float.type },
        .int => |int| .{ .int_type = int.type },
        else => unreachable,
    };

    const type_id = try spv.resolve(.{
        .vector_type = .{
            .elem_type = try spv.resolve(elem_type_key),
            .size = inst.size,
        },
    });

    if (inst.value.? == .none) {
        return spv.resolve(.{ .null = type_id });
    }

    var constituents = std.ArrayList(IdRef).init(spv.allocator);
    defer constituents.deinit();

    try constituents.ensureTotalCapacityPrecise(@intFromEnum(inst.size));

    const value = spv.air.getValue(Inst.Vector.Value, inst.value.?);
    switch (value) {
        .literal => for (value.literal[0..@intFromEnum(inst.size)]) |elem_inst| {
            const elem_id = try spv.emitExpr(section, elem_inst);
            constituents.appendAssumeCapacity(elem_id);
        },
        .cast => |cast| for (cast.value[0..@intFromEnum(inst.size)]) |elem_inst| {
            const elem_id = switch (elem_type_key) {
                .float_type => |float| try spv.emitFloatCast(section, float, .{ .type = cast.type, .value = elem_inst }),
                .int_type => |int| try spv.emitIntCast(section, int, .{ .type = cast.type, .value = elem_inst }),
                else => unreachable,
            };
            constituents.appendAssumeCapacity(elem_id);
        },
    }

    const id = spv.allocId();
    try section.emit(.OpCompositeConstruct, .{
        .id_result_type = type_id,
        .id_result = id,
        .constituents = constituents.items,
    });
    return id;
}

fn emitMatrix(spv: *SpirV, section: *Section, inst: Inst.Matrix) !IdRef {
    const vec_elem_type_id = try spv.emitType(inst.elem_type);
    const elem_type_id = try spv.resolve(.{
        .vector_type = .{
            .elem_type = vec_elem_type_id,
            .size = inst.rows,
        },
    });
    const type_id = try spv.resolve(.{
        .matrix_type = .{
            .elem_type = elem_type_id,
            .cols = inst.cols,
        },
    });

    if (inst.value.? == .none) {
        return spv.resolve(.{ .null = type_id });
    }

    var constituents = std.ArrayList(IdRef).init(spv.allocator);
    defer constituents.deinit();
    try constituents.ensureTotalCapacityPrecise(@intFromEnum(inst.cols));

    const value = spv.air.getValue(Inst.Matrix.Value, inst.value.?);
    for (value[0..@intFromEnum(inst.cols)]) |elem_inst| {
        const elem_id = try spv.emitExpr(section, elem_inst);
        constituents.appendAssumeCapacity(elem_id);
    }

    const id = spv.allocId();
    try section.emit(.OpCompositeConstruct, .{
        .id_result_type = type_id,
        .id_result = id,
        .constituents = constituents.items,
    });
    return id;
}

fn emitArray(spv: *SpirV, section: *Section, inst: Inst.Array) !IdRef {
    const len = if (inst.len != .none) try spv.emitExpr(&spv.global_section, inst.len) else null;
    const type_id = try spv.resolve(.{
        .array_type = .{
            .elem_type = try spv.emitType(inst.elem_type),
            .len = len,
        },
    });

    if (inst.value.? == .none) {
        return spv.resolve(.{ .null = type_id });
    }

    const value = spv.air.refToList(inst.value.?);

    var constituents = std.ArrayList(IdRef).init(spv.allocator);
    defer constituents.deinit();
    try constituents.ensureTotalCapacityPrecise(value.len);

    for (value) |elem_inst| {
        const elem_id = try spv.emitExpr(section, elem_inst);
        constituents.appendAssumeCapacity(elem_id);
    }

    const id = spv.allocId();
    try section.emit(.OpCompositeConstruct, .{
        .id_result_type = type_id,
        .id_result = id,
        .constituents = constituents.items,
    });
    return id;
}

const Key = union(enum) {
    void_type,
    bool_type,
    sampler_type,
    int_type: Inst.Int.Type,
    float_type: Inst.Float.Type,
    vector_type: VectorType,
    matrix_type: MatrixType,
    array_type: ArrayType,
    ptr_type: PointerType,
    fn_type: FunctionType,
    texture_type: TextureType,
    sampled_image_type: IdRef,
    null: IdRef,
    bool: bool,
    int: Int,
    float: Float,
    vector: Vector,

    const VectorType = struct {
        size: Inst.Vector.Size,
        elem_type: IdRef,
    };

    const MatrixType = struct {
        cols: Inst.Vector.Size,
        elem_type: IdRef,
    };

    const ArrayType = struct {
        len: ?IdRef,
        elem_type: IdRef,
    };

    const PointerType = struct {
        storage_class: spec.StorageClass,
        elem_type: IdRef,
    };

    const FunctionType = struct {
        return_type: IdRef,
        params_type: []const IdRef,
    };

    const TextureType = struct {
        sampled_type: IdRef,
        dim: spec.Dim,
        depth: u2,
        arrayed: u1,
        multisampled: u1,
        sampled: u2,
        image_format: spec.ImageFormat,
    };

    const Int = struct {
        type: Inst.Int.Type,
        value: i64,
    };

    const Float = struct {
        type: Inst.Float.Type,
        value: u32,
    };

    const Vector = struct {
        type: IdRef,
        value: []const IdRef,
    };

    const Adapter = struct {
        pub fn hash(ctx: Adapter, key: Key) u32 {
            _ = ctx;
            var hasher = std.hash.XxHash32.init(0);
            std.hash.autoHashStrat(&hasher, key, std.hash.Strategy.Shallow);
            return hasher.final();
        }

        pub fn eql(ctx: Adapter, a: Key, b: Key, b_index: usize) bool {
            _ = ctx;
            _ = b_index;
            return std.meta.eql(a, b);
        }
    };
};

pub fn resolve(spv: *SpirV, key: Key) !IdRef {
    if (spv.type_value_map.get(key)) |value| return value;

    const id = spv.allocId();
    switch (key) {
        .void_type => try spv.global_section.emit(.OpTypeVoid, .{ .id_result = id }),
        .bool_type => try spv.global_section.emit(.OpTypeBool, .{ .id_result = id }),
        .int_type => |int| try spv.global_section.emit(.OpTypeInt, .{
            .id_result = id,
            .width = int.width(),
            .signedness = @intFromBool(int.signedness()),
        }),
        .float_type => |float| try spv.global_section.emit(.OpTypeFloat, .{
            .id_result = id,
            .width = float.width(),
        }),
        .vector_type => |vector| try spv.global_section.emit(.OpTypeVector, .{
            .id_result = id,
            .component_type = vector.elem_type,
            .component_count = @intFromEnum(vector.size),
        }),
        .matrix_type => |matrix| try spv.global_section.emit(.OpTypeMatrix, .{
            .id_result = id,
            .column_type = matrix.elem_type,
            .column_count = @intFromEnum(matrix.cols),
        }),
        .array_type => |array| {
            if (array.len) |len| {
                try spv.global_section.emit(.OpTypeArray, .{
                    .id_result = id,
                    .element_type = array.elem_type,
                    .length = len,
                });
            } else {
                try spv.global_section.emit(.OpTypeRuntimeArray, .{
                    .id_result = id,
                    .element_type = array.elem_type,
                });
            }
        },
        .ptr_type => |ptr_type| {
            try spv.global_section.emit(.OpTypePointer, .{
                .id_result = id,
                .storage_class = ptr_type.storage_class,
                .type = ptr_type.elem_type,
            });
        },
        .fn_type => |fn_type| {
            try spv.global_section.emit(.OpTypeFunction, .{
                .id_result = id,
                .return_type = fn_type.return_type,
                .id_ref_2 = fn_type.params_type,
            });
        },
        .null => |nil| {
            try spv.global_section.emit(.OpConstantNull, .{ .id_result_type = nil, .id_result = id });
        },
        .bool => |val| {
            const type_id = try spv.resolve(.bool_type);
            if (val) {
                try spv.global_section.emit(.OpConstantTrue, .{ .id_result_type = type_id, .id_result = id });
            } else {
                try spv.global_section.emit(.OpConstantFalse, .{ .id_result_type = type_id, .id_result = id });
            }
        },
        .int => |int| {
            const value: spec.LiteralContextDependentNumber = switch (int.type) {
                .u32 => .{ .uint32 = @intCast(int.value) },
                .i32 => .{ .int32 = @intCast(int.value) },
            };
            try spv.global_section.emit(.OpConstant, .{
                .id_result_type = try spv.resolve(.{ .int_type = int.type }),
                .id_result = id,
                .value = value,
            });
        },
        .float => |float| {
            const value: spec.LiteralContextDependentNumber = switch (float.type) {
                .f16 => .{ .uint32 = @as(u16, @bitCast(@as(f16, @floatCast(@as(f32, @bitCast(float.value)))))) },
                .f32 => .{ .float32 = @bitCast(float.value) },
            };
            try spv.global_section.emit(.OpConstant, .{
                .id_result_type = try spv.resolve(.{ .float_type = float.type }),
                .id_result = id,
                .value = value,
            });
        },
        .vector => |vector| {
            try spv.global_section.emit(.OpConstantComposite, .{
                .id_result_type = vector.type,
                .id_result = id,
                .constituents = vector.value,
            });
        },
        .sampler_type => try spv.global_section.emit(.OpTypeSampler, .{ .id_result = id }),
        .texture_type => |texture_type| try spv.global_section.emit(.OpTypeImage, .{
            .id_result = id,
            .sampled_type = texture_type.sampled_type,
            .dim = texture_type.dim,
            .depth = texture_type.depth,
            .arrayed = texture_type.arrayed,
            .ms = texture_type.multisampled,
            .sampled = texture_type.sampled,
            .image_format = texture_type.image_format,
        }),
        .sampled_image_type => |si| try spv.global_section.emit(.OpTypeSampledImage, .{
            .id_result = id,
            .image_type = si,
        }),
    }

    try spv.type_value_map.put(spv.allocator, key, id);
    return id;
}

fn debugName(spv: *SpirV, id: IdResult, name: []const u8) !void {
    if (spv.emit_debug_names) {
        try spv.debug_section.emit(.OpName, .{ .target = id, .name = name });
    }
}

fn debugMemberName(spv: *SpirV, struct_id: IdResult, index: usize, name: []const u8) !void {
    if (spv.emit_debug_names) {
        try spv.debug_section.emit(.OpMemberName, .{
            .type = struct_id,
            .member = @as(spec.LiteralInteger, @intCast(index)),
            .name = name,
        });
    }
}

fn allocId(spv: *SpirV) IdResult {
    defer spv.next_result_id += 1;
    return .{ .id = spv.next_result_id };
}

fn spirvBuiltin(builtin: Air.Inst.Builtin) spec.BuiltIn {
    return switch (builtin) {
        .vertex_index => .VertexIndex,
        .instance_index => .InstanceIndex,
        .position => .Position,
        .front_facing => .FrontFacing,
        .frag_depth => .FragDepth,
        .local_invocation_id => .LocalInvocationId,
        .local_invocation_index => .LocalInvocationIndex,
        .global_invocation_id => .GlobalInvocationId,
        .workgroup_id => .WorkgroupId,
        .num_workgroups => .NumWorkgroups,
        .sample_index => .SampleMask,
        .sample_mask => .SampleId,
    };
}

fn storageClassFromAddrSpace(addr_space: Air.Inst.PointerType.AddressSpace) spec.StorageClass {
    return switch (addr_space) {
        .uniform_constant => .UniformConstant,
        .function => .Function,
        .private => .Private,
        .workgroup => .Workgroup,
        .uniform => .Uniform,
        .storage => .StorageBuffer,
    };
}

fn spirvDim(kind: Inst.TextureType.Kind) spec.Dim {
    return switch (kind) {
        .sampled_1d, .storage_1d => .@"1D",
        .sampled_3d, .storage_3d => .@"3D",
        .sampled_2d,
        .sampled_2d_array,
        .multisampled_2d,
        .multisampled_depth_2d,
        .storage_2d,
        .storage_2d_array,
        .depth_2d,
        .depth_2d_array,
        => .@"2D",
        .sampled_cube,
        .sampled_cube_array,
        .depth_cube,
        .depth_cube_array,
        => .Cube,
    };
}

fn spirvDepth(kind: Inst.TextureType.Kind) u1 {
    return switch (kind) {
        .depth_2d,
        .depth_2d_array,
        .depth_cube,
        .depth_cube_array,
        => 1,
        else => 0,
    };
}

fn spirvArrayed(kind: Inst.TextureType.Kind) u1 {
    return switch (kind) {
        .sampled_2d_array,
        .sampled_cube_array,
        .storage_2d_array,
        .depth_2d_array,
        .depth_cube_array,
        => 1,
        else => 0,
    };
}

fn spirvMultisampled(kind: Inst.TextureType.Kind) u1 {
    return switch (kind) {
        .multisampled_2d, .multisampled_depth_2d => 1,
        else => 0,
    };
}

fn spirvSampled(kind: Inst.TextureType.Kind) u2 {
    return switch (kind) {
        .sampled_1d,
        .sampled_2d,
        .sampled_2d_array,
        .sampled_3d,
        .sampled_cube,
        .sampled_cube_array,
        .multisampled_2d,
        .multisampled_depth_2d,
        => 1,
        .storage_1d,
        .storage_2d,
        .storage_2d_array,
        .storage_3d,
        => 2,
        else => 0,
    };
}

fn spirvImageFormat(texel_format: Inst.TextureType.TexelFormat) spec.ImageFormat {
    return switch (texel_format) {
        .none => .Unknown,
        .rgba8unorm => .Rgba8,
        .rgba8snorm => .Rgba8Snorm,
        .rgba8uint => .Rgba8ui,
        .rgba8sint => .Rgba8i,
        .rgba16uint => .Rgba16ui,
        .rgba16sint => .Rgba16i,
        .rgba16float => .Rgba16f,
        .r32uint => .R32ui,
        .r32sint => .R32i,
        .r32float => .R32f,
        .rg32uint => .Rg32ui,
        .rg32sint => .Rg32i,
        .rg32float => .Rg32f,
        .rgba32uint => .Rgba32ui,
        .rgba32sint => .Rgba32i,
        .rgba32float => .Rgba32f,
        .bgra8unorm => .Unknown,
    };
}
