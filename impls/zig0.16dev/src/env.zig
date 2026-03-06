const std = @import("std");

const MalSymbol = @import("types.zig").MalSymbol;
const MalType = @import("types.zig").MalType;

pub const Env = struct {
    outer: ?*Env,
    data: std.StringHashMap(MalType),

    pub fn init(
        allocator: std.mem.Allocator,
        outer: ?*Env,
        maybe_binds: ?[]MalSymbol,
        maybe_exprs: ?[]MalType,
    ) !Env {
        const data = std.StringHashMap(MalType).init(allocator);
        var env: Env = .{
            .outer = outer,
            .data = data,
        };

        if (maybe_binds) |binds| {
            if (maybe_exprs) |exprs| {
                if (binds.len != exprs.len and !contains(binds, MalType.newSymbol("&"))) {
                    @panic("when length of exprs is not equal to length of binds, it must be '&'rest ");
                }
                for (0..binds.len) |i| {
                    if (std.mem.eql(u8, binds[i].value, "&")) {
                        try env.set(binds[i + 1].value, try MalType.newList(allocator, exprs[i..]));
                        break;
                    }
                    try env.set(binds[i].value, exprs[i]);
                }
            }
        } else {
            if (maybe_exprs != null) {
                @panic("when binds is null, exprs must be null");
            }
        }

        return env;
    }

    pub fn set(self: *Env, key: []const u8, value: MalType) !void {
        try self.data.put(key, value);
    }

    pub fn get(self: *Env, key: []const u8) ?MalType {
        const option_value = self.data.get(key);
        if (option_value) |value| {
            return value;
        }
        if (self.outer) |outer| {
            return outer.get(key);
        }
        return null;
    }
};

/// Checks if the list contains the element t.
/// Supports ArrayList, fixed-size Array, Slice, and pointers to them.
fn contains(list: anytype, t: anytype) bool {
    const ListType = @TypeOf(list);

    // 1. Extract the underlying items slice
    const items = blk: {
        const info = @typeInfo(ListType);
        break :blk switch (info) {
            .@"struct" => if (@hasField(ListType, "items")) list.items else @compileError("Struct must have 'items' field"),
            .pointer => |p| break :blk switch (p.size) {
                .one => switch (@typeInfo(p.child)) {
                    .array => |a| @as([]const a.child, list),
                    else => @compileError("Expected pointer to array"),
                },
                .slice => list,
                else => @compileError("Expected slice or pointer to array"),
            },
            .array => list[0..],
            else => @compileError("Expected ArrayList, Array, or Slice"),
        };
    };

    // 2. Extract the element type T from the slice
    const SliceType = @TypeOf(items);
    const T = std.meta.Child(SliceType);

    // Compile-time check: verify t can be compared with T (optional strictness)
    comptime {
        const info = @typeInfo(T);

        const is_supported_builtin = switch (info) {
            .int, .float, .bool, .@"enum" => true,
            .array => true,
            .pointer => |p| p.size == .slice,
            else => false,
        };

        if (!is_supported_builtin) {
            const has_eql = @hasDecl(T, "eql");

            if (!has_eql) {
                @compileError("T must either provide an 'eql(a,b) bool' method or be a supported built-in comparable type (int/float/bool/enum/slice)");
            }
        }
    }

    // 3. Runtime iteration — dispatch comparison strategy based on T
    for (items) |item| {
        if (itemEql(T, item, t)) return true;
    }

    return false;
}

/// Inline helper that selects the appropriate equality comparison strategy
/// for the given element type T.
inline fn itemEql(comptime T: type, a: T, b: anytype) bool {
    const info = @typeInfo(T);
    const can_have_decls = switch (info) {
        .@"struct", .@"enum", .@"union", .@"opaque" => true,
        else => false,
    };

    // If type provides custom .eql() method, use it
    if (can_have_decls and @hasDecl(T, "eql")) return T.eql(a, b);

    // Otherwise fall back to standard equality strategies
    return switch (info) {
        .int, .float, .bool, .@"enum" => a == b,
        .array => std.mem.eql(std.meta.Child(T), &a, &b),
        .pointer => |p| if (p.size == .slice or p.size == .many)
            std.mem.eql(p.child, a, b)
        else
            a == b,
        else => @compileError("Unsupported type T for comparison: " ++ @typeName(T)),
    };
}
