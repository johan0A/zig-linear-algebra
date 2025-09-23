const std = @import("std");
const zbench = @import("zbench");
const zla = @import("zla");

fn bubbleSort(nums: []i32) void {
    var i: usize = nums.len - 1;
    while (i > 0) : (i -= 1) {
        var j: usize = 0;
        while (j < i) : (j += 1) {
            if (nums[j] > nums[j + 1]) {
                std.mem.swap(i32, &nums[j], &nums[j + 1]);
            }
        }
    }
}

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

fn myBenchmark(_: std.mem.Allocator) void {
    var numbers = [_]i32{ 4, 1, 3, 1, 5, 2 };
    _ = bubbleSort(&numbers);
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

    try writer.writeAll("\n");
    try bench.run(writer);
}
