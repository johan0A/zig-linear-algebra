// Jolt Physics Library (https://github.com/jrouwe/JoltPhysics)
// SPDX-FileCopyrightText: 2021 Jorrit Rouwe
// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2025 Michael Pollind
const std = @import("std");
const Float = std.meta.Float;

const Mat = @import("matrix.zig").Mat;
const meta = @import("meta.zig");
const testing = @import("testing.zig");

pub const Vec4f32 = @Vector(4, f32);
pub const Vec3f32 = @Vector(3, f32);
pub const Vec2f32 = @Vector(2, f32);

pub const Vec4f64 = @Vector(4, f64);
pub const Vec3f64 = @Vector(3, f64);
pub const Vec2f64 = @Vector(2, f64);

pub fn to_mat(vec: anytype) Mat(std.meta.Child(@TypeOf(vec)), 1, meta.array_vector_length(@TypeOf(vec))) {
    var result: Mat(std.meta.Child(@TypeOf(vec)), 1, meta.array_vector_length(@TypeOf(vec))) = .zero;
    inline for (0..meta.array_vector_length(@TypeOf(vec))) |i| {
        result.items[0][i] = vec[i];
    }
    return result;
}

pub fn extract(vec: anytype, comptime len: usize) @Vector(len, std.meta.Child(@TypeOf(vec))) {
    if (len > meta.array_vector_length(@TypeOf(vec))) @compileError("extract: length out of bounds");
    var result: @Vector(len, std.meta.Child(@TypeOf(vec))) = undefined;
    inline for (0..len) |i| {
        result[i] = vec[i];
    }
    return result;
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
pub fn swizzle(vec: anytype, comptime components: []const u8) @Vector(components.len, std.meta.Child(@TypeOf(vec))) {
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
        std.meta.Child(@TypeOf(vec)),
        vec,
        @as(@Vector(1, std.meta.Child(@TypeOf(vec))), undefined),
        mask,
    );
}

pub fn norm_sqr_adv(vec: anytype, comptime precision: u8) Float(precision) {
    comptime {
        std.debug.assert(@typeInfo(@TypeOf(vec)) == .vector);
    }
    const T = std.meta.Child(@TypeOf(vec));
    if (@typeInfo(T) == .int) {
        return @as(
            Float(precision),
            @floatFromInt(@reduce(
                .Add,
                vec * vec,
            )),
        );
    } else {
        const items: blk: {
            if (precision > @bitSizeOf(T)) {
                break :blk @Vector(meta.array_vector_length(@TypeOf(vec)), Float(precision));
            } else {
                break :blk @TypeOf(vec);
            }
        } = vec;

        return @floatCast(@reduce(
            .Add,
            items * items,
        ));
    }
}

pub inline fn norm_sqr(vec: anytype) Float(@bitSizeOf(std.meta.Child(@TypeOf(vec)))) {
    return norm_sqr_adv(vec, @bitSizeOf(std.meta.Child(@TypeOf(vec))));
}

/// Returns the norm of the vector as a Float.
///
/// the precsion parameter is the number of bits of the output.
/// the precision of the calculations will match the precision of the output type.
pub fn norm_adv(vec: anytype, comptime precision: u8) Float(precision) {
    comptime {
        std.debug.assert(@typeInfo(@TypeOf(vec)) == .vector);
    }
    const T = std.meta.Child(@TypeOf(vec));
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
                break :blk @Vector(meta.array_vector_length(@TypeOf(vec)), Float(precision));
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
pub inline fn norm(vec: anytype) Float(@bitSizeOf(std.meta.Child(@TypeOf(vec)))) {
    return norm_adv(vec, @bitSizeOf(std.meta.Child(@TypeOf(vec))));
}

/// Returns a new vector with the same direction as the original vector, but with a norm closest to 1.
pub fn normalize(vec: anytype) @TypeOf(vec) {
    comptime {
        std.debug.assert(@typeInfo(@TypeOf(vec)) == .vector);
    }
    const self_norm = switch (@typeInfo(std.meta.Child(@TypeOf(vec)))) {
        .float => norm(vec),
        .int => @as(std.meta.Child(@TypeOf(vec)), @intFromFloat(norm(vec))),
        else => unreachable,
    };
    return vec / @as(
        @TypeOf(vec),
        @splat(self_norm),
    );
}

/// dot product of two vectors.
pub fn dot(vec: anytype, other: @TypeOf(vec)) std.meta.Child(@TypeOf(vec)) {
    comptime {
        std.debug.assert(@typeInfo(@TypeOf(vec)) == .vector);
    }
    return @reduce(.Add, vec * other);
}

pub fn norm_perpendicular(a: anytype) @TypeOf(a) {
    comptime {
        std.debug.assert(@typeInfo(@TypeOf(a)) == .vector);
        std.debug.assert(@typeInfo(@TypeOf(a)).vector.len == 3);
    }
    if (@abs(a[0]) > @abs(a[1])) {
        const len = norm(swizzle(a, "xz"));
        return @TypeOf(a){ a[2], 0.0, -a[0] } / @as(@TypeOf(a), @splat(len));
    } else {
        const len = norm(swizzle(a, "yz"));
        return @TypeOf(a){ 0.0, a[2], -a[1] } / @as(@TypeOf(a), @splat(len));
    }
}

/// Returns the cross product of two vectors.
pub fn cross(a: anytype, b: @TypeOf(a)) @TypeOf(a) {
    comptime {
        std.debug.assert(@typeInfo(@TypeOf(a)) == .vector);
        std.debug.assert(@typeInfo(@TypeOf(a)).vector.len == 3);
    }
    const T = std.meta.Child(@TypeOf(a));
    const self1 = @shuffle(T, a, a, [3]u8{ 1, 2, 0 });
    const self2 = @shuffle(T, a, a, [3]u8{ 2, 0, 1 });
    const other1 = @shuffle(T, b, b, [3]u8{ 1, 2, 0 });
    const other2 = @shuffle(T, b, b, [3]u8{ 2, 0, 1 });

    return self1 * other2 - self2 * other1;
}

/// Returns the distance between two vectors.
///
/// the precsion parameter is the number of bits of the Vector type T.
/// the precision of the calculations will match the precision of the output type.
pub fn distance_adv(a: anytype, b: @TypeOf(a), comptime precision: u8) Float(precision) {
    comptime {
        std.debug.assert(@typeInfo(@TypeOf(a)) == .vector);
    }
    return norm_adv(a - b, precision);
}

/// Returns the distance between two vectors.
///
/// the precision of the output is the number of bits of T.
/// see `distanceAdv` for more information.
pub inline fn distance(vec: anytype, other: @TypeOf(vec)) Float(@bitSizeOf(std.meta.Child(@TypeOf(vec)))) {
    comptime {
        std.debug.assert(@typeInfo(@TypeOf(vec)) == .vector);
    }
    return distance_adv(vec, other, @bitSizeOf(std.meta.Child(@TypeOf(vec))));
}

/// Returns the angle between two vectors.
///
/// the precsion parameter is the number of bits of the Vector type T.
/// the precision of the calculations will match the precision of the output type.
pub fn angle_adv(vec: anytype, other: @TypeOf(vec), comptime precision: u8) Float(precision) {
    comptime {
        std.debug.assert(@typeInfo(@TypeOf(vec)) == .vector);
    }
    return std.math.acos(dot(vec, other) / (norm_adv(vec, precision) * norm_adv(other, precision)));
}

/// Returns the angle between two vectors.
pub inline fn angle(a: anytype, b: @TypeOf(a)) std.meta.Child(@TypeOf(a)) {
    comptime {
        std.debug.assert(@typeInfo(@TypeOf(a)) == .vector);
    }
    return angle_adv(a, b, @bitSizeOf(std.meta.Child(@TypeOf(a))));
}

/// Returns a new vector that is the reflection of the original vector on the given normal.
pub fn reflect(vec: anytype, normal: @TypeOf(vec)) @TypeOf(vec) {
    comptime {
        std.debug.assert(@typeInfo(@TypeOf(vec)) == .vector);
    }
    const dot_product = dot(vec, normal);
    return vec - (normal *
        @as(@TypeOf(normal), @splat(2)) *
        @as(@TypeOf(normal), @splat(dot_product)));
}

pub fn sin_cos(input: anytype) struct { sin_out: @TypeOf(input), cos_out: @TypeOf(input) } {
    comptime {
        std.debug.assert(@typeInfo(@TypeOf(input)) == .vector);
    }
    const FVec = @TypeOf(input);
    const UVec = @Vector(@typeInfo(@TypeOf(input)).vector.len, switch (@typeInfo(std.meta.Child(@TypeOf(input)))) {
        .float => |v| switch (v.bits) {
            32 => u32,
            64 => u64,
            else => @compileError("Unsupported float size"),
        },
        else => @compileError("sin_cos only supports floating point vectors"),
    });
    const last_bit = switch (@typeInfo(std.meta.Child(@TypeOf(input)))) {
        .float => |v| switch (v.bits) {
            32 => 0x80000000,
            64 => 0x8000000000000000,
            else => @compileError("Unsupported float size"),
        },
        else => @compileError("sin_cos only supports floating point vectors"),
    };

    // Apply sign changes based on quadrant
    const num_bits = switch (@typeInfo(std.meta.Child(@TypeOf(input)))) {
        .float => |v| v.bits,
        else => @compileError("sin_cos only supports floating point vectors"),
    };

    // Implementation based on sinf.c from the cephes library, combines sinf and cosf in a single function, changes octants to quadrants and vectorizes it
    // Original implementation by Stephen L. Moshier (See: http://www.moshier.net/)

    // Make argument positive and remember sign for sin only since cos is symmetric around x (highest bit of a float is the sign bit)
    var sin_sign = @as(UVec, @bitCast(input)) & @as(UVec, @splat(last_bit));
    var x: FVec = @bitCast(@as(UVec, @bitCast(input)) ^ sin_sign);

    // x / (PI / 2) rounded to nearest int gives us the quadrant closest to x
    const quadrant: UVec = @intFromFloat(@as(FVec, @splat(0.6366197723675814)) * x + @as(FVec, @splat(0.5)));
    const float_quadrant: FVec = @floatFromInt(quadrant);

    // Make x relative to the closest quadrant.
    // This does x = x - quadrant * PI / 2 using a two step Cody-Waite argument reduction.
    // This improves the accuracy of the result by avoiding loss of significant bits in the subtraction.
    // We start with x = x - quadrant * PI / 2, PI / 2 in hexadecimal notation is 0x3fc90fdb, we remove the lowest 16 bits to
    // get 0x3fc90000 (= 1.5703125) this means we can now multiply with a number of up to 2^16 without losing any bits.
    // This leaves us with: x = (x - quadrant * 1.5703125) - quadrant * (PI / 2 - 1.5703125).
    // PI / 2 - 1.5703125 in hexadecimal is 0x39fdaa22, stripping the lowest 12 bits we get 0x39fda000 (= 0.0004837512969970703125)
    // This leaves uw with: x = ((x - quadrant * 1.5703125) - quadrant * 0.0004837512969970703125) - quadrant * (PI / 2 - 1.5703125 - 0.0004837512969970703125)
    // See: https://stackoverflow.com/questions/42455143/sine-cosine-modular-extended-precision-arithmetic
    // After this we have x in the range [-PI / 4, PI / 4].
    x = ((x - float_quadrant * @as(FVec, @splat(1.5703125))) - float_quadrant * @as(FVec, @splat(0.0004837512969970703125))) - float_quadrant * @as(FVec, @splat(7.549789948768648e-8));

    //Calculate x2 = x^2
    const x2 = x * x;

    // Taylor expansion:
    // Cos(x) = 1 - x^2/2! + x^4/4! - x^6/6! + x^8/8! + ... = (((x2/8!- 1/6!) * x2 + 1/4!) * x2 - 1/2!) * x2 + 1
    const taylor_cos = ((@as(FVec, @splat(2.443315711809948e-5)) * x2 - @as(FVec, @splat(1.388731625493765e-3))) * x2 + @as(FVec, @splat(4.166664568298827e-2))) * x2 * x2 - @as(FVec, @splat(0.5)) * x2 + @as(FVec, @splat(1.0));
    // Sin(x) = x - x^3/3! + x^5/5! - x^7/7! + ... = ((-x2/7! + 1/5!) * x2 - 1/3!) * x2 * x + x
    const taylor_sin = ((@as(FVec, @splat(-1.9515295891e-4)) * x2 + @as(FVec, @splat(8.3321608736e-3))) * x2 - @as(FVec, @splat(1.6666654611e-1))) * x2 * x + x;

    // The lowest 2 bits of quadrant indicate the quadrant that we are in.
    // Let x be the original input value and x' our value that has been mapped to the range [-PI / 4, PI / 4].
    // since cos(x) = sin(x - PI / 2) and since we want to use the Taylor expansion as close as possible to 0,
    // we can alternate between using the Taylor expansion for sin and cos according to the following table:
    //
    // quadrant  sin(x)      cos(x)
    // XXX00b    sin(x')    cos(x')
    // XXX01b   cos(x')    -sin(x')
    // XXX10b   -sin(x')    -cos(x')
    // XXX11b   -cos(x')    sin(x')
    //
    // Extract the lowest 2 bits of quadrant to determine which Taylor expansion to use and signs
    const bit1: UVec = quadrant << @as(UVec, @splat(num_bits - 1)); // bit 0
    const bit2: UVec = (quadrant << @as(UVec, @splat(num_bits - 2))) & @as(UVec, @splat(last_bit)); // bit 1

    // Select which one of the results is sin and which one is cos based on bit1
    const s = @select(std.meta.Child(FVec), bit1 > @as(UVec, @splat(0)), taylor_cos, taylor_sin);
    const c = @select(std.meta.Child(FVec), bit1 > @as(UVec, @splat(0)), taylor_sin, taylor_cos);

    sin_sign = sin_sign ^ bit2;
    const cos_sign = bit1 ^ bit2;

    return .{
        .sin_out = @bitCast(@as(UVec, @bitCast(s)) ^ sin_sign),
        .cos_out = @bitCast(@as(UVec, @bitCast(c)) ^ cos_sign),
    };
}

/// Returns a new vector with a direction closest to the original vector, but with a magnitude scaled by the given value.
pub inline fn scale(a: anytype, value: std.meta.Child(@TypeOf(a))) @TypeOf(a) {
    comptime {
        std.debug.assert(@typeInfo(@TypeOf(a)) == .vector);
    }
    return a * @as(@TypeOf(a), @splat(value));
}

pub fn is_close_default(a: anytype, b: @TypeOf(a)) bool {
    return is_close(a, b, 1.0e-12);
}

pub fn is_close(a: anytype, b: @TypeOf(a), max_distance_sqr: Float(@bitSizeOf(std.meta.Child(@TypeOf(a))))) bool {
    comptime {
        std.debug.assert(@typeInfo(@TypeOf(a)) == .vector);
    }
    return norm_sqr(a - b) <= max_distance_sqr;
}

pub fn is_normalized_default(a: anytype) bool {
    comptime {
        std.debug.assert(@typeInfo(@TypeOf(a)) == .vector);
    }
    return is_normalized(a, 1.0e-6);
}

pub fn is_normalized(a: anytype, tolerance: Float(@bitSizeOf(std.meta.Child(@TypeOf(a))))) bool {
    comptime {
        std.debug.assert(@typeInfo(@TypeOf(a)) == .vector);
    }
    return @abs(norm_sqr(a) - 1.0) <= tolerance;
}

test scale {
    const v = @Vector(2, f32){ 1, 2 };
    try std.testing.expectEqual(@Vector(2, f32){ 2, 4 }, scale(v, 2));
    try std.testing.expectEqual(@Vector(2, f32){ 0.5, 1 }, scale(v, 0.5));
}

test is_close {
    try std.testing.expect(is_close(@Vector(4, f32){ 1, 2, 3, 4 }, @Vector(4, f32){ 1.001, 2.001, 3.001, 4.001 }, 1.0e-4));
    try std.testing.expect(!is_close(@Vector(4, f32){ 1, 2, 3, 4 }, @Vector(4, f32){ 1.001, 2.001, 3.001, 4.001 }, 1.0e-6));
}

test swizzle {
    const v = @Vector(2, f32){ 1, 2 };
    try std.testing.expectEqual(@as(f32, 2), swizzle(v, "yx")[0]);
    try std.testing.expectEqual(@as(f32, 1), swizzle(v, "yx")[1]);
    const v2 = @Vector(3, f32){ 1, 2, 3 };
    const v2_expected = @Vector(3, f32){ 2, 3, 1 };
    try std.testing.expectEqual(v2_expected, swizzle(v2, "yzx"));
}

test angle_adv {
    const v1 = @Vector(2, f32){ 1, 0 };
    const v2 = @Vector(2, f32){ 0, 1 };
    const expected: f64 = @as(f64, std.math.pi) / @as(f64, 2);
    try std.testing.expectApproxEqAbs(expected, angle_adv(v1, v2, 32), 0.0000001);
    try std.testing.expectApproxEqAbs(expected, angle_adv(v1, v2, 64), 0.00000000001);
}

test normalize {
    // Test with floating point vector
    const normalized_f32 = normalize(@Vector(3, f32){ 3, 4, 0 });
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

test norm_adv {
    const v = @Vector(2, f64){ 1, 0 };
    try std.testing.expectEqual(@as(f32, 1), norm_adv(v, 32));
    const v2 = @Vector(2, f16){ 1, 2 };
    const result = norm_adv(v2, 64);
    try std.testing.expect(@TypeOf(result) == f64);
    const expected = 2.2360679774997896964091736687;
    try std.testing.expectEqual(@as(f16, expected), norm_adv(v2, 16));
    try std.testing.expectEqual(@as(f32, expected), norm_adv(v2, 32));
    try std.testing.expectEqual(@as(f64, expected), norm_adv(v2, 64));
    const v3 = @Vector(2, i8){ 1, 2 };
    try std.testing.expect(@TypeOf(norm_adv(v3, 64)) == f64);
    try std.testing.expectEqual(@as(f16, expected), norm_adv(v3, 16));
    try std.testing.expectEqual(@as(f32, expected), norm_adv(v3, 32));
    try std.testing.expectEqual(@as(f64, expected), norm_adv(v3, 64));
    const v4 = @Vector(2, u8){ 1, 2 };
    try std.testing.expect(@TypeOf(norm_adv(v4, 64)) == f64);
    try std.testing.expectEqual(@as(f16, expected), norm_adv(v4, 16));
    try std.testing.expectEqual(@as(f32, expected), norm_adv(v4, 32));
    try std.testing.expectEqual(@as(f64, expected), norm_adv(v4, 64));
}

test norm {
    const v1 = @Vector(2, f32){ 3, 4 };
    try std.testing.expectEqual(@as(f32, 5), norm(v1));

    const v2 = @Vector(3, f64){ 1, 2, 2 };
    try std.testing.expectApproxEqAbs(@as(f64, 3), norm(v2), 0.0001);

    const v3 = @Vector(4, i32){ 1, 2, 2, 0 };
    try std.testing.expectApproxEqAbs(@as(f32, 3), norm(v3), 0.0001);
}

test sin_cos {
    {
        const input = @Vector(2, f32){ 0, std.math.pi * 0.5 };
        const res = sin_cos(input);
        try testing.expect_is_close(res.cos_out, @Vector(2, f32){ 1, 0 }, 0.0001);
        try testing.expect_is_close(res.sin_out, @Vector(2, f32){ 0, 1.0 }, 0.0001);
    }
    {
        const input = @Vector(4, f32){ 0, std.math.pi * 0.5, std.math.pi, -0.5 * std.math.pi };
        const res = sin_cos(input);
        try testing.expect_is_close(res.cos_out, @Vector(4, f32){ 1, 0, -1, 0 }, 0.0001);
        try testing.expect_is_close(res.sin_out, @Vector(4, f32){ 0, 1.0, 0, -1.0 }, 0.0001);
    }
    var ms: f64 = 0.0;
    var mc: f64 = 0.0;

    var x: f32 = -100.0 * std.math.pi;
    while (x < 100.0 * std.math.pi) : (x += 1.0e-3) {
        const xv = @as(Vec4f32, @splat(x)) + Vec4f32{ 0.0e-4, 2.5e-4, 5.0e-4, 7.5e-4 };
        const res2 = sin_cos(xv);
        inline for (0..3) |i| {
            const s1 = std.math.sin(xv[i]);
            const s2 = res2.sin_out[i];
            ms = @max(ms, @abs(s1 - s2));

            const c1 = std.math.cos(xv[i]);
            const c2 = res2.cos_out[i];
            mc = @max(mc, @abs(c1 - c2));
        }
    }
    try std.testing.expect(ms < 1.0e-7);
    try std.testing.expect(mc < 1.0e-7);
}
