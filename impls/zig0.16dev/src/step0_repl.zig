const std = @import("std");

const rl = @import("readline.zig");

fn READ(x: []const u8) []const u8 {
    return x;
}

fn EVAL(x: []const u8) []const u8 {
    return x;
}

fn PRINT(x: []const u8) []const u8 {
    return x;
}

fn rep(x: []const u8) []const u8 {
    PRINT(EVAL(READ(x)));
}

const prompt = "user> ";

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    try stdout_writer.flush();

    while (true) {
        if (try rl.readline(prompt)) |input| {
            if (std.mem.eql(u8, input, "(exit)")) break;
            try stdout_writer.writeAll(input);
            try stdout_writer.writeAll("\n");
            try stdout_writer.flush();
        }
    }
}
