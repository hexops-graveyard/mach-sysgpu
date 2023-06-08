const std = @import("std");
const Air = @import("Air.zig");
const null_inst = Air.null_inst;
const null_ref = Air.null_ref;

const indention_size = 2;

pub fn printAir(ir: Air, writer: anytype) !void {
    var p = Printer(@TypeOf(writer)){
        .ir = ir,
        .writer = writer,
        .tty = std.io.tty.Config{ .escape_codes = {} },
    };
    const globals = std.mem.sliceTo(ir.refs[ir.globals_index..], null_inst);
    for (globals) |ref| {
        try p.printInst(0, ref);
    }
}

fn Printer(comptime Writer: type) type {
    return struct {
        ir: Air,
        writer: Writer,
        tty: std.io.tty.Config,

        fn printInst(self: @This(), indent: u16, index: Air.InstIndex) Writer.Error!void {
            const inst = self.ir.instructions[index];
            switch (inst) {
                .global_var => {
                    std.debug.assert(indent == 0);
                    try self.printGlobalVariable(indent, index);
                    try self.printFieldEnd();
                },
                .global_const => {
                    std.debug.assert(indent == 0);
                    try self.printConstDecl(indent, index);
                    try self.printFieldEnd();
                },
                .@"struct" => {
                    std.debug.assert(indent == 0);
                    try self.printStructDecl(indent, index);
                    try self.printFieldEnd();
                },
                .@"fn" => {
                    std.debug.assert(indent == 0);
                    try self.printFnDecl(indent, index);
                    try self.printFieldEnd();
                },
                .bool => try self.printBool(indent, index),
                .int, .float => try self.printNumber(indent, index),
                .vector => try self.printVector(indent, index),
                .matrix => try self.printMatrix(indent, index),
                .sampler_type,
                .comparison_sampler_type,
                .external_texture_type,
                => {
                    try self.tty.setColor(self.writer, .bright_magenta);
                    try self.writer.print(".{s}", .{@tagName(inst)});
                    try self.tty.setColor(self.writer, .reset);
                },
                .mul,
                .div,
                .mod,
                .add,
                .sub,
                .shift_left,
                .shift_right,
                .@"and",
                .@"or",
                .xor,
                .logical_and,
                .logical_or,
                .equal,
                .not_equal,
                .less_than,
                .less_than_equal,
                .greater_than,
                .greater_than_equal,
                .assign,
                => |bin| {
                    try self.instBlockStart(index);
                    try self.printFieldInst(indent + 1, "lhs", bin.lhs);
                    try self.printFieldInst(indent + 1, "rhs", bin.rhs);
                    try self.instBlockEnd(indent);
                },
                .field_access => try self.printFieldAccess(indent, index),
                .index_access => try self.printIndexAccess(indent, index),
                .struct_ref, .var_ref => |ref| {
                    try self.instStart(index);
                    try self.tty.setColor(self.writer, .yellow);
                    try self.writer.print("{d}", .{ref});
                    try self.tty.setColor(self.writer, .reset);
                    try self.instEnd();
                },
                else => {
                    try self.instStart(index);
                    try self.writer.writeAll("TODO");
                    try self.instEnd();
                },
            }
        }

        fn printGlobalVariable(self: @This(), indent: u16, index: Air.InstIndex) Writer.Error!void {
            const inst = self.ir.instructions[index];
            try self.instBlockStart(index);
            try self.printFieldString(indent + 1, "name", inst.global_var.name);
            if (inst.global_var.addr_space != .none) {
                try self.printFieldEnum(indent + 1, "addr_space", inst.global_var.addr_space);
            }
            if (inst.global_var.access_mode != .none) {
                try self.printFieldEnum(indent + 1, "access_mode", inst.global_var.access_mode);
            }
            if (inst.global_var.type != null_inst) {
                try self.printFieldInst(indent + 1, "type", inst.global_var.type);
            }
            if (inst.global_var.expr != null_inst) {
                try self.printFieldInst(indent + 1, "value", inst.global_var.expr);
            }
            try self.instBlockEnd(indent);
        }

        fn printConstDecl(self: @This(), indent: u16, index: Air.InstIndex) Writer.Error!void {
            const inst = self.ir.instructions[index];
            try self.instBlockStart(index);
            try self.printFieldString(indent + 1, "name", inst.global_const.name);
            if (inst.global_const.type != null_inst) {
                try self.printFieldInst(indent + 1, "type", inst.global_const.type);
            }
            try self.printFieldInst(indent + 1, "value", inst.global_const.expr);
            try self.instBlockEnd(indent);
        }

        fn printStructDecl(self: @This(), indent: u16, index: Air.InstIndex) Writer.Error!void {
            const inst = self.ir.instructions[index];
            try self.instBlockStart(index);
            try self.printFieldString(indent + 1, "name", inst.@"struct".name);
            try self.printFieldName(indent + 1, "members");
            try self.listStart();
            const members = std.mem.sliceTo(self.ir.refs[inst.@"struct".members..], null_inst);
            for (members) |member| {
                const member_index = member;
                const member_inst = self.ir.instructions[member_index];
                try self.printIndent(indent + 2);
                try self.instBlockStart(member_index);
                try self.printFieldString(indent + 3, "name", member_inst.struct_member.name);
                try self.printFieldInst(indent + 3, "type", member_inst.struct_member.type);
                if (member_inst.struct_member.@"align") |@"align"| {
                    try self.printFieldAny(indent + 3, "align", @"align");
                }
                if (member_inst.struct_member.size) |size| {
                    try self.printFieldAny(indent + 3, "size", size);
                }
                if (member_inst.struct_member.builtin != .none) {
                    try self.printFieldAny(indent + 3, "builtin", member_inst.struct_member.builtin);
                }
                if (member_inst.struct_member.location != null_inst) {
                    try self.printFieldAny(indent + 3, "location", member_inst.struct_member.location);
                }
                try self.instBlockEnd(indent + 2);
                try self.printFieldEnd();
            }
            try self.listEnd(indent + 1);
            try self.printFieldEnd();
            try self.instBlockEnd(indent);
        }

        fn printFnDecl(self: @This(), indent: u16, index: Air.InstIndex) Writer.Error!void {
            const inst = self.ir.instructions[index];
            try self.instBlockStart(index);
            try self.printFieldString(indent + 1, "name", inst.@"fn".name);

            if (inst.@"fn".params != null_ref) {
                try self.printFieldName(indent + 1, "params");
                try self.listStart();
                const params = std.mem.sliceTo(self.ir.refs[inst.@"fn".params..], null_inst);
                for (params) |arg| {
                    const arg_index = arg;
                    const arg_inst = self.ir.instructions[arg_index];
                    try self.printIndent(indent + 2);
                    try self.instBlockStart(arg_index);
                    try self.printFieldString(indent + 3, "name", arg_inst.fn_param.name);
                    try self.printFieldInst(indent + 3, "type", arg_inst.fn_param.type);
                    if (arg_inst.fn_param.builtin != .none) {
                        try self.printFieldEnum(indent + 3, "builtin", arg_inst.fn_param.builtin);
                    }
                    if (arg_inst.fn_param.interpolate) |interpolate| {
                        try self.printFieldName(indent + 3, "interpolate");
                        try self.instBlockStart(index);
                        try self.printFieldEnum(indent + 4, "type", interpolate.type);
                        if (interpolate.sample != .none) {
                            try self.printFieldEnum(indent + 4, "sample", interpolate.sample);
                        }
                        try self.instBlockEnd(indent + 4);
                        try self.printFieldEnd();
                    }
                    if (arg_inst.fn_param.location != null_inst) {
                        try self.printFieldInst(indent + 3, "location", arg_inst.fn_param.location);
                    }
                    if (arg_inst.fn_param.invariant) {
                        try self.printFieldAny(indent + 3, "invariant", arg_inst.fn_param.invariant);
                    }
                    try self.instBlockEnd(indent + 2);
                    try self.printFieldEnd();
                }
                try self.listEnd(indent + 1);
                try self.printFieldEnd();
            }

            if (inst.@"fn".block != null_ref) {
                try self.printFieldName(indent + 1, "block");
                try self.printBlock(indent + 1, inst.@"fn".block);
                try self.printFieldEnd();
            }

            try self.instBlockEnd(indent);
        }

        fn printBlock(self: @This(), indent: u16, index: Air.RefIndex) Writer.Error!void {
            const statements = std.mem.sliceTo(self.ir.refs[index..], null_inst);
            try self.listStart();
            for (statements) |statement| {
                try self.printIndent(indent + 1);
                try self.printInst(indent + 1, statement);
                try self.printFieldEnd();
            }
            try self.listEnd(indent);
        }

        fn printBool(self: @This(), indent: u16, index: Air.InstIndex) Writer.Error!void {
            const inst = self.ir.instructions[index];
            if (inst.bool.value) |value| {
                try self.instBlockStart(index);
                switch (value) {
                    .literal => |lit| try self.printFieldAny(indent + 1, "value", lit),
                    .inst => |cast_inst| try self.printFieldAny(indent + 1, "cast", cast_inst),
                }
                try self.instBlockEnd(indent);
            } else {
                try self.instStart(index);
                try self.instEnd();
            }
        }

        fn printNumber(self: @This(), indent: u16, index: Air.InstIndex) Writer.Error!void {
            const inst = self.ir.instructions[index];
            try self.instBlockStart(index);
            switch (inst) {
                inline .int, .float => |num| {
                    try self.printFieldEnum(indent + 1, "type", num.type);
                    if (num.value) |value| {
                        switch (value) {
                            .literal => |lit| {
                                try self.printFieldAny(indent + 1, "value", lit.value);
                                try self.printFieldAny(indent + 1, "base", lit.base);
                            },
                            .inst => |cast| try self.printFieldAny(indent + 1, "cast", cast),
                        }
                    }
                },
                else => unreachable,
            }
            try self.instBlockEnd(indent);
        }

        fn printVector(self: @This(), indent: u16, index: Air.InstIndex) Writer.Error!void {
            const vec = self.ir.instructions[index].vector;
            try self.instBlockStart(index);
            try self.printFieldInst(indent + 1, "type", vec.elem_type);
            if (vec.value) |value| {
                switch (value) {
                    .literal => |lit| {
                        try self.printFieldName(indent + 1, "literal");
                        try self.tty.setColor(self.writer, .dim);
                        try self.writer.writeAll("[");
                        try self.tty.setColor(self.writer, .reset);
                        for (0..@enumToInt(vec.size)) |i| {
                            try self.tty.setColor(self.writer, .cyan);
                            try self.writer.print("{d}", .{lit[i]});
                            try self.tty.setColor(self.writer, .reset);
                            try self.tty.setColor(self.writer, .dim);
                            if (i < @enumToInt(vec.size) - 1) try self.writer.writeAll(", ");
                            try self.tty.setColor(self.writer, .reset);
                        }
                        try self.tty.setColor(self.writer, .dim);
                        try self.writer.writeAll("]");
                        try self.tty.setColor(self.writer, .reset);
                        try self.printFieldEnd();
                    },
                    .inst => |cast| {
                        try self.printFieldName(indent + 1, "cast");
                        try self.listStart();
                        for (0..@enumToInt(vec.size)) |i| {
                            if (cast[i] == null_inst) continue;
                            try self.printIndent(indent + 2);
                            try self.printInst(indent + 2, cast[i]);
                            try self.printFieldEnd();
                        }
                        try self.listEnd(indent + 1);
                        try self.printFieldEnd();
                    },
                }
            }
            try self.instBlockEnd(indent);
        }

        fn printMatrix(self: @This(), indent: u16, index: Air.InstIndex) Writer.Error!void {
            const mat = self.ir.instructions[index].matrix;
            try self.instBlockStart(index);
            try self.printFieldInst(indent + 1, "type", mat.elem_type);
            if (mat.value) |value| {
                switch (value) {
                    .literal => |lit| {
                        try self.printFieldName(indent + 1, "literal");
                        try self.tty.setColor(self.writer, .dim);
                        try self.writer.writeAll("[");
                        try self.tty.setColor(self.writer, .reset);
                        for (0..@enumToInt(mat.cols) * @enumToInt(mat.rows)) |i| {
                            try self.tty.setColor(self.writer, .cyan);
                            try self.writer.print("{d}", .{lit[i]});
                            try self.tty.setColor(self.writer, .reset);
                            try self.tty.setColor(self.writer, .dim);
                            if (i < @enumToInt(mat.cols) * @enumToInt(mat.rows) - 1) try self.writer.writeAll(", ");
                            try self.tty.setColor(self.writer, .reset);
                        }
                        try self.tty.setColor(self.writer, .dim);
                        try self.writer.writeAll("]");
                        try self.tty.setColor(self.writer, .reset);
                        try self.printFieldEnd();
                    },
                    .inst => |cast| {
                        try self.printFieldName(indent + 1, "cast");
                        try self.listStart();
                        for (0..@enumToInt(mat.cols) * @enumToInt(mat.rows)) |i| {
                            if (cast[i] == null_inst) continue;
                            try self.printIndent(indent + 2);
                            try self.printInst(indent + 2, cast[i]);
                            try self.printFieldEnd();
                        }
                        try self.listEnd(indent + 1);
                        try self.printFieldEnd();
                    },
                }
            }
            try self.instBlockEnd(indent);
        }

        fn printFieldAccess(self: @This(), indent: u16, index: Air.InstIndex) Writer.Error!void {
            const inst = self.ir.instructions[index];
            try self.instBlockStart(index);
            try self.printFieldInst(indent + 1, "base", inst.field_access.base);
            try self.printFieldString(indent + 1, "name", inst.field_access.name);
            try self.instBlockEnd(indent);
        }

        fn printIndexAccess(self: @This(), indent: u16, index: Air.InstIndex) Writer.Error!void {
            const inst = self.ir.instructions[index];
            try self.instBlockStart(index);
            try self.printFieldInst(indent + 1, "base", inst.index_access.base);
            try self.printFieldInst(indent + 1, "elem_type", inst.index_access.elem_type);
            try self.printFieldInst(indent + 1, "index", inst.index_access.index);
            try self.instBlockEnd(indent);
        }

        fn instStart(self: @This(), index: Air.InstIndex) !void {
            const inst = self.ir.instructions[index];
            try self.tty.setColor(self.writer, .bold);
            try self.writer.print("{s}", .{@tagName(inst)});
            try self.tty.setColor(self.writer, .reset);
            try self.tty.setColor(self.writer, .dim);
            try self.writer.writeAll("<");
            try self.tty.setColor(self.writer, .reset);
            try self.tty.setColor(self.writer, .blue);
            try self.writer.print("{d}", .{index});
            try self.tty.setColor(self.writer, .reset);
            try self.tty.setColor(self.writer, .dim);
            try self.writer.writeAll(">");
            try self.writer.writeAll("(");
            try self.tty.setColor(self.writer, .reset);
        }

        fn instEnd(self: @This()) !void {
            try self.tty.setColor(self.writer, .dim);
            try self.writer.writeAll(")");
            try self.tty.setColor(self.writer, .reset);
        }

        fn instBlockStart(self: @This(), index: Air.InstIndex) !void {
            const inst = self.ir.instructions[index];
            try self.tty.setColor(self.writer, .bold);
            try self.writer.print("{s}", .{@tagName(inst)});
            try self.tty.setColor(self.writer, .reset);
            try self.tty.setColor(self.writer, .dim);
            try self.writer.writeAll("<");
            try self.tty.setColor(self.writer, .reset);
            try self.tty.setColor(self.writer, .blue);
            try self.writer.print("{d}", .{index});
            try self.tty.setColor(self.writer, .reset);
            try self.tty.setColor(self.writer, .dim);
            try self.writer.writeAll(">");
            try self.writer.writeAll("{\n");
            try self.tty.setColor(self.writer, .reset);
        }

        fn instBlockEnd(self: @This(), indent: u16) !void {
            try self.printIndent(indent);
            try self.tty.setColor(self.writer, .dim);
            try self.writer.writeAll("}");
            try self.tty.setColor(self.writer, .reset);
        }

        fn listStart(self: @This()) !void {
            try self.tty.setColor(self.writer, .dim);
            try self.writer.writeAll("[\n");
            try self.tty.setColor(self.writer, .reset);
        }

        fn listEnd(self: @This(), indent: u16) !void {
            try self.printIndent(indent);
            try self.tty.setColor(self.writer, .dim);
            try self.writer.writeAll("]");
            try self.tty.setColor(self.writer, .reset);
        }

        fn printFieldName(self: @This(), indent: u16, name: []const u8) !void {
            try self.printIndent(indent);
            try self.tty.setColor(self.writer, .reset);
            try self.writer.print("{s}", .{name});
            try self.tty.setColor(self.writer, .dim);
            try self.writer.print(": ", .{});
            try self.tty.setColor(self.writer, .reset);
        }

        fn printFieldString(self: @This(), indent: u16, name: []const u8, value: u32) !void {
            try self.printFieldName(indent, name);
            try self.tty.setColor(self.writer, .green);
            try self.writer.print("'{s}'", .{self.ir.getStr(value)});
            try self.tty.setColor(self.writer, .reset);
            try self.printFieldEnd();
        }

        fn printFieldInst(self: @This(), indent: u16, name: []const u8, value: Air.InstIndex) !void {
            try self.printFieldName(indent, name);
            try self.printInst(indent, value);
            try self.printFieldEnd();
        }

        fn printFieldEnum(self: @This(), indent: u16, name: []const u8, value: anytype) !void {
            try self.printFieldName(indent, name);
            try self.tty.setColor(self.writer, .magenta);
            try self.writer.print(".{s}", .{@tagName(value)});
            try self.tty.setColor(self.writer, .reset);
            try self.printFieldEnd();
        }

        fn printFieldAny(self: @This(), indent: u16, name: []const u8, value: anytype) !void {
            try self.printFieldName(indent, name);
            try self.tty.setColor(self.writer, .cyan);
            try self.writer.print("{}", .{value});
            try self.tty.setColor(self.writer, .reset);
            try self.printFieldEnd();
        }

        fn printFieldEnd(self: @This()) !void {
            try self.writer.writeAll(",\n");
        }

        fn printIndent(self: @This(), indent: u16) !void {
            try self.writer.writeByteNTimes(' ', indent * indention_size);
        }
    };
}
