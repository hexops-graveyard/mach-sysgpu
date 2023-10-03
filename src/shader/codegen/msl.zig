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
indent: u32,
stage: Inst.Fn.Stage,

pub fn gen(allocator: std.mem.Allocator, air: *const Air, debug_info: DebugInfo) ![]const u8 {
    _ = debug_info;

    var storage = std.ArrayListUnmanaged(u8){};
    var msl = Msl{
        .air = air,
        .allocator = allocator,
        .storage = storage,
        .writer = storage.writer(allocator),
        .indent = 0,
        .stage = .none,
    };
    defer {
        msl.storage.deinit(allocator);
    }

    try msl.writeAll("#include <metal_stdlib>\n");
    try msl.writeAll("using namespace metal;\n\n");

    for (air.refToList(air.globals_index)) |inst_idx| {
        switch (air.getInst(inst_idx)) {
            .@"fn" => |inst| try msl.emitFn(inst),
            .@"struct" => |inst| try msl.emitStruct(inst),
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
            //.bool
            .int => |inst| try msl.emitIntType(inst),
            .float => |inst| try msl.emitFloatType(inst),
            .vector => |inst| try msl.emitVectorType(inst),
            .matrix => |inst| try msl.emitMatrixType(inst),
            .array => |inst| try msl.emitType(inst.elem_type),
            .@"struct" => |inst| try msl.writeAll(msl.air.getStr(inst.name)),
            else => |inst| try msl.print("Type: {}", .{inst}), // TODO
        }
    }
}

fn emitTypeSuffix(msl: *Msl, inst_idx: InstIndex) !void {
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
}

fn emitTypeAsPointer(msl: *Msl, inst_idx: InstIndex) !void {
    if (inst_idx != .none) {
        switch (msl.air.getInst(inst_idx)) {
            .array => try msl.writeAll("*"),
            else => try msl.writeAll("&"),
        }
    }
}

fn emitIntType(msl: *Msl, inst: Inst.Int) !void {
    switch (inst.type) {
        .u32 => try msl.writeAll("uint"),
        .i32 => try msl.writeAll("int"),
    }
}

fn emitFloatType(msl: *Msl, inst: Inst.Float) !void {
    _ = inst;
    try msl.writeAll("float");
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

fn emitStruct(msl: *Msl, inst: Inst.Struct) !void {
    try msl.print("struct {s} {{\n", .{msl.air.getStr(inst.name)});

    msl.enterScope();
    defer msl.exitScope();

    const struct_members = msl.air.refToList(inst.members);
    for (struct_members) |member_index| {
        const member = msl.air.getInst(member_index).struct_member;

        try msl.writeIndent();
        try msl.emitType(member.type);
        try msl.writeAll(" ");
        try msl.writeAll(msl.air.getStr(member.name));
        try msl.emitTypeSuffix(member.type);
        if (member.builtin) |builtin| {
            try msl.emitBuiltin(builtin);
        } else if (member.location) |location| {
            try msl.print(" [[attribute({})]]", .{location});
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

fn isStageInParameter(msl: *Msl, inst_idx: InstIndex) bool {
    const inst = msl.air.getInst(inst_idx).fn_param;
    return inst.builtin == null;
}

fn hasStageInType(msl: *Msl, inst: Inst.Fn) bool {
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

    const has_stage_in = msl.hasStageInType(inst);
    if (has_stage_in) {
        try msl.emitStageInType(inst);
    }

    if (inst.stage != .none) {
        try msl.print("{s} ", .{stringFromStage(inst.stage)});
    }
    try msl.emitType(inst.return_type);

    const fn_name = msl.air.getStr(inst.name);
    const mtl_fn_name = if (std.mem.eql(u8, fn_name, "main")) "main_" else fn_name;
    try msl.print(" {s}(", .{mtl_fn_name});

    {
        msl.enterScope();
        defer msl.exitScope();

        var add_comma = false;

        const global_var_ref_list = msl.air.refToList(inst.global_var_refs);
        for (global_var_ref_list) |var_inst_idx| {
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
                if (msl.isStageInParameter(param_inst_idx))
                    continue;
                try msl.writeAll(if (add_comma) ",\n" else "\n");
                add_comma = true;
                try msl.writeIndent();
                try msl.emitFnParam(param_inst_idx);
            }
        }

        if (has_stage_in) {
            // TODO - name collisions
            try msl.writeAll(if (add_comma) ",\n" else "\n");
            add_comma = true;
            try msl.writeIndent();
            try msl.print("{s}In in [[stage_in]]", .{stringFromStageCapitalized(inst.stage)});
        }
    }

    try msl.writeAll(")\n");
    try msl.emitStatement(inst.block);
}

fn emitStageInType(msl: *Msl, inst: Inst.Fn) !void {
    try msl.print("struct {s}In {{\n", .{stringFromStageCapitalized(inst.stage)});
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

    try msl.writeAll(if (inst.addr_space == .uniform) "constant" else "device");
    try msl.writeAll(" ");
    try msl.emitType(inst.type);
    try msl.emitTypeAsPointer(inst.type);
    try msl.print(" {s}", .{msl.air.getStr(inst.name)});

    // TODO - slot mapping and different object types
    if (msl.air.resolveInt(inst.binding)) |binding| {
        try msl.print(" [[buffer({})]]", .{binding});
    }
}

fn emitFnParam(msl: *Msl, inst_idx: InstIndex) !void {
    const inst = msl.air.getInst(inst_idx).fn_param;

    try msl.emitType(inst.type);
    try msl.print(" {s}", .{msl.air.getStr(inst.name)});
    if (inst.builtin) |builtin| {
        try msl.emitBuiltin(builtin);
    } else if (inst.location) |location| {
        if (msl.stage == .vertex) {
            try msl.print(" [[attribute({})]]", .{location});
        }
    }
}

fn emitStatement(msl: *Msl, inst_idx: InstIndex) error{OutOfMemory}!void {
    try msl.writeIndent();
    switch (msl.air.getInst(inst_idx)) {
        .@"var" => |inst| try msl.emitVar(inst),
        .block => |block| try msl.emitBlock(block),
        // .loop => |inst| try msl.emitLoop(inst),
        // .continuing
        .@"return" => |return_inst_idx| try msl.emitReturn(return_inst_idx),
        // .break_if
        .@"if" => |inst| try msl.emitIf(inst),
        // .@"while" => |inst| try msl.emitWhile(inst),
        .@"for" => |inst| try msl.emitFor(inst),
        // .switch
        .assign => |inst| try msl.emitAssignStmt(inst),
        // .increase
        // .decrease
        // .discard
        // .@"break" => try msl.emitBreak(),
        .@"continue" => try msl.writeAll("continue;\n"),
        // .call => |inst| try msl.emitCall(inst),
        //else => |inst| std.debug.panic("TODO: implement Air tag {s}", .{@tagName(inst)}),
        else => |inst| try msl.print("Statement: {}\n", .{inst}), // TODO
    }
}

fn emitVar(msl: *Msl, inst: Inst.Var) !void {
    const t = if (inst.type != .none) inst.type else inst.expr;
    try msl.emitType(t);
    try msl.print(" {s}", .{msl.air.getStr(inst.name)});
    try msl.emitTypeSuffix(t);
    if (inst.expr != .none) {
        try msl.writeAll(" = ");
        try msl.emitExpr(inst.expr);
    }
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

fn emitAssignStmt(msl: *Msl, inst: Inst.Assign) !void {
    try msl.emitAssign(inst);
    try msl.writeAll(";\n");
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
        //.matrix => |inst| msl.emitMatrix(inst),
        .array => |inst| try msl.emitArray(inst),
        .unary => |inst| try msl.emitUnary(inst),
        .unary_intrinsic => |inst| try msl.emitUnaryIntrinsic(inst),
        .binary => |inst| try msl.emitBinary(inst),
        .binary_intrinsic => |inst| try msl.emitBinaryIntrinsic(inst),
        .triple_intrinsic => |inst| try msl.emitTripleIntrinsic(inst),
        .assign => |inst| try msl.emitAssign(inst),
        .field_access => |inst| try msl.emitFieldAccess(inst),
        .swizzle_access => |inst| try msl.emitSwizzleAccess(inst),
        .index_access => |inst| try msl.emitIndexAccess(inst),
        //.call => |inst| msl.emitCall(inst),
        //.struct_construct: StructConstruct,
        //.bitcast: Bitcast,
        //else => |inst| std.debug.panic("TODO: implement Air tag {s}", .{@tagName(inst)}),
        else => |inst| try msl.print("Expr: {}", .{inst}), // TODO
    }
}

fn emitVarRef(msl: *Msl, inst_idx: InstIndex) !void {
    switch (msl.air.getInst(inst_idx)) {
        .@"var" => |v| try msl.writeAll(msl.air.getStr(v.name)),
        .fn_param => |p| {
            if (msl.isStageInParameter(inst_idx)) {
                try msl.writeAll("in.");
            }
            try msl.writeAll(msl.air.getStr(p.name));
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
    try msl.emitType(inst.elem_type);
    switch (inst.size) {
        .two => try msl.writeAll("2"),
        .three => try msl.writeAll("3"),
        .four => try msl.writeAll("4"),
    }

    try msl.writeAll("(");

    const value = msl.air.getValue(Inst.Vector.Value, inst.value.?);
    for (value[0..@intFromEnum(inst.size)], 0..) |elem_inst, i| {
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
        else => {
            try msl.writeAll(switch (inst.op) {
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
                //.degrees => "degrees",
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
                //.radians => "radians",
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
    });
    try msl.writeAll("(");
    try msl.emitExpr(inst.lhs);
    try msl.writeAll(", ");
    try msl.emitExpr(inst.rhs);
    try msl.writeAll(")");
}

fn emitTripleIntrinsic(msl: *Msl, inst: Inst.TripleIntrinsic) !void {
    try msl.writeAll(switch (inst.op) {
        .clamp => "clamp",
        else => std.debug.panic("TODO: implement Air tag {s}", .{@tagName(inst.op)}),
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

fn emitFieldAccess(msl: *Msl, inst: Inst.FieldAccess) !void {
    try msl.emitExpr(inst.base);
    try msl.print(".{s}", .{msl.air.getStr(inst.name)});
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

fn enterScope(msl: *Msl) void {
    msl.indent += 4;
}

fn exitScope(msl: *Msl) void {
    msl.indent -= 4;
}

fn writeIndent(msl: *Msl) !void {
    try msl.writer.writeByteNTimes(' ', msl.indent);
}

fn writeAll(msl: *Msl, bytes: []const u8) !void {
    try msl.writer.writeAll(bytes);
}

fn print(msl: *Msl, comptime format: []const u8, args: anytype) !void {
    return std.fmt.format(msl.writer, format, args);
}
