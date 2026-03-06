const std = @import("std");

const regex = @import("pcrez");

const MalError = @import("error.zig").MalError;
const MalType = @import("types.zig").MalType;

const Reader = struct {
    tokens: [][]const u8,
    position: usize,

    fn init(tokens: [][]const u8) Reader {
        return .{
            .tokens = tokens,
            .position = 0,
        };
    }

    fn next(self: *Reader) ?[]const u8 {
        const token = self.peek();
        defer self.position += 1;
        return token;
    }

    fn peek(self: *Reader) ?[]const u8 {
        if (self.position >= self.tokens.len) return null;
        return self.tokens[self.position];
    }
};

pub fn read_str(allocator: std.mem.Allocator, code: []const u8) !MalType {
    const tokens = try tokenizer(allocator, code);
    if (tokens.len == 0) {
        // TODO: throw new NoInputException();
        return MalError.NoInput;
    }
    var reader = Reader.init(tokens);
    return read_form(allocator, &reader);
}

const mal_reg_exp_pattern =
    \\[\s,]*(~@|[\[\]{}()'`~^@]|"(?:\\.|[^\\"])*"?|;.*|[^\s\[\]{}('"`,;)]*)
;

pub fn tokenizer(allocator: std.mem.Allocator, code: []const u8) MalError![][]const u8 {
    var re = regex.Regex.from(mal_reg_exp_pattern, true, allocator) catch return MalError.InvalidRegex;
    defer re.deinit();

    const matches = re.searchAll(code, 0, -1);
    defer {
        for (0..matches.items.len) |i| {
            matches.items[i].deinit();
        }
        matches.deinit();
    }

    var tokens = try std.ArrayList([]const u8).initCapacity(allocator, matches.items.len);
    for (matches.items) |match| {
        const group1 = match.data.items[1];
        if (group1.end.? - group1.start.? > 0 and code[group1.start.?] != ';') {
            try tokens.append(allocator, code[group1.start.?..group1.end.?]);
        }
    }
    return try tokens.toOwnedSlice(allocator);
}

const macros = std.StaticStringMap([]const u8).initComptime(.{
    .{ "'", "quote" },
    .{ "`", "quasiquote" },
    .{ "~", "unquote" },
    .{ "~@", "splice-unquote" },
    .{ "@", "deref" },
    .{ "^", "with-meta" },
});

const sequenceStarters = std.StaticStringMap([]const u8).initComptime(.{
    .{ "(", ")" },
    .{ "[", "]" },
    .{ "{", "}" },
});

pub fn read_form(allocator: std.mem.Allocator, reader: *Reader) MalError!MalType {
    const token = reader.peek().?;
    if (sequenceStarters.has(token)) {
        const elements = try read_sequence(allocator, reader, token, sequenceStarters.get(token).?);
        if (std.mem.eql(u8, token, "(")) {
            return MalType.newList(allocator, elements);
        }
        if (std.mem.eql(u8, token, "[")) {
            return MalType.newVector(allocator, elements);
        }
        if (std.mem.eql(u8, token, "{")) {
            return MalType.fromSequence(allocator, elements);
        }

        // TODO:throw new StateError("Impossible!");
        return MalError.ImpossibleState;
    } else if (macros.has(token)) {
        const macro = MalType.newSymbol(macros.get(token).?);
        _ = reader.next();
        const form = try read_form(allocator, reader);
        if (std.mem.eql(u8, token, "^")) {
            const meta = try read_form(allocator, reader);
            var elements = try std.ArrayList(MalType).initCapacity(allocator, 3);
            try elements.append(allocator, macro);
            try elements.append(allocator, meta);
            try elements.append(allocator, form);
            return try MalType.newList(allocator, try elements.toOwnedSlice(allocator));
        } else {
            var elements = try std.ArrayList(MalType).initCapacity(allocator, 2);
            try elements.append(allocator, macro);
            try elements.append(allocator, form);
            return try MalType.newList(allocator, try elements.toOwnedSlice(allocator));
        }
    } else {
        return read_atom(allocator, reader);
    }
}

pub fn read_sequence(allocator: std.mem.Allocator, reader: *Reader, open: []const u8, close: []const u8) MalError![]MalType {
    // Consume opening token
    const actual_open = reader.next();
    if (!std.mem.eql(u8, actual_open.?, open)) {
        @panic("wrong open");
    }

    var elements = try std.ArrayList(MalType).initCapacity(allocator, 8);
    while (reader.peek()) |token| {
        if (std.mem.eql(u8, token, close)) break;
        try elements.append(allocator, try read_form(allocator, reader));
    } else {
        // TODO:throw new ParseException("expected '$close', got EOF");
        return MalError.EOF;
    }

    const actual_close = reader.next();
    if (!std.mem.eql(u8, actual_close.?, close)) {
        @panic("wrong close");
    }

    return elements.toOwnedSlice(allocator);
}

pub fn read_atom(allocator: std.mem.Allocator, reader: *Reader) MalError!MalType {
    const option_token = reader.next();
    const token = option_token.?;

    if (isTokenInt(token)) {
        const int_atom = try std.fmt.parseInt(i32, token, 10);
        return MalType.newInt(int_atom);
    }

    if (token[0] == '"') {
        return try read_atom_string(allocator, token);
    }

    if (token[0] == ':') {
        return MalType.newKeyword(token[1..]);
    }

    if (std.mem.eql(u8, token, "nil")) {
        return MalType.newNil();
    }

    if (std.mem.eql(u8, token, "true")) {
        return MalType.newBool(true);
    }

    if (std.mem.eql(u8, token, "false")) {
        return MalType.newBool(false);
    }

    return MalType.newSymbol(token);
}

fn read_atom_string(allocator: std.mem.Allocator, token: []const u8) MalError!MalType {
    const n = token.len;
    if (token[0] != '"' or token[n - 1] != '"' or n <= 1) {
        // TODO: @panic("unbalanced '\"'");
        return MalError.Unbalanced;
    }

    var buffer = allocator.alloc(u8, n - 2) catch return MalError.OutOfMemory;
    errdefer allocator.free(buffer);
    var i: usize = 1; // pointer to token
    var j: usize = 0; // pointer to bufffer
    const escape_char = '\\';

    while (i < n - 1) {
        if (token[i] != escape_char) {
            buffer[j] = token[i];
            i += 1;
            j += 1;
        } else {
            if (i == n - 2) {
                // TODO: @panic("unbalanced '\"'");
                return MalError.Unbalanced;
            }
            if (token[i + 1] == 'n') {
                buffer[j] = '\n';
            } else {
                buffer[j] = token[i + 1];
            }
            i += 2;
            j += 1;
        }
    }

    return MalType.newString(buffer[0..j]);
}

fn isTokenInt(token: []const u8) bool {
    if (std.ascii.isDigit(token[0])) return true;
    if (token.len >= 2 and token[0] == '-' and std.ascii.isDigit(token[1])) return true;
    return false;
}
