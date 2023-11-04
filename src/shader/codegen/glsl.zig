const std = @import("std");
const Air = @import("../Air.zig");
const DebugInfo = @import("../CodeGen.zig").DebugInfo;
const Inst = Air.Inst;
const InstIndex = Air.InstIndex;
const Builtin = Air.Inst.Builtin;

const Glsl = @This();

air: *const Air,
allocator: std.mem.Allocator,
storage: std.ArrayListUnmanaged(u8),
writer: std.ArrayListUnmanaged(u8).Writer,
entrypoint_inst: ?Inst.Fn = null,
indent: u32 = 0,

pub fn gen(allocator: std.mem.Allocator, air: *const Air, debug_info: DebugInfo, entrypoint: [*:0]const u8) ![]const u8 {
    _ = debug_info;

    var storage = std.ArrayListUnmanaged(u8){};
    var glsl = Glsl{
        .air = air,
        .allocator = allocator,
        .storage = storage,
        .writer = storage.writer(allocator),
    };
    defer {
        glsl.storage.deinit(allocator);
    }

    try glsl.writeAll("#version 450\n\n");

    for (air.refToList(air.globals_index)) |inst_idx| {
        switch (air.getInst(inst_idx)) {
            .@"fn" => |inst| try glsl.emitFn(inst, entrypoint),
            else => |inst| try glsl.print("TopLevel: {}\n", .{inst}), // TODO
        }
    }

    return storage.toOwnedSlice(allocator);
}

fn emitElemType(glsl: *Glsl, inst_idx: InstIndex) !void {
    switch (glsl.air.getInst(inst_idx)) {
        .bool => |inst| try glsl.emitBoolElemType(inst),
        .int => |inst| try glsl.emitIntElemType(inst),
        .float => |inst| try glsl.emitFloatElemType(inst),
        else => unreachable,
    }
}

fn emitBoolElemType(glsl: *Glsl, inst: Inst.Bool) !void {
    _ = inst;
    try glsl.writeAll("b");
}

fn emitIntElemType(glsl: *Glsl, inst: Inst.Int) !void {
    try glsl.writeAll(switch (inst.type) {
        .u32 => "u",
        .i32 => "i",
    });
}

fn emitFloatElemType(glsl: *Glsl, inst: Inst.Float) !void {
    try glsl.writeAll(switch (inst.type) {
        .f32 => "",
        .f16 => "", // TODO - extension for half support?
    });
}

fn emitType(glsl: *Glsl, inst_idx: InstIndex) error{OutOfMemory}!void {
    if (inst_idx == .none) {
        try glsl.writeAll("void");
    } else {
        switch (glsl.air.getInst(inst_idx)) {
            .bool => |inst| try glsl.emitBoolType(inst),
            .int => |inst| try glsl.emitIntType(inst),
            .float => |inst| try glsl.emitFloatType(inst),
            .vector => |inst| try glsl.emitVectorType(inst),
            .matrix => |inst| try glsl.emitMatrixType(inst),
            .array => |inst| try glsl.emitType(inst.elem_type),
            else => |inst| try glsl.print("Type: {}", .{inst}), // TODO
        }
    }
}

fn emitTypeSuffix(glsl: *Glsl, inst_idx: InstIndex) error{OutOfMemory}!void {
    if (inst_idx != .none) {
        switch (glsl.air.getInst(inst_idx)) {
            .array => |inst| try glsl.emitArrayTypeSuffix(inst),
            else => {},
        }
    }
}

fn emitArrayTypeSuffix(glsl: *Glsl, inst: Inst.Array) !void {
    if (inst.len != .none) {
        if (glsl.air.resolveInt(inst.len)) |len| {
            try glsl.print("[{}]", .{len});
        }
    } else {
        try glsl.writeAll("[1]");
    }
    try glsl.emitTypeSuffix(inst.elem_type);
}

fn emitBoolType(glsl: *Glsl, inst: Inst.Bool) !void {
    _ = inst;
    try glsl.writeAll("bool");
}

fn emitIntType(glsl: *Glsl, inst: Inst.Int) !void {
    try glsl.writeAll(switch (inst.type) {
        .u32 => "uint",
        .i32 => "int",
    });
}

fn emitFloatType(glsl: *Glsl, inst: Inst.Float) !void {
    try glsl.writeAll(switch (inst.type) {
        .f32 => "float",
        .f16 => "half",
    });
}

fn emitVectorSize(glsl: *Glsl, size: Inst.Vector.Size) !void {
    try glsl.writeAll(switch (size) {
        .two => "2",
        .three => "3",
        .four => "4",
    });
}

fn emitVectorType(glsl: *Glsl, inst: Inst.Vector) !void {
    try glsl.emitElemType(inst.elem_type);
    try glsl.writeAll("vec");
    try glsl.emitVectorSize(inst.size);
}

fn emitMatrixType(glsl: *Glsl, inst: Inst.Matrix) !void {
    // TODO - verify dimension order
    try glsl.emitElemType(inst.elem_type);
    try glsl.writeAll("mat");
    try glsl.emitVectorSize(inst.cols);
    try glsl.writeAll("x");
    try glsl.emitVectorSize(inst.rows);
}

fn emitBuiltin(glsl: *Glsl, builtin: Builtin) !void {
    try glsl.writeAll(switch (builtin) {
        .vertex_index => "gl_VertexID",
        .position => "gl_Position",
        else => @panic("TODO - emitBuiltin"),
    });
}

fn emitFn(glsl: *Glsl, inst: Inst.Fn, entrypoint_ptr: [*:0]const u8) !void {
    if (inst.stage != .none) {
        const entrypoint = std.mem.span(entrypoint_ptr);
        const name = glsl.air.getStr(inst.name);
        if (!std.mem.eql(u8, entrypoint, name))
            return;

        switch (glsl.air.getInst(inst.return_type)) {
            .@"struct" => @panic("TODO struct return"),
            else => {
                if (inst.return_attrs.builtin == null) {
                    try glsl.writeAll("layout(location = 0) out ");
                    try glsl.emitType(inst.return_type);
                    try glsl.writeAll(" main_output;\n");
                }
            },
        }

        glsl.entrypoint_inst = inst;
        try glsl.emitType(.none);
    } else {
        try glsl.emitType(inst.return_type);
    }

    try glsl.writeAll(" ");
    if (inst.stage != .none) {
        try glsl.writeEntrypoint();
    } else {
        try glsl.writeName(inst.name);
    }
    try glsl.writeAll("(");

    if (inst.stage == .none) {
        glsl.enterScope();
        defer glsl.exitScope();

        var add_comma = false;

        if (inst.params != .none) {
            for (glsl.air.refToList(inst.params)) |param_inst_idx| {
                try glsl.writeAll(if (add_comma) ",\n" else "\n");
                add_comma = true;
                try glsl.writeIndent();
                try glsl.emitFnParam(param_inst_idx);
            }
        }
    }

    try glsl.writeAll(")\n");

    const block = glsl.air.getInst(inst.block).block;
    try glsl.writeAll("{\n");
    {
        glsl.enterScope();
        defer glsl.exitScope();

        for (glsl.air.refToList(block)) |statement| {
            try glsl.emitStatement(statement);
        }
    }
    try glsl.writeAll("}\n");

    glsl.entrypoint_inst = null;
}

fn emitFnParam(glsl: *Glsl, inst_idx: InstIndex) !void {
    const inst = glsl.air.getInst(inst_idx).fn_param;

    try glsl.emitType(inst.type);
    try glsl.writeAll(" ");
    try glsl.writeName(inst.name);
}

fn emitStatement(glsl: *Glsl, inst_idx: InstIndex) error{OutOfMemory}!void {
    try glsl.writeIndent();
    switch (glsl.air.getInst(inst_idx)) {
        .@"var" => |inst| try glsl.emitVar(inst),
        //.@"const" => |inst| try glsl.emitConst(inst),
        //.block => |block| try glsl.emitBlock(block),
        // .loop => |inst| try glsl.emitLoop(inst),
        // .continuing
        .@"return" => |return_inst_idx| try glsl.emitReturn(return_inst_idx),
        // .break_if
        //.@"if" => |inst| try glsl.emitIf(inst),
        // .@"while" => |inst| try glsl.emitWhile(inst),
        //.@"for" => |inst| try glsl.emitFor(inst),
        // .switch
        //.discard => try glsl.emitDiscard(),
        // .@"break" => try glsl.emitBreak(),
        //.@"continue" => try glsl.writeAll("continue;\n"),
        // .call => |inst| try glsl.emitCall(inst),
        .assign,
        .nil_intrinsic,
        .texture_store,
        => {
            try glsl.emitExpr(inst_idx);
            try glsl.writeAll(";\n");
        },
        //else => |inst| std.debug.panic("TODO: implement Air tag {s}", .{@tagName(inst)}),
        else => |inst| try glsl.print("Statement: {}\n", .{inst}), // TODO
    }
}

fn emitVar(glsl: *Glsl, inst: Inst.Var) !void {
    const t = if (inst.type != .none) inst.type else inst.expr;
    try glsl.emitType(t);
    try glsl.writeAll(" ");
    try glsl.writeName(inst.name);
    try glsl.emitTypeSuffix(t);
    if (inst.expr != .none) {
        try glsl.writeAll(" = ");
        try glsl.emitExpr(inst.expr);
    }
    try glsl.writeAll(";\n");
}

fn emitReturn(glsl: *Glsl, inst_idx: InstIndex) !void {
    if (glsl.entrypoint_inst) |fn_inst| {
        switch (glsl.air.getInst(fn_inst.return_type)) {
            .@"struct" => @panic("TODO struct return"),
            else => {
                if (fn_inst.return_attrs.builtin) |builtin| {
                    try glsl.emitBuiltin(builtin);
                } else {
                    try glsl.writeAll("main_output");
                }
                if (inst_idx != .none) {
                    try glsl.writeAll(" = ");
                    try glsl.emitExpr(inst_idx);
                }
                try glsl.writeAll(";\n");
            },
        }
    } else {
        try glsl.writeAll("return");
        if (inst_idx != .none) {
            try glsl.writeAll(" ");
            try glsl.emitExpr(inst_idx);
        }
        try glsl.writeAll(";\n");
    }
}

fn emitExpr(glsl: *Glsl, inst_idx: InstIndex) error{OutOfMemory}!void {
    switch (glsl.air.getInst(inst_idx)) {
        .var_ref => |inst| try glsl.emitVarRef(inst),
        //.bool => |inst| glsl.emitBool(inst),
        //.int => |inst| try glsl.emitInt(inst),
        .float => |inst| try glsl.emitFloat(inst),
        .vector => |inst| try glsl.emitVector(inst),
        //.matrix => |inst| try glsl.emitMatrix(inst),
        .array => |inst| try glsl.emitArray(inst),
        //.nil_intrinsic => |inst| try glsl.emitNilIntrinsic(inst),
        //.unary => |inst| try glsl.emitUnary(inst),
        //.unary_intrinsic => |inst| try glsl.emitUnaryIntrinsic(inst),
        //.binary => |inst| try glsl.emitBinary(inst),
        //.binary_intrinsic => |inst| try glsl.emitBinaryIntrinsic(inst),
        //.triple_intrinsic => |inst| try glsl.emitTripleIntrinsic(inst),
        //.assign => |inst| try glsl.emitAssign(inst),
        //.field_access => |inst| try glsl.emitFieldAccess(inst),
        .swizzle_access => |inst| try glsl.emitSwizzleAccess(inst),
        .index_access => |inst| try glsl.emitIndexAccess(inst),
        //.call => |inst| try glsl.emitCall(inst),
        //.call => |inst| glsl.emitCall(inst),
        //.struct_construct: StructConstruct,
        //.bitcast: Bitcast,
        //.texture_sample => |inst| try glsl.emitTextureSample(inst),
        //.texture_dimension => |inst| try glsl.emitTextureDimension(inst),
        //.texture_load => |inst| try glsl.emitTextureLoad(inst),
        //.texture_store => |inst| try glsl.emitTextureStore(inst),
        //else => |inst| std.debug.panic("TODO: implement Air tag {s}", .{@tagName(inst)}),
        else => |inst| std.debug.panic("Expr: {}", .{inst}), // TODO
    }
}

fn emitVarRef(glsl: *Glsl, inst_idx: InstIndex) !void {
    switch (glsl.air.getInst(inst_idx)) {
        .@"var" => |v| try glsl.writeName(v.name),
        .@"const" => |c| try glsl.writeName(c.name),
        .fn_param => |p| {
            if (p.builtin) |builtin| {
                try glsl.emitBuiltin(builtin);
            } else {
                try glsl.writeName(p.name);
            }
        },
        else => |x| std.debug.panic("VarRef: {}", .{x}), // TODO
    }
}

fn emitFloat(glsl: *Glsl, inst: Inst.Float) !void {
    switch (glsl.air.getValue(Inst.Float.Value, inst.value.?)) {
        .literal => |lit| try glsl.print("{}", .{lit}),
        .cast => |cast| try glsl.emitFloatCast(inst, cast),
    }
}

fn emitFloatCast(glsl: *Glsl, dest_type: Inst.Float, cast: Inst.ScalarCast) !void {
    try glsl.emitFloatType(dest_type);
    try glsl.writeAll("(");
    try glsl.emitExpr(cast.value);
    try glsl.writeAll(")");
}

fn emitVector(glsl: *Glsl, inst: Inst.Vector) !void {
    try glsl.emitVectorType(inst);
    try glsl.writeAll("(");

    const value = glsl.air.getValue(Inst.Vector.Value, inst.value.?);
    switch (value) {
        .literal => |literal| try glsl.emitVectorElems(inst.size, literal),
        .cast => |cast| try glsl.emitVectorElems(inst.size, cast.value),
    }

    try glsl.writeAll(")");
}

fn emitVectorElems(glsl: *Glsl, size: Inst.Vector.Size, value: [4]InstIndex) !void {
    for (value[0..@intFromEnum(size)], 0..) |elem_inst, i| {
        try glsl.writeAll(if (i == 0) "" else ", ");
        try glsl.emitExpr(elem_inst);
    }
}

fn emitArray(glsl: *Glsl, inst: Inst.Array) !void {
    try glsl.emitType(inst.elem_type);
    try glsl.writeAll("[](");
    {
        glsl.enterScope();
        defer glsl.exitScope();

        const value = glsl.air.refToList(inst.value.?);
        for (value, 0..) |elem_inst, i| {
            try glsl.writeAll(if (i == 0) "\n" else ",\n");
            try glsl.writeIndent();
            try glsl.emitExpr(elem_inst);
        }
    }
    try glsl.writeAll(")");
}

fn emitSwizzleAccess(glsl: *Glsl, inst: Inst.SwizzleAccess) !void {
    try glsl.emitExpr(inst.base);
    try glsl.writeAll(".");
    for (0..@intFromEnum(inst.size)) |i| {
        switch (inst.pattern[i]) {
            .x => try glsl.writeAll("x"),
            .y => try glsl.writeAll("y"),
            .z => try glsl.writeAll("z"),
            .w => try glsl.writeAll("w"),
        }
    }
}

fn emitIndexAccess(glsl: *Glsl, inst: Inst.IndexAccess) !void {
    try glsl.emitExpr(inst.base);
    try glsl.writeAll("[");
    try glsl.emitExpr(inst.index);
    try glsl.writeAll("]");
}

fn enterScope(glsl: *Glsl) void {
    glsl.indent += 4;
}

fn exitScope(glsl: *Glsl) void {
    glsl.indent -= 4;
}

fn writeIndent(glsl: *Glsl) !void {
    try glsl.writer.writeByteNTimes(' ', glsl.indent);
}

fn writeEntrypoint(glsl: *Glsl) !void {
    try glsl.writeAll("main");
}

fn writeName(glsl: *Glsl, name: Air.StringIndex) !void {
    // Suffix with index as WGSL has different scoping rules and to avoid conflicts with keywords
    const str = glsl.air.getStr(name);
    try glsl.print("{s}_{}", .{ str, @intFromEnum(name) });
}

fn writeAll(glsl: *Glsl, bytes: []const u8) !void {
    try glsl.writer.writeAll(bytes);
}

fn print(glsl: *Glsl, comptime format: []const u8, args: anytype) !void {
    return std.fmt.format(glsl.writer, format, args);
}
