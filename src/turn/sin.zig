const std = @import("std");

/// Max error 2.37 ULP.
pub fn sin(x: anytype) @TypeOf(x) {
    return sinOrCos(x, false);
}

/// Max error 2.61 ULP.
pub fn cos(x: anytype) @TypeOf(x) {
    return sinOrCos(x, true);
}

inline fn sinOrCos(x: anytype, comptime is_cos: bool) @TypeOf(x) {
    const T = @TypeOf(x);
    const E = Element(T);
    switch (@typeInfo(E)) {
        .float, .comptime_float => {},
        else => @compileError("expected a float or vector of floats, got " ++ @typeName(T)),
    }
    if (E == comptime_float) return comptime sinOrCos(@as(f128, x), is_cos);
    if (E == f16) return @floatCast(sinOrCos(@as(SetElement(T, f32), @floatCast(x)), is_cos));

    const U = SetElement(T, @Int(.unsigned, @bitSizeOf(E)));
    const zero = splat(T, 0.0);
    const sign_bit = splat(U, @as(Element(U), 1) << (@bitSizeOf(E) - 1));

    // TODO: would be cheaper to tie to even instead of to 0
    // but zig doesnt support it without inline assembly
    const f = x - @round(x);
    // TODO: would be cheaper to tie to even here as well
    const q = @round(f + f);
    var t = q * splat(T, -0.5) + f;
    if (is_cos) t = splat(T, 0.25) - @abs(t);

    const flip = select(U, q != zero, sign_bit, splat(U, 0));
    t = @bitCast(@as(U, @bitCast(t)) ^ flip);

    const s = t * t;
    const u = switch (E) {
        f32 => u: {
            var p = splat(T, 3.971091843e+01);
            p = @mulAdd(T, p, s, splat(T, -7.657498932e+01));
            p = @mulAdd(T, p, s, splat(T, 8.160223389e+01));
            p = @mulAdd(T, p, s, splat(T, -4.134167862e+01));
            p = @mulAdd(T, p, s, splat(T, -2.08234354e-07));
            break :u @mulAdd(T, splat(T, 6.28318548), t, t * p);
        },
        f64 => u: {
            var p = splat(T, 0.10085632871529823);
            p = @mulAdd(T, p, s, splat(T, -0.7177235796565475));
            p = @mulAdd(T, p, s, splat(T, 3.8199270504299707));
            p = @mulAdd(T, p, s, splat(T, -15.094641620507467));
            p = @mulAdd(T, p, s, splat(T, 42.058693923785164));
            p = @mulAdd(T, p, s, splat(T, -76.7058597527985));
            p = @mulAdd(T, p, s, splat(T, 81.60524927607341));
            p = @mulAdd(T, p, s, splat(T, -41.341702240399755));
            p = @mulAdd(T, p, s, splat(T, 2.4331316686560163e-16));
            break :u @mulAdd(T, splat(T, 6.283185307179586), t, t * p);
        },
        else => @sin(t * splat(T, std.math.tau)),
    };

    if (is_cos) return u + zero;
    const signed_zero: T = @bitCast(@as(U, @bitCast(x)) & sign_bit);
    return select(T, u == zero, signed_zero, u);
}

// TODO: @select might also become compatible with scalars in the future
inline fn select(comptime T: type, c: SetElement(T, bool), a: T, b: T) T {
    return switch (@typeInfo(T)) {
        .vector => @select(Element(T), c, a, b),
        else => if (c) a else b,
    };
}

fn SetElement(comptime T: type, comptime E: type) type {
    return switch (@typeInfo(T)) {
        .vector => |v| @Vector(v.len, E),
        else => E,
    };
}

// TODO: replace with `@splat` after zig 0.18
inline fn splat(comptime T: type, v: Element(T)) T {
    return switch (@typeInfo(T)) {
        .vector => @splat(v),
        else => v,
    };
}

fn Element(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .vector => |v| v.child,
        else => T,
    };
}

test "special values" {
    inline for (.{ f16, f32, f64, f80, f128 }) |F| {
        const inf = std.math.inf(F);
        try std.testing.expect(std.math.isNan(sin(inf)));
        try std.testing.expect(std.math.isNan(sin(-inf)));
        try std.testing.expect(std.math.isNan(sin(std.math.nan(F))));
        for ([_]F{ 0.0, 0.5, 1.0, 3.0, 1e4 }) |x| {
            try std.testing.expect(!std.math.signbit(sin(x)) and sin(x) == 0);
            try std.testing.expect(std.math.signbit(sin(-x)) and sin(-x) == 0);
        }
        try std.testing.expectEqual(@as(F, 1.0), sin(@as(F, 0.25)));
        try std.testing.expectEqual(@as(F, -1.0), sin(@as(F, 0.75)));
        try std.testing.expectApproxEqRel(@as(F, std.math.sqrt1_2), sin(@as(F, 0.125)), std.math.floatEps(F) * 2);
    }
}

test "comptime_float" {
    const y = sin(1.0 / 12.0);
    comptime std.debug.assert(@TypeOf(y) == comptime_float);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), @as(f64, y), 1e-30);
}
