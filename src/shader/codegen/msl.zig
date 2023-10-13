const std = @import("std");
const Air = @import("../Air.zig");
const DebugInfo = @import("../CodeGen.zig").DebugInfo;
const Inst = Air.Inst;
const InstIndex = Air.InstIndex;
const Builtin = Air.Inst.Builtin;

const Msl = @This();

// TODO - where to share?
const slot_buffer_lengths = 28;

air: *const Air,
allocator: std.mem.Allocator,
storage: std.ArrayListUnmanaged(u8),
writer: std.ArrayListUnmanaged(u8).Writer,
indent: u32 = 0,
stage: Inst.Fn.Stage = .none,
has_stage_in: bool = false,
buffer_index: u32 = 0,
texture_index: u32 = 0,
sampler_index: u32 = 0,
frag_result_inst_idx: InstIndex = .none,

pub fn gen(allocator: std.mem.Allocator, air: *const Air, debug_info: DebugInfo) ![]const u8 {
    _ = debug_info;

    var storage = std.ArrayListUnmanaged(u8){};
    var msl = Msl{
        .air = air,
        .allocator = allocator,
        .storage = storage,
        .writer = storage.writer(allocator),
    };
    defer {
        msl.storage.deinit(allocator);
    }

    try msl.writeAll("#include <metal_stdlib>\n");
    try msl.writeAll("using namespace metal;\n\n");

    // TODO - track fragment return usage on Inst.Struct so HLSL can use it as well
    for (air.refToList(air.globals_index)) |inst_idx| {
        switch (air.getInst(inst_idx)) {
            .@"fn" => |fn_inst| {
                if (fn_inst.stage == .fragment) {
                    switch (air.getInst(fn_inst.return_type)) {
                        .@"struct" => |_| {
                            msl.frag_result_inst_idx = fn_inst.return_type;
                        },
                        else => {},
                    }
                }
            },
            else => {},
        }
    }

    for (air.refToList(air.globals_index)) |inst_idx| {
        switch (air.getInst(inst_idx)) {
            .@"fn" => |inst| try msl.emitFn(inst),
            .@"struct" => |inst| try msl.emitStruct(inst_idx, inst),
            .@"const" => |inst| try msl.emitGlobalConst(inst),
            .@"var" => {},
            else => |inst| try msl.print("TopLevel: {}\n", .{inst}), // TODO
        }
    }

    return storage.toOwnedSlice(allocator);
}

fn stringFromStage(stage: Inst.Fn.Stage) []const u8 {
    return switch (stage) {
        .none => "",
        .compute => "kernel",
        .vertex => "vertex",
        .fragment => "fragment",
    };
}

fn stringFromStageCapitalized(stage: Inst.Fn.Stage) []const u8 {
    return switch (stage) {
        .none => "",
        .compute => "Kernel",
        .vertex => "Vertex",
        .fragment => "Fragment",
    };
}

fn emitType(msl: *Msl, inst_idx: InstIndex) error{OutOfMemory}!void {
    if (inst_idx == .none) {
        try msl.writeAll("void");
    } else {
        switch (msl.air.getInst(inst_idx)) {
            .bool => |inst| try msl.emitBoolType(inst),
            .int => |inst| try msl.emitIntType(inst),
            .float => |inst| try msl.emitFloatType(inst),
            .vector => |inst| try msl.emitVectorType(inst),
            .matrix => |inst| try msl.emitMatrixType(inst),
            .array => |inst| try msl.emitType(inst.elem_type),
            .@"struct" => |inst| try msl.writeName(inst.name),
            else => |inst| try msl.print("Type: {}", .{inst}), // TODO
        }
    }
}

fn emitTypeSuffix(msl: *Msl, inst_idx: InstIndex) error{OutOfMemory}!void {
    if (inst_idx != .none) {
        switch (msl.air.getInst(inst_idx)) {
            .array => |inst| try msl.emitArrayTypeSuffix(inst),
            else => {},
        }
    }
}

fn emitArrayTypeSuffix(msl: *Msl, inst: Inst.Array) !void {
    if (inst.len != .none) {
        if (msl.air.resolveInt(inst.len)) |len| {
            try msl.print("[{}]", .{len});
        }
    } else {
        // Flexible array members are a C99 feature, but Metal validation checks actual resource size not what is in the shader.
        try msl.writeAll("[1]");
    }
    try msl.emitTypeSuffix(inst.elem_type);
}

fn emitTypeAsPointer(msl: *Msl, inst_idx: InstIndex) !void {
    if (inst_idx != .none) {
        switch (msl.air.getInst(inst_idx)) {
            .array => try msl.writeAll("*"),
            else => try msl.writeAll("&"),
        }
    }
}

fn emitBoolType(msl: *Msl, inst: Inst.Bool) !void {
    _ = inst;
    try msl.writeAll("bool");
}

fn emitIntType(msl: *Msl, inst: Inst.Int) !void {
    try msl.writeAll(switch (inst.type) {
        .u32 => "uint",
        .i32 => "int",
    });
}

fn emitFloatType(msl: *Msl, inst: Inst.Float) !void {
    try msl.writeAll(switch (inst.type) {
        .f32 => "float",
        .f16 => "half",
    });
}

fn emitVectorSize(msl: *Msl, size: Inst.Vector.Size) !void {
    try msl.writeAll(switch (size) {
        .two => "2",
        .three => "3",
        .four => "4",
    });
}

fn emitVectorType(msl: *Msl, inst: Inst.Vector) !void {
    try msl.emitType(inst.elem_type);
    try msl.emitVectorSize(inst.size);
}

fn emitMatrixType(msl: *Msl, inst: Inst.Matrix) !void {
    // TODO - verify dimension order
    try msl.emitType(inst.elem_type);
    try msl.emitVectorSize(inst.cols);
    try msl.writeAll("x");
    try msl.emitVectorSize(inst.rows);
}

fn emitStruct(msl: *Msl, inst_idx: InstIndex, inst: Inst.Struct) !void {
    try msl.writeAll("struct ");
    try msl.writeName(inst.name);
    try msl.writeAll(" {\n");

    msl.enterScope();
    defer msl.exitScope();

    const struct_members = msl.air.refToList(inst.members);
    for (struct_members) |member_index| {
        const member = msl.air.getInst(member_index).struct_member;

        try msl.writeIndent();
        try msl.emitType(member.type);
        try msl.writeAll(" ");
        try msl.writeName(member.name);
        try msl.emitTypeSuffix(member.type);
        if (member.builtin) |builtin| {
            try msl.emitBuiltin(builtin);
        } else if (member.location) |location| {
            if (inst_idx == msl.frag_result_inst_idx) {
                try msl.print(" [[color({})]]", .{location});
            } else {
                try msl.print(" [[user(_{})]]", .{location});
            }
        }
        try msl.writeAll(";\n");
    }

    try msl.writeAll("};\n");
}

fn emitBuiltin(msl: *Msl, builtin: Builtin) !void {
    try msl.writeAll(" [[");
    try msl.writeAll(switch (builtin) {
        .vertex_index => "vertex_id",
        .instance_index => "instance_id",
        .position => "position",
        .front_facing => "front_facing",
        .frag_depth => "depth(any)",
        .local_invocation_id => "thread_position_in_threadgroup",
        .local_invocation_index => "thread_index_in_threadgroup",
        .global_invocation_id => "thread_position_in_grid",
        .workgroup_id => "threadgroup_position_in_grid",
        .num_workgroups => "threadgroups_per_grid",
        .sample_index => "sample_id",
        .sample_mask => "sample_mask",
    });
    try msl.writeAll("]]");
}

fn emitGlobalConst(msl: *Msl, inst: Inst.Const) !void {
    const t = if (inst.type != .none) inst.type else inst.expr;
    try msl.writeAll("constant ");
    try msl.emitType(t);
    try msl.writeAll(" ");
    try msl.writeName(inst.name);
    try msl.emitTypeSuffix(inst.type);
    try msl.writeAll(" = ");
    try msl.emitExpr(inst.expr);
    try msl.writeAll(";\n");
}

fn isStageInParameter(msl: *Msl, inst_idx: InstIndex) bool {
    const inst = msl.air.getInst(inst_idx).fn_param;
    return inst.builtin == null;
}

fn hasStageInType(msl: *Msl, inst: Inst.Fn) bool {
    if (inst.stage == .none)
        return false;

    if (inst.params != .none) {
        const param_list = msl.air.refToList(inst.params);
        for (param_list) |param_inst_idx| {
            if (msl.isStageInParameter(param_inst_idx))
                return true;
        }
    }
    return false;
}

fn emitFn(msl: *Msl, inst: Inst.Fn) !void {
    msl.stage = inst.stage;
    msl.has_stage_in = msl.hasStageInType(inst);
    // TODO - caller should provide a remapping table based on the pipeline layout, currently mach examples
    // rebind all groups on pipeline changes so this isn't needed yet.
    msl.buffer_index = 0;
    msl.texture_index = 0;
    msl.sampler_index = 0;

    try msl.emitStageInType(inst);

    if (inst.stage != .none) {
        try msl.print("{s} ", .{stringFromStage(inst.stage)});
    }
    try msl.emitType(inst.return_type);
    try msl.writeAll(" ");
    if (inst.stage != .none) {
        try msl.writeEntrypoint(inst.name);
    } else {
        try msl.writeName(inst.name);
    }
    try msl.writeAll("(");

    {
        msl.enterScope();
        defer msl.exitScope();

        var add_comma = false;

        for (msl.air.refToList(inst.global_var_refs)) |var_inst_idx| {
            const var_inst = msl.air.getInst(var_inst_idx).@"var";
            if (var_inst.addr_space == .workgroup)
                continue;

            try msl.writeAll(if (add_comma) ",\n" else "\n");
            add_comma = true;
            try msl.writeIndent();
            try msl.emitFnGlobalVar(var_inst_idx);
        }

        if (inst.has_array_length) {
            try msl.writeAll(if (add_comma) ",\n" else "\n");
            add_comma = true;
            try msl.writeIndent();
            try msl.print("constant uint* buffer_lengths [[buffer({})]]", .{slot_buffer_lengths});
        }

        if (inst.params != .none) {
            const param_list = msl.air.refToList(inst.params);
            for (param_list) |param_inst_idx| {
                if (msl.has_stage_in and msl.isStageInParameter(param_inst_idx))
                    continue;
                try msl.writeAll(if (add_comma) ",\n" else "\n");
                add_comma = true;
                try msl.writeIndent();
                try msl.emitFnParam(param_inst_idx);
            }
        }

        if (msl.has_stage_in) {
            try msl.writeAll(if (add_comma) ",\n" else "\n");
            add_comma = true;
            try msl.writeIndent();
            try msl.print("_{s}In in [[stage_in]]", .{stringFromStageCapitalized(inst.stage)});
        }
    }

    try msl.writeAll(")\n");

    const block = msl.air.getInst(inst.block).block;
    try msl.writeAll("{\n");
    {
        msl.enterScope();
        defer msl.exitScope();

        for (msl.air.refToList(inst.global_var_refs)) |var_inst_idx| {
            const var_inst = msl.air.getInst(var_inst_idx).@"var";
            if (var_inst.addr_space == .workgroup) {
                try msl.writeIndent();
                try msl.writeAll("threadgroup ");
                try msl.emitType(var_inst.type);
                try msl.writeAll(" ");
                try msl.writeName(var_inst.name);
                try msl.emitTypeSuffix(var_inst.type);
                try msl.writeAll(";\n");
            }
        }

        for (msl.air.refToList(block)) |statement| {
            try msl.emitStatement(statement);
        }
    }
    try msl.writeIndent();
    try msl.writeAll("}\n");
}

fn emitStageInType(msl: *Msl, inst: Inst.Fn) !void {
    if (!msl.has_stage_in)
        return;

    try msl.print("struct _{s}In {{\n", .{stringFromStageCapitalized(inst.stage)});
    {
        msl.enterScope();
        defer msl.exitScope();

        const param_list = msl.air.refToList(inst.params);
        for (param_list) |param_inst_idx| {
            if (!msl.isStageInParameter(param_inst_idx))
                continue;
            try msl.writeIndent();
            try msl.emitFnParam(param_inst_idx);
            try msl.writeAll(";\n");
        }
    }
    try msl.writeAll("};\n");
}

fn emitFnGlobalVar(msl: *Msl, inst_idx: InstIndex) !void {
    const inst = msl.air.getInst(inst_idx).@"var";
    const type_inst = msl.air.getInst(inst.type);

    switch (type_inst) {
        .texture_type => |texture| try msl.emitFnTexture(inst, texture),
        .sampler_type, .comparison_sampler_type => try msl.emitFnSampler(inst),
        else => try msl.emitFnBuffer(inst),
    }
}

fn emitFnTexture(msl: *Msl, inst: Inst.Var, texture: Inst.TextureType) !void {
    try msl.writeAll(switch (texture.kind) {
        .sampled_1d => "texture1d",
        .sampled_2d => "texture2d",
        .sampled_2d_array => "texture2d_array",
        .sampled_3d => "texture3d",
        .sampled_cube => "texturecube",
        .sampled_cube_array => "texturecube_array",
        .multisampled_2d => "texture2d_ms",
        .multisampled_depth_2d => "depth2d_ms",
        .storage_1d => "texture1d",
        .storage_2d => "texture2d",
        .storage_2d_array => "texture2d_array",
        .storage_3d => "texture3d",
        .depth_2d => "depth2d",
        .depth_2d_array => "depth2d_array",
        .depth_cube => "depthcube",
        .depth_cube_array => "depthcube_array",
    });
    try msl.writeAll("<");
    try msl.writeAll(switch (texture.texel_format) {
        .none => "float", // TODO - is this right?

        .rgba8unorm,
        .rgba8snorm,
        .bgra8unorm,
        .rgba16float,
        .r32float,
        .rg32float,
        .rgba32float,
        => "float",

        .rgba8uint,
        .rgba16uint,
        .r32uint,
        .rg32uint,
        .rgba32uint,
        => "uint",

        .rgba8sint,
        .rgba16sint,
        .r32sint,
        .rg32sint,
        .rgba32sint,
        => "int",
    });
    try msl.writeAll(", access::");
    try msl.writeAll(switch (texture.kind) {
        .sampled_1d,
        .sampled_2d,
        .sampled_2d_array,
        .sampled_3d,
        .sampled_cube,
        .sampled_cube_array,
        .multisampled_2d,
        .multisampled_depth_2d,
        .depth_2d,
        .depth_2d_array,
        .depth_cube,
        .depth_cube_array,
        => "sample",
        .storage_1d,
        .storage_2d,
        .storage_2d_array,
        .storage_3d,
        => "read_write", // TODO - read, write only
    });
    try msl.writeAll("> ");
    try msl.writeName(inst.name);

    try msl.print(" [[texture({})]]", .{msl.texture_index});
    msl.texture_index += 1;
}

fn emitFnSampler(msl: *Msl, inst: Inst.Var) !void {
    try msl.writeAll("sampler");
    try msl.writeAll(" ");
    try msl.writeName(inst.name);

    try msl.print(" [[sampler({})]]", .{msl.sampler_index});
    msl.sampler_index += 1;
}

fn emitFnBuffer(msl: *Msl, inst: Inst.Var) !void {
    try msl.writeAll(switch (inst.addr_space) {
        .uniform => "constant",
        else => "device",
    });
    try msl.writeAll(" ");
    try msl.emitType(inst.type);
    try msl.emitTypeAsPointer(inst.type);
    try msl.writeAll(" ");
    try msl.writeName(inst.name);
    try msl.emitTypeSuffix(inst.type);

    try msl.print(" [[buffer({})]]", .{msl.buffer_index});
    msl.buffer_index += 1;
}

fn emitFnParam(msl: *Msl, inst_idx: InstIndex) !void {
    const inst = msl.air.getInst(inst_idx).fn_param;

    try msl.emitType(inst.type);
    try msl.writeAll(" ");
    try msl.writeName(inst.name);
    if (inst.builtin) |builtin| {
        try msl.emitBuiltin(builtin);
    } else if (inst.location) |location| {
        if (msl.stage == .vertex) {
            try msl.print(" [[attribute({})]]", .{location});
        } else {
            try msl.print(" [[user(_{})]]", .{location});
        }
    }
}

fn emitStatement(msl: *Msl, inst_idx: InstIndex) error{OutOfMemory}!void {
    try msl.writeIndent();
    switch (msl.air.getInst(inst_idx)) {
        .@"var" => |inst| try msl.emitVar(inst),
        .@"const" => |inst| try msl.emitConst(inst),
        .block => |block| try msl.emitBlock(block),
        // .loop => |inst| try msl.emitLoop(inst),
        // .continuing
        .@"return" => |return_inst_idx| try msl.emitReturn(return_inst_idx),
        // .break_if
        .@"if" => |inst| try msl.emitIf(inst),
        // .@"while" => |inst| try msl.emitWhile(inst),
        .@"for" => |inst| try msl.emitFor(inst),
        // .switch
        // .increase
        // .decrease
        .discard => try msl.emitDiscard(),
        // .@"break" => try msl.emitBreak(),
        .@"continue" => try msl.writeAll("continue;\n"),
        // .call => |inst| try msl.emitCall(inst),
        .assign,
        .nil_intrinsic,
        .texture_store,
        => {
            try msl.emitExpr(inst_idx);
            try msl.writeAll(";\n");
        },
        //else => |inst| std.debug.panic("TODO: implement Air tag {s}", .{@tagName(inst)}),
        else => |inst| try msl.print("Statement: {}\n", .{inst}), // TODO
    }
}

fn emitVar(msl: *Msl, inst: Inst.Var) !void {
    const t = if (inst.type != .none) inst.type else inst.expr;
    try msl.emitType(t);
    try msl.writeAll(" ");
    try msl.writeName(inst.name);
    try msl.emitTypeSuffix(t);
    if (inst.expr != .none) {
        try msl.writeAll(" = ");
        try msl.emitExpr(inst.expr);
    }
    try msl.writeAll(";\n");
}

fn emitConst(msl: *Msl, inst: Inst.Const) !void {
    const t = if (inst.type != .none) inst.type else inst.expr;
    try msl.writeAll("const ");
    try msl.emitType(t);
    try msl.writeAll(" ");
    try msl.writeName(inst.name);
    try msl.emitTypeSuffix(inst.type);
    try msl.writeAll(" = ");
    try msl.emitExpr(inst.expr);
    try msl.writeAll(";\n");
}

fn emitReturn(msl: *Msl, inst_idx: InstIndex) !void {
    try msl.writeAll("return");
    if (inst_idx != .none) {
        try msl.writeAll(" ");
        try msl.emitExpr(inst_idx);
    }
    try msl.writeAll(";\n");
}

fn emitIf(msl: *Msl, inst: Inst.If) !void {
    try msl.writeAll("if (");
    try msl.emitExpr(inst.cond);
    try msl.writeAll(")\n");
    {
        const body_inst = msl.air.getInst(inst.body);
        if (body_inst != .block)
            msl.enterScope();
        try msl.emitStatement(inst.body);
        if (body_inst != .block)
            msl.exitScope();
    }
    if (inst.@"else" != .none) {
        try msl.writeAll(" else\n");
        try msl.emitStatement(inst.@"else");
    }
    try msl.writeAll("\n");
}

fn emitFor(msl: *Msl, inst: Inst.For) !void {
    try msl.writeAll("for (\n");
    {
        msl.enterScope();
        defer msl.exitScope();

        try msl.emitStatement(inst.init);
        try msl.writeIndent();
        try msl.emitExpr(inst.cond);
        try msl.writeAll(";\n");
        try msl.writeIndent();
        try msl.emitExpr(inst.update);
        try msl.writeAll(")\n");
    }
    try msl.emitStatement(inst.body);
}

fn emitDiscard(msl: *Msl) !void {
    try msl.writeAll("discard_fragment();\n");
}

fn emitBlock(msl: *Msl, block: Air.RefIndex) !void {
    try msl.writeAll("{\n");
    {
        msl.enterScope();
        defer msl.exitScope();

        for (msl.air.refToList(block)) |statement| {
            try msl.emitStatement(statement);
        }
    }
    try msl.writeIndent();
    try msl.writeAll("}\n");
}

fn emitExpr(msl: *Msl, inst_idx: InstIndex) error{OutOfMemory}!void {
    switch (msl.air.getInst(inst_idx)) {
        .var_ref => |inst| try msl.emitVarRef(inst),
        //.bool => |inst| msl.emitBool(inst),
        .int => |inst| try msl.emitInt(inst),
        .float => |inst| try msl.emitFloat(inst),
        .vector => |inst| try msl.emitVector(inst),
        .matrix => |inst| try msl.emitMatrix(inst),
        .array => |inst| try msl.emitArray(inst),
        .nil_intrinsic => |inst| try msl.emitNilIntrinsic(inst),
        .unary => |inst| try msl.emitUnary(inst),
        .unary_intrinsic => |inst| try msl.emitUnaryIntrinsic(inst),
        .binary => |inst| try msl.emitBinary(inst),
        .binary_intrinsic => |inst| try msl.emitBinaryIntrinsic(inst),
        .triple_intrinsic => |inst| try msl.emitTripleIntrinsic(inst),
        .assign => |inst| try msl.emitAssign(inst),
        .increase => |inst| try msl.emitIncrease(inst),
        .decrease => |inst| try msl.emitDecrease(inst),
        .field_access => |inst| try msl.emitFieldAccess(inst),
        .swizzle_access => |inst| try msl.emitSwizzleAccess(inst),
        .index_access => |inst| try msl.emitIndexAccess(inst),
        .call => |inst| try msl.emitCall(inst),
        //.struct_construct: StructConstruct,
        //.bitcast: Bitcast,
        .texture_sample => |inst| try msl.emitTextureSample(inst),
        .texture_dimension => |inst| try msl.emitTextureDimension(inst),
        .texture_load => |inst| try msl.emitTextureLoad(inst),
        .texture_store => |inst| try msl.emitTextureStore(inst),
        //else => |inst| std.debug.panic("TODO: implement Air tag {s}", .{@tagName(inst)}),
        else => |inst| try msl.print("Expr: {}", .{inst}), // TODO
    }
}

fn emitVarRef(msl: *Msl, inst_idx: InstIndex) !void {
    switch (msl.air.getInst(inst_idx)) {
        .@"var" => |v| try msl.writeName(v.name),
        .@"const" => |c| try msl.writeName(c.name),
        .fn_param => |p| {
            if (msl.has_stage_in and msl.isStageInParameter(inst_idx)) {
                try msl.writeAll("in.");
            }
            try msl.writeName(p.name);
        },
        else => |x| try msl.print("VarRef: {}", .{x}), // TODO
    }
}

fn emitInt(msl: *Msl, inst: Inst.Int) !void {
    return switch (msl.air.getValue(Inst.Int.Value, inst.value.?)) {
        .literal => |lit| try msl.print("{}", .{lit}),
        .cast => |cast| msl.emitIntCast(inst, cast),
    };
}

fn emitIntCast(msl: *Msl, dest_type: Inst.Int, cast: Inst.Cast) !void {
    try msl.emitIntType(dest_type);
    try msl.writeAll("(");
    try msl.emitExpr(cast.value);
    try msl.writeAll(")");
}

fn emitFloat(msl: *Msl, inst: Inst.Float) !void {
    return switch (msl.air.getValue(Inst.Float.Value, inst.value.?)) {
        .literal => |lit| try msl.print("{}", .{lit}),
        .cast => |cast| msl.emitFloatCast(inst, cast),
    };
}

fn emitFloatCast(msl: *Msl, dest_type: Inst.Float, cast: Inst.Cast) !void {
    try msl.emitFloatType(dest_type);
    try msl.writeAll("(");
    try msl.emitExpr(cast.value);
    try msl.writeAll(")");
}

fn emitVector(msl: *Msl, inst: Inst.Vector) !void {
    try msl.emitVectorType(inst);
    try msl.writeAll("(");

    const value = msl.air.getValue(Inst.Vector.Value, inst.value.?);
    for (value[0..@intFromEnum(inst.size)], 0..) |elem_inst, i| {
        try msl.writeAll(if (i == 0) "" else ", ");
        try msl.emitExpr(elem_inst);
    }

    try msl.writeAll(")");
}

fn emitMatrix(msl: *Msl, inst: Inst.Matrix) !void {
    try msl.emitMatrixType(inst);
    try msl.writeAll("(");

    const value = msl.air.getValue(Inst.Matrix.Value, inst.value.?);
    for (value[0..@intFromEnum(inst.cols)], 0..) |elem_inst, i| {
        try msl.writeAll(if (i == 0) "" else ", ");
        try msl.emitExpr(elem_inst);
    }

    try msl.writeAll(")");
}

fn emitArray(msl: *Msl, inst: Inst.Array) !void {
    try msl.writeAll("{");
    {
        msl.enterScope();
        defer msl.exitScope();

        const value = msl.air.refToList(inst.value.?);
        for (value, 0..) |elem_inst, i| {
            try msl.writeAll(if (i == 0) "\n" else ",\n");
            try msl.writeIndent();
            try msl.emitExpr(elem_inst);
        }
    }
    try msl.writeAll("}");
}

fn emitNilIntrinsic(msl: *Msl, op: Inst.NilIntrinsic) !void {
    try msl.writeAll(switch (op) {
        .storage_barrier => "threadgroup_barrier(mem_flags::mem_device)",
        .workgroup_barrier => "threadgroup_barrier(mem_flags::mem_threadgroup)",
    });
}

fn emitUnary(msl: *Msl, inst: Inst.Unary) !void {
    try msl.writeAll(switch (inst.op) {
        .not => "!",
        .negate => "-",
        .deref => "*",
        .addr_of => "&",
    });
    try msl.emitExpr(inst.expr);
}

fn emitUnaryIntrinsic(msl: *Msl, inst: Inst.UnaryIntrinsic) !void {
    const result_type = msl.air.getInst(inst.result_type);
    switch (inst.op) {
        .array_length => try msl.emitArrayLength(inst),
        .degrees => {
            try msl.writeAll("(");
            try msl.emitExpr(inst.expr);
            try msl.print(" * {}", .{180.0 / std.math.pi});
            try msl.writeAll(")");
        },
        .radians => {
            try msl.writeAll("(");
            try msl.emitExpr(inst.expr);
            try msl.print(" * {}", .{std.math.pi / 180.0});
            try msl.writeAll(")");
        },
        else => {
            try msl.writeAll(switch (inst.op) {
                .array_length => unreachable,
                .degrees => unreachable,
                .radians => unreachable,
                .all => "all",
                .any => "any",
                .abs => if (result_type == .float) "fabs" else "abs",
                .acos => "acos",
                .acosh => "acosh",
                .asin => "asin",
                .asinh => "asinh",
                .atan => "atan",
                .atanh => "atanh",
                .ceil => "ceil",
                .cos => "cos",
                .cosh => "cosh",
                .count_leading_zeros => "clz",
                .count_one_bits => "popcount",
                .count_trailing_zeros => "ctz",
                .exp => "exp",
                .exp2 => "exp2",
                //.first_leading_bit => "first_leading_bit",
                //.first_trailing_bit => "first_trailing_bit",
                .floor => "floor",
                .fract => "fract",
                .inverse_sqrt => "rsqrt",
                //.length => "length",
                .log => "log",
                .log2 => "log2",
                //.quantize_to_F16 => "quantize_to_F16",
                .reverseBits => "reverse_bits",
                .round => "rint",
                //.saturate => "saturate",
                .sign => "sign",
                .sin => "sin",
                .sinh => "sinh",
                .sqrt => "sqrt",
                .tan => "tan",
                .tanh => "tanh",
                .trunc => "trunc",
                .dpdx => "dfdx",
                .dpdx_coarse => "dfdx",
                .dpdx_fine => "dfdx",
                .dpdy => "dfdy",
                .dpdy_coarse => "dfdy",
                .dpdy_fine => "dfdy",
                .fwidth => "fwidth",
                .fwidth_coarse => "fwidth",
                .fwidth_fine => "fwidth",
                .normalize => "normalize",
                .length => "length",
                else => std.debug.panic("TODO: implement Air tag {s}", .{@tagName(inst.op)}),
            });
            try msl.writeAll("(");
            try msl.emitExpr(inst.expr);
            try msl.writeAll(")");
        },
    }
}

fn emitArrayLength(msl: *Msl, inst: Inst.UnaryIntrinsic) !void {
    switch (msl.air.getInst(inst.expr)) {
        .unary => |un| switch (un.op) {
            .addr_of => try msl.emitArrayLengthTarget(un.expr, 0),
            else => try msl.print("ArrayLength (unary_op): {}", .{un.op}),
        },
        else => |array_length_expr| try msl.print("ArrayLength (array_length_expr): {}", .{array_length_expr}),
    }
}

fn emitArrayLengthTarget(msl: *Msl, inst_idx: InstIndex, offset: usize) error{OutOfMemory}!void {
    switch (msl.air.getInst(inst_idx)) {
        .var_ref => |var_ref_inst_idx| try msl.emitArrayLengthVarRef(var_ref_inst_idx, offset),
        .field_access => |inst| try msl.emitArrayLengthFieldAccess(inst, offset),
        else => |inst| try msl.print("ArrayLengthTarget: {}", .{inst}),
    }
}

fn emitArrayLengthVarRef(msl: *Msl, inst_idx: InstIndex, offset: usize) !void {
    switch (msl.air.getInst(inst_idx)) {
        .@"var" => |var_inst| {
            if (msl.air.resolveInt(var_inst.binding)) |binding| {
                try msl.print("(buffer_lengths[{}] / sizeof(", .{binding});
                try msl.emitType(var_inst.type);
                try msl.print(") - {})", .{offset});
            }
        },
        else => |var_ref_expr| try msl.print("arrayLength (var_ref_expr): {}", .{var_ref_expr}),
    }
}

fn emitArrayLengthFieldAccess(msl: *Msl, inst: Inst.FieldAccess, base_offset: usize) !void {
    const member_offset = 0; // TODO
    try msl.emitArrayLengthTarget(inst.base, base_offset + member_offset);
}

fn emitBinary(msl: *Msl, inst: Inst.Binary) !void {
    try msl.writeAll("(");
    try msl.emitExpr(inst.lhs);
    try msl.print(" {s} ", .{switch (inst.op) {
        .mul => "*",
        .div => "/",
        .mod => "%",
        .add => "+",
        .sub => "-",
        .shl => "<<",
        .shr => ">>",
        .@"and" => "&",
        .@"or" => "|",
        .xor => "^",
        .logical_and => "&&",
        .logical_or => "||",
        .equal => "==",
        .not_equal => "!=",
        .less_than => "<",
        .less_than_equal => "<=",
        .greater_than => ">",
        .greater_than_equal => ">=",
    }});
    try msl.emitExpr(inst.rhs);
    try msl.writeAll(")");
}

fn emitBinaryIntrinsic(msl: *Msl, inst: Inst.BinaryIntrinsic) !void {
    const result_type = msl.air.getInst(inst.result_type);
    try msl.writeAll(switch (inst.op) {
        .min => if (result_type == .float) "fmin" else "min",
        .max => if (result_type == .float) "fmax" else "max",
        .atan2 => "atan2",
        .distance => "distance",
        .dot => "dot",
        .pow => "pow",
        .step => "step",
    });
    try msl.writeAll("(");
    try msl.emitExpr(inst.lhs);
    try msl.writeAll(", ");
    try msl.emitExpr(inst.rhs);
    try msl.writeAll(")");
}

fn emitTripleIntrinsic(msl: *Msl, inst: Inst.TripleIntrinsic) !void {
    try msl.writeAll(switch (inst.op) {
        .smoothstep => "smoothstep",
        .clamp => "clamp",
        .mix => "mix",
    });
    try msl.writeAll("(");
    try msl.emitExpr(inst.a1);
    try msl.writeAll(", ");
    try msl.emitExpr(inst.a2);
    try msl.writeAll(", ");
    try msl.emitExpr(inst.a3);
    try msl.writeAll(")");
}

fn emitAssign(msl: *Msl, inst: Inst.Assign) !void {
    try msl.emitExpr(inst.lhs);
    try msl.print(" {s}= ", .{switch (inst.mod) {
        .none => "",
        .add => "+",
        .sub => "-",
        .mul => "*",
        .div => "/",
        .mod => "%",
        .@"and" => "&",
        .@"or" => "|",
        .xor => "^",
        .shl => "<<",
        .shr => ">>",
    }});
    try msl.emitExpr(inst.rhs);
}

fn emitIncrease(msl: *Msl, inst_index: InstIndex) !void {
    try msl.emitExpr(inst_index);
    try msl.writeAll("++");
}

fn emitDecrease(msl: *Msl, inst_index: InstIndex) !void {
    try msl.emitExpr(inst_index);
    try msl.writeAll("--");
}

fn emitFieldAccess(msl: *Msl, inst: Inst.FieldAccess) !void {
    try msl.emitExpr(inst.base);
    try msl.writeAll(".");
    try msl.writeName(inst.name);
}

fn emitSwizzleAccess(msl: *Msl, inst: Inst.SwizzleAccess) !void {
    try msl.emitExpr(inst.base);
    try msl.writeAll(".");
    for (0..@intFromEnum(inst.size)) |i| {
        switch (inst.pattern[i]) {
            .x => try msl.writeAll("x"),
            .y => try msl.writeAll("y"),
            .z => try msl.writeAll("z"),
            .w => try msl.writeAll("w"),
        }
    }
}

fn emitIndexAccess(msl: *Msl, inst: Inst.IndexAccess) !void {
    try msl.emitExpr(inst.base);
    try msl.writeAll("[");
    try msl.emitExpr(inst.index);
    try msl.writeAll("]");
}

fn emitCall(msl: *Msl, inst: Inst.FnCall) !void {
    const fn_inst = msl.air.getInst(inst.@"fn").@"fn";

    try msl.writeName(fn_inst.name);
    try msl.writeAll("(");
    var add_comma = false;

    for (msl.air.refToList(fn_inst.global_var_refs)) |var_inst_idx| {
        try msl.writeAll(if (add_comma) ", " else "");
        add_comma = true;
        const var_inst = msl.air.getInst(var_inst_idx).@"var";
        try msl.writeName(var_inst.name);
    }
    if (inst.args != .none) {
        for (msl.air.refToList(inst.args)) |arg_inst_idx| {
            try msl.writeAll(if (add_comma) ", " else "");
            add_comma = true;
            try msl.emitExpr(arg_inst_idx);
        }
    }
    try msl.writeAll(")");
}

fn emitTextureSample(msl: *Msl, inst: Inst.TextureSample) !void {
    try msl.emitExpr(inst.texture);
    try msl.writeAll(".sample(");
    try msl.emitExpr(inst.sampler);
    try msl.writeAll(", ");
    try msl.emitExpr(inst.coords);
    try msl.writeAll(")");
}

fn emitTextureDimension(msl: *Msl, inst: Inst.TextureDimension) !void {
    try msl.writeAll("uint2("); // TODO
    try msl.emitExpr(inst.texture);
    try msl.writeAll(".get_width()");
    try msl.writeAll(", ");
    try msl.emitExpr(inst.texture);
    try msl.writeAll(".get_height()");
    try msl.writeAll(")");
}

fn emitTextureLoad(msl: *Msl, inst: Inst.TextureLoad) !void {
    try msl.emitExpr(inst.texture);
    try msl.writeAll(".read(");
    try msl.writeAll("uint2("); // TODO
    try msl.emitExpr(inst.coords);
    try msl.writeAll(")");
    try msl.writeAll(", ");
    try msl.emitExpr(inst.level);
    try msl.writeAll(")");
}

fn emitTextureStore(msl: *Msl, inst: Inst.TextureStore) !void {
    try msl.emitExpr(inst.texture);
    try msl.writeAll(".write(");
    try msl.emitExpr(inst.value);
    try msl.writeAll(", ");
    try msl.writeAll("uint2("); // TODO
    try msl.emitExpr(inst.coords);
    try msl.writeAll(")");
    try msl.writeAll(")");
}

fn enterScope(msl: *Msl) void {
    msl.indent += 4;
}

fn exitScope(msl: *Msl) void {
    msl.indent -= 4;
}

fn writeIndent(msl: *Msl) !void {
    try msl.writer.writeByteNTimes(' ', msl.indent);
}

fn writeEntrypoint(msl: *Msl, name: Air.StringIndex) !void {
    const str = msl.air.getStr(name);
    if (std.mem.eql(u8, str, "main")) {
        try msl.writeAll("main_");
    } else {
        try msl.writeAll(str);
    }
}

fn writeName(msl: *Msl, name: Air.StringIndex) !void {
    // Suffix with index as WGSL has different scoping rules and to avoid conflicts with keywords
    const str = msl.air.getStr(name);
    try msl.print("{s}_{}", .{ str, @intFromEnum(name) });
}

fn writeAll(msl: *Msl, bytes: []const u8) !void {
    try msl.writer.writeAll(bytes);
}

fn print(msl: *Msl, comptime format: []const u8, args: anytype) !void {
    return std.fmt.format(msl.writer, format, args);
}
