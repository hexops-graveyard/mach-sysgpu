const std = @import("std");
const Air = @import("../Air.zig");
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
next_result_id: Word = 1,
compute_stage: ?ComputeStage = null,
vertex_stage: ?VertexStage = null,
fragment_stage: ?FragmentStage = null,
store_return: ?IdRef = null,

const Decl = struct {
    id: IdRef,
    type_id: IdRef,
    is_ptr: bool,
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

pub fn gen(allocator: std.mem.Allocator, air: *const Air) ![]const u8 {
    var spv = SpirV{
        .air = air,
        .allocator = allocator,
        .debug_section = .{ .allocator = allocator },
        .annotations_section = .{ .allocator = allocator },
        .global_section = .{ .allocator = allocator },
        .main_section = .{ .allocator = allocator },
    };
    defer {
        spv.debug_section.deinit();
        spv.annotations_section.deinit();
        spv.global_section.deinit();
        spv.main_section.deinit();
        spv.type_value_map.deinit(allocator);
        spv.decl_map.deinit(allocator);
        if (spv.compute_stage) |stage| allocator.free(stage.interface);
        if (spv.vertex_stage) |stage| allocator.free(stage.interface);
        if (spv.fragment_stage) |stage| allocator.free(stage.interface);
    }

    var module_section = Section{ .allocator = allocator };
    defer module_section.deinit();

    for (air.refToList(air.globals_index)) |inst_idx| {
        switch (spv.air.getInst(inst_idx)) {
            .@"fn" => _ = try spv.emitFn(inst_idx),
            .@"const" => _ = try spv.emitConst(inst_idx),
            .@"var" => _ = try spv.emitVarProto(&spv.global_section, inst_idx),
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

    var fn_section = Section{ .allocator = spv.allocator };
    var fn_params_section = Section{ .allocator = spv.allocator };
    defer {
        fn_section.deinit();
        fn_params_section.deinit();
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

    var return_var_id: ?IdRef = null;
    if (inst.stage != .none and inst.return_type != .none) {
        return_var_id = spv.allocId();
        spv.store_return = return_var_id;

        const return_var_name_slice = try std.mem.concat(
            spv.allocator,
            u8,
            &.{ name_slice, "_return_output" },
        );
        defer spv.allocator.free(return_var_name_slice);
        try spv.debugName(return_var_id.?, return_var_name_slice);

        const return_var_type_id = try spv.resolve(.{ .ptr_type = .{
            .storage_class = .Output,
            .elem_type = raw_return_type_id,
        } });
        try spv.global_section.emit(.OpVariable, .{
            .id_result_type = return_var_type_id,
            .id_result = return_var_id.?,
            .storage_class = .Output,
        });

        if (inst.return_attrs.builtin) |builtin| {
            try spv.annotations_section.emit(.OpDecorate, .{
                .target = return_var_id.?,
                .decoration = .{ .BuiltIn = .{ .built_in = builtInFromAirBuiltin(builtin) } },
            });
        }

        if (inst.return_attrs.location) |location| {
            try spv.annotations_section.emit(.OpDecorate, .{
                .target = return_var_id.?,
                .decoration = .{ .Location = .{ .location = location } },
            });
        }

        try interface.append(return_var_id.?);
    } else {
        spv.store_return = null;
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
                            .built_in = builtInFromAirBuiltin(builtin),
                        } },
                    });
                }

                try interface.append(param_id);
                try spv.decl_map.put(spv.allocator, param_inst_idx, .{
                    .id = param_id,
                    .type_id = elem_type_id,
                    .is_ptr = true,
                });
            } else {
                const param_type_id = try spv.emitType(param_inst.type);
                try fn_params_section.emit(.OpFunctionParameter, .{
                    .id_result_type = param_type_id,
                    .id_result = param_id,
                });
                try params_type.append(param_type_id);
                try spv.decl_map.put(spv.allocator, param_inst_idx, .{
                    .id = param_id,
                    .type_id = param_type_id,
                    .is_ptr = false,
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

    try fn_section.emit(.OpFunction, .{
        .id_result_type = return_type_id,
        .id_result = fn_id,
        .function_control = .{ .Const = inst.is_const },
        .function_type = fn_type_id,
    });

    try fn_section.append(fn_params_section);

    const block_id = spv.allocId();
    const statements_ref = spv.air.getInst(inst.block).block;
    try fn_section.emit(.OpLabel, .{ .id_result = block_id });

    if (statements_ref != .none) {
        try spv.emitFnVars(&fn_section, statements_ref);
    }

    if (statements_ref != .none) {
        const list = spv.air.refToList(statements_ref);
        for (list) |statement_idx| {
            try spv.emitStatement(&fn_section, statement_idx);
        }

        if (spv.air.getInst(list[list.len - 1]) != .@"return") {
            try spv.emitReturn(&fn_section, .none);
        }
    } else {
        try spv.emitReturn(&fn_section, .none);
    }

    try fn_section.emit(.OpFunctionEnd, {});

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

    try spv.main_section.append(fn_section);
    try spv.decl_map.put(spv.allocator, inst_idx, .{
        .id = fn_id,
        .type_id = fn_type_id,
        .is_ptr = false,
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
                }
            },
            .@"while" => |@"while"| try spv.emitFnVars(section, spv.air.getInst(@"while".rhs).block),
            .continuing => |continuing| try spv.emitFnVars(section, spv.air.getInst(continuing).block),
            .@"switch" => |@"switch"| {
                const switch_cases_list = spv.air.refToList(@"switch".cases_list);
                for (switch_cases_list) |switch_case_idx| {
                    const switch_case = spv.air.getInst(switch_case_idx).switch_case;
                    try spv.emitFnVars(section, spv.air.getInst(switch_case.body).block);
                }
            },
            .@"for" => unreachable, // TODO
            else => {},
        }
    }
}

fn emitVarProto(spv: *SpirV, section: *Section, inst_idx: InstIndex) !IdRef {
    if (spv.decl_map.get(inst_idx)) |decl| return decl.id;

    const inst = spv.air.getInst(inst_idx).@"var";
    const id = spv.allocId();
    try spv.debugName(id, spv.air.getStr(inst.name));

    const storage_class = storageClassFromAddrSpace(inst.addr_space);
    const type_id = try spv.emitType(if (inst.type != .none) inst.type else inst.expr);
    const ptr_type_id = try spv.resolve(.{ .ptr_type = .{
        .elem_type = type_id,
        .storage_class = storage_class,
    } });

    const zero_id = try spv.resolve(.{ .null = type_id });

    try section.emit(.OpVariable, .{
        .id_result_type = ptr_type_id,
        .id_result = id,
        .storage_class = storage_class,
        .initializer = zero_id,
    });

    try spv.decl_map.put(spv.allocator, inst_idx, .{
        .id = id,
        .type_id = type_id,
        .is_ptr = true,
    });

    return id;
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
                .len = try spv.emitExpr(&spv.global_section, array.len),
                .elem_type = try spv.emitType(array.elem_type),
            },
        }),
        .ptr_type => |ptr| try spv.resolve(.{
            .ptr_type = .{
                .storage_class = storageClassFromAddrSpace(ptr.addr_space),
                .elem_type = try spv.emitType(ptr.elem_type),
            },
        }),
        else => unreachable, // TODO: make this unreachable
    };
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
            if (spv.store_return) |store_to| {
                try section.emit(.OpStore, .{
                    .pointer = store_to,
                    .object = try spv.emitExpr(section, inst),
                });
                try spv.emitReturn(section, .none);
            } else {
                try spv.emitReturn(section, inst);
            }
        },
        .call => |inst| _ = try spv.emitCall(section, inst),
        .@"if" => |@"if"| try spv.emitIf(section, @"if"),
        .assign => |assign| try spv.emitAssign(section, assign),
        else => {}, // TODO
    }
}

fn emitIf(spv: *SpirV, section: *Section, inst: Inst.If) !void {
    const cond = try spv.emitExpr(section, inst.cond);
    const true_branch = spv.allocId();
    const false_branch = spv.allocId();
    const merge_branch = spv.allocId();

    try section.emit(.OpSelectionMerge, .{
        .merge_block = merge_branch,
        .selection_control = .{},
    });

    try section.emit(.OpBranchConditional, .{
        .condition = cond,
        .true_label = true_branch,
        .false_label = false_branch,
    });

    try section.emit(.OpLabel, .{ .id_result = true_branch });
    const if_body = spv.air.getInst(inst.body).block;
    if (if_body != .none) {
        const true_branch_statements = spv.air.refToList(if_body);
        for (true_branch_statements) |statement_idx| {
            try spv.emitStatement(section, statement_idx);
        }
        try section.emit(.OpBranch, .{ .target_label = merge_branch });
    }

    if (inst.@"else" != .none) {
        try section.emit(.OpLabel, .{ .id_result = false_branch });
        switch (spv.air.getInst(inst.@"else")) {
            .@"if" => |else_if| try spv.emitIf(section, else_if),
            .block => |else_body| if (else_body != .none) {
                const false_branch_statements = spv.air.refToList(else_body);
                for (false_branch_statements) |statement_idx| {
                    try spv.emitStatement(section, statement_idx);
                }
            },
            else => unreachable,
        }
        try section.emit(.OpBranch, .{ .target_label = merge_branch });
    }

    try section.emit(.OpLabel, .{ .id_result = merge_branch });
}

fn emitAssign(spv: *SpirV, section: *Section, inst: Inst.Assign) !void {
    const var_idx = spv.air.getInst(inst.lhs).var_ref;
    const decl = spv.decl_map.get(var_idx).?;
    const expr = try spv.emitExpr(section, inst.rhs);

    if (inst.mod != .none) unreachable; // TODO

    try section.emit(.OpStore, .{
        .pointer = decl.id,
        .object = expr,
    });
}

fn emitReturn(spv: *SpirV, section: *Section, inst: InstIndex) !void {
    if (inst == .none) return section.emit(.OpReturn, {});
    try section.emit(.OpReturnValue, .{ .value = try spv.emitExpr(section, inst) });
}

fn emitExpr(spv: *SpirV, section: *Section, inst_idx: InstIndex) error{OutOfMemory}!IdRef {
    return switch (spv.air.getInst(inst_idx)) {
        .bool => |boolean| spv.emitBool(section, boolean),
        .int => |int| spv.emitInt(section, int),
        .float => |float| spv.emitFloat(section, float),
        .vector => |vector| spv.emitVector(section, vector),
        .matrix => |matrix| spv.emitMatrix(section, matrix),
        .array => |array| spv.emitArray(section, array),
        .call => |call| spv.emitCall(section, call),
        .var_ref => |var_ref| blk: {
            const decl = spv.decl_map.get(var_ref).?;
            if (decl.is_ptr) {
                const load_id = spv.allocId();
                try section.emit(.OpLoad, .{
                    .id_result_type = decl.type_id,
                    .id_result = load_id,
                    .pointer = decl.id,
                });
                break :blk load_id;
            }
            break :blk decl.id;
        },
        .swizzle_access => |swizzle_access| spv.emitSwizzleAccess(section, swizzle_access),
        .index_access => |index_access| spv.emitIndexAccess(section, index_access),
        else => std.debug.panic("TODO: implement Air tag {s}", .{@tagName(spv.air.getInst(inst_idx))}),
    };
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

fn emitBoolCast(spv: *SpirV, section: *Section, cast: Inst.Cast) !IdRef {
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

fn emitIntCast(spv: *SpirV, section: *Section, dest_type: Inst.Int.Type, cast: Inst.Cast) !IdRef {
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

fn emitFloatCast(spv: *SpirV, section: *Section, dest_type: Inst.Float.Type, cast: Inst.Cast) !IdRef {
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

    var elem_value = std.ArrayList(IdRef).init(spv.allocator);
    defer elem_value.deinit();
    try elem_value.ensureTotalCapacityPrecise(@intFromEnum(inst.size));

    const value = spv.air.getValue(Inst.Vector.Value, inst.value.?);
    for (value[0..@intFromEnum(inst.size)]) |elem_inst| {
        const elem_id = try spv.emitExpr(section, elem_inst);
        elem_value.appendAssumeCapacity(elem_id);
    }

    const id = spv.allocId();
    try section.emit(.OpCompositeConstruct, .{
        .id_result_type = type_id,
        .id_result = id,
        .constituents = elem_value.items,
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

    var elem_value = std.ArrayList(IdRef).init(spv.allocator);
    defer elem_value.deinit();
    try elem_value.ensureTotalCapacityPrecise(@intFromEnum(inst.cols));

    const value = spv.air.getValue(Inst.Matrix.Value, inst.value.?);
    for (value[0..@intFromEnum(inst.cols)]) |elem_inst| {
        const elem_id = try spv.emitVector(section, spv.air.getInst(elem_inst).vector);
        elem_value.appendAssumeCapacity(elem_id);
    }

    const id = spv.allocId();
    try section.emit(.OpCompositeConstruct, .{
        .id_result_type = type_id,
        .id_result = id,
        .constituents = elem_value.items,
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

fn emitSwizzleAccess(spv: *SpirV, section: *Section, inst: Inst.SwizzleAccess) !IdRef {
    if (inst.size == .one) {
        const id = spv.allocId();
        try section.emit(.OpCompositeExtract, .{
            .id_result_type = try spv.emitType(inst.type),
            .id_result = id,
            .composite = try spv.emitExpr(section, inst.base),
            .indexes = &.{@intFromEnum(inst.pattern[0])},
        });
        return id;
    }

    if (spv.air.resolveConstExpr(inst.base)) |_| {
        const swizzles = try spv.extractSwizzle(&spv.global_section, inst);
        defer spv.allocator.free(swizzles);

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

    const id = spv.allocId();
    const swizzles = try spv.extractSwizzle(section, inst);
    defer spv.allocator.free(swizzles);
    try section.emit(.OpCompositeConstruct, .{
        .id_result_type = try spv.emitType(inst.type),
        .id_result = id,
        .constituents = swizzles,
    });
    return id;
}

fn emitIndexAccess(spv: *SpirV, section: *Section, inst: Inst.IndexAccess) !IdRef {
    const id = spv.allocId();
    const type_id = try spv.emitType(inst.type);
    const base_decl = spv.decl_map.get(spv.air.getInst(inst.base).var_ref).?;
    std.debug.assert(base_decl.is_ptr);

    if (spv.air.resolveConstExpr(inst.index)) |_| {
        const index_value_idx = spv.air.getInst(inst.index).int.value.?;
        const index_value = spv.air.getValue(Inst.Int.Value, index_value_idx).literal;
        try section.emit(.OpCompositeExtract, .{
            .id_result_type = type_id,
            .id_result = id,
            .composite = base_decl.id,
            .indexes = &[_]u32{@intCast(index_value)},
        });
        return id;
    }

    const access_chain_id = spv.allocId();
    const index_id = try spv.emitExpr(section, inst.index);
    try section.emit(.OpAccessChain, .{
        .id_result_type = try spv.resolve(.{
            .ptr_type = .{
                .elem_type = type_id,
                .storage_class = .Function,
            },
        }),
        .id_result = access_chain_id,
        .base = base_decl.id,
        .indexes = &.{index_id},
    });

    try section.emit(.OpLoad, .{
        .id_result_type = type_id,
        .id_result = id,
        .pointer = access_chain_id,
    });

    return id;
}

const Key = union(enum) {
    void_type,
    bool_type,
    int_type: Inst.Int.Type,
    float_type: Inst.Float.Type,
    vector_type: VectorType,
    matrix_type: MatrixType,
    array_type: ArrayType,
    ptr_type: PointerType,
    fn_type: FunctionType,
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

    const Int = struct {
        type: Inst.Int.Type,
        value: i33,
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
    if (spv.type_value_map.get(key)) |value| {
        return value;
    }

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
    }

    try spv.type_value_map.put(spv.allocator, key, id);
    return id;
}

fn debugName(spv: *SpirV, id: IdResult, name: []const u8) !void {
    try spv.debug_section.emit(.OpName, .{ .target = id, .name = name });
}

fn allocId(spv: *SpirV) IdResult {
    defer spv.next_result_id += 1;
    return .{ .id = spv.next_result_id };
}

fn builtInFromAirBuiltin(builtin: Air.Inst.Builtin) spec.BuiltIn {
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
        .function => .Function,
        .private => .Private,
        .workgroup => .Workgroup,
        .uniform => .Uniform,
        .storage => .StorageBuffer,
    };
}
