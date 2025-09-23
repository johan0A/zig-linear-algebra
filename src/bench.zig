const std = @import("std");
const zbench = @import("zbench");
const zla = @import("zla");

fn benchmark_multiply(comptime size: usize) type {
    return struct {
        const Matrix512 = zla.Mat(f32, size, size);
        a: Matrix512,
        b: Matrix512,

        fn init() @This() {
            var input: Matrix512 = undefined;
            for (&input.items, 0..) |*row, i| {
                for (row, 0..) |*col, j| {
                    col.* = @floatFromInt(i * size + j);
                }
            }
            return .{
                .a = input,
                .b = input,
            };
        }

        pub fn run(self: @This(), _: std.mem.Allocator) void {
            std.mem.doNotOptimizeAway(@call(.never_inline, Matrix512.mul, .{ self.a, self.b }));
        }
    };
}

fn bench_sin_cos_fused(comptime size: usize) type {
    return struct {
        angles: @Vector(size, f32),

        fn init() @This() {
            var val: [size]f32 = undefined;
            for (0..size) |k| {
                val[k] = @as(f32, @floatFromInt(k)) * 0.01;
            }
            return .{ .angles = val };
        }

        pub fn run(self: @This(), _: std.mem.Allocator) void {
           std.mem.doNotOptimizeAway(@call(.never_inline, zla.vec.sin_cos, .{self.angles}));
        }
    };
}

fn benchmark_sin_cos_system(comptime size: usize) type {
    return struct {
        angles: [size]f32,

        fn init() @This() {
            var val: [size]f32 = undefined;
            for (0..size) |k| {
                val[k] = @as(f32, @floatFromInt(k)) * 0.01;
            }
            return .{ .angles = val };
        }

        pub fn run(self: @This(), _: std.mem.Allocator) void {
            var sin_val: [size]f32 = undefined;
            var cos_val: [size]f32 = undefined;
            for(self.angles, 0..) |angle, i| {
                sin_val[i] = std.math.sin(angle);
                cos_val[i] = std.math.cos(angle);
            }
            std.mem.doNotOptimizeAway(sin_val);
            std.mem.doNotOptimizeAway(cos_val);
        }
    };
}

pub fn main() !void {
    var stdout = std.fs.File.stdout().writerStreaming(&.{});
    const writer = &stdout.interface;

    var bench = zbench.Benchmark.init(std.heap.page_allocator, .{});
    defer bench.deinit();

    try bench.addParam("Multiple 4x4 matrix multiplication", &benchmark_multiply(4).init(), .{
        .iterations = 256,
    });
    try bench.addParam("Multiple 512x512 matrix multiplication", &benchmark_multiply(512).init(), .{
        .iterations = 256,
    });
    try bench.addParam("Sin/Cos", &benchmark_sin_cos_system(256).init(), .{
        .iterations = 256,
    });
    try bench.addParam("Sin/Cos vectorized", &bench_sin_cos_fused(256).init(), .{
        .iterations = 256,
    });

    try writer.writeAll("\n");
    try bench.run(writer);
}
