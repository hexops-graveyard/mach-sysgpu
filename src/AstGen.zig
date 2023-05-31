const std = @import("std");
const Ast = @import("Ast.zig");
const Air = @import("Air.zig");
const ErrorList = @import("ErrorList.zig");
const null_inst = Air.null_inst;
const Inst = Air.Inst;
const InstIndex = Air.InstIndex;
const null_node = Ast.null_node;
const Node = Ast.Node;
const NodeIndex = Ast.NodeIndex;
const TokenIndex = Ast.TokenIndex;
const stringToEnum = std.meta.stringToEnum;

const AstGen = @This();

allocator: std.mem.Allocator,
tree: *const Ast,
instructions: std.ArrayListUnmanaged(Inst) = .{},
refs: std.ArrayListUnmanaged(InstIndex) = .{},
strings: std.ArrayListUnmanaged(u8) = .{},
scratch: std.ArrayListUnmanaged(InstIndex) = .{},
errors: ErrorList,
scope_pool: std.heap.MemoryPool(Scope),

pub const Scope = struct {
    tag: Tag,
    /// this is undefined if tag == .root
    parent: *Scope,
    decls: std.AutoHashMapUnmanaged(NodeIndex, error{AnalysisFail}!InstIndex) = .{},

    const Tag = enum {
        root,
        func,
        block,
    };
};

pub fn genTranslationUnit(astgen: *AstGen) !u32 {
    const scratch_top = astgen.scratch.items.len;
    defer astgen.scratch.shrinkRetainingCapacity(scratch_top);

    var root_scope = try astgen.scope_pool.create();
    root_scope.* = .{ .tag = .root, .parent = undefined };

    const global_nodes = astgen.tree.spanToList(0);
    astgen.scanDecls(root_scope, global_nodes) catch |err| switch (err) {
        error.AnalysisFail => return astgen.addRefList(astgen.scratch.items[scratch_top..]),
        error.OutOfMemory => return error.OutOfMemory,
    };

    for (global_nodes) |node| {
        const global = astgen.genGlobalDecl(root_scope, node) catch |err| switch (err) {
            error.AnalysisFail => continue,
            error.OutOfMemory => return error.OutOfMemory,
        };
        try astgen.scratch.append(astgen.allocator, global);
    }

    return astgen.addRefList(astgen.scratch.items[scratch_top..]);
}

/// adds `decls` to scope and checks for re-declarations
fn scanDecls(astgen: *AstGen, scope: *Scope, decls: []const NodeIndex) !void {
    std.debug.assert(scope.decls.count() == 0);

    for (decls) |decl| {
        const loc = astgen.tree.declNameLoc(decl).?;
        const name = loc.slice(astgen.tree.source);

        var iter = scope.decls.keyIterator();
        while (iter.next()) |node| {
            const name_loc = astgen.tree.declNameLoc(node.*).?;
            if (std.mem.eql(u8, name, name_loc.slice(astgen.tree.source))) {
                try astgen.errors.add(
                    loc,
                    "redeclaration of '{s}'",
                    .{name},
                    try astgen.errors.createNote(
                        name_loc,
                        "other declaration here",
                        .{},
                    ),
                );
                return error.AnalysisFail;
            }
        }

        try scope.decls.putNoClobber(astgen.scope_pool.arena.allocator(), decl, null_inst);
    }
}

fn genGlobalDecl(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    var decl = try scope.decls.get(node).?;
    if (decl != null_inst) {
        // the declaration has already analysed
        return decl;
    }

    decl = switch (astgen.tree.nodeTag(node)) {
        .global_var => astgen.genGlobalVariable(scope, node),
        .global_const => astgen.genGlobalConst(scope, node),
        .@"struct" => astgen.genStruct(scope, node),
        .@"fn" => astgen.genFnDecl(scope, node),
        .type_alias => astgen.genTypeAlias(scope, node),
        else => return error.AnalysisFail, // TODO: make this unreachable
    } catch |err| {
        if (err == error.AnalysisFail) {
            scope.decls.putAssumeCapacity(node, error.AnalysisFail);
        }
        return err;
    };

    scope.decls.putAssumeCapacity(node, decl);
    return decl;
}

fn genGlobalVariable(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const var_decl = try astgen.allocInst();
    const node_rhs = astgen.tree.nodeRHS(node);
    const extra_data = astgen.tree.extraData(Node.GlobalVarDecl, astgen.tree.nodeLHS(node));
    const name_loc = astgen.tree.declNameLoc(node).?;

    var is_resource = false;
    var var_type = null_inst;
    if (extra_data.type != null_node) {
        var_type = try astgen.genType(scope, extra_data.type);

        switch (astgen.getInst(var_type)) {
            .sampler_type,
            .comparison_sampler_type,
            .external_texture_type,
            .multisampled_texture_type,
            .storage_texture_type,
            .depth_texture_type,
            => {
                is_resource = true;
            },
            else => {},
        }
    }

    var addr_space: Inst.GlobalVariableDecl.AddressSpace = .none;
    if (extra_data.addr_space != null_node) {
        const addr_space_loc = astgen.tree.tokenLoc(extra_data.addr_space);
        const ast_addr_space = stringToEnum(Ast.AddressSpace, addr_space_loc.slice(astgen.tree.source)).?;
        addr_space = switch (ast_addr_space) {
            .function => .function,
            .private => .private,
            .workgroup => .workgroup,
            .uniform => .uniform,
            .storage => .storage,
        };
    }

    if (addr_space == .uniform or addr_space == .storage) {
        is_resource = true;
    }

    var access_mode: Inst.GlobalVariableDecl.AccessMode = .none;
    if (extra_data.access_mode != null_node) {
        const access_mode_loc = astgen.tree.tokenLoc(extra_data.access_mode);
        const ast_access_mode = stringToEnum(Ast.AccessMode, access_mode_loc.slice(astgen.tree.source)).?;
        access_mode = switch (ast_access_mode) {
            .read => .read,
            .write => .write,
            .read_write => .read_write,
        };
    }

    var binding = null_inst;
    var group = null_inst;
    if (extra_data.attrs != null_node) {
        for (astgen.tree.spanToList(extra_data.attrs)) |attr| {
            if (!is_resource) {
                try astgen.errors.add(
                    astgen.tree.nodeLoc(attr),
                    "variable '{s}' is not a resource",
                    .{name_loc.slice(astgen.tree.source)},
                    null,
                );
                return error.AnalysisFail;
            }

            switch (astgen.tree.nodeTag(attr)) {
                .attr_binding => binding = try astgen.attrBinding(scope, attr),
                .attr_group => group = try astgen.attrGroup(scope, attr),
                else => {
                    try astgen.errors.add(
                        astgen.tree.nodeLoc(attr),
                        "unexpected attribute '{s}'",
                        .{astgen.tree.nodeLoc(attr).slice(astgen.tree.source)},
                        null,
                    );
                    return error.AnalysisFail;
                },
            }
        }
    }

    if (is_resource and (binding == null_inst or group == null_inst)) {
        try astgen.errors.add(
            astgen.tree.nodeLoc(node),
            "resource variable must specify binding and group",
            .{},
            null,
        );
        return error.AnalysisFail;
    }

    var expr = null_inst;
    if (node_rhs != null_node) {
        expr = try astgen.genExpr(scope, node_rhs);
    }

    const name = try astgen.addString(name_loc.slice(astgen.tree.source));
    astgen.instructions.items[var_decl] = .{
        .global_variable_decl = .{
            .name = name,
            .type = var_type,
            .addr_space = addr_space,
            .access_mode = access_mode,
            .binding = binding,
            .group = group,
            .expr = expr,
        },
    };
    return var_decl;
}

fn genGlobalConst(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const const_decl = try astgen.allocInst();
    const node_lhs = astgen.tree.nodeLHS(node);
    const node_rhs = astgen.tree.nodeRHS(node);
    const name_loc = astgen.tree.declNameLoc(node).?;

    var var_type = null_inst;
    if (node_lhs != null_node) {
        var_type = try astgen.genType(scope, node_lhs);
    }

    const expr = try astgen.genExpr(scope, node_rhs);
    if (astgen.resolveConstExpr(expr) == null) {
        try astgen.errors.add(
            name_loc,
            "value of '{s}' must be a const-expression",
            .{name_loc.slice(astgen.tree.source)},
            null,
        );
        return error.AnalysisFail;
    }

    const name = try astgen.addString(name_loc.slice(astgen.tree.source));
    astgen.instructions.items[const_decl] = .{
        .global_const = .{
            .name = name,
            .type = var_type,
            .expr = expr,
        },
    };
    return const_decl;
}

fn genStruct(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const struct_decl = try astgen.allocInst();

    const scratch_top = astgen.scratch.items.len;
    defer astgen.scratch.shrinkRetainingCapacity(scratch_top);

    const member_nodes_list = astgen.tree.spanToList(astgen.tree.nodeLHS(node));
    for (member_nodes_list, 0..) |member_node, i| {
        const member = try astgen.allocInst();
        const member_name_loc = astgen.tree.tokenLoc(astgen.tree.nodeToken(member_node));
        const member_attrs_node = astgen.tree.nodeLHS(member_node);
        const member_type_node = astgen.tree.nodeRHS(member_node);
        const member_type_loc = astgen.tree.nodeLoc(member_type_node);
        const member_type = astgen.genType(scope, member_type_node) catch |err| switch (err) {
            error.AnalysisFail => continue,
            error.OutOfMemory => return error.OutOfMemory,
        };
        const member_type_inst = astgen.getInst(member_type);

        switch (member_type_inst) {
            .array_type,
            .vector_type,
            .matrix_type,
            .atomic_type,
            .struct_ref,
            .bool_type,
            .u32_type,
            .i32_type,
            .f32_type,
            .f16_type,
            => {},
            else => {
                try astgen.errors.add(
                    member_name_loc,
                    "invalid struct member type '{s}'",
                    .{member_type_loc.slice(astgen.tree.source)},
                    null,
                );
            },
        }

        if (member_type_inst == .array_type) {
            const array_size = member_type_inst.array_type.size;
            if (array_size == null_inst and i + 1 != member_nodes_list.len) {
                try astgen.errors.add(
                    member_name_loc,
                    "struct member with runtime-sized array type, must be the last member of the structure",
                    .{},
                    null,
                );
            }
        }

        var @"align": u29 = 0;
        var size: u32 = 0;
        var builtin: Inst.Builtin = .none;
        var location: InstIndex = null_inst;
        var interpolate: ?Inst.Interpolate = null;
        if (member_attrs_node != null_node) {
            for (astgen.tree.spanToList(member_attrs_node)) |attr| {
                switch (astgen.tree.nodeTag(attr)) {
                    .attr_align => @"align" = try astgen.attrAlign(scope, attr),
                    .attr_size => size = try astgen.attrSize(scope, attr),
                    .attr_location => location = try astgen.attrLocation(scope, attr),
                    .attr_builtin => builtin = astgen.attrBuiltin(attr),
                    .attr_interpolate => interpolate = astgen.attrInterpolate(attr),
                    else => {
                        try astgen.errors.add(
                            astgen.tree.nodeLoc(attr),
                            "unexpected attribute '{s}'",
                            .{astgen.tree.nodeLoc(attr).slice(astgen.tree.source)},
                            null,
                        );
                        return error.AnalysisFail;
                    },
                }
            }
        }

        const name = try astgen.addString(member_name_loc.slice(astgen.tree.source));
        astgen.instructions.items[member] = .{
            .struct_member = .{
                .name = name,
                .type = member_type,
                .@"align" = @"align",
                .size = size,
                .builtin = builtin,
                .location = location,
                .interpolate = interpolate,
            },
        };
        try astgen.scratch.append(astgen.allocator, member);
    }

    const name_str = astgen.tree.declNameLoc(node).?.slice(astgen.tree.source);
    const name = try astgen.addString(name_str);
    const member_list = try astgen.addRefList(astgen.scratch.items[scratch_top..]);

    astgen.instructions.items[struct_decl] = .{
        .@"struct" = .{
            .name = name,
            .members = member_list,
        },
    };
    return struct_decl;
}

fn genFnDecl(astgen: *AstGen, global_scope: *Scope, node: NodeIndex) !InstIndex {
    const fn_decl = try astgen.allocInst();
    const fn_proto = astgen.tree.extraData(Node.FnProto, astgen.tree.nodeLHS(node));

    var scope = try astgen.scope_pool.create();
    scope.* = .{ .tag = .func, .parent = global_scope };

    var params: u32 = 0;
    if (fn_proto.params != null_node) {
        params = try astgen.getFnParams(scope, fn_proto.params);
    }

    var return_type = null_inst;
    var return_attrs = Inst.FnDecl.ReturnAttrs{
        .builtin = .none,
        .location = null_inst,
        .interpolate = null,
        .invariant = false,
    };
    if (fn_proto.return_type != null_node) {
        return_type = try astgen.genType(scope, fn_proto.return_type);

        if (fn_proto.return_attrs != null_node) {
            for (astgen.tree.spanToList(fn_proto.return_attrs)) |attr| {
                switch (astgen.tree.nodeTag(attr)) {
                    .attr_invariant => return_attrs.invariant = true,
                    .attr_location => return_attrs.location = try astgen.attrLocation(scope, attr),
                    .attr_builtin => return_attrs.builtin = astgen.attrBuiltin(attr),
                    .attr_interpolate => return_attrs.interpolate = astgen.attrInterpolate(attr),
                    else => {
                        try astgen.errors.add(
                            astgen.tree.nodeLoc(attr),
                            "unexpected attribute '{s}'",
                            .{astgen.tree.nodeLoc(attr).slice(astgen.tree.source)},
                            null,
                        );
                        return error.AnalysisFail;
                    },
                }
            }
        }
    }

    var stage: Inst.FnDecl.Stage = .normal;
    var workgroup_size_attr = null_node;
    var is_const = false;
    if (fn_proto.attrs != null_node) {
        for (astgen.tree.spanToList(fn_proto.attrs)) |attr| {
            switch (astgen.tree.nodeTag(attr)) {
                .attr_vertex,
                .attr_fragment,
                .attr_compute,
                => |stage_attr| {
                    if (stage != .normal) {
                        try astgen.errors.add(astgen.tree.nodeLoc(attr), "multiple shader stages", .{}, null);
                        return error.AnalysisFail;
                    }

                    stage = switch (stage_attr) {
                        .attr_vertex => .vertex,
                        .attr_fragment => .fragment,
                        .attr_compute => .{ .compute = undefined },
                        else => unreachable,
                    };
                },
                .attr_workgroup_size => workgroup_size_attr = attr,
                .attr_const => is_const = true,
                else => {
                    try astgen.errors.add(
                        astgen.tree.nodeLoc(attr),
                        "unexpected attribute '{s}'",
                        .{astgen.tree.nodeLoc(attr).slice(astgen.tree.source)},
                        null,
                    );
                    return error.AnalysisFail;
                },
            }
        }
    }

    if (stage == .compute) {
        if (return_type != null_inst) {
            try astgen.errors.add(
                astgen.tree.nodeLoc(fn_proto.return_type),
                "return type on compute function",
                .{},
                null,
            );
            return error.AnalysisFail;
        }

        if (workgroup_size_attr == null_node) {
            try astgen.errors.add(
                astgen.tree.nodeLoc(node),
                "@workgroup_size not specified on compute shader",
                .{},
                null,
            );
            return error.AnalysisFail;
        }

        const workgroup_size_data = astgen.tree.extraData(Ast.Node.WorkgroupSize, astgen.tree.nodeLHS(workgroup_size_attr));
        stage.compute = Inst.FnDecl.Stage.WorkgroupSize{
            .x = blk: {
                const x = try astgen.genExpr(scope, workgroup_size_data.x);
                if (astgen.resolveConstExpr(x) == null) {
                    try astgen.errors.add(
                        astgen.tree.nodeLoc(workgroup_size_data.x),
                        "expected const-expression",
                        .{},
                        null,
                    );
                    return error.AnalysisFail;
                }
                break :blk x;
            },
            .y = blk: {
                const y = try astgen.genExpr(scope, workgroup_size_data.y);
                if (astgen.resolveConstExpr(y) == null) {
                    try astgen.errors.add(
                        astgen.tree.nodeLoc(workgroup_size_data.y),
                        "expected const-expression",
                        .{},
                        null,
                    );
                    return error.AnalysisFail;
                }
                break :blk y;
            },
            .z = blk: {
                const z = try astgen.genExpr(scope, workgroup_size_data.z);
                if (astgen.resolveConstExpr(z) == null) {
                    try astgen.errors.add(
                        astgen.tree.nodeLoc(workgroup_size_data.z),
                        "expected const-expression",
                        .{},
                        null,
                    );
                    return error.AnalysisFail;
                }
                break :blk z;
            },
        };
    } else if (workgroup_size_attr != null_node) {
        try astgen.errors.add(
            astgen.tree.nodeLoc(node),
            "@workgroup_size must be specified with a compute shader",
            .{},
            null,
        );
        return error.AnalysisFail;
    }

    var statements: u32 = 0;
    if (astgen.tree.nodeRHS(node) != null_node) {
        statements = try astgen.genStatements(scope, astgen.tree.nodeRHS(node));
    }

    const name_loc = astgen.tree.declNameLoc(node).?;
    const name = try astgen.addString(name_loc.slice(astgen.tree.source));
    astgen.instructions.items[fn_decl] = .{
        .fn_decl = .{
            .name = name,
            .stage = stage,
            .is_const = is_const,
            .params = params,
            .return_type = return_type,
            .return_attrs = return_attrs,
            .statements = statements,
        },
    };
    return fn_decl;
}

fn genTypeAlias(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    return astgen.genType(scope, node_lhs);
}

fn getFnParams(astgen: *AstGen, scope: *Scope, node: NodeIndex) !u32 {
    const scratch_top = astgen.scratch.items.len;
    defer astgen.scratch.shrinkRetainingCapacity(scratch_top);

    for (astgen.tree.spanToList(node)) |param_node| {
        const param = try astgen.allocInst();
        const param_node_lhs = astgen.tree.nodeLHS(param_node);
        const param_name_loc = astgen.tree.tokenLoc(astgen.tree.nodeToken(param_node));
        const param_type_node = astgen.tree.nodeRHS(param_node);
        const param_type = astgen.genType(scope, param_type_node) catch |err| switch (err) {
            error.AnalysisFail => continue,
            error.OutOfMemory => return error.OutOfMemory,
        };

        var builtin = Inst.Builtin.none;
        var inter: ?Inst.Interpolate = null;
        var location = null_inst;
        var invariant = false;

        if (param_node_lhs != null_node) {
            for (astgen.tree.spanToList(param_node_lhs)) |attr| {
                switch (astgen.tree.nodeTag(attr)) {
                    .attr_invariant => invariant = true,
                    .attr_location => location = try astgen.attrLocation(scope, attr),
                    .attr_builtin => builtin = astgen.attrBuiltin(attr),
                    .attr_interpolate => inter = astgen.attrInterpolate(attr),
                    else => {
                        try astgen.errors.add(
                            astgen.tree.nodeLoc(attr),
                            "unexpected attribute '{s}'",
                            .{astgen.tree.nodeLoc(attr).slice(astgen.tree.source)},
                            null,
                        );
                        return error.AnalysisFail;
                    },
                }
            }
        }

        const name = try astgen.addString(param_name_loc.slice(astgen.tree.source));
        astgen.instructions.items[param] = .{
            .fn_param = .{
                .name = name,
                .type = param_type,
                .builtin = builtin,
                .interpolate = inter,
                .location = location,
                .invariant = invariant,
            },
        };
        try astgen.scratch.append(astgen.allocator, param);
    }

    return astgen.addRefList(astgen.scratch.items[scratch_top..]);
}

fn attrBinding(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    const node_lhs_loc = astgen.tree.nodeLoc(node_lhs);
    const binding = try astgen.genExpr(scope, node_lhs);

    if (astgen.resolveConstExpr(binding) == null) {
        try astgen.errors.add(
            node_lhs_loc,
            "expected const-expression, found '{s}'",
            .{node_lhs_loc.slice(astgen.tree.source)},
            null,
        );
        return error.AnalysisFail;
    }

    const binding_res = try astgen.resolve(binding);
    const is_integer = if (binding_res) |res| astgen.getInst(res) == .integer else false;
    if (!is_integer) {
        try astgen.errors.add(
            node_lhs_loc,
            "binding value must be integer",
            .{},
            null,
        );
        return error.AnalysisFail;
    }

    if (astgen.getInst(binding_res.?).integer.value < 0) {
        try astgen.errors.add(
            node_lhs_loc,
            "binding value must be a positive",
            .{},
            null,
        );
        return error.AnalysisFail;
    }

    return binding;
}

fn attrGroup(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    const node_lhs_loc = astgen.tree.nodeLoc(node_lhs);
    const group = try astgen.genExpr(scope, node_lhs);

    if (astgen.resolveConstExpr(group) == null) {
        try astgen.errors.add(
            node_lhs_loc,
            "expected const-expression, found '{s}'",
            .{node_lhs_loc.slice(astgen.tree.source)},
            null,
        );
        return error.AnalysisFail;
    }

    const group_res = try astgen.resolve(group);
    const is_integer = if (group_res) |res| astgen.getInst(res) == .integer else false;
    if (!is_integer) {
        try astgen.errors.add(
            node_lhs_loc,
            "group value must be integer",
            .{},
            null,
        );
        return error.AnalysisFail;
    }

    if (astgen.getInst(group_res.?).integer.value < 0) {
        try astgen.errors.add(
            node_lhs_loc,
            "group value must be a positive",
            .{},
            null,
        );
        return error.AnalysisFail;
    }

    return group;
}

fn attrAlign(astgen: *AstGen, scope: *Scope, node: NodeIndex) !u29 {
    const expr = try astgen.genExpr(scope, astgen.tree.nodeLHS(node));
    if (astgen.resolveConstExpr(expr)) |expr_res| {
        if (expr_res == .integer) {
            return @intCast(u29, expr_res.integer);
        }
    }

    try astgen.errors.add(
        astgen.tree.nodeLoc(astgen.tree.nodeLHS(node)),
        "expected integer const-expression",
        .{},
        null,
    );
    return error.AnalysisFail;
}

fn attrSize(astgen: *AstGen, scope: *Scope, node: NodeIndex) !u32 {
    const expr = try astgen.genExpr(scope, astgen.tree.nodeLHS(node));
    if (astgen.resolveConstExpr(expr)) |expr_res| {
        if (expr_res == .integer) {
            return @intCast(u32, expr_res.integer);
        }
    }

    try astgen.errors.add(
        astgen.tree.nodeLoc(astgen.tree.nodeLHS(node)),
        "expected integer const-expression",
        .{},
        null,
    );
    return error.AnalysisFail;
}

fn attrLocation(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    return astgen.genExpr(scope, astgen.tree.nodeLHS(node));
}

fn attrBuiltin(astgen: *AstGen, node: NodeIndex) Inst.Builtin {
    const builtin_loc = astgen.tree.tokenLoc(astgen.tree.nodeLHS(node));
    const builtin_ast = stringToEnum(Ast.Builtin, builtin_loc.slice(astgen.tree.source)).?;
    return Inst.Builtin.fromAst(builtin_ast);
}

fn attrInterpolate(astgen: *AstGen, node: NodeIndex) Inst.Interpolate {
    const inter_type_loc = astgen.tree.tokenLoc(astgen.tree.nodeLHS(node));
    const inter_type_ast = stringToEnum(Ast.InterpolationType, inter_type_loc.slice(astgen.tree.source)).?;

    var inter = Inst.Interpolate{
        .type = switch (inter_type_ast) {
            .perspective => .perspective,
            .linear => .linear,
            .flat => .flat,
        },
        .sample = .none,
    };

    if (astgen.tree.nodeRHS(node) != null_node) {
        const inter_sample_loc = astgen.tree.tokenLoc(astgen.tree.nodeRHS(node));
        const inter_sample_ast = stringToEnum(Ast.InterpolationSample, inter_sample_loc.slice(astgen.tree.source)).?;
        inter.sample = switch (inter_sample_ast) {
            .center => .center,
            .centroid => .centroid,
            .sample => .sample,
        };
    }

    return inter;
}

fn genStatements(astgen: *AstGen, scope: *Scope, node: NodeIndex) !u32 {
    const scratch_top = astgen.scratch.items.len;
    defer astgen.scratch.shrinkRetainingCapacity(scratch_top);

    for (astgen.tree.spanToList(node)) |stmnt_node| {
        const stmnt_inst = switch (astgen.tree.nodeTag(stmnt_node)) {
            .compound_assign => try astgen.genCompoundAssign(scope, stmnt_node),
            else => continue, // TODO
        };
        try astgen.scratch.append(astgen.allocator, stmnt_inst);
    }

    return astgen.addRefList(astgen.scratch.items[scratch_top..]);
}

fn genCompoundAssign(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const inst = try astgen.allocInst();
    const node_lhs = astgen.tree.nodeLHS(node);
    const node_rhs = astgen.tree.nodeRHS(node);
    const lhs = try astgen.genExpr(scope, node_lhs);
    const rhs = try astgen.genExpr(scope, node_rhs);
    const lhs_type = try astgen.resolveSymbol(lhs);
    const rhs_type = try astgen.resolve(rhs);

    if (!astgen.eql(lhs_type.?, rhs_type.?)) {
        try astgen.errors.add(
            astgen.tree.nodeLoc(node),
            "type mismatch",
            .{},
            null,
        );
        return error.AnalysisFail;
    }

    const inst_data: Inst = switch (astgen.tree.tokenTag(astgen.tree.nodeToken(node))) {
        .equal => .{ .assign = .{ .lhs = lhs, .rhs = rhs } },
        .plus_equal => .{ .assign_add = .{ .lhs = lhs, .rhs = rhs } },
        .minus_equal => .{ .assign_sub = .{ .lhs = lhs, .rhs = rhs } },
        .asterisk_equal => .{ .assign_mul = .{ .lhs = lhs, .rhs = rhs } },
        .slash_equal => .{ .assign_div = .{ .lhs = lhs, .rhs = rhs } },
        .percent_equal => .{ .assign_mod = .{ .lhs = lhs, .rhs = rhs } },
        .ampersand_equal => .{ .assign_and = .{ .lhs = lhs, .rhs = rhs } },
        .pipe_equal => .{ .assign_or = .{ .lhs = lhs, .rhs = rhs } },
        .xor_equal => .{ .assign_xor = .{ .lhs = lhs, .rhs = rhs } },
        .angle_bracket_angle_bracket_left_equal => .{ .assign_shl = .{ .lhs = lhs, .rhs = rhs } },
        .angle_bracket_angle_bracket_right_equal => .{ .assign_shr = .{ .lhs = lhs, .rhs = rhs } },
        else => unreachable,
    };
    astgen.instructions.items[inst] = inst_data;
    return inst;
}

fn genExpr(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_tag = astgen.tree.nodeTag(node);
    switch (node_tag) {
        .number => return astgen.genNumber(node),
        .true => return astgen.addInst(.true),
        .false => return astgen.addInst(.false),
        .not => return astgen.genNot(scope, node),
        .negate => return astgen.genNegate(scope, node),
        .deref => return astgen.genDeref(scope, node),
        .addr_of => return astgen.genAddrOf(scope, node),
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
        => return astgen.genBinary(scope, node),
        .index_access => return astgen.genIndexAccess(scope, node),
        .field_access => return astgen.genFieldAccess(scope, node),
        .call => return astgen.genCall(scope, node),
        .bitcast => return astgen.genBitcast(scope, node),
        .ident => return astgen.genVarRef(scope, node),
        else => unreachable,
    }
}

fn genNumber(astgen: *AstGen, node: NodeIndex) !InstIndex {
    const node_loc = astgen.tree.nodeLoc(node);
    const bytes = node_loc.slice(astgen.tree.source);

    var i: usize = 0;
    var suffix: u8 = 0;
    var base: u8 = 10;
    var exponent = false;
    var dot = false;

    if (bytes.len >= 2 and bytes[0] == '0') switch (bytes[1]) {
        '0'...'9' => {
            try astgen.errors.add(node_loc, "leading zero disallowed", .{}, null);
            return error.AnalysisFail;
        },
        'x', 'X' => {
            i = 2;
            base = 16;
        },
        else => {},
    };

    while (i < bytes.len) : (i += 1) {
        const c = bytes[i];
        switch (c) {
            'f', 'h' => suffix = c,
            'i', 'u' => {
                if (dot or suffix == 'f' or suffix == 'h' or exponent) {
                    try astgen.errors.add(node_loc, "suffix '{c}' on float literal", .{c}, null);
                    return error.AnalysisFail;
                }

                suffix = c;
            },
            'e', 'E', 'p', 'P' => {
                if (exponent) {
                    try astgen.errors.add(node_loc, "duplicate exponent '{c}'", .{c}, null);
                    return error.AnalysisFail;
                }

                exponent = true;
            },
            '.' => dot = true,
            else => {},
        }
    }

    var inst: Inst = undefined;
    if (dot or exponent or suffix == 'f' or suffix == 'h') {
        if (base == 16) {
            // TODO
            try astgen.errors.add(node_loc, "hexadecimal float literals not implemented", .{}, null);
            return error.AnalysisFail;
        }

        const value = std.fmt.parseFloat(f64, bytes[0 .. bytes.len - @boolToInt(suffix != 0)]) catch |err| {
            try astgen.errors.add(
                node_loc,
                "cannot parse float literal ({s})",
                .{@errorName(err)},
                try astgen.errors.createNote(
                    null,
                    "this is a bug in dusk. please report it",
                    .{},
                ),
            );
            return error.AnalysisFail;
        };

        inst = .{
            .float = .{
                .value = value,
                .base = base,
                .tag = switch (suffix) {
                    0 => .none,
                    'f' => .f,
                    'h' => .h,
                    else => unreachable,
                },
            },
        };
    } else {
        const value = std.fmt.parseInt(i64, bytes[0 .. bytes.len - @boolToInt(suffix != 0)], 0) catch |err| {
            try astgen.errors.add(
                node_loc,
                "cannot parse integer literal ({s})",
                .{@errorName(err)},
                try astgen.errors.createNote(
                    null,
                    "this is a bug in dusk. please report it",
                    .{},
                ),
            );
            return error.AnalysisFail;
        };

        inst = .{
            .integer = .{
                .value = value,
                .base = base,
                .tag = switch (suffix) {
                    0 => .none,
                    'i' => .i,
                    'u' => .u,
                    else => unreachable,
                },
            },
        };
    }
    return astgen.addInst(inst);
}

fn genNot(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    const node_lhs_loc = astgen.tree.nodeLoc(node_lhs);
    const lhs = try astgen.genExpr(scope, node_lhs);

    if (try astgen.resolve(lhs)) |lhs_res| {
        switch (astgen.getInst(lhs_res)) {
            .bool_type, .true, .false => {
                return astgen.addInst(.{ .not = lhs });
            },
            else => {},
        }
    }

    try astgen.errors.add(
        node_lhs_loc,
        "cannot operate not (!) on '{s}'",
        .{node_lhs_loc.slice(astgen.tree.source)},
        null,
    );
    return error.AnalysisFail;
}

fn genNegate(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    const node_lhs_loc = astgen.tree.nodeLoc(node_lhs);
    const lhs = try astgen.genExpr(scope, node_lhs);

    if (try astgen.resolve(lhs)) |lhs_res| {
        switch (astgen.getInst(lhs_res)) {
            .u32_type,
            .i32_type,
            .f32_type,
            .f16_type,
            .integer,
            .float,
            => return astgen.addInst(.{ .negate = lhs }),
            else => {},
        }
    }

    try astgen.errors.add(
        node_lhs_loc,
        "cannot negate '{s}'",
        .{node_lhs_loc.slice(astgen.tree.source)},
        null,
    );
    return error.AnalysisFail;
}

fn genDeref(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    const node_lhs_loc = astgen.tree.nodeLoc(node_lhs);
    const lhs = try astgen.genExpr(scope, node_lhs);
    if (try astgen.resolveSymbol(lhs)) |lhs_res| {
        if (astgen.getInst(lhs_res) == .ptr_type) {
            const inst = try astgen.addInst(.{ .deref = lhs });
            return inst;
        } else {
            try astgen.errors.add(
                node_lhs_loc,
                "cannot dereference non-pointer variable '{s}'",
                .{node_lhs_loc.slice(astgen.tree.source)},
                null,
            );
            return error.AnalysisFail;
        }
    }

    try astgen.errors.add(
        node_lhs_loc,
        "cannot dereference '{s}'",
        .{node_lhs_loc.slice(astgen.tree.source)},
        null,
    );
    return error.AnalysisFail;
}

fn genAddrOf(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const inst = try astgen.addInst(.{
        .addr_of = try astgen.genExpr(scope, astgen.tree.nodeLHS(node)),
    });
    return inst;
}

fn genBinary(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const inst = try astgen.allocInst();
    const node_tag = astgen.tree.nodeTag(node);
    const node_loc = astgen.tree.nodeLoc(node);
    const node_lhs = astgen.tree.nodeLHS(node);
    const node_rhs = astgen.tree.nodeRHS(node);
    const node_lhs_loc = astgen.tree.nodeLoc(node_lhs);
    const node_rhs_loc = astgen.tree.nodeLoc(node_rhs);
    const lhs = try astgen.genExpr(scope, node_lhs);
    const rhs = try astgen.genExpr(scope, node_rhs);

    const lhs_res = try astgen.resolve(lhs) orelse {
        try astgen.errors.add(
            node_lhs_loc,
            "invalid operation with '{s}'",
            .{node_lhs_loc.slice(astgen.tree.source)},
            null,
        );
        return error.AnalysisFail;
    };
    const rhs_res = try astgen.resolve(rhs) orelse {
        try astgen.errors.add(
            node_rhs_loc,
            "invalid operation with '{s}'",
            .{node_rhs_loc.slice(astgen.tree.source)},
            null,
        );
        return error.AnalysisFail;
    };
    const lhs_res_tag = astgen.getInst(lhs_res);
    const rhs_res_tag = astgen.getInst(rhs_res);

    var is_valid = false;
    switch (node_tag) {
        .shift_left, .shift_right, .@"and", .@"or", .xor => {
            switch (lhs_res_tag) {
                .u32_type, .i32_type, .integer => switch (rhs_res_tag) {
                    .u32_type, .i32_type, .integer => {
                        is_valid = true;
                    },
                    else => {},
                },
                else => {},
            }
        },
        .logical_and, .logical_or => {
            switch (lhs_res_tag) {
                .bool_type, .true, .false => switch (rhs_res_tag) {
                    .bool_type, .true, .false => {
                        is_valid = true;
                    },
                    else => {},
                },
                else => {},
            }
        },
        else => {
            switch (lhs_res_tag) {
                .u32_type,
                .i32_type,
                .f32_type,
                .f16_type,
                .integer,
                .float,
                => switch (rhs_res_tag) {
                    .u32_type,
                    .i32_type,
                    .f32_type,
                    .f16_type,
                    .integer,
                    .float,
                    => {
                        is_valid = true;
                    },
                    else => {},
                },
                else => {},
            }
        },
    }

    if (!is_valid) {
        try astgen.errors.add(node_loc, "invalid operation", .{}, null);
        return error.AnalysisFail;
    }

    const inst_data: Inst = switch (node_tag) {
        .mul => .{ .mul = .{ .lhs = lhs, .rhs = rhs } },
        .div => .{ .div = .{ .lhs = lhs, .rhs = rhs } },
        .mod => .{ .mod = .{ .lhs = lhs, .rhs = rhs } },
        .add => .{ .add = .{ .lhs = lhs, .rhs = rhs } },
        .sub => .{ .sub = .{ .lhs = lhs, .rhs = rhs } },
        .shift_left => .{ .shift_left = .{ .lhs = lhs, .rhs = rhs } },
        .shift_right => .{ .shift_right = .{ .lhs = lhs, .rhs = rhs } },
        .@"and" => .{ .@"and" = .{ .lhs = lhs, .rhs = rhs } },
        .@"or" => .{ .@"or" = .{ .lhs = lhs, .rhs = rhs } },
        .xor => .{ .xor = .{ .lhs = lhs, .rhs = rhs } },
        .logical_and => .{ .logical_and = .{ .lhs = lhs, .rhs = rhs } },
        .logical_or => .{ .logical_or = .{ .lhs = lhs, .rhs = rhs } },
        .equal => .{ .equal = .{ .lhs = lhs, .rhs = rhs } },
        .not_equal => .{ .not_equal = .{ .lhs = lhs, .rhs = rhs } },
        .less_than => .{ .less_than = .{ .lhs = lhs, .rhs = rhs } },
        .less_than_equal => .{ .less_than_equal = .{ .lhs = lhs, .rhs = rhs } },
        .greater_than => .{ .greater_than = .{ .lhs = lhs, .rhs = rhs } },
        .greater_than_equal => .{ .greater_than_equal = .{ .lhs = lhs, .rhs = rhs } },
        else => unreachable,
    };
    astgen.instructions.items[inst] = inst_data;
    return inst;
}

fn genCall(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const inst = try astgen.allocInst();
    const token = astgen.tree.nodeToken(node);
    const token_tag = astgen.tree.tokenTag(token);
    const token_loc = astgen.tree.tokenLoc(token);
    const node_lhs = astgen.tree.nodeLHS(node);
    const node_rhs = astgen.tree.nodeRHS(node);
    const node_loc = astgen.tree.nodeLoc(node);

    astgen.instructions.items[inst] = switch (token_tag) {
        .k_bool => if (node_lhs == null_inst) .false else unreachable,
        .k_u32 => if (node_lhs == null_inst) .{ .integer = .{ .value = 0, .base = 10, .tag = .u } } else unreachable,
        .k_i32 => if (node_lhs == null_inst) .{ .integer = .{ .value = 0, .base = 10, .tag = .i } } else unreachable,
        .k_f32 => if (node_lhs == null_inst) .{ .float = .{ .value = 0, .base = 10, .tag = .f } } else unreachable,
        .k_f16 => if (node_lhs == null_inst) .{ .float = .{ .value = 0, .base = 10, .tag = .h } } else unreachable,
        .k_vec2, .k_vec3, .k_vec4 => if (node_lhs == null_inst) .{
            .vector = .{
                .value = .{ 0, 0, 0, 0 },
                .type = if (node_rhs != null_inst)
                    try astgen.genVectorType(scope, node_rhs)
                else
                    try astgen.addInst(.{
                        .vector_type = .{
                            .size = switch (token_tag) {
                                .k_vec2 => .two,
                                .k_vec3 => .three,
                                .k_vec4 => .four,
                                else => unreachable,
                            },
                            .elem_type = try astgen.addInst(.u32_type), // TODO: AbstractInt!,
                        },
                    }),
            },
        } else unreachable,
        .k_mat2x2,
        .k_mat2x3,
        .k_mat2x4,
        .k_mat3x2,
        .k_mat3x3,
        .k_mat3x4,
        .k_mat4x2,
        .k_mat4x3,
        .k_mat4x4,
        => if (node_lhs == null_inst) .{
            .matrix = .{
                .value = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
                .type = if (node_rhs != null_inst)
                    try astgen.genMatrixType(scope, node_rhs)
                else
                    try astgen.addInst(.{
                        .matrix_type = .{
                            .cols = switch (token_tag) {
                                .k_mat2x2, .k_mat2x3, .k_mat2x4 => .two,
                                .k_mat3x2, .k_mat3x3, .k_mat3x4 => .three,
                                .k_mat4x2, .k_mat4x3, .k_mat4x4 => .four,
                                else => unreachable,
                            },
                            .rows = switch (token_tag) {
                                .k_mat2x2, .k_mat3x2, .k_mat4x2 => .two,
                                .k_mat2x3, .k_mat3x3, .k_mat4x3 => .three,
                                .k_mat2x4, .k_mat3x4, .k_mat4x4 => .four,
                                else => unreachable,
                            },
                            .elem_type = try astgen.addInst(.u32_type), // TODO: AbstractInt!,
                        },
                    }),
            },
        } else unreachable,
        .ident => {
            const func = try astgen.findSymbol(scope, token);
            if (astgen.getInst(func) == .fn_decl) {
                const scratch_top = astgen.scratch.items.len;
                defer astgen.scratch.shrinkRetainingCapacity(scratch_top);

                if (node_lhs != null_node) {
                    for (astgen.tree.spanToList(node_lhs)) |arg_node| {
                        const arg = try astgen.genExpr(scope, arg_node);
                        try astgen.scratch.append(astgen.allocator, arg);
                    }
                }

                const args = try astgen.addRefList(astgen.scratch.items[scratch_top..]);
                astgen.instructions.items[inst] = .{ .call = .{ .@"fn" = func, .args = args } };
                return inst;
            } else {
                try astgen.errors.add(
                    node_loc,
                    "'{s}' cannot be called",
                    .{token_loc.slice(astgen.tree.source)},
                    null,
                );
                return error.AnalysisFail;
            }
        },
        else => unreachable,
    };

    return inst;
}

fn genBitcast(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    const node_rhs = astgen.tree.nodeRHS(node);
    const node_lhs_loc = astgen.tree.nodeLoc(node_lhs);
    const node_rhs_loc = astgen.tree.nodeLoc(node_rhs);
    const lhs = try astgen.genType(scope, node_lhs);
    const lhs_inst = astgen.getInst(lhs);
    const rhs = try astgen.genExpr(scope, node_rhs);
    const rhs_res = try astgen.resolve(rhs) orelse unreachable;
    const rhs_res_inst = astgen.getInst(rhs_res);
    var result_type = null_inst;

    switch (lhs_inst) {
        .u32_type,
        .i32_type,
        .f32_type,
        => {
            switch (rhs_res_inst) {
                .u32_type,
                .i32_type,
                .f32_type,
                => {
                    // bitcast<T>(T) -> T
                    // bitcast<T>(S) -> T
                    result_type = lhs;
                },
                .vector_type => |rhs_vector_type| {
                    if (rhs_vector_type.size == .two and
                        astgen.getInst(rhs_vector_type.elem_type) == .f16_type)
                    {
                        // bitcast<T>(vec2<f16>) -> T
                        result_type = lhs;
                    }
                },
                else => {},
            }
        },
        .vector_type => |lhs_vector_type| {
            switch (rhs_res_inst) {
                .u32_type,
                .i32_type,
                .f32_type,
                => {
                    if (lhs_vector_type.size == .two and
                        astgen.getInst(lhs_vector_type.elem_type) == .f16_type)
                    {
                        // bitcast<vec2<f16>>(T) -> vec2<f16>
                        result_type = lhs;
                    }
                },
                .vector_type => |rhs_vector_type| {
                    const rhs_vec_type = astgen.getInst(rhs_vector_type.elem_type);
                    switch (astgen.getInst(lhs_vector_type.elem_type)) {
                        .u32_type, .i32_type, .f32_type => switch (rhs_vec_type) {
                            .u32_type, .i32_type, .f32_type => {
                                if (lhs_vector_type.size == rhs_vector_type.size) {
                                    if (lhs_vector_type.elem_type == rhs_vector_type.elem_type) {
                                        // bitcast<vecN<T>>(vecN<T>) -> vecN<T>
                                        result_type = lhs;
                                    } else {
                                        // bitcast<vecN<T>>(vecN<S>) -> T
                                        result_type = lhs_vector_type.elem_type;
                                    }
                                }
                            },
                            .f16_type => {
                                if (lhs_vector_type.size == .two and
                                    rhs_vector_type.size == .four)
                                {
                                    // bitcast<vec2<T>>(vec4<f16>) -> vec2<T>
                                    result_type = lhs;
                                }
                            },
                            else => {},
                        },
                        .f16_type => switch (rhs_vec_type) {
                            .u32_type, .i32_type, .f32_type => {
                                if (rhs_vector_type.size == .two and
                                    lhs_vector_type.size == .four)
                                {
                                    // bitcast<vec4<f16>>(vec2<T>) -> vec4<f16>
                                    result_type = lhs;
                                }
                            },
                            else => {},
                        },
                        else => {},
                    }
                },
                else => {},
            }
        },
        else => {},
    }

    if (result_type != null_inst) {
        const inst = try astgen.addInst(.{
            .bitcast = .{
                .type = lhs,
                .expr = rhs,
                .result_type = result_type,
            },
        });
        return inst;
    }

    try astgen.errors.add(
        node_rhs_loc,
        "cannot cast '{s}' into '{s}'",
        .{ node_rhs_loc.slice(astgen.tree.source), node_lhs_loc.slice(astgen.tree.source) },
        null,
    );
    return error.AnalysisFail;
}

fn genVarRef(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const inst = try astgen.addInst(.{
        .var_ref = try astgen.findSymbol(scope, astgen.tree.nodeToken(node)),
    });
    return inst;
}

fn genIndexAccess(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const base = try astgen.genExpr(scope, astgen.tree.nodeLHS(node));
    const base_type = try astgen.resolveSymbol(base) orelse {
        try astgen.errors.add(
            astgen.tree.nodeLoc(astgen.tree.nodeLHS(node)),
            "expected array type",
            .{},
            null,
        );
        return error.AnalysisFail;
    };

    if (astgen.getInst(base_type) != .array_type) {
        try astgen.errors.add(
            astgen.tree.nodeLoc(astgen.tree.nodeRHS(node)),
            "cannot access index of a non-array variable",
            .{},
            null,
        );
        return error.AnalysisFail;
    }

    const rhs = try astgen.genExpr(scope, astgen.tree.nodeRHS(node));
    if (try astgen.resolve(rhs)) |rhs_res| {
        switch (astgen.getInst(rhs_res)) {
            .u32_type,
            .i32_type,
            .integer,
            => {
                const inst = try astgen.addInst(.{
                    .index_access = .{
                        .base = base,
                        .elem_type = astgen.getInst(base_type).array_type.elem_type,
                        .index = rhs,
                    },
                });
                return inst;
            },
            else => {},
        }
    }

    try astgen.errors.add(
        astgen.tree.nodeLoc(astgen.tree.nodeRHS(node)),
        "index must be an integer",
        .{},
        null,
    );
    return error.AnalysisFail;
}

fn genFieldAccess(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const base = try astgen.genExpr(scope, astgen.tree.nodeLHS(node));
    const base_type = try astgen.resolveSymbol(base) orelse {
        try astgen.errors.add(
            astgen.tree.nodeLoc(node),
            "expected struct type",
            .{},
            null,
        );
        return error.AnalysisFail;
    };

    if (astgen.getInst(base_type) != .struct_ref) {
        try astgen.errors.add(
            astgen.tree.nodeLoc(node),
            "expected struct type",
            .{},
            null,
        );
        return error.AnalysisFail;
    }

    const base_struct = astgen.getInst(base_type).struct_ref;
    const struct_members = astgen.getInst(base_struct).@"struct".members;
    for (std.mem.sliceTo(astgen.refs.items[struct_members..], null_inst)) |member| {
        const member_data = astgen.getInst(member).struct_member;
        if (std.mem.eql(
            u8,
            astgen.tree.tokenLoc(astgen.tree.nodeRHS(node)).slice(astgen.tree.source),
            std.mem.sliceTo(astgen.strings.items[member_data.name..], 0),
        )) {
            const inst = try astgen.addInst(.{
                .field_access = .{
                    .base = base,
                    .field = member,
                    .name = member_data.name,
                },
            });
            return inst;
        }
    }

    try astgen.errors.add(
        astgen.tree.nodeLoc(node),
        "struct '{s}' has no member named '{s}'",
        .{
            std.mem.sliceTo(astgen.strings.items[astgen.getInst(base_struct).@"struct".name..], 0),
            astgen.tree.tokenLoc(astgen.tree.nodeRHS(node)).slice(astgen.tree.source),
        },
        null,
    );
    return error.AnalysisFail;
}

fn genType(astgen: *AstGen, scope: *Scope, node: NodeIndex) error{ AnalysisFail, OutOfMemory }!InstIndex {
    return switch (astgen.tree.nodeTag(node)) {
        .bool_type => try astgen.addInst(.bool_type),
        .number_type => try astgen.genNumberType(node),
        .vector_type => try astgen.genVectorType(scope, node),
        .matrix_type => try astgen.genMatrixType(scope, node),
        .atomic_type => try astgen.genAtomicType(scope, node),
        .array_type => try astgen.genArrayType(scope, node),
        .ptr_type => try astgen.genPtrType(scope, node),
        .sampler_type => try astgen.genSamplerType(node),
        .texture_type => try astgen.genTextureType(scope, node),
        .multisampled_texture_type => try astgen.genMultisampledTextureType(scope, node),
        .storage_texture_type => try astgen.genStorageTextureType(node),
        .depth_texture_type => try astgen.genDepthTextureType(node),
        .external_texture_type => try astgen.addInst(.external_texture_type),
        .ident => {
            const node_loc = astgen.tree.nodeLoc(node);
            const decl = try astgen.findSymbol(scope, astgen.tree.nodeToken(node));
            switch (astgen.getInst(decl)) {
                .true,
                .false,
                .bool_type,
                .i32_type,
                .u32_type,
                .f32_type,
                .f16_type,
                .vector_type,
                .matrix_type,
                .atomic_type,
                .array_type,
                .ptr_type,
                .sampler_type,
                .comparison_sampler_type,
                .external_texture_type,
                .texture_type,
                .multisampled_texture_type,
                .storage_texture_type,
                .depth_texture_type,
                .struct_ref,
                => return decl,
                else => {},
            }

            if (astgen.getInst(decl) == .@"struct") {
                return astgen.addInst(.{ .struct_ref = decl });
            } else {
                try astgen.errors.add(
                    node_loc,
                    "'{s}' is not a type",
                    .{node_loc.slice(astgen.tree.source)},
                    null,
                );
                return error.AnalysisFail;
            }
        },
        else => unreachable,
    };
}

fn genNumberType(astgen: *AstGen, node: NodeIndex) !InstIndex {
    const token = astgen.tree.nodeToken(node);
    const token_tag = astgen.tree.tokenTag(token);
    return astgen.addInst(switch (token_tag) {
        .k_i32 => .i32_type,
        .k_u32 => .u32_type,
        .k_f32 => .f32_type,
        .k_f16 => .f16_type,
        else => unreachable,
    });
}

fn genVectorType(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const vector_type = try astgen.allocInst();
    const elem_type_node = astgen.tree.nodeLHS(node);
    const elem_type = try astgen.genType(scope, elem_type_node);

    switch (astgen.getInst(elem_type)) {
        .bool_type,
        .u32_type,
        .i32_type,
        .f32_type,
        .f16_type,
        => {
            const token_tag = astgen.tree.tokenTag(astgen.tree.nodeToken(node));
            astgen.instructions.items[vector_type] = .{
                .vector_type = .{
                    .size = switch (token_tag) {
                        .k_vec2 => .two,
                        .k_vec3 => .three,
                        .k_vec4 => .four,
                        else => unreachable,
                    },
                    .elem_type = elem_type,
                },
            };
            return vector_type;
        },
        else => {
            try astgen.errors.add(
                astgen.tree.nodeLoc(elem_type_node),
                "invalid vector component type",
                .{},
                try astgen.errors.createNote(
                    null,
                    "must be 'i32', 'u32', 'f32', 'f16' or 'bool'",
                    .{},
                ),
            );
            return error.AnalysisFail;
        },
    }
}

fn genMatrixType(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const inst = try astgen.allocInst();
    const elem_type_node = astgen.tree.nodeLHS(node);
    const elem_type = try astgen.genType(scope, elem_type_node);

    switch (astgen.getInst(elem_type)) {
        .u32_type, .i32_type => {
            const token_tag = astgen.tree.tokenTag(astgen.tree.nodeToken(node));
            astgen.instructions.items[inst] = .{
                .matrix_type = .{
                    .cols = switch (token_tag) {
                        .k_mat2x2, .k_mat2x3, .k_mat2x4 => .two,
                        .k_mat3x2, .k_mat3x3, .k_mat3x4 => .three,
                        .k_mat4x2, .k_mat4x3, .k_mat4x4 => .four,
                        else => unreachable,
                    },
                    .rows = switch (token_tag) {
                        .k_mat2x2, .k_mat3x2, .k_mat4x2 => .two,
                        .k_mat2x3, .k_mat3x3, .k_mat4x3 => .three,
                        .k_mat2x4, .k_mat3x4, .k_mat4x4 => .four,
                        else => unreachable,
                    },
                    .elem_type = elem_type,
                },
            };
            return inst;
        },
        else => {
            try astgen.errors.add(
                astgen.tree.nodeLoc(elem_type_node),
                "invalid matrix component type",
                .{},
                try astgen.errors.createNote(
                    null,
                    "must be 'f32' or 'f16'",
                    .{},
                ),
            );
            return error.AnalysisFail;
        },
    }
}

fn genAtomicType(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    std.debug.assert(astgen.tree.nodeTag(node) == .atomic_type);

    const inst = try astgen.allocInst();
    const elem_type_node = astgen.tree.nodeLHS(node);
    const elem_type = try astgen.genType(scope, elem_type_node);

    switch (astgen.getInst(elem_type)) {
        .u32_type, .i32_type => {
            astgen.instructions.items[inst] = .{ .atomic_type = .{ .elem_type = elem_type } };
            return inst;
        },
        else => {
            try astgen.errors.add(
                astgen.tree.nodeLoc(elem_type_node),
                "invalid atomic component type",
                .{},
                try astgen.errors.createNote(
                    null,
                    "must be 'i32' or 'u32'",
                    .{},
                ),
            );
            return error.AnalysisFail;
        },
    }
}

fn genPtrType(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const inst = try astgen.allocInst();
    const elem_type_node = astgen.tree.nodeLHS(node);
    const elem_type = try astgen.genType(scope, elem_type_node);

    switch (astgen.getInst(elem_type)) {
        .bool_type,
        .u32_type,
        .i32_type,
        .f32_type,
        .f16_type,
        .sampler_type,
        .comparison_sampler_type,
        .external_texture_type,
        => {
            const extra_data = astgen.tree.extraData(Node.PtrType, astgen.tree.nodeRHS(node));

            const addr_space_loc = astgen.tree.tokenLoc(extra_data.addr_space);
            const ast_addr_space = stringToEnum(Ast.AddressSpace, addr_space_loc.slice(astgen.tree.source)).?;
            const addr_space: Inst.PointerType.AddressSpace = switch (ast_addr_space) {
                .function => .function,
                .private => .private,
                .workgroup => .workgroup,
                .uniform => .uniform,
                .storage => .storage,
            };

            var access_mode: Inst.PointerType.AccessMode = .none;
            if (extra_data.access_mode != null_node) {
                const access_mode_loc = astgen.tree.tokenLoc(extra_data.access_mode);
                const ast_access_mode = stringToEnum(Ast.AccessMode, access_mode_loc.slice(astgen.tree.source)).?;
                access_mode = switch (ast_access_mode) {
                    .read => .read,
                    .write => .write,
                    .read_write => .read_write,
                };
            }

            astgen.instructions.items[inst] = .{
                .ptr_type = .{
                    .elem_type = elem_type,
                    .addr_space = addr_space,
                    .access_mode = access_mode,
                },
            };

            return inst;
        },
        else => {},
    }

    try astgen.errors.add(
        astgen.tree.nodeLoc(elem_type_node),
        "invalid pointer component type",
        .{},
        null,
    );
    return error.AnalysisFail;
}

fn genArrayType(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const inst = try astgen.allocInst();
    const elem_type_node = astgen.tree.nodeLHS(node);
    const elem_type = try astgen.genType(scope, elem_type_node);

    switch (astgen.getInst(elem_type)) {
        .array_type,
        .vector_type,
        .matrix_type,
        .atomic_type,
        .struct_ref,
        .u32_type,
        .i32_type,
        .f32_type,
        .f16_type,
        .bool_type,
        => {
            if (astgen.getInst(elem_type) == .array_type) {
                if (astgen.getInst(elem_type).array_type.size == null_inst) {
                    try astgen.errors.add(
                        astgen.tree.nodeLoc(elem_type_node),
                        "array componet type can not be a runtime-sized array",
                        .{},
                        null,
                    );
                    return error.AnalysisFail;
                }
            }

            const size_node = astgen.tree.nodeRHS(node);
            var size = null_inst;
            if (size_node != null_node) {
                size = try astgen.genExpr(scope, size_node);
            }

            astgen.instructions.items[inst] = .{
                .array_type = .{
                    .elem_type = elem_type,
                    .size = size,
                },
            };

            return inst;
        },
        else => {},
    }

    try astgen.errors.add(
        astgen.tree.nodeLoc(elem_type_node),
        "invalid array component type",
        .{},
        null,
    );
    return error.AnalysisFail;
}

fn genSamplerType(astgen: *AstGen, node: NodeIndex) !InstIndex {
    const token = astgen.tree.nodeToken(node);
    const token_tag = astgen.tree.tokenTag(token);
    return astgen.addInst(switch (token_tag) {
        .k_sampler => .sampler_type,
        .k_sampler_comparison => .comparison_sampler_type,
        else => unreachable,
    });
}

fn genTextureType(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const inst = try astgen.allocInst();
    const elem_type_node = astgen.tree.nodeLHS(node);
    const elem_type = try astgen.genType(scope, elem_type_node);

    switch (astgen.getInst(elem_type)) {
        .u32_type, .i32_type, .f32_type => {
            const token_tag = astgen.tree.tokenTag(astgen.tree.nodeToken(node));
            astgen.instructions.items[inst] = .{
                .texture_type = .{
                    .kind = switch (token_tag) {
                        .k_texture_1d => .@"1d",
                        .k_texture_2d => .@"2d",
                        .k_texture_2d_array => .@"2d_array",
                        .k_texture_3d => .@"3d",
                        .k_texture_cube => .cube,
                        .k_texture_cube_array => .cube_array,
                        else => unreachable,
                    },
                    .elem_type = elem_type,
                },
            };
            return inst;
        },
        else => {
            try astgen.errors.add(
                astgen.tree.nodeLoc(elem_type_node),
                "invalid texture component type",
                .{},
                try astgen.errors.createNote(
                    null,
                    "must be 'i32', 'u32' or 'f32'",
                    .{},
                ),
            );
            return error.AnalysisFail;
        },
    }
}

fn genMultisampledTextureType(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const inst = try astgen.allocInst();
    const elem_type_node = astgen.tree.nodeLHS(node);
    const elem_type = try astgen.genType(scope, elem_type_node);

    switch (astgen.getInst(elem_type)) {
        .u32_type, .i32_type, .f32_type => {
            const token_tag = astgen.tree.tokenTag(astgen.tree.nodeToken(node));
            astgen.instructions.items[inst] = .{
                .multisampled_texture_type = .{
                    .kind = switch (token_tag) {
                        .k_texture_multisampled_2d => .@"2d",
                        else => unreachable,
                    },
                    .elem_type = elem_type,
                },
            };
            return inst;
        },
        else => {
            try astgen.errors.add(
                astgen.tree.nodeLoc(elem_type_node),
                "invalid multisampled texture component type",
                .{},
                try astgen.errors.createNote(
                    null,
                    "must be 'i32', 'u32' or 'f32'",
                    .{},
                ),
            );
            return error.AnalysisFail;
        },
    }
}

fn genStorageTextureType(astgen: *AstGen, node: NodeIndex) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    const texel_format_loc = astgen.tree.nodeLoc(node_lhs);
    const ast_texel_format = stringToEnum(Ast.TexelFormat, texel_format_loc.slice(astgen.tree.source)).?;
    const texel_format: Inst.StorageTextureType.TexelFormat = switch (ast_texel_format) {
        .rgba8unorm => .rgba8unorm,
        .rgba8snorm => .rgba8snorm,
        .rgba8uint => .rgba8uint,
        .rgba8sint => .rgba8sint,
        .rgba16uint => .rgba16uint,
        .rgba16sint => .rgba16sint,
        .rgba16float => .rgba16float,
        .r32uint => .r32uint,
        .r32sint => .r32sint,
        .r32float => .r32float,
        .rg32uint => .rg32uint,
        .rg32sint => .rg32sint,
        .rg32float => .rg32float,
        .rgba32uint => .rgba32uint,
        .rgba32sint => .rgba32sint,
        .rgba32float => .rgba32float,
        .bgra8unorm => .bgra8unorm,
    };

    const node_rhs = astgen.tree.nodeRHS(node);
    const access_mode_loc = astgen.tree.nodeLoc(node_rhs);
    const access_mode_full = stringToEnum(Ast.AccessMode, access_mode_loc.slice(astgen.tree.source)).?;
    const access_mode = switch (access_mode_full) {
        .write => Inst.StorageTextureType.AccessMode.write,
        else => {
            try astgen.errors.add(
                access_mode_loc,
                "invalid access mode",
                .{},
                try astgen.errors.createNote(
                    null,
                    "only 'write' is allowed",
                    .{},
                ),
            );
            return error.AnalysisFail;
        },
    };

    const token_tag = astgen.tree.tokenTag(astgen.tree.nodeToken(node));
    const inst = try astgen.addInst(.{
        .storage_texture_type = .{
            .kind = switch (token_tag) {
                .k_texture_storage_1d => .@"1d",
                .k_texture_storage_2d => .@"2d",
                .k_texture_storage_2d_array => .@"2d_array",
                .k_texture_storage_3d => .@"3d",
                else => unreachable,
            },
            .texel_format = texel_format,
            .access_mode = access_mode,
        },
    });

    return inst;
}

fn genDepthTextureType(astgen: *AstGen, node: NodeIndex) !InstIndex {
    const token_tag = astgen.tree.tokenTag(astgen.tree.nodeToken(node));
    const inst = try astgen.addInst(.{
        .depth_texture_type = switch (token_tag) {
            .k_texture_depth_2d => .@"2d",
            .k_texture_depth_2d_array => .@"2d_array",
            .k_texture_depth_cube => .cube,
            .k_texture_depth_cube_array => .cube_array,
            .k_texture_depth_multisampled_2d => .multisampled_2d,
            else => unreachable,
        },
    });
    return inst;
}

/// takes token and returns the first declaration in the current and parent scopes
fn findSymbol(astgen: *AstGen, scope: *Scope, token: TokenIndex) error{ OutOfMemory, AnalysisFail }!InstIndex {
    std.debug.assert(astgen.tree.tokenTag(token) == .ident);

    const loc = astgen.tree.tokenLoc(token);
    const name = loc.slice(astgen.tree.source);

    var s = scope;
    while (true) {
        var node_iter = s.decls.keyIterator();
        while (node_iter.next()) |other_node| {
            if (std.mem.eql(u8, name, astgen.tree.declNameLoc(other_node.*).?.slice(astgen.tree.source))) {
                return astgen.genGlobalDecl(s, other_node.*);
            }
        }

        if (s.tag == .root) {
            try astgen.errors.add(
                loc,
                "use of undeclared identifier '{s}'",
                .{name},
                null,
            );
            return error.AnalysisFail;
        }

        s = s.parent;
    }
}

fn resolve(astgen: *AstGen, _index: InstIndex) !?InstIndex {
    var in_deref = false;
    var in_decl = false;
    var index = _index;

    while (true) {
        const inst = astgen.getInst(index);
        switch (inst) {
            .bool_type,
            .i32_type,
            .u32_type,
            .f32_type,
            .f16_type,
            .vector_type,
            .matrix_type,
            .atomic_type,
            .array_type,
            .ptr_type,
            .sampler_type,
            .comparison_sampler_type,
            .external_texture_type,
            .texture_type,
            .multisampled_texture_type,
            .storage_texture_type,
            .depth_texture_type,
            .struct_ref,
            => if (in_decl) return index,

            .true,
            .false,
            .integer,
            .float,
            .vector,
            .matrix,
            => return index,

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
            => |bin| {
                index = bin.lhs; // TODO
            },

            .not, .negate => |un| {
                index = un;
            },

            .deref => {
                in_deref = true;
                index = inst.deref;
            },

            else => {
                if (try astgen.resolveSymbol(index)) |res| {
                    index = res;
                    in_decl = true;
                    if (in_deref) {
                        index = astgen.getInst(res).ptr_type.elem_type;
                    }
                } else {
                    return null;
                }
            },
        }
    }
}

fn resolveConstExpr(astgen: *AstGen, inst_idx: InstIndex) ?Value {
    const inst = astgen.getInst(inst_idx);
    switch (inst) {
        .true => return .{ .bool = true },
        .false => return .{ .bool = false },
        .integer => |integer| return .{ .integer = integer.value },
        .float => |float| return .{ .float = float.value },
        .negate, .not => |un| {
            const value = astgen.resolveConstExpr(un) orelse return null;
            return switch (inst) {
                .negate => value.negate(),
                .not => value.not(),
                else => unreachable,
            };
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
        .equal,
        .not_equal,
        .less_than,
        .less_than_equal,
        .greater_than,
        .greater_than_equal,
        .logical_and,
        .logical_or,
        => |bin| {
            const lhs = astgen.resolveConstExpr(bin.lhs) orelse return null;
            const rhs = astgen.resolveConstExpr(bin.rhs) orelse return null;
            return switch (inst) {
                .mul => lhs.mul(rhs),
                .div => lhs.div(rhs),
                .mod => lhs.mod(rhs),
                .add => lhs.add(rhs),
                .sub => lhs.sub(rhs),
                .shift_left => lhs.shiftLeft(rhs),
                .shift_right => lhs.shiftRight(rhs),
                .@"and" => lhs.bitwiseAnd(rhs),
                .@"or" => lhs.bitwiseOr(rhs),
                .xor => lhs.bitwiseXor(rhs),
                .equal => lhs.equal(rhs),
                .not_equal => lhs.notEqual(rhs),
                .less_than => lhs.lessThan(rhs),
                .greater_than => lhs.greaterThan(rhs),
                .less_than_equal => lhs.lessThanEqual(rhs),
                .greater_than_equal => lhs.greaterThanEqual(rhs),
                .logical_and => lhs.logicalAnd(rhs),
                .logical_or => lhs.logicalOr(rhs),
                else => unreachable,
            };
        },
        .var_ref => |var_ref| {
            const res = try astgen.resolveSymbol(var_ref) orelse return null;
            return astgen.resolveConstExpr(res);
        },
        else => return null,
    }
}

/// expects a var_ref index_access, field_access, global_variable_decl or global_const
fn resolveSymbol(astgen: *AstGen, inst_idx: InstIndex) !?InstIndex {
    const inst = astgen.getInst(inst_idx);
    switch (inst) {
        .index_access => |index_access| return index_access.elem_type,
        .field_access => |field_access| return astgen.getInst(field_access.field).struct_member.type,
        .call => |call| return astgen.resolveSymbol(call.@"fn"),
        .fn_decl => |func| return func.return_type,
        .var_ref => |var_ref| return astgen.resolveSymbol(var_ref),
        .global_variable_decl => |global_variable_decl| {
            const decl_type = global_variable_decl.type;
            if (decl_type != null_inst) {
                return decl_type;
            } else {
                if (astgen.getInst(global_variable_decl.expr) == .var_ref) {
                    return astgen.resolveSymbol(global_variable_decl.expr);
                }
                return global_variable_decl.expr;
            }
        },
        .global_const => |global_const| {
            const decl_type = global_const.type;
            if (decl_type != null_inst) {
                return decl_type;
            } else {
                if (astgen.getInst(global_const.expr) == .var_ref) {
                    return astgen.resolveSymbol(global_const.expr);
                }
                return global_const.expr;
            }
        },
        else => return null,
    }
}

pub fn eql(astgen: *AstGen, a_idx: InstIndex, b_idx: InstIndex) bool {
    const a = astgen.getInst(a_idx);
    const b = astgen.getInst(b_idx);

    return switch (a) {
        .bool_type, .true, .false => switch (b) {
            .bool_type, .true, .false => true,
            else => false,
        },
        .integer, .u32_type, .i32_type => switch (b) {
            .integer, .u32_type, .i32_type => true,
            else => false,
        },
        .float, .f32_type, .f16_type => switch (b) {
            .float, .f32_type, .f16_type => true,
            else => false,
        },
        .vector => |vec_a| switch (b) {
            .vector => |vec_b| astgen.eqlVector(vec_a.type, vec_b.type),
            .vector_type => astgen.eqlVector(vec_a.type, b_idx),
            else => false,
        },
        .vector_type => switch (b) {
            .vector => |vec_b| astgen.eqlVector(a_idx, vec_b.type),
            .vector_type => astgen.eqlVector(a_idx, b_idx),
            else => false,
        },
        .matrix => |mat_a| switch (b) {
            .matrix => |mat_b| astgen.eqlMatrix(mat_a.type, mat_b.type),
            .matrix_type => astgen.eqlMatrix(mat_a.type, b_idx),
            else => false,
        },
        .matrix_type => switch (b) {
            .matrix => |mat_b| astgen.eqlMatrix(a_idx, mat_b.type),
            .matrix_type => astgen.eqlMatrix(a_idx, b_idx),
            else => false,
        },
        else => if (std.meta.activeTag(a) == std.meta.activeTag(b)) true else false,
    };
}

pub fn eqlVector(astgen: *AstGen, a_idx: InstIndex, b_idx: InstIndex) bool {
    const a = astgen.getInst(a_idx).vector_type;
    const b = astgen.getInst(b_idx).vector_type;
    return a.size == b.size and astgen.eql(a.elem_type, b.elem_type);
}

pub fn eqlMatrix(astgen: *AstGen, a_idx: InstIndex, b_idx: InstIndex) bool {
    const a = astgen.getInst(a_idx).matrix_type;
    const b = astgen.getInst(b_idx).matrix_type;
    return a.cols == b.cols and a.rows == b.rows and astgen.eql(a.elem_type, b.elem_type);
}

fn allocInst(astgen: *AstGen) error{OutOfMemory}!InstIndex {
    try astgen.instructions.append(astgen.allocator, undefined);
    return @intCast(InstIndex, astgen.instructions.items.len - 1);
}

fn addInst(astgen: *AstGen, inst: Inst) error{OutOfMemory}!InstIndex {
    try astgen.instructions.append(astgen.allocator, inst);
    return @intCast(InstIndex, astgen.instructions.items.len - 1);
}

fn addRefList(astgen: *AstGen, list: []const InstIndex) error{OutOfMemory}!u32 {
    const len = list.len + 1;
    try astgen.refs.ensureUnusedCapacity(astgen.allocator, len);
    astgen.refs.appendSliceAssumeCapacity(list);
    astgen.refs.appendAssumeCapacity(null_inst);
    return @intCast(u32, astgen.refs.items.len - len);
}

fn addString(astgen: *AstGen, str: []const u8) error{OutOfMemory}!u32 {
    const len = str.len + 1;
    try astgen.strings.ensureUnusedCapacity(astgen.allocator, len);
    astgen.strings.appendSliceAssumeCapacity(str);
    astgen.strings.appendAssumeCapacity(0);
    return @intCast(u32, astgen.strings.items.len - len);
}

fn getInst(astgen: *AstGen, inst: InstIndex) Inst {
    return astgen.instructions.items[inst];
}

const Value = union(enum) {
    integer: i64,
    float: f64,
    bool: bool,

    fn negate(unary: Value) Value {
        return switch (unary) {
            .integer => .{ .integer = -unary.integer },
            .float => .{ .float = -unary.float },
            .bool => unreachable,
        };
    }

    fn not(unary: Value) Value {
        return switch (unary) {
            .bool => .{ .bool = !unary.bool },
            .integer, .float => unreachable,
        };
    }

    fn mul(lhs: Value, rhs: Value) Value {
        return switch (lhs) {
            .integer => .{ .integer = lhs.integer * rhs.integer },
            .float => .{ .float = lhs.float * rhs.float },
            .bool => unreachable,
        };
    }

    fn div(lhs: Value, rhs: Value) Value {
        return switch (lhs) {
            .integer => .{ .integer = @divExact(lhs.integer, rhs.integer) },
            .float => .{ .float = lhs.float / rhs.float },
            .bool => unreachable,
        };
    }

    fn mod(lhs: Value, rhs: Value) Value {
        return switch (lhs) {
            .integer => .{ .integer = @rem(lhs.integer, rhs.integer) },
            .float => .{ .float = @rem(lhs.float, rhs.float) },
            .bool => unreachable,
        };
    }

    fn add(lhs: Value, rhs: Value) Value {
        return switch (lhs) {
            .integer => .{ .integer = lhs.integer + rhs.integer },
            .float => .{ .float = lhs.float + rhs.float },
            .bool => unreachable,
        };
    }

    fn sub(lhs: Value, rhs: Value) Value {
        return switch (lhs) {
            .integer => .{ .integer = lhs.integer - rhs.integer },
            .float => .{ .float = lhs.float - rhs.float },
            .bool => unreachable,
        };
    }

    fn shiftLeft(lhs: Value, rhs: Value) Value {
        return switch (lhs) {
            .integer => .{ .integer = lhs.integer << @intCast(u6, rhs.integer) },
            .float, .bool => unreachable,
        };
    }

    fn shiftRight(lhs: Value, rhs: Value) Value {
        return switch (lhs) {
            .integer => .{ .integer = lhs.integer >> @intCast(u6, rhs.integer) },
            .float, .bool => unreachable,
        };
    }

    fn bitwiseAnd(lhs: Value, rhs: Value) Value {
        return switch (lhs) {
            .integer => .{ .integer = lhs.integer & rhs.integer },
            .float, .bool => unreachable,
        };
    }

    fn bitwiseOr(lhs: Value, rhs: Value) Value {
        return switch (lhs) {
            .integer => .{ .integer = lhs.integer | rhs.integer },
            .float, .bool => unreachable,
        };
    }

    fn bitwiseXor(lhs: Value, rhs: Value) Value {
        return switch (lhs) {
            .integer => .{ .integer = lhs.integer ^ rhs.integer },
            .float, .bool => unreachable,
        };
    }

    fn equal(lhs: Value, rhs: Value) Value {
        return switch (lhs) {
            .integer => .{ .bool = lhs.integer == rhs.integer },
            .float => .{ .bool = lhs.float == rhs.float },
            .bool => unreachable,
        };
    }

    fn notEqual(lhs: Value, rhs: Value) Value {
        return switch (lhs) {
            .integer => .{ .bool = lhs.integer != rhs.integer },
            .float => .{ .bool = lhs.float != rhs.float },
            .bool => unreachable,
        };
    }

    fn lessThan(lhs: Value, rhs: Value) Value {
        return switch (lhs) {
            .integer => .{ .bool = lhs.integer < rhs.integer },
            .float => .{ .bool = lhs.float < rhs.float },
            .bool => unreachable,
        };
    }

    fn greaterThan(lhs: Value, rhs: Value) Value {
        return switch (lhs) {
            .integer => .{ .bool = lhs.integer > rhs.integer },
            .float => .{ .bool = lhs.float > rhs.float },
            .bool => unreachable,
        };
    }

    fn lessThanEqual(lhs: Value, rhs: Value) Value {
        return switch (lhs) {
            .integer => .{ .bool = lhs.integer <= rhs.integer },
            .float => .{ .bool = lhs.float <= rhs.float },
            .bool => unreachable,
        };
    }

    fn greaterThanEqual(lhs: Value, rhs: Value) Value {
        return switch (lhs) {
            .integer => .{ .bool = lhs.integer >= rhs.integer },
            .float => .{ .bool = lhs.float >= rhs.float },
            .bool => unreachable,
        };
    }

    fn logicalAnd(lhs: Value, rhs: Value) Value {
        return switch (lhs) {
            .bool => .{ .bool = lhs.bool and rhs.bool },
            .integer, .float => unreachable,
        };
    }

    fn logicalOr(lhs: Value, rhs: Value) Value {
        return switch (lhs) {
            .bool => .{ .bool = lhs.bool or rhs.bool },
            .integer, .float => unreachable,
        };
    }
};
