const std = @import("std");

const MalError = @import("error.zig").MalError;
const MalType = @import("types.zig").MalType;

pub fn pr_str(allocator: std.mem.Allocator, data: MalType, print_readably: bool) ![]const u8 {
    return switch (data) {
        .symbol => |s| s.value,
        .int => |i| try std.fmt.allocPrint(
            allocator,
            "{d}",
            .{i.value},
        ),
        .iterable => |it| switch (it) {
            .list => |l| {
                var printedElements = try std.ArrayList(u8).initCapacity(allocator, l.length() * 2);
                errdefer printedElements.deinit(allocator);

                for (0..l.length()) |i| {
                    const item = l.get(i);
                    switch (item) {
                        .exception => return pr_str(allocator, item, print_readably),
                        else => {},
                    }
                    try printedElements.appendSlice(allocator, try pr_str(allocator, l.get(i), print_readably));
                    if (i != l.length() - 1) {
                        try printedElements.append(allocator, ' ');
                    }
                }

                return try std.fmt.allocPrint(
                    allocator,
                    "({s})",
                    .{try printedElements.toOwnedSlice(allocator)},
                );
            },
            .vector => |v| {
                var printedElements = try std.ArrayList(u8).initCapacity(allocator, v.length() * 2);
                errdefer printedElements.deinit(allocator);

                for (0..v.length()) |i| {
                    try printedElements.appendSlice(allocator, try pr_str(allocator, v.get(i), print_readably));
                    if (i != v.length() - 1) {
                        try printedElements.append(allocator, ' ');
                    }
                }

                return try std.fmt.allocPrint(
                    allocator,
                    "[{s}]",
                    .{try printedElements.toOwnedSlice(allocator)},
                );
            },
            .nil => "nil",
        },
        .hashmap => |hm| {
            var printedElements = try std.ArrayList(u8).initCapacity(allocator, 32);
            errdefer printedElements.deinit(allocator);

            var i: usize = 0;
            const size = hm.value.count();
            var iter = hm.value.iterator();
            while (iter.next()) |entry| {
                i += 1;
                try printedElements.appendSlice(allocator, try pr_str(allocator, entry.key_ptr.*, print_readably));
                try printedElements.append(allocator, ' ');
                try printedElements.appendSlice(allocator, try pr_str(allocator, entry.value_ptr.*, print_readably));
                if (i < size) {
                    try printedElements.append(allocator, ' ');
                }
            }

            return try std.fmt.allocPrint(
                allocator,
                "{{{s}}}",
                .{try printedElements.toOwnedSlice(allocator)},
            );
        },
        .string => |s| if (print_readably) {
            var readable_value = try std.ArrayList(u8).initCapacity(allocator, s.value.len);
            errdefer readable_value.deinit(allocator);

            try readable_value.append(allocator, '"');
            for (s.value) |c| {
                if (c == '\\') {
                    try readable_value.append(allocator, '\\');
                    try readable_value.append(allocator, '\\');
                } else if (c == '\n') {
                    try readable_value.append(allocator, '\\');
                    try readable_value.append(allocator, 'n');
                } else if (c == '"') {
                    try readable_value.append(allocator, '\\');
                    try readable_value.append(allocator, '"');
                } else {
                    try readable_value.append(allocator, c);
                }
            }
            try readable_value.append(allocator, '"');

            return readable_value.toOwnedSlice(allocator);
        } else s.value,
        .keyword => |kw| try std.fmt.allocPrint(
            allocator,
            ":{s}",
            .{kw.value},
        ),
        .bool => |b| if (b.value) "true" else "false",
        .callable => |c| switch (c.*) {
            .builtin => "#<built in function>",
            .closure => "#<function>",
        },
        .atom => |a| try std.fmt.allocPrint(
            allocator,
            "(atom {s})",
            .{try pr_str(allocator, a.value, print_readably)},
        ),
        .exception => |exp| {
            return try std.fmt.allocPrint(allocator,
                \\"{s}"
            , .{exp.value.string.value});
        },
    };
}
