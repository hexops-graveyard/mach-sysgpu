const std = @import("std");
const Air = @import("../Air.zig");
const Section = @import("spirv/Section.zig");
const spec = @import("spirv/spec.zig");
const Word = spec.Word;
const Opcode = spec.Opcode;
const Operand = spec.Operand;

const SpirV = @This();

air: *const Air,
section: Section = .{},
bound: Word = 1,

pub fn gen(allocator: std.mem.Allocator, air: *const Air) ![]const u8 {
    var spirv = SpirV{ .air = air };
    defer spirv.section.words.deinit(allocator);

    try spirv.section.words.ensureUnusedCapacity(allocator, 1);
    spirv.section.writeWord(spec.magic_number); // magic number
    spirv.section.writeWord((1 << 16) | (4 << 8)); // Spir-V 1.4
    spirv.section.writeWord(0); // generator magic number. TODO: register dusk compiler
    spirv.section.writeWord(spirv.bound); // id's bound
    spirv.section.writeWord(0); // Reserved for instruction schema, if needed.

    return allocator.dupe(u8, std.mem.sliceAsBytes(spirv.section.words.items));
}
