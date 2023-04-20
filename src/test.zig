const std = @import("std");
const IR = @import("IR.zig");
const Ast = @import("Ast.zig");
const ErrorList = @import("ErrorList.zig");
const printIR = @import("print_ir.zig").printIR;
const expect = std.testing.expect;
const allocator = std.testing.allocator;

fn expectIR(source: [:0]const u8) !IR {
    var tree = try Ast.parse(allocator, source);
    defer tree.deinit(allocator);

    if (tree.errors.list.items.len > 0) {
        try tree.errors.print(source, null);
        return error.Parsing;
    }

    var ir = try IR.generate(allocator, &tree);
    errdefer ir.deinit();

    if (ir.errors.list.items.len > 0) {
        try ir.errors.print(source, null);
        return error.ExpectedIR;
    }

    return ir;
}

fn expectError(source: [:0]const u8, err: ErrorList.ErrorMsg) !void {
    var tree = try Ast.parse(allocator, source);
    defer tree.deinit(allocator);
    var err_list = tree.errors;

    var ir: ?IR = null;
    defer if (ir != null) ir.?.deinit();

    if (err_list.list.items.len == 0) {
        ir = try IR.generate(allocator, &tree);

        err_list = ir.?.errors;
        if (err_list.list.items.len == 0) {
            return error.ExpectedError;
        }
    }

    const first_error = err_list.list.items[0];
    {
        errdefer {
            std.debug.print(
                "\n\x1b[31mexpected error({d}..{d}):\n{s}\n\x1b[32mactual error({d}..{d}):\n{s}\n\x1b[0m",
                .{
                    err.loc.start,         err.loc.end,         err.msg,
                    first_error.loc.start, first_error.loc.end, first_error.msg,
                },
            );
        }
        try expect(std.mem.eql(u8, err.msg, first_error.msg));
        try expect(first_error.loc.start == err.loc.start);
        try expect(first_error.loc.end == err.loc.end);
    }
    if (first_error.note) |_| {
        errdefer {
            std.debug.print(
                "\n\x1b[31mexpected note msg:\n{s}\n\x1b[32mactual note msg:\n{s}\n\x1b[0m",
                .{ err.note.?.msg, first_error.note.?.msg },
            );
        }
        if (err.note == null) {
            std.debug.print("\x1b[31mnote missed: {s}\x1b[0m\n", .{first_error.note.?.msg});
            return error.NoteMissed;
        }
        try expect(std.mem.eql(u8, err.note.?.msg, first_error.note.?.msg));
        if (first_error.note.?.loc) |_| {
            errdefer {
                std.debug.print(
                    "\n\x1b[31mexpected note loc: {d}..{d}\n\x1b[32mactual note loc: {d}..{d}\n\x1b[0m",
                    .{
                        err.note.?.loc.?.start,         err.note.?.loc.?.end,
                        first_error.note.?.loc.?.start, first_error.note.?.loc.?.end,
                    },
                );
            }
            try expect(first_error.note.?.loc.?.start == err.note.?.loc.?.start);
            try expect(first_error.note.?.loc.?.end == err.note.?.loc.?.end);
        }
    }
}

test {
    std.testing.refAllDecls(@import("Ast.zig"));
    std.testing.refAllDecls(@import("AstGen.zig"));
    std.testing.refAllDecls(@import("ErrorList.zig"));
    std.testing.refAllDecls(@import("IR.zig"));
    std.testing.refAllDecls(@import("Parser.zig"));
    std.testing.refAllDecls(@import("print_ir.zig"));
    std.testing.refAllDecls(@import("Token.zig"));
    std.testing.refAllDecls(@import("Tokenizer.zig"));
}

test "empty" {
    const source = "";
    var ir = try expectIR(source);
    defer ir.deinit();
}

test "gkurve" {
    var ir = try expectIR(@embedFile("test/gkurve.wgsl"));
    defer ir.deinit();
}

test "must pass" {
    {
        const source =
            \\var v0: ptr<storage, u32> = 2;
            \\var v1 = *v0 + 5;
            \\var v2 = v1 * 4;
        ;
        var ir = try expectIR(source);
        ir.deinit();
    }
    {
        const source =
            \\var v0: array<u32, 4> = 2;
        ;
        var ir = try expectIR(source);
        ir.deinit();
    }
}

test "must error" {
    {
        const source = "^";
        try expectError(source, .{
            .msg = "expected global declaration, found '^'",
            .loc = .{ .start = 0, .end = 1 },
        });
    }
    {
        const source = "struct S { m0: array<f32>, m1: f32 }";
        try expectError(source, .{
            .msg = "struct member with runtime-sized array type, must be the last member of the structure",
            .loc = .{ .start = 11, .end = 13 },
        });
    }
    {
        const source = "struct S0 { m: S1 }";
        try expectError(source, .{
            .msg = "use of undeclared identifier 'S1'",
            .loc = .{ .start = 15, .end = 17 },
        });
    }
    {
        const source =
            \\var S1 = 0;
            \\struct S0 { m: S1 }
        ;
        try expectError(source, .{
            .msg = "'S1' is not a type",
            .loc = .{ .start = 27, .end = 29 },
        });
    }
    {
        const source =
            \\struct S0 { m: sampler }
        ;
        try expectError(source, .{
            .msg = "invalid struct member type 'sampler'",
            .loc = .{ .start = 12, .end = 13 },
        });
    }
    {
        const source =
            \\var d1 = 0;
            \\var d1 = 0;
        ;
        try expectError(source, .{
            .msg = "redeclaration of 'd1'",
            .loc = .{ .start = 16, .end = 18 },
            .note = .{ .msg = "other declaration here", .loc = .{ .start = 4, .end = 6 } },
        });
    }
    {
        const source = "struct S { m0: vec2<sampler> }";
        try expectError(source, .{
            .msg = "invalid vector component type",
            .loc = .{ .start = 20, .end = 27 },
            .note = .{ .msg = "must be 'i32', 'u32', 'f32', 'f16' or 'bool'" },
        });
    }
    {
        const source =
            \\type T0 = sampler;
            \\type T1 = texture_1d<T0>;
        ;
        try expectError(source, .{
            .msg = "invalid sampled texture component type",
            .loc = .{ .start = 40, .end = 42 },
            .note = .{ .msg = "must be 'i32', 'u32' or 'f32'" },
        });
    }
    {
        const source =
            \\var v0 = 2;
            \\var v1 = &v0 + 5;
        ;
        try expectError(source, .{
            .msg = "invalid operation with '&v0'",
            .loc = .{ .start = 21, .end = 24 },
        });
    }
    {
        const source =
            \\var v0 = *4 + 5;
        ;
        try expectError(source, .{
            .msg = "cannot dereference '4'",
            .loc = .{ .start = 10, .end = 11 },
        });
    }
    {
        const source =
            \\var v0 = 1;
            \\var v1 = *v0 + 5;
        ;
        try expectError(source, .{
            .msg = "cannot dereference non-pointer variable 'v0'",
            .loc = .{ .start = 22, .end = 24 },
        });
    }
    {
        const source =
            \\var v0 = -false;
        ;
        try expectError(source, .{
            .msg = "cannot negate 'false'",
            .loc = .{ .start = 10, .end = 15 },
        });
    }
    {
        const source =
            \\var v0 = !5;
        ;
        try expectError(source, .{
            .msg = "cannot operate not (!) on '5'",
            .loc = .{ .start = 10, .end = 11 },
        });
    }
}
