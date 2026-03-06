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
pub var stdout: *std.Io.Writer = undefined;

fn eval(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    if (args.len > 1) {
        return MalError.InvalidArgCount;
    }

    return EVAL(allocator, args[0], repl_env);
}

fn debug(allocator: std.mem.Allocator, arg: MalType) !void {
    const items = try allocator.alloc(MalType, 1);
    items[0] = arg;
    _ = try repl_env.get("prn").?.callable.call(allocator, items);
}

fn setupEnv(allocator: std.mem.Allocator, argv: []const []const u8) !void {
    const env = try allocator.create(Env);
    env.* = try Env.init(allocator, null, null, null);
    repl_env = env;

    for (ns.keys(), ns.values()) |sym, fun| {
        try repl_env.set(sym, try MalType.newBuiltin(allocator, fun));
    }

    try repl_env.set("eval", try MalType.newBuiltin(allocator, eval));

    var elements = try allocator.alloc(MalType, argv.len);
    for (argv, 0..argv.len) |s, i| {
        elements[i] = MalType.newString(s);
    }
    try repl_env.set("*ARGV*", try MalType.newList(allocator, elements));

    try repl_env.set("*host-language*", MalType.newString("zig0.16dev"));

    _ = try rep(allocator,
        \\(def! not (fn* (a) (if a false true)))
    );
    _ = try rep(allocator,
        \\(def! load-file 
        \\(fn* (f) (eval (read-string (str "(do " (slurp f) "\nnil)")))))
    );
    _ = try rep(allocator,
        \\(defmacro! cond 
        \\  (fn* (& xs) (if (> (count xs) 0) 
        \\    (list 'if (first xs) 
        \\      (if (> (count xs) 1) 
        \\          (nth xs 1) 
        \\          (throw "odd number of forms to cond")) 
        \\     (cons 'cond (rest (rest xs)))))))
    );
}

fn startsWith(ast: MalType, sym: []const u8) bool {
    return switch (ast) {
        .iterable => |it| switch (it) {
            .list => |l| l.length() == 2 and switch (l.items()[0]) {
                .symbol => |s| std.mem.eql(u8, s.value, sym),
                else => false,
            },
            else => false,
        },
        else => false,
    };
}

fn quasiquoteLoop(allocator: std.mem.Allocator, xs: []MalType) MalError!MalType {
    var acc = try std.ArrayList(MalType).initCapacity(allocator, xs.len);

    if (xs.len >= 1) {
        var i = xs.len - 1;
        outer: while (true) : (i -= 1) {
            if (startsWith(xs[i], "splice-unquote")) {
                const symbol = MalType.newSymbol("concat");
                const to_be_concat = (try xs[i].asList()).get(1);
                const old_acc = try MalType.newList(allocator, try acc.toOwnedSlice(allocator));
                acc.clearAndFree(allocator);
                try acc.append(allocator, symbol);
                try acc.append(allocator, to_be_concat);
                try acc.append(allocator, old_acc);
            } else {
                const symbol = MalType.newSymbol("cons");
                const to_be_cons = try quasiquote(allocator, xs[i]);
                const old_acc = try MalType.newList(allocator, try acc.toOwnedSlice(allocator));
                acc.clearAndFree(allocator);
                try acc.append(allocator, symbol);
                try acc.append(allocator, to_be_cons);
                try acc.append(allocator, old_acc);
            }
            if (i <= 0) break :outer;
        }
    }

    return MalType.newList(allocator, try acc.toOwnedSlice(allocator));
}

fn quasiquote(allocator: std.mem.Allocator, ast: MalType) MalError!MalType {
    if (startsWith(ast, "unquote")) {
        return (try ast.asList()).get(1);
    } else {
        switch (ast) {
            .iterable => |it| switch (it) {
                .list => |l| return try quasiquoteLoop(allocator, l.items()),
                .vector => |v| {
                    var elements = try allocator.alloc(MalType, 2);
                    elements[0] = MalType.newSymbol("vec");
                    elements[1] = try quasiquoteLoop(allocator, v.items());
                    return MalType.newList(allocator, elements);
                },
                else => {},
            },
            .symbol, .hashmap => {
                var elements = try allocator.alloc(MalType, 2);
                elements[0] = MalType.newSymbol("quote");
                elements[1] = ast;
                return MalType.newList(allocator, elements);
            },
            else => {},
        }
    }

    return ast;
}

fn READ(allocator: std.mem.Allocator, x: []const u8) !MalType {
    return try reader.read_str(allocator, x);
}

fn EVAL(allocator: std.mem.Allocator, ast0: MalType, env0: *Env) MalError!MalType {
    var ast = ast0;
    var env = env0;

    outer: while (true) {
        const option_dbgeval = env.get("DEBUG-EVAL");
        if (option_dbgeval) |dbgeval| {
            const b = dbgeval.isBoolValue();
            if (b) {
                try stdout.writeAll("EVAL: ");
                try stdout.writeAll(try printer.pr_str(allocator, ast, true));
                try stdout.writeAll("\n");
                try stdout.flush();
            }
        }

        // try debug(allocator, ast);

        switch (ast) {
            .symbol => |s| {
                const option_result = env.get(s.value);
                if (option_result) |result| {
                    return result;
                } else {
                    const message = try std.fmt.allocPrint(allocator, "'{s}' not found", .{s.value});
                    return MalType.newException(allocator, MalType.newString(message));
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

        var forms = ast.iterable.list;
        if (forms.length() == 0) return ast;
        const list = ast.iterable.list;
        switch (list.items()[0]) {
            .symbol => |symbol| {
                const args = forms.items()[1..];
                if (std.mem.eql(u8, symbol.value, "def!")) {
                    const key = try args[0].as(MalSymbol);
                    const value = try EVAL(allocator, args[1], env);
                    switch (value) {
                        .exception => {},
                        else => try env.set(key.value, value),
                    }
                    return value;
                } else if (std.mem.eql(u8, symbol.value, "defmacro!")) {
                    const key = try args[0].as(MalSymbol);
                    var value = try EVAL(allocator, args[1], env);
                    _ = &value;
                    var macro: MalType = undefined;
                    switch (value) {
                        .callable => |c| switch (c.*) {
                            .closure => {
                                const cloned_callable = try c.clone(allocator);
                                cloned_callable.*.closure.is_macro = true;
                                macro = .{ .callable = cloned_callable };
                            },
                            else => return MalError.IncompatibleTypeConversion,
                        },
                        else => return MalError.IncompatibleTypeConversion,
                    }
                    try env.set(key.value, macro);
                    return macro;
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

                    ast = args[1];
                    env = new_env;
                    continue :outer;
                } else if (std.mem.eql(u8, symbol.value, "do")) {
                    const last = args.len - 1;
                    for (args[0..last]) |arg| {
                        _ = try EVAL(allocator, arg, env);
                    }
                    ast = args[last];
                    continue :outer;
                } else if (std.mem.eql(u8, symbol.value, "if")) {
                    const condition = try EVAL(allocator, args[0], env);
                    const b = condition.isBoolValue();
                    if (b) {
                        // True side of branch
                        ast = args[1];
                        continue :outer;
                    } else {
                        // False side of branch
                        if (args.len < 3) {
                            return MalType.newNil();
                        }
                        ast = args[2];
                        continue :outer;
                    }
                } else if (std.mem.eql(u8, symbol.value, "fn*")) {
                    const mal_it = try args[0].as(MalIterable);
                    var params = try allocator.alloc(MalSymbol, mal_it.length());
                    for (mal_it.items(), 0..params.len) |e, i| {
                        params[i] = try e.as(MalSymbol);
                    }

                    return try MalType.newClosure(allocator, params, args[1], env, EVAL);
                } else if (std.mem.eql(u8, symbol.value, "quote")) {
                    if (args.len > 1) {
                        return MalError.InvalidArgCount;
                    }
                    return args[0];
                } else if (std.mem.eql(u8, symbol.value, "quasiquote")) {
                    ast = try quasiquote(allocator, args[0]);
                    continue :outer;
                } else if (std.mem.eql(u8, symbol.value, "try*")) {
                    const body = args[0];
                    if (args.len < 2) {
                        ast = try EVAL(allocator, body, env);
                        continue :outer;
                    }
                    const catch_clause = try args[1].asList();

                    var exception_value: MalType = undefined;
                    const result = EVAL(allocator, body, env) catch |err| {
                        switch (err) {
                            error.Unbalanced, error.EOF => {
                                exception_value = MalType.newString(@errorName(err));
                            },
                            else => {
                                exception_value = MalType.newString(@errorName(err));
                            },
                        }
                        return err;
                    };
                    switch (result) {
                        .exception => |exp| {
                            exception_value = exp.value;
                        },
                        else => {
                            return result;
                        },
                    }
                    switch (catch_clause.items()[0]) {
                        .symbol => |s| {
                            if (!std.mem.eql(u8, s.value, "catch*")) {
                                return MalError.LackOfCatchClause;
                            }
                        },
                        else => return MalError.LackOfCatchClause,
                    }
                    const exception_symbol = try catch_clause.items()[1].as(MalSymbol);
                    const catch_body = catch_clause.items()[2];
                    var binds = try allocator.alloc(MalSymbol, 1);
                    binds[0] = exception_symbol;
                    var exprs = try allocator.alloc(MalType, 1);
                    exprs[0] = exception_value;
                    const new_env = try allocator.create(Env);
                    new_env.* = try Env.init(allocator, env, binds, exprs);
                    ast = try EVAL(allocator, catch_body, new_env);
                    continue :outer;
                }
            },
            else => {},
        }

        const f = try EVAL(allocator, forms.get(0), env);
        switch (f) {
            .callable => |callable| {
                if (callable.*.isMacro()) {
                    ast = try callable.call(allocator, list.items()[1..]);
                    continue :outer;
                }
            },
            .exception => return f,
            else => {},
        }
        var args = try allocator.alloc(MalType, forms.length() - 1);
        errdefer allocator.free(args);

        for (1..forms.length()) |i| {
            args[i - 1] = try EVAL(allocator, forms.get(i), env);
        }

        switch (f) {
            .callable => |c| {
                switch (c.*) {
                    .builtin => |mal_builtin| return try mal_builtin.call(allocator, args),
                    .closure => |mal_closure| {
                        const new_env = try allocator.create(Env);
                        new_env.* = try Env.init(allocator, mal_closure.env, mal_closure.params, args);

                        ast = mal_closure.ast;
                        env = new_env;
                        continue :outer;
                    },
                }
            },
            else => return MalError.IncompatibleTypeConversion,
        }
    }
}

fn PRINT(allocator: std.mem.Allocator, x: MalType) ![]const u8 {
    return try printer.pr_str(allocator, x, true);
}

fn rep(allocator: std.mem.Allocator, x: []const u8) ![]const u8 {
    const result = try EVAL(allocator, try READ(allocator, x), repl_env);
    switch (result) {
        .exception => |exp| {
            const message = try std.fmt.allocPrint(allocator, "Error: {s}", .{try printer.pr_str(allocator, exp.value, false)});
            return try PRINT(allocator, MalType.newString(message));
        },
        else => return try PRINT(allocator, result),
    }
}

const prompt = "user> ";

pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();

    const args = try init.minimal.args.toSlice(arena);
    const argv = if (args.len > 1) args[2..] else &.{};
    try setupEnv(arena, argv);
    if (args.len > 1) {
        const text = try std.fmt.allocPrint(arena,
            \\(load-file "{s}")
        , .{args[1]});
        _ = try rep(arena, text);
        return;
    }

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), init.io, &stdout_buffer);
    stdout = &stdout_file_writer.interface;

    try stdout.flush();

    _ = try rep(arena,
        \\(println (str "Mal [" *host-language* "]"))
    );
    while (true) {
        if (try rl.readline(prompt)) |input| {
            if (std.mem.eql(u8, input, "(exit)")) break;
            const output = rep(arena, input) catch |err| {
                try stdout.writeAll("Error: ");
                switch (err) {
                    error.Unbalanced => try stdout.writeAll("unbalanced"),
                    else => try stdout.writeAll(@errorName(err)),
                }
                try stdout.writeAll("\n");
                try stdout.flush();
                continue;
            };
            try stdout.writeAll(output);
            try stdout.writeAll("\n");
            try stdout.flush();
        }
    }
}
