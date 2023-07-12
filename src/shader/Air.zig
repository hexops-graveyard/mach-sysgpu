//! Analyzed Intermediate Representation.
//! This data is produced by AstGen and consumed by CodeGen.

const std = @import("std");
const AstGen = @import("AstGen.zig");
const Ast = @import("Ast.zig");
const ErrorList = @import("ErrorList.zig");
const Extensions = @import("wgsl.zig").Extensions;
const Air = @This();

tree: *const Ast,
globals_index: RefIndex,
compute_stage: InstIndex,
vertex_stage: InstIndex,
fragment_stage: InstIndex,
instructions: []const Inst,
refs: []const InstIndex,
strings: []const u8,
values: []const u8,
extensions: Extensions,

pub fn deinit(self: *Air, allocator: std.mem.Allocator) void {
    allocator.free(self.instructions);
    allocator.free(self.refs);
    allocator.free(self.strings);
    allocator.free(self.values);
    self.* = undefined;
}

pub fn generate(
    allocator: std.mem.Allocator,
    tree: *const Ast,
    errors: *ErrorList,
    entry_point: ?[]const u8,
) error{ OutOfMemory, AnalysisFail }!Air {
    var astgen = AstGen{
        .allocator = allocator,
        .tree = tree,
        .scope_pool = std.heap.MemoryPool(AstGen.Scope).init(allocator),
        .entry_point_name = entry_point,
        .errors = errors,
    };
    defer {
        astgen.instructions.deinit(allocator);
        astgen.scratch.deinit(allocator);
        astgen.scope_pool.deinit();
    }
    errdefer {
        astgen.refs.deinit(allocator);
        astgen.strings.deinit(allocator);
        astgen.values.deinit(allocator);
    }

    const globals_index = try astgen.genTranslationUnit();

    return .{
        .tree = tree,
        .globals_index = globals_index,
        .compute_stage = astgen.compute_stage,
        .vertex_stage = astgen.vertex_stage,
        .fragment_stage = astgen.fragment_stage,
        .instructions = try allocator.dupe(Inst, astgen.instructions.keys()),
        .refs = try astgen.refs.toOwnedSlice(allocator),
        .strings = try astgen.strings.toOwnedSlice(allocator),
        .values = try astgen.values.toOwnedSlice(allocator),
        .extensions = tree.extensions,
    };
}

pub fn refToList(self: Air, ref: RefIndex) []const InstIndex {
    return std.mem.sliceTo(self.refs[@intFromEnum(ref)..], .none);
}

pub fn getInst(self: Air, index: InstIndex) Inst {
    return self.instructions[@intFromEnum(index)];
}

pub fn getStr(self: Air, index: StringIndex) []const u8 {
    return std.mem.sliceTo(self.strings[@intFromEnum(index)..], 0);
}

pub fn getValue(self: Air, comptime T: type, value: ValueIndex) T {
    return std.mem.bytesAsValue(T, self.values[@intFromEnum(value)..][0..@sizeOf(T)]).*;
}

pub const ConstExpr = union(enum) {
    guaranteed,
    bool: bool,
    int: i33,
    float: f32,

    fn negate(unary: *ConstExpr) void {
        switch (unary.*) {
            .int => unary.int = -unary.int,
            .float => unary.float = -unary.float,
            else => unreachable,
        }
    }

    fn not(unary: *ConstExpr) void {
        switch (unary.*) {
            .bool => unary.bool = !unary.bool,
            else => unreachable,
        }
    }

    fn mul(lhs: *ConstExpr, rhs: ConstExpr) void {
        switch (lhs.*) {
            .int => lhs.int *= rhs.int,
            .float => lhs.float *= rhs.float,
            else => unreachable,
        }
    }

    fn div(lhs: *ConstExpr, rhs: ConstExpr) void {
        switch (lhs.*) {
            .int => lhs.int = @divExact(lhs.int, rhs.int),
            .float => lhs.float /= rhs.float,
            else => unreachable,
        }
    }

    fn mod(lhs: *ConstExpr, rhs: ConstExpr) void {
        switch (lhs.*) {
            .int => lhs.int = @rem(lhs.int, rhs.int),
            .float => lhs.float = @rem(lhs.float, rhs.float),
            else => unreachable,
        }
    }

    fn add(lhs: *ConstExpr, rhs: ConstExpr) void {
        switch (lhs.*) {
            .int => lhs.int += rhs.int,
            .float => lhs.float += rhs.float,
            else => unreachable,
        }
    }

    fn sub(lhs: *ConstExpr, rhs: ConstExpr) void {
        switch (lhs.*) {
            .int => lhs.int -= rhs.int,
            .float => lhs.float -= rhs.float,
            else => unreachable,
        }
    }

    fn shiftLeft(lhs: *ConstExpr, rhs: ConstExpr) void {
        switch (lhs.*) {
            .int => lhs.int <<= @intCast(rhs.int),
            else => unreachable,
        }
    }

    fn shiftRight(lhs: *ConstExpr, rhs: ConstExpr) void {
        switch (lhs.*) {
            .int => lhs.int >>= @intCast(rhs.int),
            else => unreachable,
        }
    }

    fn bitwiseAnd(lhs: *ConstExpr, rhs: ConstExpr) void {
        switch (lhs.*) {
            .int => lhs.int &= rhs.int,
            else => unreachable,
        }
    }

    fn bitwiseOr(lhs: *ConstExpr, rhs: ConstExpr) void {
        switch (lhs.*) {
            .int => lhs.int |= rhs.int,
            else => unreachable,
        }
    }

    fn bitwiseXor(lhs: *ConstExpr, rhs: ConstExpr) void {
        switch (lhs.*) {
            .int => lhs.int ^= rhs.int,
            else => unreachable,
        }
    }

    fn equal(lhs: ConstExpr, rhs: ConstExpr) ConstExpr {
        switch (lhs) {
            .bool => return .{ .bool = lhs.bool == rhs.bool },
            .int => return .{ .bool = lhs.int == rhs.int },
            .float => return .{ .bool = lhs.float == rhs.float },
            .guaranteed => unreachable,
        }
    }

    fn notEqual(lhs: ConstExpr, rhs: ConstExpr) ConstExpr {
        return switch (lhs) {
            .int => .{ .bool = lhs.int != rhs.int },
            .float => .{ .bool = lhs.float != rhs.float },
            else => unreachable,
        };
    }

    fn lessThan(lhs: ConstExpr, rhs: ConstExpr) ConstExpr {
        return switch (lhs) {
            .int => .{ .bool = lhs.int < rhs.int },
            .float => .{ .bool = lhs.float < rhs.float },
            else => unreachable,
        };
    }

    fn greaterThan(lhs: ConstExpr, rhs: ConstExpr) ConstExpr {
        return switch (lhs) {
            .int => .{ .bool = lhs.int > rhs.int },
            .float => .{ .bool = lhs.float > rhs.float },
            else => unreachable,
        };
    }

    fn lessThanEqual(lhs: ConstExpr, rhs: ConstExpr) ConstExpr {
        return switch (lhs) {
            .int => .{ .bool = lhs.int <= rhs.int },
            .float => .{ .bool = lhs.float <= rhs.float },
            else => unreachable,
        };
    }

    fn greaterThanEqual(lhs: ConstExpr, rhs: ConstExpr) ConstExpr {
        return switch (lhs) {
            .int => .{ .bool = lhs.int >= rhs.int },
            .float => .{ .bool = lhs.float >= rhs.float },
            else => unreachable,
        };
    }

    fn logicalAnd(lhs: ConstExpr, rhs: ConstExpr) ConstExpr {
        return .{ .bool = lhs.bool and rhs.bool };
    }

    fn logicalOr(lhs: ConstExpr, rhs: ConstExpr) ConstExpr {
        return .{ .bool = lhs.bool or rhs.bool };
    }
};

pub fn resolveConstExpr(air: Air, inst_idx: InstIndex) ?ConstExpr {
    const inst = air.getInst(inst_idx);
    switch (inst) {
        .bool => |data| {
            if (data.value) |value| {
                switch (value) {
                    .literal => |literal| return .{ .bool = literal },
                    .cast => return null,
                }
            } else {
                return null;
            }
        },
        .int => |data| {
            if (data.value) |value| {
                switch (air.getValue(Inst.Int.Value, value)) {
                    .literal => |literal| return .{ .int = literal },
                    .cast => return null,
                }
            } else {
                return null;
            }
        },
        .float => |data| {
            if (data.value) |value| {
                switch (air.getValue(Inst.Float.Value, value)) {
                    .literal => |literal| return .{ .float = literal },
                    .cast => return null,
                }
            } else {
                return null;
            }
        },
        .vector => |vec| {
            if (vec.value.? == .none) return .guaranteed;
            for (air.getValue(Inst.Vector.Value, vec.value.?)[0..@intFromEnum(vec.size)]) |elem_val| {
                if (air.resolveConstExpr(elem_val) == null) {
                    return null;
                }
            }
            return .guaranteed;
        },
        .matrix => |mat| {
            if (mat.value.? == .none) return .guaranteed;
            for (air.getValue(Inst.Matrix.Value, mat.value.?)[0..@intFromEnum(mat.cols)]) |elem_val| {
                if (air.resolveConstExpr(elem_val) == null) {
                    return null;
                }
            }
            return .guaranteed;
        },
        .array => |arr| {
            for (air.refToList(arr.value.?)) |elem_val| {
                if (air.resolveConstExpr(elem_val) == null) {
                    return null;
                }
            }
            return .guaranteed;
        },
        .struct_construct => |sc| {
            for (air.refToList(sc.members)) |elem_val| {
                if (air.resolveConstExpr(elem_val) == null) {
                    return null;
                }
            }
            return .guaranteed;
        },
        .negate, .not => |un| {
            var value = air.resolveConstExpr(un) orelse return null;
            switch (inst) {
                .negate => value.negate(),
                .not => value.not(),
                else => unreachable,
            }
            return value;
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
            var lhs = air.resolveConstExpr(bin.lhs) orelse return null;
            const rhs = air.resolveConstExpr(bin.rhs) orelse return null;
            switch (inst) {
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
                .equal => return lhs.equal(rhs),
                .not_equal => return lhs.notEqual(rhs),
                .less_than => return lhs.lessThan(rhs),
                .greater_than => return lhs.greaterThan(rhs),
                .less_than_equal => return lhs.lessThanEqual(rhs),
                .greater_than_equal => return lhs.greaterThanEqual(rhs),
                .logical_and => return lhs.logicalAnd(rhs),
                .logical_or => return lhs.logicalOr(rhs),
                else => unreachable,
            }
            return lhs;
        },
        .var_ref => |var_ref| return air.resolveConstExpr(var_ref),
        .@"const" => |@"const"| return air.resolveConstExpr(@"const".expr).?,
        inline .index_access, .field_access, .swizzle_access => |access| return air.resolveConstExpr(access.base),
        else => return null,
    }
}

pub const InstIndex = enum(u32) { none = std.math.maxInt(u32), _ };
pub const RefIndex = enum(u32) { none = std.math.maxInt(u32), _ };
pub const ValueIndex = enum(u32) { none = std.math.maxInt(u32), _ };
pub const StringIndex = enum(u32) { _ };

pub const Inst = union(enum) {
    @"var": Var,
    @"const": Const,
    var_ref: InstIndex,

    @"fn": Fn,
    fn_param: FnParam,

    @"struct": Struct,
    struct_member: StructMember,

    bool: Bool,
    int: Int,
    float: Float,
    vector: Vector,
    matrix: Matrix,
    array: Array,
    atomic_type: AtomicType,
    ptr_type: PointerType,
    sampled_texture_type: SampledTextureType,
    multisampled_texture_type: MultisampledTextureType,
    storage_texture_type: StorageTextureType,
    depth_texture_type: DepthTextureType,
    sampler_type,
    comparison_sampler_type,
    external_texture_type,

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

    block: RefIndex,
    loop: InstIndex,
    continuing: InstIndex,
    @"return": InstIndex,
    break_if: InstIndex,
    @"if": If,
    @"while": Binary,
    @"for": For,
    @"switch": Switch,
    switch_case: SwitchCase,
    assign: Assign,
    increase: InstIndex,
    decrease: InstIndex,
    discard,
    @"break",
    @"continue",

    field_access: FieldAccess,
    swizzle_access: SwizzleAccess,
    index_access: IndexAccess,
    call: FnCall,
    struct_construct: StructConstruct,
    bitcast: Bitcast,
    builtin_all: InstIndex,
    builtin_any: InstIndex,
    builtin_select: BuiltinSelect,
    builtin_abs: InstIndex,
    builtin_acos: InstIndex,
    builtin_acosh: InstIndex,
    builtin_asin: InstIndex,
    builtin_asinh: InstIndex,
    builtin_atan: InstIndex,
    builtin_atanh: InstIndex,
    builtin_ceil: InstIndex,
    builtin_cos: InstIndex,
    builtin_cosh: InstIndex,
    builtin_count_leading_zeros: InstIndex,
    builtin_count_one_bits: InstIndex,
    builtin_count_trailing_zeros: InstIndex,
    builtin_degrees: InstIndex,
    builtin_exp: InstIndex,
    builtin_exp2: InstIndex,
    builtin_first_leading_bit: InstIndex,
    builtin_first_trailing_bit: InstIndex,
    builtin_floor: InstIndex,
    builtin_fract: InstIndex,
    builtin_inverse_sqrt: InstIndex,
    builtin_length: InstIndex,
    builtin_log: InstIndex,
    builtin_log2: InstIndex,
    builtin_min: Binary,
    builtin_max: Binary,
    builtin_quantize_to_F16: InstIndex,
    builtin_radians: InstIndex,
    builtin_reverseBits: InstIndex,
    builtin_round: InstIndex,
    builtin_saturate: InstIndex,
    builtin_sign: InstIndex,
    builtin_sin: InstIndex,
    builtin_sinh: InstIndex,
    builtin_smoothstep: BuiltinSmoothstep,
    builtin_sqrt: InstIndex,
    builtin_tan: InstIndex,
    builtin_tanh: InstIndex,
    builtin_trunc: InstIndex,
    builtin_dpdx: InstIndex,
    builtin_dpdx_coarse: InstIndex,
    builtin_dpdx_fine: InstIndex,
    builtin_dpdy: InstIndex,
    builtin_dpdy_coarse: InstIndex,
    builtin_dpdy_fine: InstIndex,
    builtin_fwidth: InstIndex,
    builtin_fwidth_coarse: InstIndex,
    builtin_fwidth_fine: InstIndex,

    pub const Var = struct {
        name: StringIndex,
        type: InstIndex,
        expr: InstIndex, // TODO: rename to `init`
        addr_space: PointerType.AddressSpace,
        access_mode: PointerType.AccessMode,
        binding: InstIndex = .none,
        group: InstIndex = .none,
        id: InstIndex = .none,
    };

    pub const Const = struct {
        name: StringIndex,
        type: InstIndex,
        expr: InstIndex, // TODO: rename to `init`
    };

    pub const Fn = struct {
        name: StringIndex,
        stage: Stage,
        is_const: bool,
        params: RefIndex,
        return_type: InstIndex,
        return_attrs: ReturnAttrs,
        block: InstIndex,

        pub const Stage = union(enum) {
            none,
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
            builtin: ?Builtin,
            location: ?u16,
            interpolate: ?Interpolate,
            invariant: bool,
        };
    };

    pub const FnParam = struct {
        name: StringIndex,
        type: InstIndex,
        builtin: ?Builtin,
        location: ?u16,
        interpolate: ?Interpolate,
        invariant: bool,
    };

    pub const Builtin = Ast.Builtin;

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

    pub const Struct = struct {
        name: StringIndex,
        members: RefIndex,
    };

    pub const StructMember = struct {
        name: StringIndex,
        type: InstIndex,
        @"align": ?u29,
        size: ?u32,
        location: ?u16,
        builtin: ?Builtin,
        interpolate: ?Interpolate,
    };

    pub const Bool = struct {
        value: ?Value,

        pub const Value = union(enum) {
            literal: bool,
            cast: Cast,
        };
    };

    pub const Int = struct {
        type: Type,
        value: ?ValueIndex,

        pub const Type = enum {
            u32,
            i32,

            pub fn width(self: Type) u8 {
                _ = self;
                return 32;
            }

            pub fn signedness(self: Type) bool {
                return switch (self) {
                    .u32 => false,
                    .i32 => true,
                };
            }
        };

        pub const Value = union(enum) {
            literal: i33,
            cast: Cast,
        };
    };

    pub const Float = struct {
        type: Type,
        value: ?ValueIndex,

        pub const Type = enum {
            f32,
            f16,

            pub fn width(self: Type) u8 {
                return switch (self) {
                    .f32 => 32,
                    .f16 => 16,
                };
            }
        };

        pub const Value = union(enum) {
            literal: f32,
            cast: Cast,
        };
    };

    pub const Cast = struct {
        type: InstIndex,
        value: InstIndex,
    };

    pub const Vector = struct {
        elem_type: InstIndex,
        size: Size,
        value: ?ValueIndex,

        pub const Size = enum(u3) { two = 2, three = 3, four = 4 };
        pub const Value = [4]InstIndex;
    };

    pub const Matrix = struct {
        elem_type: InstIndex,
        cols: Vector.Size,
        rows: Vector.Size,
        value: ?ValueIndex,

        pub const Value = [4]InstIndex;
    };

    pub const Array = struct {
        elem_type: InstIndex,
        len: InstIndex,
        value: ?RefIndex,
    };

    pub const AtomicType = struct { elem_type: InstIndex };

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
            read,
            write,
            read_write,
        };
    };

    pub const SampledTextureType = struct {
        kind: Kind,
        elem_type: InstIndex,

        pub const Kind = enum {
            @"1d",
            @"2d",
            @"2d_array",
            @"3d",
            cube,
            cube_array,
            multisampled_2d,
        };
    };

    pub const MultisampledTextureType = struct {
        kind: Kind,
        elem_type: InstIndex,

        pub const Kind = enum { @"2d", depth_2d };
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

    pub const Assign = struct {
        mod: Modifier,
        lhs: InstIndex,
        rhs: InstIndex,

        pub const Modifier = enum {
            none,
            add,
            sub,
            mul,
            div,
            mod,
            @"and",
            @"or",
            xor,
            shl,
            shr,
        };
    };

    pub const FieldAccess = struct {
        base: InstIndex,
        field: InstIndex,
        name: StringIndex,
    };

    pub const SwizzleAccess = struct {
        base: InstIndex,
        type: InstIndex,
        size: Size,
        pattern: [4]Component,

        pub const Size = enum(u3) {
            one = 1,
            two = 2,
            three = 3,
            four = 4,
        };
        pub const Component = enum(u3) { x, y, z, w };
    };

    pub const IndexAccess = struct {
        base: InstIndex,
        type: InstIndex,
        index: InstIndex,
    };

    pub const FnCall = struct {
        @"fn": InstIndex,
        args: RefIndex,
    };

    pub const StructConstruct = struct {
        @"struct": InstIndex,
        members: RefIndex,
    };

    pub const Bitcast = struct {
        type: InstIndex,
        expr: InstIndex,
        result_type: InstIndex,
    };

    pub const BuiltinSelect = struct {
        true: InstIndex,
        false: InstIndex,
        cond: InstIndex,
    };

    pub const BuiltinSmoothstep = struct {
        low: InstIndex,
        high: InstIndex,
        x: InstIndex,
    };

    pub const If = struct {
        cond: InstIndex,
        body: InstIndex,
        /// `if` or `block`
        @"else": InstIndex,
    };

    pub const Switch = struct {
        switch_on: InstIndex,
        cases_list: RefIndex,
    };

    pub const SwitchCase = struct {
        cases: RefIndex,
        body: InstIndex,
        default: bool,
    };

    pub const For = struct {
        init: InstIndex,
        cond: InstIndex,
        update: InstIndex,
        body: InstIndex,
    };

    comptime {
        std.debug.assert(@sizeOf(Inst) <= 64);
    }
};
