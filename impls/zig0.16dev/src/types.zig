const std = @import("std");

const Env = @import("env.zig").Env;
const MalError = @import("error.zig").MalError;

inline fn tagForType(comptime Union: type, comptime T: type) std.meta.Tag(Union) {
    const TagType = std.meta.Tag(Union);
    inline for (std.meta.fields(Union)) |field| {
        if (field.type == T) {
            return std.meta.stringToEnum(TagType, field.name) orelse unreachable;
        }
    }
    @compileError("Type `" ++ @typeName(T) ++ "` is not a field type of `" ++ @typeName(Union) ++ "`");
}

inline fn asImpl(comptime Curr: type, self: *const Curr, comptime T: type) T {
    const tag = comptime tagForType(Curr, T);
    if (std.meta.activeTag(self.*) != tag) unreachable;
    return @field(self.*, @tagName(tag));
}

inline fn isImpl(comptime Curr: type, self: *const Curr, comptime T: type) bool {
    return std.meta.activeTag(self.*) == comptime tagForType(Curr, T);
}

inline fn intoImpl(
    comptime Current: type,
    val: *const Current,
    comptime path: []const type,
    comptime T: type, // for zls type inference
) MalError!T {
    if (comptime path.len == 0) @compileError("into: path must not be empty");

    comptime if (path[path.len - 1] != T) {
        @compileError("into: typeB must equal the last type in path, got `" ++
            @typeName(T) ++ "` vs `" ++ @typeName(path[path.len - 1]) ++ "`");
    };

    const Next = path[0];
    const tag = comptime tagForType(Current, Next);
    if (std.meta.activeTag(val.*) != tag) return MalError.IncompatibleTypeConversion;
    const next_val: Next = @field(val.*, @tagName(tag));

    return if (comptime path.len == 1)
        next_val
    else
        intoImpl(Next, &next_val, path[1..], T);
}

inline fn intoCheck(
    comptime Current: type,
    val: *const Current,
    comptime path: []const type,
) bool {
    if (comptime path.len == 0) @compileError("into: path must not be empty");

    const Next = path[0];
    const tag = comptime tagForType(Current, Next);
    if (std.meta.activeTag(val.*) != tag) return false;
    const next_val: Next = @field(val.*, @tagName(tag));

    return if (comptime path.len == 1)
        true
    else
        intoCheck(Next, &next_val, path[1..]);
}

pub const MalType = union(enum) {
    iterable: MalIterable,
    hashmap: MalHashMap,
    int: MalInt,
    symbol: MalSymbol,
    keyword: MalKeyword,
    string: MalString,
    bool: MalBool,
    atom: *MalAtom,
    callable: *MalCallable,
    exception: *MalException,

    /// not to coerce type conversion, but convert it to bool value
    pub fn isBoolValue(self: *const MalType) bool {
        return switch (self.*) {
            .iterable => |it| switch (it) {
                .nil => false,
                else => true,
            },
            .bool => |b| b.value,
            else => true,
        };
    }

    pub fn as(self: *const MalType, comptime T: type) !T {
        return asImpl(MalType, self, T);
    }

    pub fn is(self: *const MalType, comptime T: type) bool {
        return isImpl(MalType, self, T);
    }

    inline fn into(self: *const MalType, comptime path: []const type, comptime T: type) !T {
        return try intoImpl(MalType, self, path, T);
    }
    inline fn check(self: *const MalType, comptime path: []const type) bool {
        return intoCheck(MalType, self, path);
    }

    pub fn asList(self: *const MalType) !MalList {
        return self.into(&.{ MalIterable, MalList }, MalList);
    }

    pub fn isNil(self: *const MalType) bool {
        return self.check(&.{ MalIterable, MalNil });
    }

    pub fn isList(self: *const MalType) bool {
        return self.check(&.{ MalIterable, MalList });
    }

    pub fn isVector(self: *const MalType) bool {
        return self.check(&.{ MalIterable, MalVector });
    }

    pub fn isSequential(self: *const MalType) bool {
        return switch (self.*) {
            .iterable => |it| switch (it) {
                .list, .vector => true,
                else => false,
            },
            else => false,
        };
    }

    pub fn newInt(value: i64) MalType {
        return .{ .int = MalInt.init(value) };
    }

    pub fn newBool(value: bool) MalType {
        return .{ .bool = MalBool.init(value) };
    }

    pub fn newNil() MalType {
        return .{ .iterable = .{ .nil = MalNil.init() } };
    }

    pub fn newSymbol(value: []const u8) MalType {
        return .{ .symbol = MalSymbol.init(value) };
    }

    pub fn newKeyword(value: []const u8) MalType {
        return .{ .keyword = MalKeyword.init(value) };
    }

    pub fn newString(value: []const u8) MalType {
        return .{ .string = MalString.init(value) };
    }

    pub fn newList(allocator: std.mem.Allocator, elements: []MalType) !MalType {
        const list = try MalList.init(allocator, elements);
        return .{ .iterable = .{ .list = list } };
    }

    pub fn newVector(allocator: std.mem.Allocator, elements: []MalType) !MalType {
        const vector = try MalVector.init(allocator, elements);
        return .{ .iterable = .{ .vector = vector } };
    }

    pub fn newHashMap(allocator: std.mem.Allocator, value: std.HashMap(
        MalType,
        MalType,
        MalTypeContext,
        std.hash_map.default_max_load_percentage,
    )) !MalType {
        return .{ .hashmap = try MalHashMap.init(allocator, value) };
    }

    pub fn fromSequence(allocator: std.mem.Allocator, elements: []MalType) !MalType {
        return .{ .hashmap = try MalHashMap.fromSequence(allocator, elements) };
    }

    pub fn newAtom(allocator: std.mem.Allocator, value: MalType) !MalType {
        const atom = try allocator.create(MalAtom);
        atom.* = MalAtom.init(value);
        return .{ .atom = atom };
    }

    pub fn newException(allocator: std.mem.Allocator, value: MalType) !MalType {
        const exception = try allocator.create(MalException);
        exception.* = MalException.init(value);
        return .{ .exception = exception };
    }

    pub fn newBuiltin(allocator: std.mem.Allocator, func: MalFunction) !MalType {
        const callable = try allocator.create(MalCallable);
        callable.* = .{ .builtin = MalBuiltin.init(func) };
        return .{ .callable = callable };
    }

    pub fn newClosure(allocator: std.mem.Allocator, params: []MalSymbol, ast: MalType, env: *Env, eval_fn: EvalFunction) !MalType {
        const callable = try allocator.create(MalCallable);
        callable.* = .{ .closure = MalClosure.init(params, ast, env, eval_fn) };
        return .{ .callable = callable };
    }

    pub fn deinit(self: *MalType, alllocator: std.mem.Allocator) void {
        _ = self;
        _ = alllocator;
    }

    pub fn clone(self: *const MalType, allocator: std.mem.Allocator) !MalType {
        return switch (self.*) {
            .iterable => |it| .{ .iterable = try it.clone(allocator) },
            .hashmap => |mal_hashmap| .{ .hashmap = try mal_hashmap.clone() },
            .int => |mal_int| .{ .int = mal_int.clone() },
            .symbol => |mal_symbol| .{ .symbol = mal_symbol.clone() },
            .keyword => |mal_keyword| .{ .keyword = mal_keyword.clone() },
            .string => |mal_string| .{ .string = mal_string.clone() },
            .bool => |mal_bool| .{ .bool = mal_bool.clone() },
            .atom => |mal_atom| .{ .atom = try mal_atom.clone(allocator) },
            .callable => |mal_callable| .{ .callable = try mal_callable.clone(allocator) },
            .exception => @panic("exception can not be cloned"),
        };
    }

    pub fn hash(self: MalType) u64 {
        var hasher = std.hash.Wyhash.init(0);

        std.hash.autoHash(&hasher, std.meta.activeTag(self));

        switch (self) {
            .iterable => |mal_iterable| switch (mal_iterable) {
                .nil => {},
                else => std.hash.autoHash(&hasher, @intFromPtr(&mal_iterable)),
            },
            .hashmap => |mal_hashmap| std.hash.autoHash(&hasher, @intFromPtr(&mal_hashmap)),
            .int => |mal_int| std.hash.autoHash(&hasher, mal_int.value),
            .symbol => |mal_symbol| std.hash.autoHash(&hasher, @intFromPtr(&mal_symbol)),
            .keyword => |mal_keyword| std.hash.autoHash(&hasher, mal_keyword.hash_code),
            .string => |mal_string| std.hash.autoHash(&hasher, mal_string.hash_code),
            .bool => |mal_bool| std.hash.autoHash(&hasher, mal_bool.value),
            .atom => |mal_atom| std.hash.autoHash(&hasher, @intFromPtr(mal_atom)),
            .callable => |mal_callable| std.hash.autoHash(&hasher, @intFromPtr(mal_callable)),
            .exception => @panic("exception can not be hashed"),
        }

        return hasher.final();
    }

    pub fn eql(self: MalType, other: MalType) bool {
        if (std.meta.activeTag(self) != std.meta.activeTag(other)) {
            return false;
        }

        return switch (self) {
            .iterable => |mal_iterable| mal_iterable.eql(other),
            .hashmap => |mal_hashmap| mal_hashmap.eql(other),
            .int => |mal_int| mal_int.eql(other),
            .symbol => |mal_symbol| mal_symbol.eql(other),
            .keyword => |mal_keyword| mal_keyword.eql(other),
            .string => |mal_string| mal_string.eql(other),
            .bool => |mal_bool| mal_bool.eql(other),
            .atom => @intFromPtr(&self) == @intFromPtr(&other),
            .callable => @intFromPtr(&self) == @intFromPtr(&other),
            .exception => @intFromPtr(&self) == @intFromPtr(&other),
        };
    }

    pub fn isMacro(self: *MalType) bool {
        return switch (self.*) {
            .callable => |mal_callable| mal_callable.isMacro(),
            else => false,
        };
    }

    pub fn getMeta(self: *const MalType) ?*MalType {
        return switch (self.*) {
            .iterable => |it| switch (it) {
                .list => |l| l.meta,
                .vector => |v| v.meta,
                .nil => |n| n.meta,
            },
            .hashmap => |hm| hm.meta,
            .int => |i| i.meta,
            .symbol => |s| s.meta,
            .keyword => |kw| kw.meta,
            .string => |s| s.meta,
            .bool => |b| b.meta,
            .atom => |a| a.meta,
            .callable => |c| switch (c.*) {
                .builtin => |b| b.meta,
                .closure => |cl| cl.meta,
            },
            .exception => |mal_exception| mal_exception.meta,
        };
    }

    pub fn setMeta(self: *MalType, meta: ?*MalType) void {
        return switch (self.*) {
            .iterable => |*it| switch (it.*) {
                .list => |*l| l.*.meta = meta,
                .vector => |*v| v.*.meta = meta,
                .nil => |*n| n.*.meta = meta,
            },
            .hashmap => |*hm| hm.*.meta = meta,
            .int => |*i| i.*.meta = meta,
            .symbol => |*s| s.*.meta = meta,
            .keyword => |*kw| kw.*.meta = meta,
            .string => |*s| s.*.meta = meta,
            .bool => |*b| b.*.meta = meta,
            .atom => |*a| a.*.meta = meta,
            .callable => |*c| switch (c.*.*) {
                .builtin => |*b| b.*.meta = meta,
                .closure => |*cl| cl.*.meta = meta,
            },
            .exception => |*mal_exception| mal_exception.*.meta = meta,
        };
    }
};

pub const MalIterable = union(enum) {
    list: MalList,
    vector: MalVector,
    nil: MalNil,

    pub fn as(self: *const MalIterable, comptime T: type) !T {
        return asImpl(MalIterable, self, T);
    }

    pub fn is(self: *const MalIterable, comptime T: type) bool {
        return isImpl(MalIterable, self, T);
    }

    pub fn length(self: *const MalIterable) usize {
        return switch (self.*) {
            .list => |mal_list| mal_list.length(),
            .vector => |mal_vector| mal_vector.length(),
            .nil => 0,
        };
    }

    pub fn items(self: *const MalIterable) []MalType {
        return switch (self.*) {
            .list => |mal_list| mal_list.items(),
            .vector => |mal_vector| mal_vector.items(),
            .nil => &.{},
        };
    }

    pub fn setLength(self: *MalIterable, allocator: std.mem.Allocator, new_len: usize) void {
        return switch (self.*) {
            .list => |mal_list| mal_list.elements.resize(allocator, new_len),
            .vector => |mal_vector| mal_vector.elements.resize(allocator, new_len),
            .nil => {},
        };
    }

    pub fn get(self: *const MalIterable, index: usize) MalType {
        return switch (self.*) {
            .list => |mal_list| mal_list.get(index),
            .vector => |mal_vector| mal_vector.get(index),
            .nil => @panic("can not get from nil"),
        };
    }

    pub fn set(self: *MalIterable, index: usize, value: MalType) void {
        return switch (self.*) {
            .list => |mal_list| mal_list.set(index, value),
            .vector => |mal_vector| mal_vector.set(index, value),
            .nil => @panic("can not set on nil"),
        };
    }

    pub fn eql(self: MalIterable, other: MalType) bool {
        switch (self) {
            .nil => switch (other) {
                .iterable => |it| switch (it) {
                    .nil => return true,
                    else => return false,
                },
                else => return false,
            },
            else => {
                switch (other) {
                    .iterable => |o| {
                        switch (o) {
                            .nil => return switch (self) {
                                .nil => true,
                                else => false,
                            },
                            else => {},
                        }
                        if (self.length() != o.length()) return false;
                        for (0..self.length()) |i| {
                            if (!self.get(i).eql(o.get(i))) return false;
                        }
                        return true;
                    },
                    else => return false,
                }
            },
        }
    }

    pub fn clone(self: *const MalIterable, allocator: std.mem.Allocator) !MalIterable {
        return switch (self.*) {
            .list => |mal_list| .{ .list = try mal_list.clone(allocator) },
            .vector => |mal_vector| .{ .vector = try mal_vector.clone(allocator) },
            .nil => |mal_nil| .{ .nil = mal_nil.clone() },
        };
    }
};

pub const MalList = struct {
    elements: std.ArrayList(MalType),
    meta: ?*MalType,

    pub fn init(allocator: std.mem.Allocator, elements0: []MalType) !MalList {
        var elements = try std.ArrayList(MalType).initCapacity(allocator, elements0.len);
        try elements.appendSlice(allocator, elements0);
        return .{
            .elements = elements,
            .meta = null,
        };
    }

    pub fn items(self: *const MalList) []MalType {
        return self.elements.items;
    }

    pub fn get(self: *const MalList, index: usize) MalType {
        return self.elements.items[index];
    }

    pub fn set(self: *MalList, index: usize, value: MalType) void {
        self.elements.items[index] = value;
    }

    pub fn length(self: *const MalList) usize {
        return self.elements.items.len;
    }

    pub fn clone(self: *const MalList, allocator: std.mem.Allocator) !MalList {
        var cloned_elements = try self.elements.clone(allocator);

        return init(allocator, try cloned_elements.toOwnedSlice(allocator));
    }
};

pub const MalVector = struct {
    elements: std.ArrayList(MalType),
    meta: ?*MalType,

    pub fn init(allocator: std.mem.Allocator, elements0: []MalType) !MalVector {
        var elements = try std.ArrayList(MalType).initCapacity(allocator, elements0.len);
        try elements.appendSlice(allocator, elements0);
        return .{
            .elements = elements,
            .meta = null,
        };
    }

    pub fn items(self: *const MalVector) []MalType {
        return self.elements.items;
    }

    pub fn get(self: *const MalVector, index: usize) MalType {
        return self.elements.items[index];
    }

    pub fn set(self: *MalVector, index: usize, value: MalType) void {
        self.elements.items[index] = value;
    }

    pub fn length(self: *const MalVector) usize {
        return self.elements.items.len;
    }

    pub fn clone(self: *const MalVector, allocator: std.mem.Allocator) !MalVector {
        var cloned_elements = try self.elements.clone(allocator);

        return init(allocator, try cloned_elements.toOwnedSlice(allocator));
    }
};

pub const MalHashMap = struct {
    allocator: std.mem.Allocator,
    value: std.HashMap(MalType, MalType, MalTypeContext, std.hash_map.default_max_load_percentage),
    meta: ?*MalType,

    pub fn init(allocator: std.mem.Allocator, value: std.HashMap(
        MalType,
        MalType,
        MalTypeContext,
        std.hash_map.default_max_load_percentage,
    )) !MalHashMap {
        var new_value = std.HashMap(MalType, MalType, MalTypeContext, std.hash_map.default_max_load_percentage).init(allocator);
        var iter = value.iterator();
        while (iter.next()) |entry| {
            try new_value.put(entry.key_ptr.*, entry.value_ptr.*);
        }

        return .{
            .allocator = allocator,
            .value = new_value,
            .meta = null,
        };
    }

    pub fn fromSequence(allocator: std.mem.Allocator, elements: []MalType) !MalHashMap {
        const value = std.HashMap(MalType, MalType, MalTypeContext, std.hash_map.default_max_load_percentage).init(allocator);
        var map = try init(allocator, value);

        var reading_key = true;
        var pending_key: MalType = undefined;
        for (elements) |mal_type| {
            if (reading_key) {
                switch (mal_type) {
                    .string, .keyword => pending_key = mal_type,
                    else => {
                        // TODO: throw new ArgumentError('hash-map keys must be strings or keywords');
                        @panic("hash-map keys must be strings or keywords");
                    },
                }
            } else {
                try map.value.put(pending_key, mal_type);
            }
            reading_key = !reading_key;
        }

        return map;
    }

    pub fn eql(self: MalHashMap, other: MalType) bool {
        return switch (other) {
            .hashmap => |o| {
                if (self.value.count() != o.value.count()) return false;
                var key_iter = self.value.keyIterator();
                while (key_iter.next()) |key| {
                    if (!o.value.contains(key.*)) return false;
                    if (self.value.get(key.*) == null or o.value.get(key.*) == null) {
                        return false;
                    }
                    return self.value.get(key.*).?.eql(o.value.get(key.*).?);
                }
                return true;
            },
            else => false,
        };
    }

    pub fn clone(self: *const MalHashMap) !MalHashMap {
        var mal_hash_map = try init(self.allocator, self.value);

        var iter = self.value.iterator();
        while (iter.next()) |entry| {
            try mal_hash_map.value.put(entry.key_ptr.*, entry.value_ptr.*);
        }

        return mal_hash_map;
    }
};

pub const MalTypeContext = struct {
    pub fn hash(_: MalTypeContext, key: MalType) u64 {
        return key.hash();
    }

    pub fn eql(_: MalTypeContext, a: MalType, b: MalType) bool {
        return a.eql(b);
    }
};

pub const MalInt = struct {
    value: i64,
    meta: ?*MalType,

    pub fn init(value: i64) MalInt {
        return .{ .value = value, .meta = null };
    }

    pub fn eql(self: MalInt, other: MalType) bool {
        return switch (other) {
            .int => |o| self.value == o.value,
            else => false,
        };
    }

    pub fn clone(self: *const MalInt) MalInt {
        return init(self.value);
    }
};

pub const MalSymbol = struct {
    value: []const u8,
    hash_code: u32,
    meta: ?*MalType,

    pub fn init(value: []const u8) MalSymbol {
        return .{
            .value = value,
            .hash_code = hashString(value),
            .meta = null,
        };
    }

    pub fn eql(self: MalSymbol, other: MalType) bool {
        return switch (other) {
            .symbol => |o| std.mem.eql(u8, self.value, o.value),
            else => false,
        };
    }

    pub fn clone(self: *const MalSymbol) MalSymbol {
        return init(self.value);
    }
};

pub const MalKeyword = struct {
    value: []const u8,
    hash_code: u32,
    meta: ?*MalType,

    pub fn init(value: []const u8) MalKeyword {
        var hash: u32 = 2166136261;
        hash ^= ':';
        hash *%= 16777619;
        for (value) |bit| {
            hash ^= bit;
            hash *%= 16777619;
        }

        return .{
            .value = value,
            .hash_code = hash,
            .meta = null,
        };
    }

    pub fn eql(self: MalKeyword, other: MalType) bool {
        return switch (other) {
            .keyword => |o| std.mem.eql(u8, self.value, o.value),
            else => false,
        };
    }

    pub fn clone(self: *const MalKeyword) MalKeyword {
        return init(self.value);
    }
};

pub const MalString = struct {
    value: []const u8,
    hash_code: u32,
    meta: ?*MalType,

    pub fn init(value: []const u8) MalString {
        return .{
            .value = value,
            .hash_code = hashString(value),
            .meta = null,
        };
    }

    pub fn eql(self: MalString, other: MalType) bool {
        return switch (other) {
            .string => |o| std.mem.eql(u8, self.value, o.value),
            else => false,
        };
    }

    pub fn clone(self: *const MalString) MalString {
        return init(self.value);
    }
};

fn hashString(key: []const u8) u32 {
    var hash: u32 = 2166136261;
    for (key) |bit| {
        hash ^= bit;
        hash *%= 16777619;
    }
    return hash;
}

pub const MalBool = struct {
    value: bool,
    meta: ?*MalType,

    pub fn init(value: bool) MalBool {
        return .{
            .value = value,
            .meta = null,
        };
    }

    pub fn eql(self: MalBool, other: MalType) bool {
        return switch (other) {
            .bool => |o| self.value == o.value,
            else => false,
        };
    }

    pub fn clone(self: *const MalBool) MalBool {
        return init(self.value);
    }
};

pub const MalNil = struct {
    meta: ?*MalType,

    pub fn init() MalNil {
        return .{
            .meta = null,
        };
    }

    pub fn length(self: *const MalNil) usize {
        _ = self;
        return 0;
    }

    pub fn eql(self: MalNil, other: MalType) bool {
        _ = self;
        switch (other) {
            .nil => true,
            else => false,
        }
        return;
    }

    pub fn clone(self: *const MalNil) MalNil {
        _ = self;
        return init();
    }
};

pub const MalAtom = struct {
    value: MalType,
    meta: ?*MalType,

    pub fn init(value: MalType) MalAtom {
        return .{
            .value = value,
            .meta = null,
        };
    }

    pub fn clone(self: *const MalAtom, allocator: std.mem.Allocator) !*MalAtom {
        const mal_atom = try allocator.create(MalAtom);
        mal_atom.* = MalAtom.init(self.value);

        return mal_atom;
    }
};

pub const MalCallable = union(enum) {
    builtin: MalBuiltin,
    closure: MalClosure,

    pub fn as(self: *const MalBuiltin, comptime T: type) !T {
        return asImpl(MalCallable, self, T);
    }

    pub fn is(self: *const MalClosure, comptime T: type) bool {
        return isImpl(MalCallable, self, T);
    }

    pub fn call(self: *MalCallable, allocator: std.mem.Allocator, args: []MalType) !MalType {
        return switch (self.*) {
            .builtin => |mal_builtin| try mal_builtin.call(allocator, args),
            .closure => |mal_closure| try mal_closure.call(allocator, args),
        };
    }

    pub fn isMacro(self: *const MalCallable) bool {
        return switch (self.*) {
            .builtin => |mal_builtin| mal_builtin.is_macro,
            .closure => |mal_closure| mal_closure.is_macro,
        };
    }

    pub fn clone(self: *const MalCallable, allocator: std.mem.Allocator) !*MalCallable {
        const callable = try allocator.create(MalCallable);
        switch (self.*) {
            .builtin => |mal_builtin| callable.* = .{ .builtin = mal_builtin.clone() },
            .closure => |mal_closure| callable.* = .{ .closure = mal_closure.clone() },
        }

        return callable;
    }
};

pub const MalFunction =
    *const fn (allocator: std.mem.Allocator, args: []MalType) MalError!MalType;

pub const MalBuiltin = struct {
    func: MalFunction,
    is_macro: bool,
    meta: ?*MalType,

    pub fn init(func: MalFunction) MalBuiltin {
        return .{
            .func = func,
            .is_macro = false,
            .meta = null,
        };
    }

    pub fn call(self: *const MalBuiltin, allocator: std.mem.Allocator, args: []MalType) !MalType {
        return try self.func(allocator, args);
    }

    pub fn clone(self: *const MalBuiltin) MalBuiltin {
        return init(self.func);
    }
};

pub const EvalFunction = *const fn (
    allocator: std.mem.Allocator,
    ast: MalType,
    env: *Env,
) MalError!MalType;

pub const MalClosure = struct {
    params: []MalSymbol,
    ast: MalType,
    env: *Env,
    eval_fn: EvalFunction,
    is_macro: bool,
    meta: ?*MalType,

    pub fn init(
        params: []MalSymbol,
        ast: MalType,
        env: *Env,
        eval_fn: EvalFunction,
    ) MalClosure {
        return .{
            .params = params,
            .ast = ast,
            .env = env,
            .eval_fn = eval_fn,
            .is_macro = false,
            .meta = null,
        };
    }

    pub fn call(self: *const MalClosure, allocator: std.mem.Allocator, args: []MalType) !MalType {
        const new_env = try allocator.create(Env);
        new_env.* = try Env.init(allocator, self.env, self.params, args);

        return try self.eval_fn(allocator, self.ast, new_env);
    }

    pub fn clone(self: *const MalClosure) MalClosure {
        var mal_closure = init(self.params, self.ast, self.env, self.eval_fn);
        mal_closure.is_macro = self.is_macro;
        return mal_closure;
    }
};

pub const MalException = struct {
    value: MalType,
    meta: ?*MalType,

    pub fn init(value: MalType) MalException {
        return .{
            .value = value,
            .meta = null,
        };
    }
};
