const std = @import("std");
const Air = @import("../Air.zig");
const DebugInfo = @import("../CodeGen.zig").DebugInfo;
const Inst = Air.Inst;
const InstIndex = Air.InstIndex;
const Builtin = Air.Inst.Builtin;

pub fn gen(allocator: std.mem.Allocator, air: *const Air, debug_info: DebugInfo) ![]const u8 {
    _ = debug_info;

    var arr = std.ArrayList(u8).init(allocator);
    defer arr.deinit();

    const writer = arr.writer();

    for (air.refToList(air.globals_index)) |inst_idx| {
        switch (air.getInst(inst_idx)) {
            .@"fn" => _ = try emitFn(writer, air, inst_idx),
            //.@"const" => _ = try emitConst(writer, air, inst_idx),    // TODO
            //.@"var" => _ = try emitVarProto(writer, air, inst_idx),   // TODO
            else => {},
        }
    }

    return arr.toOwnedSlice();
}

fn emitType(writer: std.ArrayList(u8).Writer, air: *const Air, inst_idx: InstIndex) !void {
    if (inst_idx == .none) {
        try writer.writeAll("void");
    } else {
        switch (air.getInst(inst_idx)) {
            .int => |i| switch (i.type) {
                .u32 => try writer.writeAll("uint"),
                .i32 => try writer.writeAll("int"),
            },
            .float => try writer.writeAll("float"),
            .vector => |v| {
                try emitType(writer, air, v.elem_type);
                switch (v.size) {
                    .two => try writer.writeAll("2"),
                    .three => try writer.writeAll("3"),
                    .four => try writer.writeAll("4"),
                }
            },
            .array => |array| try emitType(writer, air, array.elem_type),
            else => |inst| try writer.print("{}", .{inst}), // TODO
        }
    }
}

fn emitTypeSuffix(writer: std.ArrayList(u8).Writer, air: *const Air, inst_idx: InstIndex) !void {
    if (inst_idx != .none) {
        switch (air.getInst(inst_idx)) {
            .array => try writer.writeAll("[]"),
            else => {},
        }
    }
}

fn emitBuiltin(writer: std.ArrayList(u8).Writer, air: *const Air, builtin: ?Builtin) !void {
    _ = air;
    if (builtin) |b| {
        try writer.writeAll(" : ");
        try writer.writeAll(switch (b) {
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
}

fn emitFn(writer: std.ArrayList(u8).Writer, air: *const Air, inst_idx: InstIndex) !void {
    const inst = air.getInst(inst_idx).@"fn";

    try emitType(writer, air, inst.return_type);
    try writer.print(" {s}(", .{air.getStr(inst.name)});

    if (inst.params != .none) {
        const param_list = air.refToList(inst.params);

        for (param_list, 0..) |param_inst_idx, i| {
            try writer.writeAll(if (i == 0) "\n" else ",\n");
            const param_inst = air.getInst(param_inst_idx).fn_param;
            try emitType(writer, air, param_inst.type);
            try writer.print(" {s}", .{air.getStr(param_inst.name)});
            try emitBuiltin(writer, air, param_inst.builtin);
        }
    }

    try writer.print(")", .{});
    try emitBuiltin(writer, air, inst.return_attrs.builtin);
    if (inst.stage == .fragment)
        try writer.writeAll(" : SV_Target");
    try writer.print("\n{{\n", .{});

    const body = air.getInst(inst.block).block;
    for (air.refToList(body)) |statement| {
        try emitStatement(writer, air, statement);
    }

    try writer.print("}}\n", .{});
}

fn emitStatement(writer: std.ArrayList(u8).Writer, air: *const Air, inst_idx: InstIndex) !void {
    switch (air.getInst(inst_idx)) {
        .@"var" => |v| {
            const t = if (v.type != .none) v.type else v.expr;
            try emitType(writer, air, t);
            try writer.print(" {s}", .{air.getStr(v.name)});
            try emitTypeSuffix(writer, air, t);
            try writer.writeAll(" = ");
            try emitExpr(writer, air, v.expr);
            try writer.writeAll(";\n");
        },
        .@"return" => |return_inst_idx| {
            try writer.writeAll("return ");
            try emitExpr(writer, air, return_inst_idx);
            try writer.writeAll(";\n");
        },
        else => |inst| try writer.print("{}", .{inst}), // TODO
    }
}
fn emitExpr(writer: std.ArrayList(u8).Writer, air: *const Air, inst_idx: InstIndex) error{OutOfMemory}!void {
    switch (air.getInst(inst_idx)) {
        .float => |float| try emitFloat(writer, air, float),
        .vector => |vector| try emitVector(writer, air, vector),
        .array => |array| try emitArray(writer, air, array),
        .var_ref => |var_ref| try emitVarRef(writer, air, var_ref),
        .swizzle_access => |swizzle_access| try emitSwizzleAccess(writer, air, swizzle_access),
        .index_access => |index_access| try emitIndexAccess(writer, air, index_access),
        else => |inst| try writer.print("{}", .{inst}), // TODO
    }
}

fn emitFloat(writer: std.ArrayList(u8).Writer, air: *const Air, float: Inst.Float) !void {
    return switch (air.getValue(Inst.Float.Value, float.value.?)) {
        .literal => |lit| try writer.print("{}", .{lit}),
        //.cast => |cast| spv.emitFloatCast(section, float.type, cast), // TODO
        else => |x| try writer.print("{}", .{x}),
    };
}

fn emitVector(writer: std.ArrayList(u8).Writer, air: *const Air, inst: Inst.Vector) !void {
    try emitType(writer, air, inst.elem_type);
    switch (inst.size) {
        .two => try writer.writeAll("2"),
        .three => try writer.writeAll("3"),
        .four => try writer.writeAll("4"),
    }

    try writer.writeAll("(");

    const value = air.getValue(Inst.Vector.Value, inst.value.?);
    for (value[0..@intFromEnum(inst.size)], 0..) |elem_inst, i| {
        try writer.writeAll(if (i == 0) "\n" else ",\n");
        try emitExpr(writer, air, elem_inst);
    }

    try writer.writeAll(")");
}

fn emitArray(writer: std.ArrayList(u8).Writer, air: *const Air, inst: Inst.Array) !void {
    try writer.writeAll("{");
    const value = air.refToList(inst.value.?);
    for (value, 0..) |elem_inst, i| {
        try writer.writeAll(if (i == 0) "\n" else ",\n");
        try emitExpr(writer, air, elem_inst);
    }
    try writer.writeAll("}");
}

fn emitVarRef(writer: std.ArrayList(u8).Writer, air: *const Air, inst_idx: InstIndex) !void {
    switch (air.getInst(inst_idx)) {
        .@"var" => |v| try writer.writeAll(air.getStr(v.name)),
        .fn_param => |p| try writer.writeAll(air.getStr(p.name)),
        else => |x| try writer.print("{}", .{x}), // TODO
    }
}

fn emitSwizzleAccess(writer: std.ArrayList(u8).Writer, air: *const Air, inst: Inst.SwizzleAccess) !void {
    if (inst.size == .one) {
        try emitExpr(writer, air, inst.base);
        switch (inst.pattern[0]) {
            .x => try writer.writeAll(".x"),
            .y => try writer.writeAll(".y"),
            .z => try writer.writeAll(".z"),
            .w => try writer.writeAll(".w"),
        }
    }
}

fn emitIndexAccess(writer: std.ArrayList(u8).Writer, air: *const Air, inst: Inst.IndexAccess) !void {
    try emitExpr(writer, air, inst.base);
    try writer.writeAll("[");
    try emitExpr(writer, air, inst.index);
    try writer.writeAll("]");
}
