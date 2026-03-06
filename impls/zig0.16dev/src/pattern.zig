const std = @import("std");
const testing = std.testing;

const regex = @import("pcrez");

test "verify mal reg_exp" {
    const mal_reg_exp_pattern =
        \\[\s,]*(~@|[\[\]{}()'`~^@]|"(?:\\.|[^\\"])*"?|;.*|[^\s\[\]{}('"`,;)]*)
    ;

    var re = regex.Regex.from(mal_reg_exp_pattern, true, testing.allocator) catch |err| {
        std.debug.print("Failed to compile pattern '{s}': {s}\n", .{ "mal_reg_exp", mal_reg_exp_pattern });
        return err;
    };
    defer re.deinit();

    const text =
        \\(def! my-list [1 2, "hello \"world\"", ~@splice-me]) ; 这是一个注释
        \\{ :a 123 :b 'quoted `(a b ~c) @atom } ,,, ,
    ;

    const matches = re.searchAll(text, 0, -1);
    defer {
        for (0..matches.items.len) |i| {
            matches.items[i].deinit();
        }
        matches.deinit();
    }

    const Expected = struct {
        fs: usize,
        fe: usize,
        full: []const u8,
        cs: usize,
        ce: usize,
        capture: []const u8,
    };
    const expected = [_]Expected{
        .{ .fs = 0, .fe = 1, .full = "(", .cs = 0, .ce = 1, .capture = "(" },
        .{ .fs = 1, .fe = 5, .full = "def!", .cs = 1, .ce = 5, .capture = "def!" },
        .{ .fs = 5, .fe = 13, .full = " my-list", .cs = 6, .ce = 13, .capture = "my-list" },
        .{ .fs = 13, .fe = 15, .full = " [", .cs = 14, .ce = 15, .capture = "[" },
        .{ .fs = 15, .fe = 16, .full = "1", .cs = 15, .ce = 16, .capture = "1" },
        .{ .fs = 16, .fe = 18, .full = " 2", .cs = 17, .ce = 18, .capture = "2" },
        .{ .fs = 18, .fe = 37, .full = ", \"hello \\\"world\\\"\"", .cs = 20, .ce = 37, .capture = "\"hello \\\"world\\\"\"" },
        .{ .fs = 37, .fe = 41, .full = ", ~@", .cs = 39, .ce = 41, .capture = "~@" },
        .{ .fs = 41, .fe = 50, .full = "splice-me", .cs = 41, .ce = 50, .capture = "splice-me" },
        .{ .fs = 50, .fe = 51, .full = "]", .cs = 50, .ce = 51, .capture = "]" },
        .{ .fs = 51, .fe = 52, .full = ")", .cs = 51, .ce = 52, .capture = ")" },
        .{ .fs = 52, .fe = 73, .full = " ; 这是一个注释", .cs = 53, .ce = 73, .capture = "; 这是一个注释" },
        .{ .fs = 73, .fe = 75, .full = "\n{", .cs = 74, .ce = 75, .capture = "{" },
        .{ .fs = 75, .fe = 78, .full = " :a", .cs = 76, .ce = 78, .capture = ":a" },
        .{ .fs = 78, .fe = 82, .full = " 123", .cs = 79, .ce = 82, .capture = "123" },
        .{ .fs = 82, .fe = 85, .full = " :b", .cs = 83, .ce = 85, .capture = ":b" },
        .{ .fs = 85, .fe = 87, .full = " '", .cs = 86, .ce = 87, .capture = "'" },
        .{ .fs = 87, .fe = 93, .full = "quoted", .cs = 87, .ce = 93, .capture = "quoted" },
        .{ .fs = 93, .fe = 95, .full = " `", .cs = 94, .ce = 95, .capture = "`" },
        .{ .fs = 95, .fe = 96, .full = "(", .cs = 95, .ce = 96, .capture = "(" },
        .{ .fs = 96, .fe = 97, .full = "a", .cs = 96, .ce = 97, .capture = "a" },
        .{ .fs = 97, .fe = 99, .full = " b", .cs = 98, .ce = 99, .capture = "b" },
        .{ .fs = 99, .fe = 101, .full = " ~", .cs = 100, .ce = 101, .capture = "~" },
        .{ .fs = 101, .fe = 102, .full = "c", .cs = 101, .ce = 102, .capture = "c" },
        .{ .fs = 102, .fe = 103, .full = ")", .cs = 102, .ce = 103, .capture = ")" },
        .{ .fs = 103, .fe = 105, .full = " @", .cs = 104, .ce = 105, .capture = "@" },
        .{ .fs = 105, .fe = 109, .full = "atom", .cs = 105, .ce = 109, .capture = "atom" },
        .{ .fs = 109, .fe = 111, .full = " }", .cs = 110, .ce = 111, .capture = "}" },
        .{ .fs = 111, .fe = 117, .full = " ,,, ,", .cs = 117, .ce = 117, .capture = "" },
        .{ .fs = 117, .fe = 117, .full = "", .cs = 117, .ce = 117, .capture = "" },
    };

    try testing.expectEqual(expected.len, matches.items.len);

    for (expected, 0..) |exp, i| {
        const m = matches.items[i];
        try testing.expectEqual(@as(usize, 2), m.data.items.len);

        try testing.expectEqual(@as(?usize, exp.fs), m.data.items[0].start);
        try testing.expectEqual(@as(?usize, exp.fe), m.data.items[0].end);
        try testing.expectEqualStrings(exp.full, text[exp.fs..exp.fe]);

        try testing.expectEqual(@as(?usize, exp.cs), m.data.items[1].start);
        try testing.expectEqual(@as(?usize, exp.ce), m.data.items[1].end);
        try testing.expectEqualStrings(exp.capture, text[exp.cs..exp.ce]);
    }
}
