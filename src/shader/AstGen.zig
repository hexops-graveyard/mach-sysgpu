const std = @import("std");
const Ast = @import("Ast.zig");
const Air = @import("Air.zig");
const ErrorList = @import("ErrorList.zig");
const Inst = Air.Inst;
const InstIndex = Air.InstIndex;
const RefIndex = Air.RefIndex;
const StringIndex = Air.StringIndex;
const ValueIndex = Air.ValueIndex;
const Node = Ast.Node;
const NodeIndex = Ast.NodeIndex;
const TokenIndex = Ast.TokenIndex;
const TokenTag = @import("Token.zig").Tag;
const Loc = @import("Token.zig").Loc;
const stringToEnum = std.meta.stringToEnum;

const AstGen = @This();

allocator: std.mem.Allocator,
tree: *const Ast,
instructions: std.AutoArrayHashMapUnmanaged(Inst, void) = .{},
refs: std.ArrayListUnmanaged(InstIndex) = .{},
strings: std.ArrayListUnmanaged(u8) = .{},
values: std.ArrayListUnmanaged(u8) = .{},
scratch: std.ArrayListUnmanaged(InstIndex) = .{},
compute_stage: InstIndex = .none,
vertex_stage: InstIndex = .none,
fragment_stage: InstIndex = .none,
entry_point_name: ?[]const u8 = null,
scope_pool: std.heap.MemoryPool(Scope),
errors: ErrorList,

pub const Scope = struct {
    tag: Tag,
    /// this is undefined if tag == .root
    parent: *Scope,
    decls: std.AutoHashMapUnmanaged(NodeIndex, error{AnalysisFail}!InstIndex) = .{},

    const Tag = union(enum) {
        root,
        @"fn": struct {
            return_type: InstIndex,
            returned: bool,
        },
        block,
        loop,
        continuing,
        switch_case,
        @"if",
        @"for",
    };
};

pub fn genTranslationUnit(astgen: *AstGen) !RefIndex {
    const scratch_top = astgen.scratch.items.len;
    defer astgen.scratch.shrinkRetainingCapacity(scratch_top);

    var root_scope = try astgen.scope_pool.create();
    root_scope.* = .{ .tag = .root, .parent = undefined };

    const global_nodes = astgen.tree.spanToList(.globals);
    astgen.scanDecls(root_scope, global_nodes) catch |err| switch (err) {
        error.AnalysisFail => return astgen.addRefList(astgen.scratch.items[scratch_top..]),
        error.OutOfMemory => return error.OutOfMemory,
    };

    for (global_nodes) |node| {
        var global = root_scope.decls.get(node).? catch continue;
        if (global == .none) {
            // declaration has not analysed
            global = astgen.genGlobalDecl(root_scope, node) catch |err| switch (err) {
                error.AnalysisFail => continue,
                error.OutOfMemory => return error.OutOfMemory,
            };
        }

        try astgen.scratch.append(astgen.allocator, global);
    }

    if (astgen.entry_point_name != null and
        astgen.compute_stage == .none and
        astgen.vertex_stage == .none and
        astgen.fragment_stage == .none)
    {
        try astgen.errors.add(Loc{ .start = 0, .end = 1 }, "entry point not found", .{}, null);
    }

    return astgen.addRefList(astgen.scratch.items[scratch_top..]);
}

/// adds `nodes` to scope and checks for re-declarations
fn scanDecls(astgen: *AstGen, scope: *Scope, nodes: []const NodeIndex) !void {
    for (nodes) |decl_node| {
        const loc = astgen.tree.declNameLoc(decl_node) orelse continue;
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

        try scope.decls.putNoClobber(astgen.scope_pool.arena.allocator(), decl_node, .none);
    }
}

fn genGlobalDecl(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const decl = switch (astgen.tree.nodeTag(node)) {
        .global_var => astgen.genGlobalVar(scope, node),
        .override => astgen.genOverride(scope, node),
        .@"const" => astgen.genConst(scope, node),
        .@"struct" => astgen.genStruct(scope, node),
        .@"fn" => astgen.genFn(scope, node),
        .type_alias => astgen.genTypeAlias(scope, node),
        else => unreachable,
    } catch |err| {
        if (err == error.AnalysisFail) {
            scope.decls.putAssumeCapacity(node, error.AnalysisFail);
        }
        return err;
    };

    scope.decls.putAssumeCapacity(node, decl);
    return decl;
}

fn genGlobalVar(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_rhs = astgen.tree.nodeRHS(node);
    const extra = astgen.tree.extraData(Node.GlobalVar, astgen.tree.nodeLHS(node));
    const name_loc = astgen.tree.declNameLoc(node).?;

    var is_resource = false;
    var var_type = InstIndex.none;
    if (extra.type != .none) {
        var_type = try astgen.genType(scope, extra.type);

        switch (astgen.getInst(var_type)) {
            .sampler_type,
            .comparison_sampler_type,
            .sampled_texture_type,
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

    var addr_space: ?Inst.PointerType.AddressSpace = null;
    if (extra.addr_space != .none) {
        const addr_space_loc = astgen.tree.tokenLoc(extra.addr_space);
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

    var access_mode: ?Inst.PointerType.AccessMode = null;
    if (extra.access_mode != .none) {
        const access_mode_loc = astgen.tree.tokenLoc(extra.access_mode);
        const ast_access_mode = stringToEnum(Ast.AccessMode, access_mode_loc.slice(astgen.tree.source)).?;
        access_mode = switch (ast_access_mode) {
            .read => .read,
            .write => .write,
            .read_write => .read_write,
        };
    }

    var binding = InstIndex.none;
    var group = InstIndex.none;
    if (extra.attrs != .none) {
        for (astgen.tree.spanToList(extra.attrs)) |attr| {
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

    if (is_resource and (binding == .none or group == .none)) {
        try astgen.errors.add(
            astgen.tree.nodeLoc(node),
            "resource variable must specify binding and group",
            .{},
            null,
        );
        return error.AnalysisFail;
    }

    var expr = InstIndex.none;
    if (node_rhs != .none) {
        expr = try astgen.genExpr(scope, node_rhs);
    }

    const name = try astgen.addString(name_loc.slice(astgen.tree.source));
    return astgen.addInst(.{
        .global_var = .{
            .name = name,
            .type = var_type,
            .addr_space = addr_space,
            .access_mode = access_mode,
            .binding = binding,
            .group = group,
            .expr = expr,
        },
    });
}

fn genOverride(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_rhs = astgen.tree.nodeRHS(node);
    const extra = astgen.tree.extraData(Node.Override, astgen.tree.nodeLHS(node));
    const name_loc = astgen.tree.declNameLoc(node).?;

    var override_type = InstIndex.none;
    if (extra.type != .none) {
        override_type = try astgen.genType(scope, extra.type);
        switch (astgen.getInst(override_type)) {
            .bool => {},
            inline .int, .float => |num| {
                if (num.type == .abstract) {
                    try astgen.errors.add(
                        astgen.tree.nodeLoc(extra.type),
                        "only 'u32', 'i32', 'f32' and 'f16' types are allowed",
                        .{},
                        null,
                    );
                    return error.AnalysisFail;
                }
            },
            else => {},
        }
    }

    var id = InstIndex.none;
    if (extra.attrs != .none) {
        for (astgen.tree.spanToList(extra.attrs)) |attr| {
            switch (astgen.tree.nodeTag(attr)) {
                .attr_id => id = try astgen.attrId(scope, attr),
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

    var expr = InstIndex.none;
    if (node_rhs != .none) {
        expr = try astgen.genExpr(scope, node_rhs);
    }

    const name = try astgen.addString(name_loc.slice(astgen.tree.source));
    return astgen.addInst(.{
        .override = .{
            .name = name,
            .type = override_type,
            .id = id,
            .expr = expr,
        },
    });
}

fn genStruct(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const name_str = astgen.tree.declNameLoc(node).?.slice(astgen.tree.source);
    const name = try astgen.addString(name_str);
    const members = try astgen.genStructMembers(scope, astgen.tree.nodeLHS(node));
    return astgen.addInst(.{
        .@"struct" = .{
            .name = name,
            .members = members,
        },
    });
}

fn genStructMembers(astgen: *AstGen, scope: *Scope, node: NodeIndex) !RefIndex {
    const scratch_top = astgen.scratch.items.len;
    defer astgen.scratch.shrinkRetainingCapacity(scratch_top);

    const member_nodes_list = astgen.tree.spanToList(node);
    for (member_nodes_list, 0..) |member_node, i| {
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
            .array,
            .atomic_type,
            .struct_ref,
            => {},
            inline .bool, .int, .float, .vector, .matrix => |data| {
                std.debug.assert(data.value == null);
            },
            else => {
                try astgen.errors.add(
                    member_name_loc,
                    "invalid struct member type '{s}'",
                    .{member_type_loc.slice(astgen.tree.source)},
                    null,
                );
                return error.AnalysisFail;
            },
        }

        if (member_type_inst == .array) {
            const array_len = member_type_inst.array.len;
            if (array_len == .none and i + 1 != member_nodes_list.len) {
                try astgen.errors.add(
                    member_name_loc,
                    "struct member with runtime-sized array type, must be the last member of the structure",
                    .{},
                    null,
                );
                return error.AnalysisFail;
            }
        }

        var @"align": ?u29 = null;
        var size: ?u32 = null;
        var builtin: Inst.Builtin = .none;
        var location = InstIndex.none;
        var interpolate: ?Inst.Interpolate = null;
        if (member_attrs_node != .none) {
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
        const member = try astgen.addInst(.{
            .struct_member = .{
                .name = name,
                .type = member_type,
                .@"align" = @"align",
                .size = size,
                .builtin = builtin,
                .location = location,
                .interpolate = interpolate,
            },
        });
        try astgen.scratch.append(astgen.allocator, member);
    }

    return astgen.addRefList(astgen.scratch.items[scratch_top..]);
}

fn genFn(astgen: *AstGen, root_scope: *Scope, node: NodeIndex) !InstIndex {
    const fn_proto = astgen.tree.extraData(Node.FnProto, astgen.tree.nodeLHS(node));
    const node_rhs = astgen.tree.nodeRHS(node);
    const node_loc = astgen.tree.nodeLoc(node);

    var return_type = InstIndex.none;
    var return_attrs = Inst.Fn.ReturnAttrs{
        .builtin = .none,
        .location = .none,
        .interpolate = null,
        .invariant = false,
    };
    if (fn_proto.return_type != .none) {
        return_type = try astgen.genType(root_scope, fn_proto.return_type);

        if (fn_proto.return_attrs != .none) {
            for (astgen.tree.spanToList(fn_proto.return_attrs)) |attr| {
                switch (astgen.tree.nodeTag(attr)) {
                    .attr_invariant => return_attrs.invariant = true,
                    .attr_location => return_attrs.location = try astgen.attrLocation(root_scope, attr),
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

    var stage: Inst.Fn.Stage = .none;
    var workgroup_size_attr = NodeIndex.none;
    var is_const = false;
    if (fn_proto.attrs != .none) {
        for (astgen.tree.spanToList(fn_proto.attrs)) |attr| {
            switch (astgen.tree.nodeTag(attr)) {
                .attr_vertex,
                .attr_fragment,
                .attr_compute,
                => |stage_attr| {
                    if (stage != .none) {
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
        if (return_type != .none) {
            try astgen.errors.add(
                astgen.tree.nodeLoc(fn_proto.return_type),
                "return type on compute function",
                .{},
                null,
            );
            return error.AnalysisFail;
        }

        if (workgroup_size_attr == .none) {
            try astgen.errors.add(
                node_loc,
                "@workgroup_size not specified on compute shader",
                .{},
                null,
            );
            return error.AnalysisFail;
        }

        const workgroup_size_data = astgen.tree.extraData(Ast.Node.WorkgroupSize, astgen.tree.nodeLHS(workgroup_size_attr));
        stage.compute = Inst.Fn.Stage.WorkgroupSize{
            .x = blk: {
                const x = try astgen.genExpr(root_scope, workgroup_size_data.x);
                if (try astgen.resolveConstExpr(x) == null) {
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
                if (workgroup_size_data.y == .none) break :blk .none;

                const y = try astgen.genExpr(root_scope, workgroup_size_data.y);
                if (try astgen.resolveConstExpr(y) == null) {
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
                if (workgroup_size_data.z == .none) break :blk .none;

                const z = try astgen.genExpr(root_scope, workgroup_size_data.z);
                if (try astgen.resolveConstExpr(z) == null) {
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
    } else if (workgroup_size_attr != .none) {
        try astgen.errors.add(
            node_loc,
            "@workgroup_size must be specified with a compute shader",
            .{},
            null,
        );
        return error.AnalysisFail;
    }

    var scope = try astgen.scope_pool.create();
    scope.* = .{
        .tag = .{
            .@"fn" = .{
                .return_type = return_type,
                .returned = false,
            },
        },
        .parent = root_scope,
    };

    var params = RefIndex.none;
    if (fn_proto.params != .none) {
        params = try astgen.genFnParams(scope, fn_proto.params);
    }

    const name_slice = astgen.tree.declNameLoc(node).?.slice(astgen.tree.source);
    const name = try astgen.addString(name_slice);
    const block = try astgen.genBlock(scope, node_rhs);

    if (return_type != .none and !scope.tag.@"fn".returned) {
        try astgen.errors.add(node_loc, "function does not return", .{}, null);
        return error.AnalysisFail;
    }

    const inst = try astgen.addInst(.{
        .@"fn" = .{
            .name = name,
            .stage = stage,
            .is_const = is_const,
            .params = params,
            .return_type = return_type,
            .return_attrs = return_attrs,
            .block = block,
        },
    });

    if (astgen.entry_point_name) |entry_point_name| {
        if (std.mem.eql(u8, name_slice, entry_point_name)) {
            astgen.compute_stage = .none;
            astgen.vertex_stage = .none;
            astgen.fragment_stage = .none;
            if (stage == .none) {
                try astgen.errors.add(node_loc, "function is not an entry point", .{}, null);
                return error.AnalysisFail;
            }
        }
    }

    switch (stage) {
        .none => {},
        .compute => astgen.compute_stage = inst,
        .vertex => astgen.vertex_stage = inst,
        .fragment => astgen.fragment_stage = inst,
    }

    return inst;
}

fn genTypeAlias(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    return astgen.genType(scope, node_lhs);
}

fn genFnParams(astgen: *AstGen, scope: *Scope, node: NodeIndex) !RefIndex {
    const scratch_top = astgen.scratch.items.len;
    defer astgen.scratch.shrinkRetainingCapacity(scratch_top);

    const param_nodes = astgen.tree.spanToList(node);
    try astgen.scanDecls(scope, param_nodes);

    for (param_nodes) |param_node| {
        const param_node_lhs = astgen.tree.nodeLHS(param_node);
        const param_name_loc = astgen.tree.tokenLoc(astgen.tree.nodeToken(param_node));
        const param_type_node = astgen.tree.nodeRHS(param_node);
        const param_type = astgen.genType(scope, param_type_node) catch |err| switch (err) {
            error.AnalysisFail => continue,
            error.OutOfMemory => return error.OutOfMemory,
        };

        var builtin = Inst.Builtin.none;
        var inter: ?Inst.Interpolate = null;
        var location = InstIndex.none;
        var invariant = false;

        if (param_node_lhs != .none) {
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
        const param = try astgen.addInst(.{
            .fn_param = .{
                .name = name,
                .type = param_type,
                .builtin = builtin,
                .interpolate = inter,
                .location = location,
                .invariant = invariant,
            },
        });
        try astgen.scratch.append(astgen.allocator, param);
        scope.decls.putAssumeCapacity(param_node, param);
    }

    return astgen.addRefList(astgen.scratch.items[scratch_top..]);
}

fn attrBinding(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    const node_lhs_loc = astgen.tree.nodeLoc(node_lhs);
    const binding = try astgen.genExpr(scope, node_lhs);

    if (try astgen.resolveConstExpr(binding) == null) {
        try astgen.errors.add(
            node_lhs_loc,
            "expected const-expression, found '{s}'",
            .{node_lhs_loc.slice(astgen.tree.source)},
            null,
        );
        return error.AnalysisFail;
    }

    const binding_res = try astgen.resolve(binding);
    if (astgen.getInst(binding_res) != .int) {
        try astgen.errors.add(
            node_lhs_loc,
            "binding value must be integer",
            .{},
            null,
        );
        return error.AnalysisFail;
    }

    if (astgen.getValue(Inst.Int.Value, astgen.getInst(binding_res).int.value.?).literal.value < 0) {
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

fn attrId(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    const node_lhs_loc = astgen.tree.nodeLoc(node_lhs);
    const id = try astgen.genExpr(scope, node_lhs);

    if (try astgen.resolveConstExpr(id) == null) {
        try astgen.errors.add(
            node_lhs_loc,
            "expected const-expression, found '{s}'",
            .{node_lhs_loc.slice(astgen.tree.source)},
            null,
        );
        return error.AnalysisFail;
    }

    const id_res = try astgen.resolve(id);
    if (astgen.getInst(id_res) != .int) {
        try astgen.errors.add(
            node_lhs_loc,
            "id value must be integer",
            .{},
            null,
        );
        return error.AnalysisFail;
    }

    if (astgen.getValue(Inst.Int.Value, astgen.getInst(id_res).int.value.?).literal.value < 0) {
        try astgen.errors.add(
            node_lhs_loc,
            "id value must be a positive",
            .{},
            null,
        );
        return error.AnalysisFail;
    }

    return id;
}

fn attrGroup(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    const node_lhs_loc = astgen.tree.nodeLoc(node_lhs);
    const group = try astgen.genExpr(scope, node_lhs);

    if (try astgen.resolveConstExpr(group) == null) {
        try astgen.errors.add(
            node_lhs_loc,
            "expected const-expression, found '{s}'",
            .{node_lhs_loc.slice(astgen.tree.source)},
            null,
        );
        return error.AnalysisFail;
    }

    const group_res = try astgen.resolve(group);
    if (astgen.getInst(group_res) != .int) {
        try astgen.errors.add(
            node_lhs_loc,
            "group value must be integer",
            .{},
            null,
        );
        return error.AnalysisFail;
    }

    if (astgen.getValue(Inst.Int.Value, astgen.getInst(group_res).int.value.?).literal.value < 0) {
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
    if (try astgen.resolveConstExpr(expr)) |expr_res| {
        if (expr_res == .int) {
            return @intCast(u29, expr_res.int);
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
    if (try astgen.resolveConstExpr(expr)) |expr_res| {
        if (expr_res == .int) {
            return @intCast(u32, expr_res.int);
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
    const builtin_loc = astgen.tree.tokenLoc(astgen.tree.nodeLHS(node).asTokenIndex());
    const builtin_ast = stringToEnum(Ast.Builtin, builtin_loc.slice(astgen.tree.source)).?;
    return Inst.Builtin.fromAst(builtin_ast);
}

fn attrInterpolate(astgen: *AstGen, node: NodeIndex) Inst.Interpolate {
    const inter_type_token = astgen.tree.nodeLHS(node).asTokenIndex();
    const inter_type_loc = astgen.tree.tokenLoc(inter_type_token);
    const inter_type_ast = stringToEnum(Ast.InterpolationType, inter_type_loc.slice(astgen.tree.source)).?;

    var inter = Inst.Interpolate{
        .type = switch (inter_type_ast) {
            .perspective => .perspective,
            .linear => .linear,
            .flat => .flat,
        },
        .sample = .none,
    };

    if (astgen.tree.nodeRHS(node) != .none) {
        const inter_sample_token = astgen.tree.nodeRHS(node).asTokenIndex();
        const inter_sample_loc = astgen.tree.tokenLoc(inter_sample_token);
        const inter_sample_ast = stringToEnum(Ast.InterpolationSample, inter_sample_loc.slice(astgen.tree.source)).?;
        inter.sample = switch (inter_sample_ast) {
            .center => .center,
            .centroid => .centroid,
            .sample => .sample,
        };
    }

    return inter;
}

fn genBlock(astgen: *AstGen, scope: *Scope, node: NodeIndex) error{ OutOfMemory, AnalysisFail }!InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    if (node_lhs == .none) return .none;

    const stmnt_nodes = astgen.tree.spanToList(node_lhs);
    try astgen.scanDecls(scope, stmnt_nodes);

    const scratch_top = astgen.scratch.items.len;
    defer astgen.scratch.shrinkRetainingCapacity(scratch_top);

    var is_unreachable = false;
    for (stmnt_nodes) |stmnt_node| {
        const stmnt_node_loc = astgen.tree.nodeLoc(stmnt_node);
        if (is_unreachable) {
            try astgen.errors.add(stmnt_node_loc, "unreachable code", .{}, null);
            return error.AnalysisFail;
        }
        const stmnt = try astgen.genStatement(scope, stmnt_node);
        if (astgen.getInst(stmnt) == .@"return") {
            is_unreachable = true;
        }
        try astgen.scratch.append(astgen.allocator, stmnt);
    }

    const statements = try astgen.addRefList(astgen.scratch.items[scratch_top..]);
    return astgen.addInst(.{ .block = statements });
}

fn genStatement(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    return switch (astgen.tree.nodeTag(node)) {
        .compound_assign => try astgen.genCompoundAssign(scope, node),
        .phony_assign => try astgen.genPhonyAssign(scope, node),
        .call => try astgen.genFnCall(scope, node),
        .@"return" => try astgen.genReturn(scope, node),
        .break_if => try astgen.genBreakIf(scope, node),
        .@"if" => try astgen.genIf(scope, node),
        .if_else => try astgen.genIfElse(scope, node),
        .if_else_if => try astgen.genIfElseIf(scope, node),
        .@"while" => try astgen.genWhile(scope, node),
        .@"for" => try astgen.genFor(scope, node),
        .@"switch" => try astgen.genSwitch(scope, node),
        .loop => try astgen.genLoop(scope, node),
        .block => blk: {
            var inner_scope = try astgen.scope_pool.create();
            inner_scope.* = .{ .tag = .block, .parent = scope };
            const inner_block = try astgen.genBlock(inner_scope, node);
            break :blk inner_block;
        },
        .continuing => try astgen.genContinuing(scope, node),
        .discard => try astgen.addInst(.discard),
        .@"break" => try astgen.addInst(.@"break"),
        .@"continue" => try astgen.addInst(.@"continue"),
        .increase => try astgen.genIncreaseDecrease(scope, node, true),
        .decrease => try astgen.genIncreaseDecrease(scope, node, false),
        .@"var" => blk: {
            const decl = try astgen.genVar(scope, node);
            scope.decls.putAssumeCapacity(node, decl);
            break :blk decl;
        },
        .@"const" => blk: {
            const decl = try astgen.genConst(scope, node);
            scope.decls.putAssumeCapacity(node, decl);
            break :blk decl;
        },
        .let => blk: {
            const decl = try astgen.genLet(scope, node);
            scope.decls.putAssumeCapacity(node, decl);
            break :blk decl;
        },
        else => unreachable,
    };
}

fn genLoop(astgen: *AstGen, parent_scope: *Scope, node: NodeIndex) !InstIndex {
    var scope = try astgen.scope_pool.create();
    scope.* = .{ .tag = .loop, .parent = parent_scope };

    const block = try astgen.genBlock(scope, astgen.tree.nodeLHS(node));
    return astgen.addInst(.{ .loop = block });
}

fn genContinuing(astgen: *AstGen, parent_scope: *Scope, node: NodeIndex) !InstIndex {
    var scope = try astgen.scope_pool.create();
    scope.* = .{ .tag = .continuing, .parent = parent_scope };

    const block = try astgen.genBlock(scope, astgen.tree.nodeLHS(node));
    return astgen.addInst(.{ .continuing = block });
}

fn genBreakIf(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const expr = try astgen.genExpr(scope, astgen.tree.nodeLHS(node));
    return astgen.addInst(.{ .break_if = expr });
}

fn genIf(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    const node_rhs = astgen.tree.nodeRHS(node);
    const node_lhs_loc = astgen.tree.nodeLoc(node_lhs);

    const cond = try astgen.genExpr(scope, node_lhs);
    const cond_res = try astgen.resolve(cond);
    if (astgen.getInst(cond_res) != .bool) {
        try astgen.errors.add(node_lhs_loc, "expected bool", .{}, null);
        return error.AnalysisFail;
    }

    var body_scope = try astgen.scope_pool.create();
    body_scope.* = .{ .tag = .@"if", .parent = scope };
    const block = try astgen.genBlock(body_scope, node_rhs);

    return astgen.addInst(.{
        .@"if" = .{
            .cond = cond,
            .body = block,
            .@"else" = .none,
        },
    });
}

fn genIfElse(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const if_node = astgen.tree.nodeLHS(node);
    const cond = try astgen.genExpr(scope, astgen.tree.nodeLHS(if_node));

    var if_body_scope = try astgen.scope_pool.create();
    if_body_scope.* = .{ .tag = .@"if", .parent = scope };
    const if_block = try astgen.genBlock(if_body_scope, astgen.tree.nodeRHS(if_node));

    var else_body_scope = try astgen.scope_pool.create();
    else_body_scope.* = .{ .tag = .@"if", .parent = scope };
    const else_block = try astgen.genBlock(else_body_scope, astgen.tree.nodeRHS(node));

    return astgen.addInst(.{
        .@"if" = .{
            .cond = cond,
            .body = if_block,
            .@"else" = else_block,
        },
    });
}

fn genIfElseIf(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const if_node = astgen.tree.nodeLHS(node);
    const node_rhs = astgen.tree.nodeRHS(node);
    const cond = try astgen.genExpr(scope, astgen.tree.nodeLHS(if_node));
    const block = try astgen.genBlock(scope, astgen.tree.nodeRHS(if_node));
    const else_if = switch (astgen.tree.nodeTag(node_rhs)) {
        .@"if" => try astgen.genIf(scope, node_rhs),
        .if_else => try astgen.genIfElse(scope, node_rhs),
        .if_else_if => try astgen.genIfElseIf(scope, node_rhs),
        else => unreachable,
    };
    return astgen.addInst(.{
        .@"if" = .{
            .cond = cond,
            .body = block,
            .@"else" = else_if,
        },
    });
}

fn genWhile(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    const node_rhs = astgen.tree.nodeRHS(node);
    const node_lhs_loc = astgen.tree.nodeLoc(node_lhs);

    const cond = try astgen.genExpr(scope, node_lhs);
    const cond_res = try astgen.resolve(cond);
    if (astgen.getInst(cond_res) != .bool) {
        try astgen.errors.add(node_lhs_loc, "expected bool", .{}, null);
        return error.AnalysisFail;
    }

    const block = try astgen.genBlock(scope, node_rhs);
    return astgen.addInst(.{ .@"while" = .{ .lhs = cond, .rhs = block } });
}

fn genFor(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    const node_rhs = astgen.tree.nodeRHS(node);
    const extra = astgen.tree.extraData(Ast.Node.ForHeader, node_lhs);

    var for_scope = try astgen.scope_pool.create();
    for_scope.* = .{ .tag = .@"for", .parent = scope };

    try astgen.scanDecls(for_scope, &.{extra.init});
    const init = switch (astgen.tree.nodeTag(extra.init)) {
        .@"var" => try astgen.genVar(for_scope, extra.init),
        .@"const" => try astgen.genConst(for_scope, extra.init),
        .let => try astgen.genLet(for_scope, extra.init),
        else => unreachable,
    };
    scope.decls.putAssumeCapacity(extra.init, init);

    const cond_node_loc = astgen.tree.nodeLoc(extra.cond);
    const cond = try astgen.genExpr(for_scope, extra.cond);
    const cond_res = try astgen.resolve(cond);
    if (astgen.getInst(cond_res) != .bool) {
        try astgen.errors.add(cond_node_loc, "expected bool", .{}, null);
        return error.AnalysisFail;
    }

    const update = switch (astgen.tree.nodeTag(extra.update)) {
        .phony_assign => try astgen.genPhonyAssign(for_scope, extra.update),
        .increase => try astgen.genIncreaseDecrease(for_scope, extra.update, true),
        .decrease => try astgen.genIncreaseDecrease(for_scope, extra.update, false),
        .compound_assign => try astgen.genCompoundAssign(for_scope, extra.update),
        .call => try astgen.genFnCall(scope, extra.update),
        else => unreachable,
    };

    const block = try astgen.genBlock(for_scope, node_rhs);

    return astgen.addInst(.{
        .@"for" = .{
            .init = init,
            .cond = cond,
            .update = update,
            .body = block,
        },
    });
}

fn genSwitch(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const switch_on = try astgen.genExpr(scope, astgen.tree.nodeLHS(node));
    const switch_on_res = try astgen.resolve(switch_on);

    const scratch_top = astgen.scratch.items.len;
    defer astgen.scratch.shrinkRetainingCapacity(scratch_top);

    const cases_nodes = astgen.tree.spanToList(astgen.tree.nodeRHS(node));
    for (cases_nodes) |cases_node| {
        const cases_node_tag = astgen.tree.nodeTag(cases_node);

        var cases_scope = try astgen.scope_pool.create();
        cases_scope.* = .{ .tag = .switch_case, .parent = scope };

        var cases = RefIndex.none;
        const body = try astgen.genBlock(cases_scope, astgen.tree.nodeRHS(cases_node));
        var default = cases_node_tag == .switch_default or cases_node_tag == .switch_case_default;

        switch (cases_node_tag) {
            .switch_case, .switch_case_default => {
                const cases_scratch_top = astgen.scratch.items.len;
                defer astgen.scratch.shrinkRetainingCapacity(cases_scratch_top);

                const case_nodes = astgen.tree.spanToList(astgen.tree.nodeLHS(cases_node));
                for (case_nodes) |case_node| {
                    const case_node_loc = astgen.tree.nodeLoc(case_node);
                    const case = try astgen.genExpr(scope, case_node);
                    const case_res = try astgen.resolve(case);
                    if (!astgen.eql(switch_on_res, case_res)) {
                        try astgen.errors.add(case_node_loc, "switch and case type mismatch", .{}, null);
                        return error.AnalysisFail;
                    }
                    try astgen.scratch.append(astgen.allocator, case);
                }

                cases = try astgen.addRefList(astgen.scratch.items[scratch_top..]);
            },
            .switch_default => {},
            else => unreachable,
        }

        const case_inst = try astgen.addInst(.{
            .switch_case = .{
                .cases = cases,
                .body = body,
                .default = default,
            },
        });
        try astgen.scratch.append(astgen.allocator, case_inst);
    }

    const cases_list = try astgen.addRefList(astgen.scratch.items[scratch_top..]);
    return astgen.addInst(.{
        .@"switch" = .{
            .switch_on = switch_on,
            .cases_list = cases_list,
        },
    });
}

fn genCompoundAssign(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    const node_rhs = astgen.tree.nodeRHS(node);
    const lhs = try astgen.genExpr(scope, node_lhs);
    const rhs = try astgen.genExpr(scope, node_rhs);
    const lhs_type = try astgen.resolve(lhs);
    const rhs_type = try astgen.resolve(rhs);
    astgen.checkMutability(lhs) catch {
        try astgen.errors.add(astgen.tree.nodeLoc(node), "cannot assign to constant", .{}, null);
        return error.AnalysisFail;
    };

    if (!astgen.eql(lhs_type, rhs_type)) {
        try astgen.errors.add(astgen.tree.nodeLoc(node), "type mismatch", .{}, null);
        return error.AnalysisFail;
    }

    return astgen.addInst(switch (astgen.tree.tokenTag(astgen.tree.nodeToken(node))) {
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
    });
}

fn checkMutability(astgen: *AstGen, index: InstIndex) error{Immutable}!void {
    var idx = index;
    while (true) {
        const inst = astgen.getInst(idx);
        switch (inst) {
            .deref => idx = inst.deref,
            .var_ref => |var_ref| idx = var_ref,
            inline .field_access, .swizzle_access, .index_access => |access| idx = access.base,
            .@"const", .let, .override, .fn_param, .vector => return error.Immutable,
            .global_var, .@"var" => return,
            else => unreachable,
        }
    }
}

fn genPhonyAssign(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    const lhs = try astgen.genExpr(scope, node_lhs);
    return astgen.addInst(.{ .assign_phony = lhs });
}

fn genIncreaseDecrease(astgen: *AstGen, scope: *Scope, node: NodeIndex, increase: bool) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    const node_lhs_loc = astgen.tree.nodeLoc(node_lhs);

    const lhs = try astgen.genExpr(scope, node_lhs);
    if (astgen.getInst(lhs) != .var_ref) {
        try astgen.errors.add(node_lhs_loc, "expected a reference", .{}, null);
        return error.AnalysisFail;
    }

    const lhs_res = try astgen.resolve(lhs);
    if (astgen.getInst(lhs_res) != .int) {
        try astgen.errors.add(node_lhs_loc, "expected an integer", .{}, null);
        return error.AnalysisFail;
    }

    return astgen.addInst(if (increase) .{ .increase = lhs } else .{ .decrease = lhs });
}

fn genVar(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_rhs = astgen.tree.nodeRHS(node);
    const extra = astgen.tree.extraData(Node.Var, astgen.tree.nodeLHS(node));
    const name_loc = astgen.tree.declNameLoc(node).?;

    var is_resource = false;
    var var_type = InstIndex.none;
    if (extra.type != .none) {
        var_type = try astgen.genType(scope, extra.type);

        switch (astgen.getInst(var_type)) {
            .sampler_type,
            .comparison_sampler_type,
            .sampled_texture_type,
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

    var addr_space: ?Inst.PointerType.AddressSpace = null;
    if (extra.addr_space != .none) {
        const addr_space_loc = astgen.tree.tokenLoc(extra.addr_space);
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

    var access_mode: ?Inst.PointerType.AccessMode = null;
    if (extra.access_mode != .none) {
        const access_mode_loc = astgen.tree.tokenLoc(extra.access_mode);
        const ast_access_mode = stringToEnum(Ast.AccessMode, access_mode_loc.slice(astgen.tree.source)).?;
        access_mode = switch (ast_access_mode) {
            .read => .read,
            .write => .write,
            .read_write => .read_write,
        };
    }

    var expr = InstIndex.none;
    if (node_rhs != .none) {
        expr = try astgen.genExpr(scope, node_rhs);
    }

    const name = try astgen.addString(name_loc.slice(astgen.tree.source));
    return astgen.addInst(.{
        .@"var" = .{
            .name = name,
            .type = var_type,
            .addr_space = addr_space,
            .access_mode = access_mode,
            .expr = expr,
        },
    });
}

fn genConst(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    const node_rhs = astgen.tree.nodeRHS(node);
    const name_loc = astgen.tree.declNameLoc(node).?;

    var var_type = InstIndex.none;
    if (node_lhs != .none) {
        var_type = try astgen.genType(scope, node_lhs);
    }

    const expr = try astgen.genExpr(scope, node_rhs);
    if (try astgen.resolveConstExpr(expr) == null) {
        try astgen.errors.add(
            name_loc,
            "value of '{s}' must be a const-expression",
            .{name_loc.slice(astgen.tree.source)},
            null,
        );
        return error.AnalysisFail;
    }

    const name = try astgen.addString(name_loc.slice(astgen.tree.source));
    return astgen.addInst(.{
        .@"const" = .{
            .name = name,
            .type = var_type,
            .expr = expr,
        },
    });
}

fn genLet(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    const node_rhs = astgen.tree.nodeRHS(node);
    const name_loc = astgen.tree.declNameLoc(node).?;

    var var_type = InstIndex.none;
    if (node_lhs != .none) {
        var_type = try astgen.genType(scope, node_lhs);
    }

    const expr = try astgen.genExpr(scope, node_rhs);
    const name = try astgen.addString(name_loc.slice(astgen.tree.source));
    return astgen.addInst(.{
        .let = .{
            .name = name,
            .type = var_type,
            .expr = expr,
        },
    });
}

fn genExpr(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_tag = astgen.tree.nodeTag(node);
    switch (node_tag) {
        .number => return astgen.genNumber(node),
        .true => return astgen.addInst(.{ .bool = .{ .value = .{ .literal = false } } }),
        .false => return astgen.addInst(.{ .bool = .{ .value = .{ .literal = false } } }),
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

        const value = std.fmt.parseFloat(f64, bytes[0 .. bytes.len - @intFromBool(suffix != 0)]) catch |err| {
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
                .type = switch (suffix) {
                    0 => .abstract,
                    'f' => .f32,
                    'h' => .f16,
                    else => unreachable,
                },
                .value = try astgen.addValue(Inst.Float.Value, .{
                    .literal = .{
                        .value = value,
                        .base = base,
                    },
                }),
            },
        };
    } else {
        const value = std.fmt.parseInt(i64, bytes[0 .. bytes.len - @intFromBool(suffix != 0)], 0) catch |err| {
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
            .int = .{
                .type = switch (suffix) {
                    0 => .abstract,
                    'u' => .u32,
                    'i' => .i32,
                    else => unreachable,
                },
                .value = try astgen.addValue(Inst.Int.Value, .{
                    .literal = .{
                        .value = value,
                        .base = base,
                    },
                }),
            },
        };
    }
    return astgen.addInst(inst);
}

fn genNot(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    const node_lhs_loc = astgen.tree.nodeLoc(node_lhs);
    const lhs = try astgen.genExpr(scope, node_lhs);

    const lhs_res = try astgen.resolve(lhs);
    if (astgen.getInst(lhs_res) == .bool) {
        return astgen.addInst(.{ .not = lhs });
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

    const lhs_res = try astgen.resolve(lhs);
    switch (astgen.getInst(lhs_res)) {
        .int, .float => return astgen.addInst(.{ .negate = lhs }),
        else => {},
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
    const lhs_res = try astgen.resolve(lhs);
    if (astgen.getInst(lhs_res) == .ptr_type) {
        const inst = try astgen.addInst(.{ .deref = lhs });
        return inst;
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
    const node_tag = astgen.tree.nodeTag(node);
    const node_loc = astgen.tree.nodeLoc(node);
    const node_lhs = astgen.tree.nodeLHS(node);
    const node_rhs = astgen.tree.nodeRHS(node);
    const lhs = try astgen.genExpr(scope, node_lhs);
    const rhs = try astgen.genExpr(scope, node_rhs);

    const lhs_res = try astgen.resolve(lhs);
    const rhs_res = try astgen.resolve(rhs);
    const lhs_res_tag = astgen.getInst(lhs_res);
    const rhs_res_tag = astgen.getInst(rhs_res);

    var is_valid = false;
    switch (node_tag) {
        .shift_left, .shift_right, .@"and", .@"or", .xor => {
            is_valid = lhs_res_tag == .int and rhs_res_tag == .int;
        },
        .logical_and, .logical_or => {
            is_valid = lhs_res_tag == .bool and rhs_res_tag == .bool;
        },
        .mul, .div, .mod, .add, .sub => switch (lhs_res_tag) {
            .int, .float => switch (rhs_res_tag) {
                .int, .float => {
                    is_valid = true;
                },
                .vector => |rhs_vec| switch (astgen.getInst(rhs_vec.elem_type)) {
                    .int, .float => {
                        is_valid = true;
                    },
                    else => {},
                },
                else => {},
            },
            .vector => |lhs_vec| switch (astgen.getInst(lhs_vec.elem_type)) {
                .int, .float => {
                    is_valid = true;
                    switch (rhs_res_tag) {
                        .int, .float => {
                            is_valid = true;
                        },
                        .vector => |rhs_vec| switch (astgen.getInst(rhs_vec.elem_type)) {
                            .int, .float => {
                                is_valid = true;
                            },
                            else => {},
                        },
                        else => {},
                    }
                },
                else => {},
            },
            else => {},
        },
        .equal,
        .not_equal,
        .less_than,
        .less_than_equal,
        .greater_than,
        .greater_than_equal,
        => switch (lhs_res_tag) {
            .int, .float, .bool, .vector => switch (rhs_res_tag) {
                .int, .float, .bool, .vector => {
                    is_valid = true;
                },
                else => {},
            },
            else => {},
        },
        else => unreachable,
    }

    if (!is_valid) {
        try astgen.errors.add(node_loc, "invalid operation", .{}, null);
        return error.AnalysisFail;
    }

    return astgen.addInst(switch (node_tag) {
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
    });
}

fn genCall(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const null_vec = [4]InstIndex{ .none, .none, .none, .none };
    const null_mat = [4 * 4]InstIndex{
        .none, .none, .none, .none,
        .none, .none, .none, .none,
        .none, .none, .none, .none,
        .none, .none, .none, .none,
    };

    const token = astgen.tree.nodeToken(node);
    const token_tag = astgen.tree.tokenTag(token);
    const token_loc = astgen.tree.tokenLoc(token);
    const node_lhs = astgen.tree.nodeLHS(node);
    const node_rhs = astgen.tree.nodeRHS(node);
    const node_loc = astgen.tree.nodeLoc(node);

    if (node_rhs == .none) {
        std.debug.assert(token_tag == .ident);

        const builtin_fn = std.meta.stringToEnum(BuiltinFn, token_loc.slice(astgen.tree.source)) orelse {
            const decl = try astgen.findSymbol(scope, token);
            switch (astgen.getInst(decl)) {
                .@"fn" => return astgen.genFnCall(scope, node),
                .@"struct" => return astgen.genStructConstruct(scope, decl, node),
                else => {
                    try astgen.errors.add(
                        node_loc,
                        "'{s}' cannot be called",
                        .{token_loc.slice(astgen.tree.source)},
                        null,
                    );
                    return error.AnalysisFail;
                },
            }
        };
        switch (builtin_fn) {
            .all => return astgen.genBuiltinAllAny(scope, node, true),
            .any => return astgen.genBuiltinAllAny(scope, node, false),
            .select => return astgen.genBuiltinSelect(scope, node),
            .abs => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_abs, &.{ .u32, .i32, .abstract }, &.{ .f32, .f16, .abstract }),
            .acos => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_acos, &.{}, &.{ .f32, .f16, .abstract }),
            .acosh => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_acosh, &.{}, &.{ .f32, .f16, .abstract }),
            .asin => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_asin, &.{}, &.{ .f32, .f16, .abstract }),
            .asinh => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_asinh, &.{}, &.{ .f32, .f16, .abstract }),
            .atan => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_atan, &.{}, &.{ .f32, .f16, .abstract }),
            .atanh => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_atanh, &.{}, &.{ .f32, .f16, .abstract }),
            .ceil => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_ceil, &.{}, &.{ .f32, .f16, .abstract }),
            .cos => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_cos, &.{}, &.{ .f32, .f16, .abstract }),
            .cosh => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_cosh, &.{}, &.{ .f32, .f16, .abstract }),
            .countLeadingZeros => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_count_leading_zeros, &.{ .u32, .i32 }, &.{}),
            .countOneBits => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_count_one_bits, &.{ .u32, .i32 }, &.{}),
            .countTrailingZeros => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_count_trailing_zeros, &.{ .u32, .i32 }, &.{}),
            .degrees => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_degrees, &.{}, &.{ .f32, .f16, .abstract }),
            .exp => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_exp, &.{}, &.{ .f32, .f16, .abstract }),
            .exp2 => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_exp2, &.{}, &.{ .f32, .f16, .abstract }),
            .firstLeadingBit => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_first_leading_bit, &.{ .u32, .i32 }, &.{}),
            .firstTrailingBit => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_first_trailing_bit, &.{ .u32, .i32 }, &.{}),
            .floor => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_floor, &.{}, &.{ .f32, .f16, .abstract }),
            .fract => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_fract, &.{}, &.{ .f32, .f16, .abstract }),
            .inverseSqrt => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_inverse_sqrt, &.{}, &.{ .f32, .f16, .abstract }),
            .length => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_length, &.{}, &.{ .f32, .f16, .abstract }),
            .log => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_log, &.{}, &.{ .f32, .f16, .abstract }),
            .log2 => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_log2, &.{}, &.{ .f32, .f16, .abstract }),
            .quantizeToF16 => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_quantize_to_F16, &.{}, &.{.f32}),
            .radians => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_radians, &.{}, &.{ .f32, .f16, .abstract }),
            .reverseBits => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_reverseBits, &.{ .u32, .i32 }, &.{}),
            .round => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_round, &.{}, &.{ .f32, .f16, .abstract }),
            .saturate => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_saturate, &.{}, &.{ .f32, .f16, .abstract }),
            .sign => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_sign, &.{ .u32, .i32, .abstract }, &.{ .f16, .abstract }),
            .sin => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_sin, &.{}, &.{ .f32, .f16, .abstract }),
            .sinh => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_sinh, &.{}, &.{ .f32, .f16, .abstract }),
            .sqrt => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_sqrt, &.{}, &.{ .f32, .f16, .abstract }),
            .tan => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_tan, &.{}, &.{ .f32, .f16, .abstract }),
            .tanh => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_tanh, &.{}, &.{ .f32, .f16, .abstract }),
            .trunc => return astgen.genSimpleNumericBuiltin(scope, node, .builtin_trunc, &.{}, &.{ .f32, .f16, .abstract }),
            .min => return astgen.genMinMaxBuiltin(scope, node, true),
            .max => return astgen.genMinMaxBuiltin(scope, node, true),
            .smoothstep => return astgen.genSmoothstepBuiltin(scope, node),
            .dpdx => return astgen.genDerivativeBuiltin(scope, node, .builtin_dpdx),
            .dpdxCoarse => return astgen.genDerivativeBuiltin(scope, node, .builtin_dpdx_coarse),
            .dpdxFine => return astgen.genDerivativeBuiltin(scope, node, .builtin_dpdx_fine),
            .dpdy => return astgen.genDerivativeBuiltin(scope, node, .builtin_dpdy),
            .dpdyCoarse => return astgen.genDerivativeBuiltin(scope, node, .builtin_dpdy_coarse),
            .dpdyFine => return astgen.genDerivativeBuiltin(scope, node, .builtin_dpdy_fine),
            .fwidth => return astgen.genDerivativeBuiltin(scope, node, .builtin_fwidth),
            .fwidthCoarse => return astgen.genDerivativeBuiltin(scope, node, .builtin_fwidth_coarse),
            .fwidthFine => return astgen.genDerivativeBuiltin(scope, node, .builtin_fwidth_fine),
            else => {
                try astgen.errors.add(
                    node_loc,
                    "TODO: unimplemented builtin '{s}'",
                    .{token_loc.slice(astgen.tree.source)},
                    null,
                );
                return error.AnalysisFail;
            },
        }
    }

    switch (token_tag) {
        .k_bool => {
            if (node_lhs == .none) {
                return astgen.addInst(.{ .bool = .{ .value = .{ .literal = false } } });
            }

            const arg_node = astgen.tree.spanToList(node_lhs)[0];
            const lhs = try astgen.genExpr(scope, arg_node);
            const lhs_res = try astgen.resolve(lhs);
            switch (astgen.getInst(lhs_res)) {
                .bool => return lhs,
                .int, .float => return astgen.addInst(.{ .bool = .{ .value = .{ .inst = lhs } } }),
                else => {},
            }

            try astgen.errors.add(node_loc, "cannot construct bool", .{}, null);
            return error.AnalysisFail;
        },
        .k_u32 => {
            if (node_lhs == .none) {
                return astgen.addInst(.{
                    .int = .{
                        .value = try astgen.addValue(Inst.Int.Value, .{ .literal = .{ .value = 0, .base = 10 } }),
                        .type = .u32,
                    },
                });
            }

            const arg_node = astgen.tree.spanToList(node_lhs)[0];
            const lhs = try astgen.genExpr(scope, arg_node);
            const lhs_res = try astgen.resolve(lhs);
            switch (astgen.getInst(lhs_res)) {
                .bool => return astgen.addInst(.{
                    .int = .{
                        .value = try astgen.addValue(Inst.Int.Value, .{ .inst = lhs }),
                        .type = .u32,
                    },
                }),
                .int => |int| switch (int.type) {
                    .u32 => return lhs,
                    .i32, .abstract => return astgen.addInst(.{
                        .int = .{
                            .value = try astgen.addValue(Inst.Int.Value, .{ .inst = lhs }),
                            .type = .u32,
                        },
                    }),
                },
                .float => return astgen.addInst(.{
                    .int = .{
                        .value = try astgen.addValue(Inst.Int.Value, .{ .inst = lhs }),
                        .type = .u32,
                    },
                }),
                else => {},
            }

            try astgen.errors.add(node_loc, "cannot construct u32", .{}, null);
            return error.AnalysisFail;
        },
        .k_i32 => {
            if (node_lhs == .none) {
                return astgen.addInst(.{
                    .int = .{
                        .value = try astgen.addValue(Inst.Int.Value, .{ .literal = .{ .value = 0, .base = 10 } }),
                        .type = .i32,
                    },
                });
            }

            const arg_node = astgen.tree.spanToList(node_lhs)[0];
            const lhs = try astgen.genExpr(scope, arg_node);
            const lhs_res = try astgen.resolve(lhs);
            switch (astgen.getInst(lhs_res)) {
                .bool => return astgen.addInst(.{
                    .int = .{
                        .value = try astgen.addValue(Inst.Int.Value, .{ .inst = lhs }),
                        .type = .i32,
                    },
                }),
                .int => |int| switch (int.type) {
                    .i32 => return lhs,
                    .u32, .abstract => return astgen.addInst(.{
                        .int = .{
                            .value = try astgen.addValue(Inst.Int.Value, .{ .inst = lhs }),
                            .type = .i32,
                        },
                    }),
                },
                .float => return astgen.addInst(.{
                    .int = .{
                        .value = try astgen.addValue(Inst.Int.Value, .{ .inst = lhs }),
                        .type = .i32,
                    },
                }),
                else => {},
            }

            try astgen.errors.add(node_loc, "cannot construct i32", .{}, null);
            return error.AnalysisFail;
        },
        .k_f32 => {
            if (node_lhs == .none) {
                return astgen.addInst(.{
                    .float = .{
                        .value = try astgen.addValue(Inst.Float.Value, .{ .literal = .{ .value = 0, .base = 10 } }),
                        .type = .f32,
                    },
                });
            }

            const arg_node = astgen.tree.spanToList(node_lhs)[0];
            const lhs = try astgen.genExpr(scope, arg_node);
            const lhs_res = try astgen.resolve(lhs);
            switch (astgen.getInst(lhs_res)) {
                .bool => return astgen.addInst(.{
                    .float = .{
                        .value = try astgen.addValue(Inst.Float.Value, .{ .inst = lhs }),
                        .type = .f32,
                    },
                }),
                .int => return astgen.addInst(.{
                    .float = .{
                        .value = try astgen.addValue(Inst.Float.Value, .{ .inst = lhs }),
                        .type = .f32,
                    },
                }),
                .float => |float| switch (float.type) {
                    .f32 => return lhs,
                    .f16, .abstract => return astgen.addInst(.{
                        .float = .{
                            .value = try astgen.addValue(Inst.Float.Value, .{ .inst = lhs }),
                            .type = .f32,
                        },
                    }),
                },
                else => {},
            }

            try astgen.errors.add(node_loc, "cannot construct f32", .{}, null);
            return error.AnalysisFail;
        },
        .k_f16 => {
            if (node_lhs == .none) {
                return astgen.addInst(.{
                    .float = .{
                        .value = try astgen.addValue(Inst.Float.Value, .{ .literal = .{ .value = 0, .base = 10 } }),
                        .type = .f16,
                    },
                });
            }

            const arg_node = astgen.tree.spanToList(node_lhs)[0];
            const lhs = try astgen.genExpr(scope, arg_node);
            const lhs_res = try astgen.resolve(lhs);
            switch (astgen.getInst(lhs_res)) {
                .bool => return astgen.addInst(.{
                    .float = .{
                        .value = try astgen.addValue(Inst.Float.Value, .{ .inst = lhs }),
                        .type = .f16,
                    },
                }),
                .int => return astgen.addInst(.{
                    .float = .{
                        .value = try astgen.addValue(Inst.Float.Value, .{ .inst = lhs }),
                        .type = .f16,
                    },
                }),
                .float => |float| switch (float.type) {
                    .f16 => return lhs,
                    .f32, .abstract => return astgen.addInst(.{
                        .float = .{
                            .value = try astgen.addValue(Inst.Float.Value, .{ .inst = lhs }),
                            .type = .f16,
                        },
                    }),
                },
                else => {},
            }

            try astgen.errors.add(node_loc, "cannot construct f16", .{}, null);
            return error.AnalysisFail;
        },
        .k_vec2 => {
            if (node_lhs == .none) {
                return astgen.genVector(
                    scope,
                    node_rhs,
                    try astgen.addInst(.{ .int = .{ .type = .abstract, .value = null } }),
                    null_vec,
                );
            }

            var args = null_vec;
            const arg_nodes = astgen.tree.spanToList(node_lhs);
            switch (arg_nodes.len) {
                1 => {
                    args[0] = try astgen.genExpr(scope, arg_nodes[0]);
                    args[1] = args[0];
                    const arg_res = try astgen.resolve(args[0]);
                    if (astgen.getInst(arg_res) == .vector) {
                        const vector = astgen.getInst(arg_res).vector;
                        if (vector.size == .two) {
                            const vec = try astgen.genVector(scope, node_rhs, vector.elem_type, args);
                            if (astgen.eql(astgen.getInst(vec).vector.elem_type, vector.elem_type)) {
                                return vec;
                            }
                        }
                    } else {
                        const vec = try astgen.genVector(scope, node_rhs, arg_res, args);
                        if (astgen.eql(astgen.getInst(vec).vector.elem_type, arg_res)) {
                            return vec;
                        }
                    }
                },
                2 => blk: {
                    var arg0_res = InstIndex.none;
                    for (arg_nodes, 0..) |arg_node, i| {
                        const arg = try astgen.genExpr(scope, arg_node);
                        const arg_res = try astgen.resolve(arg);
                        switch (astgen.getInst(arg_res)) {
                            .bool, .int, .float => {
                                if (i == 0) {
                                    args[i] = arg;
                                    arg0_res = arg_res;
                                } else if (astgen.eql(arg0_res, arg_res)) {
                                    args[i] = arg;
                                } else break :blk;
                            },
                            else => break :blk,
                        }
                    }
                    const vec = try astgen.genVector(scope, node_rhs, arg0_res, args);
                    if (astgen.eql(astgen.getInst(vec).vector.elem_type, arg0_res)) {
                        return vec;
                    }
                },
                else => {},
            }

            try astgen.errors.add(node_loc, "cannot construct vec2", .{}, null);
            return error.AnalysisFail;
        },
        .k_vec3 => {
            if (node_lhs == .none) {
                return astgen.genVector(
                    scope,
                    node_rhs,
                    try astgen.addInst(.{ .int = .{ .type = .abstract, .value = null } }),
                    null_vec,
                );
            }

            var args = null_vec;
            const arg_nodes = astgen.tree.spanToList(node_lhs);
            switch (arg_nodes.len) {
                1 => {
                    args[0] = try astgen.genExpr(scope, arg_nodes[0]);
                    args[1] = args[0];
                    args[2] = args[0];
                    const arg_res = try astgen.resolve(args[0]);
                    if (astgen.getInst(arg_res) == .vector) {
                        const vector = astgen.getInst(arg_res).vector;
                        if (vector.size == .three) {
                            const vec = try astgen.genVector(
                                scope,
                                node_rhs,
                                astgen.getInst(arg_res).vector.elem_type,
                                args,
                            );
                            if (astgen.eql(astgen.getInst(vec).vector.elem_type, vector.elem_type)) {
                                return vec;
                            }
                        }
                    } else {
                        const vec = try astgen.genVector(scope, node_rhs, arg_res, args);
                        if (astgen.eql(astgen.getInst(vec).vector.elem_type, arg_res)) {
                            return vec;
                        }
                    }
                },
                2 => {
                    args[0] = try astgen.genExpr(scope, arg_nodes[0]);
                    const arg0_res = try astgen.resolve(args[0]);
                    if (astgen.getInst(arg0_res) == .vector) {
                        const vector = astgen.getInst(arg0_res).vector;
                        if (vector.size == .two) {
                            args[2] = try astgen.genExpr(scope, arg_nodes[1]);
                            const arg1_res = try astgen.resolve(args[2]);
                            if (astgen.eql(arg1_res, vector.elem_type)) {
                                const vec = try astgen.genVector(
                                    scope,
                                    node_rhs,
                                    vector.elem_type,
                                    args,
                                );

                                if (astgen.eql(astgen.getInst(vec).vector.elem_type, arg0_res)) {
                                    return vec;
                                }
                            }
                        }
                    } else {
                        args[1] = try astgen.genExpr(scope, arg_nodes[1]);
                        const arg1_res = try astgen.resolve(args[1]);
                        if (astgen.getInst(arg1_res) == .vector and
                            astgen.getInst(arg1_res).vector.size == .two and
                            astgen.eql(arg0_res, astgen.getInst(arg1_res).vector.elem_type))
                        {
                            const vec = try astgen.genVector(scope, node_rhs, arg0_res, args);
                            if (astgen.eql(astgen.getInst(vec).vector.elem_type, arg0_res)) {
                                return vec;
                            }
                        }
                    }
                },
                3 => blk: {
                    var arg0_res = InstIndex.none;
                    for (arg_nodes, 0..) |arg_node, i| {
                        const arg = try astgen.genExpr(scope, arg_node);
                        const arg_res = try astgen.resolve(arg);
                        if (i == 0) {
                            args[i] = arg;
                            arg0_res = arg_res;
                        } else if (astgen.eql(arg0_res, arg_res)) {
                            args[i] = arg;
                        } else break :blk;
                    }
                    const vec = try astgen.genVector(scope, node_rhs, arg0_res, args);
                    if (astgen.eql(astgen.getInst(vec).vector.elem_type, arg0_res)) {
                        return vec;
                    }
                },
                else => {},
            }

            try astgen.errors.add(node_loc, "cannot construct vec3", .{}, null);
            return error.AnalysisFail;
        },
        .k_vec4 => {
            if (node_lhs == .none) {
                return astgen.genVector(
                    scope,
                    node_rhs,
                    try astgen.addInst(.{ .int = .{ .type = .abstract, .value = null } }),
                    null_vec,
                );
            }

            var args = null_vec;
            const arg_nodes = astgen.tree.spanToList(node_lhs);
            switch (arg_nodes.len) {
                1 => {
                    args[0] = try astgen.genExpr(scope, arg_nodes[0]);
                    args[1] = args[0];
                    args[2] = args[0];
                    args[3] = args[0];
                    const arg_res = try astgen.resolve(args[0]);
                    if (astgen.getInst(arg_res) == .vector) {
                        const vector = astgen.getInst(arg_res).vector;
                        if (vector.size == .four) {
                            const vec = try astgen.genVector(
                                scope,
                                node_rhs,
                                astgen.getInst(arg_res).vector.elem_type,
                                args,
                            );

                            if (astgen.eql(astgen.getInst(vec).vector.elem_type, vector.elem_type)) {
                                return vec;
                            }
                        }
                    } else {
                        const vec = try astgen.genVector(
                            scope,
                            node_rhs,
                            arg_res,
                            args,
                        );

                        if (astgen.eql(astgen.getInst(vec).vector.elem_type, arg_res)) {
                            return vec;
                        }
                    }
                },
                2 => {
                    args[0] = try astgen.genExpr(scope, arg_nodes[0]);
                    const arg0_res = try astgen.resolve(args[0]);
                    if (astgen.getInst(arg0_res) == .vector) {
                        args[2] = try astgen.genExpr(scope, arg_nodes[1]);
                        const arg1_res = try astgen.resolve(args[2]);
                        const vector0 = astgen.getInst(arg0_res).vector;
                        if (astgen.getInst(arg1_res) == .vector) {
                            const vector1 = astgen.getInst(arg1_res).vector;
                            if (vector0.size == .two and astgen.eqlVector(vector0, vector1)) {
                                const vec = try astgen.genVector(scope, node_rhs, vector0.elem_type, args);
                                if (astgen.eql(astgen.getInst(vec).vector.elem_type, vector0.elem_type)) {
                                    return vec;
                                }
                            }
                        } else {
                            if (vector0.size == .three) {
                                if (astgen.eql(arg1_res, vector0.elem_type)) {
                                    const vec = try astgen.genVector(scope, node_rhs, arg1_res, args);
                                    if (astgen.eql(astgen.getInst(vec).vector.elem_type, arg1_res)) {
                                        return vec;
                                    }
                                }
                            }
                        }
                    } else {
                        args[1] = try astgen.genExpr(scope, arg_nodes[1]);
                        const arg1_res = try astgen.resolve(args[1]);
                        if (astgen.getInst(arg1_res) == .vector) {
                            const vector = astgen.getInst(arg1_res).vector;
                            if (vector.size == .three and
                                astgen.eql(arg0_res, vector.elem_type))
                            {
                                const vec = try astgen.genVector(scope, node_rhs, arg0_res, args);
                                if (astgen.eql(astgen.getInst(vec).vector.elem_type, arg0_res)) {
                                    return vec;
                                }
                            }
                        }
                    }
                },
                3 => blk: {
                    var vector_arg = InstIndex.none;
                    var scalar_arg0 = InstIndex.none;
                    var scalar_arg1 = InstIndex.none;
                    var vector_arg_offset: ?usize = null;
                    var scalar_arg0_offset: ?usize = null;
                    var scalar_arg1_offset: ?usize = null;

                    for (arg_nodes, 0..) |arg_node, i| {
                        const arg = try astgen.genExpr(scope, arg_node);
                        const arg_res = try astgen.resolve(arg);
                        if (astgen.getInst(arg_res) == .vector) {
                            if (vector_arg_offset) |_| break :blk;
                            vector_arg = arg;
                            vector_arg_offset = i;
                            if (astgen.getInst(arg_res).vector.size != .two) break :blk;
                        } else {
                            if (scalar_arg0 == .none) {
                                scalar_arg0 = arg;
                                scalar_arg0_offset = i + if (vector_arg_offset) |vec_off| @intFromBool(vec_off < i) else 0;
                            } else if (scalar_arg1 == .none) {
                                scalar_arg1 = arg;
                                scalar_arg1_offset = i + if (vector_arg_offset) |vec_off| @intFromBool(vec_off < i) else 0;
                            } else break :blk;
                        }
                    }

                    const vector_arg_res = try astgen.resolve(vector_arg);
                    const scalar_arg0_res = try astgen.resolve(scalar_arg0);
                    const scalar_arg1_res = try astgen.resolve(scalar_arg1);
                    if (astgen.eql(scalar_arg0_res, scalar_arg1_res) and
                        astgen.eql(astgen.getInst(vector_arg_res).vector.elem_type, scalar_arg0_res))
                    {
                        args[vector_arg_offset.?] = vector_arg;
                        args[scalar_arg0_offset.?] = scalar_arg0;
                        args[scalar_arg1_offset.?] = scalar_arg1;

                        const vec = try astgen.genVector(scope, node_rhs, scalar_arg0, args);
                        if (astgen.eql(astgen.getInst(vec).vector.elem_type, scalar_arg0_res)) {
                            return vec;
                        }
                    }
                },
                4 => blk: {
                    var arg0_res = InstIndex.none;
                    for (arg_nodes, 0..) |arg_node, i| {
                        const arg = try astgen.genExpr(scope, arg_node);
                        const arg_res = try astgen.resolve(arg);
                        if (i == 0) {
                            args[i] = arg;
                            arg0_res = arg_res;
                        } else if (astgen.eql(arg0_res, arg_res)) {
                            args[i] = arg;
                        } else break :blk;
                    }
                    const vec = try astgen.genVector(scope, node_rhs, arg0_res, args);
                    if (astgen.eql(astgen.getInst(vec).vector.elem_type, arg0_res)) {
                        return vec;
                    }
                },
                else => {},
            }

            try astgen.errors.add(node_loc, "cannot construct vec4", .{}, null);
            return error.AnalysisFail;
        },
        .k_mat2x2,
        .k_mat2x3,
        .k_mat2x4,
        .k_mat3x2,
        .k_mat3x3,
        .k_mat3x4,
        .k_mat4x2,
        .k_mat4x3,
        .k_mat4x4,
        => {
            if (node_lhs == .none) {
                return astgen.genMatrix(
                    scope,
                    node_rhs,
                    try astgen.addInst(.{ .int = .{ .type = .abstract, .value = null } }),
                    std.mem.zeroes([4 * 4]InstIndex),
                );
            }

            const cols = matrixCols(token_tag);
            const rows = matrixRows(token_tag);

            var args = null_mat;
            const arg_nodes = astgen.tree.spanToList(node_lhs);
            if (arg_nodes.len == 1) {
                args[0] = try astgen.genExpr(scope, arg_nodes[0]);
                const arg_res = try astgen.resolve(args[0]);
                switch (astgen.getInst(arg_res)) {
                    .matrix => |matrix| if (matrix.cols == cols and matrix.rows == rows) {
                        const mat = try astgen.genMatrix(
                            scope,
                            node_rhs,
                            astgen.getInst(arg_res).matrix.elem_type,
                            args,
                        );
                        if (astgen.eql(astgen.getInst(mat).matrix.elem_type, matrix.elem_type)) {
                            return mat;
                        }
                    },
                    else => {},
                }
            } else if (arg_nodes.len == @intFromEnum(cols)) blk: {
                const offset = @intFromEnum(rows);
                var arg0_res = InstIndex.none;
                for (arg_nodes, 0..) |arg_node, i| {
                    const arg = try astgen.genExpr(scope, arg_node);
                    const arg_res = try astgen.resolve(arg);
                    if (i == 0) {
                        args[0] = arg;
                        arg0_res = arg_res;

                        if (astgen.getInst(arg0_res) != .vector or
                            astgen.getInst(arg0_res).vector.size != rows)
                        {
                            break :blk;
                        }
                    } else if (astgen.eql(arg0_res, arg_res)) {
                        args[i * offset] = arg;
                    } else break :blk;
                }

                const mat = try astgen.genMatrix(
                    scope,
                    node_rhs,
                    astgen.getInst(arg0_res).vector.elem_type,
                    args,
                );
                if (astgen.eql(astgen.getInst(mat).matrix.elem_type, astgen.getInst(arg0_res).vector.elem_type)) {
                    return mat;
                }
            } else if (arg_nodes.len == @intFromEnum(cols) * @intFromEnum(rows)) blk: {
                var arg0_res = InstIndex.none;
                for (arg_nodes, 0..) |arg_node, i| {
                    const arg = try astgen.genExpr(scope, arg_node);
                    const arg_res = try astgen.resolve(arg);
                    if (i == 0) {
                        args[i] = arg;
                        arg0_res = arg_res;
                    } else if (astgen.eql(arg0_res, arg_res)) {
                        args[i] = arg;
                    } else break :blk;
                }
                const mat = try astgen.genMatrix(scope, node_rhs, arg0_res, args);
                if (astgen.eql(astgen.getInst(mat).matrix.elem_type, arg0_res)) {
                    return mat;
                }
            }

            try astgen.errors.add(node_loc, "cannot construct matrix", .{}, null);
            return error.AnalysisFail;
        },
        .k_array => {
            if (node_lhs == .none) {
                return astgen.genArray(scope, node_rhs, .none);
            }

            const scratch_top = astgen.scratch.items.len;
            defer astgen.scratch.shrinkRetainingCapacity(scratch_top);

            var arg0_res = InstIndex.none;
            const arg_nodes = astgen.tree.spanToList(node_lhs);
            for (arg_nodes, 0..) |arg_node, i| {
                const arg = try astgen.genExpr(scope, arg_node);
                const arg_res = try astgen.resolve(arg);
                if (i == 0) {
                    arg0_res = arg_res;
                } else if (astgen.eql(arg0_res, arg_res)) {
                    try astgen.scratch.append(astgen.allocator, arg);
                } else {
                    try astgen.errors.add(node_loc, "cannot construct array", .{}, null);
                    return error.AnalysisFail;
                }
            }

            const args = try astgen.addRefList(astgen.scratch.items[scratch_top..]);
            const arr = try astgen.genArray(scope, node_rhs, args);
            if (astgen.eql(astgen.getInst(arr).array.elem_type, arg0_res)) {
                return arr;
            }

            try astgen.errors.add(node_loc, "cannot construct array", .{}, null);
            return error.AnalysisFail;
        },
        else => unreachable,
    }
}

fn genReturn(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    const node_loc = astgen.tree.nodeLoc(node);

    var fn_scope = findFnScope(scope);
    var value = InstIndex.none;
    if (node_lhs != .none) {
        if (fn_scope.tag.@"fn".return_type == .none) {
            try astgen.errors.add(node_loc, "cannot return value", .{}, null);
            return error.AnalysisFail;
        }

        value = try astgen.genExpr(scope, node_lhs);
        const value_res = try astgen.resolve(value);
        if (!astgen.eql(fn_scope.tag.@"fn".return_type, value_res)) {
            try astgen.errors.add(node_loc, "return type mismatch", .{}, null);
            return error.AnalysisFail;
        }
    } else {
        if (fn_scope.tag.@"fn".return_type != .none) {
            try astgen.errors.add(node_loc, "return value not specified", .{}, null);
            return error.AnalysisFail;
        }
    }

    fn_scope.tag.@"fn".returned = true;
    return astgen.addInst(.{ .@"return" = value });
}

fn findFnScope(scope: *Scope) *Scope {
    var s = scope;
    while (true) {
        switch (s.tag) {
            .root => unreachable,
            .@"fn" => return s,
            .block,
            .loop,
            .continuing,
            .switch_case,
            .@"if",
            .@"for",
            => s = s.parent,
        }
    }
}

fn genFnCall(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    const node_loc = astgen.tree.nodeLoc(node);
    const token = astgen.tree.nodeToken(node);
    const decl = try astgen.findSymbol(scope, token);
    if (astgen.tree.nodeRHS(node) != .none) {
        try astgen.errors.add(node_loc, "expected a function", .{}, null);
        return error.AnalysisFail;
    }

    const scratch_top = astgen.scratch.items.len;
    defer astgen.scratch.shrinkRetainingCapacity(scratch_top);

    var args = RefIndex.none;
    if (node_lhs != .none) {
        const params = astgen.refToList(astgen.getInst(decl).@"fn".params);
        const arg_nodes = astgen.tree.spanToList(node_lhs);
        if (params.len != arg_nodes.len) {
            try astgen.errors.add(node_loc, "function params count mismatch", .{}, null);
            return error.AnalysisFail;
        }
        for (arg_nodes, 0..) |arg_node, i| {
            const arg = try astgen.genExpr(scope, arg_node);
            const arg_res = try astgen.resolve(arg);
            if (astgen.eql(astgen.getInst(params[i]).fn_param.type, arg_res)) {
                try astgen.scratch.append(astgen.allocator, arg);
            } else {
                try astgen.errors.add(
                    astgen.tree.nodeLoc(arg_node),
                    "value and member type mismatch",
                    .{},
                    null,
                );
                return error.AnalysisFail;
            }
        }
        args = try astgen.addRefList(astgen.scratch.items[scratch_top..]);
    } else {
        if (astgen.getInst(decl).@"fn".params != .none) {
            try astgen.errors.add(node_loc, "function params count mismatch", .{}, null);
            return error.AnalysisFail;
        }
    }

    return astgen.addInst(.{ .call = .{ .@"fn" = decl, .args = args } });
}

fn genStructConstruct(astgen: *AstGen, scope: *Scope, decl: InstIndex, node: NodeIndex) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    const node_loc = astgen.tree.nodeLoc(node);

    const scratch_top = astgen.scratch.items.len;
    defer astgen.scratch.shrinkRetainingCapacity(scratch_top);

    const struct_members = astgen.refToList(astgen.getInst(decl).@"struct".members);
    if (node_lhs != .none) {
        const arg_nodes = astgen.tree.spanToList(node_lhs);
        if (struct_members.len != arg_nodes.len) {
            try astgen.errors.add(node_loc, "struct members count mismatch", .{}, null);
            return error.AnalysisFail;
        }
        for (arg_nodes, 0..) |arg_node, i| {
            const arg = try astgen.genExpr(scope, arg_node);
            const arg_res = try astgen.resolve(arg);
            if (astgen.eql(astgen.getInst(struct_members[i]).struct_member.type, arg_res)) {
                try astgen.scratch.append(astgen.allocator, arg);
            } else {
                try astgen.errors.add(
                    astgen.tree.nodeLoc(arg_node),
                    "value and member type mismatch",
                    .{},
                    null,
                );
                return error.AnalysisFail;
            }
        }
    } else {
        if (struct_members.len != 0) {
            try astgen.errors.add(node_loc, "struct members count mismatch", .{}, null);
            return error.AnalysisFail;
        }
    }

    const members = try astgen.addRefList(astgen.scratch.items[scratch_top..]);
    return astgen.addInst(.{
        .struct_construct = .{
            .@"struct" = decl,
            .members = members,
        },
    });
}

fn genBitcast(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    const node_rhs = astgen.tree.nodeRHS(node);
    const node_lhs_loc = astgen.tree.nodeLoc(node_lhs);
    const node_rhs_loc = astgen.tree.nodeLoc(node_rhs);
    const lhs = try astgen.genType(scope, node_lhs);
    const lhs_inst = astgen.getInst(lhs);
    const rhs = try astgen.genExpr(scope, node_rhs);
    const rhs_res = try astgen.resolve(rhs);
    const rhs_res_inst = astgen.getInst(rhs_res);
    var result_type = InstIndex.none;

    const lhs_is_32bit = switch (lhs_inst) {
        .int => |int| int.type == .u32 or int.type == .i32,
        .float => |float| float.type == .f32,
        else => false,
    };
    const rhs_is_32bit = switch (rhs_res_inst) {
        .int => |int| int.type == .u32 or int.type == .i32,
        .float => |float| float.type == .f32,
        else => false,
    };

    if (lhs_is_32bit) {
        if (rhs_is_32bit) {
            // bitcast<T>(T) -> T
            // bitcast<T>(S) -> T
            result_type = lhs;
        } else if (rhs_res_inst == .vector) {
            const rhs_vec_type = astgen.getInst(rhs_res_inst.vector.elem_type);

            if (rhs_res_inst.vector.size == .two and
                rhs_vec_type == .float and rhs_vec_type.float.type == .f16)
            {
                // bitcast<T>(vec2<f16>) -> T
                result_type = lhs;
            }
        }
    } else if (lhs_inst == .vector) {
        if (rhs_is_32bit) {
            const lhs_vec_type = astgen.getInst(lhs_inst.vector.elem_type);

            if (lhs_inst.vector.size == .two and
                lhs_vec_type == .float and lhs_vec_type.float.type == .f16)
            {
                // bitcast<vec2<f16>>(T) -> vec2<f16>
                result_type = lhs;
            }
        } else if (rhs_res_inst == .vector) {
            const lhs_vec_type = astgen.getInst(lhs_inst.vector.elem_type);
            const rhs_vec_type = astgen.getInst(rhs_res_inst.vector.elem_type);

            const lhs_vec_is_32bit = switch (lhs_vec_type) {
                .int => |int| int.type == .u32 or int.type == .i32,
                .float => |float| float.type == .f32,
                else => false,
            };
            const rhs_vec_is_32bit = switch (rhs_vec_type) {
                .int => |int| int.type == .u32 or int.type == .i32,
                .float => |float| float.type == .f32,
                else => false,
            };

            if (lhs_vec_is_32bit) {
                if (rhs_vec_is_32bit) {
                    if (lhs_inst.vector.size == rhs_res_inst.vector.size) {
                        if (lhs_inst.vector.elem_type == rhs_res_inst.vector.elem_type) {
                            // bitcast<vecN<T>>(vecN<T>) -> vecN<T>
                            result_type = lhs;
                        } else {
                            // bitcast<vecN<T>>(vecN<S>) -> T
                            result_type = lhs_inst.vector.elem_type;
                        }
                    }
                } else if (rhs_vec_type == .float and rhs_vec_type.float.type == .f16) {
                    if (lhs_inst.vector.size == .two and
                        rhs_res_inst.vector.size == .four)
                    {
                        // bitcast<vec2<T>>(vec4<f16>) -> vec2<T>
                        result_type = lhs;
                    }
                }
            } else if (lhs_vec_type == .float and lhs_vec_type.float.type == .f16) {
                if (rhs_res_inst.vector.size == .two and
                    lhs_inst.vector.size == .four)
                {
                    // bitcast<vec4<f16>>(vec2<T>) -> vec4<f16>
                    result_type = lhs;
                }
            }
        }
    }

    if (result_type != .none) {
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

fn genBuiltinAllAny(astgen: *AstGen, scope: *Scope, node: NodeIndex, all: bool) !InstIndex {
    const node_loc = astgen.tree.nodeLoc(node);
    const node_lhs = astgen.tree.nodeLHS(node);
    if (node_lhs == .none) {
        return astgen.failArgCountMismatch(node_loc, 1, 0);
    }

    const arg_nodes = astgen.tree.spanToList(node_lhs);
    if (arg_nodes.len != 1) {
        return astgen.failArgCountMismatch(node_loc, 1, arg_nodes.len);
    }

    const arg = try astgen.genExpr(scope, arg_nodes[0]);
    const arg_res = try astgen.resolve(arg);
    switch (astgen.getInst(arg_res)) {
        .bool => return arg,
        .vector => |vec| {
            if (astgen.getInst(vec.elem_type) != .bool) {
                try astgen.errors.add(node_loc, "invalid vector element type", .{}, null);
                return error.AnalysisFail;
            }

            if (all) {
                return astgen.addInst(.{ .builtin_all = arg });
            } else {
                return astgen.addInst(.{ .builtin_any = arg });
            }
        },
        else => {
            try astgen.errors.add(node_loc, "type mismatch", .{}, null);
            return error.AnalysisFail;
        },
    }
}

fn genBuiltinSelect(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_loc = astgen.tree.nodeLoc(node);
    const node_lhs = astgen.tree.nodeLHS(node);
    if (node_lhs == .none) {
        return astgen.failArgCountMismatch(node_loc, 3, 0);
    }

    const arg_nodes = astgen.tree.spanToList(node_lhs);
    if (arg_nodes.len != 3) {
        return astgen.failArgCountMismatch(node_loc, 3, arg_nodes.len);
    }

    const arg0 = try astgen.genExpr(scope, arg_nodes[0]);
    const arg1 = try astgen.genExpr(scope, arg_nodes[1]);
    const arg2 = try astgen.genExpr(scope, arg_nodes[2]);
    const arg0_res = try astgen.resolve(arg0);
    const arg1_res = try astgen.resolve(arg1);
    const arg2_res = try astgen.resolve(arg2);

    if (!astgen.eql(arg0_res, arg1_res)) {
        try astgen.errors.add(node_loc, "type mismatch", .{}, null);
        return error.AnalysisFail;
    }

    switch (astgen.getInst(arg2_res)) {
        .bool => {
            return astgen.addInst(.{
                .builtin_select = .{
                    .true = arg0,
                    .false = arg1,
                    .cond = arg2,
                },
            });
        },
        .vector => |vec| {
            if (astgen.getInst(vec.elem_type) != .bool) {
                try astgen.errors.add(node_loc, "invalid vector element type", .{}, null);
                return error.AnalysisFail;
            }

            if (astgen.getInst(arg0_res) != .vector) {
                try astgen.errors.add(node_loc, "'true' and 'false' must be vector", .{}, null);
                return error.AnalysisFail;
            }

            return astgen.addInst(.{
                .builtin_select = .{
                    .true = arg0,
                    .false = arg1,
                    .cond = arg2,
                },
            });
        },
        else => {
            try astgen.errors.add(node_loc, "type mismatch", .{}, null);
            return error.AnalysisFail;
        },
    }
}

fn genDerivativeBuiltin(
    astgen: *AstGen,
    scope: *Scope,
    node: NodeIndex,
    comptime tag: std.meta.Tag(Inst),
) !InstIndex {
    const node_loc = astgen.tree.nodeLoc(node);
    const node_lhs = astgen.tree.nodeLHS(node);
    if (node_lhs == .none) {
        return astgen.failArgCountMismatch(node_loc, 1, 0);
    }

    const arg_nodes = astgen.tree.spanToList(node_lhs);
    if (arg_nodes.len != 1) {
        return astgen.failArgCountMismatch(node_loc, 1, arg_nodes.len);
    }

    const arg = try astgen.genExpr(scope, arg_nodes[0]);
    const arg_res = try astgen.resolve(arg);
    const inst = @unionInit(Inst, @tagName(tag), arg);
    switch (astgen.getInst(arg_res)) {
        .float => |float| {
            if (float.type == .f32) {
                return astgen.addInst(inst);
            }
        },
        .vector => |vec| {
            switch (astgen.getInst(vec.elem_type)) {
                .float => |float| {
                    if (float.type == .f32) {
                        return astgen.addInst(inst);
                    }
                },
                else => {},
            }
        },
        else => {},
    }

    try astgen.errors.add(node_loc, "type mismatch", .{}, null);
    return error.AnalysisFail;
}

fn genSimpleNumericBuiltin(
    astgen: *AstGen,
    scope: *Scope,
    node: NodeIndex,
    comptime tag: std.meta.Tag(Inst),
    comptime int_limit: []const Inst.Int.Type,
    comptime float_limit: []const Inst.Float.Type,
) !InstIndex {
    const node_loc = astgen.tree.nodeLoc(node);
    const node_lhs = astgen.tree.nodeLHS(node);
    if (node_lhs == .none) {
        return astgen.failArgCountMismatch(node_loc, 1, 0);
    }

    const arg_nodes = astgen.tree.spanToList(node_lhs);
    if (arg_nodes.len != 1) {
        return astgen.failArgCountMismatch(node_loc, 1, arg_nodes.len);
    }

    const arg = try astgen.genExpr(scope, arg_nodes[0]);
    const arg_res = try astgen.resolve(arg);
    const inst = @unionInit(Inst, @tagName(tag), arg);
    switch (astgen.getInst(arg_res)) {
        .int => |int| if (std.mem.indexOfScalar(Inst.Int.Type, int_limit, int.type)) |_| {
            return astgen.addInst(inst);
        },
        .float => |float| if (std.mem.indexOfScalar(Inst.Float.Type, float_limit, float.type)) |_| {
            return astgen.addInst(inst);
        },
        .vector => |vec| {
            switch (astgen.getInst(vec.elem_type)) {
                .int => |int| if (std.mem.indexOfScalar(Inst.Int.Type, int_limit, int.type)) |_| {
                    return astgen.addInst(inst);
                },
                .float => |float| if (std.mem.indexOfScalar(Inst.Float.Type, float_limit, float.type)) |_| {
                    return astgen.addInst(inst);
                },
                else => {},
            }
        },
        else => {},
    }

    try astgen.errors.add(node_loc, "type mismatch", .{}, null);
    return error.AnalysisFail;
}

fn genMinMaxBuiltin(astgen: *AstGen, scope: *Scope, node: NodeIndex, min: bool) !InstIndex {
    const node_loc = astgen.tree.nodeLoc(node);
    const node_lhs = astgen.tree.nodeLHS(node);
    if (node_lhs == .none) {
        return astgen.failArgCountMismatch(node_loc, 2, 0);
    }

    const arg_nodes = astgen.tree.spanToList(node_lhs);
    if (arg_nodes.len != 2) {
        return astgen.failArgCountMismatch(node_loc, 2, arg_nodes.len);
    }

    const arg0 = try astgen.genExpr(scope, arg_nodes[0]);
    const arg1 = try astgen.genExpr(scope, arg_nodes[1]);
    const arg0_res = try astgen.resolve(arg0);
    const arg1_res = try astgen.resolve(arg1);
    switch (astgen.getInst(arg0_res)) {
        .int, .float => {},
        .vector => |vec| {
            if (astgen.getInst(vec.elem_type) == .bool) {
                try astgen.errors.add(node_loc, "invalid vector element type", .{}, null);
                return error.AnalysisFail;
            }
        },
        else => {
            try astgen.errors.add(node_loc, "type mismatch", .{}, null);
            return error.AnalysisFail;
        },
    }

    if (!astgen.eql(arg0_res, arg1_res)) {
        try astgen.errors.add(node_loc, "type mismatch", .{}, null);
        return error.AnalysisFail;
    }

    if (min) {
        return astgen.addInst(.{ .builtin_min = .{ .lhs = arg0, .rhs = arg1 } });
    } else {
        return astgen.addInst(.{ .builtin_max = .{ .lhs = arg0, .rhs = arg1 } });
    }
}

fn genSmoothstepBuiltin(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_loc = astgen.tree.nodeLoc(node);
    const node_lhs = astgen.tree.nodeLHS(node);
    if (node_lhs == .none) {
        return astgen.failArgCountMismatch(node_loc, 3, 0);
    }

    const arg_nodes = astgen.tree.spanToList(node_lhs);
    if (arg_nodes.len != 3) {
        return astgen.failArgCountMismatch(node_loc, 3, arg_nodes.len);
    }

    const low = try astgen.genExpr(scope, arg_nodes[0]);
    const high = try astgen.genExpr(scope, arg_nodes[1]);
    const x = try astgen.genExpr(scope, arg_nodes[2]);
    const low_res = try astgen.resolve(low);
    const high_res = try astgen.resolve(high);
    const x_res = try astgen.resolve(x);

    if (!astgen.eql(low_res, high_res) or !astgen.eql(low_res, x_res)) {
        try astgen.errors.add(node_loc, "type mismatch", .{}, null);
        return error.AnalysisFail;
    }

    switch (astgen.getInst(low_res)) {
        .float => return astgen.addInst(.{ .builtin_smoothstep = .{
            .low = low,
            .high = high,
            .x = x,
        } }),
        .vector => |vec| {
            if (astgen.getInst(vec.elem_type) == .float) {
                return astgen.addInst(.{ .builtin_smoothstep = .{
                    .low = low,
                    .high = high,
                    .x = x,
                } });
            }
        },
        else => {},
    }

    try astgen.errors.add(node_loc, "type mismatch", .{}, null);
    return error.AnalysisFail;
}

fn genVarRef(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    return astgen.addInst(.{
        .var_ref = try astgen.findSymbol(scope, astgen.tree.nodeToken(node)),
    });
}

fn genIndexAccess(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const base = try astgen.genExpr(scope, astgen.tree.nodeLHS(node));
    const base_type = try astgen.resolve(base);

    if (astgen.getInst(base_type) != .array) {
        try astgen.errors.add(
            astgen.tree.nodeLoc(astgen.tree.nodeRHS(node)),
            "cannot access index of a non-array",
            .{},
            null,
        );
        return error.AnalysisFail;
    }

    const rhs = try astgen.genExpr(scope, astgen.tree.nodeRHS(node));
    const rhs_res = try astgen.resolve(rhs);
    if (astgen.getInst(rhs_res) == .int) {
        const inst = try astgen.addInst(.{
            .index_access = .{
                .base = base,
                .elem_type = astgen.getInst(base_type).array.elem_type,
                .index = rhs,
            },
        });
        return inst;
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
    const base_type = try astgen.resolve(base);
    const field_node = astgen.tree.nodeRHS(node).asTokenIndex();
    const field_name = astgen.tree.tokenLoc(field_node).slice(astgen.tree.source);

    switch (astgen.getInst(base_type)) {
        .vector => |base_vec| {
            if (field_name.len > 4 or field_name.len > @intFromEnum(base_vec.size)) {
                try astgen.errors.add(
                    astgen.tree.tokenLoc(field_node),
                    "invalid swizzle name",
                    .{},
                    null,
                );
                return error.AnalysisFail;
            }

            var pattern: [4]Inst.SwizzleAccess.Component = undefined;
            for (field_name, 0..) |c, i| {
                pattern[i] = switch (c) {
                    'x', 'r' => .x,
                    'y', 'g' => .y,
                    'z', 'b' => .z,
                    'w', 'a' => .w,
                    else => {
                        try astgen.errors.add(
                            astgen.tree.tokenLoc(field_node),
                            "invalid swizzle name",
                            .{},
                            null,
                        );
                        return error.AnalysisFail;
                    },
                };
            }

            const inst = try astgen.addInst(.{
                .swizzle_access = .{
                    .base = base,
                    .size = @enumFromInt(Inst.SwizzleAccess.Size, field_name.len),
                    .pattern = pattern,
                },
            });
            return inst;
        },
        .struct_ref => |base_struct| {
            const struct_members = astgen.getInst(base_struct).@"struct".members;
            for (astgen.refToList(struct_members)) |member| {
                const member_data = astgen.getInst(member).struct_member;
                if (std.mem.eql(u8, field_name, astgen.getStr(member_data.name))) {
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
                    astgen.getStr(astgen.getInst(base_struct).@"struct".name),
                    field_name,
                },
                null,
            );
            return error.AnalysisFail;
        },
        else => {
            try astgen.errors.add(
                astgen.tree.nodeLoc(node),
                "expected struct type",
                .{},
                null,
            );
            return error.AnalysisFail;
        },
    }
}

fn genType(astgen: *AstGen, scope: *Scope, node: NodeIndex) error{ AnalysisFail, OutOfMemory }!InstIndex {
    const inst = switch (astgen.tree.nodeTag(node)) {
        .bool_type => try astgen.addInst(.{ .bool = .{ .value = null } }),
        .number_type => try astgen.genNumberType(node),
        .vector_type => try astgen.genVector(scope, node, .none, null),
        .matrix_type => try astgen.genMatrix(scope, node, .none, null),
        .atomic_type => try astgen.genAtomicType(scope, node),
        .array_type => try astgen.genArray(scope, node, null),
        .ptr_type => try astgen.genPtrType(scope, node),
        .sampler_type => try astgen.genSamplerType(node),
        .sampled_texture_type => try astgen.genSampledTextureType(scope, node),
        .multisampled_texture_type => try astgen.genMultisampledTextureType(scope, node),
        .storage_texture_type => try astgen.genStorageTextureType(node),
        .depth_texture_type => try astgen.genDepthTextureType(node),
        .external_texture_type => try astgen.addInst(.external_texture_type),
        .ident => {
            const node_loc = astgen.tree.nodeLoc(node);
            const decl = try astgen.findSymbol(scope, astgen.tree.nodeToken(node));
            switch (astgen.getInst(decl)) {
                .bool,
                .int,
                .float,
                .vector,
                .matrix,
                .atomic_type,
                .array,
                .ptr_type,
                .sampler_type,
                .comparison_sampler_type,
                .external_texture_type,
                .sampled_texture_type,
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
    return inst;
}

fn genNumberType(astgen: *AstGen, node: NodeIndex) !InstIndex {
    const token = astgen.tree.nodeToken(node);
    const token_tag = astgen.tree.tokenTag(token);
    return astgen.addInst(switch (token_tag) {
        .k_u32 => .{ .int = .{ .type = .u32, .value = null } },
        .k_i32 => .{ .int = .{ .type = .i32, .value = null } },
        .k_f32 => .{ .float = .{ .type = .f32, .value = null } },
        .k_f16 => .{ .float = .{ .type = .f16, .value = null } },
        else => unreachable,
    });
}

fn genVector(astgen: *AstGen, scope: *Scope, node: NodeIndex, element_type: InstIndex, value: ?Air.Inst.Vector.Value) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    var loc = astgen.tree.nodeLoc(node);
    var elem_type = element_type;
    if (node_lhs != .none) {
        loc = astgen.tree.nodeLoc(node_lhs);
        elem_type = try astgen.genType(scope, node_lhs);
    }

    switch (astgen.getInst(elem_type)) {
        .bool, .int, .float => {},
        else => {
            try astgen.errors.add(
                loc,
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

    const token_tag = astgen.tree.tokenTag(astgen.tree.nodeToken(node));
    return astgen.addInst(.{
        .vector = .{
            .size = switch (token_tag) {
                .k_vec2 => .two,
                .k_vec3 => .three,
                .k_vec4 => .four,
                else => unreachable,
            },
            .elem_type = elem_type,
            .value = if (value) |val| try astgen.addValue(Inst.Vector.Value, val) else null,
        },
    });
}

fn genMatrix(astgen: *AstGen, scope: *Scope, node: NodeIndex, element_type: InstIndex, value: ?Air.Inst.Matrix.Value) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    var loc = astgen.tree.nodeLoc(node);
    var elem_type = element_type;
    if (node_lhs != .none) {
        loc = astgen.tree.nodeLoc(node_lhs);
        elem_type = try astgen.genType(scope, node_lhs);
    }

    if (astgen.getInst(elem_type) != .float) {
        try astgen.errors.add(
            loc,
            "invalid matrix component type",
            .{},
            try astgen.errors.createNote(
                null,
                "must be 'f32' or 'f16'",
                .{},
            ),
        );
        return error.AnalysisFail;
    }

    const token_tag = astgen.tree.tokenTag(astgen.tree.nodeToken(node));
    return astgen.addInst(.{
        .matrix = .{
            .cols = matrixCols(token_tag),
            .rows = matrixRows(token_tag),
            .elem_type = elem_type,
            .value = if (value) |val| try astgen.addValue(Inst.Matrix.Value, val) else null,
        },
    });
}

fn matrixCols(tag: TokenTag) Air.Inst.Vector.Size {
    return switch (tag) {
        .k_mat2x2, .k_mat2x3, .k_mat2x4 => .two,
        .k_mat3x2, .k_mat3x3, .k_mat3x4 => .three,
        .k_mat4x2, .k_mat4x3, .k_mat4x4 => .four,
        else => unreachable,
    };
}

fn matrixRows(tag: TokenTag) Air.Inst.Vector.Size {
    return switch (tag) {
        .k_mat2x2, .k_mat3x2, .k_mat4x2 => .two,
        .k_mat2x3, .k_mat3x3, .k_mat4x3 => .three,
        .k_mat2x4, .k_mat3x4, .k_mat4x4 => .four,
        else => unreachable,
    };
}

fn genAtomicType(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    const elem_type = try astgen.genType(scope, node_lhs);

    if (astgen.getInst(elem_type) == .int) {
        return astgen.addInst(.{ .atomic_type = .{ .elem_type = elem_type } });
    }

    try astgen.errors.add(
        astgen.tree.nodeLoc(node_lhs),
        "invalid atomic component type",
        .{},
        try astgen.errors.createNote(
            null,
            "must be 'i32' or 'u32'",
            .{},
        ),
    );
    return error.AnalysisFail;
}

fn genPtrType(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    const elem_type = try astgen.genType(scope, node_lhs);

    switch (astgen.getInst(elem_type)) {
        .bool,
        .int,
        .float,
        .sampler_type,
        .comparison_sampler_type,
        .external_texture_type,
        => {
            const extra = astgen.tree.extraData(Node.PtrType, astgen.tree.nodeRHS(node));

            const addr_space_loc = astgen.tree.tokenLoc(extra.addr_space);
            const ast_addr_space = stringToEnum(Ast.AddressSpace, addr_space_loc.slice(astgen.tree.source)).?;
            const addr_space: Inst.PointerType.AddressSpace = switch (ast_addr_space) {
                .function => .function,
                .private => .private,
                .workgroup => .workgroup,
                .uniform => .uniform,
                .storage => .storage,
            };

            var access_mode: ?Inst.PointerType.AccessMode = null;
            if (extra.access_mode != .none) {
                const access_mode_loc = astgen.tree.tokenLoc(extra.access_mode);
                const ast_access_mode = stringToEnum(Ast.AccessMode, access_mode_loc.slice(astgen.tree.source)).?;
                access_mode = switch (ast_access_mode) {
                    .read => .read,
                    .write => .write,
                    .read_write => .read_write,
                };
            }

            return astgen.addInst(.{
                .ptr_type = .{
                    .elem_type = elem_type,
                    .addr_space = addr_space,
                    .access_mode = access_mode,
                },
            });
        },
        else => {},
    }

    try astgen.errors.add(
        astgen.tree.nodeLoc(node_lhs),
        "invalid pointer component type",
        .{},
        null,
    );
    return error.AnalysisFail;
}

fn genArray(astgen: *AstGen, scope: *Scope, node: NodeIndex, args: ?RefIndex) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    var elem_type = InstIndex.none;
    if (node_lhs != .none) {
        elem_type = try astgen.genType(scope, node_lhs);
        switch (astgen.getInst(elem_type)) {
            .array,
            .atomic_type,
            .struct_ref,
            .bool,
            .int,
            .float,
            .vector,
            .matrix,
            => {
                if (astgen.getInst(elem_type) == .array) {
                    if (astgen.getInst(elem_type).array.len == .none) {
                        try astgen.errors.add(
                            astgen.tree.nodeLoc(node_lhs),
                            "array component type can not be a runtime-known array",
                            .{},
                            null,
                        );
                        return error.AnalysisFail;
                    }
                }
            },
            else => {
                try astgen.errors.add(
                    astgen.tree.nodeLoc(node_lhs),
                    "invalid array component type",
                    .{},
                    null,
                );
                return error.AnalysisFail;
            },
        }
    }

    if (args != null) {
        if (args.? == .none) {
            try astgen.errors.add(
                astgen.tree.nodeLoc(node),
                "element type not specified",
                .{},
                null,
            );
            return error.AnalysisFail;
        }

        if (elem_type == .none) {
            elem_type = astgen.refToList(args.?)[0];
        }
    }

    const len_node = astgen.tree.nodeRHS(node);
    var len = InstIndex.none;
    if (len_node != .none) {
        len = try astgen.genExpr(scope, len_node);
        if (try astgen.resolveConstExpr(len) == null) {
            try astgen.errors.add(
                astgen.tree.nodeLoc(len_node),
                "expected const-expression",
                .{},
                null,
            );
            return error.AnalysisFail;
        }
    }

    return astgen.addInst(.{
        .array = .{
            .elem_type = elem_type,
            .len = len,
            .value = args,
        },
    });
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

fn genSampledTextureType(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    const elem_type = try astgen.genType(scope, node_lhs);
    const elem_type_inst = astgen.getInst(elem_type);

    if (elem_type_inst == .int or (elem_type_inst == .float and elem_type_inst.float.type == .f32)) {
        const token_tag = astgen.tree.tokenTag(astgen.tree.nodeToken(node));
        return astgen.addInst(.{
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
                .elem_type = elem_type,
            },
        });
    }

    try astgen.errors.add(
        astgen.tree.nodeLoc(node_lhs),
        "invalid texture component type",
        .{},
        try astgen.errors.createNote(
            null,
            "must be 'i32', 'u32' or 'f32'",
            .{},
        ),
    );
    return error.AnalysisFail;
}

fn genMultisampledTextureType(astgen: *AstGen, scope: *Scope, node: NodeIndex) !InstIndex {
    const node_lhs = astgen.tree.nodeLHS(node);
    var elem_type = InstIndex.none;

    if (node_lhs != .none) {
        elem_type = try astgen.genType(scope, node_lhs);
        const elem_type_inst = astgen.getInst(elem_type);

        if (elem_type_inst != .int and !(elem_type_inst == .float and elem_type_inst.float.type == .f32)) {
            try astgen.errors.add(
                astgen.tree.nodeLoc(node_lhs),
                "invalid multisampled texture component type",
                .{},
                try astgen.errors.createNote(
                    null,
                    "must be 'i32', 'u32' or 'f32'",
                    .{},
                ),
            );
            return error.AnalysisFail;
        }
    }

    const token_tag = astgen.tree.tokenTag(astgen.tree.nodeToken(node));
    return astgen.addInst(.{
        .multisampled_texture_type = .{
            .kind = switch (token_tag) {
                .k_texture_multisampled_2d => .@"2d",
                .k_texture_depth_multisampled_2d => .depth_2d,
                else => unreachable,
            },
            .elem_type = elem_type,
        },
    });
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
        var iter = s.decls.iterator();
        while (iter.next()) |decl| {
            const decl_node = decl.key_ptr.*;
            const decl_inst = try decl.value_ptr.*;
            if (std.mem.eql(u8, name, astgen.tree.declNameLoc(decl_node).?.slice(astgen.tree.source))) {
                if (decl_inst == .none) {
                    // declaration has not analysed
                    switch (s.tag) {
                        .root => return astgen.genGlobalDecl(s, decl_node),
                        .@"fn",
                        .block,
                        .loop,
                        .continuing,
                        .switch_case,
                        .@"if",
                        .@"for",
                        => {},
                    }
                } else {
                    return decl_inst;
                }
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

fn resolve(astgen: *AstGen, index: InstIndex) !InstIndex {
    var in_deref = false;
    var idx = index;

    while (true) {
        const inst = astgen.getInst(idx);
        switch (inst) {
            inline .bool, .int, .float, .vector, .matrix, .array => |data| {
                std.debug.assert(data.value != null);
                return idx;
            },
            .struct_construct => |struct_construct| return struct_construct.@"struct",
            .bitcast => |bitcast| return bitcast.result_type,
            .addr_of => return idx,

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
            .builtin_min,
            .builtin_max,
            => |bin| idx = astgen.selectType(&.{ bin.lhs, bin.rhs }),

            .builtin_smoothstep => |smoothstep| {
                idx = astgen.selectType(&.{ smoothstep.low, smoothstep.high, smoothstep.x });
            },

            .builtin_select => |select| idx = astgen.selectType(&.{ select.true, select.false }),

            .logical_and,
            .logical_or,
            .equal,
            .not_equal,
            .less_than,
            .less_than_equal,
            .greater_than,
            .greater_than_equal,
            .builtin_all,
            .builtin_any,
            => return astgen.addInst(.{ .bool = .{ .value = null } }),

            .not,
            .negate,
            .builtin_abs,
            .builtin_acos,
            .builtin_acosh,
            .builtin_asin,
            .builtin_asinh,
            .builtin_atan,
            .builtin_atanh,
            .builtin_ceil,
            .builtin_cos,
            .builtin_cosh,
            .builtin_count_leading_zeros,
            .builtin_count_one_bits,
            .builtin_count_trailing_zeros,
            .builtin_degrees,
            .builtin_exp,
            .builtin_exp2,
            .builtin_first_leading_bit,
            .builtin_first_trailing_bit,
            .builtin_floor,
            .builtin_fract,
            .builtin_inverse_sqrt,
            .builtin_length,
            .builtin_log,
            .builtin_log2,
            .builtin_quantize_to_F16,
            .builtin_radians,
            .builtin_reverseBits,
            .builtin_round,
            .builtin_saturate,
            .builtin_sign,
            .builtin_sin,
            .builtin_sinh,
            .builtin_sqrt,
            .builtin_tan,
            .builtin_tanh,
            .builtin_trunc,
            .builtin_dpdx,
            .builtin_dpdx_coarse,
            .builtin_dpdx_fine,
            .builtin_dpdy,
            .builtin_dpdy_coarse,
            .builtin_dpdy_fine,
            .builtin_fwidth,
            .builtin_fwidth_coarse,
            .builtin_fwidth_fine,
            => |un| idx = un,

            .deref => {
                in_deref = true;
                idx = inst.deref;
            },

            .call => |call| return astgen.getInst(call.@"fn").@"fn".return_type,
            .var_ref => |var_ref| idx = var_ref,

            .field_access => |field_access| {
                const field_type = astgen.getInst(field_access.field).struct_member.type;
                if (in_deref) {
                    return astgen.getInst(field_type).ptr_type.elem_type;
                }
                return field_type;
            },
            .swizzle_access => |swizzle_access| {
                const vector_base = try astgen.resolve(swizzle_access.base);
                const elem_type = astgen.getInst(vector_base).vector.elem_type;
                if (swizzle_access.size == .one) {
                    return elem_type;
                }
                return astgen.addInst(.{
                    .vector = .{
                        .elem_type = elem_type,
                        .size = @enumFromInt(Inst.Vector.Size, @intFromEnum(swizzle_access.size)),
                        .value = null,
                    },
                });
            },
            .index_access => |index_access| {
                const elem_type = index_access.elem_type;
                if (in_deref) {
                    return astgen.getInst(elem_type).ptr_type.elem_type;
                }
                return elem_type;
            },

            inline .global_var, .override, .@"var", .@"const", .let => |decl| {
                std.debug.assert(index != idx);

                const decl_type = decl.type;
                const decl_expr = decl.expr;
                if (decl_type != .none) {
                    if (in_deref) {
                        return astgen.getInst(decl_type).ptr_type.elem_type;
                    }
                    return decl_type;
                }
                idx = decl_expr;
            },

            .fn_param => |param| return param.type,

            .struct_ref => |struct_ref| return struct_ref,

            .atomic_type,
            .ptr_type,
            .sampler_type,
            .comparison_sampler_type,
            .external_texture_type,
            .sampled_texture_type,
            .multisampled_texture_type,
            .storage_texture_type,
            .depth_texture_type,
            .@"fn",
            .@"struct",
            .struct_member,
            .block,
            .loop,
            .continuing,
            .@"return",
            .break_if,
            .@"if",
            .@"while",
            .@"for",
            .discard,
            .@"break",
            .@"continue",
            .@"switch",
            .switch_case,
            .assign,
            .assign_add,
            .assign_sub,
            .assign_mul,
            .assign_div,
            .assign_mod,
            .assign_and,
            .assign_or,
            .assign_xor,
            .assign_shl,
            .assign_shr,
            .assign_phony,
            .increase,
            .decrease,
            => unreachable,
        }
    }
}

fn selectType(astgen: *AstGen, cands: []const InstIndex) InstIndex {
    for (cands) |cand| {
        switch (astgen.getInst(cand)) {
            inline .int, .float => |num| {
                if (num.type != .abstract) {
                    return cand;
                }
            },
            else => return cand,
        }
    }
    return cands[0];
}

fn resolveConstExpr(astgen: *AstGen, inst_idx: InstIndex) !?Value {
    const inst = astgen.getInst(inst_idx);
    switch (inst) {
        .bool => |data| {
            if (data.value) |value| {
                switch (value) {
                    .literal => |literal| return .{ .bool = literal },
                    .inst => return null,
                }
            } else {
                return null;
            }
        },
        .int => |data| {
            if (data.value) |value| {
                switch (astgen.getValue(Inst.Int.Value, value)) {
                    .literal => |literal| return .{ .int = literal.value },
                    .inst => return null,
                }
            } else {
                return null;
            }
        },
        .float => |data| {
            if (data.value) |value| {
                switch (astgen.getValue(Inst.Float.Value, value)) {
                    .literal => |literal| return .{ .float = literal.value },
                    .inst => return null,
                }
            } else {
                return null;
            }
        },
        .negate, .not => |un| {
            const value = try astgen.resolveConstExpr(un) orelse return null;
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
            const lhs = try astgen.resolveConstExpr(bin.lhs) orelse return null;
            const rhs = try astgen.resolveConstExpr(bin.rhs) orelse return null;
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
        .var_ref => {
            const res = try astgen.resolve(inst_idx);
            return try astgen.resolveConstExpr(res);
        },
        else => return null,
    }
}

fn eql(astgen: *AstGen, a_idx: InstIndex, b_idx: InstIndex) bool {
    const a = astgen.getInst(a_idx);
    const b = astgen.getInst(b_idx);

    return switch (a) {
        .vector => |vec_a| switch (b) {
            .vector => |vec_b| astgen.eqlVector(vec_a, vec_b),
            else => false,
        },
        .int => |int_a| switch (b) {
            .int => |int_b| int_a.type == int_b.type or
                int_a.type == .abstract or
                int_b.type == .abstract,
            else => false,
        },
        .float => |float_a| switch (b) {
            .float => |float_b| float_a.type == float_b.type or
                float_a.type == .abstract or
                float_b.type == .abstract,
            else => false,
        },
        .matrix => |mat_a| switch (b) {
            .matrix => |mat_b| astgen.eqlMatrix(mat_a, mat_b),
            else => false,
        },
        else => if (std.meta.activeTag(a) == std.meta.activeTag(b)) true else false,
    };
}

fn eqlVector(astgen: *AstGen, a: Air.Inst.Vector, b: Air.Inst.Vector) bool {
    return a.size == b.size and astgen.eql(a.elem_type, b.elem_type);
}

fn eqlMatrix(astgen: *AstGen, a: Air.Inst.Matrix, b: Air.Inst.Matrix) bool {
    return a.cols == b.cols and a.rows == b.rows and astgen.eql(a.elem_type, b.elem_type);
}

fn addInst(astgen: *AstGen, inst: Inst) error{OutOfMemory}!InstIndex {
    try astgen.instructions.put(astgen.allocator, inst, {});
    return @enumFromInt(InstIndex, astgen.instructions.getIndex(inst).?);
}

fn addRefList(astgen: *AstGen, list: []const InstIndex) error{OutOfMemory}!RefIndex {
    const len = list.len + 1;
    try astgen.refs.ensureUnusedCapacity(astgen.allocator, len);
    astgen.refs.appendSliceAssumeCapacity(list);
    astgen.refs.appendAssumeCapacity(.none);
    return @enumFromInt(RefIndex, astgen.refs.items.len - len);
}

fn addString(astgen: *AstGen, str: []const u8) error{OutOfMemory}!StringIndex {
    const len = str.len + 1;
    try astgen.strings.ensureUnusedCapacity(astgen.allocator, len);
    astgen.strings.appendSliceAssumeCapacity(str);
    astgen.strings.appendAssumeCapacity(0);
    return @enumFromInt(StringIndex, astgen.strings.items.len - len);
}

fn addValue(astgen: *AstGen, comptime T: type, value: T) error{OutOfMemory}!ValueIndex {
    const value_bytes = std.mem.asBytes(&value);
    try astgen.values.appendSlice(astgen.allocator, value_bytes);
    std.testing.expectEqual(value, std.mem.bytesToValue(T, value_bytes)) catch unreachable;
    return @enumFromInt(ValueIndex, astgen.values.items.len - value_bytes.len);
}

fn getInst(astgen: *AstGen, inst: InstIndex) Inst {
    return astgen.instructions.entries.slice().items(.key)[@intFromEnum(inst)];
}

fn getValue(astgen: *AstGen, comptime T: type, value: ValueIndex) T {
    return std.mem.bytesAsValue(T, astgen.values.items[@intFromEnum(value)..][0..@sizeOf(T)]).*;
}

fn getStr(astgen: *AstGen, index: StringIndex) []const u8 {
    return std.mem.sliceTo(astgen.strings.items[@intFromEnum(index)..], 0);
}

fn refToList(astgen: *AstGen, ref: RefIndex) []const InstIndex {
    return std.mem.sliceTo(astgen.refs.items[@intFromEnum(ref)..], .none);
}

fn failArgCountMismatch(
    astgen: *AstGen,
    node_loc: Loc,
    expected: usize,
    actual: usize,
) error{ OutOfMemory, AnalysisFail } {
    try astgen.errors.add(
        node_loc,
        "expected {} argument(s), found {}",
        .{ expected, actual },
        null,
    );
    return error.AnalysisFail;
}

const Value = union(enum) {
    int: i64,
    float: f64,
    bool: bool,

    fn negate(unary: Value) Value {
        return switch (unary) {
            .int => .{ .int = -unary.int },
            .float => .{ .float = -unary.float },
            .bool => unreachable,
        };
    }

    fn not(unary: Value) Value {
        return .{ .bool = !unary.bool };
    }

    fn mul(lhs: Value, rhs: Value) Value {
        return switch (lhs) {
            .int => .{ .int = lhs.int * rhs.int },
            .float => .{ .float = lhs.float * rhs.float },
            .bool => unreachable,
        };
    }

    fn div(lhs: Value, rhs: Value) Value {
        return switch (lhs) {
            .int => .{ .int = @divExact(lhs.int, rhs.int) },
            .float => .{ .float = lhs.float / rhs.float },
            .bool => unreachable,
        };
    }

    fn mod(lhs: Value, rhs: Value) Value {
        return switch (lhs) {
            .int => .{ .int = @rem(lhs.int, rhs.int) },
            .float => .{ .float = @rem(lhs.float, rhs.float) },
            .bool => unreachable,
        };
    }

    fn add(lhs: Value, rhs: Value) Value {
        return switch (lhs) {
            .int => .{ .int = lhs.int + rhs.int },
            .float => .{ .float = lhs.float + rhs.float },
            .bool => unreachable,
        };
    }

    fn sub(lhs: Value, rhs: Value) Value {
        return switch (lhs) {
            .int => .{ .int = lhs.int - rhs.int },
            .float => .{ .float = lhs.float - rhs.float },
            .bool => unreachable,
        };
    }

    fn shiftLeft(lhs: Value, rhs: Value) Value {
        return .{ .int = lhs.int << @intCast(u6, rhs.int) };
    }

    fn shiftRight(lhs: Value, rhs: Value) Value {
        return .{ .int = lhs.int >> @intCast(u6, rhs.int) };
    }

    fn bitwiseAnd(lhs: Value, rhs: Value) Value {
        return switch (lhs) {
            .int => .{ .int = lhs.int & rhs.int },
            .float, .bool => unreachable,
        };
    }

    fn bitwiseOr(lhs: Value, rhs: Value) Value {
        return .{ .int = lhs.int | rhs.int };
    }

    fn bitwiseXor(lhs: Value, rhs: Value) Value {
        return .{ .int = lhs.int ^ rhs.int };
    }

    fn equal(lhs: Value, rhs: Value) Value {
        return switch (lhs) {
            .int => .{ .bool = lhs.int == rhs.int },
            .float => .{ .bool = lhs.float == rhs.float },
            .bool => unreachable,
        };
    }

    fn notEqual(lhs: Value, rhs: Value) Value {
        return switch (lhs) {
            .int => .{ .bool = lhs.int != rhs.int },
            .float => .{ .bool = lhs.float != rhs.float },
            .bool => unreachable,
        };
    }

    fn lessThan(lhs: Value, rhs: Value) Value {
        return switch (lhs) {
            .int => .{ .bool = lhs.int < rhs.int },
            .float => .{ .bool = lhs.float < rhs.float },
            .bool => unreachable,
        };
    }

    fn greaterThan(lhs: Value, rhs: Value) Value {
        return switch (lhs) {
            .int => .{ .bool = lhs.int > rhs.int },
            .float => .{ .bool = lhs.float > rhs.float },
            .bool => unreachable,
        };
    }

    fn lessThanEqual(lhs: Value, rhs: Value) Value {
        return switch (lhs) {
            .int => .{ .bool = lhs.int <= rhs.int },
            .float => .{ .bool = lhs.float <= rhs.float },
            .bool => unreachable,
        };
    }

    fn greaterThanEqual(lhs: Value, rhs: Value) Value {
        return switch (lhs) {
            .int => .{ .bool = lhs.int >= rhs.int },
            .float => .{ .bool = lhs.float >= rhs.float },
            .bool => unreachable,
        };
    }

    fn logicalAnd(lhs: Value, rhs: Value) Value {
        return .{ .bool = lhs.bool and rhs.bool };
    }

    fn logicalOr(lhs: Value, rhs: Value) Value {
        return .{ .bool = lhs.bool or rhs.bool };
    }
};

const BuiltinFn = enum {
    all,
    any,
    select,
    arrayLength, // unimplemented
    abs,
    acos,
    acosh,
    asin,
    asinh,
    atan,
    atanh,
    atan2, // unimplemented
    ceil,
    clamp, // unimplemented
    cos,
    cosh,
    countLeadingZeros,
    countOneBits,
    countTrailingZeros,
    cross, // unimplemented
    degrees,
    determinant, // unimplemented
    distance, // unimplemented
    dot, // unimplemented
    exp,
    exp2,
    extractBits, // unimplemented
    faceForward, // unimplemented
    firstLeadingBit,
    firstTrailingBit,
    floor,
    fma, // unimplemented
    fract,
    frexp, // unimplemented
    insertBits, // unimplemented
    inverseSqrt,
    ldexp, // unimplemented
    length,
    log,
    log2,
    max, // unimplemented
    min, // unimplemented
    mix, // unimplemented
    modf, // unimplemented
    normalize, // unimplemented
    pow, // unimplemented
    quantizeToF16,
    radians,
    reflect, // unimplemented
    refract, // unimplemented
    reverseBits,
    round,
    saturate,
    sign,
    sin,
    sinh,
    smoothstep, // unimplemented
    sqrt,
    step, // unimplemented
    tan,
    tanh,
    transpose, // unimplemented
    trunc,
    dpdx,
    dpdxCoarse,
    dpdxFine,
    dpdy,
    dpdyCoarse,
    dpdyFine,
    fwidth,
    fwidthCoarse,
    fwidthFine,
    textureDimensions, // unimplemented
    textureGather, // unimplemented
    textureLoad, // unimplemented
    textureNumLayers, // unimplemented
    textureNumLevels, // unimplemented
    textureNumSamples, // unimplemented
    textureSample, // unimplemented
    textureSampleBias, // unimplemented
    textureSampleCompare, // unimplemented
    textureSampleCompareLevel, // unimplemented
    textureSampleGrad, // unimplemented
    textureSampleLevel, // unimplemented
    textureSampleBaseClampToEdge, // unimplemented
    textureStore, // unimplemented
    atomicLoad, // unimplemented
    atomicStore, // unimplemented
    atomicAdd, // unimplemented
    atomicSub, // unimplemented
    atomicMax, // unimplemented
    atomicMin, // unimplemented
    atomicAnd, // unimplemented
    atomicOr, // unimplemented
    atomicXor, // unimplemented
    atomicExchange, // unimplemented
    atomicCompareExchangeWeak, // unimplemented
    pack4x8unorm, // unimplemented
    pack2x16snorm, // unimplemented
    pack2x16unorm, // unimplemented
    pack2x16float, // unimplemented
    unpack4x8snorm, // unimplemented
    unpack4x8unorm, // unimplemented
    unpack2x16snorm, // unimplemented
    unpack2x16unorm, // unimplemented
    unpack2x16float, // unimplemented
    storageBarrier, // unimplemented
    workgroupBarrier, // unimplemented
    workgroupUniformLoad, // unimplemented
};
