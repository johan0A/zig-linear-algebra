const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    {
        _ = b.addModule("linear-algebra-types", .{
            .root_source_file = b.path("src/module.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
    }

    {
        const module_unit_tests = b.addTest(.{
            .root_source_file = b.path("src/module.zig"),
            .target = target,
            .optimize = optimize,
        });
        const run_lib_unit_tests = b.addRunArtifact(module_unit_tests);

        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&run_lib_unit_tests.step);
    }

    {
        const module_benchmark = b.addTest(.{
            .root_source_file = b.path("src/benchmark.zig"),
            .target = target,
            .optimize = optimize,
        });
        const run_lib_unit_tests = b.addRunArtifact(module_benchmark);
        run_lib_unit_tests.has_side_effects = true;

        const test_step = b.step("benchmark", "Run benchmarks");
        test_step.dependOn(&run_lib_unit_tests.step);
    }
}