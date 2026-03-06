const std = @import("std");
const Io = std.Io;

const MalError = @import("error.zig").MalError;
const MalType = @import("types.zig").MalType;
const printer = @import("printer.zig");
const reader = @import("reader.zig");
const rl = @import("readline.zig");

fn READ(allocator: std.mem.Allocator, x: []const u8) !MalType {
    return try reader.read_str(allocator, x);
}

fn EVAL(x: MalType) MalType {
    return x;
}

fn PRINT(allocator: std.mem.Allocator, x: MalType) ![]const u8 {
    return try printer.pr_str(allocator, x, true);
}

fn rep(allocator: std.mem.Allocator, x: []const u8) ![]const u8 {
    return try PRINT(allocator, EVAL(try READ(allocator, x)));
}

const prompt = "user> ";

pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();
    const io = init.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

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
