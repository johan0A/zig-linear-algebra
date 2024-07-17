const std = @import("std");

const Vec = @import("module.zig").Vec;

test "benchmark cross" {
    const Vec2 = Vec(f32, 3);
    const v1 = Vec2{ .values = .{ 1.0, 2.0, 3.0 } };
    const v2 = Vec2{ .values = .{ 4.0, 5.0, 6.0 } };

    var timer = try std.time.Timer.start();

    const n = 10000000;
    for (0..n) |_| {
        std.mem.doNotOptimizeAway(@call(.never_inline, Vec2.cross, .{ v1, v2 }));
    }

    const elapsed = timer.read();
    std.debug.print("cross benchmark:\n", .{});
    std.debug.print("time per operation: {d}\n", .{
        @as(f64, @floatFromInt(elapsed)) / n,
    });
}

test "benchmark distance" {
    const Vec2 = Vec(f32, 3);
    const v1 = Vec2{ .values = .{ 1.0, 2.0, 3.0 } };
    const v2 = Vec2{ .values = .{ 4.0, 5.0, 6.0 } };

    var timer = try std.time.Timer.start();

    const n = 10000000;
    for (0..n) |_| {
        std.mem.doNotOptimizeAway(@call(.never_inline, Vec2.distance, .{ v1, v2 }));
    }

    const elapsed = timer.read();
    std.debug.print("distance benchmark:\n", .{});
    std.debug.print("time per operation: {d}\n", .{
        @as(f64, @floatFromInt(elapsed)) / n,
    });
}

test "benchmark normalize" {
    const Vec2 = Vec(f32, 3);
    const v1 = Vec2{ .values = .{ 1.0, 2.0, 3.0 } };

    var timer = try std.time.Timer.start();

    const n = 10000000;
    for (0..n) |_| {
        std.mem.doNotOptimizeAway(@call(.never_inline, Vec2.normalize, .{v1}));
    }
    const elapsed = timer.read();
    std.debug.print("normalize benchmark:\n", .{});
    std.debug.print("time per operation: {d}\n", .{
        @as(f64, @floatFromInt(elapsed)) / n,
    });
}

test "sum benchmark" {
    const Vec2 = Vec(f32, 3);
    const v1 = Vec2{ .values = .{ 1.0, 2.0, 3.0 } };

    var timer = try std.time.Timer.start();

    const n = 10000000;
    for (0..n) |_| {
        std.mem.doNotOptimizeAway(@call(.never_inline, Vec2.sum, .{v1}));
    }

    const elapsed = timer.read();
    std.debug.print("sum benchmark:\n", .{});
    std.debug.print("time per operation: {d}\n", .{
        @as(f64, @floatFromInt(elapsed)) / n,
    });
}
