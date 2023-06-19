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
name_section: Section,
decor_section: Section,
type_section: Section,
global_section: Section,
main_section: Section,
cache: std.AutoArrayHashMapUnmanaged(Key, IdRef) = .{},
decl_map: std.AutoHashMapUnmanaged(InstIndex, IdRef) = .{},
capabilities: std.ArrayListUnmanaged(spec.Capability) = .{},
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
        .name_section = .{ .allocator = allocator },
        .decor_section = .{ .allocator = allocator },
        .type_section = .{ .allocator = allocator },
        .global_section = .{ .allocator = allocator },
        .main_section = .{ .allocator = allocator },
    };
    defer {
        spirv.name_section.deinit();
        spirv.decor_section.deinit();
        spirv.type_section.deinit();
        spirv.global_section.deinit();
        spirv.main_section.deinit();
        spirv.cache.deinit(allocator);
        spirv.decl_map.deinit(allocator);
        spirv.capabilities.deinit(allocator);
    }

    var module_section = Section{ .allocator = allocator };
    defer module_section.deinit();

    for (air.refToList(air.globals_index)) |inst_idx| {
        _ = try spirv.emitGlobalDecl(inst_idx);
    }

    try spirv.emitModule(&module_section);
    try module_section.append(spirv.name_section);
    try module_section.append(spirv.decor_section);
    try module_section.append(spirv.type_section);
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
    for (spirv.capabilities.items) |capability| {
        try section.emit(.OpCapability, .{ .capability = capability });
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

    const return_type_id = if (inst.return_type != .none)
        try spirv.emitType(inst.return_type)
    else
        try spirv.resolve(.void_type);

    var params_type = std.ArrayList(IdRef).init(spirv.allocator);
    defer params_type.deinit();

    if (inst.params != .none) {
        const param_list = spirv.air.refToList(inst.params);
        try params_type.ensureUnusedCapacity(param_list.len);
        for (param_list) |param_inst_idx| {
            const param_inst = spirv.air.getInst(param_inst_idx).fn_param;
            const param_type_id = try spirv.emitType(param_inst.type);

            const param_id = spirv.allocId();
            try spirv.name_section.emit(.OpName, .{
                .target = param_id,
                .name = spirv.air.getStr(param_inst.name),
            });

            if (param_inst.builtin != .none) {
                try spirv.decor_section.emit(.OpDecorate, .{
                    .target = param_id,
                    .decoration = .{ .BuiltIn = .{
                        .built_in = switch (param_inst.builtin) {
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
                        },
                    } },
                });
            }

            params_type.appendAssumeCapacity(param_type_id);
        }
    }

    const fn_type_id = spirv.allocId();
    try spirv.global_section.emit(.OpTypeFunction, .{
        .id_result = fn_type_id,
        .return_type = return_type_id,
        .id_ref_2 = params_type.items,
    });

    const id = spirv.allocId();
    try fn_section.emit(.OpFunction, .{
        .id_result_type = return_type_id,
        .id_result = id,
        .function_control = .{ .Const = inst.is_const },
        .function_type = fn_type_id,
    });
    try spirv.emitBlock(&fn_section, spirv.air.getInst(inst.block).block);
    if (inst.return_type == .none) try spirv.emitReturn(&fn_section, .none);
    try fn_section.emit(.OpFunctionEnd, {});

    const name_slice = spirv.air.getStr(inst.name);
    try spirv.name_section.emit(.OpName, .{
        .target = id,
        .name = name_slice,
    });
    switch (inst.stage) {
        .none => {},
        .compute => |compute| spirv.compute_stage = .{
            .id = id,
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
        .vertex => spirv.vertex_stage = .{ .id = id, .name = name_slice },
        .fragment => spirv.fragment_stage = .{ .id = id, .name = name_slice },
    }

    try spirv.main_section.append(fn_section);
    return id;
}

fn emitType(spirv: *SpirV, inst: InstIndex) error{OutOfMemory}!IdRef {
    return switch (spirv.air.getInst(inst)) {
        .int => |int| try spirv.resolve(.{
            .int_type = .{
                .width = int.type.width(),
                .signedness = int.type.signedness(),
            },
        }),
        .float => |float| try spirv.resolve(.{
            .float_type = .{
                .width = float.type.width(),
            },
        }),
        .vector => |vector| try spirv.resolve(.{
            .vector_type = .{
                .size = @enumToInt(vector.size),
                .elem_type = try spirv.emitType(vector.elem_type),
            },
        }),
        .matrix => |matrix| try spirv.resolve(.{
            .matrix_type = .{
                .cols = @enumToInt(matrix.cols),
                .elem_type = try spirv.resolve(.{
                    .vector_type = .{
                        .size = @enumToInt(matrix.rows),
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
        else => .{ .id = 1 }, // TODO: make this unreachable
    };
}

fn emitBlock(spirv: *SpirV, section: *Section, inst: RefIndex) !void {
    const block_id = spirv.allocId();
    try section.emit(.OpLabel, .{ .id_result = block_id });

    if (inst != .none) {
        for (spirv.air.refToList(inst)) |statement| {
            switch (spirv.air.getInst(statement)) {
                .@"return" => |stmnt_inst| try spirv.emitReturn(section, stmnt_inst),
                .call => |stmnt_inst| _ = try spirv.emitCall(section, stmnt_inst),
                else => {}, // TODO: unreachable
            }
        }
    }
}

fn emitReturn(spirv: *SpirV, section: *Section, inst: InstIndex) !void {
    if (inst == .none) return section.emit(.OpReturn, {});
    try section.emit(.OpReturnValue, .{ .value = try spirv.emitExpr(section, inst) });
}

fn emitExpr(spirv: *SpirV, section: *Section, inst_idx: InstIndex) !IdRef {
    return switch (spirv.air.getInst(inst_idx)) {
        .int => |int| switch (spirv.air.getValue(Inst.Int.Value, int.value.?)) {
            .literal => |lit| try spirv.constInt(int.type, lit.value),
            .inst => |val_inst| try spirv.emitExpr(section, val_inst),
        },
        .float => |float| switch (spirv.air.getValue(Inst.Float.Value, float.value.?)) {
            .literal => |lit| try spirv.constFloat(float.type, lit.value),
            .inst => |val_inst| try spirv.emitExpr(section, val_inst),
        },
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

fn constInt(spirv: *SpirV, ty: Inst.Int.Type, value: i64) !IdRef {
    return spirv.resolve(.{
        .int = .{
            .type_ref = try spirv.resolve(.{
                .int_type = .{
                    .width = ty.width(),
                    .signedness = ty.signedness(),
                },
            }),
            .type = ty,
            .value = value,
        },
    });
}

fn constFloat(spirv: *SpirV, ty: Inst.Float.Type, value: f64) !IdRef {
    const coerced_type = if (value <= std.math.floatMax(f32) and ty == .abstract) .f32 else ty;
    return spirv.resolve(.{
        .float = .{
            .type_ref = try spirv.resolve(.{
                .float_type = .{ .width = coerced_type.width() },
            }),
            .type = coerced_type,
            .value = @bitCast(u64, value),
        },
    });
}

const Key = union(enum) {
    void_type,
    int_type: IntType,
    float_type: FloatType,
    vector_type: VectorType,
    matrix_type: MatrixType,
    array_type: ArrayType,
    int: Int,
    float: Float,

    const IntType = struct {
        width: u8,
        signedness: bool,
    };

    const FloatType = struct { width: u8 };

    const VectorType = struct {
        size: u8,
        elem_type: IdRef,
    };

    const MatrixType = struct {
        cols: u8,
        elem_type: IdRef,
    };

    const ArrayType = struct {
        len: ?IdRef,
        elem_type: IdRef,
    };

    const Int = struct {
        type_ref: IdRef,
        type: Inst.Int.Type,
        value: i64,
    };

    const Float = struct {
        type_ref: IdRef,
        type: Inst.Float.Type,
        value: u64,
    };
};

pub fn resolve(spirv: *SpirV, key: Key) !IdRef {
    var gop = try spirv.cache.getOrPut(spirv.allocator, key);
    if (gop.found_existing) return gop.value_ptr.*;

    const id = spirv.allocId();
    switch (key) {
        .void_type => try spirv.type_section.emit(.OpTypeVoid, .{ .id_result = id }),
        .int_type => |int| try spirv.type_section.emit(.OpTypeInt, .{
            .id_result = id,
            .width = int.width,
            .signedness = @boolToInt(int.signedness),
        }),
        .float_type => |float| {
            switch (float.width) {
                16 => try spirv.capabilities.append(spirv.allocator, .Float16),
                64 => try spirv.capabilities.append(spirv.allocator, .Float64),
                else => {},
            }
            try spirv.type_section.emit(.OpTypeFloat, .{
                .id_result = id,
                .width = float.width,
            });
        },
        .vector_type => |vector| try spirv.type_section.emit(.OpTypeVector, .{
            .id_result = id,
            .component_type = vector.elem_type,
            .component_count = vector.size,
        }),
        .matrix_type => |matrix| try spirv.type_section.emit(.OpTypeMatrix, .{
            .id_result = id,
            .column_type = matrix.elem_type,
            .column_count = matrix.cols,
        }),
        .array_type => |array| {
            if (array.len) |len| {
                try spirv.type_section.emit(.OpTypeArray, .{
                    .id_result = id,
                    .element_type = array.elem_type,
                    .length = len,
                });
            } else unreachable;
        },
        .int => |int| {
            const value: spec.LiteralContextDependentNumber = switch (int.type) {
                .u32 => .{ .uint32 = @intCast(u32, int.value) },
                .i32 => .{ .int32 = @intCast(i32, int.value) },
                .abstract => .{ .int64 = int.value },
            };
            try spirv.global_section.emit(.OpConstant, .{
                .id_result_type = int.type_ref,
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
                .id_result_type = float.type_ref,
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
