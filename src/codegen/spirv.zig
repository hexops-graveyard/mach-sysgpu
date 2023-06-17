const std = @import("std");
const Air = @import("../Air.zig");
const Section = @import("spirv/Section.zig");
const spec = @import("spirv/spec.zig");
const InstIndex = Air.InstIndex;
const Word = spec.Word;
const Opcode = spec.Opcode;
const Operand = spec.Operand;
const IdResult = spec.IdResult;

const SpirV = @This();

air: *const Air,
bound: Word = 1,
compute_stage: ?Stage = null,
vertex_stage: ?Stage = null,
fragment_stage: ?Stage = null,

const Stage = struct {
    name: []const u8,
    id_result: IdResult,
};

pub fn gen(allocator: std.mem.Allocator, air: *const Air) ![]const u8 {
    var spirv = SpirV{ .air = air };

    var module = Section{ .allocator = allocator };
    defer module.deinit();

    try module.ensureUnusedCapacity(5);
    // Magic number
    module.writeWord(spec.magic_number);
    // Spir-V 1.4
    module.writeWord((spec.Version{ .major = 1, .minor = 4 }).toWord());
    // Generator magic number. TODO: register dusk compiler
    module.writeWord(0);
    // Id's bound
    module.writeWord(spirv.bound);
    // Reserved for instruction schema, if needed
    module.writeWord(0);

    var instructions = Section{ .allocator = allocator };
    defer instructions.deinit();
    for (spirv.air.types) |type_inst| {
        try spirv.emitType(&instructions, type_inst);
    }

    try spirv.emitModule(&module);
    try module.append(instructions);

    return allocator.dupe(u8, std.mem.sliceAsBytes(module.words.items));
}

fn emitModule(spirv: *SpirV, section: *Section) !void {
    try section.emit(.OpCapability, .{ .capability = .Shader });
    try section.emit(.OpMemoryModel, .{ .addressing_model = .Logical, .memory_model = .GLSL450 });

    if (spirv.compute_stage) |compute_stage| {
        try section.emit(.OpEntryPoint, .{
            .execution_model = .GLCompute,
            .entry_point = compute_stage.id_result,
            .name = compute_stage.name,
        });
    }
    if (spirv.vertex_stage) |vertex_stage| {
        try section.emit(.OpEntryPoint, .{
            .execution_model = .Vertex,
            .entry_point = vertex_stage.id_result,
            .name = vertex_stage.name,
        });
    }
    if (spirv.fragment_stage) |fragment_stage| {
        try section.emit(.OpEntryPoint, .{
            .execution_model = .Fragment,
            .entry_point = fragment_stage.id_result,
            .name = fragment_stage.name,
        });
    }
}

fn emitType(spirv: *SpirV, section: *Section, inst: InstIndex) !void {
    _ = spirv;
    _ = section;
    _ = inst;
}
