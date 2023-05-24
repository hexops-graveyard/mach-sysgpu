const std = @import("std");
const Air = @import("Air.zig");

const indention_size = 2;

pub fn printAir(ir: Air, writer: anytype) !void {
    var p = Printer(@TypeOf(writer)){
        .ir = ir,
        .writer = writer,
        .tty = std.debug.TTY.Config{ .escape_codes = {} },
    };
    const globals = std.mem.sliceTo(ir.refs[ir.globals_index..], .none);
    for (globals) |ref| {
        try p.printInst(0, ref, false);
    }
}

fn Printer(comptime Writer: type) type {
    return struct {
        ir: Air,
        writer: Writer,
        tty: std.debug.TTY.Config,

        fn printInst(self: @This(), indent: u16, ref: Air.Inst.Ref, decl_scope: bool) Writer.Error!void {
            switch (ref) {
                .none,
                .bool_type,
                .i32_type,
                .u32_type,
                .f32_type,
                .f16_type,
                .sampler_type,
                .comparison_sampler_type,
                .external_sampled_texture_type,
                .true,
                .false,
                => {
                    try self.tty.setColor(self.writer, .Green);
                    try self.writer.print(".{s}", .{@tagName(ref)});
                    try self.tty.setColor(self.writer, .Reset);
                },
                _ => {
                    const index = ref.toIndex().?;
                    const inst = self.ir.instructions[index];

                    if (decl_scope and inst.tag.isDecl()) {
                        try self.writer.print("&[{d}]", .{index});
                        return;
                    }

                    switch (inst.tag) {
                        .global_variable_decl => {
                            std.debug.assert(indent == 0);
                            try self.printGlobalVariable(indent, index);
                            try self.printFieldEnd();
                        },
                        .global_const => {
                            std.debug.assert(indent == 0);
                            try self.printConstDecl(indent, index);
                            try self.printFieldEnd();
                        },
                        .struct_decl => {
                            std.debug.assert(indent == 0);
                            try self.printStructDecl(indent, index);
                            try self.printFieldEnd();
                        },
                        .fn_decl => {
                            std.debug.assert(indent == 0);
                            try self.printFnDecl(indent, index);
                            try self.printFieldEnd();
                        },
                        .integer, .float => try self.printNumberLiteral(indent, index),
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
                        => try self.printBinary(indent, index),
                        .field_access => try self.printFieldAccess(indent, index),
                        .index_access => try self.printIndexAccess(indent, index),
                        else => {
                            try self.instStart(index);
                            try self.writer.writeAll("TODO");
                            try self.instEnd();
                        },
                    }
                },
            }
        }

        fn printGlobalVariable(self: @This(), indent: u16, index: Air.Inst.Index) Writer.Error!void {
            const inst = self.ir.instructions[index];
            try self.instBlockStart(index);
            try self.printField(indent + 1, "name", inst.data.global_variable_decl.name);
            if (inst.data.global_variable_decl.addr_space != .none) {
                try self.printField(indent + 1, "addr_space", inst.data.global_variable_decl.addr_space);
            }
            if (inst.data.global_variable_decl.access_mode != .none) {
                try self.printField(indent + 1, "access_mode", inst.data.global_variable_decl.access_mode);
            }
            try self.printField(indent + 1, "type", inst.data.global_variable_decl.type);
            try self.printField(indent + 1, "value", inst.data.global_variable_decl.expr);
            try self.instBlockEnd(indent);
        }

        fn printConstDecl(self: @This(), indent: u16, index: Air.Inst.Index) Writer.Error!void {
            const inst = self.ir.instructions[index];
            try self.instBlockStart(index);
            try self.printField(indent + 1, "name", inst.data.global_const.name);
            try self.printField(indent + 1, "type", inst.data.global_const.type);
            try self.printField(indent + 1, "value", inst.data.global_const.expr);
            try self.instBlockEnd(indent);
        }

        fn printStructDecl(self: @This(), indent: u16, index: Air.Inst.Index) Writer.Error!void {
            const inst = self.ir.instructions[index];
            try self.instBlockStart(index);
            try self.printField(indent + 1, "name", inst.data.struct_decl.name);
            try self.printFieldName(indent + 1, "members");
            try self.listStart();
            const members = std.mem.sliceTo(self.ir.refs[inst.data.struct_decl.members..], .none);
            for (members) |member| {
                const member_index = member.toIndex().?;
                const member_inst = self.ir.instructions[member_index];
                try self.printIndent(indent + 2);
                try self.instBlockStart(member_index);
                try self.printField(indent + 3, "name", member_inst.data.struct_member.name);
                try self.printField(indent + 3, "type", member_inst.data.struct_member.type);
                try self.instBlockEnd(indent + 2);
                try self.printFieldEnd();
            }
            try self.listEnd(indent + 1);
            try self.printFieldEnd();
            try self.instBlockEnd(indent);
        }

        fn printFnDecl(self: @This(), indent: u16, index: Air.Inst.Index) Writer.Error!void {
            const inst = self.ir.instructions[index];
            try self.instBlockStart(index);
            try self.printField(indent + 1, "name", inst.data.fn_decl.name);

            if (inst.data.fn_decl.params != 0) {
                try self.printFieldName(indent + 1, "params");
                try self.listStart();
                const params = std.mem.sliceTo(self.ir.refs[inst.data.fn_decl.params..], .none);
                for (params) |arg| {
                    const arg_index = arg.toIndex().?;
                    const arg_inst = self.ir.instructions[arg_index];
                    try self.printIndent(indent + 2);
                    try self.instBlockStart(arg_index);
                    try self.printField(indent + 3, "name", arg_inst.data.fn_param.name);
                    try self.printField(indent + 3, "type", arg_inst.data.fn_param.type);
                    if (arg_inst.data.fn_param.builtin != .none) {
                        try self.printField(indent + 3, "builtin", arg_inst.data.fn_param.builtin);
                    }
                    if (arg_inst.data.fn_param.interpolate) |interpolate| {
                        try self.printFieldName(indent + 3, "interpolate");
                        try self.instBlockStart(index);
                        try self.printField(indent + 4, "type", interpolate.type);
                        if (interpolate.sample != .none) {
                            try self.printField(indent + 4, "sample", interpolate.sample);
                        }
                        try self.instBlockEnd(indent + 4);
                        try self.printFieldEnd();
                    }
                    if (arg_inst.data.fn_param.location != .none) {
                        try self.printField(indent + 3, "location", arg_inst.data.fn_param.location);
                    }
                    if (arg_inst.data.fn_param.invariant) {
                        try self.printField(indent + 3, "invariant", arg_inst.data.fn_param.invariant);
                    }
                    try self.instBlockEnd(indent + 2);
                    try self.printFieldEnd();
                }
                try self.listEnd(indent + 1);
                try self.printFieldEnd();
            }

            if (inst.data.fn_decl.statements != 0) {
                try self.printFieldName(indent + 1, "statements");
                try self.listStart();
                const statements = std.mem.sliceTo(self.ir.refs[inst.data.fn_decl.statements..], .none);
                for (statements) |statement| {
                    try self.printIndent(indent + 2);
                    try self.printInst(indent + 2, statement, true);
                    try self.printFieldEnd();
                }
                try self.listEnd(indent + 1);
                try self.printFieldEnd();
            }

            try self.instBlockEnd(indent);
        }

        fn printNumberLiteral(self: @This(), indent: u16, index: Air.Inst.Index) Writer.Error!void {
            const inst = self.ir.instructions[index];
            try self.instBlockStart(index);
            switch (inst.tag) {
                .integer => try self.printField(indent + 1, "value", inst.data.integer.value),
                .float => try self.printField(indent + 1, "value", inst.data.float.value),
                else => unreachable,
            }
            switch (inst.tag) {
                .integer => try self.printField(indent + 1, "base", inst.data.integer.base),
                .float => try self.printField(indent + 1, "base", inst.data.float.base),
                else => unreachable,
            }
            switch (inst.tag) {
                .integer => try self.printField(indent + 1, "tag", inst.data.integer.tag),
                .float => try self.printField(indent + 1, "tag", inst.data.float.tag),
                else => unreachable,
            }
            try self.instBlockEnd(indent);
        }

        fn printBinary(self: @This(), indent: u16, index: Air.Inst.Index) Writer.Error!void {
            const inst = self.ir.instructions[index];
            try self.instBlockStart(index);
            try self.printField(indent + 1, "lhs", inst.data.binary.lhs);
            try self.printField(indent + 1, "rhs", inst.data.binary.rhs);
            try self.instBlockEnd(indent);
        }

        fn printFieldAccess(self: @This(), indent: u16, index: Air.Inst.Index) Writer.Error!void {
            const inst = self.ir.instructions[index];
            try self.instBlockStart(index);
            try self.printField(indent + 1, "base", inst.data.field_access.base);
            try self.printField(indent + 1, "name", inst.data.field_access.name);
            try self.instBlockEnd(indent);
        }

        fn printIndexAccess(self: @This(), indent: u16, index: Air.Inst.Index) Writer.Error!void {
            const inst = self.ir.instructions[index];
            try self.instBlockStart(index);
            try self.printField(indent + 1, "base", inst.data.index_access.base);
            try self.printField(indent + 1, "elem_type", inst.data.index_access.elem_type);
            try self.printField(indent + 1, "index", inst.data.index_access.index);
            try self.instBlockEnd(indent);
        }

        fn instStart(self: @This(), index: Air.Inst.Index) !void {
            const inst = self.ir.instructions[index];
            try self.tty.setColor(self.writer, .Bold);
            try self.writer.print("{s}", .{@tagName(inst.tag)});
            try self.tty.setColor(self.writer, .Reset);
            try self.tty.setColor(self.writer, .Dim);
            try self.writer.print("<", .{});
            try self.tty.setColor(self.writer, .Reset);
            try self.tty.setColor(self.writer, .Cyan);
            try self.writer.print("{d}", .{index});
            try self.tty.setColor(self.writer, .Reset);
            try self.tty.setColor(self.writer, .Dim);
            try self.writer.print(">", .{});
            try self.writer.print("(", .{});
            try self.tty.setColor(self.writer, .Reset);
        }

        fn instEnd(self: @This()) !void {
            try self.tty.setColor(self.writer, .Dim);
            try self.writer.writeAll(")");
            try self.tty.setColor(self.writer, .Reset);
        }

        fn instBlockStart(self: @This(), index: Air.Inst.Index) !void {
            const inst = self.ir.instructions[index];
            try self.tty.setColor(self.writer, .Bold);
            try self.writer.print("{s}", .{@tagName(inst.tag)});
            try self.tty.setColor(self.writer, .Reset);
            try self.tty.setColor(self.writer, .Dim);
            try self.writer.print("<", .{});
            try self.tty.setColor(self.writer, .Reset);
            try self.tty.setColor(self.writer, .Cyan);
            try self.writer.print("{d}", .{index});
            try self.tty.setColor(self.writer, .Reset);
            try self.tty.setColor(self.writer, .Dim);
            try self.writer.print(">", .{});
            try self.writer.print("(\n", .{});
            try self.tty.setColor(self.writer, .Reset);
        }

        fn instBlockEnd(self: @This(), indent: u16) !void {
            try self.printIndent(indent);
            try self.tty.setColor(self.writer, .Dim);
            try self.writer.writeAll(")");
            try self.tty.setColor(self.writer, .Reset);
        }

        fn listStart(self: @This()) !void {
            try self.tty.setColor(self.writer, .Dim);
            try self.writer.writeAll("[\n");
            try self.tty.setColor(self.writer, .Reset);
        }

        fn listEnd(self: @This(), indent: u16) !void {
            try self.printIndent(indent);
            try self.tty.setColor(self.writer, .Dim);
            try self.writer.writeAll("]");
            try self.tty.setColor(self.writer, .Reset);
        }

        fn printFieldName(self: @This(), indent: u16, name: []const u8) !void {
            try self.printIndent(indent);
            try self.tty.setColor(self.writer, .White);
            try self.writer.print("{s}", .{name});
            try self.tty.setColor(self.writer, .Dim);
            try self.writer.print(": ", .{});
            try self.tty.setColor(self.writer, .Reset);
        }

        fn printField(self: @This(), indent: u16, name: []const u8, value: anytype) !void {
            try self.printFieldName(indent, name);
            switch (@TypeOf(value)) {
                Air.Inst.Ref => try self.printInst(indent, value, true),
                u32 => {
                    // assume string index
                    try self.tty.setColor(self.writer, .Yellow);
                    try self.writer.print("'{s}'", .{self.ir.getStr(value)});
                    try self.tty.setColor(self.writer, .Reset);
                },
                else => {
                    if (@typeInfo(@TypeOf(value)) == .Enum) {
                        try self.tty.setColor(self.writer, .Green);
                        try self.writer.print(".{s}", .{@tagName(value)});
                        try self.tty.setColor(self.writer, .Reset);
                    } else {
                        try self.tty.setColor(self.writer, .Cyan);
                        try self.writer.print("{}", .{value});
                        try self.tty.setColor(self.writer, .Reset);
                    }
                },
            }
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
