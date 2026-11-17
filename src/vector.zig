const std = @import("std");

fn arrayInfo(comptime V: type) std.builtin.Type.Array {
    const info = @typeInfo(V);
    if (info != .array) @compileError("expected array type, got: " ++ @typeName(V));
    return info.array;
}

fn Simd(comptime V: type) type {
    const info = arrayInfo(V);
    return @Vector(info.len, info.child);
}

inline fn simd(v: anytype) Simd(@TypeOf(v)) {
    return v;
}

fn OutFloat(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .float => T,
        .int => if (@bitSizeOf(T) <= 32) f32 else f64,
        else => @compileError("expected int or float element type, got: " ++ @typeName(T)),
    };
}

fn CalcFloat(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .float => T,
        .int => f64,
        else => @compileError("expected int or float element type, got: " ++ @typeName(T)),
    };
}

fn calc(v: anytype) @Vector(arrayInfo(@TypeOf(v)).len, CalcFloat(std.meta.Child(@TypeOf(v)))) {
    return simd(cast(CalcFloat(std.meta.Child(@TypeOf(v))), v));
}

/// Float to int conversion truncates and is illegal behavior if the value does not fit.
pub fn cast(comptime T: type, v: anytype) [arrayInfo(@TypeOf(v)).len]T {
    const S = std.meta.Child(@TypeOf(v));
    const s = simd(v);
    const R = @Vector(arrayInfo(@TypeOf(v)).len, T);
    const r: R = switch (@typeInfo(T)) {
        .float => switch (@typeInfo(S)) {
            .float => @floatCast(s),
            .int => @floatFromInt(s),
            else => @compileError("expected int or float element type, got: " ++ @typeName(S)),
        },
        .int => switch (@typeInfo(S)) {
            .float => @intFromFloat(s),
            .int => @intCast(s),
            else => @compileError("expected int or float element type, got: " ++ @typeName(S)),
        },
        else => @compileError("expected int or float target type, got: " ++ @typeName(T)),
    };
    return r;
}

/// Returns a new vector with the components swizzled.
///
/// example:
/// ```
/// const v: [2]f32 = .{ 1, 2 };
/// const v2 = swizzle(v, "yx"); // <= here x and y are swapped
/// ```
/// v2 is equal to `[2]f32{ 2, 1 }`
///
/// this is also valid:
/// ```
/// const v: [4]f32 = .{ 1, 2, 3, 4 };
/// const v2 = swizzle(v, "wxx");
/// ```
/// here v2 is equal to `[3]f32{ 4, 1, 1 }`
pub fn swizzle(v: anytype, comptime components: []const u8) [components.len]std.meta.Child(@TypeOf(v)) {
    const len = arrayInfo(@TypeOf(v)).len;
    const T = std.meta.Child(@TypeOf(v));

    comptime var mask: [components.len]i32 = undefined;
    inline for (components, 0..) |c, i| {
        mask[i] = switch (c) {
            'x' => 0,
            'y' => 1,
            'z' => 2,
            'w' => 3,
            else => @compileError("swizzle: invalid component '" ++ [_]u8{c} ++ "'"),
        };
        if (mask[i] >= len) @compileError("swizzle: component '" ++ [_]u8{c} ++ "' out of range for vector of this length");
    }

    return @shuffle(T, simd(v), @as(@Vector(1, T), undefined), mask);
}

pub fn add(v: anytype, other: @TypeOf(v)) @TypeOf(v) {
    return simd(v) + simd(other);
}

pub fn sub(v: anytype, other: @TypeOf(v)) @TypeOf(v) {
    return simd(v) - simd(other);
}

pub fn scale(v: anytype, value: std.meta.Child(@TypeOf(v))) @TypeOf(v) {
    return simd(v) * @as(Simd(@TypeOf(v)), @splat(value));
}

/// dot product of two vectors.
pub fn dot(v: anytype, other: @TypeOf(v)) std.meta.Child(@TypeOf(v)) {
    return @reduce(.Add, simd(v) * simd(other));
}

/// Returns the cross product of two vectors.
pub fn cross(v: anytype, other: @TypeOf(v)) @TypeOf(v) {
    if (arrayInfo(@TypeOf(v)).len != 3) @compileError("vector must have three elements for cross() to be defined");
    const T = std.meta.Child(@TypeOf(v));
    const a = simd(v);
    const b = simd(other);

    const a1 = @shuffle(T, a, a, [3]i32{ 1, 2, 0 });
    const a2 = @shuffle(T, a, a, [3]i32{ 2, 0, 1 });
    const b1 = @shuffle(T, b, b, [3]i32{ 1, 2, 0 });
    const b2 = @shuffle(T, b, b, [3]i32{ 2, 0, 1 });

    return a1 * b2 - a2 * b1;
}

/// Returns the squared norm of the vector, i.e. `dot(v, v)`.
pub fn normSqr(v: anytype) std.meta.Child(@TypeOf(v)) {
    return dot(v, v);
}

/// Returns the norm (length) of the vector.
/// For float vectors the output type is the element type, for int vectors it is f32 (<= 32 bits) or f64.
pub fn norm(v: anytype) OutFloat(std.meta.Child(@TypeOf(v))) {
    const f = calc(v);
    return @floatCast(@sqrt(@reduce(.Add, f * f)));
}

/// Assume vector is not zero.
pub fn normalize(v: anytype) @TypeOf(v) {
    const T = std.meta.Child(@TypeOf(v));
    if (@typeInfo(T) != .float) @compileError("normalize requires a float vector, got: " ++ @typeName(@TypeOf(v)));
    const s = simd(v);
    return s / @as(Simd(@TypeOf(v)), @splat(@sqrt(@reduce(.Add, s * s))));
}

/// Returns the distance between two vectors.
/// Output type and int handling are the same as `norm`.
pub fn distance(v: anytype, other: @TypeOf(v)) OutFloat(std.meta.Child(@TypeOf(v))) {
    const d = calc(v) - calc(other);
    return @floatCast(@sqrt(@reduce(.Add, d * d)));
}

/// Returns the angle between two vectors in radians, in the range [0, pi].
/// Output type is the same as `norm`. Returns 0 if either vector is zero.
pub fn angle(v: anytype, other: @TypeOf(v)) OutFloat(std.meta.Child(@TypeOf(v))) {
    const F = CalcFloat(std.meta.Child(@TypeOf(v)));
    const S = @Vector(arrayInfo(@TypeOf(v)).len, F);
    const a = calc(v);
    const b = calc(other);
    const na: S = @splat(@sqrt(@reduce(.Add, a * a)));
    const nb: S = @splat(@sqrt(@reduce(.Add, b * b)));
    const x = a * nb - b * na;
    const y = a * nb + b * na;
    return @floatCast(2 * std.math.atan2(@sqrt(@reduce(.Add, x * x)), @sqrt(@reduce(.Add, y * y))));
}

/// Returns a new vector that is the reflection of the original vector on the given normal.
/// assumes `normal` is normalized.
pub fn reflect(v: anytype, normal: @TypeOf(v)) @TypeOf(v) {
    const S = Simd(@TypeOf(v));
    const n = simd(normal);
    return simd(v) - n * @as(S, @splat(2 * dot(v, normal)));
}

test add {
    const a: [3]f32 = .{ 1, 2, 3 };
    try std.testing.expectEqual([3]f32{ 5, 7, 9 }, add(a, .{ 4, 5, 6 }));
    const b: [2]i32 = .{ 1, -2 };
    try std.testing.expectEqual([2]i32{ 4, -6 }, add(b, .{ 3, -4 }));
}

test sub {
    const a: [3]f32 = .{ 1, 2, 3 };
    try std.testing.expectEqual([3]f32{ -3, -3, -3 }, sub(a, .{ 4, 5, 6 }));
    const b: [2]u8 = .{ 5, 7 };
    try std.testing.expectEqual([2]u8{ 2, 3 }, sub(b, .{ 3, 4 }));
}

test scale {
    const v: [2]f32 = .{ 1, 2 };
    try std.testing.expectEqual([2]f32{ 2, 4 }, scale(v, 2));
    try std.testing.expectEqual([2]f32{ 0.5, 1 }, scale(v, 0.5));
}

test swizzle {
    const v: [2]f32 = .{ 1, 2 };
    try std.testing.expectEqual([2]f32{ 2, 1 }, swizzle(v, "yx"));
    const v2: [3]f32 = .{ 1, 2, 3 };
    try std.testing.expectEqual([3]f32{ 2, 3, 1 }, swizzle(v2, "yzx"));
    const v3: [4]f32 = .{ 1, 2, 3, 4 };
    try std.testing.expectEqual([3]f32{ 4, 1, 1 }, swizzle(v3, "wxx"));
}

test cast {
    const v: [3]f32 = .{ 1.5, -2.5, 3 };
    try std.testing.expectEqual([3]f64{ 1.5, -2.5, 3 }, cast(f64, v));
    try std.testing.expectEqual([3]i32{ 1, -2, 3 }, cast(i32, v));
    const u: [2]u8 = .{ 200, 3 };
    try std.testing.expectEqual([2]f32{ 200, 3 }, cast(f32, u));
    try std.testing.expectEqual([2]i16{ 200, 3 }, cast(i16, u));
}

test normSqr {
    const v: [3]f32 = .{ 1, 2, 2 };
    try std.testing.expectEqual(@as(f32, 9), normSqr(v));
    const v2: [2]i32 = .{ 3, -4 };
    try std.testing.expectEqual(@as(i32, 25), normSqr(v2));
}

test normalize {
    const v_f32: [3]f32 = .{ 3, 4, 0 };
    const normalized_f32 = normalize(v_f32);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), normalized_f32[0], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), normalized_f32[1], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), normalized_f32[2], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1), norm(normalized_f32), 0.0001);
}

test dot {
    const v1: [3]f32 = .{ 1, 2, 3 };
    const v2: [3]f32 = .{ 4, 5, 6 };
    try std.testing.expectEqual(@as(f32, 32), dot(v1, v2));

    const v3: [2]i32 = .{ 2, 3 };
    const v4: [2]i32 = .{ 4, 5 };
    try std.testing.expectEqual(@as(i32, 23), dot(v3, v4));
}

test cross {
    const v1: [3]f32 = .{ 1, 0, 0 };
    const v2: [3]f32 = .{ 0, 1, 0 };
    try std.testing.expectEqual([3]f32{ 0, 0, 1 }, cross(v1, v2));

    const v3: [3]i32 = .{ 2, 3, 4 };
    const v4: [3]i32 = .{ 5, 6, 7 };
    try std.testing.expectEqual([3]i32{ -3, 6, -3 }, cross(v3, v4));
}

test distance {
    const v1: [2]f32 = .{ 1, 1 };
    const v2: [2]f32 = .{ 4, 5 };
    try std.testing.expectApproxEqAbs(@as(f32, 5), distance(v1, v2), 0.0001);

    const v3: [3]f64 = .{ 1, 2, 3 };
    const v4: [3]f64 = .{ 4, 6, 8 };
    try std.testing.expectApproxEqAbs(@as(f64, 7.0710678118654755), distance(v3, v4), 0.0000001);

    const v5: [2]u8 = .{ 4, 5 };
    const v6: [2]u8 = .{ 1, 1 };
    try std.testing.expectEqual(@as(f32, 5), distance(v6, v5));
}

test angle {
    const v1: [2]f32 = .{ 1, 0 };
    const v2: [2]f32 = .{ 0, 1 };
    try std.testing.expectApproxEqAbs(@as(f32, std.math.pi / 2.0), angle(v1, v2), 0.0001);

    const v3: [2]f32 = .{ 1, 1 };
    const v4: [2]f32 = .{ -1, 1 };
    try std.testing.expectApproxEqAbs(@as(f32, std.math.pi / 2.0), angle(v3, v4), 0.0001);

    const v5: [2]i32 = .{ 1, 0 };
    const v6: [2]i32 = .{ 0, 3 };
    try std.testing.expectApproxEqAbs(@as(f32, std.math.pi / 2.0), angle(v5, v6), 0.0001);

    const v7: [3]f32 = .{ 0.1, 0.2, 0.3 };
    try std.testing.expectEqual(@as(f32, 0), angle(v7, v7));
    try std.testing.expectApproxEqAbs(@as(f32, std.math.pi), angle(v7, scale(v7, -1)), 0.000001);
    try std.testing.expectEqual(@as(f32, 0), angle(v7, .{ 0, 0, 0 }));

    const a: [3]f32 = .{ 1, 0, 0 };
    try std.testing.expectApproxEqRel(@as(f32, 1e-4), angle(a, .{ 1, 1e-4, 0 }), 1e-5);
    try std.testing.expectApproxEqRel(@as(f32, std.math.pi - 1e-4), angle(a, .{ -1, 1e-4, 0 }), 1e-6);
}

test reflect {
    const v: [2]f32 = .{ 1, -1 };
    const normal: [2]f32 = .{ 0, 1 };
    try std.testing.expectEqual([2]f32{ 1, 1 }, reflect(v, normal));

    const v2: [3]f32 = .{ 1, -1, 0.5 };
    const normal2: [3]f32 = .{ 0, 1, 0 };
    const expected2: [3]f32 = .{ 1, 1, 0.5 };

    const result = reflect(v2, normal2);
    try std.testing.expectApproxEqAbs(expected2[0], result[0], 0.0001);
    try std.testing.expectApproxEqAbs(expected2[1], result[1], 0.0001);
    try std.testing.expectApproxEqAbs(expected2[2], result[2], 0.0001);
}

test norm {
    const expected = 2.2360679774997896964091736687;
    const h: [2]f16 = .{ 1, 2 };
    try std.testing.expect(@TypeOf(norm(h)) == f16);
    try std.testing.expectEqual(@as(f16, expected), norm(h));

    const big: [2]f16 = .{ 300, 400 };
    try std.testing.expectEqual(@as(f32, 500), norm(cast(f32, big)));
    const i: [2]i64 = .{ 1, 2 };
    try std.testing.expect(@TypeOf(norm(i)) == f64);
    try std.testing.expectEqual(@as(f64, expected), norm(i));

    const s: [2]i8 = .{ 100, 100 };
    try std.testing.expectApproxEqAbs(@as(f32, 141.42136), norm(s), 0.001);

    const v1: [2]f32 = .{ 3, 4 };
    try std.testing.expectEqual(@as(f32, 5), norm(v1));

    const v2: [3]f64 = .{ 1, 2, 2 };
    try std.testing.expectApproxEqAbs(@as(f64, 3), norm(v2), 0.0001);

    const v3: [4]i32 = .{ 1, 2, 2, 0 };
    try std.testing.expectApproxEqAbs(@as(f32, 3), norm(v3), 0.0001);

    const v4: [2]u8 = .{ 3, 4 };
    try std.testing.expectEqual(@as(f32, 5), norm(v4));
}
