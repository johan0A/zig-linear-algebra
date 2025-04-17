const std = @import("std");

const module = @import("module.zig");
const Vec = module.Vec;
const Matrix = module.Mat;

test "benchmark cross" {
    const Vec2 = Vec(3, f32);
    const v1 = Vec2.init(.{ 1, 2, 3 });
    const v2 = Vec2.init(.{ 4, 5, 6 });

    var timer = try std.time.Timer.start();

    const n = 10000000;
    for (0..n) |_| {
        std.mem.doNotOptimizeAway(@call(.never_inline, Vec2.cross, .{ v1, v2 }));
    }

    const elapsed = timer.read();
    std.debug.print("cross benchmark:\n", .{});
    std.debug.print("operation: (1.0, 2.0, 3.0).cross((4.0, 5.0, 6.0))\n", .{});
    std.debug.print("time per operation: {d}\n", .{
        @as(f64, @floatFromInt(elapsed)) / n,
    });
}

test "benchmark distance" {
    const Vec2 = Vec(3, f32);
    const v1 = Vec2.init(.{ 1, 2, 3 });
    const v2 = Vec2.init(.{ 4, 5, 6 });

    var timer = try std.time.Timer.start();

    const n = 10000000;
    for (0..n) |_| {
        std.mem.doNotOptimizeAway(@call(.never_inline, Vec2.distance, .{ v1, v2 }));
    }

    const elapsed = timer.read();
    std.debug.print("--------------------------------\n", .{});
    std.debug.print("distance benchmark:\n", .{});
    std.debug.print("operation: (1.0, 2.0, 3.0).distance((4.0, 5.0, 6.0))\n", .{});
    std.debug.print("time per operation: {d}\n", .{
        @as(f64, @floatFromInt(elapsed)) / n,
    });
}

test "benchmark normalize" {
    const Vec2 = Vec(3, f32);
    const v1 = Vec2.init(.{ 1, 2, 3 });

    var timer = try std.time.Timer.start();

    const n = 10000000;
    for (0..n) |_| {
        std.mem.doNotOptimizeAway(@call(.never_inline, Vec2.normalize, .{v1}));
    }
    const elapsed = timer.read();
    std.debug.print("--------------------------------\n", .{});
    std.debug.print("normalize benchmark:\n", .{});
    std.debug.print("operation: (1.0, 2.0, 3.0).normalize()\n", .{});
    std.debug.print("time per operation: {d} ns\n", .{
        @as(f64, @floatFromInt(elapsed)) / n,
    });
}

test "sum benchmark" {
    const Vec2 = Vec(3, f32);
    const v1 = Vec2.init(.{ 1, 2, 3 });

    var timer = try std.time.Timer.start();

    const n = 10000000;
    for (0..n) |_| {
        std.mem.doNotOptimizeAway(@call(.never_inline, Vec2.sum, .{v1}));
    }

    const elapsed = timer.read();
    std.debug.print("--------------------------------\n", .{});
    std.debug.print("sum benchmark:\n", .{});
    std.debug.print("operation: (1.0, 2.0, 3.0).sum()\n", .{});
    std.debug.print("time per operation: {d} ns\n", .{
        @as(f64, @floatFromInt(elapsed)) / n,
    });
}

test "benchmark matrix multiplication 256x256 * 256x256" {
    const size = 256;
    const Matrix512 = Matrix(f32, size, size);
    const a = matrixMaker(size, size, 1);
    const b = matrixMaker(size, size, 1);

    var timer = try std.time.Timer.start();

    const n = 10;
    for (0..n) |_| {
        std.mem.doNotOptimizeAway(@call(.never_inline, Matrix512.mul, .{ a, b }));
    }

    const elapsed = timer.read();
    std.debug.print("--------------------------------\n", .{});
    std.debug.print("matrix multiplication benchmark:\n", .{});
    std.debug.print("operation: 256x256 * 256x256 matrix multiplication\n", .{});
    std.debug.print("time per operation: {d} ns\n", .{
        @as(f64, @floatFromInt(elapsed)) / n,
    });
    std.debug.print("time per operation: {d} ms\n", .{
        @as(f64, @floatFromInt(elapsed)) / n / 1000000,
    });
}

test "benchmark matrix multiplication 8x8 * 8x8" {
    const size = 8;
    const Matrix8 = Matrix(f32, size, size);
    const a = matrixMaker(size, size, 1);
    const b = matrixMaker(size, size, 1);

    var timer = try std.time.Timer.start();

    const n = 10;
    for (0..n) |_| {
        std.mem.doNotOptimizeAway(@call(.never_inline, Matrix8.mul, .{ a, b }));
    }

    const elapsed = timer.read();
    std.debug.print("--------------------------------\n", .{});
    std.debug.print("matrix multiplication benchmark:\n", .{});
    std.debug.print("operation: 8x8 * 8x8 matrix multiplication\n", .{});
    std.debug.print("time per operation: {d} ns\n", .{
        @as(f64, @floatFromInt(elapsed)) / n,
    });
    std.debug.print("time per operation: {d} ms\n", .{
        @as(f64, @floatFromInt(elapsed)) / n / 1000000,
    });
}

test "benchmark matrix multiplication 4x4 * 4x4" {
    const Mat4 = Matrix(f32, 4, 4);

    const n = 1e4;
    const nn = 1e4;

    const as = try std.testing.allocator.alloc(Mat4, n);
    defer std.testing.allocator.free(as);
    for (as, 0..) |*item, i| item.* = matrixMaker(4, 4, i);
    const bs = try std.testing.allocator.alloc(Mat4, n);
    defer std.testing.allocator.free(bs);
    for (bs, 0..) |*item, i| item.* = matrixMaker(4, 4, i);

    var timer = try std.time.Timer.start();

    for (0..nn) |_| {
        for (as, bs) |*a, b| {
            a.* = @call(.always_inline, Mat4.mul, .{ a.*, b });
        }
    }

    const elapsed = timer.read();
    std.debug.print("--------------------------------\n", .{});
    std.debug.print("matrix multiplication benchmark:\n", .{});
    std.debug.print("operation: 4x4 * 4x4 matrix multiplication\n", .{});
    std.debug.print("time per operation: {d} ns\n", .{
        @as(f64, @floatFromInt(elapsed)) / (n * nn),
    });
}

test "benchmark matrix multiplication 3x3 * 3x3" {
    const Mat3 = Matrix(f32, 3, 3);

    const n = 1e4;
    const nn = 1e4;

    const as = try std.testing.allocator.alloc(Mat3, n);
    defer std.testing.allocator.free(as);
    for (as, 0..) |*item, i| item.* = matrixMaker(3, 3, i);
    const bs = try std.testing.allocator.alloc(Mat3, n);
    defer std.testing.allocator.free(bs);
    for (bs, 0..) |*item, i| item.* = matrixMaker(3, 3, i);

    var timer = try std.time.Timer.start();

    for (0..nn) |_| {
        for (as, bs) |*a, b| {
            a.* = @call(.always_inline, Mat3.mul, .{ a.*, b });
        }
    }

    const elapsed = timer.read();
    std.debug.print("--------------------------------\n", .{});
    std.debug.print("matrix multiplication benchmark:\n", .{});
    std.debug.print("operation: 3x3 * 3x3 matrix multiplication\n", .{});
    std.debug.print("time per operation: {d} ns\n", .{
        @as(f64, @floatFromInt(elapsed)) / (n * nn),
    });
}

test "benchmark matrix multiplication 2x2 * 2x2" {
    const Mat2 = Matrix(f32, 2, 2);

    const n = 1e4;
    const nn = 1e4;

    const as = try std.testing.allocator.alloc(Mat2, n);
    defer std.testing.allocator.free(as);
    for (as, 0..) |*item, i| item.* = matrixMaker(2, 2, i);
    const bs = try std.testing.allocator.alloc(Mat2, n);
    defer std.testing.allocator.free(bs);
    for (bs, 0..) |*item, i| item.* = matrixMaker(2, 2, i);

    var timer = try std.time.Timer.start();

    for (0..nn) |_| {
        for (as, bs) |*a, b| {
            a.* = @call(.always_inline, Mat2.mul, .{ a.*, b });
        }
    }

    const elapsed = timer.read();
    std.debug.print("--------------------------------\n", .{});
    std.debug.print("matrix multiplication benchmark:\n", .{});
    std.debug.print("operation: 2x2 * 2x2 matrix multiplication\n", .{});
    std.debug.print("time per operation: {d} ns\n", .{
        @as(f64, @floatFromInt(elapsed)) / (n * nn),
    });
}

fn matrixMaker(comptime rows: usize, comptime cols: usize, added: usize) Matrix(f32, rows, cols) {
    var result = Matrix(f32, rows, cols).init(undefined);
    for (&result.items, 0..) |*row, i| {
        for (row, 0..) |*col, j| {
            col.* = @floatFromInt(i * cols + j + added);
        }
    }
    return result;
}
