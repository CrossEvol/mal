const std = @import("std");

pub fn build(b: *std.Build) void {
    const name = b.option([]const u8, "name", "step name (without .zig)") orelse "stepA_mal";
    const source = b.option([]const u8, "source", "step name (with .zig)") orelse "stepA_mal.zig";

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const pcrez_dep = b.dependency("pcrez", .{
        .target = target,
        .optimize = optimize,
    });
    const pcrez_mod = pcrez_dep.module("pcrez");

    const mod = b.addModule("zig0_16dev", .{
        .root_source_file = b.path("src/root.zig"),

        .target = target,
    });

    build_main(b, target, optimize, mod, pcrez_mod);
    build_step(b, target, optimize, mod, pcrez_mod, name, source);
}

fn build_main(
    b: *std.Build,
    target: ?std.Build.ResolvedTarget,
    optimize: ?std.builtin.OptimizeMode,
    mod: *std.Build.Module,
    pcrez_mod: *std.Build.Module,
) void {
    const exe = b.addExecutable(.{
        .name = "zig0_16dev",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),

            .target = target,
            .optimize = optimize,
            .link_libc = true,

            .imports = &.{
                .{ .name = "zig0_16dev", .module = mod },
                .{ .name = "pcrez", .module = pcrez_mod },
            },
        }),
    });
    exe.root_module.addCSourceFile(.{
        .file = b.path("libs/linenoise/linenoise.c"),
        .flags = &[_][]const u8{ "-Wall", "-Werror" },
    });
    exe.root_module.addIncludePath(b.path("libs/linenoise"));

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}

fn build_step(
    b: *std.Build,
    target: ?std.Build.ResolvedTarget,
    optimize: ?std.builtin.OptimizeMode,
    mod: *std.Build.Module,
    pcrez_mod: *std.Build.Module,
    name: []const u8,
    root_source_file: []const u8,
) void {
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_source_file),

            .target = target,
            .optimize = optimize,
            .link_libc = true,

            .imports = &.{
                .{ .name = "zig0_16dev", .module = mod },
                .{ .name = "pcrez", .module = pcrez_mod },
            },
        }),
    });
    exe.root_module.addCSourceFile(.{
        .file = b.path("libs/linenoise/linenoise.c"),
        .flags = &[_][]const u8{ "-Wall", "-Werror" },
    });
    exe.root_module.addIncludePath(b.path("libs/linenoise"));

    b.installArtifact(exe);

    const run_step = b.step(name, "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("step0_repl_test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
