//! Borrowed from Zig compiler codebase with some changes.
//! Licensed under LICENSE-zig

const std = @import("std");
const spec = @import("spec.zig");
const Opcode = spec.Opcode;
const Word = spec.Word;
const DoubleWord = std.meta.Int(.unsigned, @bitSizeOf(Word) * 2);
const Log2Word = std.math.Log2Int(Word);

const Section = @This();

allocator: std.mem.Allocator,
words: std.ArrayListUnmanaged(Word) = .{},

pub fn deinit(section: *Section) void {
    section.words.deinit(section.allocator);
}

pub fn emit(
    section: *Section,
    comptime opcode: spec.Opcode,
    operands: opcode.Operands(),
) !void {
    const word_count = instructionSize(opcode, operands);
    try section.ensureUnusedCapacity(word_count);
    section.writeWord(@intCast(Word, word_count << 16) | @enumToInt(opcode));
    section.writeOperands(opcode.Operands(), operands);
}

pub fn append(section: *Section, other: Section) !void {
    try section.words.appendSlice(section.allocator, other.words.items);
}

pub fn ensureUnusedCapacity(section: *Section, add: usize) !void {
    try section.words.ensureUnusedCapacity(section.allocator, add);
}

pub fn writeWord(section: *Section, word: Word) void {
    section.words.appendAssumeCapacity(word);
}

pub fn writeWords(section: *Section, words: []const Word) void {
    section.words.appendSliceAssumeCapacity(words);
}

pub fn writeString(section: *Section, str: []const u8) void {
    const zero_terminated_len = str.len + 1;
    var i: usize = 0;
    while (i < zero_terminated_len) : (i += @sizeOf(Word)) {
        var word: Word = 0;

        var j: usize = 0;
        while (j < @sizeOf(Word) and i + j < str.len) : (j += 1) {
            word |= @as(Word, str[i + j]) << @intCast(Log2Word, j * @bitSizeOf(u8));
        }

        section.words.appendAssumeCapacity(word);
    }
}

pub fn writeOperand(section: *Section, comptime Operand: type, operand: Operand) void {
    switch (Operand) {
        spec.IdResult => section.writeWord(operand.id),
        spec.LiteralInteger => section.writeWord(operand),
        spec.LiteralString => section.writeString(operand),
        spec.LiteralContextDependentNumber => section.writeContextDependentNumber(operand),
        spec.LiteralExtInstInteger => section.writeWord(operand.inst),
        spec.PairLiteralIntegerIdRef => section.writeWords(&.{ operand.value, operand.label.id }),
        spec.PairIdRefLiteralInteger => section.writeWords(&.{ operand.target.id, operand.member }),
        spec.PairIdRefIdRef => section.writeWords(&.{ operand[0].id, operand[1].id }),
        else => switch (@typeInfo(Operand)) {
            .Enum => section.writeWord(@enumToInt(operand)),
            .Optional => |info| if (operand) |child| {
                section.writeOperand(info.child, child);
            },
            .Pointer => |info| {
                std.debug.assert(info.size == .Slice);
                for (operand) |item| {
                    section.writeOperand(info.child, item);
                }
            },
            .Struct => |info| {
                std.debug.assert(info.size == .Packed);
                section.writeWord(@bitCast(Word, operand));
            },
            else => unreachable,
        },
    }
}

pub fn writeOperands(section: *Section, comptime Operands: type, operands: Operands) void {
    const fields = switch (@typeInfo(Operands)) {
        .Struct => |info| info.fields,
        .Void => return,
        else => unreachable,
    };

    inline for (fields) |field| {
        section.writeOperand(field.type, @field(operands, field.name));
    }
}

fn instructionSize(comptime opcode: spec.Opcode, operands: opcode.Operands()) usize {
    return operandsSize(opcode.Operands(), operands) + 1;
}

fn operandsSize(comptime Operands: type, operands: Operands) usize {
    const fields = switch (@typeInfo(Operands)) {
        .Struct => |info| info.fields,
        .Void => return 0,
        else => unreachable,
    };

    var total: usize = 0;
    inline for (fields) |field| {
        total += operandSize(field.type, @field(operands, field.name));
    }

    return total;
}

fn operandSize(comptime Operand: type, operand: Operand) usize {
    return switch (Operand) {
        spec.IdResult,
        spec.LiteralInteger,
        spec.LiteralExtInstInteger,
        => 1,
        spec.LiteralString => std.math.divCeil(usize, operand.len + 1, @sizeOf(Word)) catch unreachable,
        spec.LiteralContextDependentNumber => switch (operand) {
            .int32, .uint32, .float32 => 1,
            .int64, .uint64, .float64 => 2,
        },
        spec.PairLiteralIntegerIdRef,
        spec.PairIdRefLiteralInteger,
        spec.PairIdRefIdRef,
        => 2,
        else => switch (@typeInfo(Operand)) {
            .Enum => 1,
            .Optional => |info| if (operand) |child| operandSize(info.child, child) else 0,
            .Pointer => |info| blk: {
                std.debug.assert(info.size == .Slice);
                var total: usize = 0;
                for (operand) |item| {
                    total += operandSize(info.child, item);
                }
                break :blk total;
            },
            .Struct => |info| if (info.layout == .Packed) 1 else unreachable,
            else => unreachable,
        },
    };
}
