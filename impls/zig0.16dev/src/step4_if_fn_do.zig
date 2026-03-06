const std = @import("std");
const Io = std.Io;

const Env = @import("env.zig").Env;
const MalCallable = @import("types.zig").MalCallable;
const MalError = @import("error.zig").MalError;
const MalHashMap = @import("types.zig").MalHashMap;
const MalIterable = @import("types.zig").MalIterable;
const MalSymbol = @import("types.zig").MalSymbol;
const MalType = @import("types.zig").MalType;
const MalTypeContext = @import("types.zig").MalTypeContext;
const ns = @import("core.zig").ns;
const printer = @import("printer.zig");
const reader = @import("reader.zig");
const rl = @import("readline.zig");

var repl_env: *Env = undefined;
var stdout_writer: *std.Io.Writer = undefined;

fn setupEnv(allocator: std.mem.Allocator) !void {
    const env = try allocator.create(Env);
    env.* = try Env.init(allocator, null, null, null);
    repl_env = env;

    for (ns.keys(), ns.values()) |sym, fun| {
        try repl_env.set(sym, try MalType.newBuiltin(allocator, fun));
    }

    _ = try rep(allocator, "(def! not (fn* (a) (if a false true)))");
}

fn READ(allocator: std.mem.Allocator, x: []const u8) !MalType {
    return try reader.read_str(allocator, x);
}

fn EVAL(allocator: std.mem.Allocator, ast: MalType, env: *Env) MalError!MalType {
    const option_dbgeval = env.get("DEBUG-EVAL");
    if (option_dbgeval) |dbgeval| {
        const b = dbgeval.isBoolValue();
        if (b) {
            try stdout_writer.writeAll("EVAL: ");
            try stdout_writer.writeAll(try printer.pr_str(allocator, ast, true));
            try stdout_writer.writeAll("\n");
            try stdout_writer.flush();
        }
    }

    switch (ast) {
        .symbol => |s| {
            const option_result = env.get(s.value);
            if (option_result) |result| {
                return result;
            } else {
                std.debug.print("Error: '{s}' not found", .{s.value});
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
            return try MalType.newHashMap(allocator, new_map);
        },
        else => return ast,
    }

    var forms = try ast.asList();
    if (forms.length() == 0) return ast;
    const list = try ast.asList();
    switch (list.items()[0]) {
        .symbol => |symbol| {
            const args = forms.items()[1..];
            if (std.mem.eql(u8, symbol.value, "def!")) {
                const key = try args[0].as(MalSymbol);
                const value = try EVAL(allocator, args[1], env);
                try env.set(key.value, value);
                return value;
            } else if (std.mem.eql(u8, symbol.value, "let*")) {
                const new_env = try allocator.create(Env);
                new_env.* = try Env.init(allocator, env, null, null);
                var bindings = try args[0].as(MalIterable);

                if (bindings.length() % 2 != 0) {
                    return MalError.InvalidArgument;
                }

                var i: usize = 0;
                while (i < bindings.length()) : (i += 2) {
                    const key = try bindings.items()[i].as(MalSymbol);
                    const value = try EVAL(allocator, bindings.items()[i + 1], new_env);
                    try new_env.set(key.value, value);
                }

                return try EVAL(allocator, args[1], new_env);
            } else if (std.mem.eql(u8, symbol.value, "do")) {
                const last = args.len - 1;
                for (args[0..last]) |arg| {
                    _ = try EVAL(allocator, arg, env);
                }
                return try EVAL(allocator, args[last], env);
            } else if (std.mem.eql(u8, symbol.value, "if")) {
                const condition = try EVAL(allocator, args[0], env);
                const b = condition.isBoolValue();
                if (b) {
                    // True side of branch
                    return try EVAL(allocator, args[1], env);
                } else {
                    // False side of branch
                    if (args.len < 3) {
                        return MalType.newNil();
                    }
                    return try EVAL(allocator, args[2], env);
                }
            } else if (std.mem.eql(u8, symbol.value, "fn*")) {
                const mal_it = try args[0].as(MalIterable);
                var params = try allocator.alloc(MalSymbol, mal_it.length());
                for (mal_it.items(), 0..params.len) |e, i| {
                    params[i] = try e.as(MalSymbol);
                }

                return try MalType.newClosure(allocator, params, args[1], env, EVAL);
            }
        },
        else => {},
    }

    const f = (try EVAL(allocator, forms.get(0), env));
    var args = try allocator.alloc(MalType, forms.length() - 1);
    errdefer allocator.free(args);

    for (1..forms.length()) |i| {
        args[i - 1] = try EVAL(allocator, forms.get(i), env);
    }

    return (try f.as(*MalCallable)).call(allocator, args);
}

fn PRINT(allocator: std.mem.Allocator, x: MalType) ![]const u8 {
    return try printer.pr_str(allocator, x, true);
}

fn rep(allocator: std.mem.Allocator, x: []const u8) ![]const u8 {
    return try PRINT(allocator, try EVAL(allocator, try READ(allocator, x), repl_env));
}

const prompt = "user> ";

pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();
    const io = init.io;

    try setupEnv(arena);

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    stdout_writer = &stdout_file_writer.interface;

    try stdout_writer.flush();

    while (true) {
        if (try rl.readline(prompt)) |input| {
            if (std.mem.eql(u8, input, "(exit)")) break;
            const output = rep(arena, input) catch |err| {
                try stdout_writer.writeAll("Error: ");
                switch (err) {
                    error.Unbalanced => try stdout_writer.writeAll("unbalanced"),
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
