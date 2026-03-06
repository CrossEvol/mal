const std = @import("std");
const Io = std.Io;

const MalError = @import("error.zig").MalError;
const MalHashMap = @import("types.zig").MalHashMap;
const MalInt = @import("types.zig").MalInt;
const MalType = @import("types.zig").MalType;
const MalTypeContext = @import("types.zig").MalTypeContext;
const printer = @import("printer.zig");
const reader = @import("reader.zig");
const rl = @import("readline.zig");

fn @"+"(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    const a = try args[0].as(MalInt);
    const b = try args[1].as(MalInt);

    return MalType.newInt(a.value + b.value);
}

fn @"-"(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    const a = try args[0].as(MalInt);
    const b = try args[1].as(MalInt);

    return MalType.newInt(a.value - b.value);
}

fn @"*"(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    const a = try args[0].as(MalInt);
    const b = try args[1].as(MalInt);

    return MalType.newInt(a.value * b.value);
}

fn @"/"(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    const a = try args[0].as(MalInt);
    const b = try args[1].as(MalInt);

    return MalType.newInt(@divTrunc(a.value, b.value));
}

fn READ(allocator: std.mem.Allocator, x: []const u8) !MalType {
    return try reader.read_str(allocator, x);
}

fn EVAL(allocator: std.mem.Allocator, ast: MalType, env: std.StringHashMap(MalType)) !MalType {
    switch (ast) {
        .symbol => |s| {
            const option_result = env.get(s.value);
            if (option_result) |result| {
                return result;
            } else {
                return MalError.SymbolNotFound;
            }
        },
        .iterable => |it| switch (it) {
            .list => {
                // exit this switch
            },
            .vector => |v| {
                var new_elements = try allocator.alloc(MalType, v.length());
                for (v.items(), 0..v.length()) |x, i| {
                    new_elements[i] = try EVAL(allocator, x, env);
                }
                return MalType.newVector(allocator, new_elements);
            },
            else => return ast,
        },
        .hashmap => |hm| {
            var new_map = std.HashMap(
                MalType,
                MalType,
                MalTypeContext,
                std.hash_map.default_max_load_percentage,
            ).init(allocator);
            var key_iter = hm.value.keyIterator();
            while (key_iter.next()) |key| {
                try new_map.put(key.*, try EVAL(allocator, hm.value.get(key.*).?, env));
            }
            return MalType.newHashMap(allocator, new_map);
        },
        else => return ast,
    }

    const forms = try ast.asList();
    if (forms.length() == 0) return ast;
    const f = (try EVAL(allocator, forms.get(0), env)).callable.builtin;
    var args = try allocator.alloc(MalType, forms.length() - 1);
    errdefer allocator.free(args);

    for (1..forms.length()) |i| {
        args[i - 1] = try EVAL(allocator, forms.get(i), env);
    }
    return try f.func(allocator, args);
}

fn PRINT(allocator: std.mem.Allocator, x: MalType) ![]const u8 {
    return try printer.pr_str(allocator, x, true);
}

fn rep(allocator: std.mem.Allocator, x: []const u8, env: std.StringHashMap(MalType)) ![]const u8 {
    return try PRINT(allocator, try EVAL(allocator, try READ(allocator, x), env));
}

const prompt = "user> ";

pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();
    const io = init.io;

    var repl_env = std.StringHashMap(MalType).init(arena);
    try repl_env.put("+", try MalType.newBuiltin(arena, @"+"));
    try repl_env.put("-", try MalType.newBuiltin(arena, @"-"));
    try repl_env.put("*", try MalType.newBuiltin(arena, @"*"));
    try repl_env.put("/", try MalType.newBuiltin(arena, @"/"));

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    try stdout_writer.flush();

    while (true) {
        if (try rl.readline(prompt)) |input| {
            if (std.mem.eql(u8, input, "(exit)")) break;
            const output = rep(arena, input, repl_env) catch |err| {
                try stdout_writer.writeAll("Error: ");
                switch (err) {
                    error.Unbalanced => try stdout_writer.writeAll("unbalanced"),
                    error.SymbolNotFound => try stdout_writer.writeAll(" not found"),
                    else => try stdout_writer.writeAll(@errorName(err)),
                }
                try stdout_writer.writeAll("\n");
                try stdout_writer.flush();
                continue;
            };
            try stdout_writer.writeAll(output);
            try stdout_writer.writeAll("\n");
            try stdout_writer.flush();
        }
    }
}
