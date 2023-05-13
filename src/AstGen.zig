const std = @import("std");
const Ast = @import("Ast.zig");
const IR = @import("IR.zig");
const ErrorList = @import("ErrorList.zig");
const Node = Ast.Node;
const NodeIndex = Ast.NodeIndex;
const TokenIndex = Ast.TokenIndex;
const null_node = Ast.null_node;

const AstGen = @This();

allocator: std.mem.Allocator,
tree: *const Ast,
instructions: std.ArrayListUnmanaged(IR.Inst) = .{},
refs: std.ArrayListUnmanaged(IR.Inst.Ref) = .{},
strings: std.ArrayListUnmanaged(u8) = .{},
scratch: std.ArrayListUnmanaged(IR.Inst.Ref) = .{},
resolved_refs: std.AutoHashMapUnmanaged(IR.Inst.Ref, IR.Inst.Ref) = .{},
errors: ErrorList,
scope_pool: std.heap.MemoryPool(Scope),

pub const Scope = struct {
    tag: Tag,
    /// this is undefined if tag == .root
    parent: *Scope,
    decls: std.AutoHashMapUnmanaged(NodeIndex, error{AnalysisFail}!IR.Inst.Ref) = .{},

    pub const Tag = enum {
        root,
        func,
        block,
    };
};

pub fn genTranslationUnit(self: *AstGen) !u32 {
    const global_decls = self.tree.spanToList(0);

    const scratch_top = self.scratch.items.len;
    defer self.scratch.shrinkRetainingCapacity(scratch_top);

    var root_scope = try self.scope_pool.create();
    root_scope.* = .{ .tag = .root, .parent = undefined };

    self.scanDecls(root_scope, global_decls) catch |err| switch (err) {
        error.AnalysisFail => return try self.addRefList(self.scratch.items[scratch_top..]),
        error.OutOfMemory => return error.OutOfMemory,
    };

    for (global_decls) |node| {
        const global = self.genDecl(root_scope, node) catch |err| switch (err) {
            error.AnalysisFail => continue,
            error.OutOfMemory => return error.OutOfMemory,
        };
        try self.scratch.append(self.allocator, global);
    }

    return try self.addRefList(self.scratch.items[scratch_top..]);
}

pub fn genDecl(self: *AstGen, scope: *Scope, node: NodeIndex) !IR.Inst.Ref {
    const ref = try scope.decls.get(node).?;
    if (ref != .none) {
        // the declaration has already analysed
        return ref;
    }

    const decl = switch (self.tree.nodeTag(node)) {
        .global_variable => self.genGlobalVariable(scope, node),
        .global_constant => self.genGlobalConstDecl(scope, node),
        .fn_decl => self.genFnDecl(scope, node),
        .type_alias => self.genTypeAlias(scope, node),
        .struct_decl => self.genStruct(scope, node),
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
pub fn scanDecls(self: *AstGen, scope: *Scope, decls: []const NodeIndex) !void {
    std.debug.assert(scope.decls.count() == 0);

    for (decls) |decl| {
        const loc = self.tree.declNameLoc(decl).?;
        const name = loc.slice(self.tree.source);

        var iter = scope.decls.keyIterator();
        while (iter.next()) |node| {
            if (std.mem.eql(u8, name, self.tree.declNameLoc(node.*).?.slice(self.tree.source))) {
                try self.errors.add(
                    loc,
                    "redeclaration of '{s}'",
                    .{name},
                    try self.errors.createNote(
                        self.tree.declNameLoc(node.*),
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

/// takes token and returns the first declaration in the current and parent scopes
pub fn findSymbol(self: *AstGen, scope: *Scope, token: TokenIndex) error{ OutOfMemory, AnalysisFail }!IR.Inst.Ref {
    std.debug.assert(self.tree.tokenTag(token) == .ident);

    const loc = self.tree.tokenLoc(token);
    const name = loc.slice(self.tree.source);

    var s = scope;
    while (true) {
        var node_iter = s.decls.keyIterator();
        while (node_iter.next()) |other_node| {
            if (std.mem.eql(u8, name, self.tree.declNameLoc(other_node.*).?.slice(self.tree.source))) {
                return self.genDecl(scope, other_node.*);
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

pub fn genTypeAlias(self: *AstGen, scope: *Scope, node: NodeIndex) !IR.Inst.Ref {
    return self.genType(scope, self.tree.nodeLHS(node));
}

pub fn genGlobalConstDecl(self: *AstGen, scope: *Scope, node: NodeIndex) !IR.Inst.Ref {
    std.debug.assert(self.tree.nodeTag(node) == .global_constant);

    const inst = try self.reserveInst();
    const node_lhs = self.tree.nodeLHS(node);
    const node_rhs = self.tree.nodeRHS(node);
    const name_loc = self.tree.declNameLoc(node).?;

    var var_type = IR.Inst.Ref.none;
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
    return IR.Inst.toRef(inst);
}

// TODO
fn isConstExpr(self: *AstGen, expr: IR.Inst.Ref) bool {
    _ = self;
    _ = expr;
    return true;
}

pub fn genGlobalVariable(self: *AstGen, scope: *Scope, node: NodeIndex) !IR.Inst.Ref {
    std.debug.assert(self.tree.nodeTag(node) == .global_variable);

    const inst = try self.reserveInst();
    const node_rhs = self.tree.nodeRHS(node);
    const gv = self.tree.extraData(Node.GlobalVarDecl, self.tree.nodeLHS(node));
    const name_loc = self.tree.declNameLoc(node).?;

    var is_resource = false;

    var var_type = IR.Inst.Ref.none;
    if (gv.type != null_node) {
        var_type = try self.genType(scope, gv.type);
    }

    if (var_type == .sampler_type or
        var_type == .comparison_sampler_type or
        var_type == .external_sampled_texture_type or
        var_type.is(self.instructions.items, &.{
        .sampled_texture_type,
        .multisampled_texture_type,
        .storage_texture_type,
        .depth_texture_type,
    })) {
        is_resource = true;
    }

    var addr_space: IR.Inst.GlobalVariableDecl.AddressSpace = .none;
    if (gv.addr_space != null_node) {
        const addr_space_loc = self.tree.tokenLoc(gv.addr_space);
        const ast_addr_space = std.meta.stringToEnum(Ast.AddressSpace, addr_space_loc.slice(self.tree.source)).?;
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

    var access_mode: IR.Inst.GlobalVariableDecl.AccessMode = .none;
    if (gv.access_mode != null_node) {
        const access_mode_loc = self.tree.tokenLoc(gv.access_mode);
        const ast_access_mode = std.meta.stringToEnum(Ast.AccessMode, access_mode_loc.slice(self.tree.source)).?;
        access_mode = switch (ast_access_mode) {
            .read => .read,
            .write => .write,
            .read_write => .read_write,
        };
    }

    var binding = IR.Inst.Ref.none;
    var group = IR.Inst.Ref.none;
    if (gv.attrs != null_node) {
        for (self.tree.spanToList(gv.attrs)) |attr| {
            const attr_lhs = self.tree.nodeLHS(attr);
            switch (self.tree.nodeTag(attr)) {
                .attr_binding => {
                    if (!is_resource) {
                        try self.errors.add(
                            self.tree.nodeLoc(attr),
                            "variable '{s}' is not a resource",
                            .{name_loc.slice(self.tree.source)},
                            null,
                        );
                        return error.AnalysisFail;
                    }

                    binding = try self.genExpr(scope, attr_lhs);
                    if (!self.isConstExpr(binding)) {
                        try self.errors.add(
                            self.tree.nodeLoc(attr_lhs),
                            "expected const-expressions, found '{s}'",
                            .{self.tree.nodeLoc(attr_lhs).slice(self.tree.source)},
                            null,
                        );
                        return error.AnalysisFail;
                    }
                    if (self.instructions.items[binding.toIndex().?].data.integer_literal.value < 0) {
                        try self.errors.add(
                            self.tree.nodeLoc(attr_lhs),
                            "binding value must not be a negative",
                            .{},
                            null,
                        );
                        return error.AnalysisFail;
                    }
                },
                .attr_group => {
                    if (!is_resource) {
                        try self.errors.add(
                            self.tree.nodeLoc(attr),
                            "variable '{s}' is not a resource",
                            .{name_loc.slice(self.tree.source)},
                            null,
                        );
                        return error.AnalysisFail;
                    }

                    group = try self.genExpr(scope, attr_lhs);
                    if (!self.isConstExpr(group)) {
                        try self.errors.add(
                            self.tree.nodeLoc(attr_lhs),
                            "expected const-expressions, found '{s}'",
                            .{self.tree.nodeLoc(attr_lhs).slice(self.tree.source)},
                            null,
                        );
                        return error.AnalysisFail;
                    }
                    if (self.instructions.items[group.toIndex().?].data.integer_literal.value < 0) {
                        try self.errors.add(
                            self.tree.nodeLoc(attr_lhs),
                            "group value must not be a negative",
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

    var expr = IR.Inst.Ref.none;
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
    return IR.Inst.toRef(inst);
}

pub fn genStruct(self: *AstGen, scope: *Scope, node: NodeIndex) !IR.Inst.Ref {
    std.debug.assert(self.tree.nodeTag(node) == .struct_decl);

    const inst = try self.reserveInst();

    const scratch_top = self.scratch.items.len;
    defer self.scratch.shrinkRetainingCapacity(scratch_top);

    const member_nodes_list = self.tree.spanToList(self.tree.nodeLHS(node));
    for (member_nodes_list, 0..) |member_node, i| {
        const member_inst = try self.reserveInst();
        const member_name_loc = self.tree.tokenLoc(self.tree.nodeToken(member_node));
        const member_type_node = self.tree.nodeRHS(member_node);
        const member_type_loc = self.tree.nodeLoc(member_type_node);
        const member_type_ref = self.genType(scope, member_type_node) catch |err| switch (err) {
            error.AnalysisFail => continue,
            error.OutOfMemory => return error.OutOfMemory,
        };

        switch (member_type_ref) {
            .bool_type, .i32_type, .u32_type, .f32_type, .f16_type => {},
            .sampler_type, .comparison_sampler_type, .external_sampled_texture_type => {
                try self.errors.add(
                    member_name_loc,
                    "invalid struct member type '{s}'",
                    .{member_type_loc.slice(self.tree.source)},
                    null,
                );
                continue;
            },
            .none, .true_literal, .false_literal => unreachable,
            _ => switch (self.instructions.items[member_type_ref.toIndex().?].tag) {
                .vector_type, .matrix_type, .atomic_type, .struct_ref => {},
                .array_type => {
                    if (self.instructions.items[member_type_ref.toIndex().?].data.array_type.size == .none and i + 1 != member_nodes_list.len) {
                        try self.errors.add(
                            member_name_loc,
                            "struct member with runtime-sized array type, must be the last member of the structure",
                            .{},
                            null,
                        );
                        continue;
                    }
                },
                .ptr_type,
                .sampled_texture_type,
                .multisampled_texture_type,
                .storage_texture_type,
                .depth_texture_type,
                => {
                    try self.errors.add(
                        member_name_loc,
                        "invalid struct member type '{s}'",
                        .{member_type_loc.slice(self.tree.source)},
                        null,
                    );
                    continue;
                },
                else => unreachable,
            },
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
        try self.scratch.append(self.allocator, IR.Inst.toRef(member_inst));
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
    return IR.Inst.toRef(inst);
}

pub fn genFnDecl(self: *AstGen, scope: *Scope, node: NodeIndex) !IR.Inst.Ref {
    std.debug.assert(self.tree.nodeTag(node) == .fn_decl);

    const inst = try self.reserveInst();
    const fn_proto = self.tree.extraData(Node.FnProto, self.tree.nodeLHS(node));
    var args: u32 = 0;
    if (fn_proto.params != 0) {
        args = try self.getFnArgs(scope, fn_proto.params);
    }
    var statements: u32 = 0;
    if (self.tree.nodeRHS(node) != null_node) {
        statements = try self.genStatements(scope, self.tree.nodeRHS(node));
    }
    const name = self.tree.declNameLoc(node).?.slice(self.tree.source);
    const name_index = try self.addString(name);
    self.instructions.items[inst] = .{
        .tag = .fn_decl,
        .data = .{
            .fn_decl = .{
                .name = name_index,
                .args = args,
                .statements = statements,
                .fragment = false, // TODO
            },
        },
    };
    return IR.Inst.toRef(inst);
}

pub fn genStatements(self: *AstGen, scope: *Scope, node: NodeIndex) !u32 {
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

pub fn genCompoundAssign(self: *AstGen, scope: *Scope, node: NodeIndex) !IR.Inst.Ref {
    const node_lhs = self.tree.nodeLHS(node);
    const node_rhs = self.tree.nodeRHS(node);
    const lhs = try self.findSymbol(scope, self.tree.nodeToken(node_lhs));
    const rhs = try self.genExpr(scope, node_rhs);
    const tag: IR.Inst.Tag = switch (self.tree.tokenTag(self.tree.nodeToken(node))) {
        .equal => .assign,
        else => .assign_xor,
    };
    const inst = try self.addInst(.{ .tag = tag, .data = .{ .binary = .{ .lhs = lhs, .rhs = rhs } } });
    return IR.Inst.toRef(inst);
}

fn getFnArgs(self: *AstGen, scope: *Scope, node: NodeIndex) !u32 {
    const scratch_top = self.scratch.items.len;
    defer self.scratch.shrinkRetainingCapacity(scratch_top);

    for (self.tree.spanToList(node)) |arg_node| {
        const arg_inst = try self.reserveInst();
        const arg_name_loc = self.tree.tokenLoc(self.tree.nodeToken(arg_node));
        const arg_type_node = self.tree.nodeRHS(arg_node);
        const arg_type_ref = self.genType(scope, arg_type_node) catch |err| switch (err) {
            error.AnalysisFail => continue,
            error.OutOfMemory => return error.OutOfMemory,
        };

        var builtin = IR.Inst.FnArg.BuiltinValue.none;
        var inter: ?IR.Inst.FnArg.Interpolate = null;
        var location = IR.Inst.Ref.none;
        var invariant = false;

        if (self.tree.nodeLHS(arg_node) != null_node) {
            for (self.tree.spanToList(self.tree.nodeLHS(arg_node))) |attr| {
                switch (self.tree.nodeTag(attr)) {
                    .attr_invariant => invariant = true,
                    .attr_location => location = try self.genExpr(scope, self.tree.nodeLHS(attr)),
                    .attr_builtin => {
                        const builtin_loc = self.tree.tokenLoc(self.tree.nodeLHS(attr));
                        const builtin_ast = std.meta.stringToEnum(Ast.BuiltinValue, builtin_loc.slice(self.tree.source)).?;
                        builtin = switch (builtin_ast) {
                            .vertex_index => .vertex_index,
                            .instance_index => .instance_index,
                            .position => .position,
                            .front_facing => .front_facing,
                            .frag_depth => .frag_depth,
                            .local_invocation_id => .local_invocation_id,
                            .local_invocation_index => .local_invocation_index,
                            .global_invocation_id => .global_invocation_id,
                            .workgroup_id => .workgroup_id,
                            .num_workgroups => .num_workgroups,
                            .sample_index => .sample_index,
                            .sample_mask => .sample_mask,
                        };
                    },
                    .attr_interpolate => {
                        const inter_type_loc = self.tree.tokenLoc(self.tree.nodeLHS(attr));
                        const inter_type_ast = std.meta.stringToEnum(Ast.InterpolationType, inter_type_loc.slice(self.tree.source)).?;
                        inter = .{
                            .type = switch (inter_type_ast) {
                                .perspective => .perspective,
                                .linear => .linear,
                                .flat => .flat,
                            },
                            .sample = .none,
                        };

                        if (self.tree.nodeRHS(attr) != null_node) {
                            const inter_sample_loc = self.tree.tokenLoc(self.tree.nodeRHS(attr));
                            const inter_sample_ast = std.meta.stringToEnum(Ast.InterpolationSample, inter_sample_loc.slice(self.tree.source)).?;
                            inter.?.sample = switch (inter_sample_ast) {
                                .center => .center,
                                .centroid => .centroid,
                                .sample => .sample,
                            };
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

        const name_index = try self.addString(arg_name_loc.slice(self.tree.source));
        self.instructions.items[arg_inst] = .{
            .tag = .fn_arg,
            .data = .{
                .fn_arg = .{
                    .name = name_index,
                    .type = arg_type_ref,
                    .builtin = builtin,
                    .interpolate = inter,
                    .location = location,
                    .invariant = invariant,
                },
            },
        };
        try self.scratch.append(self.allocator, IR.Inst.toRef(arg_inst));
    }

    return self.addRefList(self.scratch.items[scratch_top..]);
}

pub fn genNot(self: *AstGen, scope: *Scope, node: NodeIndex) !IR.Inst.Ref {
    const node_lhs = self.tree.nodeLHS(node);
    const node_lhs_loc = self.tree.nodeLoc(node_lhs);
    const lhs = try self.genExpr(scope, node_lhs);
    const lhs_res = try self.resolve(lhs);

    if (lhs_res != null and lhs_res.?.isBool()) {
        const inst_index = try self.addInst(.{ .tag = .not, .data = .{ .ref = lhs } });
        return IR.Inst.toRef(inst_index);
    }

    try self.errors.add(
        node_lhs_loc,
        "cannot operate not (!) on '{s}'",
        .{node_lhs_loc.slice(self.tree.source)},
        null,
    );
    return error.AnalysisFail;
}

pub fn genNegate(self: *AstGen, scope: *Scope, node: NodeIndex) !IR.Inst.Ref {
    const node_lhs = self.tree.nodeLHS(node);
    const node_lhs_loc = self.tree.nodeLoc(node_lhs);
    const lhs = try self.genExpr(scope, node_lhs);
    const lhs_res = try self.resolve(lhs);

    if (lhs_res != null and lhs_res.?.isNumber(self.instructions.items)) {
        const inst_index = try self.addInst(.{ .tag = .negate, .data = .{ .ref = lhs } });
        return IR.Inst.toRef(inst_index);
    }

    try self.errors.add(
        node_lhs_loc,
        "cannot negate '{s}'",
        .{node_lhs_loc.slice(self.tree.source)},
        null,
    );
    return error.AnalysisFail;
}

pub fn genDeref(self: *AstGen, scope: *Scope, node: NodeIndex) !IR.Inst.Ref {
    const node_lhs = self.tree.nodeLHS(node);
    const node_lhs_loc = self.tree.nodeLoc(node_lhs);
    const lhs = try self.genExpr(scope, node_lhs);
    if (lhs.is(self.instructions.items, &.{.var_ref})) {
        const lhs_res = try self.resolveVarTypeOrValue(lhs);
        if (lhs_res.is(self.instructions.items, &.{.ptr_type})) {
            const inst_index = try self.addInst(.{ .tag = .deref, .data = .{ .ref = lhs } });
            return IR.Inst.toRef(inst_index);
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

pub fn genAddrOf(self: *AstGen, scope: *Scope, node: NodeIndex) !IR.Inst.Ref {
    const inst_index = try self.addInst(.{
        .tag = .addr_of,
        .data = .{
            .ref = try self.genExpr(scope, self.tree.nodeLHS(node)),
        },
    });
    return IR.Inst.toRef(inst_index);
}

pub fn genBinary(self: *AstGen, scope: *Scope, node: NodeIndex) !IR.Inst.Ref {
    const node_tag = self.tree.nodeTag(node);
    const node_loc = self.tree.nodeLoc(node);
    const node_lhs = self.tree.nodeLHS(node);
    const node_rhs = self.tree.nodeRHS(node);
    const node_lhs_loc = self.tree.nodeLoc(node_lhs);
    const node_rhs_loc = self.tree.nodeLoc(node_rhs);
    const lhs = try self.genExpr(scope, node_lhs);
    const rhs = try self.genExpr(scope, node_rhs);
    const inst_tag: IR.Inst.Tag = switch (node_tag) {
        .mul => .mul,
        .div => .div,
        .mod => .mod,
        .add => .add,
        .sub => .sub,
        .shift_left => .shift_left,
        .shift_right => .shift_right,
        .binary_and => .binary_and,
        .binary_or => .binary_or,
        .binary_xor => .binary_xor,
        .circuit_and => .circuit_and,
        .circuit_or => .circuit_or,
        .equal => .equal,
        .not_equal => .not_equal,
        .less => .less,
        .less_equal => .less_equal,
        .greater => .greater,
        .greater_equal => .greater_equal,
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
        .circuit_and,
        .circuit_or,
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
    return IR.Inst.toRef(inst_index);
}

pub fn genBitcast(self: *AstGen, scope: *Scope, node: NodeIndex) !IR.Inst.Ref {
    const node_lhs = self.tree.nodeLHS(node);
    const node_rhs = self.tree.nodeRHS(node);
    const node_lhs_loc = self.tree.nodeLoc(node_lhs);
    const node_rhs_loc = self.tree.nodeLoc(node_rhs);
    const lhs = try self.genType(scope, node_lhs);
    const rhs = try self.genExpr(scope, node_rhs);
    const rhs_res = try self.resolve(rhs) orelse unreachable;
    var result_type: ?IR.Inst.Ref = null;

    // bitcast<T>(T) -> T
    if (lhs.isNumberType() and lhs == rhs_res) {
        result_type = lhs;
    } else if (lhs.is32BitNumberType()) {
        // bitcast<T>(S) -> T
        if (rhs_res.is32BitNumberType() and lhs != rhs_res) {
            result_type = lhs;
        }
        // bitcast<T>(vec2<f16>) -> T
        else if (rhs_res.is(self.instructions.items, &.{.vector_type})) {
            const rhs_inst = self.instructions.items[rhs_res.toIndex().?];

            if (rhs_inst.data.vector_type.size == .two and
                rhs_inst.data.vector_type.component_type == .f16_type)
            {
                result_type = lhs;
            }
        }
    } else if (lhs.is(self.instructions.items, &.{.vector_type})) {
        const lhs_inst = self.instructions.items[lhs.toIndex().?];

        // bitcast<vec2<f16>>(T) -> vec2<f16>
        if (lhs_inst.data.vector_type.size == .two and
            lhs_inst.data.vector_type.component_type == .f16_type and
            rhs_res.is32BitNumberType())
        {
            result_type = lhs;
        } else if (rhs_res.is(self.instructions.items, &.{.vector_type})) {
            const rhs_inst = self.instructions.items[rhs_res.toIndex().?];

            if (lhs_inst.data.vector_type.size == rhs_inst.data.vector_type.size and
                lhs_inst.data.vector_type.component_type.is32BitNumberType() and
                rhs_inst.data.vector_type.component_type.is32BitNumberType())
            {
                // bitcast<vecN<T>>(vecN<T>) -> vecN<T>
                if (lhs_inst.data.vector_type.component_type == rhs_inst.data.vector_type.component_type) {
                    result_type = lhs;
                }
                // bitcast<vecN<T>>(vecN<S>) -> T
                else {
                    result_type = lhs_inst.data.vector_type.component_type;
                }
            }
            // bitcast<vec2<T>>(vec4<f16>) -> vec2<T>
            else if (lhs_inst.data.vector_type.size == .two and
                lhs_inst.data.vector_type.component_type.is32BitNumberType() and
                rhs_inst.data.vector_type.size == .four and
                rhs_inst.data.vector_type.component_type == .f16_type)
            {
                result_type = lhs;
            }
            // bitcast<vec4<f16>>(vec2<T>) -> vec4<f16>
            else if (rhs_inst.data.vector_type.size == .two and
                rhs_inst.data.vector_type.component_type.is32BitNumberType() and
                lhs_inst.data.vector_type.size == .four and
                lhs_inst.data.vector_type.component_type == .f16_type)
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
        return IR.Inst.toRef(inst_index);
    }

    try self.errors.add(
        node_rhs_loc,
        "cannot cast '{s}' into '{s}'",
        .{ node_rhs_loc.slice(self.tree.source), node_lhs_loc.slice(self.tree.source) },
        null,
    );
    return error.AnalysisFail;
}

pub fn genIdent(self: *AstGen, scope: *Scope, node: NodeIndex) !IR.Inst.Ref {
    const inst_index = try self.addInst(.{
        .tag = .var_ref,
        .data = .{ .ref = try self.findSymbol(scope, self.tree.nodeToken(node)) },
    });
    return IR.Inst.toRef(inst_index);
}

fn genIndexAccess(self: *AstGen, scope: *Scope, node: NodeIndex) !IR.Inst.Ref {
    const base = try self.genExpr(scope, self.tree.nodeLHS(node));
    const base_array = blk: {
        if (base.is(self.instructions.items, &.{.var_ref})) {
            const var_type = try self.resolveVarTypeOrValue(base);
            if (!var_type.is(self.instructions.items, &.{.array_type})) {
                try self.errors.add(
                    self.tree.nodeLoc(self.tree.nodeRHS(node)),
                    "cannot access index of a non-array variable",
                    .{},
                    null,
                );
                return error.AnalysisFail;
            }
            break :blk var_type;
        } else if (base.is(self.instructions.items, &.{.index_access})) {
            const index_data = self.instructions.items[base.toIndex().?].data.index_access;
            if (!index_data.elem_type.is(self.instructions.items, &.{.array_type})) {
                try self.errors.add(
                    self.tree.nodeLoc(self.tree.nodeRHS(node)),
                    "cannot access index of a non-array variable",
                    .{},
                    null,
                );
                return error.AnalysisFail;
            }
            break :blk index_data.elem_type;
        } else if (base.is(self.instructions.items, &.{.field_access})) {
            const field_data = self.instructions.items[base.toIndex().?].data.field_access;
            const struct_member_data = self.instructions.items[field_data.field.toIndex().?].data.struct_member;
            if (!struct_member_data.type.is(self.instructions.items, &.{.array_type})) {
                try self.errors.add(
                    self.tree.nodeLoc(self.tree.nodeRHS(node)),
                    "cannot access index of a non-array variable",
                    .{},
                    null,
                );
                return error.AnalysisFail;
            }
            break :blk struct_member_data.type;
        } else {
            try self.errors.add(
                self.tree.nodeLoc(self.tree.nodeLHS(node)),
                "expected array type",
                .{},
                null,
            );
            return error.AnalysisFail;
        }
    };

    const rhs = try self.genExpr(scope, self.tree.nodeRHS(node));
    const rhs_res = try self.resolve(rhs);
    if (rhs_res != null and rhs_res.?.isInteger(self.instructions.items)) {
        const inst_index = try self.addInst(.{
            .tag = .index_access,
            .data = .{
                .index_access = .{
                    .base = base,
                    .elem_type = self.instructions.items[base_array.toIndex().?].data.array_type.component_type,
                    .index = rhs,
                },
            },
        });
        return IR.Inst.toRef(inst_index);
    }

    try self.errors.add(
        self.tree.nodeLoc(self.tree.nodeRHS(node)),
        "index must be an integer",
        .{},
        null,
    );
    return error.AnalysisFail;
}

fn genFieldAccess(self: *AstGen, scope: *Scope, node: NodeIndex) !IR.Inst.Ref {
    const base = try self.genExpr(scope, self.tree.nodeLHS(node));
    const base_struct_ref = blk: {
        if (base.is(self.instructions.items, &.{.var_ref})) {
            const var_type = try self.resolveVarTypeOrValue(base);
            if (!var_type.is(self.instructions.items, &.{.struct_ref})) {
                try self.errors.add(
                    self.tree.nodeLoc(node),
                    "expected struct type",
                    .{},
                    null,
                );
                return error.AnalysisFail;
            }
            break :blk var_type;
        } else if (base.is(self.instructions.items, &.{.index_access})) {
            const index_data = self.instructions.items[base.toIndex().?].data.index_access;
            if (!index_data.elem_type.is(self.instructions.items, &.{.struct_ref})) {
                try self.errors.add(
                    self.tree.nodeLoc(node),
                    "expected struct type",
                    .{},
                    null,
                );
                return error.AnalysisFail;
            }
            break :blk index_data.elem_type;
        } else if (base.is(self.instructions.items, &.{.field_access})) {
            const field_data = self.instructions.items[base.toIndex().?].data.field_access;
            const struct_member_data = self.instructions.items[field_data.field.toIndex().?].data.struct_member;
            if (!struct_member_data.type.is(self.instructions.items, &.{.struct_ref})) {
                try self.errors.add(
                    self.tree.nodeLoc(node),
                    "expected struct type",
                    .{},
                    null,
                );
                return error.AnalysisFail;
            }
            break :blk struct_member_data.type;
        } else unreachable;
    };
    const base_struct = self.instructions.items[base_struct_ref.toIndex().?].data.ref;
    const struct_members = self.instructions.items[base_struct.toIndex().?].data.struct_decl.members;
    for (std.mem.sliceTo(self.refs.items[struct_members..], .none)) |member| {
        const member_data = self.instructions.items[member.toIndex().?].data.struct_member;
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
            return IR.Inst.toRef(inst_index);
        }
    }

    try self.errors.add(
        self.tree.nodeLoc(node),
        "struct '{s}' has no member named '{s}'",
        .{
            std.mem.sliceTo(self.strings.items[self.instructions.items[base_struct.toIndex().?].data.struct_decl.name..], 0),
            self.tree.tokenLoc(self.tree.nodeRHS(node)).slice(self.tree.source),
        },
        null,
    );
    return error.AnalysisFail;
}

pub fn genExpr(self: *AstGen, scope: *Scope, node: NodeIndex) !IR.Inst.Ref {
    const node_tag = self.tree.nodeTag(node);
    switch (node_tag) {
        .number_literal => return self.genNumber(node),
        .bool_true => return .true_literal,
        .bool_false => return .false_literal,
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
        .binary_and,
        .binary_or,
        .binary_xor,
        .circuit_and,
        .circuit_or,
        .equal,
        .not_equal,
        .less,
        .less_equal,
        .greater,
        .greater_equal,
        => return self.genBinary(scope, node),
        .index_access => return self.genIndexAccess(scope, node),
        .field_access => return self.genFieldAccess(scope, node),
        .bitcast => return self.genBitcast(scope, node),
        .ident_expr => return self.genIdent(scope, node),
        // TODO: call expr
        else => unreachable,
    }
}

fn genNumber(self: *AstGen, node: NodeIndex) !IR.Inst.Ref {
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

    var inst: IR.Inst = undefined;
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
            .tag = .float_literal,
            .data = .{
                .float_literal = .{
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
            .tag = .integer_literal,
            .data = .{
                .integer_literal = .{
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
    return IR.Inst.toRef(try self.addInst(inst));
}

pub fn addString(self: *AstGen, str: []const u8) error{OutOfMemory}!u32 {
    const len = str.len + 1;
    try self.strings.ensureUnusedCapacity(self.allocator, len);
    self.strings.appendSliceAssumeCapacity(str);
    self.strings.appendAssumeCapacity('\x00');
    return @intCast(u32, self.strings.items.len - len);
}

pub fn addRefList(self: *AstGen, list: []const IR.Inst.Ref) error{OutOfMemory}!u32 {
    const len = list.len + 1;
    try self.refs.ensureUnusedCapacity(self.allocator, len);
    self.refs.appendSliceAssumeCapacity(list);
    self.refs.appendAssumeCapacity(.none);
    return @intCast(u32, self.refs.items.len - len);
}

pub fn reserveInst(self: *AstGen) error{OutOfMemory}!IR.Inst.Index {
    try self.instructions.append(self.allocator, undefined);
    return @intCast(IR.Inst.Index, self.instructions.items.len - 1);
}

pub fn addInst(self: *AstGen, inst: IR.Inst) error{OutOfMemory}!IR.Inst.Index {
    try self.instructions.append(self.allocator, inst);
    return @intCast(IR.Inst.Index, self.instructions.items.len - 1);
}

pub fn genType(self: *AstGen, scope: *Scope, node: NodeIndex) error{ AnalysisFail, OutOfMemory }!IR.Inst.Ref {
    return switch (self.tree.nodeTag(node)) {
        .bool_type => try self.genBoolType(node),
        .number_type => try self.genNumberType(node),
        .vector_type => try self.genVectorType(scope, node),
        .matrix_type => try self.genMatrixType(scope, node),
        .atomic_type => try self.genAtomicType(scope, node),
        .array_type => try self.genArrayType(scope, node),
        .ptr_type => try self.genPtrType(scope, node),
        .ident_expr => {
            const node_loc = self.tree.nodeLoc(node);
            const decl_ref = try self.findSymbol(scope, self.tree.nodeToken(node));
            switch (decl_ref) {
                .bool_type,
                .i32_type,
                .u32_type,
                .f32_type,
                .f16_type,
                .sampler_type,
                .comparison_sampler_type,
                .external_sampled_texture_type,
                => return decl_ref,
                .none, .true_literal, .false_literal => unreachable,
                _ => switch (self.instructions.items[decl_ref.toIndex().?].tag) {
                    .vector_type,
                    .matrix_type,
                    .atomic_type,
                    .array_type,
                    .ptr_type,
                    .sampled_texture_type,
                    .multisampled_texture_type,
                    .storage_texture_type,
                    .depth_texture_type,
                    => return decl_ref,
                    .struct_decl => return IR.Inst.toRef(try self.addInst(.{ .tag = .struct_ref, .data = .{ .ref = decl_ref } })),
                    .global_variable_decl, .global_const_decl => {
                        try self.errors.add(
                            node_loc,
                            "'{s}' is not a type",
                            .{node_loc.slice(self.tree.source)},
                            null,
                        );
                        return error.AnalysisFail;
                    },
                    else => unreachable,
                },
            }
        },
        .sampler_type => try self.genSamplerType(node),
        .sampled_texture_type => try self.genSampledTextureType(scope, node),
        .multisampled_texture_type => try self.genMultigenSampledTextureType(scope, node),
        .storage_texture_type => try self.genStorageTextureType(node),
        .depth_texture_type => try self.genDepthTextureType(node),
        .external_texture_type => try self.genExternalTextureType(node),
        else => unreachable,
    };
}

pub fn genSampledTextureType(self: *AstGen, scope: *Scope, node: NodeIndex) !IR.Inst.Ref {
    std.debug.assert(self.tree.nodeTag(node) == .sampled_texture_type);

    const inst = try self.reserveInst();
    const component_type_node = self.tree.nodeLHS(node);
    const component_type_ref = try self.genType(scope, component_type_node);

    switch (component_type_ref) {
        .i32_type,
        .u32_type,
        .f32_type,
        => {},
        .bool_type,
        .f16_type,
        .sampler_type,
        .comparison_sampler_type,
        .external_sampled_texture_type,
        => {
            try self.errors.add(
                self.tree.nodeLoc(component_type_node),
                "invalid sampled texture component type",
                .{},
                try self.errors.createNote(
                    null,
                    "must be 'i32', 'u32' or 'f32'",
                    .{},
                ),
            );
            return error.AnalysisFail;
        },
        .none, .true_literal, .false_literal => unreachable,
        _ => switch (self.instructions.items[component_type_ref.toIndex().?].tag) {
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
            => {
                try self.errors.add(
                    self.tree.nodeLoc(component_type_node),
                    "invalid sampled texture component type",
                    .{},
                    try self.errors.createNote(
                        null,
                        "must be 'i32', 'u32' or 'f32'",
                        .{},
                    ),
                );
                return error.AnalysisFail;
            },
            else => unreachable,
        },
    }

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
                .component_type = component_type_ref,
            },
        },
    };
    return IR.Inst.toRef(inst);
}

pub fn genMultigenSampledTextureType(self: *AstGen, scope: *Scope, node: NodeIndex) !IR.Inst.Ref {
    std.debug.assert(self.tree.nodeTag(node) == .multisampled_texture_type);

    const inst = try self.reserveInst();
    const component_type_node = self.tree.nodeLHS(node);
    const component_type_ref = try self.genType(scope, component_type_node);

    switch (component_type_ref) {
        .i32_type,
        .u32_type,
        .f32_type,
        => {},
        .bool_type,
        .f16_type,
        .sampler_type,
        .comparison_sampler_type,
        .external_sampled_texture_type,
        => {
            try self.errors.add(
                self.tree.nodeLoc(component_type_node),
                "invalid multisampled texture component type",
                .{},
                try self.errors.createNote(
                    null,
                    "must be 'i32', 'u32' or 'f32'",
                    .{},
                ),
            );
            return error.AnalysisFail;
        },
        .none, .true_literal, .false_literal => unreachable,
        _ => switch (self.instructions.items[component_type_ref.toIndex().?].tag) {
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
            => {
                try self.errors.add(
                    self.tree.nodeLoc(component_type_node),
                    "invalid multisampled texture component type",
                    .{},
                    try self.errors.createNote(
                        null,
                        "must be 'i32', 'u32' or 'f32'",
                        .{},
                    ),
                );
                return error.AnalysisFail;
            },
            else => unreachable,
        },
    }

    const token_tag = self.tree.tokenTag(self.tree.nodeToken(node));
    self.instructions.items[inst] = .{
        .tag = .multisampled_texture_type,
        .data = .{
            .multisampled_texture_type = .{
                .kind = switch (token_tag) {
                    .k_texture_multisampled_2d => .@"2d",
                    else => unreachable,
                },
                .component_type = component_type_ref,
            },
        },
    };

    return IR.Inst.toRef(inst);
}

pub fn genStorageTextureType(self: *AstGen, node: NodeIndex) !IR.Inst.Ref {
    std.debug.assert(self.tree.nodeTag(node) == .storage_texture_type);

    const node_lhs = self.tree.nodeLHS(node);
    const texel_format_loc = self.tree.nodeLoc(node_lhs);
    const ast_texel_format = std.meta.stringToEnum(Ast.TexelFormat, texel_format_loc.slice(self.tree.source)).?;
    const texel_format: IR.Inst.StorageTextureType.TexelFormat = switch (ast_texel_format) {
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
    const access_mode_full = std.meta.stringToEnum(Ast.AccessMode, access_mode_loc.slice(self.tree.source)).?;
    const access_mode = switch (access_mode_full) {
        .write => IR.Inst.StorageTextureType.AccessMode.write,
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

    return IR.Inst.toRef(inst);
}

pub fn genDepthTextureType(self: *AstGen, node: NodeIndex) !IR.Inst.Ref {
    std.debug.assert(self.tree.nodeTag(node) == .depth_texture_type);

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
    return IR.Inst.toRef(inst);
}

pub fn genExternalTextureType(self: *AstGen, node: NodeIndex) !IR.Inst.Ref {
    std.debug.assert(self.tree.nodeTag(node) == .external_texture_type);
    return .external_sampled_texture_type;
}

pub fn genBoolType(self: *AstGen, node: NodeIndex) !IR.Inst.Ref {
    std.debug.assert(self.tree.nodeTag(node) == .bool_type);
    return .bool_type;
}

pub fn genNumberType(self: *AstGen, node: NodeIndex) !IR.Inst.Ref {
    std.debug.assert(self.tree.nodeTag(node) == .number_type);

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

pub fn genSamplerType(self: *AstGen, node: NodeIndex) !IR.Inst.Ref {
    std.debug.assert(self.tree.nodeTag(node) == .sampler_type);

    const token = self.tree.nodeToken(node);
    const token_tag = self.tree.tokenTag(token);
    return switch (token_tag) {
        .k_sampler => .sampler_type,
        .k_sampler_comparison => .comparison_sampler_type,
        else => unreachable,
    };
}

pub fn genVectorType(self: *AstGen, scope: *Scope, node: NodeIndex) !IR.Inst.Ref {
    std.debug.assert(self.tree.nodeTag(node) == .vector_type);

    const inst = try self.reserveInst();
    const component_type_node = self.tree.nodeLHS(node);
    const component_type_ref = try self.genType(scope, component_type_node);

    switch (component_type_ref) {
        .bool_type, .i32_type, .u32_type, .f32_type, .f16_type => {},
        .sampler_type, .comparison_sampler_type, .external_sampled_texture_type => {
            try self.errors.add(
                self.tree.nodeLoc(component_type_node),
                "invalid vector component type",
                .{},
                try self.errors.createNote(
                    null,
                    "must be 'i32', 'u32', 'f32', 'f16' or 'bool'",
                    .{},
                ),
            );
            return error.AnalysisFail;
        },
        .none, .true_literal, .false_literal => unreachable,
        _ => switch (self.instructions.items[component_type_ref.toIndex().?].tag) {
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
            => {
                try self.errors.add(
                    self.tree.nodeLoc(component_type_node),
                    "invalid vector component type",
                    .{},
                    try self.errors.createNote(
                        null,
                        "must be 'i32', 'u32', 'f32', 'f16' or 'bool'",
                        .{},
                    ),
                );
                return error.AnalysisFail;
            },
            else => unreachable,
        },
    }

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
                .component_type = component_type_ref,
            },
        },
    };

    return IR.Inst.toRef(inst);
}

pub fn genMatrixType(self: *AstGen, scope: *Scope, node: NodeIndex) !IR.Inst.Ref {
    std.debug.assert(self.tree.nodeTag(node) == .matrix_type);

    const inst = try self.reserveInst();
    const component_type_node = self.tree.nodeLHS(node);
    const component_type_ref = try self.genType(scope, component_type_node);

    switch (component_type_ref) {
        .f32_type,
        .f16_type,
        => {},
        .bool_type,
        .i32_type,
        .u32_type,
        .sampler_type,
        .comparison_sampler_type,
        .external_sampled_texture_type,
        => {
            try self.errors.add(
                self.tree.nodeLoc(component_type_node),
                "invalid matrix component type",
                .{},
                try self.errors.createNote(
                    null,
                    "must be 'f32' or 'f16'",
                    .{},
                ),
            );
            return error.AnalysisFail;
        },
        .none, .true_literal, .false_literal => unreachable,
        _ => switch (self.instructions.items[component_type_ref.toIndex().?].tag) {
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
            => {
                try self.errors.add(
                    self.tree.nodeLoc(component_type_node),
                    "invalid matrix component type",
                    .{},
                    try self.errors.createNote(
                        null,
                        "must be 'f32' or 'f16'",
                        .{},
                    ),
                );
                return error.AnalysisFail;
            },
            else => unreachable,
        },
    }

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
                .component_type = component_type_ref,
            },
        },
    };

    return IR.Inst.toRef(inst);
}

pub fn genAtomicType(self: *AstGen, scope: *Scope, node: NodeIndex) !IR.Inst.Ref {
    std.debug.assert(self.tree.nodeTag(node) == .atomic_type);

    const inst = try self.reserveInst();
    const component_type_node = self.tree.nodeLHS(node);
    const component_type_ref = try self.genType(scope, component_type_node);

    switch (component_type_ref) {
        .i32_type,
        .u32_type,
        => {},
        .bool_type,
        .f32_type,
        .f16_type,
        .sampler_type,
        .comparison_sampler_type,
        .external_sampled_texture_type,
        => {
            try self.errors.add(
                self.tree.nodeLoc(component_type_node),
                "invalid atomic component type",
                .{},
                try self.errors.createNote(
                    null,
                    "must be 'i32' or 'u32'",
                    .{},
                ),
            );
            return error.AnalysisFail;
        },
        .none, .true_literal, .false_literal => unreachable,
        _ => switch (self.instructions.items[component_type_ref.toIndex().?].tag) {
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
            => {
                try self.errors.add(
                    self.tree.nodeLoc(component_type_node),
                    "invalid atomic component type",
                    .{},
                    try self.errors.createNote(
                        null,
                        "must be 'i32' or 'u32'",
                        .{},
                    ),
                );
                return error.AnalysisFail;
            },
            else => unreachable,
        },
    }

    self.instructions.items[inst] = .{
        .tag = .atomic_type,
        .data = .{ .atomic_type = .{ .component_type = component_type_ref } },
    };

    return IR.Inst.toRef(inst);
}

pub fn genArrayType(self: *AstGen, scope: *Scope, node: NodeIndex) !IR.Inst.Ref {
    std.debug.assert(self.tree.nodeTag(node) == .array_type);

    const inst = try self.reserveInst();
    const component_type_node = self.tree.nodeLHS(node);
    const component_type_ref = try self.genType(scope, component_type_node);

    switch (component_type_ref) {
        .bool_type,
        .i32_type,
        .u32_type,
        .f32_type,
        .f16_type,
        => {},
        .sampler_type,
        .comparison_sampler_type,
        .external_sampled_texture_type,
        => {
            try self.errors.add(
                self.tree.nodeLoc(component_type_node),
                "invalid array component type",
                .{},
                null,
            );
            return error.AnalysisFail;
        },
        .none, .true_literal, .false_literal => unreachable,
        _ => switch (self.instructions.items[component_type_ref.toIndex().?].tag) {
            .vector_type,
            .matrix_type,
            .atomic_type,
            .struct_ref,
            => {},
            .array_type => {
                if (self.instructions.items[component_type_ref.toIndex().?].data.array_type.size == .none) {
                    try self.errors.add(
                        self.tree.nodeLoc(component_type_node),
                        "array componet type can not be a runtime-sized array",
                        .{},
                        null,
                    );
                    return error.AnalysisFail;
                }
            },
            .ptr_type,
            .sampled_texture_type,
            .multisampled_texture_type,
            .storage_texture_type,
            .depth_texture_type,
            => {
                try self.errors.add(
                    self.tree.nodeLoc(component_type_node),
                    "invalid array component type",
                    .{},
                    null,
                );
                return error.AnalysisFail;
            },
            else => unreachable,
        },
    }

    const size_node = self.tree.nodeRHS(node);
    var size_ref = IR.Inst.Ref.none;
    if (size_node != null_node) {
        size_ref = try self.genExpr(scope, size_node);
    }

    self.instructions.items[inst] = .{
        .tag = .array_type,
        .data = .{
            .array_type = .{
                .component_type = component_type_ref,
                .size = size_ref,
            },
        },
    };

    return IR.Inst.toRef(inst);
}

pub fn genPtrType(self: *AstGen, scope: *Scope, node: NodeIndex) !IR.Inst.Ref {
    std.debug.assert(self.tree.nodeTag(node) == .ptr_type);

    const inst = try self.reserveInst();
    const component_type_node = self.tree.nodeLHS(node);
    const component_type_ref = try self.genType(scope, component_type_node);

    switch (component_type_ref) {
        .bool_type,
        .i32_type,
        .u32_type,
        .f32_type,
        .f16_type,
        .sampler_type,
        .comparison_sampler_type,
        .external_sampled_texture_type,
        => {},
        .none, .true_literal, .false_literal => unreachable,
        _ => switch (self.instructions.items[component_type_ref.toIndex().?].tag) {
            .vector_type,
            .matrix_type,
            .atomic_type,
            .struct_ref,
            .array_type,
            .sampled_texture_type,
            .multisampled_texture_type,
            .storage_texture_type,
            .depth_texture_type,
            => {},
            .ptr_type => {
                try self.errors.add(
                    self.tree.nodeLoc(component_type_node),
                    "invalid array component type",
                    .{},
                    null,
                );
                return error.AnalysisFail;
            },
            else => unreachable,
        },
    }

    const gv = self.tree.extraData(Node.PtrType, self.tree.nodeRHS(node));

    const addr_space_loc = self.tree.tokenLoc(gv.addr_space);
    const ast_addr_space = std.meta.stringToEnum(Ast.AddressSpace, addr_space_loc.slice(self.tree.source)).?;
    const addr_space: IR.Inst.PointerType.AddressSpace = switch (ast_addr_space) {
        .function => .function,
        .private => .private,
        .workgroup => .workgroup,
        .uniform => .uniform,
        .storage => .storage,
    };

    var access_mode: IR.Inst.PointerType.AccessMode = .none;
    if (gv.access_mode != null_node) {
        const access_mode_loc = self.tree.tokenLoc(gv.access_mode);
        const ast_access_mode = std.meta.stringToEnum(Ast.AccessMode, access_mode_loc.slice(self.tree.source)).?;
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
                .component_type = component_type_ref,
                .addr_space = addr_space,
                .access_mode = access_mode,
            },
        },
    };

    return IR.Inst.toRef(inst);
}

fn resolve(self: *AstGen, ref: IR.Inst.Ref) !?IR.Inst.Ref {
    var in_deref = false;
    var in_decl = false;
    var r = ref;

    while (true) {
        if (in_decl and r.isType(self.instructions.items)) {
            return r;
        } else if (r.isLiteral(self.instructions.items)) {
            return r;
        } else if (r.is(self.instructions.items, &.{
            .circuit_and,
            .circuit_or,
            .equal,
            .not_equal,
            .less,
            .less_equal,
            .greater,
            .greater_equal,
            .not,
        })) {
            return .bool_type;
        } else if (r.is(self.instructions.items, &.{
            .mul,
            .div,
            .mod,
            .add,
            .sub,
            .shift_left,
            .shift_right,
            .binary_and,
            .binary_or,
            .binary_xor,
        })) {
            const inst = self.instructions.items[r.toIndex().?];
            r = inst.data.binary.lhs; // TODO
        } else if (r.is(self.instructions.items, &.{.negate})) {
            const inst = self.instructions.items[r.toIndex().?];
            r = inst.data.ref;
        } else if (r.is(self.instructions.items, &.{.deref})) {
            in_deref = true;
            const inst = self.instructions.items[r.toIndex().?];
            r = inst.data.ref;
        } else if (r.is(self.instructions.items, &.{.var_ref})) {
            in_decl = true;
            r = try self.resolveVarTypeOrValue(r);
            if (in_deref) {
                r = self.instructions.items[r.toIndex().?].data.ptr_type.component_type;
            }
        } else {
            return null;
        }
    }
}

fn resolveVarTypeOrValue(self: *AstGen, ref: IR.Inst.Ref) !IR.Inst.Ref {
    var r = ref;
    const inst = self.instructions.items[r.toIndex().?];
    const var_inst = self.instructions.items[inst.data.ref.toIndex().?];

    const resolved = try self.resolved_refs.getOrPut(self.allocator, inst.data.ref);
    if (resolved.found_existing) return resolved.value_ptr.*;

    switch (var_inst.tag) {
        .var_ref => return self.resolveVarTypeOrValue(var_inst.data.ref),
        .global_variable_decl => {
            const decl_type = var_inst.data.global_variable_decl.type;
            if (decl_type != .none) {
                r = decl_type;
            } else {
                r = var_inst.data.global_variable_decl.expr;
                if (r.is(self.instructions.items, &.{.var_ref})) {
                    r = try self.resolveVarTypeOrValue(r);
                }
            }
        },
        .global_const_decl => {
            const decl_type = var_inst.data.global_const_decl.type;
            if (decl_type != .none) {
                r = decl_type;
            } else {
                r = var_inst.data.global_const_decl.expr;
                if (r.is(self.instructions.items, &.{.var_ref})) {
                    r = try self.resolveVarTypeOrValue(r);
                }
            }
        },
        else => unreachable,
    }

    resolved.value_ptr.* = r;
    return r;
}
