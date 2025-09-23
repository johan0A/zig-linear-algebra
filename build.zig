const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const root_module = b.addModule("zla", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    {
        const tests = b.addTest(.{ .name = "test", .root_module = root_module });
        const run_tests = b.addRunArtifact(tests);
        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&run_tests.step);
    }
    
    {
        const zbench_module = b.dependency("zbench", .{
            .target = target,
            .optimize = optimize,
        });
        const bench = b.addExecutable(.{
            .name = "bench",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/bench.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{ 
                    .{ .name = "zla", .module = root_module },
                    .{ .name = "zbench", .module = zbench_module.module("zbench")}
                },
            }),
        });
        const bench_step = b.step("bench", "run benchmark");
        const bench_cmd = b.addRunArtifact(bench);
        bench_step.dependOn(&bench_cmd.step);
    }

}
