const std = @import("std");
const dusk = @import("main.zig");
const ErrorList = dusk.ErrorList;
const Ast = dusk.Ast;
const Air = dusk.Air;
const printAir = dusk.printAir;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const allocator = std.testing.allocator;

fn expectIR(source: [:0]const u8) !Air {
    var tree = try Ast.parse(allocator, source);
    defer tree.deinit(allocator);

    if (tree.errors.list.items.len > 0) {
        try tree.errors.print(source, null);
        return error.Parsing;
    }

    var ir = try Air.generate(allocator, &tree);
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

    var ir: ?Air = null;
    defer if (ir != null) ir.?.deinit();

    if (err_list.list.items.len == 0) {
        ir = try Air.generate(allocator, &tree);

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

test "empty" {
    const source = "";
    var ir = try expectIR(source);
    defer ir.deinit();
}

test "gkurve" {
    if (true) return;
    var ir = try expectIR(@embedFile("test/gkurve.wgsl"));
    defer ir.deinit();
    try printAir(ir, std.io.getStdOut().writer());
}

test "must pass" {
    {
        const source =
            \\const expr = 5 + 6;
            \\var v0: i32;
            \\struct G {
            \\  @align(expr % 2 + 3) l: L,
            \\}
            \\struct L {
            \\  f: array<O>,
            \\}
            \\struct O {
            \\  n: u32,
            \\}
            \\var v1: G;
            \\fn test() -> u32 {
            \\  v0 = v1.l.f[0].n;
            \\}
        ;
        var ir = try expectIR(source);
        try printAir(ir, std.io.getStdOut().writer());
        ir.deinit();
    }
    {
        const source =
            \\var v0: ptr<storage, u32>;
            \\var v1 = *v0 + 5;
            \\var v2 = v1 * 4;
        ;
        var ir = try expectIR(source);
        ir.deinit();
    }
    {
        const source =
            \\var v0: array<u32, 4>;
        ;
        var ir = try expectIR(source);
        ir.deinit();
    }
    {
        const source =
            \\var v0: array<u32>;
            \\var v1 = v0[0];
        ;
        var ir = try expectIR(source);
        ir.deinit();
    }
    {
        const source =
            \\struct S { f: u32 }
            \\var v0: S;
            \\var v1 = v0.f;
        ;
        var ir = try expectIR(source);
        ir.deinit();
    }
    {
        const source =
            \\var v0: u32;
            \\var v1 = bitcast<u32>(v0);
        ;
        var ir = try expectIR(source);
        ir.deinit();
    }
    {
        const source =
            \\var v0: vec2<u32>;
            \\var v1 = bitcast<vec2<u32>>(v0);
        ;
        var ir = try expectIR(source);
        ir.deinit();
    }
}

test "integer/float literals" {
    const source =
        \\var a = 1u;
        \\var b = +123;
        \\var c = 0;
        \\var d = 0i;
        \\
        \\var e = 0x123;
        \\var f = 0X123u;
        \\//var g = 0x3f;
        \\
        \\var h = 0.e+4f;
        \\var i = .01;
        \\var j = 12.34;
        \\var k = .0f;
        \\var l = 0h;
        \\var m = 1e-3;
        \\
        \\//var n = 0xa.fp+2;
        \\//var o = 0x1P+4f;
        \\//var p = 0X.3;
        \\//var q = 0x3p+2h;
        \\//var r = 0X1.fp-4;
        \\//var s = 0x3.2p+2h;
    ;
    var ir = try expectIR(source);
    defer ir.deinit();

    const toInst = struct {
        fn toInst(air: Air, i: Air.InstIndex) Air.Inst {
            return air.instructions[air.instructions[i].global_variable_decl.expr];
        }
    }.toInst;

    const vars = std.mem.sliceTo(ir.refs[ir.globals_index..], Air.null_index);
    try expectEqual(toInst(ir, vars[0]).integer, .{ .value = 1, .base = 10, .tag = .u });
    try expectEqual(toInst(ir, vars[1]).integer, .{ .value = 123, .base = 10, .tag = .none });
    try expectEqual(toInst(ir, vars[2]).integer, .{ .value = 0, .base = 10, .tag = .none });
    try expectEqual(toInst(ir, vars[3]).integer, .{ .value = 0, .base = 10, .tag = .i });
    try expectEqual(toInst(ir, vars[4]).integer, .{ .value = 0x123, .base = 16, .tag = .none });
    try expectEqual(toInst(ir, vars[5]).integer, .{ .value = 0x123, .base = 16, .tag = .u });
    try expectEqual(toInst(ir, vars[6]).float, .{ .value = 0.e+4, .base = 10, .tag = .f });
    try expectEqual(toInst(ir, vars[7]).float, .{ .value = 0.01, .base = 10, .tag = .none });
    try expectEqual(toInst(ir, vars[8]).float, .{ .value = 12.34, .base = 10, .tag = .none });
    try expectEqual(toInst(ir, vars[9]).float, .{ .value = 0.0, .base = 10, .tag = .f });
    try expectEqual(toInst(ir, vars[10]).float, .{ .value = 0, .base = 10, .tag = .h });
    try expectEqual(toInst(ir, vars[11]).float, .{ .value = 1e-3, .base = 10, .tag = .none });
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
            .msg = "invalid texture component type",
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
    {
        const source =
            \\var v0: u32;
            \\var v1 = v0[0];
        ;
        try expectError(source, .{
            .msg = "cannot access index of a non-array variable",
            .loc = .{ .start = 25, .end = 26 },
        });
    }
    {
        const source =
            \\var v0: array<u32>;
            \\var v1 = 5[0];
        ;
        try expectError(source, .{
            .msg = "expected array type",
            .loc = .{ .start = 29, .end = 30 },
        });
    }
    {
        const source =
            \\var v0: array<u32>;
            \\var v1 = v0[true];
        ;
        try expectError(source, .{
            .msg = "index must be an integer",
            .loc = .{ .start = 32, .end = 36 },
        });
    }
    {
        const source =
            \\struct S { f: u32 }
            \\var v0: S;
            \\var v1 = v0.d;
        ;
        try expectError(source, .{
            .msg = "struct 'S' has no member named 'd'",
            .loc = .{ .start = 42, .end = 44 },
        });
    }
    {
        const source =
            \\var v0 = 01;
        ;
        try expectError(source, .{
            .msg = "leading zero disallowed",
            .loc = .{ .start = 9, .end = 11 },
        });
    }
    {
        const source =
            \\var v0 = 1ee;
        ;
        try expectError(source, .{
            .msg = "duplicate exponent 'e'",
            .loc = .{ .start = 9, .end = 12 },
        });
    }
    {
        const source =
            \\var v0 = 1.0u;
        ;
        try expectError(source, .{
            .msg = "suffix 'u' on float literal",
            .loc = .{ .start = 9, .end = 13 },
        });
    }
    {
        const source =
            \\var v0 = 5 << 1.0;
        ;
        try expectError(source, .{
            .msg = "invalid operation",
            .loc = .{ .start = 11, .end = 13 },
        });
    }
}
