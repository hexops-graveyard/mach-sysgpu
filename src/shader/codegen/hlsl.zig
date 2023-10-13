const std = @import("std");
const Air = @import("../Air.zig");
const DebugInfo = @import("../CodeGen.zig").DebugInfo;
const Inst = Air.Inst;
const InstIndex = Air.InstIndex;
const Builtin = Air.Inst.Builtin;

const Hlsl = @This();

air: *const Air,
allocator: std.mem.Allocator,
storage: std.ArrayListUnmanaged(u8),
writer: std.ArrayListUnmanaged(u8).Writer,
indent: u32 = 0,

pub fn gen(allocator: std.mem.Allocator, air: *const Air, debug_info: DebugInfo) ![]const u8 {
    _ = debug_info;

    var storage = std.ArrayListUnmanaged(u8){};
    var hlsl = Hlsl{
        .air = air,
        .allocator = allocator,
        .storage = storage,
        .writer = storage.writer(allocator),
    };
    defer {
        hlsl.storage.deinit(allocator);
    }

    for (air.refToList(air.globals_index)) |inst_idx| {
        switch (air.getInst(inst_idx)) {
            .@"var" => |inst| try hlsl.emitGlobalVar(inst),
            .@"fn" => |inst| try hlsl.emitFn(inst),
            .@"struct" => |inst| try hlsl.emitStruct(inst_idx, inst, false),
            else => |inst| try hlsl.print("TopLevel: {}\n", .{inst}), // TODO
        }
    }

    return storage.toOwnedSlice(allocator);
}

fn emitType(hlsl: *Hlsl, inst_idx: InstIndex) error{OutOfMemory}!void {
    if (inst_idx == .none) {
        try hlsl.writeAll("void");
    } else {
        switch (hlsl.air.getInst(inst_idx)) {
            //.bool
            .int => |inst| try hlsl.emitIntType(inst),
            .float => |inst| try hlsl.emitFloatType(inst),
            .vector => |inst| try hlsl.emitVectorType(inst),
            .matrix => |inst| try hlsl.emitMatrixType(inst),
            .array => |inst| try hlsl.emitType(inst.elem_type),
            .@"struct" => |inst| try hlsl.writeName(hlsl.air.getStr(inst.name)),
            else => |inst| try hlsl.print("Type: {}", .{inst}), // TODO
        }
    }
}

fn emitTypeSuffix(hlsl: *Hlsl, inst_idx: InstIndex) !void {
    if (inst_idx != .none) {
        switch (hlsl.air.getInst(inst_idx)) {
            .array => |inst| try hlsl.emitArrayTypeSuffix(inst),
            else => {},
        }
    }
}

fn emitArrayTypeSuffix(hlsl: *Hlsl, inst: Inst.Array) !void {
    if (inst.len != .none) {
        if (hlsl.air.resolveInt(inst.len)) |len| {
            try hlsl.print("[{}]", .{len});
        }
    } else {
        try hlsl.writeAll("[1]");
    }
}

fn emitTypeAsPointer(hlsl: *Hlsl, inst_idx: InstIndex) !void {
    if (inst_idx != .none) {
        switch (hlsl.air.getInst(inst_idx)) {
            .array => try hlsl.writeAll("*"),
            else => try hlsl.writeAll("&"),
        }
    }
}

fn emitIntType(hlsl: *Hlsl, inst: Inst.Int) !void {
    switch (inst.type) {
        .u32 => try hlsl.writeAll("uint"),
        .i32 => try hlsl.writeAll("int"),
    }
}

fn emitFloatType(hlsl: *Hlsl, inst: Inst.Float) !void {
    _ = inst;
    try hlsl.writeAll("float");
}

fn emitVectorSize(hlsl: *Hlsl, size: Inst.Vector.Size) !void {
    try hlsl.writeAll(switch (size) {
        .two => "2",
        .three => "3",
        .four => "4",
    });
}

fn emitVectorType(hlsl: *Hlsl, inst: Inst.Vector) !void {
    try hlsl.emitType(inst.elem_type);
    try hlsl.emitVectorSize(inst.size);
}

fn emitMatrixType(hlsl: *Hlsl, inst: Inst.Matrix) !void {
    // TODO - verify dimension order
    try hlsl.emitType(inst.elem_type);
    try hlsl.emitVectorSize(inst.cols);
    try hlsl.writeAll("x");
    try hlsl.emitVectorSize(inst.rows);
}

fn structMemberLessThan(hlsl: *Hlsl, lhs: InstIndex, rhs: InstIndex) bool {
    const lhs_member = hlsl.air.getInst(lhs).struct_member;
    const rhs_member = hlsl.air.getInst(rhs).struct_member;

    // Location
    if (lhs_member.location != null and rhs_member.location == null) return true;
    if (lhs_member.location == null and rhs_member.location != null) return false;

    const lhs_location = lhs_member.location orelse 0;
    const rhs_location = rhs_member.location orelse 0;

    if (lhs_location < rhs_location) return true;
    if (lhs_location > rhs_location) return false;

    // Builtin
    if (lhs_member.builtin == null and rhs_member.builtin != null) return true;
    if (lhs_member.builtin != null and rhs_member.builtin == null) return false;

    const lhs_builtin = lhs_member.builtin orelse .vertex_index;
    const rhs_builtin = rhs_member.builtin orelse .vertex_index;

    return @intFromEnum(lhs_builtin) < @intFromEnum(rhs_builtin);
}

fn emitStruct(hlsl: *Hlsl, inst_idx: InstIndex, inst: Inst.Struct, is_fragment_stage: bool) !void {
    try hlsl.writeAll("struct ");
    if (is_fragment_stage) {
        try hlsl.print("FragOut{}", .{@intFromEnum(inst_idx)});
    } else {
        try hlsl.writeName(hlsl.air.getStr(inst.name));
    }
    try hlsl.writeAll(" {\n");

    hlsl.enterScope();
    defer hlsl.exitScope();

    var sorted_members = std.ArrayListUnmanaged(InstIndex){};
    defer sorted_members.deinit(hlsl.allocator);

    const struct_members = hlsl.air.refToList(inst.members);
    for (struct_members) |member_index| {
        try sorted_members.append(hlsl.allocator, member_index);
    }

    std.sort.insertion(InstIndex, sorted_members.items, hlsl, structMemberLessThan);

    for (sorted_members.items) |member_index| {
        const member = hlsl.air.getInst(member_index).struct_member;

        try hlsl.writeIndent();
        try hlsl.emitType(member.type);
        try hlsl.writeAll(" ");
        try hlsl.writeName(hlsl.air.getStr(member.name));
        try hlsl.emitTypeSuffix(member.type);
        if (member.builtin) |builtin| {
            try hlsl.emitBuiltin(builtin);
        } else if (member.location) |location| {
            if (is_fragment_stage) {
                try hlsl.print(" : SV_Target{}", .{location});
            } else {
                try hlsl.print(" : ATTR{}", .{location});
            }
        }
        try hlsl.writeAll(";\n");
    }

    try hlsl.writeAll("};\n");
}

fn emitBufferElemType(hlsl: *Hlsl, inst_idx: InstIndex) !void {
    switch (hlsl.air.getInst(inst_idx)) {
        .@"struct" => |inst| {
            const struct_members = hlsl.air.refToList(inst.members);
            if (struct_members.len > 0) {
                const last_member_idx = struct_members[struct_members.len - 1];
                const last_member = hlsl.air.getInst(last_member_idx).struct_member;
                try hlsl.emitBufferElemType(last_member.type);
            } else {
                std.debug.panic("Array member expected of buffer type expected to be last", .{});
            }
        },
        else => try hlsl.emitType(inst_idx),
    }
}

fn emitBuiltin(hlsl: *Hlsl, builtin: Builtin) !void {
    try hlsl.writeAll(" : ");
    try hlsl.writeAll(switch (builtin) {
        .vertex_index => "SV_VertexID",
        .instance_index => "SV_InstanceID",
        .position => "SV_Position",
        .front_facing => "SV_IsFrontFace",
        .frag_depth => "SV_Depth",
        .local_invocation_id => "SV_GroupThreadID",
        .local_invocation_index => "SV_GroupIndex",
        .global_invocation_id => "SV_DispatchThreadID",
        .workgroup_id => "SV_GroupID",
        .num_workgroups => "TODO", // TODO - is this available?
        .sample_index => "SV_SampleIndex",
        .sample_mask => "SV_Coverage",
    });
}

fn emitWrapperStruct(hlsl: *Hlsl, inst: Inst.Var) !void {
    const type_inst = hlsl.air.getInst(inst.type);
    if (type_inst == .@"struct")
        return;

    try hlsl.print("struct Wrapper{} {{ ", .{@intFromEnum(inst.type)});
    try hlsl.emitType(inst.type);
    try hlsl.writeAll(" data");
    try hlsl.emitTypeSuffix(inst.type);
    try hlsl.writeAll("; };\n");
}

fn emitGlobalVar(hlsl: *Hlsl, inst: Inst.Var) !void {
    const type_inst = hlsl.air.getInst(inst.type);
    const binding = hlsl.air.resolveInt(inst.binding) orelse return error.constExpr;
    var binding_space: []const u8 = undefined;

    if (inst.addr_space == .uniform) {
        try hlsl.emitWrapperStruct(inst);
        try hlsl.writeAll("ConstantBuffer<");
        if (type_inst != .@"struct") {
            try hlsl.print("Wrapper{}", .{@intFromEnum(inst.type)});
        } else {
            try hlsl.emitType(inst.type);
        }
        try hlsl.writeAll(">");
        binding_space = "b";
    } else if (inst.addr_space == .storage) {
        if (inst.access_mode == .write or inst.access_mode == .read_write) {
            try hlsl.writeAll("RWStructuredBuffer<");
            binding_space = "u";
        } else {
            try hlsl.writeAll("StructuredBuffer<");
            binding_space = "t";
        }
        try hlsl.emitBufferElemType(inst.type);
        try hlsl.writeAll(">");
    } else {
        std.debug.panic("TODO: implement workgroup variable\n", .{});
    }

    try hlsl.writeAll(" ");
    try hlsl.writeName(hlsl.air.getStr(inst.name));
    try hlsl.print(" : register({s}{});\n", .{ binding_space, binding });
}

fn emitFragmentReturnStruct(hlsl: *Hlsl, inst_idx: InstIndex) !void {
    switch (hlsl.air.getInst(inst_idx)) {
        .@"struct" => |inst| try hlsl.emitStruct(inst_idx, inst, true),
        else => {},
    }
}

fn emitFragmentReturnType(hlsl: *Hlsl, inst_idx: InstIndex) !void {
    switch (hlsl.air.getInst(inst_idx)) {
        .@"struct" => try hlsl.print("FragOut{}", .{@intFromEnum(inst_idx)}),
        else => try hlsl.emitType(inst_idx),
    }
}

fn emitFn(hlsl: *Hlsl, inst: Inst.Fn) !void {
    if (inst.stage == .fragment)
        try hlsl.emitFragmentReturnStruct(inst.return_type);

    switch (inst.stage) {
        .compute => |workgroup_size| {
            try hlsl.print("[numthreads({}, {}, {})]\n", .{
                hlsl.air.resolveInt(workgroup_size.x) orelse 1,
                hlsl.air.resolveInt(workgroup_size.y) orelse 1,
                hlsl.air.resolveInt(workgroup_size.z) orelse 1,
            });
        },
        else => {},
    }

    if (inst.stage == .fragment) {
        try hlsl.emitFragmentReturnType(inst.return_type);
    } else {
        try hlsl.emitType(inst.return_type);
    }
    try hlsl.writeAll(" ");
    try hlsl.writeName(hlsl.air.getStr(inst.name));
    try hlsl.writeAll("(");

    {
        hlsl.enterScope();
        defer hlsl.exitScope();

        var add_comma = false;

        if (inst.params != .none) {
            for (hlsl.air.refToList(inst.params)) |param_inst_idx| {
                try hlsl.writeAll(if (add_comma) ",\n" else "\n");
                add_comma = true;
                try hlsl.writeIndent();
                try hlsl.emitFnParam(param_inst_idx);
            }
        }
    }

    try hlsl.writeAll(")");
    if (inst.return_attrs.builtin) |builtin| {
        try hlsl.emitBuiltin(builtin);
    } else if (inst.return_attrs.location) |location| {
        try hlsl.print(" : SV_Target{}", .{location});
    }
    try hlsl.writeAll("\n");

    const block = hlsl.air.getInst(inst.block).block;
    try hlsl.writeAll("{\n");
    {
        hlsl.enterScope();
        defer hlsl.exitScope();

        if (inst.has_array_length) {
            try hlsl.writeIndent();
            try hlsl.writeAll("uint _array_length, _array_stride;\n");
        }

        for (hlsl.air.refToList(block)) |statement| {
            try hlsl.emitStatement(statement);
        }
    }
    try hlsl.writeIndent();
    try hlsl.writeAll("}\n");
}

fn emitFnGlobalVar(hlsl: *Hlsl, inst_idx: InstIndex) !void {
    const inst = hlsl.air.getInst(inst_idx).@"var";

    try hlsl.writeAll(if (inst.addr_space == .uniform) "constant" else "device");
    try hlsl.writeAll(" ");
    try hlsl.emitType(inst.type);
    try hlsl.emitTypeAsPointer(inst.type);
    try hlsl.writeAll(" ");
    try hlsl.writeName(hlsl.air.getStr(inst.name));

    // TODO - slot mapping and different object types
    if (hlsl.air.resolveInt(inst.binding)) |binding| {
        try hlsl.print(" [[buffer({})]]", .{binding});
    }
}

fn emitFnParam(hlsl: *Hlsl, inst_idx: InstIndex) !void {
    const inst = hlsl.air.getInst(inst_idx).fn_param;

    try hlsl.emitType(inst.type);
    try hlsl.writeAll(" ");
    try hlsl.writeName(hlsl.air.getStr(inst.name));
    if (inst.builtin) |builtin| {
        try hlsl.emitBuiltin(builtin);
    } else if (inst.location) |location| {
        try hlsl.print(" : ATTR{}", .{location});
    }
}

fn emitStatement(hlsl: *Hlsl, inst_idx: InstIndex) error{OutOfMemory}!void {
    try hlsl.writeIndent();
    switch (hlsl.air.getInst(inst_idx)) {
        .@"var" => |inst| try hlsl.emitFnVar(inst),
        .block => |block| try hlsl.emitBlock(block),
        // .loop => |inst| try hlsl.emitLoop(inst),
        // .continuing
        .@"return" => |return_inst_idx| try hlsl.emitReturn(return_inst_idx),
        // .break_if
        .@"if" => |inst| try hlsl.emitIf(inst),
        // .@"while" => |inst| try hlsl.emitWhile(inst),
        .@"for" => |inst| try hlsl.emitFor(inst),
        // .switch
        .assign => |inst| try hlsl.emitAssignStmt(inst),
        // .increase
        // .decrease
        // .discard
        // .@"break" => try hlsl.emitBreak(),
        .@"continue" => try hlsl.writeAll("continue;\n"),
        // .call => |inst| try hlsl.emitCall(inst),
        //else => |inst| std.debug.panic("TODO: implement Air tag {s}", .{@tagName(inst)}),
        else => |inst| try hlsl.print("Statement: {}\n", .{inst}), // TODO
    }
}

fn emitFnVar(hlsl: *Hlsl, inst: Inst.Var) !void {
    const t = if (inst.type != .none) inst.type else inst.expr;
    try hlsl.emitType(t);
    try hlsl.writeAll(" ");
    try hlsl.writeName(hlsl.air.getStr(inst.name));
    try hlsl.emitTypeSuffix(t);
    if (inst.expr != .none) {
        try hlsl.writeAll(" = ");
        try hlsl.emitExpr(inst.expr);
    }
    try hlsl.writeAll(";\n");
}

fn emitReturn(hlsl: *Hlsl, inst_idx: InstIndex) !void {
    try hlsl.writeAll("return");
    if (inst_idx != .none) {
        try hlsl.writeAll(" ");
        try hlsl.emitExpr(inst_idx);
    }
    try hlsl.writeAll(";\n");
}

fn emitIf(hlsl: *Hlsl, inst: Inst.If) !void {
    try hlsl.writeAll("if (");
    try hlsl.emitExpr(inst.cond);
    try hlsl.writeAll(")\n");
    {
        const body_inst = hlsl.air.getInst(inst.body);
        if (body_inst != .block)
            hlsl.enterScope();
        try hlsl.emitStatement(inst.body);
        if (body_inst != .block)
            hlsl.exitScope();
    }
    if (inst.@"else" != .none) {
        try hlsl.writeAll(" else\n");
        try hlsl.emitStatement(inst.@"else");
    }
    try hlsl.writeAll("\n");
}

fn emitFor(hlsl: *Hlsl, inst: Inst.For) !void {
    try hlsl.writeAll("for (\n");
    {
        hlsl.enterScope();
        defer hlsl.exitScope();

        try hlsl.emitStatement(inst.init);
        try hlsl.writeIndent();
        try hlsl.emitExpr(inst.cond);
        try hlsl.writeAll(";\n");
        try hlsl.writeIndent();
        try hlsl.emitExpr(inst.update);
        try hlsl.writeAll(")\n");
    }
    try hlsl.emitStatement(inst.body);
}

fn emitAssignStmt(hlsl: *Hlsl, inst: Inst.Assign) !void {
    _ = try hlsl.emitAssign(inst);
    try hlsl.writeAll(";\n");
}

fn emitBlock(hlsl: *Hlsl, block: Air.RefIndex) !void {
    try hlsl.writeAll("{\n");
    {
        hlsl.enterScope();
        defer hlsl.exitScope();

        for (hlsl.air.refToList(block)) |statement| {
            try hlsl.emitStatement(statement);
        }
    }
    try hlsl.writeIndent();
    try hlsl.writeAll("}\n");
}

// TODO - move this to Air?
fn exprType(hlsl: *Hlsl, inst_idx: InstIndex) InstIndex {
    return switch (hlsl.air.getInst(inst_idx)) {
        .var_ref => |var_ref_idx| switch (hlsl.air.getInst(var_ref_idx)) {
            .@"var" => |v| v.type,
            .fn_param => |p| p.type,
            else => |x| std.debug.panic("VarRef: {}", .{x}), // TODO
        },
        .bool => inst_idx,
        .int => inst_idx,
        .float => inst_idx,
        .vector => inst_idx,
        //.matrix => inst_idx,
        .array => inst_idx,
        .unary => |inst| inst.result_type,
        .unary_intrinsic => |inst| inst.result_type,
        .binary => |inst| inst.result_type,
        .binary_intrinsic => |inst| inst.result_type,
        .triple_intrinsic => |inst| inst.result_type,
        .assign => |inst| inst.type,
        .field_access => |inst| {
            const name = hlsl.air.getStr(inst.name);
            const base_type = hlsl.exprType(inst.base);
            const base_inst = hlsl.air.getInst(base_type).@"struct";
            const struct_members = hlsl.air.refToList(base_inst.members);
            for (struct_members) |member_index| {
                const member = hlsl.air.getInst(member_index).struct_member;
                const member_name = hlsl.air.getStr(member.name);

                if (std.mem.eql(u8, name, member_name)) {
                    return member.type;
                }
            }

            std.debug.panic("Member {s} not found", .{name});
        },
        .swizzle_access => |inst| inst.type,
        .index_access => |inst| inst.type,
        //.call => |inst| hlsl.emitCall(inst),
        //.struct_construct: StructConstruct,
        //.bitcast: Bitcast,
        //else => |inst| std.debug.panic("TODO: implement Air tag {s}", .{@tagName(inst)}),
        else => |inst| std.debug.panic("Expr: {}", .{inst}), // TODO
    };
}

fn emitExpr(hlsl: *Hlsl, inst_idx: InstIndex) error{OutOfMemory}!void {
    switch (hlsl.air.getInst(inst_idx)) {
        .var_ref => |inst| try hlsl.emitVarRef(inst),
        //.bool => |inst| hlsl.emitBool(inst),
        .int => |inst| try hlsl.emitInt(inst),
        .float => |inst| try hlsl.emitFloat(inst),
        .vector => |inst| try hlsl.emitVector(inst),
        //.matrix => |inst| hlsl.emitMatrix(inst),
        .array => |inst| try hlsl.emitArray(inst),
        .unary => |inst| try hlsl.emitUnary(inst),
        .unary_intrinsic => |inst| try hlsl.emitUnaryIntrinsic(inst),
        .binary => |inst| try hlsl.emitBinary(inst),
        .binary_intrinsic => |inst| try hlsl.emitBinaryIntrinsic(inst),
        .triple_intrinsic => |inst| try hlsl.emitTripleIntrinsic(inst),
        .assign => |inst| try hlsl.emitAssign(inst),
        .field_access => |inst| try hlsl.emitFieldAccess(inst),
        .swizzle_access => |inst| try hlsl.emitSwizzleAccess(inst),
        .index_access => |inst| try hlsl.emitIndexAccess(inst),
        //.call => |inst| hlsl.emitCall(inst),
        //.struct_construct: StructConstruct,
        //.bitcast: Bitcast,
        //else => |inst| std.debug.panic("TODO: implement Air tag {s}", .{@tagName(inst)}),
        else => |inst| std.debug.panic("Expr: {}", .{inst}), // TODO
    }
}

fn emitVarRef(hlsl: *Hlsl, inst_idx: InstIndex) !void {
    switch (hlsl.air.getInst(inst_idx)) {
        .@"var" => |v| {
            try hlsl.writeName(hlsl.air.getStr(v.name));
            const v_type_inst = hlsl.air.getInst(v.type);
            if (v.addr_space == .uniform and v_type_inst != .@"struct")
                try hlsl.writeAll(".data");
        },
        .fn_param => |p| {
            try hlsl.writeName(hlsl.air.getStr(p.name));
        },
        else => |x| std.debug.panic("VarRef: {}", .{x}), // TODO
    }
}

fn emitInt(hlsl: *Hlsl, inst: Inst.Int) !void {
    switch (hlsl.air.getValue(Inst.Int.Value, inst.value.?)) {
        .literal => |lit| try hlsl.print("{}", .{lit}),
        .cast => |cast| try hlsl.emitIntCast(inst, cast),
    }
}

fn emitIntCast(hlsl: *Hlsl, dest_type: Inst.Int, cast: Inst.Cast) !void {
    try hlsl.emitIntType(dest_type);
    try hlsl.writeAll("(");
    try hlsl.emitExpr(cast.value);
    try hlsl.writeAll(")");
}

fn emitFloat(hlsl: *Hlsl, inst: Inst.Float) !void {
    switch (hlsl.air.getValue(Inst.Float.Value, inst.value.?)) {
        .literal => |lit| try hlsl.print("{}", .{lit}),
        .cast => |cast| try hlsl.emitFloatCast(inst, cast),
    }
}

fn emitFloatCast(hlsl: *Hlsl, dest_type: Inst.Float, cast: Inst.Cast) !void {
    try hlsl.emitFloatType(dest_type);
    try hlsl.writeAll("(");
    try hlsl.emitExpr(cast.value);
    try hlsl.writeAll(")");
}

fn emitVector(hlsl: *Hlsl, inst: Inst.Vector) !void {
    try hlsl.emitType(inst.elem_type);
    switch (inst.size) {
        .two => try hlsl.writeAll("2"),
        .three => try hlsl.writeAll("3"),
        .four => try hlsl.writeAll("4"),
    }

    try hlsl.writeAll("(");

    const value = hlsl.air.getValue(Inst.Vector.Value, inst.value.?);
    for (value[0..@intFromEnum(inst.size)], 0..) |elem_inst, i| {
        try hlsl.writeAll(if (i == 0) "" else ", ");
        try hlsl.emitExpr(elem_inst);
    }

    try hlsl.writeAll(")");
}

fn emitArray(hlsl: *Hlsl, inst: Inst.Array) !void {
    try hlsl.writeAll("{");
    {
        hlsl.enterScope();
        defer hlsl.exitScope();

        const value = hlsl.air.refToList(inst.value.?);
        for (value, 0..) |elem_inst, i| {
            try hlsl.writeAll(if (i == 0) "\n" else ",\n");
            try hlsl.writeIndent();
            try hlsl.emitExpr(elem_inst);
        }
    }
    try hlsl.writeAll("}");
}

fn emitUnary(hlsl: *Hlsl, inst: Inst.Unary) !void {
    try hlsl.writeAll(switch (inst.op) {
        .not => "!",
        .negate => "-",
        .deref => "*",
        .addr_of => "&",
    });
    try hlsl.emitExpr(inst.expr);
}

fn emitUnaryIntrinsic(hlsl: *Hlsl, inst: Inst.UnaryIntrinsic) !void {
    switch (inst.op) {
        .array_length => try hlsl.emitArrayLength(inst),
        else => {
            try hlsl.writeAll(switch (inst.op) {
                .all => "all",
                .any => "any",
                .abs => "abs",
                .acos => "acos",
                //.acosh => "acosh",
                .asin => "asin",
                //.asinh => "asinh",
                .atan => "atan",
                //.atanh => "atanh",
                .ceil => "ceil",
                .cos => "cos",
                .cosh => "cosh",
                //.count_leading_zeros => "count_leading_zeros",
                .count_one_bits => "countbits",
                //.count_trailing_zeros => "count_trailing_zeros",
                .degrees => "degrees",
                .exp => "exp",
                .exp2 => "exp2",
                //.first_leading_bit => "first_leading_bit",
                //.first_trailing_bit => "first_trailing_bit",
                .floor => "floor",
                .fract => "frac",
                .inverse_sqrt => "rsqrt",
                .length => "length",
                .log => "log",
                .log2 => "log2",
                //.quantize_to_F16 => "quantize_to_F16",
                .radians => "radians",
                .reverseBits => "reversebits",
                .round => "rint",
                .saturate => "saturate",
                .sign => "sign",
                .sin => "sin",
                .sinh => "sinh",
                .sqrt => "sqrt",
                .tan => "tan",
                .tanh => "tanh",
                .trunc => "trunc",
                .dpdx => "ddx",
                .dpdx_coarse => "ddx_coarse",
                .dpdx_fine => "ddx_fine",
                .dpdy => "ddy",
                .dpdy_coarse => "ddy_coarse",
                .dpdy_fine => "ddy_fine",
                .fwidth => "fwidth",
                .fwidth_coarse => "fwidth",
                .fwidth_fine => "fwidth",
                .normalize => "normalize",
                else => std.debug.panic("TODO: implement Air tag {s}", .{@tagName(inst.op)}),
            });
            try hlsl.writeAll("(");
            try hlsl.emitExpr(inst.expr);
            try hlsl.writeAll(")");
        },
    }
}

fn emitArrayLength(hlsl: *Hlsl, inst: Inst.UnaryIntrinsic) !void {
    switch (hlsl.air.getInst(inst.expr)) {
        .unary => |un| switch (un.op) {
            .addr_of => try hlsl.emitArrayLengthTarget(un.expr, 0),
            else => try hlsl.print("ArrayLength (unary_op): {}", .{un.op}),
        },
        else => |array_length_expr| try hlsl.print("ArrayLength (array_length_expr): {}", .{array_length_expr}),
    }
}

fn emitArrayLengthTarget(hlsl: *Hlsl, inst_idx: InstIndex, offset: usize) error{OutOfMemory}!void {
    switch (hlsl.air.getInst(inst_idx)) {
        .var_ref => |var_ref_inst_idx| try hlsl.emitArrayLengthVarRef(var_ref_inst_idx, offset),
        .field_access => |inst| try hlsl.emitArrayLengthFieldAccess(inst, offset),
        else => |inst| try hlsl.print("ArrayLengthTarget: {}", .{inst}),
    }
}

fn emitArrayLengthVarRef(hlsl: *Hlsl, inst_idx: InstIndex, offset: usize) !void {
    switch (hlsl.air.getInst(inst_idx)) {
        .@"var" => |var_inst| {
            try hlsl.writeAll("(");
            try hlsl.writeName(hlsl.air.getStr(var_inst.name));
            try hlsl.print(
                ".GetDimensions(_array_length, _array_stride), _array_length - {})",
                .{offset},
            );
        },
        else => |var_ref_expr| try hlsl.print("arrayLength (var_ref_expr): {}", .{var_ref_expr}),
    }
}

fn emitArrayLengthFieldAccess(hlsl: *Hlsl, inst: Inst.FieldAccess, base_offset: usize) !void {
    const member_offset = 0; // TODO
    try hlsl.emitArrayLengthTarget(inst.base, base_offset + member_offset);
}

fn emitBinary(hlsl: *Hlsl, inst: Inst.Binary) !void {
    switch (inst.op) {
        .mul => {
            const lhs_type_idx = hlsl.exprType(inst.lhs);
            const rhs_type_idx = hlsl.exprType(inst.rhs);
            const lhs_type = hlsl.air.getInst(lhs_type_idx);
            const rhs_type = hlsl.air.getInst(rhs_type_idx);

            if ((lhs_type == .vector and rhs_type == .matrix) or (lhs_type == .matrix and rhs_type == .vector)) {
                try hlsl.writeAll("mul");
                try hlsl.writeAll("(");
                try hlsl.emitExpr(inst.lhs);
                try hlsl.writeAll(", ");
                try hlsl.emitExpr(inst.rhs);
                try hlsl.writeAll(")");
            } else {
                try hlsl.emitBinaryOp(inst);
            }
        },
        else => try hlsl.emitBinaryOp(inst),
    }
}

fn emitBinaryOp(hlsl: *Hlsl, inst: Inst.Binary) !void {
    try hlsl.writeAll("(");
    try hlsl.emitExpr(inst.lhs);
    try hlsl.print(" {s} ", .{switch (inst.op) {
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
    try hlsl.emitExpr(inst.rhs);
    try hlsl.writeAll(")");
}

fn emitBinaryIntrinsic(hlsl: *Hlsl, inst: Inst.BinaryIntrinsic) !void {
    const result_type = hlsl.air.getInst(inst.result_type);
    try hlsl.writeAll(switch (inst.op) {
        .min => if (result_type == .float) "fmin" else "min",
        .max => if (result_type == .float) "fmax" else "max",
        .atan2 => "atan2",
        .distance => "distance",
        .dot => "dot",
        .pow => "pow",
        .step => "step",
    });
    try hlsl.writeAll("(");
    try hlsl.emitExpr(inst.lhs);
    try hlsl.writeAll(", ");
    try hlsl.emitExpr(inst.rhs);
    try hlsl.writeAll(")");
}

fn emitTripleIntrinsic(hlsl: *Hlsl, inst: Inst.TripleIntrinsic) !void {
    try hlsl.writeAll(switch (inst.op) {
        .clamp => "clamp",
        else => std.debug.panic("TODO: implement Air tag {s}", .{@tagName(inst.op)}),
    });
    try hlsl.writeAll("(");
    try hlsl.emitExpr(inst.a1);
    try hlsl.writeAll(", ");
    try hlsl.emitExpr(inst.a2);
    try hlsl.writeAll(", ");
    try hlsl.emitExpr(inst.a3);
    try hlsl.writeAll(")");
}

fn emitAssign(hlsl: *Hlsl, inst: Inst.Assign) !void {
    try hlsl.emitExpr(inst.lhs);
    try hlsl.print(" {s}= ", .{switch (inst.mod) {
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
    try hlsl.emitExpr(inst.rhs);
}

fn emitFieldAccess(hlsl: *Hlsl, inst: Inst.FieldAccess) !void {
    const base_inst = hlsl.air.getInst(inst.base);
    switch (base_inst) {
        .var_ref => |var_ref_inst_idx| {
            switch (hlsl.air.getInst(var_ref_inst_idx)) {
                .@"var" => |v| {
                    const v_type_inst = hlsl.air.getInst(v.type);
                    if (v.addr_space == .storage and v_type_inst == .@"struct") {
                        // assume 1 field that is an array
                        try hlsl.emitExpr(inst.base);
                    } else {
                        try hlsl.emitFieldAccessRegular(inst);
                    }
                },
                else => try hlsl.emitFieldAccessRegular(inst),
            }
        },
        else => try hlsl.emitFieldAccessRegular(inst),
    }
}

fn emitFieldAccessRegular(hlsl: *Hlsl, inst: Inst.FieldAccess) !void {
    try hlsl.emitExpr(inst.base);
    try hlsl.writeAll(".");
    try hlsl.writeName(hlsl.air.getStr(inst.name));
}

fn emitSwizzleAccess(hlsl: *Hlsl, inst: Inst.SwizzleAccess) !void {
    try hlsl.emitExpr(inst.base);
    try hlsl.writeAll(".");
    for (0..@intFromEnum(inst.size)) |i| {
        switch (inst.pattern[i]) {
            .x => try hlsl.writeAll("x"),
            .y => try hlsl.writeAll("y"),
            .z => try hlsl.writeAll("z"),
            .w => try hlsl.writeAll("w"),
        }
    }
}

fn emitIndexAccess(hlsl: *Hlsl, inst: Inst.IndexAccess) !void {
    try hlsl.emitExpr(inst.base);
    try hlsl.writeAll("[");
    try hlsl.emitExpr(inst.index);
    try hlsl.writeAll("]");
}

fn enterScope(hlsl: *Hlsl) void {
    hlsl.indent += 4;
}

fn exitScope(hlsl: *Hlsl) void {
    hlsl.indent -= 4;
}

fn writeIndent(hlsl: *Hlsl) !void {
    try hlsl.writer.writeByteNTimes(' ', hlsl.indent);
}

fn writeName(hlsl: *Hlsl, name: []const u8) !void {
    try hlsl.writeAll(
        if (std.mem.eql(u8, name, "in")) "in_" else if (std.mem.eql(u8, name, "out")) "out_" else name,
    );
}

fn writeAll(hlsl: *Hlsl, bytes: []const u8) !void {
    try hlsl.writer.writeAll(bytes);
}

fn print(hlsl: *Hlsl, comptime format: []const u8, args: anytype) !void {
    return std.fmt.format(hlsl.writer, format, args);
}
