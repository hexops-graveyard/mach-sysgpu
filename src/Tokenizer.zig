const std = @import("std");
const Token = @import("Token.zig");

const Tokenizer = @This();

source: [:0]const u8,
index: u32 = 0,

const State = union(enum) {
    start,
    ident,
    underscore,
    number: struct {
        hex: bool = false,
        leading_sign: bool = false,
        dot: bool = false,
    },
    block_comment,
    @"and",
    bang,
    equal,
    greater,
    shift_right,
    less,
    shift_left,
    minus,
    percent,
    dot,
    pipe,
    plus,
    slash,
    star,
    xor,
};

pub fn init(source: [:0]const u8) Tokenizer {
    // return Tokenizer{
    //     // Skip the UTF-8 BOM if present
    //     .source = std.mem.trimLeft(u8, source, "\xEF\xBB\xBF"),
    // };

    // Skip the UTF-8 BOM if present
    const src_start: u32 = if (std.mem.startsWith(u8, source, "\xEF\xBB\xBF")) 3 else 0;
    return Tokenizer{ .source = source[src_start..] };
}

pub fn peek(self: *Tokenizer) Token {
    var index = self.index;
    var state: State = .start;
    var result = Token{
        .tag = .eof,
        .loc = .{
            .start = index,
            .end = undefined,
        },
    };

    while (true) : (index += 1) {
        var c = self.source[index];
        switch (state) {
            .start => switch (c) {
                0 => {
                    if (index != self.source.len) {
                        result.tag = .invalid;
                        index += 1;
                        result.loc.end = index;
                        return result;
                    }
                    break;
                },

                ' ', '\n', '\t', '\r' => result.loc.start = index + 1,
                'a'...'z', 'A'...'Z' => state = .ident,
                '0'...'9' => state = .{ .number = .{} },

                '&' => state = .@"and",
                '!' => state = .bang,
                '=' => state = .equal,
                '>' => state = .greater,
                '<' => state = .less,
                '-' => state = .minus,
                '%' => state = .percent,
                '.' => state = .dot,
                '|' => state = .pipe,
                '+' => state = .plus,
                '/' => state = .slash,
                '*' => state = .star,
                '_' => state = .underscore,
                '^' => state = .xor,

                '@' => {
                    result.tag = .attr;
                    index += 1;
                    break;
                },
                '[' => {
                    result.tag = .bracket_left;
                    index += 1;
                    break;
                },
                ']' => {
                    result.tag = .bracket_right;
                    index += 1;
                    break;
                },
                '{' => {
                    result.tag = .brace_left;
                    index += 1;
                    break;
                },
                '}' => {
                    result.tag = .brace_right;
                    index += 1;
                    break;
                },
                ':' => {
                    result.tag = .colon;
                    index += 1;
                    break;
                },
                ',' => {
                    result.tag = .comma;
                    index += 1;
                    break;
                },
                '(' => {
                    result.tag = .paren_left;
                    index += 1;
                    break;
                },
                ')' => {
                    result.tag = .paren_right;
                    index += 1;
                    break;
                },
                ';' => {
                    result.tag = .semicolon;
                    index += 1;
                    break;
                },
                '~' => {
                    result.tag = .tilde;
                    index += 1;
                    break;
                },

                else => {
                    result.tag = .invalid;
                    index += 1;
                    break;
                },
            },
            .ident => switch (c) {
                'a'...'z', 'A'...'Z', '0'...'9', '_' => {},
                else => {
                    result.tag = .ident;
                    if (Token.keywords.get(self.source[result.loc.start..index])) |tag| {
                        result.tag = tag;
                    }
                    break;
                },
            },
            .underscore => switch (c) { // TODO: two underscore `__` https://www.w3.org/TR/WGSL/#identifiers
                'a'...'z', 'A'...'Z', '_', '0'...'9' => state = .ident,
                else => {
                    result.tag = .underscore;
                    break;
                },
            },
            .number => |*number| {
                result.tag = .number;
                while (true) : (index += 1) {
                    c = self.source[index];
                    switch (c) {
                        '0'...'9' => {},
                        'a'...'d', 'A'...'D' => if (!number.hex) break,
                        'x', 'X' => number.hex = true,
                        '.' => {
                            if (number.dot) break;
                            number.dot = true;
                        },
                        '+', '-' => {
                            if (!number.leading_sign) break;
                            number.leading_sign = false;
                            number.hex = false;
                        },
                        'e', 'E' => if (!number.hex) {
                            number.leading_sign = true;
                        },
                        'p', 'P' => if (number.hex) {
                            number.leading_sign = true;
                        },
                        'i', 'u' => {
                            index += 1;
                            break;
                        },
                        'f', 'h' => if (!number.hex) {
                            index += 1;
                            break;
                        },
                        else => break,
                    }
                }

                break;
            },
            .block_comment => switch (c) {
                0 => break,
                '\n' => {
                    state = .start;
                    result.loc.start = index + 1;
                },
                else => {},
            },
            .@"and" => switch (c) {
                '&' => {
                    result.tag = .and_and;
                    index += 1;
                    break;
                },
                '=' => {
                    result.tag = .and_equal;
                    index += 1;
                    break;
                },
                else => {
                    result.tag = .@"and";
                    break;
                },
            },
            .bang => switch (c) {
                '=' => {
                    result.tag = .not_equal;
                    index += 1;
                    break;
                },
                else => {
                    result.tag = .bang;
                    break;
                },
            },
            .equal => switch (c) {
                '=' => {
                    result.tag = .equal_equal;
                    index += 1;
                    break;
                },
                else => {
                    result.tag = .equal;
                    break;
                },
            },
            .greater => switch (c) {
                '>' => state = .shift_right,
                '=' => {
                    result.tag = .greater_than_equal;
                    index += 1;
                    break;
                },
                else => {
                    result.tag = .greater_than;
                    break;
                },
            },
            .shift_right => switch (c) {
                '=' => {
                    result.tag = .shift_right_equal;
                    index += 1;
                    break;
                },
                else => {
                    result.tag = .shift_right;
                    break;
                },
            },
            .less => switch (c) {
                '<' => state = .shift_left,
                '=' => {
                    result.tag = .less_than_equal;
                    index += 1;
                    break;
                },
                else => {
                    result.tag = .less_than;
                    break;
                },
            },
            .shift_left => switch (c) {
                '=' => {
                    result.tag = .shift_left_equal;
                    index += 1;
                    break;
                },
                else => {
                    result.tag = .shift_left;
                    break;
                },
            },
            .minus => switch (c) {
                '-' => {
                    result.tag = .minus_minus;
                    index += 1;
                    break;
                },
                '=' => {
                    result.tag = .minus_equal;
                    index += 1;
                    break;
                },
                '>' => {
                    result.tag = .arrow;
                    index += 1;
                    break;
                },
                '0'...'9' => {
                    // workaround for x-1 being tokenized as [x] [-1]
                    // TODO: maybe it's user fault? :^)
                    // duplicated at .plus too
                    if (index >= 2 and std.ascii.isAlphabetic(self.source[index - 2])) {
                        result.tag = .minus;
                        break;
                    }
                    state = .{ .number = .{} };
                },
                else => {
                    result.tag = .minus;
                    break;
                },
            },
            .percent => switch (c) {
                '=' => {
                    result.tag = .percent_equal;
                    index += 1;
                    break;
                },
                else => {
                    result.tag = .percent;
                    break;
                },
            },
            .pipe => switch (c) {
                '|' => {
                    result.tag = .or_or;
                    index += 1;
                    break;
                },
                '=' => {
                    result.tag = .or_equal;
                    index += 1;
                    break;
                },
                else => {
                    result.tag = .@"or";
                    break;
                },
            },
            .dot => switch (c) {
                '0'...'9' => state = .{ .number = .{} },
                else => {
                    result.tag = .dot;
                    break;
                },
            },
            .plus => switch (c) {
                '+' => {
                    result.tag = .plus_plus;
                    index += 1;
                    break;
                },
                '=' => {
                    result.tag = .plus_equal;
                    index += 1;
                    break;
                },
                '0'...'9' => {
                    if (index >= 2 and std.ascii.isAlphabetic(self.source[index - 2])) {
                        result.tag = .plus;
                        break;
                    }
                    state = .{ .number = .{} };
                },
                else => {
                    result.tag = .plus;
                    break;
                },
            },
            .slash => switch (c) {
                '/' => state = .block_comment,
                '=' => {
                    result.tag = .division_equal;
                    index += 1;
                    break;
                },
                else => {
                    result.tag = .division;
                    break;
                },
            },
            .star => switch (c) {
                '=' => {
                    result.tag = .times_equal;
                    index += 1;
                    break;
                },
                else => {
                    result.tag = .star;
                    break;
                },
            },
            .xor => switch (c) {
                '=' => {
                    result.tag = .xor_equal;
                    index += 1;
                    break;
                },
                else => {
                    result.tag = .xor;
                    break;
                },
            },
        }
    }

    result.loc.end = index;
    return result;
}

pub fn next(self: *Tokenizer) Token {
    const tok = self.peek();
    self.index = tok.loc.end;
    return tok;
}

test "tokenize identifier and numbers" {
    const str =
        \\_ __ _iden iden -100i 100.8i // cc
        \\// commnet
        \\
    ;
    var tokenizer = Tokenizer.init(str);
    try std.testing.expect(tokenizer.next().tag == .underscore);
    try std.testing.expect(tokenizer.next().tag == .ident);
    try std.testing.expect(tokenizer.next().tag == .ident);
    try std.testing.expect(tokenizer.next().tag == .ident);
    try std.testing.expectEqualStrings("-100i", tokenizer.next().loc.slice(str));
    try std.testing.expect(tokenizer.next().tag == .number);
    try std.testing.expect(tokenizer.next().tag == .eof);
}
