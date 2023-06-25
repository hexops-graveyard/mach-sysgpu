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
type_value_map: std.AutoArrayHashMapUnmanaged(Key, IdRef) = .{},
/// Map Air Instruction Index to IdRefs to prevent duplicated declarations
decl_map: std.AutoHashMapUnmanaged(InstIndex, IdRef) = .{},
/// Required Capabilities
capabilities: std.AutoHashMapUnmanaged(spec.Capability, void) = .{},
next_result_id: Word = 1,
compute_stage: ?ComputeStage = null,
vertex_stage: ?VertexStage = null,
fragment_stage: ?FragmentStage = null,

const ComputeStage = struct {
    id: IdResult,
    name: []const u8,
    workgroup_size: struct {
        x: spec.LiteralInteger,
        y: spec.LiteralInteger,
        z: spec.LiteralInteger,
    },
};

const VertexStage = struct {
    id: IdResult,
    name: []const u8,
};

const FragmentStage = struct {
    id: IdResult,
    name: []const u8,
};

pub fn gen(allocator: std.mem.Allocator, air: *const Air) ![]const u8 {
    var spirv = SpirV{
        .air = air,
        .allocator = allocator,
        .debug_section = .{ .allocator = allocator },
        .annotations_section = .{ .allocator = allocator },
        .global_section = .{ .allocator = allocator },
        .main_section = .{ .allocator = allocator },
    };
    defer {
        spirv.debug_section.deinit();
        spirv.annotations_section.deinit();
        spirv.global_section.deinit();
        spirv.main_section.deinit();
        spirv.type_value_map.deinit(allocator);
        spirv.decl_map.deinit(allocator);
        spirv.capabilities.deinit(allocator);
    }

    var module_section = Section{ .allocator = allocator };
    defer module_section.deinit();

    for (air.refToList(air.globals_index)) |inst_idx| {
        _ = try spirv.emitGlobalDecl(inst_idx);
    }

    try spirv.emitModule(&module_section);
    try module_section.append(spirv.debug_section);
    try module_section.append(spirv.annotations_section);
    try module_section.append(spirv.global_section);
    try module_section.append(spirv.main_section);

    return allocator.dupe(u8, std.mem.sliceAsBytes(module_section.words.items));
}

fn emitModule(spirv: *SpirV, section: *Section) !void {
    const header = &[_]Word{
        // Magic number
        spec.magic_number,
        // Spir-V 1.3
        spec.Version.toWord(.{ .major = 1, .minor = 3 }),
        // Generator magic number. TODO: register dusk compiler
        0,
        // Id's bound
        spirv.next_result_id,
        // Reserved for instruction schema, if needed
        0,
    };
    try section.ensureUnusedCapacity(header.len);
    section.writeWords(header);

    try section.emit(.OpCapability, .{ .capability = .Shader });
    var cap_iter = spirv.capabilities.keyIterator();
    while (cap_iter.next()) |capability| {
        try section.emit(.OpCapability, .{ .capability = capability.* });
    }

    try section.emit(.OpMemoryModel, .{ .addressing_model = .Logical, .memory_model = .GLSL450 });

    if (spirv.compute_stage) |compute_stage| {
        try section.emit(.OpEntryPoint, .{
            .execution_model = .GLCompute,
            .entry_point = compute_stage.id,
            .name = compute_stage.name,
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
    if (spirv.vertex_stage) |vertex_stage| {
        try section.emit(.OpEntryPoint, .{
            .execution_model = .Vertex,
            .entry_point = vertex_stage.id,
            .name = vertex_stage.name,
        });
    }
    if (spirv.fragment_stage) |fragment_stage| {
        try section.emit(.OpEntryPoint, .{
            .execution_model = .Fragment,
            .entry_point = fragment_stage.id,
            .name = fragment_stage.name,
        });
    }
}

fn emitGlobalDecl(spirv: *SpirV, inst_idx: InstIndex) !IdRef {
    const gop = try spirv.decl_map.getOrPut(spirv.allocator, inst_idx);
    if (gop.found_existing) return gop.value_ptr.*;

    const id = switch (spirv.air.getInst(inst_idx)) {
        .@"fn" => |inst| try spirv.emitFn(inst),
        else => IdResult{ .id = 1 }, // TODO: make this unreachable
    };

    gop.key_ptr.* = inst_idx;
    gop.value_ptr.* = id;
    return id;
}

fn emitFn(spirv: *SpirV, inst: Inst.Fn) error{OutOfMemory}!IdRef {
    var fn_section = Section{ .allocator = spirv.allocator };
    defer fn_section.deinit();

    const fn_id = spirv.allocId();
    const fn_type_id = spirv.allocId();
    const return_type_id = blk: {
        if (inst.return_type == .none) {
            break :blk try spirv.resolve(.void_type);
        }
        break :blk try spirv.emitType(inst.return_type);
    };

    const name_slice = spirv.air.getStr(inst.name);
    try spirv.debug_section.emit(.OpName, .{
        .target = fn_id,
        .name = name_slice,
    });

    try fn_section.emit(.OpFunction, .{
        .id_result_type = return_type_id,
        .id_result = fn_id,
        .function_control = .{ .Const = inst.is_const },
        .function_type = fn_type_id,
    });

    const block_id = spirv.allocId();
    try fn_section.emit(.OpLabel, .{ .id_result = block_id });

    var params_type = std.ArrayList(IdRef).init(spirv.allocator);
    defer params_type.deinit();

    if (inst.params != .none) {
        const param_list = spirv.air.refToList(inst.params);

        for (param_list) |param_inst_idx| {
            const param_inst = spirv.air.getInst(param_inst_idx).fn_param;
            const param_id = spirv.allocId();

            try spirv.debug_section.emit(.OpName, .{
                .target = param_id,
                .name = spirv.air.getStr(param_inst.name),
            });

            if (inst.stage != .none) {
                const elem_type_id = try spirv.emitType(param_inst.type);
                const param_type_id = try spirv.resolve(.{ .ptr_type = .{
                    .storage_class = .Input,
                    .elem_type = elem_type_id,
                } });

                const param_var_id = spirv.allocId();
                const param_var_name_slice = try std.mem.concat(
                    spirv.allocator,
                    u8,
                    &.{ name_slice, "_", spirv.air.getStr(param_inst.name), "_input" },
                );
                defer spirv.allocator.free(param_var_name_slice);
                try spirv.debug_section.emit(.OpName, .{
                    .target = param_var_id,
                    .name = param_var_name_slice,
                });

                try spirv.global_section.emit(.OpVariable, .{
                    .id_result_type = param_type_id,
                    .id_result = param_var_id,
                    .storage_class = .Input,
                });

                try fn_section.emit(.OpLoad, .{
                    .id_result_type = elem_type_id,
                    .id_result = param_id,
                    .pointer = param_var_id,
                });

                try spirv.annotations_section.emit(.OpDecorate, .{
                    .target = param_var_id,
                    .decoration = .{ .BuiltIn = .{
                        .built_in = fromAirBuiltin(param_inst.builtin),
                    } },
                });
            } else {
                const param_type_id = try spirv.emitType(param_inst.type);
                try spirv.global_section.emit(.OpFunctionParameter, .{
                    .id_result_type = param_type_id,
                    .id_result = param_id,
                });
                try params_type.append(param_type_id);
            }

            try spirv.decl_map.put(spirv.allocator, param_inst_idx, param_id);
        }
    }

    try spirv.global_section.emit(.OpTypeFunction, .{
        .id_result = fn_type_id,
        .return_type = if (inst.stage != .none) try spirv.resolve(.void_type) else return_type_id,
        .id_ref_2 = params_type.items,
    });

    var return_var_id: ?IdRef = null;
    if (inst.stage != .none and inst.return_type != .none) {
        return_var_id = spirv.allocId();
        const return_builtin = fromAirBuiltin(inst.return_attrs.builtin);

        const return_var_name_slice = try std.mem.concat(
            spirv.allocator,
            u8,
            &.{ name_slice, "_", @tagName(return_builtin), "_output" },
        );
        defer spirv.allocator.free(return_var_name_slice);
        try spirv.debug_section.emit(.OpName, .{
            .target = return_var_id.?,
            .name = return_var_name_slice,
        });

        const return_var_type_id = try spirv.resolve(.{ .ptr_type = .{
            .storage_class = .Output,
            .elem_type = return_type_id,
        } });
        try spirv.global_section.emit(.OpVariable, .{
            .id_result_type = return_var_type_id,
            .id_result = return_var_id.?,
            .storage_class = .Output,
        });

        try spirv.annotations_section.emit(.OpDecorate, .{
            .target = return_var_id.?,
            .decoration = .{ .BuiltIn = .{ .built_in = return_builtin } },
        });
    }

    const statements_ref = spirv.air.getInst(inst.block).block;
    if (statements_ref != .none) {
        const list = spirv.air.refToList(statements_ref);
        for (list) |statement_idx| {
            try spirv.emitStatement(&fn_section, statement_idx, return_var_id);
        }

        if (spirv.air.getInst(list[list.len - 1]) != .@"return") {
            try fn_section.emit(.OpReturn, {});
        }
    } else {
        try fn_section.emit(.OpReturn, {});
    }

    try fn_section.emit(.OpFunctionEnd, {});

    switch (inst.stage) {
        .none => {},
        .compute => |compute| spirv.compute_stage = .{
            .id = fn_id,
            .name = name_slice,
            .workgroup_size = .{
                .x = blk: {
                    const int = spirv.air.getInst(compute.x).int;
                    const value = spirv.air.getValue(Inst.Int.Value, int.value.?);
                    break :blk @intCast(Word, value.literal.value);
                },
                .y = blk: {
                    if (compute.y == .none) break :blk 1;

                    const int = spirv.air.getInst(compute.y).int;
                    const value = spirv.air.getValue(Inst.Int.Value, int.value.?);
                    break :blk @intCast(Word, value.literal.value);
                },
                .z = blk: {
                    if (compute.y == .none) break :blk 1;

                    const int = spirv.air.getInst(compute.z).int;
                    const value = spirv.air.getValue(Inst.Int.Value, int.value.?);
                    break :blk @intCast(Word, value.literal.value);
                },
            },
        },
        .vertex => spirv.vertex_stage = .{ .id = fn_id, .name = name_slice },
        .fragment => spirv.fragment_stage = .{ .id = fn_id, .name = name_slice },
    }

    try spirv.main_section.append(fn_section);
    return fn_id;
}

fn emitType(spirv: *SpirV, inst: InstIndex) error{OutOfMemory}!IdRef {
    return switch (spirv.air.getInst(inst)) {
        .int => |int| try spirv.resolve(.{ .int_type = int.type }),
        .float => |float| try spirv.resolve(.{ .float_type = float.type }),
        .vector => |vector| try spirv.resolve(.{
            .vector_type = .{
                .size = vector.size,
                .elem_type = try spirv.emitType(vector.elem_type),
            },
        }),
        .matrix => |matrix| try spirv.resolve(.{
            .matrix_type = .{
                .cols = matrix.cols,
                .elem_type = try spirv.resolve(.{
                    .vector_type = .{
                        .size = matrix.rows,
                        .elem_type = try spirv.emitType(matrix.elem_type),
                    },
                }),
            },
        }),
        .array => |array| try spirv.resolve(.{
            .array_type = .{
                .len = try spirv.emitExpr(&spirv.global_section, array.len),
                .elem_type = try spirv.emitType(array.elem_type),
            },
        }),
        .ptr_type => |ptr| try spirv.resolve(.{
            .ptr_type = .{
                .storage_class = switch (ptr.addr_space) {
                    .function => .Function,
                    .private => .Private,
                    .workgroup => .Workgroup,
                    .uniform => .Uniform,
                    .storage => .StorageBuffer,
                },
                .elem_type = try spirv.emitType(ptr.elem_type),
            },
        }),
        else => .{ .id = 1 }, // TODO: make this unreachable
    };
}

fn emitStatement(spirv: *SpirV, section: *Section, inst_idx: InstIndex, store_return: ?IdRef) !void {
    switch (spirv.air.getInst(inst_idx)) {
        .@"return" => |inst| {
            if (store_return) |store_to| {
                try section.emit(.OpStore, .{
                    .pointer = store_to,
                    .object = try spirv.emitExpr(section, inst),
                });
            } else {
                try spirv.emitReturn(section, inst);
            }
        },
        .call => |inst| _ = try spirv.emitCall(section, inst),
        else => {}, // TODO: unreachable
    }
}

fn emitReturn(spirv: *SpirV, section: *Section, inst: InstIndex) !void {
    if (inst == .none) return section.emit(.OpReturn, {});
    try section.emit(.OpReturnValue, .{ .value = try spirv.emitExpr(section, inst) });
}

fn emitExpr(spirv: *SpirV, section: *Section, inst_idx: InstIndex) error{OutOfMemory}!IdRef {
    return switch (spirv.air.getInst(inst_idx)) {
        .int => |int| switch (spirv.air.getValue(Inst.Int.Value, int.value.?)) {
            .literal => |lit| try spirv.constInt(int.type, lit.value),
            .inst => |val_inst| try spirv.emitExpr(section, val_inst), // TODO
        },
        .float => |float| switch (spirv.air.getValue(Inst.Float.Value, float.value.?)) {
            .literal => |lit| try spirv.constFloat(float.type, lit.value),
            .inst => |val_inst| try spirv.emitExpr(section, val_inst), // TODO
        },
        .vector => |vector| try spirv.emitVector(section, vector),
        .call => |call| spirv.emitCall(section, call),
        else => .{ .id = 1 }, // TODO: unreachable
    };
}

fn emitCall(spirv: *SpirV, section: *Section, inst: Inst.FnCall) !IdRef {
    var args = std.ArrayList(IdRef).init(spirv.allocator);
    defer args.deinit();

    if (inst.args != .none) {
        for (spirv.air.refToList(inst.args)) |arg_inst_idx| {
            try args.append(try spirv.emitExpr(section, arg_inst_idx));
        }
    }

    const id = spirv.allocId();
    try section.emit(.OpFunctionCall, .{
        .id_result_type = try spirv.emitType(spirv.air.getInst(inst.@"fn").@"fn".return_type),
        .id_result = id,
        .function = try spirv.emitGlobalDecl(inst.@"fn"),
        .id_ref_3 = args.items,
    });

    return id;
}

fn emitVector(spirv: *SpirV, section: *Section, inst: Inst.Vector) !IdRef {
    const value = spirv.air.getValue(Inst.Vector.Value, inst.value.?);
    var is_const = true;

    var constituents = std.ArrayList(IdRef).init(spirv.allocator);
    defer constituents.deinit();
    try constituents.ensureTotalCapacityPrecise(@intFromEnum(inst.size));

    const ty: Key = switch (spirv.air.getInst(inst.elem_type)) {
        .bool => .bool_type,
        .float => |float| .{ .float_type = float.type },
        .int => |int| .{ .int_type = int.type },
        else => unreachable,
    };

    for (value[0..@intFromEnum(inst.size)]) |val| {
        var val_id: IdRef = undefined;
        if (val != .none) {
            switch (spirv.air.getInst(val)) {
                .bool => |boolean| if (boolean.value.? == .inst) {
                    is_const = false;
                },
                .int => |int| if (spirv.air.getValue(Inst.Int.Value, int.value.?) == .inst) {
                    is_const = false;
                },
                .float => |float| if (spirv.air.getValue(Inst.Float.Value, float.value.?) == .inst) {
                    is_const = false;
                },
                .var_ref => unreachable, // TODO
                else => unreachable,
            }

            val_id = try spirv.emitExpr(section, val);
        } else {
            val_id = try spirv.constNull(ty);
        }

        constituents.appendAssumeCapacity(val_id);
    }

    const vec_type = Key.VectorType{
        .elem_type = try spirv.resolve(ty),
        .size = inst.size,
    };
    if (is_const) return spirv.constVector(vec_type, constituents.items);

    const id = spirv.allocId();
    try section.emit(.OpCompositeConstruct, .{
        .id_result_type = try spirv.resolve(.{ .vector_type = vec_type }),
        .id_result = id,
        .constituents = constituents.items,
    });
    return id;
}

fn constNull(spirv: *SpirV, ty: Key) !IdRef {
    return spirv.resolve(.{ .null = try spirv.resolve(ty) });
}

fn constBool(spirv: *SpirV, val: bool) !IdRef {
    return spirv.resolve(.{ .bool = val });
}

fn constInt(spirv: *SpirV, ty: Inst.Int.Type, value: i64) !IdRef {
    return spirv.resolve(.{
        .int = .{
            .type = ty,
            .value = value,
        },
    });
}

fn constFloat(spirv: *SpirV, ty: Inst.Float.Type, value: f64) !IdRef {
    const coerced_type = if (value <= std.math.floatMax(f32) and ty == .abstract) .f32 else ty;
    return spirv.resolve(.{
        .float = .{
            .type = coerced_type,
            .value = @bitCast(u64, value),
        },
    });
}

fn constVector(spirv: *SpirV, ty: Key.VectorType, constituents: []const IdRef) !IdRef {
    const id = spirv.allocId();
    try spirv.global_section.emit(.OpConstantComposite, .{
        .id_result_type = try spirv.resolve(.{ .vector_type = ty }),
        .id_result = id,
        .constituents = constituents,
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
    null: IdRef,
    bool: bool,
    int: Int,
    float: Float,

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

    const Int = struct {
        type: Inst.Int.Type,
        value: i64,
    };

    const Float = struct {
        type: Inst.Float.Type,
        value: u64,
    };
};

pub fn resolve(spirv: *SpirV, key: Key) !IdRef {
    var gop = try spirv.type_value_map.getOrPut(spirv.allocator, key);
    if (gop.found_existing) return gop.value_ptr.*;

    const id = spirv.allocId();
    switch (key) {
        .void_type => try spirv.global_section.emit(.OpTypeVoid, .{ .id_result = id }),
        .bool_type => try spirv.global_section.emit(.OpTypeBool, .{ .id_result = id }),
        .int_type => |int| try spirv.global_section.emit(.OpTypeInt, .{
            .id_result = id,
            .width = int.width(),
            .signedness = @intFromBool(int.signedness()),
        }),
        .float_type => |float| {
            switch (float) {
                .f16 => try spirv.capabilities.put(spirv.allocator, .Float16, {}),
                .abstract => try spirv.capabilities.put(spirv.allocator, .Float64, {}),
                .f32 => {},
            }
            try spirv.global_section.emit(.OpTypeFloat, .{
                .id_result = id,
                .width = float.width(),
            });
        },
        .vector_type => |vector| try spirv.global_section.emit(.OpTypeVector, .{
            .id_result = id,
            .component_type = vector.elem_type,
            .component_count = @intFromEnum(vector.size),
        }),
        .matrix_type => |matrix| try spirv.global_section.emit(.OpTypeMatrix, .{
            .id_result = id,
            .column_type = matrix.elem_type,
            .column_count = @intFromEnum(matrix.cols),
        }),
        .array_type => |array| {
            if (array.len) |len| {
                try spirv.global_section.emit(.OpTypeArray, .{
                    .id_result = id,
                    .element_type = array.elem_type,
                    .length = len,
                });
            } else unreachable; // TODO
        },
        .ptr_type => |ptr| {
            try spirv.global_section.emit(.OpTypePointer, .{
                .id_result = id,
                .storage_class = ptr.storage_class,
                .type = ptr.elem_type,
            });
        },
        .null => |nil| {
            try spirv.global_section.emit(.OpConstantNull, .{ .id_result_type = nil, .id_result = id });
        },
        .bool => |val| {
            const type_id = try spirv.resolve(.bool_type);
            if (val) {
                try spirv.global_section.emit(.OpConstantTrue, .{ .id_result_type = type_id, .id_result = id });
            } else {
                try spirv.global_section.emit(.OpConstantFalse, .{ .id_result_type = type_id, .id_result = id });
            }
        },
        .int => |int| {
            const value: spec.LiteralContextDependentNumber = switch (int.type) {
                .u32 => .{ .uint32 = @intCast(u32, int.value) },
                .i32 => .{ .int32 = @intCast(i32, int.value) },
                .abstract => .{ .int64 = int.value },
            };
            try spirv.global_section.emit(.OpConstant, .{
                .id_result_type = try spirv.resolve(.{ .int_type = int.type }),
                .id_result = id,
                .value = value,
            });
        },
        .float => |float| {
            const value: spec.LiteralContextDependentNumber = switch (float.type) {
                .f16 => .{ .uint32 = @bitCast(u16, @floatCast(f16, @bitCast(f64, float.value))) },
                .f32 => .{ .float32 = @floatCast(f32, @bitCast(f64, float.value)) },
                .abstract => .{ .float64 = @bitCast(f64, float.value) },
            };
            try spirv.global_section.emit(.OpConstant, .{
                .id_result_type = try spirv.resolve(.{ .float_type = float.type }),
                .id_result = id,
                .value = value,
            });
        },
    }
    gop.value_ptr.* = id;
    return id;
}

fn allocId(spirv: *SpirV) IdResult {
    defer spirv.next_result_id += 1;
    return .{ .id = spirv.next_result_id };
}

fn fromAirBuiltin(builtin: Air.Inst.Builtin) spec.BuiltIn {
    return switch (builtin) {
        .none => unreachable,
        .vertex_index => spec.BuiltIn.VertexIndex,
        .instance_index => spec.BuiltIn.InstanceIndex,
        .position => spec.BuiltIn.Position,
        .front_facing => spec.BuiltIn.FrontFacing,
        .frag_depth => spec.BuiltIn.FragDepth,
        .local_invocation_id => spec.BuiltIn.LocalInvocationId,
        .local_invocation_index => spec.BuiltIn.LocalInvocationIndex,
        .global_invocation_id => spec.BuiltIn.GlobalInvocationId,
        .workgroup_id => spec.BuiltIn.WorkgroupId,
        .num_workgroups => spec.BuiltIn.NumWorkgroups,
        .sample_index => spec.BuiltIn.SampleMask,
        .sample_mask => spec.BuiltIn.SampleId,
    };
}
