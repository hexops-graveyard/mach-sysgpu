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
refs: []const Inst.Ref,
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

pub const Inst = struct {
    tag: Tag,
    data: Data,

    pub const Index = u32;
    pub const Ref = enum(u32) {
        none,

        bool_type,
        i32_type,
        u32_type,
        f32_type,
        f16_type,
        sampler_type,
        comparison_sampler_type,
        external_sampled_texture_type,

        true,
        false,

        _,

        pub const start_index = @typeInfo(Ref).Enum.fields.len;

        pub fn isIndex(self: Ref) bool {
            const index = @enumToInt(self);
            return index >= start_index;
        }

        pub fn toIndex(self: Ref) ?Index {
            const index = @enumToInt(self);
            if (index >= start_index) {
                return @intCast(Index, index - start_index);
            } else {
                return null;
            }
        }

        pub fn isBool(self: Ref) bool {
            return switch (self) {
                .bool_type,
                .true,
                .false,
                => true,
                else => false,
            };
        }

        pub fn isNumberType(self: Ref) bool {
            return self.isIntegerType() or self.isFloatType();
        }

        pub fn isIntegerType(self: Ref) bool {
            return switch (self) {
                .u32_type,
                .i32_type,
                => true,
                else => false,
            };
        }

        pub fn isFloatType(self: Ref) bool {
            return switch (self) {
                .f32_type,
                .f16_type,
                => true,
                else => false,
            };
        }

        pub fn is32BitNumberType(self: Ref) bool {
            return switch (self) {
                .i32_type,
                .u32_type,
                .f32_type,
                => true,
                else => false,
            };
        }
    };
    pub const Tag = enum(u6) {
        /// data is global_variable_decl
        global_variable_decl,
        /// data is const_decl
        global_const,

        /// data is fn_decl
        fn_decl,
        /// data is fn_param
        fn_param,

        /// data is struct_decl
        struct_decl,
        /// data is struct_member
        struct_member,

        /// data is vector_type
        vector_type,
        /// data is matrix_type
        matrix_type,
        /// data is atomic_type
        atomic_type,
        /// data is array_type
        array_type,
        /// data is ptr_type
        ptr_type,
        /// data is sampled_texture_type
        sampled_texture_type,
        /// data is multisampled_texture_type
        multisampled_texture_type,
        /// data is storage_texture_type
        storage_texture_type,
        /// data is depth_texture_type
        depth_texture_type,

        /// data is integer
        integer,
        /// data is float
        float,

        /// data is ref
        not,
        negate,
        deref,
        addr_of,

        /// data is binary
        mul,
        div,
        mod,
        add,
        sub,
        shift_left,
        shift_right,
        @"and",
        @"or",
        xor,
        logical_and,
        logical_or,
        equal,
        not_equal,
        less_than,
        less_than_equal,
        greater_than,
        greater_than_equal,

        /// data is field_access
        field_access,
        /// data is index_access
        index_access,
        /// data is bitcast
        bitcast,

        /// data is binary
        assign,
        assign_add,
        assign_sub,
        assign_mul,
        assign_div,
        assign_mod,
        assign_and,
        assign_or,
        assign_xor,
        assign_shl,
        assign_shr,

        /// data is ref
        var_ref,
        /// data is ref
        struct_ref,

        pub fn isDecl(self: Tag) bool {
            return switch (self) {
                .global_variable_decl, .struct_decl => true,
                else => false,
            };
        }
    };
    pub const Data = union {
        ref: Ref,
        global_variable_decl: GlobalVariableDecl,
        global_const: GlobalConstDecl,
        fn_decl: FnDecl,
        fn_param: FnArg,
        struct_decl: StructDecl,
        struct_member: StructMember,
        vector_type: VectorType,
        matrix_type: MatrixType,
        atomic_type: AtomicType,
        array_type: ArrayType,
        ptr_type: PointerType,
        sampled_texture_type: SampledTextureType,
        multisampled_texture_type: MultisampledTextureType,
        storage_texture_type: StorageTextureType,
        depth_texture_type: DepthTextureType,
        integer: Integer,
        float: Float,
        /// meaning of LHS and RHS depends on the corresponding Tag.
        binary: BinaryExpr,
        field_access: FieldAccess,
        index_access: IndexAccess,
        bitcast: Bitcast,
    };
    pub const GlobalVariableDecl = struct {
        /// index to zero-terminated string in `strings`
        name: u32,
        type: Ref = .none,
        addr_space: AddressSpace,
        access_mode: AccessMode,
        binding: Ref = .none,
        group: Ref = .none,
        expr: Ref = .none,

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
        type: Ref = .none,
        expr: Ref,
    };
    pub const FnDecl = struct {
        /// index to zero-terminated string in `strings`
        name: u32,
        stage: Stage,
        is_const: bool,
        /// nullable
        /// index to zero-terminated params Ref in `refs`
        params: u32 = 0,
        return_type: Ref,
        return_attrs: ReturnAttrs,
        /// nullable
        /// index to zero-terminated statements Ref in `refs`
        statements: u32 = 0,

        pub const Stage = union(enum) {
            normal,
            vertex,
            fragment,
            compute: WorkgroupSize,

            pub const WorkgroupSize = struct {
                x: Ref,
                y: Ref = .none,
                z: Ref = .none,
            };
        };

        pub const ReturnAttrs = struct {
            builtin: BuiltinValue = .none,
            location: Ref = .none,
            interpolate: ?Interpolate = null,
            invariant: bool = false,
        };
    };
    pub const FnArg = struct {
        /// index to zero-terminated string in `strings`
        name: u32,
        type: Ref,
        builtin: BuiltinValue = .none,
        location: Ref = .none,
        interpolate: ?Interpolate = null,
        invariant: bool = false,
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
        /// nullable
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
        /// index to zero-terminated members Ref in `refs`
        members: u32,
    };
    pub const StructMember = struct {
        /// index to zero-terminated string in `strings`
        name: u32,
        type: Ref,
        @"align": u29, // 0 means null
        size: u32, // 0 means null
    };
    pub const VectorType = struct {
        elem_type: Ref,
        size: Size,

        pub const Size = enum { two, three, four };
    };
    pub const MatrixType = struct {
        elem_type: Ref,
        cols: VectorType.Size,
        rows: VectorType.Size,
    };
    pub const AtomicType = struct { elem_type: Ref };
    pub const ArrayType = struct { elem_type: Ref, size: Ref = .none };
    pub const PointerType = struct {
        elem_type: Ref,
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
    pub const SampledTextureType = struct {
        kind: Kind,
        elem_type: Ref,

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
        elem_type: Ref,

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
    pub const BinaryExpr = struct { lhs: Ref, rhs: Ref };
    pub const FieldAccess = struct {
        base: Ref,
        field: Ref,
        /// index to zero-terminated string in `strings`
        name: u32,
    };
    pub const IndexAccess = struct {
        base: Ref,
        elem_type: Ref,
        index: Ref,
    };
    pub const Bitcast = struct {
        type: Ref,
        expr: Ref,
        result_type: Ref,
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
