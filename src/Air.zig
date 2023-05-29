//! Analyzed Intermediate Representation.
//! This data is produced by AstGen and consumed by codegen.

const std = @import("std");
const AstGen = @import("AstGen.zig");
const Ast = @import("Ast.zig");
const ErrorList = @import("ErrorList.zig");
const Air = @This();

allocator: std.mem.Allocator,
globals_index: u32,
instructions: []const Inst,
refs: []const InstIndex,
strings: []const u8,
errors: ErrorList,

pub fn deinit(self: *Air) void {
    self.allocator.free(self.instructions);
    self.allocator.free(self.refs);
    self.allocator.free(self.strings);
    self.errors.deinit();
    self.* = undefined;
}

pub fn generate(allocator: std.mem.Allocator, tree: *const Ast) error{OutOfMemory}!Air {
    var astgen = AstGen{
        .allocator = allocator,
        .tree = tree,
        .errors = try ErrorList.init(allocator),
        .scope_pool = std.heap.MemoryPool(AstGen.Scope).init(allocator),
    };
    defer {
        astgen.scope_pool.deinit();
        astgen.scratch.deinit(allocator);
    }
    errdefer {
        astgen.instructions.deinit(allocator);
        astgen.refs.deinit(allocator);
        astgen.strings.deinit(allocator);
    }

    const globals_index = try astgen.genTranslationUnit();

    return .{
        .allocator = allocator,
        .globals_index = globals_index,
        .instructions = try astgen.instructions.toOwnedSlice(allocator),
        .refs = try astgen.refs.toOwnedSlice(allocator),
        .strings = try astgen.strings.toOwnedSlice(allocator),
        .errors = astgen.errors,
    };
}

pub fn getStr(self: Air, index: u32) []const u8 {
    return std.mem.sliceTo(self.strings[index..], 0);
}

pub const InstIndex = u32;
pub const null_index: InstIndex = std.math.maxInt(InstIndex);
pub const Inst = union(enum) {
    global_variable_decl: GlobalVariableDecl,
    global_const: GlobalConstDecl,

    fn_decl: FnDecl,
    fn_param: FnParam,

    struct_decl: StructDecl,
    struct_member: StructMember,

    bool_type,
    i32_type,
    u32_type,
    f32_type,
    f16_type,
    sampler_type,
    comparison_sampler_type,
    external_texture_type,
    vector_type: VectorType,
    matrix_type: MatrixType,
    atomic_type: AtomicType,
    array_type: ArrayType,
    ptr_type: PointerType,
    texture_type: TextureType,
    multisampled_texture_type: MultisampledTextureType,
    storage_texture_type: StorageTextureType,
    depth_texture_type: DepthTextureType,

    true,
    false,
    integer: Integer,
    float: Float,

    not: InstIndex,
    negate: InstIndex,
    deref: InstIndex,
    addr_of: InstIndex,

    mul: Binary,
    div: Binary,
    mod: Binary,
    add: Binary,
    sub: Binary,
    shift_left: Binary,
    shift_right: Binary,
    @"and": Binary,
    @"or": Binary,
    xor: Binary,
    logical_and: Binary,
    logical_or: Binary,
    equal: Binary,
    not_equal: Binary,
    less_than: Binary,
    less_than_equal: Binary,
    greater_than: Binary,
    greater_than_equal: Binary,

    assign: Binary,
    assign_add: Binary,
    assign_sub: Binary,
    assign_mul: Binary,
    assign_div: Binary,
    assign_mod: Binary,
    assign_and: Binary,
    assign_or: Binary,
    assign_xor: Binary,
    assign_shl: Binary,
    assign_shr: Binary,

    field_access: FieldAccess,
    index_access: IndexAccess,
    bitcast: Bitcast,

    var_ref: InstIndex,
    struct_ref: InstIndex,

    pub fn eql(a: Air.Inst, b: Air.Inst) bool {
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
            else => if (std.meta.activeTag(a) == std.meta.activeTag(b)) true else false,
        };
    }

    pub const GlobalVariableDecl = struct {
        /// index to zero-terminated string in `strings`
        name: u32,
        type: InstIndex,
        addr_space: AddressSpace,
        access_mode: AccessMode,
        binding: InstIndex,
        group: InstIndex,
        expr: InstIndex,

        pub const AddressSpace = enum {
            none,
            function,
            private,
            workgroup,
            uniform,
            storage,
        };

        pub const AccessMode = enum {
            none,
            read,
            write,
            read_write,
        };
    };

    pub const GlobalConstDecl = struct {
        /// index to zero-terminated string in `strings`
        name: u32,
        type: InstIndex,
        expr: InstIndex,
    };

    pub const FnDecl = struct {
        /// index to zero-terminated string in `strings`
        name: u32,
        stage: Stage,
        is_const: bool,
        /// index to zero-terminated params InstIndex in `refs`
        params: u32,
        return_type: InstIndex,
        return_attrs: ReturnAttrs,
        /// index to zero-terminated statements InstIndex in `refs`
        statements: u32,

        pub const Stage = union(enum) {
            normal,
            vertex,
            fragment,
            compute: WorkgroupSize,

            pub const WorkgroupSize = struct {
                x: InstIndex,
                y: InstIndex,
                z: InstIndex,
            };
        };

        pub const ReturnAttrs = struct {
            builtin: BuiltinValue,
            location: InstIndex,
            interpolate: ?Interpolate,
            invariant: bool,
        };
    };

    pub const FnParam = struct {
        /// index to zero-terminated string in `strings`
        name: u32,
        type: InstIndex,
        builtin: BuiltinValue,
        location: InstIndex,
        interpolate: ?Interpolate,
        invariant: bool,
    };

    pub const BuiltinValue = enum {
        none,
        vertex_index,
        instance_index,
        position,
        front_facing,
        frag_depth,
        local_invocation_id,
        local_invocation_index,
        global_invocation_id,
        workgroup_id,
        num_workgroups,
        sample_index,
        sample_mask,

        pub fn fromAst(ast: Ast.BuiltinValue) BuiltinValue {
            return switch (ast) {
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
        }
    };

    pub const Interpolate = struct {
        type: Type,
        sample: Sample,

        pub const Type = enum {
            perspective,
            linear,
            flat,
        };

        pub const Sample = enum {
            none,
            center,
            centroid,
            sample,
        };
    };

    pub const StructDecl = struct {
        /// index to zero-terminated string in `strings`
        name: u32,
        /// index to zero-terminated members InstIndex in `refs`
        members: u32,
    };

    pub const StructMember = struct {
        /// index to zero-terminated string in `strings`
        name: u32,
        type: InstIndex,
        @"align": u29,
        size: u32,
    };

    pub const VectorType = struct {
        elem_type: InstIndex,
        size: Size,

        pub const Size = enum { two, three, four };
    };

    pub const MatrixType = struct {
        elem_type: InstIndex,
        cols: VectorType.Size,
        rows: VectorType.Size,
    };

    pub const AtomicType = struct { elem_type: InstIndex };

    pub const ArrayType = struct { elem_type: InstIndex, size: InstIndex = null_index };

    pub const PointerType = struct {
        elem_type: InstIndex,
        addr_space: AddressSpace,
        access_mode: AccessMode,

        pub const AddressSpace = enum {
            function,
            private,
            workgroup,
            uniform,
            storage,
        };

        pub const AccessMode = enum {
            none,
            read,
            write,
            read_write,
        };
    };

    pub const TextureType = struct {
        kind: Kind,
        elem_type: InstIndex,

        pub const Kind = enum {
            @"1d",
            @"2d",
            @"2d_array",
            @"3d",
            cube,
            cube_array,
        };
    };

    pub const MultisampledTextureType = struct {
        kind: Kind,
        elem_type: InstIndex,

        pub const Kind = enum { @"2d" };
    };

    pub const StorageTextureType = struct {
        kind: Kind,
        texel_format: TexelFormat,
        access_mode: AccessMode,

        pub const Kind = enum {
            @"1d",
            @"2d",
            @"2d_array",
            @"3d",
        };

        pub const TexelFormat = enum {
            rgba8unorm,
            rgba8snorm,
            rgba8uint,
            rgba8sint,
            rgba16uint,
            rgba16sint,
            rgba16float,
            r32uint,
            r32sint,
            r32float,
            rg32uint,
            rg32sint,
            rg32float,
            rgba32uint,
            rgba32sint,
            rgba32float,
            bgra8unorm,
        };

        pub const AccessMode = enum { write };
    };

    pub const DepthTextureType = enum {
        @"2d",
        @"2d_array",
        cube,
        cube_array,
        multisampled_2d,
    };

    pub const Binary = struct { lhs: InstIndex, rhs: InstIndex };

    pub const FieldAccess = struct {
        base: InstIndex,
        field: InstIndex,
        /// index to zero-terminated string in `strings`
        name: u32,
    };

    pub const IndexAccess = struct {
        base: InstIndex,
        elem_type: InstIndex,
        index: InstIndex,
    };

    pub const Bitcast = struct {
        type: InstIndex,
        expr: InstIndex,
        result_type: InstIndex,
    };

    pub const Integer = struct {
        value: i64,
        base: u8,
        tag: enum { none, i, u },
    };

    pub const Float = struct {
        value: f64,
        base: u8,
        tag: enum { none, f, h },
    };

    comptime {
        std.debug.assert(@sizeOf(Inst) <= 64);
    }
};
