const std = @import("std");
const Ast = @import("Ast.zig");
const Air = @import("Air.zig");
const ErrorList = @import("ErrorList.zig");
const Node = Ast.Node;
const NodeIndex = Ast.NodeIndex;
const TokenIndex = Ast.TokenIndex;
const null_node = Ast.null_node;
const stringToEnum = std.meta.stringToEnum;

const AstGen = @This();

allocator: std.mem.Allocator,
tree: *const Ast,
instructions: std.ArrayListUnmanaged(Air.Inst) = .{},
refs: std.ArrayListUnmanaged(Air.Inst.Ref) = .{},
strings: std.ArrayListUnmanaged(u8) = .{},
scratch: std.ArrayListUnmanaged(Air.Inst.Ref) = .{},
errors: ErrorList,
scope_pool: std.heap.MemoryPool(Scope),

pub const Scope = struct {
    tag: Tag,
    /// this is undefined if tag == .root
    parent: *Scope,
    decls: std.AutoHashMapUnmanaged(NodeIndex, error{AnalysisFail}!Air.Inst.Ref) = .{},

    pub const Tag = enum {
        root,
        func,
        block,
    };
};

pub fn genTranslationUnit(self: *AstGen) !u32 {
    const scratch_top = self.scratch.items.len;
    defer self.scratch.shrinkRetainingCapacity(scratch_top);

    var root_scope = try self.scope_pool.create();
    root_scope.* = .{ .tag = .root, .parent = undefined };

    const global_nodes = self.tree.spanToList(0);
    self.scanDecls(root_scope, global_nodes) catch |err| switch (err) {
        error.AnalysisFail => return self.addRefList(self.scratch.items[scratch_top..]),
        error.OutOfMemory => return error.OutOfMemory,
    };

    for (global_nodes) |node| {
        const global = self.genDecl(root_scope, node) catch |err| switch (err) {
            error.AnalysisFail => continue,
            error.OutOfMemory => return error.OutOfMemory,
        };
        try self.scratch.append(self.allocator, global);
    }

    return self.addRefList(self.scratch.items[scratch_top..]);
}

fn genDecl(self: *AstGen, scope: *Scope, node: NodeIndex) !Air.Inst.Ref {
    const ref = try scope.decls.get(node).?;
    if (ref != .none) {
        // the declaration has already analysed
        return ref;
    }

    const decl = switch (self.tree.nodeTag(node)) {
        .global_var => self.genGlobalVariable(scope, node),
        .global_const => self.genGlobalConstDecl(scope, node),
        .@"struct" => self.genStruct(scope, node),
        .function => self.genFnDecl(scope, node),
        .type_alias => self.genTypeAlias(scope, node),
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

/// adds `decls` to scope and checks for re-declarations
fn scanDecls(self: *AstGen, scope: *Scope, decls: []const NodeIndex) !void {
    std.debug.assert(scope.decls.count() == 0);

    for (decls) |decl| {
        const loc = self.tree.declNameLoc(decl).?;
        const name = loc.slice(self.tree.source);

        var iter = scope.decls.keyIterator();
        while (iter.next()) |node| {
            const name_loc = self.tree.declNameLoc(node.*).?;
            if (std.mem.eql(u8, name, name_loc.slice(self.tree.source))) {
                try self.errors.add(
                    loc,
                    "redeclaration of '{s}'",
                    .{name},
                    try self.errors.createNote(
                        name_loc,
                        "other declaration here",
                        .{},
                    ),
                );
                return error.AnalysisFail;
            }
        }

        try scope.decls.putNoClobber(self.scope_pool.arena.allocator(), decl, .none);
    }
}

fn genTypeAlias(self: *AstGen, scope: *Scope, node: NodeIndex) !Air.Inst.Ref {
    const node_lhs = self.tree.nodeLHS(node);
    return self.genType(scope, node_lhs);
}

fn genGlobalConstDecl(self: *AstGen, scope: *Scope, node: NodeIndex) !Air.Inst.Ref {
    const inst = try self.allocInst();
    const node_lhs = self.tree.nodeLHS(node);
    const node_rhs = self.tree.nodeRHS(node);
    const name_loc = self.tree.declNameLoc(node).?;

    var var_type = Air.Inst.Ref.none;
    if (node_lhs != null_node) {
        var_type = try self.genType(scope, node_lhs);
    }

    const expr = try self.genExpr(scope, node_rhs);
    if (!self.isConstExpr(expr)) {
        try self.errors.add(
            name_loc,
            "value of '{s}' must be a const-expression",
            .{name_loc.slice(self.tree.source)},
            null,
        );
        return error.AnalysisFail;
    }

    const name_index = try self.addString(name_loc.slice(self.tree.source));
    self.instructions.items[inst] = .{
        .tag = .global_const_decl,
        .data = .{
            .global_const_decl = .{
                .name = name_index,
                .type = var_type,
                .expr = expr,
            },
        },
    };
    return indexToRef(inst);
}

// TODO
fn isConstExpr(self: *AstGen, expr: Air.Inst.Ref) bool {
    _ = self;
    _ = expr;
    return true;
}

fn genGlobalVariable(self: *AstGen, scope: *Scope, node: NodeIndex) !Air.Inst.Ref {
    const inst = try self.allocInst();
    const node_rhs = self.tree.nodeRHS(node);
    const extra_data = self.tree.extraData(Node.GlobalVarDecl, self.tree.nodeLHS(node));
    const name_loc = self.tree.declNameLoc(node).?;

    var var_type = Air.Inst.Ref.none;
    if (extra_data.type != null_node) {
        var_type = try self.genType(scope, extra_data.type);
    }

    var is_resource = false;
    if (var_type == .sampler_type or
        var_type == .comparison_sampler_type or
        var_type == .external_sampled_texture_type or
        self.refTagIs(var_type, &.{
        .sampled_texture_type,
        .multisampled_texture_type,
        .storage_texture_type,
        .depth_texture_type,
    })) {
        is_resource = true;
    }

    var addr_space: Air.Inst.GlobalVariableDecl.AddressSpace = .none;
    if (extra_data.addr_space != null_node) {
        const addr_space_loc = self.tree.tokenLoc(extra_data.addr_space);
        const ast_addr_space = stringToEnum(Ast.AddressSpace, addr_space_loc.slice(self.tree.source)).?;
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

    var access_mode: Air.Inst.GlobalVariableDecl.AccessMode = .none;
    if (extra_data.access_mode != null_node) {
        const access_mode_loc = self.tree.tokenLoc(extra_data.access_mode);
        const ast_access_mode = stringToEnum(Ast.AccessMode, access_mode_loc.slice(self.tree.source)).?;
        access_mode = switch (ast_access_mode) {
            .read => .read,
            .write => .write,
            .read_write => .read_write,
        };
    }

    var binding = Air.Inst.Ref.none;
    var group = Air.Inst.Ref.none;
    if (extra_data.attrs != null_node) {
        for (self.tree.spanToList(extra_data.attrs)) |attr| {
            const attr_node_lhs = self.tree.nodeLHS(attr);
            const attr_node_lhs_loc = self.tree.nodeLoc(attr_node_lhs);

            if (!is_resource) {
                try self.errors.add(
                    self.tree.nodeLoc(attr),
                    "variable '{s}' is not a resource",
                    .{name_loc.slice(self.tree.source)},
                    null,
                );
                return error.AnalysisFail;
            }

            switch (self.tree.nodeTag(attr)) {
                .attr_binding => {
                    binding = try self.genExpr(scope, attr_node_lhs);
                    const binding_res = try self.resolve(binding);

                    if (!self.isConstExpr(binding)) {
                        try self.errors.add(
                            attr_node_lhs_loc,
                            "expected const-expressions, found '{s}'",
                            .{attr_node_lhs_loc.slice(self.tree.source)},
                            null,
                        );
                        return error.AnalysisFail;
                    }

                    const is_integer = if (binding_res) |res| self.refTagIs(res, &.{.integer}) else false;
                    if (!is_integer) {
                        try self.errors.add(
                            attr_node_lhs_loc,
                            "binding value must be integer",
                            .{},
                            null,
                        );
                        return error.AnalysisFail;
                    }

                    const is_negative = self.getInst(binding_res.?).data.integer.value < 0;
                    if (is_negative) {
                        try self.errors.add(
                            attr_node_lhs_loc,
                            "binding value must be a positive",
                            .{},
                            null,
                        );
                        return error.AnalysisFail;
                    }
                },
                .attr_group => {
                    group = try self.genExpr(scope, attr_node_lhs);
                    const group_res = try self.resolve(group);

                    if (!self.isConstExpr(group)) {
                        try self.errors.add(
                            attr_node_lhs_loc,
                            "expected const-expressions, found '{s}'",
                            .{attr_node_lhs_loc.slice(self.tree.source)},
                            null,
                        );
                        return error.AnalysisFail;
                    }

                    const is_integer = if (group_res) |res| self.refTagIs(res, &.{.integer}) else false;
                    if (!is_integer) {
                        try self.errors.add(
                            attr_node_lhs_loc,
                            "group value must be integer",
                            .{},
                            null,
                        );
                        return error.AnalysisFail;
                    }

                    const is_negative = self.getInst(group_res.?).data.integer.value < 0;
                    if (is_negative) {
                        try self.errors.add(
                            attr_node_lhs_loc,
                            "group value must be a positive",
                            .{},
                            null,
                        );
                        return error.AnalysisFail;
                    }
                },
                else => {
                    try self.errors.add(
                        self.tree.nodeLoc(attr),
                        "unexpected attribute '{s}'",
                        .{self.tree.nodeLoc(attr).slice(self.tree.source)},
                        null,
                    );
                    return error.AnalysisFail;
                },
            }
        }
    }

    if (is_resource and (binding == .none or group == .none)) {
        try self.errors.add(
            self.tree.nodeLoc(node),
            "resource variable must specify binding and group",
            .{},
            null,
        );
        return error.AnalysisFail;
    }

    var expr = Air.Inst.Ref.none;
    if (node_rhs != null_node) {
        expr = try self.genExpr(scope, node_rhs);
    }

    const name_index = try self.addString(name_loc.slice(self.tree.source));
    self.instructions.items[inst] = .{
        .tag = .global_variable_decl,
        .data = .{
            .global_variable_decl = .{
                .name = name_index,
                .type = var_type,
                .addr_space = addr_space,
                .access_mode = access_mode,
                .binding = binding,
                .group = group,
                .expr = expr,
            },
        },
    };
    return indexToRef(inst);
}

fn genStruct(self: *AstGen, scope: *Scope, node: NodeIndex) !Air.Inst.Ref {
    const inst = try self.allocInst();

    const scratch_top = self.scratch.items.len;
    defer self.scratch.shrinkRetainingCapacity(scratch_top);

    const member_nodes_list = self.tree.spanToList(self.tree.nodeLHS(node));
    for (member_nodes_list, 0..) |member_node, i| {
        const member_inst = try self.allocInst();
        const member_name_loc = self.tree.tokenLoc(self.tree.nodeToken(member_node));
        const member_type_node = self.tree.nodeRHS(member_node);
        const member_type_loc = self.tree.nodeLoc(member_type_node);
        const member_type_ref = self.genType(scope, member_type_node) catch |err| switch (err) {
            error.AnalysisFail => continue,
            error.OutOfMemory => return error.OutOfMemory,
        };

        const is_valid_type =
            self.refTagIs(member_type_ref, &.{ .array_type, .vector_type, .matrix_type, .atomic_type, .struct_ref }) or
            member_type_ref.isNumberType() or
            member_type_ref == .bool_type;

        if (is_valid_type) {
            if (self.refTagIs(member_type_ref, &.{.array_type})) {
                const array_size = self.getInst(member_type_ref).data.array_type.size;
                if (array_size == .none and i + 1 != member_nodes_list.len) {
                    try self.errors.add(
                        member_name_loc,
                        "struct member with runtime-sized array type, must be the last member of the structure",
                        .{},
                        null,
                    );
                }
            }

            const name_index = try self.addString(member_name_loc.slice(self.tree.source));
            self.instructions.items[member_inst] = .{
                .tag = .struct_member,
                .data = .{
                    .struct_member = .{
                        .name = name_index,
                        .type = member_type_ref,
                        .@"align" = 0, // TODO
                    },
                },
            };
            try self.scratch.append(self.allocator, indexToRef(member_inst));
        } else {
            try self.errors.add(
                member_name_loc,
                "invalid struct member type '{s}'",
                .{member_type_loc.slice(self.tree.source)},
                null,
            );
        }
    }

    const name = self.tree.declNameLoc(node).?.slice(self.tree.source);
    const name_index = try self.addString(name);
    const member_list = try self.addRefList(self.scratch.items[scratch_top..]);

    self.instructions.items[inst] = .{
        .tag = .struct_decl,
        .data = .{
            .struct_decl = .{
                .name = name_index,
                .members = member_list,
            },
        },
    };
    return indexToRef(inst);
}

fn genFnDecl(self: *AstGen, global_scope: *Scope, node: NodeIndex) !Air.Inst.Ref {
    const inst = try self.allocInst();
    const fn_proto = self.tree.extraData(Node.FnProto, self.tree.nodeLHS(node));

    var scope = try self.scope_pool.create();
    scope.* = .{ .tag = .func, .parent = global_scope };

    var params: u32 = 0;
    if (fn_proto.params != 0) {
        params = try self.getFnParams(scope, fn_proto.params);
    }

    var return_type = Air.Inst.Ref.none;
    var return_attrs = Air.Inst.FnDecl.ReturnAttrs{};
    if (fn_proto.return_type != null_node) {
        return_type = try self.genType(scope, fn_proto.return_type);

        if (fn_proto.return_attrs != null_node) {
            for (self.tree.spanToList(fn_proto.return_attrs)) |attr| {
                switch (self.tree.nodeTag(attr)) {
                    .attr_invariant => return_attrs.invariant = true,
                    .attr_location => return_attrs.location = try self.genExpr(scope, self.tree.nodeLHS(attr)),
                    .attr_builtin => return_attrs.builtin = self.attrBuiltin(attr),
                    .attr_interpolate => return_attrs.interpolate = self.attrInterpolate(attr),
                    else => {
                        try self.errors.add(
                            self.tree.nodeLoc(attr),
                            "unexpected attribute '{s}'",
                            .{self.tree.nodeLoc(attr).slice(self.tree.source)},
                            null,
                        );
                        return error.AnalysisFail;
                    },
                }
            }
        }
    }

    var stage: Air.Inst.FnDecl.Stage = .normal;
    var workgroup_size_attr = null_node;
    if (fn_proto.attrs != null_node) {
        for (self.tree.spanToList(fn_proto.attrs)) |attr| {
            switch (self.tree.nodeTag(attr)) {
                .attr_vertex,
                .attr_fragment,
                .attr_compute,
                => |stage_attr| {
                    if (stage != .normal) {
                        try self.errors.add(self.tree.nodeLoc(attr), "multiple shader stages", .{}, null);
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
                else => {
                    try self.errors.add(
                        self.tree.nodeLoc(attr),
                        "unexpected attribute '{s}'",
                        .{self.tree.nodeLoc(attr).slice(self.tree.source)},
                        null,
                    );
                    return error.AnalysisFail;
                },
            }
        }
    }

    if (stage == .compute) {
        if (return_type != .none) {
            try self.errors.add(
                self.tree.nodeLoc(fn_proto.return_type),
                "return type on compute function",
                .{},
                null,
            );
            return error.AnalysisFail;
        }

        if (workgroup_size_attr == null_node) {
            try self.errors.add(
                self.tree.nodeLoc(node),
                "@workgroup_size not specified on compute shader",
                .{},
                null,
            );
            return error.AnalysisFail;
        }

        const workgroup_size_data = self.tree.extraData(Ast.Node.WorkgroupSize, self.tree.nodeLHS(workgroup_size_attr));
        var workgroup_size = Air.Inst.FnDecl.Stage.WorkgroupSize{
            .x = x: {
                const x = try self.genExpr(scope, workgroup_size_data.x);
                if (!self.isConstExpr(x)) {
                    try self.errors.add(
                        self.tree.nodeLoc(workgroup_size_data.x),
                        "expected const-expressions",
                        .{},
                        null,
                    );
                    return error.AnalysisFail;
                }
                break :x x;
            },
        };

        if (workgroup_size_data.y != null_node) {
            workgroup_size.y = try self.genExpr(scope, workgroup_size_data.y);
            if (!self.isConstExpr(workgroup_size.y)) {
                try self.errors.add(
                    self.tree.nodeLoc(workgroup_size_data.y),
                    "expected const-expressions",
                    .{},
                    null,
                );
                return error.AnalysisFail;
            }
        }

        if (workgroup_size_data.z != null_node) {
            workgroup_size.z = try self.genExpr(scope, workgroup_size_data.z);
            if (!self.isConstExpr(workgroup_size.z)) {
                try self.errors.add(
                    self.tree.nodeLoc(workgroup_size_data.z),
                    "expected const-expressions",
                    .{},
                    null,
                );
                return error.AnalysisFail;
            }
        }

        stage.compute = workgroup_size;
    } else if (workgroup_size_attr != null_node) {
        try self.errors.add(
            self.tree.nodeLoc(node),
            "@workgroup_size must be specified with a compute shader",
            .{},
            null,
        );
        return error.AnalysisFail;
    }

    var statements: u32 = 0;
    if (self.tree.nodeRHS(node) != null_node) {
        statements = try self.genStatements(scope, self.tree.nodeRHS(node));
    }

    const name_loc = self.tree.declNameLoc(node).?;
    const name_index = try self.addString(name_loc.slice(self.tree.source));
    self.instructions.items[inst] = .{
        .tag = .fn_decl,
        .data = .{
            .fn_decl = .{
                .name = name_index,
                .stage = stage,
                .params = params,
                .return_type = return_type,
                .return_attrs = return_attrs,
                .statements = statements,
            },
        },
    };
    return indexToRef(inst);
}

fn getFnParams(self: *AstGen, scope: *Scope, node: NodeIndex) !u32 {
    const scratch_top = self.scratch.items.len;
    defer self.scratch.shrinkRetainingCapacity(scratch_top);

    for (self.tree.spanToList(node)) |param_node| {
        const param_inst = try self.allocInst();
        const param_name_loc = self.tree.tokenLoc(self.tree.nodeToken(param_node));
        const param_type_node = self.tree.nodeRHS(param_node);
        const param_type_ref = self.genType(scope, param_type_node) catch |err| switch (err) {
            error.AnalysisFail => continue,
            error.OutOfMemory => return error.OutOfMemory,
        };

        var builtin = Air.Inst.BuiltinValue.none;
        var inter: ?Air.Inst.Interpolate = null;
        var location = Air.Inst.Ref.none;
        var invariant = false;

        if (self.tree.nodeLHS(param_node) != null_node) {
            for (self.tree.spanToList(self.tree.nodeLHS(param_node))) |attr| {
                switch (self.tree.nodeTag(attr)) {
                    .attr_invariant => invariant = true,
                    .attr_location => location = try self.genExpr(scope, self.tree.nodeLHS(attr)),
                    .attr_builtin => builtin = self.attrBuiltin(attr),
                    .attr_interpolate => inter = self.attrInterpolate(attr),
                    else => {
                        try self.errors.add(
                            self.tree.nodeLoc(attr),
                            "unexpected attribute '{s}'",
                            .{self.tree.nodeLoc(attr).slice(self.tree.source)},
                            null,
                        );
                        return error.AnalysisFail;
                    },
                }
            }
        }

        const name_index = try self.addString(param_name_loc.slice(self.tree.source));
        self.instructions.items[param_inst] = .{
            .tag = .fn_param,
            .data = .{
                .fn_param = .{
                    .name = name_index,
                    .type = param_type_ref,
                    .builtin = builtin,
                    .interpolate = inter,
                    .location = location,
                    .invariant = invariant,
                },
            },
        };
        try self.scratch.append(self.allocator, indexToRef(param_inst));
    }

    return self.addRefList(self.scratch.items[scratch_top..]);
}

fn attrBuiltin(self: *AstGen, node: Ast.NodeIndex) Air.Inst.BuiltinValue {
    const builtin_loc = self.tree.tokenLoc(self.tree.nodeLHS(node));
    const builtin_ast = stringToEnum(Ast.BuiltinValue, builtin_loc.slice(self.tree.source)).?;
    return Air.Inst.BuiltinValue.fromAst(builtin_ast);
}

fn attrInterpolate(self: *AstGen, node: Ast.NodeIndex) Air.Inst.Interpolate {
    const inter_type_loc = self.tree.tokenLoc(self.tree.nodeLHS(node));
    const inter_type_ast = stringToEnum(Ast.InterpolationType, inter_type_loc.slice(self.tree.source)).?;

    var inter = Air.Inst.Interpolate{
        .type = switch (inter_type_ast) {
            .perspective => .perspective,
            .linear => .linear,
            .flat => .flat,
        },
        .sample = .none,
    };

    if (self.tree.nodeRHS(node) != null_node) {
        const inter_sample_loc = self.tree.tokenLoc(self.tree.nodeRHS(node));
        const inter_sample_ast = stringToEnum(Ast.InterpolationSample, inter_sample_loc.slice(self.tree.source)).?;
        inter.sample = switch (inter_sample_ast) {
            .center => .center,
            .centroid => .centroid,
            .sample => .sample,
        };
    }

    return inter;
}

fn genStatements(self: *AstGen, scope: *Scope, node: NodeIndex) !u32 {
    const scratch_top = self.scratch.items.len;
    defer self.scratch.shrinkRetainingCapacity(scratch_top);

    for (self.tree.spanToList(node)) |stmnt_node| {
        const stmnt_inst = switch (self.tree.nodeTag(stmnt_node)) {
            .compound_assign => try self.genCompoundAssign(scope, stmnt_node),
            else => continue, // TODO
        };
        try self.scratch.append(self.allocator, stmnt_inst);
    }

    return self.addRefList(self.scratch.items[scratch_top..]);
}

fn genCompoundAssign(self: *AstGen, scope: *Scope, node: NodeIndex) !Air.Inst.Ref {
    const node_lhs = self.tree.nodeLHS(node);
    const node_rhs = self.tree.nodeRHS(node);
    const lhs = try self.genExpr(scope, node_lhs);
    const rhs = try self.genExpr(scope, node_rhs);
    const lhs_type = try self.resolveVar(lhs);
    const rhs_type = try self.resolve(rhs);

    if (!self.eqlType(lhs_type.?, rhs_type.?)) {
        try self.errors.add(
            self.tree.nodeLoc(node),
            "type mismatch",
            .{},
            null,
        );
        return error.AnalysisFail;
    }

    const tag: Air.Inst.Tag = switch (self.tree.tokenTag(self.tree.nodeToken(node))) {
        .equal => .assign,
        .plus_equal => .assign_add,
        .minus_equal => .assign_sub,
        .asterisk_equal => .assign_mul,
        .slash_equal => .assign_div,
        .percent_equal => .assign_mod,
        .ampersand_equal => .assign_and,
        .pipe_equal => .assign_or,
        .xor_equal => .assign_xor,
        .angle_bracket_angle_bracket_left_equal => .assign_shl,
        .angle_bracket_angle_bracket_right_equal => .assign_shr,
        else => unreachable,
    };
    const inst = try self.addInst(.{ .tag = tag, .data = .{ .binary = .{ .lhs = lhs, .rhs = rhs } } });
    return indexToRef(inst);
}

fn genExpr(self: *AstGen, scope: *Scope, node: NodeIndex) !Air.Inst.Ref {
    const node_tag = self.tree.nodeTag(node);
    switch (node_tag) {
        .number => return self.genNumber(node),
        .true => return .true,
        .false => return .false,
        .not => return self.genNot(scope, node),
        .negate => return self.genNegate(scope, node),
        .deref => return self.genDeref(scope, node),
        .addr_of => return self.genAddrOf(scope, node),
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
        => return self.genBinary(scope, node),
        .index_access => return self.genIndexAccess(scope, node),
        .field_access => return self.genFieldAccess(scope, node),
        .bitcast => return self.genBitcast(scope, node),
        .ident => return self.genVarRef(scope, node),
        // TODO: call expr
        else => unreachable,
    }
}

fn genNumber(self: *AstGen, node: NodeIndex) !Air.Inst.Ref {
    const node_loc = self.tree.nodeLoc(node);
    const bytes = node_loc.slice(self.tree.source);

    var i: usize = 0;
    var suffix: u8 = 0;
    var base: u8 = 10;
    var exponent = false;
    var dot = false;

    if (bytes.len >= 2 and bytes[0] == '0') switch (bytes[1]) {
        '0'...'9' => {
            try self.errors.add(node_loc, "leading zero disallowed", .{}, null);
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
                    try self.errors.add(node_loc, "suffix '{c}' on float literal", .{c}, null);
                    return error.AnalysisFail;
                }

                suffix = c;
            },
            'e', 'E', 'p', 'P' => {
                if (exponent) {
                    try self.errors.add(node_loc, "duplicate exponent '{c}'", .{c}, null);
                    return error.AnalysisFail;
                }

                exponent = true;
            },
            '.' => dot = true,
            else => {},
        }
    }

    var inst: Air.Inst = undefined;
    if (dot or exponent or suffix == 'f' or suffix == 'h') {
        if (base == 16) {
            // TODO
            try self.errors.add(node_loc, "hexadecimal float literals not implemented", .{}, null);
            return error.AnalysisFail;
        }

        const value = std.fmt.parseFloat(f64, bytes[0 .. bytes.len - @boolToInt(suffix != 0)]) catch |err| {
            try self.errors.add(
                node_loc,
                "cannot parse float literal ({s})",
                .{@errorName(err)},
                try self.errors.createNote(
                    null,
                    "this is a bug in dusk. please report it",
                    .{},
                ),
            );
            return error.AnalysisFail;
        };

        inst = .{
            .tag = .float,
            .data = .{
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
            },
        };
    } else {
        const value = std.fmt.parseInt(i64, bytes[0 .. bytes.len - @boolToInt(suffix != 0)], 0) catch |err| {
            try self.errors.add(
                node_loc,
                "cannot parse integer literal ({s})",
                .{@errorName(err)},
                try self.errors.createNote(
                    null,
                    "this is a bug in dusk. please report it",
                    .{},
                ),
            );
            return error.AnalysisFail;
        };

        inst = .{
            .tag = .integer,
            .data = .{
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
            },
        };
    }
    return indexToRef(try self.addInst(inst));
}

fn genNot(self: *AstGen, scope: *Scope, node: NodeIndex) !Air.Inst.Ref {
    const node_lhs = self.tree.nodeLHS(node);
    const node_lhs_loc = self.tree.nodeLoc(node_lhs);
    const lhs = try self.genExpr(scope, node_lhs);
    const lhs_res = try self.resolve(lhs);

    if (lhs_res != null and lhs_res.?.isBool()) {
        const inst_index = try self.addInst(.{ .tag = .not, .data = .{ .ref = lhs } });
        return indexToRef(inst_index);
    }

    try self.errors.add(
        node_lhs_loc,
        "cannot operate not (!) on '{s}'",
        .{node_lhs_loc.slice(self.tree.source)},
        null,
    );
    return error.AnalysisFail;
}

fn genNegate(self: *AstGen, scope: *Scope, node: NodeIndex) !Air.Inst.Ref {
    const node_lhs = self.tree.nodeLHS(node);
    const node_lhs_loc = self.tree.nodeLoc(node_lhs);
    const lhs = try self.genExpr(scope, node_lhs);

    if (try self.resolve(lhs)) |lhs_res| {
        if (lhs_res.isNumberType() or self.refTagIs(lhs_res, &.{ .integer, .float })) {
            const inst_index = try self.addInst(.{ .tag = .negate, .data = .{ .ref = lhs } });
            return indexToRef(inst_index);
        }
    }

    try self.errors.add(
        node_lhs_loc,
        "cannot negate '{s}'",
        .{node_lhs_loc.slice(self.tree.source)},
        null,
    );
    return error.AnalysisFail;
}

fn genDeref(self: *AstGen, scope: *Scope, node: NodeIndex) !Air.Inst.Ref {
    const node_lhs = self.tree.nodeLHS(node);
    const node_lhs_loc = self.tree.nodeLoc(node_lhs);
    const lhs = try self.genExpr(scope, node_lhs);
    if (try self.resolveVar(lhs)) |lhs_res| {
        if (self.refTagIs(lhs_res, &.{.ptr_type})) {
            const inst_index = try self.addInst(.{ .tag = .deref, .data = .{ .ref = lhs } });
            return indexToRef(inst_index);
        } else {
            try self.errors.add(
                node_lhs_loc,
                "cannot dereference non-pointer variable '{s}'",
                .{node_lhs_loc.slice(self.tree.source)},
                null,
            );
            return error.AnalysisFail;
        }
    }

    try self.errors.add(
        node_lhs_loc,
        "cannot dereference '{s}'",
        .{node_lhs_loc.slice(self.tree.source)},
        null,
    );
    return error.AnalysisFail;
}

fn genAddrOf(self: *AstGen, scope: *Scope, node: NodeIndex) !Air.Inst.Ref {
    const inst_index = try self.addInst(.{
        .tag = .addr_of,
        .data = .{
            .ref = try self.genExpr(scope, self.tree.nodeLHS(node)),
        },
    });
    return indexToRef(inst_index);
}

fn genBinary(self: *AstGen, scope: *Scope, node: NodeIndex) !Air.Inst.Ref {
    const node_tag = self.tree.nodeTag(node);
    const node_loc = self.tree.nodeLoc(node);
    const node_lhs = self.tree.nodeLHS(node);
    const node_rhs = self.tree.nodeRHS(node);
    const node_lhs_loc = self.tree.nodeLoc(node_lhs);
    const node_rhs_loc = self.tree.nodeLoc(node_rhs);
    const lhs = try self.genExpr(scope, node_lhs);
    const rhs = try self.genExpr(scope, node_rhs);
    const inst_tag: Air.Inst.Tag = switch (node_tag) {
        .mul => .mul,
        .div => .div,
        .mod => .mod,
        .add => .add,
        .sub => .sub,
        .shift_left => .shift_left,
        .shift_right => .shift_right,
        .@"and" => .@"and",
        .@"or" => .@"or",
        .xor => .xor,
        .logical_and => .logical_and,
        .logical_or => .logical_or,
        .equal => .equal,
        .not_equal => .not_equal,
        .less_than => .less_than,
        .less_than_equal => .less_than_equal,
        .greater_than => .greater_than,
        .greater_than_equal => .greater_than_equal,
        else => unreachable,
    };

    const lhs_res = try self.resolve(lhs) orelse {
        try self.errors.add(
            node_lhs_loc,
            "invalid operation with '{s}'",
            .{node_lhs_loc.slice(self.tree.source)},
            null,
        );
        return error.AnalysisFail;
    };
    const rhs_res = try self.resolve(rhs) orelse {
        try self.errors.add(
            node_rhs_loc,
            "invalid operation with '{s}'",
            .{node_rhs_loc.slice(self.tree.source)},
            null,
        );
        return error.AnalysisFail;
    };

    switch (inst_tag) {
        .logical_and,
        .logical_or,
        => {},
        else => {
            if (lhs_res.isBool() or rhs_res.isBool()) {
                try self.errors.add(
                    node_loc,
                    "'{s}' operation with boolean",
                    .{node_loc.slice(self.tree.source)},
                    null,
                );
                return error.AnalysisFail;
            }
        },
    }

    const inst_index = try self.addInst(.{
        .tag = inst_tag,
        .data = .{ .binary = .{ .lhs = lhs, .rhs = rhs } },
    });
    return indexToRef(inst_index);
}

fn genBitcast(self: *AstGen, scope: *Scope, node: NodeIndex) !Air.Inst.Ref {
    const node_lhs = self.tree.nodeLHS(node);
    const node_rhs = self.tree.nodeRHS(node);
    const node_lhs_loc = self.tree.nodeLoc(node_lhs);
    const node_rhs_loc = self.tree.nodeLoc(node_rhs);
    const lhs = try self.genType(scope, node_lhs);
    const rhs = try self.genExpr(scope, node_rhs);
    const rhs_res = try self.resolve(rhs) orelse unreachable;
    var result_type: ?Air.Inst.Ref = null;

    // bitcast<T>(T) -> T
    if (lhs.isNumberType() and lhs == rhs_res) {
        result_type = lhs;
    } else if (lhs.is32BitNumberType()) {
        // bitcast<T>(S) -> T
        if (rhs_res.is32BitNumberType() and lhs != rhs_res) {
            result_type = lhs;
        }
        // bitcast<T>(vec2<f16>) -> T
        else if (self.refTagIs(rhs_res, &.{.vector_type})) {
            const rhs_inst = self.getInst(rhs_res).data;

            if (rhs_inst.vector_type.size == .two and
                rhs_inst.vector_type.elem_type == .f16_type)
            {
                result_type = lhs;
            }
        }
    } else if (self.refTagIs(lhs, &.{.vector_type})) {
        const lhs_inst = self.getInst(lhs).data;

        // bitcast<vec2<f16>>(T) -> vec2<f16>
        if (lhs_inst.vector_type.size == .two and
            lhs_inst.vector_type.elem_type == .f16_type and
            rhs_res.is32BitNumberType())
        {
            result_type = lhs;
        } else if (self.refTagIs(rhs_res, &.{.vector_type})) {
            const rhs_inst = self.getInst(rhs_res).data;

            if (lhs_inst.vector_type.size == rhs_inst.vector_type.size and
                lhs_inst.vector_type.elem_type.is32BitNumberType() and
                rhs_inst.vector_type.elem_type.is32BitNumberType())
            {
                // bitcast<vecN<T>>(vecN<T>) -> vecN<T>
                if (lhs_inst.vector_type.elem_type == rhs_inst.vector_type.elem_type) {
                    result_type = lhs;
                }
                // bitcast<vecN<T>>(vecN<S>) -> T
                else {
                    result_type = lhs_inst.vector_type.elem_type;
                }
            }
            // bitcast<vec2<T>>(vec4<f16>) -> vec2<T>
            else if (lhs_inst.vector_type.size == .two and
                lhs_inst.vector_type.elem_type.is32BitNumberType() and
                rhs_inst.vector_type.size == .four and
                rhs_inst.vector_type.elem_type == .f16_type)
            {
                result_type = lhs;
            }
            // bitcast<vec4<f16>>(vec2<T>) -> vec4<f16>
            else if (rhs_inst.vector_type.size == .two and
                rhs_inst.vector_type.elem_type.is32BitNumberType() and
                lhs_inst.vector_type.size == .four and
                lhs_inst.vector_type.elem_type == .f16_type)
            {
                result_type = lhs;
            }
        }
    }

    if (result_type) |rt| {
        const inst_index = try self.addInst(.{
            .tag = .bitcast,
            .data = .{
                .bitcast = .{
                    .type = lhs,
                    .expr = rhs,
                    .result_type = rt,
                },
            },
        });
        return indexToRef(inst_index);
    }

    try self.errors.add(
        node_rhs_loc,
        "cannot cast '{s}' into '{s}'",
        .{ node_rhs_loc.slice(self.tree.source), node_lhs_loc.slice(self.tree.source) },
        null,
    );
    return error.AnalysisFail;
}

fn genVarRef(self: *AstGen, scope: *Scope, node: NodeIndex) !Air.Inst.Ref {
    const inst_index = try self.addInst(.{
        .tag = .var_ref,
        .data = .{ .ref = try self.findSymbol(scope, self.tree.nodeToken(node)) },
    });
    return indexToRef(inst_index);
}

fn genIndexAccess(self: *AstGen, scope: *Scope, node: NodeIndex) !Air.Inst.Ref {
    const base = try self.genExpr(scope, self.tree.nodeLHS(node));
    const base_type = try self.resolveVar(base) orelse {
        try self.errors.add(
            self.tree.nodeLoc(self.tree.nodeLHS(node)),
            "expected array type",
            .{},
            null,
        );
        return error.AnalysisFail;
    };

    if (!self.refTagIs(base_type, &.{.array_type})) {
        try self.errors.add(
            self.tree.nodeLoc(self.tree.nodeRHS(node)),
            "cannot access index of a non-array variable",
            .{},
            null,
        );
        return error.AnalysisFail;
    }

    const rhs = try self.genExpr(scope, self.tree.nodeRHS(node));
    if (try self.resolve(rhs)) |rhs_res| {
        if (rhs_res.isIntegerType() or self.refTagIs(rhs_res, &.{.integer})) {
            const inst_index = try self.addInst(.{
                .tag = .index_access,
                .data = .{
                    .index_access = .{
                        .base = base,
                        .elem_type = self.getInst(base_type).data.array_type.elem_type,
                        .index = rhs,
                    },
                },
            });
            return indexToRef(inst_index);
        }
    }

    try self.errors.add(
        self.tree.nodeLoc(self.tree.nodeRHS(node)),
        "index must be an integer",
        .{},
        null,
    );
    return error.AnalysisFail;
}

fn genFieldAccess(self: *AstGen, scope: *Scope, node: NodeIndex) !Air.Inst.Ref {
    const base = try self.genExpr(scope, self.tree.nodeLHS(node));
    const base_type = try self.resolveVar(base) orelse {
        try self.errors.add(
            self.tree.nodeLoc(node),
            "expected struct type",
            .{},
            null,
        );
        return error.AnalysisFail;
    };

    if (!self.refTagIs(base_type, &.{.struct_ref})) {
        try self.errors.add(
            self.tree.nodeLoc(node),
            "expected struct type",
            .{},
            null,
        );
        return error.AnalysisFail;
    }

    const base_struct = self.getInst(base_type).data.ref;
    const struct_members = self.getInst(base_struct).data.struct_decl.members;
    for (std.mem.sliceTo(self.refs.items[struct_members..], .none)) |member| {
        const member_data = self.getInst(member).data.struct_member;
        if (std.mem.eql(
            u8,
            self.tree.tokenLoc(self.tree.nodeRHS(node)).slice(self.tree.source),
            std.mem.sliceTo(self.strings.items[member_data.name..], 0),
        )) {
            const inst_index = try self.addInst(.{
                .tag = .field_access,
                .data = .{
                    .field_access = .{
                        .base = base,
                        .field = member,
                        .name = member_data.name,
                    },
                },
            });
            return indexToRef(inst_index);
        }
    }

    try self.errors.add(
        self.tree.nodeLoc(node),
        "struct '{s}' has no member named '{s}'",
        .{
            std.mem.sliceTo(self.strings.items[self.getInst(base_struct).data.struct_decl.name..], 0),
            self.tree.tokenLoc(self.tree.nodeRHS(node)).slice(self.tree.source),
        },
        null,
    );
    return error.AnalysisFail;
}

fn genType(self: *AstGen, scope: *Scope, node: NodeIndex) error{ AnalysisFail, OutOfMemory }!Air.Inst.Ref {
    return switch (self.tree.nodeTag(node)) {
        .bool_type => return .bool_type,
        .number_type => try self.genNumberType(node),
        .vector_type => try self.genVectorType(scope, node),
        .matrix_type => try self.genMatrixType(scope, node),
        .atomic_type => try self.genAtomicType(scope, node),
        .array_type => try self.genArrayType(scope, node),
        .ptr_type => try self.genPtrType(scope, node),
        .sampler_type => try self.genSamplerType(node),
        .texture_type => try self.genTextureType(scope, node),
        .multisampled_texture_type => try self.genMultisampledTextureType(scope, node),
        .storage_texture_type => try self.genStorageTextureType(node),
        .depth_texture_type => try self.genDepthTextureType(node),
        .external_texture_type => return .external_sampled_texture_type,
        .ident => {
            const node_loc = self.tree.nodeLoc(node);
            const decl_ref = try self.findSymbol(scope, self.tree.nodeToken(node));
            if (self.refIsType(decl_ref)) {
                return decl_ref;
            } else if (self.refTagIs(decl_ref, &.{.struct_decl})) {
                const inst = try self.addInst(.{ .tag = .struct_ref, .data = .{ .ref = decl_ref } });
                return indexToRef(inst);
            } else {
                try self.errors.add(
                    node_loc,
                    "'{s}' is not a type",
                    .{node_loc.slice(self.tree.source)},
                    null,
                );
                return error.AnalysisFail;
            }
        },
        else => unreachable,
    };
}

fn genNumberType(self: *AstGen, node: NodeIndex) !Air.Inst.Ref {
    const token = self.tree.nodeToken(node);
    const token_tag = self.tree.tokenTag(token);
    return switch (token_tag) {
        .k_i32 => .i32_type,
        .k_u32 => .u32_type,
        .k_f32 => .f32_type,
        .k_f16 => .f16_type,
        else => unreachable,
    };
}

fn genVectorType(self: *AstGen, scope: *Scope, node: NodeIndex) !Air.Inst.Ref {
    const inst = try self.allocInst();
    const elem_type_node = self.tree.nodeLHS(node);
    const elem_type_ref = try self.genType(scope, elem_type_node);

    if (elem_type_ref.isNumberType() or elem_type_ref == .bool_type) {
        const token_tag = self.tree.tokenTag(self.tree.nodeToken(node));
        self.instructions.items[inst] = .{
            .tag = .vector_type,
            .data = .{
                .vector_type = .{
                    .size = switch (token_tag) {
                        .k_vec2 => .two,
                        .k_vec3 => .three,
                        .k_vec4 => .four,
                        else => unreachable,
                    },
                    .elem_type = elem_type_ref,
                },
            },
        };
        return indexToRef(inst);
    }

    try self.errors.add(
        self.tree.nodeLoc(elem_type_node),
        "invalid vector component type",
        .{},
        try self.errors.createNote(
            null,
            "must be 'i32', 'u32', 'f32', 'f16' or 'bool'",
            .{},
        ),
    );
    return error.AnalysisFail;
}

fn genMatrixType(self: *AstGen, scope: *Scope, node: NodeIndex) !Air.Inst.Ref {
    const inst = try self.allocInst();
    const elem_type_node = self.tree.nodeLHS(node);
    const elem_type_ref = try self.genType(scope, elem_type_node);

    if (elem_type_ref.isFloatType()) {
        const token_tag = self.tree.tokenTag(self.tree.nodeToken(node));
        self.instructions.items[inst] = .{
            .tag = .matrix_type,
            .data = .{
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
                    .elem_type = elem_type_ref,
                },
            },
        };
        return indexToRef(inst);
    }

    try self.errors.add(
        self.tree.nodeLoc(elem_type_node),
        "invalid matrix component type",
        .{},
        try self.errors.createNote(
            null,
            "must be 'f32' or 'f16'",
            .{},
        ),
    );
    return error.AnalysisFail;
}

fn genAtomicType(self: *AstGen, scope: *Scope, node: NodeIndex) !Air.Inst.Ref {
    std.debug.assert(self.tree.nodeTag(node) == .atomic_type);

    const inst = try self.allocInst();
    const elem_type_node = self.tree.nodeLHS(node);
    const elem_type_ref = try self.genType(scope, elem_type_node);

    if (elem_type_ref.isIntegerType()) {
        self.instructions.items[inst] = .{
            .tag = .atomic_type,
            .data = .{ .atomic_type = .{ .elem_type = elem_type_ref } },
        };
        return indexToRef(inst);
    }

    try self.errors.add(
        self.tree.nodeLoc(elem_type_node),
        "invalid atomic component type",
        .{},
        try self.errors.createNote(
            null,
            "must be 'i32' or 'u32'",
            .{},
        ),
    );
    return error.AnalysisFail;
}

fn genPtrType(self: *AstGen, scope: *Scope, node: NodeIndex) !Air.Inst.Ref {
    const inst = try self.allocInst();
    const elem_type_node = self.tree.nodeLHS(node);
    const elem_type_ref = try self.genType(scope, elem_type_node);

    switch (elem_type_ref) {
        .bool_type,
        .u32_type,
        .i32_type,
        .f32_type,
        .f16_type,
        .sampler_type,
        .comparison_sampler_type,
        .external_sampled_texture_type,
        => {
            const extra_data = self.tree.extraData(Node.PtrType, self.tree.nodeRHS(node));

            const addr_space_loc = self.tree.tokenLoc(extra_data.addr_space);
            const ast_addr_space = stringToEnum(Ast.AddressSpace, addr_space_loc.slice(self.tree.source)).?;
            const addr_space: Air.Inst.PointerType.AddressSpace = switch (ast_addr_space) {
                .function => .function,
                .private => .private,
                .workgroup => .workgroup,
                .uniform => .uniform,
                .storage => .storage,
            };

            var access_mode: Air.Inst.PointerType.AccessMode = .none;
            if (extra_data.access_mode != null_node) {
                const access_mode_loc = self.tree.tokenLoc(extra_data.access_mode);
                const ast_access_mode = stringToEnum(Ast.AccessMode, access_mode_loc.slice(self.tree.source)).?;
                access_mode = switch (ast_access_mode) {
                    .read => .read,
                    .write => .write,
                    .read_write => .read_write,
                };
            }

            self.instructions.items[inst] = .{
                .tag = .ptr_type,
                .data = .{
                    .ptr_type = .{
                        .elem_type = elem_type_ref,
                        .addr_space = addr_space,
                        .access_mode = access_mode,
                    },
                },
            };

            return indexToRef(inst);
        },
        else => {},
    }

    try self.errors.add(
        self.tree.nodeLoc(elem_type_node),
        "invalid pointer component type",
        .{},
        null,
    );
    return error.AnalysisFail;
}

fn genArrayType(self: *AstGen, scope: *Scope, node: NodeIndex) !Air.Inst.Ref {
    const inst = try self.allocInst();
    const elem_type_node = self.tree.nodeLHS(node);
    const elem_type_ref = try self.genType(scope, elem_type_node);

    if (self.refTagIs(elem_type_ref, &.{ .array_type, .vector_type, .matrix_type, .atomic_type, .struct_ref }) or
        elem_type_ref.isNumberType() or elem_type_ref == .bool_type)
    {
        if (self.refTagIs(elem_type_ref, &.{.array_type})) {
            if (self.getInst(elem_type_ref).data.array_type.size == .none) {
                try self.errors.add(
                    self.tree.nodeLoc(elem_type_node),
                    "array componet type can not be a runtime-sized array",
                    .{},
                    null,
                );
                return error.AnalysisFail;
            }
        }

        const size_node = self.tree.nodeRHS(node);
        var size_ref = Air.Inst.Ref.none;
        if (size_node != null_node) {
            size_ref = try self.genExpr(scope, size_node);
        }

        self.instructions.items[inst] = .{
            .tag = .array_type,
            .data = .{
                .array_type = .{
                    .elem_type = elem_type_ref,
                    .size = size_ref,
                },
            },
        };

        return indexToRef(inst);
    }

    try self.errors.add(
        self.tree.nodeLoc(elem_type_node),
        "invalid array component type",
        .{},
        null,
    );
    return error.AnalysisFail;
}

fn genSamplerType(self: *AstGen, node: NodeIndex) !Air.Inst.Ref {
    const token = self.tree.nodeToken(node);
    const token_tag = self.tree.tokenTag(token);
    return switch (token_tag) {
        .k_sampler => .sampler_type,
        .k_sampler_comparison => .comparison_sampler_type,
        else => unreachable,
    };
}

fn genTextureType(self: *AstGen, scope: *Scope, node: NodeIndex) !Air.Inst.Ref {
    const inst = try self.allocInst();
    const elem_type_node = self.tree.nodeLHS(node);
    const elem_type_ref = try self.genType(scope, elem_type_node);

    if (elem_type_ref.is32BitNumberType()) {
        const token_tag = self.tree.tokenTag(self.tree.nodeToken(node));
        self.instructions.items[inst] = .{
            .tag = .sampled_texture_type,
            .data = .{
                .sampled_texture_type = .{
                    .kind = switch (token_tag) {
                        .k_texture_1d => .@"1d",
                        .k_texture_2d => .@"2d",
                        .k_texture_2d_array => .@"2d_array",
                        .k_texture_3d => .@"3d",
                        .k_texture_cube => .cube,
                        .k_texture_cube_array => .cube_array,
                        else => unreachable,
                    },
                    .elem_type = elem_type_ref,
                },
            },
        };
        return indexToRef(inst);
    }

    try self.errors.add(
        self.tree.nodeLoc(elem_type_node),
        "invalid texture component type",
        .{},
        try self.errors.createNote(
            null,
            "must be 'i32', 'u32' or 'f32'",
            .{},
        ),
    );
    return error.AnalysisFail;
}

fn genMultisampledTextureType(self: *AstGen, scope: *Scope, node: NodeIndex) !Air.Inst.Ref {
    const inst = try self.allocInst();
    const elem_type_node = self.tree.nodeLHS(node);
    const elem_type_ref = try self.genType(scope, elem_type_node);

    if (elem_type_ref.is32BitNumberType()) {
        const token_tag = self.tree.tokenTag(self.tree.nodeToken(node));
        self.instructions.items[inst] = .{
            .tag = .multisampled_texture_type,
            .data = .{
                .multisampled_texture_type = .{
                    .kind = switch (token_tag) {
                        .k_texture_multisampled_2d => .@"2d",
                        else => unreachable,
                    },
                    .elem_type = elem_type_ref,
                },
            },
        };
        return indexToRef(inst);
    }

    try self.errors.add(
        self.tree.nodeLoc(elem_type_node),
        "invalid multisampled texture component type",
        .{},
        try self.errors.createNote(
            null,
            "must be 'i32', 'u32' or 'f32'",
            .{},
        ),
    );
    return error.AnalysisFail;
}

fn genStorageTextureType(self: *AstGen, node: NodeIndex) !Air.Inst.Ref {
    const node_lhs = self.tree.nodeLHS(node);
    const texel_format_loc = self.tree.nodeLoc(node_lhs);
    const ast_texel_format = stringToEnum(Ast.TexelFormat, texel_format_loc.slice(self.tree.source)).?;
    const texel_format: Air.Inst.StorageTextureType.TexelFormat = switch (ast_texel_format) {
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

    const node_rhs = self.tree.nodeRHS(node);
    const access_mode_loc = self.tree.nodeLoc(node_rhs);
    const access_mode_full = stringToEnum(Ast.AccessMode, access_mode_loc.slice(self.tree.source)).?;
    const access_mode = switch (access_mode_full) {
        .write => Air.Inst.StorageTextureType.AccessMode.write,
        else => {
            try self.errors.add(
                access_mode_loc,
                "invalid access mode",
                .{},
                try self.errors.createNote(
                    null,
                    "only 'write' is allowed",
                    .{},
                ),
            );
            return error.AnalysisFail;
        },
    };

    const token_tag = self.tree.tokenTag(self.tree.nodeToken(node));
    const inst = try self.addInst(.{
        .tag = .storage_texture_type,
        .data = .{
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
        },
    });

    return indexToRef(inst);
}

fn genDepthTextureType(self: *AstGen, node: NodeIndex) !Air.Inst.Ref {
    const token_tag = self.tree.tokenTag(self.tree.nodeToken(node));
    const inst = try self.addInst(.{
        .tag = .depth_texture_type,
        .data = .{
            .depth_texture_type = switch (token_tag) {
                .k_texture_depth_2d => .@"2d",
                .k_texture_depth_2d_array => .@"2d_array",
                .k_texture_depth_cube => .cube,
                .k_texture_depth_cube_array => .cube_array,
                .k_texture_depth_multisampled_2d => .multisampled_2d,
                else => unreachable,
            },
        },
    });
    return indexToRef(inst);
}

/// takes token and returns the first declaration in the current and parent scopes
fn findSymbol(self: *AstGen, scope: *Scope, token: TokenIndex) error{ OutOfMemory, AnalysisFail }!Air.Inst.Ref {
    std.debug.assert(self.tree.tokenTag(token) == .ident);

    const loc = self.tree.tokenLoc(token);
    const name = loc.slice(self.tree.source);

    var s = scope;
    while (true) {
        var node_iter = s.decls.keyIterator();
        while (node_iter.next()) |other_node| {
            if (std.mem.eql(u8, name, self.tree.declNameLoc(other_node.*).?.slice(self.tree.source))) {
                return self.genDecl(s, other_node.*);
            }
        }

        if (s.tag == .root) {
            try self.errors.add(
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

fn genStructRef(self: *AstGen, scope: *Scope, node: NodeIndex) !Air.Inst.Ref {
    const inst_index = try self.addInst(.{
        .tag = .var_ref,
        .data = .{ .ref = try self.findSymbol(scope, self.tree.nodeToken(node)) },
    });
    return indexToRef(inst_index);
}

fn resolve(self: *AstGen, _ref: Air.Inst.Ref) !?Air.Inst.Ref {
    var in_deref = false;
    var in_decl = false;
    var ref = _ref;

    while (true) {
        switch (ref) {
            .none => unreachable,

            .true, .false => return ref,

            .bool_type,
            .i32_type,
            .u32_type,
            .f32_type,
            .f16_type,
            .sampler_type,
            .comparison_sampler_type,
            .external_sampled_texture_type,
            => if (in_decl) return ref,

            _ => switch (self.getInst(ref).tag) {
                .vector_type,
                .matrix_type,
                .atomic_type,
                .array_type,
                .ptr_type,
                .sampled_texture_type,
                .multisampled_texture_type,
                .storage_texture_type,
                .depth_texture_type,
                .struct_ref,
                => if (in_decl) return ref,

                .integer,
                .float,
                => return ref,

                .logical_and,
                .logical_or,
                .equal,
                .not_equal,
                .less_than,
                .less_than_equal,
                .greater_than,
                .greater_than_equal,
                .not,
                => return .bool_type,

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
                => {
                    const inst_data = self.getInst(ref).data;
                    ref = inst_data.binary.lhs; // TODO
                },

                .negate => {
                    const inst_data = self.getInst(ref).data;
                    ref = inst_data.ref;
                },

                .deref => {
                    in_deref = true;
                    const inst_data = self.getInst(ref).data;
                    ref = inst_data.ref;
                },

                else => {
                    if (try self.resolveVar(ref)) |res| {
                        ref = res;
                        in_decl = true;
                        if (in_deref) {
                            ref = self.getInst(res).data.ptr_type.elem_type;
                        }
                    } else {
                        return null;
                    }
                },
            },
        }
    }
}

/// expects a var_ref index_access, field_access, global_variable_decl or global_const_decl
fn resolveVar(self: *AstGen, ref: Air.Inst.Ref) !?Air.Inst.Ref {
    const inst = self.getInst(ref);
    switch (inst.tag) {
        .var_ref => return self.resolveVar(inst.data.ref),
        .index_access => return inst.data.index_access.elem_type,
        .field_access => {
            const struct_member = self.getInst(ref).data.field_access.field;
            return self.getInst(struct_member).data.struct_member.type;
        },
        .global_variable_decl => {
            const decl_type = inst.data.global_variable_decl.type;
            if (decl_type != .none) {
                return decl_type;
            } else {
                const maybe_value_ref = inst.data.global_variable_decl.expr;
                if (self.refTagIs(maybe_value_ref, &.{.var_ref})) {
                    return self.resolveVar(maybe_value_ref);
                }
                return maybe_value_ref;
            }
        },
        .global_const_decl => {
            const decl_type = inst.data.global_const_decl.type;
            if (decl_type != .none) {
                return decl_type;
            } else {
                const maybe_value_ref = inst.data.global_const_decl.expr;
                if (self.refTagIs(maybe_value_ref, &.{.var_ref})) {
                    return try self.resolveVar(maybe_value_ref);
                }
                return maybe_value_ref;
            }
        },
        else => return null,
    }
}

fn eqlType(self: *AstGen, a: Air.Inst.Ref, b: Air.Inst.Ref) bool {
    if (a == b or
        (a.isBool() and b.isBool()) or
        (a.isFloatType() and b.isFloatType()) or
        (a.isIntegerType() and b.isIntegerType()))
    {
        return true;
    }

    if ((self.refTagIs(a, &.{.integer}) and b.isIntegerType()) or
        (self.refTagIs(b, &.{.integer}) and a.isIntegerType()) or
        (self.refTagIs(a, &.{.float}) and b.isFloatType()) or
        (self.refTagIs(b, &.{.float}) and a.isFloatType()))
    {
        return true;
    }

    if (a.isIndex() and b.isIndex()) {
        const a_inst = self.getInst(a);
        const b_inst = self.getInst(b);
        if (a_inst.tag == b_inst.tag) return true;
    }

    return false;
}

fn allocInst(self: *AstGen) error{OutOfMemory}!Air.Inst.Index {
    try self.instructions.append(self.allocator, undefined);
    return @intCast(Air.Inst.Index, self.instructions.items.len - 1);
}

fn addInst(self: *AstGen, inst: Air.Inst) error{OutOfMemory}!Air.Inst.Index {
    try self.instructions.append(self.allocator, inst);
    return @intCast(Air.Inst.Index, self.instructions.items.len - 1);
}

fn addRefList(self: *AstGen, list: []const Air.Inst.Ref) error{OutOfMemory}!u32 {
    const len = list.len + 1;
    try self.refs.ensureUnusedCapacity(self.allocator, len);
    self.refs.appendSliceAssumeCapacity(list);
    self.refs.appendAssumeCapacity(.none);
    return @intCast(u32, self.refs.items.len - len);
}

fn addString(self: *AstGen, str: []const u8) error{OutOfMemory}!u32 {
    const len = str.len + 1;
    try self.strings.ensureUnusedCapacity(self.allocator, len);
    self.strings.appendSliceAssumeCapacity(str);
    self.strings.appendAssumeCapacity(0);
    return @intCast(u32, self.strings.items.len - len);
}

fn getInst(self: *AstGen, ref: Air.Inst.Ref) Air.Inst {
    return self.instructions.items[ref.toIndex().?];
}

pub fn indexToRef(index: Air.Inst.Index) Air.Inst.Ref {
    return @intToEnum(Air.Inst.Ref, Air.Inst.Ref.start_index + index);
}

pub fn refTagIs(self: AstGen, ref: Air.Inst.Ref, one_of: []const Air.Inst.Tag) bool {
    const indx = ref.toIndex() orelse return false;
    const tag = self.instructions.items[indx].tag;
    for (one_of) |t| {
        if (tag == t) return true;
    }
    return false;
}

pub fn refIsType(self: AstGen, ref: Air.Inst.Ref) bool {
    return switch (ref) {
        .none => unreachable,
        .true, .false => false,
        .bool_type,
        .i32_type,
        .u32_type,
        .f32_type,
        .f16_type,
        .sampler_type,
        .comparison_sampler_type,
        .external_sampled_texture_type,
        => true,
        _ => return self.refTagIs(ref, &.{
            .vector_type,
            .matrix_type,
            .atomic_type,
            .array_type,
            .ptr_type,
            .sampled_texture_type,
            .multisampled_texture_type,
            .storage_texture_type,
            .depth_texture_type,
            .struct_ref,
        }),
    };
}
