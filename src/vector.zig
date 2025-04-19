const std = @import("std");

const Float = std.meta.Float;

pub fn info(T: type) std.builtin.Type.Vector {
    if (@typeInfo(T) != .vector) @compileError("Excpected a @Vector type got: " ++ @typeName(T));
    return @typeInfo(T).vector;
}

/// Returns a new vector with the components swizzled.
///
/// example:
/// ```
/// const v = Vec(2, f32).init(.{ 1, 2 });
/// const v2 = v.sw("yx"); // <= here x and y are swapped
/// ```
/// v2 is equal to `Vec(2, f32).init(.{ 2, 1 });`
///
/// this is also valid:
/// ```
/// const v = Vec(2, f32).init(.{ 1, 2, 3, 4 });
/// const v2 = v.sw("wxx");
/// ```
/// here v2 is equal to `Vec(3, f32).init(.{ 4, 1, 1 });`
pub fn sw(vec: anytype, comptime components: []const u8) @Vector(components.len, info(@TypeOf(vec)).child) {
    const T = info(@TypeOf(vec)).child;
    comptime var mask: [components.len]u8 = undefined;
    comptime var i: usize = 0;
    inline for (components) |c| {
        switch (c) {
            'x' => mask[i] = 0,
            'y' => mask[i] = 1,
            'z' => mask[i] = 2,
            'w' => mask[i] = 3,
            else => @compileError("swizzle: invalid component"),
        }
        i += 1;
    }

    return @shuffle(
        T,
        vec,
        @as(@Vector(1, T), undefined),
        mask,
    );
}

/// Returns the norm of the vector as a Float.
///
/// the precsion parameter is the number of bits of the output.
/// the precision of the calculations will match the precision of the output type.
pub fn normAdv(vec: anytype, comptime precision: u8) Float(precision) {
    const T = info(@TypeOf(vec)).child;

    if (@typeInfo(T) == .int) {
        return std.math.sqrt(
            @as(
                Float(precision),
                @floatFromInt(@reduce(
                    .Add,
                    vec * vec,
                )),
            ),
        );
    } else {
        const items: blk: {
            if (precision > @bitSizeOf(T)) {
                break :blk @Vector(info(@TypeOf(vec)).len, Float(precision));
            } else {
                break :blk @TypeOf(vec);
            }
        } = vec;

        return @floatCast(std.math.sqrt(
            @reduce(
                .Add,
                items * items,
            ),
        ));
    }
}

/// Returns the norm of the vector as a Float with the default precision.
/// the precision of the output is the number of bits of the output.
/// see `normAdv` for more information.
pub inline fn norm(vec: anytype) Float(@bitSizeOf(info(@TypeOf(vec)).child)) {
    return normAdv(vec, @bitSizeOf(info(@TypeOf(vec)).child));
}

/// Returns a new vector with the same direction as the original vector, but with a norm closest to 1.
pub fn normalize(vec: anytype) @TypeOf(vec) {
    const self_norm = switch (@typeInfo(info(@TypeOf(vec)).child)) {
        .float => norm(vec),
        .int => @as(info(@TypeOf(vec)).child, @intFromFloat(norm(vec))),
        else => unreachable,
    };
    return vec / @as(
        @TypeOf(vec),
        @splat(self_norm),
    );
}

/// dot product of two vectors.
pub fn dot(vec: anytype, other: @TypeOf(vec)) info(@TypeOf(vec)).child {
    return @reduce(.Add, vec * other);
}

/// Returns the cross product of two vectors.
pub fn cross(self: anytype, other: @TypeOf(self)) @TypeOf(self) {
    if (info(@TypeOf(self)).len != 3) @compileError("vector must have three elements for cross() to be defined");
    const T = info(@TypeOf(self)).child;
    const self1 = @shuffle(T, self, self, [3]u8{ 1, 2, 0 });
    const self2 = @shuffle(T, self, self, [3]u8{ 2, 0, 1 });
    const other1 = @shuffle(T, other, other, [3]u8{ 1, 2, 0 });
    const other2 = @shuffle(T, other, other, [3]u8{ 2, 0, 1 });

    return self1 * other2 - self2 * other1;
}

/// Returns the distance between two vectors.
///
/// the precsion parameter is the number of bits of the Vector type T.
/// the precision of the calculations will match the precision of the output type.
pub fn distanceAdv(vec: anytype, other: @TypeOf(vec), comptime precision: u8) Float(precision) {
    return normAdv(vec - other, precision);
}

/// Returns the distance between two vectors.
///
/// the precision of the output is the number of bits of T.
/// see `distanceAdv` for more information.
pub inline fn distance(vec: anytype, other: @TypeOf(vec)) Float(@bitSizeOf(info(@TypeOf(vec)).child)) {
    return distanceAdv(vec, other, @bitSizeOf(info(@TypeOf(vec)).child));
}

/// Returns the angle between two vectors.
///
/// the precsion parameter is the number of bits of the Vector type T.
/// the precision of the calculations will match the precision of the output type.
pub fn angleAdv(vec: anytype, other: @TypeOf(vec), comptime precision: u8) Float(precision) {
    return std.math.acos(dot(vec, other) / (normAdv(vec, precision) * normAdv(other, precision)));
}

/// Returns the angle between two vectors.
pub inline fn angle(vec: anytype, other: @TypeOf(vec)) info(@TypeOf(vec)).child {
    return angleAdv(vec, other, @bitSizeOf(info(@TypeOf(vec)).child));
}

/// Returns a new vector that is the reflection of the original vector on the given normal.
pub fn reflect(vec: anytype, normal: @TypeOf(vec)) @TypeOf(vec) {
    const dot_product = dot(vec, normal);
    return vec - (normal *
        @as(@TypeOf(normal), @splat(2)) *
        @as(@TypeOf(normal), @splat(dot_product)));
}

/// Returns a new vector with a direction closest to the original vector, but with a magnitude scaled by the given value.
pub inline fn scale(vec: anytype, value: info(@TypeOf(vec)).child) @TypeOf(vec) {
    return vec * @as(@TypeOf(vec), @splat(value));
}

test scale {
    const v = @Vector(2, f32){ 1, 2 };
    try std.testing.expectEqual(@Vector(2, f32){ 2, 4 }, scale(v, 2));
    try std.testing.expectEqual(@Vector(2, f32){ 0.5, 1 }, scale(v, 0.5));
}

test sw {
    const v = @Vector(2, f32){ 1, 2 };
    try std.testing.expectEqual(@as(f32, 2), sw(v, "yx")[0]);
    try std.testing.expectEqual(@as(f32, 1), sw(v, "yx")[1]);
    const v2 = @Vector(3, f32){ 1, 2, 3 };
    const v2_expected = @Vector(3, f32){ 2, 3, 1 };
    try std.testing.expectEqual(v2_expected, sw(v2, "yzx"));
}

test angleAdv {
    const v1 = @Vector(2, f32){ 1, 0 };
    const v2 = @Vector(2, f32){ 0, 1 };
    const expected: f64 = @as(f64, std.math.pi) / @as(f64, 2);
    try std.testing.expectApproxEqAbs(expected, angleAdv(v1, v2, 32), 0.0000001);
    try std.testing.expectApproxEqAbs(expected, angleAdv(v1, v2, 64), 0.00000000001);
}

test normalize {
    // Test with floating point vector
    const v_f32 = @Vector(3, f32){ 3, 4, 0 };
    const normalized_f32 = normalize(v_f32);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), normalized_f32[0], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), normalized_f32[1], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), normalized_f32[2], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1), norm(normalized_f32), 0.0001);

    // Test with integer vector
    const v_i32 = @Vector(2, i32){ 3, 4 };
    const normalized_i32 = normalize(v_i32);
    try std.testing.expectEqual(@Vector(2, i32){ 0, 0 }, normalized_i32); // Integer division limitations
}

test dot {
    const v1 = @Vector(3, f32){ 1, 2, 3 };
    const v2 = @Vector(3, f32){ 4, 5, 6 };
    try std.testing.expectEqual(@as(f32, 32), dot(v1, v2));

    const v3 = @Vector(2, i32){ 2, 3 };
    const v4 = @Vector(2, i32){ 4, 5 };
    try std.testing.expectEqual(@as(i32, 23), dot(v3, v4));
}

test cross {
    const v1 = @Vector(3, f32){ 1, 0, 0 };
    const v2 = @Vector(3, f32){ 0, 1, 0 };
    const expected = @Vector(3, f32){ 0, 0, 1 };
    try std.testing.expectEqual(expected, cross(v1, v2));

    const v3 = @Vector(3, i32){ 2, 3, 4 };
    const v4 = @Vector(3, i32){ 5, 6, 7 };
    const expected_i = @Vector(3, i32){ -3, 6, -3 };
    try std.testing.expectEqual(expected_i, cross(v3, v4));
}

test distance {
    const v1 = @Vector(2, f32){ 1, 1 };
    const v2 = @Vector(2, f32){ 4, 5 };
    try std.testing.expectApproxEqAbs(@as(f32, 5), distance(v1, v2), 0.0001);

    const v3 = @Vector(3, f64){ 1, 2, 3 };
    const v4 = @Vector(3, f64){ 4, 6, 8 };
    try std.testing.expectApproxEqAbs(@as(f64, 7.0710678118654755), distance(v3, v4), 0.0000001);
}

test angle {
    const v1 = @Vector(2, f32){ 1, 0 };
    const v2 = @Vector(2, f32){ 0, 1 };
    try std.testing.expectApproxEqAbs(@as(f32, std.math.pi / 2.0), angle(v1, v2), 0.0001);

    const v3 = @Vector(2, f32){ 1, 1 };
    const v4 = @Vector(2, f32){ -1, 1 };
    try std.testing.expectApproxEqAbs(@as(f32, std.math.pi / 2.0), angle(v3, v4), 0.0001);
}

test reflect {
    const v = @Vector(2, f32){ 1, -1 };
    const normal = @Vector(2, f32){ 0, 1 };
    const expected = @Vector(2, f32){ 1, 1 };
    try std.testing.expectEqual(expected, reflect(v, normal));

    const v2 = @Vector(3, f32){ 1, -1, 0.5 };
    const normal2 = @Vector(3, f32){ 0, 1, 0 };
    const expected2 = @Vector(3, f32){ 1, 1, 0.5 };

    const result = reflect(v2, normal2);
    try std.testing.expectApproxEqAbs(expected2[0], result[0], 0.0001);
    try std.testing.expectApproxEqAbs(expected2[1], result[1], 0.0001);
    try std.testing.expectApproxEqAbs(expected2[2], result[2], 0.0001);
}

test normAdv {
    const v = @Vector(2, f64){ 1, 0 };
    try std.testing.expectEqual(@as(f32, 1), normAdv(v, 32));
    const v2 = @Vector(2, f16){ 1, 2 };
    const result = normAdv(v2, 64);
    try std.testing.expect(@TypeOf(result) == f64);
    const expected = 2.2360679774997896964091736687;
    try std.testing.expectEqual(@as(f16, expected), normAdv(v2, 16));
    try std.testing.expectEqual(@as(f32, expected), normAdv(v2, 32));
    try std.testing.expectEqual(@as(f64, expected), normAdv(v2, 64));
    const v3 = @Vector(2, i8){ 1, 2 };
    try std.testing.expect(@TypeOf(normAdv(v3, 64)) == f64);
    try std.testing.expectEqual(@as(f16, expected), normAdv(v3, 16));
    try std.testing.expectEqual(@as(f32, expected), normAdv(v3, 32));
    try std.testing.expectEqual(@as(f64, expected), normAdv(v3, 64));
    const v4 = @Vector(2, u8){ 1, 2 };
    try std.testing.expect(@TypeOf(normAdv(v4, 64)) == f64);
    try std.testing.expectEqual(@as(f16, expected), normAdv(v4, 16));
    try std.testing.expectEqual(@as(f32, expected), normAdv(v4, 32));
    try std.testing.expectEqual(@as(f64, expected), normAdv(v4, 64));
}

test norm {
    const v1 = @Vector(2, f32){ 3, 4 };
    try std.testing.expectEqual(@as(f32, 5), norm(v1));

    const v2 = @Vector(3, f64){ 1, 2, 2 };
    try std.testing.expectApproxEqAbs(@as(f64, 3), norm(v2), 0.0001);

    const v3 = @Vector(4, i32){ 1, 2, 2, 0 };
    try std.testing.expectApproxEqAbs(@as(f32, 3), norm(v3), 0.0001);
}
