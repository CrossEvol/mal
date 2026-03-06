const std = @import("std");

const MalAtom = @import("types.zig").MalAtom;
const MalBuiltin = @import("types.zig").MalBuiltin;
const MalCallable = @import("types.zig").MalCallable;
const MalError = @import("error.zig").MalError;
const MalFunction = @import("types.zig").MalFunction;
const MalHashMap = @import("types.zig").MalHashMap;
const MalInt = @import("types.zig").MalInt;
const MalIterable = @import("types.zig").MalIterable;
const MalKeyword = @import("types.zig").MalKeyword;
const MalNil = @import("types.zig").MalNil;
const MalString = @import("types.zig").MalString;
const MalSymbol = @import("types.zig").MalSymbol;
const MalType = @import("types.zig").MalType;
const pr_str = @import("printer.zig").pr_str;
const reader = @import("reader.zig");
const rl = @import("readline.zig");

pub const ns = std.StaticStringMap(MalFunction).initComptime(.{
    .{ "+", @"+" },
    .{ "-", @"-" },
    .{ "*", @"*" },
    .{ "/", @"/" },
    .{ "list", list },
    .{ "list?", @"list?" },
    .{ "empty?", @"empty?" },
    .{ "count", count },
    .{ "=", @"=" },
    .{ "<", @"<" },
    .{ "<=", @"<=" },
    .{ ">", @">" },
    .{ ">=", @">=" },
    .{ "pr-str", @"pr-str" },
    .{ "str", str },
    .{ "prn", prn },
    .{ "println", println },
    .{ "read-string", @"read-string" },
    .{ "slurp", slurp },
    .{ "atom", atom },
    .{ "atom?", @"atom?" },
    .{ "deref", deref },
    .{ "reset!", @"reset!" },
    .{ "swap!", @"swap!" },
    .{ "cons", cons },
    .{ "concat", concat },
    .{ "vec", vec },
    .{ "nth", nth },
    .{ "first", first },
    .{ "rest", rest },
    .{ "throw", throw },
    .{ "nil?", @"nil?" },
    .{ "true?", @"true?" },
    .{ "false?", @"false?" },
    .{ "symbol", symbol },
    .{ "symbol?", @"symbol?" },
    .{ "keyword", keyword },
    .{ "keyword?", @"keyword?" },
    .{ "number?", @"number?" },
    .{ "fn?", @"fn?" },
    .{ "macro?", @"macro?" },
    .{ "vector", vector },
    .{ "vector?", @"vector?" },
    .{ "hash-map", @"hash-map" },
    .{ "map?", @"map?" },
    .{ "assoc", assoc },
    .{ "dissoc", dissoc },
    .{ "get", get },
    .{ "contains?", @"contains?" },
    .{ "keys", keys },
    .{ "vals", vals },
    .{ "sequential?", @"sequential?" },
    .{ "readline", readline },
    .{ "time-ms", @"time-ms" },
    .{ "conj", conj },
    .{ "string?", @"string?" },
    .{ "seq", seq },
    .{ "map", map },
    .{ "apply", apply },
    .{ "meta", meta },
    .{ "with-meta", @"with-meta" },
});

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

fn list(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    return MalType.newList(allocator, args);
}

fn @"list?"(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    if (args.len > 1) {
        return MalError.InvalidArgCount;
    }
    const b = args[0].isList();

    return MalType.newBool(b);
}

fn @"empty?"(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    if (args.len > 1) {
        return MalError.InvalidArgCount;
    }
    const b = (try args[0].as(MalIterable)).length() == 0;

    return MalType.newBool(b);
}

fn count(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    const i = (try args[0].as(MalIterable)).length();

    return MalType.newInt(@intCast(i));
}

fn @"="(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    const a = args[0];
    const b = args[1];

    return MalType.newBool(a.eql(b));
}

fn @"<"(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    const a = try args[0].as(MalInt);
    const b = try args[1].as(MalInt);

    return MalType.newBool(a.value < b.value);
}

fn @"<="(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    const a = try args[0].as(MalInt);
    const b = try args[1].as(MalInt);

    return MalType.newBool(a.value <= b.value);
}

fn @">"(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    const a = try args[0].as(MalInt);
    const b = try args[1].as(MalInt);

    return MalType.newBool(a.value > b.value);
}

fn @">="(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    const a = try args[0].as(MalInt);
    const b = try args[1].as(MalInt);

    return MalType.newBool(a.value >= b.value);
}

fn @"pr-str"(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    var s = try std.ArrayList(u8).initCapacity(allocator, 32);
    for (0..args.len) |i| {
        try s.appendSlice(allocator, try pr_str(allocator, args[i], true));
        if (i != args.len - 1) {
            try s.append(allocator, ' ');
        }
    }

    return MalType.newString(try s.toOwnedSlice(allocator));
}

fn str(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    var s = try std.ArrayList(u8).initCapacity(allocator, 32);
    for (args) |arg| {
        try s.appendSlice(allocator, try pr_str(allocator, arg, false));
    }

    return MalType.newString(try s.toOwnedSlice(allocator));
}

fn prn(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    var s = try std.ArrayList(u8).initCapacity(allocator, 32);
    for (0..args.len) |i| {
        try s.appendSlice(allocator, try pr_str(allocator, args[i], true));
        if (i != args.len - 1) {
            try s.append(allocator, ' ');
        }
    }

    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;

    try stdout.writeAll(try s.toOwnedSlice(allocator));
    try stdout.writeAll("\n");
    try stdout.flush();

    return MalType.newNil();
}

fn println(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    var s = try std.ArrayList(u8).initCapacity(allocator, 32);
    for (0..args.len) |i| {
        try s.appendSlice(allocator, try pr_str(allocator, args[i], false));
        if (i != args.len - 1) {
            try s.append(allocator, ' ');
        }
    }

    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    try stdout.writeAll(try s.toOwnedSlice(allocator));
    try stdout.writeAll("\n");
    try stdout.flush();

    return MalType.newNil();
}

fn @"read-string"(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    if (args.len > 1) {
        return MalError.InvalidArgCount;
    }

    const code = try args[0].as(MalString);
    return reader.read_str(allocator, code.value);
}

fn slurp(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    if (args.len > 1) {
        return MalError.InvalidArgCount;
    }
    const filename = (try args[0].as(MalString)).value;

    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const _io = threaded.io();

    const cwd = std.Io.Dir.cwd();
    const file = try cwd.openFile(
        _io,
        filename,
        .{ .mode = .read_only },
    );
    defer file.close(_io);

    const stat = try file.stat(_io);
    const file_size = stat.size;
    const data = try allocator.alloc(u8, file_size);
    errdefer allocator.free(data);

    var fr = file.reader(_io, data);
    var r = &fr.interface;

    try r.readSliceAll(data);

    return MalType.newString(data);
}

fn atom(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    if (args.len > 1) {
        return MalError.InvalidArgCount;
    }

    return MalType.newAtom(allocator, args[0]);
}

fn @"atom?"(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    if (args.len > 1) {
        return MalError.InvalidArgCount;
    }

    const b = args[0].is(*MalAtom);

    return MalType.newBool(b);
}

fn deref(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    if (args.len > 1) {
        return MalError.InvalidArgCount;
    }

    return (try args[0].as(*MalAtom)).value;
}

fn @"reset!"(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    var mal_atom = try args[0].as(*MalAtom);
    const new_value = args[1];

    mal_atom.value = new_value;

    return new_value;
}

fn @"swap!"(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    const mal_atom = try args[0].as(*MalAtom);
    const func = try args[1].as(*MalCallable);

    var fn_args = try std.ArrayList(MalType).initCapacity(allocator, args.len - 1);
    try fn_args.append(allocator, mal_atom.value);
    try fn_args.appendSlice(allocator, args[2..]);

    const result = try func.call(allocator, try fn_args.toOwnedSlice(allocator));
    mal_atom.value = result;

    return result;
}

fn cons(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    const x = args[0];
    const xs = try args[1].as(MalIterable);

    var results = try std.ArrayList(MalType).initCapacity(allocator, args.len);
    try results.append(allocator, x);
    try results.appendSlice(allocator, xs.items());

    return MalType.newList(allocator, try results.toOwnedSlice(allocator));
}

fn concat(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    var results = try std.ArrayList(MalType).initCapacity(allocator, args.len);

    for (args) |element| {
        try results.appendSlice(allocator, switch (element) {
            .iterable => |it| it.items(),
            else => return MalError.IncompatibleTypeConversion,
        });
    }

    return MalType.newList(allocator, try results.toOwnedSlice(allocator));
}

fn vec(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    if (args.len == 1) {
        switch (args[0]) {
            .iterable => |it| switch (it) {
                .vector => return args[0],
                .list => |l| return MalType.newVector(allocator, l.items()),
                .nil => {},
            },
            else => {},
        }
    }

    return MalType.newException(allocator, MalType.newString("vec: wrong arguments"));
}

fn nth(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    const indexable = try args[0].as(MalIterable);
    const index = try args[1].as(MalInt);

    if (index.value < 0 or index.value >= indexable.length()) {
        return MalType.newException(allocator, MalType.newString("index out of range"));
    }

    return indexable.get(@intCast(index.value));
}

fn first(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    const it = try args[0].as(MalIterable);

    if (it.length() == 0) return MalType.newNil();

    return it.get(0);
}

fn rest(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    const it = try args[0].as(MalIterable);

    if (it.length() == 0) return MalType.newList(allocator, &.{});

    return MalType.newList(allocator, it.items()[1..]);
}

fn throw(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    return MalType.newException(allocator, args[0]);
}

fn @"nil?"(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    const b = args[0].isNil();

    return MalType.newBool(b);
}

fn @"true?"(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    const b = switch (args[0]) {
        .bool => |b| b.value,
        else => false,
    };

    return MalType.newBool(b);
}

fn @"false?"(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    const b = switch (args[0]) {
        .bool => |b| !b.value,
        else => false,
    };

    return MalType.newBool(b);
}

fn symbol(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    const value = (try args[0].as(MalString)).value;

    return MalType.newSymbol(value);
}

fn @"symbol?"(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    const b = args[0].is(MalSymbol);

    return MalType.newBool(b);
}

fn keyword(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    const arg = args[0];
    return switch (arg) {
        .keyword => arg,
        .string => |s| MalType.newKeyword(s.value),
        else => return MalError.IncompatibleTypeConversion,
    };
}

fn @"keyword?"(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    const b = args[0].is(MalKeyword);

    return MalType.newBool(b);
}

fn @"number?"(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    const b = args[0].is(MalInt);

    return MalType.newBool(b);
}

fn @"fn?"(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    const b = switch (args[0]) {
        .callable => |c| !c.isMacro(),
        else => false,
    };

    return MalType.newBool(b);
}

fn @"macro?"(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    const b = switch (args[0]) {
        .callable => |c| c.isMacro(),
        else => false,
    };

    return MalType.newBool(b);
}

fn vector(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    return MalType.newVector(allocator, args);
}

fn @"vector?"(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    const b = args[0].isVector();

    return MalType.newBool(b);
}

fn @"hash-map"(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    return MalType.fromSequence(allocator, args);
}

fn @"map?"(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    const b = args[0].is(MalHashMap);

    return MalType.newBool(b);
}

fn assoc(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    const hm = try args[0].as(MalHashMap);
    const assoc_parts = try MalHashMap.fromSequence(allocator, args[1..]);

    var new_map = try MalHashMap.init(allocator, hm.value);
    var iter = assoc_parts.value.iterator();
    while (iter.next()) |entry| {
        try new_map.value.put(entry.key_ptr.*, entry.value_ptr.*);
    }

    return try MalType.newHashMap(allocator, new_map.value);
}

fn dissoc(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    const hm = try args[0].as(MalHashMap);
    var new_map = try MalHashMap.init(allocator, hm.value);

    for (args[1..]) |key| {
        _ = new_map.value.remove(key);
    }

    return try MalType.newHashMap(allocator, new_map.value);
}

fn get(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    if (args[0].isNil()) return MalType.newNil();

    const hm = try args[0].as(MalHashMap);
    const key = args[1];
    if (hm.value.contains(key)) {
        return hm.value.get(key).?;
    }

    return MalType.newNil();
}

fn @"contains?"(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    const hm = try args[0].as(MalHashMap);
    const key = args[1];

    return MalType.newBool(hm.value.contains(key));
}

fn keys(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    const hm = try args[0].as(MalHashMap);

    var ks = try std.ArrayList(MalType).initCapacity(allocator, 8);
    var key_iter = hm.value.keyIterator();
    while (key_iter.next()) |key| {
        try ks.append(allocator, key.*);
    }

    return MalType.newList(allocator, try ks.toOwnedSlice(allocator));
}

fn vals(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    const hm = try args[0].as(MalHashMap);

    var vs = try std.ArrayList(MalType).initCapacity(allocator, 8);
    var value_iter = hm.value.valueIterator();
    while (value_iter.next()) |val| {
        try vs.append(allocator, val.*);
    }

    return MalType.newList(allocator, try vs.toOwnedSlice(allocator));
}

fn @"sequential?"(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    const b = args[0].isIterable();

    return MalType.newBool(b);
}

fn readline(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    const message = try args[0].as(MalString);
    std.debug.print("{s}\n", .{message.value});

    const option_input = try rl.readline("");
    if (option_input) |input| {
        return MalType.newString(input);
    }

    return MalType.newNil();
}

const C = @cImport({
    @cInclude("sys/time.h");
});

fn getCurrentMsCStyle() i64 {
    var tv: C.struct_timeval = undefined;
    _ = C.gettimeofday(&tv, null);
    return @as(i64, tv.tv_sec) * 1000 + @divFloor(tv.tv_usec, 1000);
}

fn @"time-ms"(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    if (args.len != 0) {
        return MalError.InvalidArgCount;
    }

    return MalType.newInt(getCurrentMsCStyle());
}

fn conj(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    const collection = args[0];
    const elements = args[1..];
    switch (collection) {
        .iterable => |it| switch (it) {
            .list => |l| {
                var new_elements = try std.ArrayList(MalType).initCapacity(allocator, 8);
                var i = elements.len - 1;
                while (true) {
                    try new_elements.append(allocator, elements[i]);
                    if (i == 0) break;
                    i -= 1;
                }
                for (l.elements.items) |item| {
                    try new_elements.append(allocator, item);
                }
                return MalType.newList(allocator, try new_elements.toOwnedSlice(allocator));
            },
            .vector => |v| {
                var new_elements = try std.ArrayList(MalType).initCapacity(allocator, 8);
                for (v.elements.items) |element| {
                    try new_elements.append(allocator, element);
                }
                try new_elements.appendSlice(allocator, elements);
                return MalType.newVector(allocator, try new_elements.toOwnedSlice(allocator));
            },
            else => {},
        },
        else => {},
    }
    return MalType.newException(allocator, MalType.newString(
        \\"conj" takes a list or vector
    ));
}

fn @"string?"(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    const b = args[0].is(MalString);

    return MalType.newBool(b);
}

fn seq(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    const arg = args[0];
    switch (arg) {
        .iterable => |it| {
            if (it.length() == 0) return MalType.newNil();

            return switch (it) {
                .nil, .list => arg,
                .vector => return MalType.newList(allocator, it.items()),
            };
        },
        .string => |s| {
            if (s.value.len == 0) return MalType.newNil();

            var chars = try std.ArrayList(MalType).initCapacity(allocator, s.value.len);
            for (s.value) |c| {
                try chars.append(allocator, MalType.newString(try allocator.dupe(u8, &.{c})));
            }
            return MalType.newList(allocator, try chars.toOwnedSlice(allocator));
        },
        else => {},
    }

    // throw new MalException(new MalString('bad argument to "seq"'));
    return MalType.newException(allocator, MalType.newString(
        \\bad argument to "seq"
    ));
}

fn map(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    const fun = try args[0].as(*MalCallable);
    const old_list = try args[1].as(MalIterable);

    var new_list = try std.ArrayList(MalType).initCapacity(allocator, 8);
    for (old_list.items()) |element| {
        var func_args = try allocator.alloc(MalType, 1);
        func_args[0] = element;

        try new_list.append(allocator, try fun.call(allocator, func_args));
    }

    return MalType.newList(allocator, try new_list.toOwnedSlice(allocator));
}

fn apply(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    const func = try args[0].as(*MalCallable);
    const arg_list = try args[args.len - 1].as(MalIterable);

    var new_args = try std.ArrayList(MalType).initCapacity(allocator, 8);
    for (args[1 .. args.len - 1]) |arg| {
        try new_args.append(allocator, arg);
    }
    for (arg_list.items()) |arg| {
        try new_args.append(allocator, arg);
    }

    return func.call(allocator, try new_args.toOwnedSlice(allocator));
}

fn meta(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    _ = allocator;

    const arg = args[0];
    if (arg.getMeta()) |mt| {
        return mt.*;
    }

    return MalType.newNil();
}

fn @"with-meta"(allocator: std.mem.Allocator, args: []MalType) MalError!MalType {
    const evaled = args[0];
    var evaled_with_meta = try evaled.clone(allocator);
    evaled_with_meta.setMeta(&args[1]);

    return evaled_with_meta;
}
