const std = @import("std");

/// TODO: rework this documentation
/// A generic vector type.
///
/// the `vals` field is of type `@Vector(T, n)` and is meant to be used directly for the basic operations available for @Vector types.
/// for example vector additions can be achieved with `vec.vals + other.vals`.
///
/// if a specific output precision is desired, it can be specified with the Adv variants of the Vec functions
/// (precsion corresponds to the number of bits of the output and the precsion of the calculations will match).
///
/// the len public constant is the number of elements in the vector, and is equivalent to vec.vals.len.
pub fn Vec(comptime n: usize, comptime T: type) type {
    switch (@typeInfo(T)) {
        .Int => {},
        .Float => {},
        else => @compileError("Vec: unsupported type, T must be an integer type or float type not " ++ @typeName(T)),
    }

    return struct {
        const Self = @This();
        const Float = std.meta.Float;

        const default_precision = switch (@typeInfo(T)) {
            .Int => |int| int.bits,
            .Float => |float| float.bits,
            else => unreachable,
        };

        const ValsType = @Vector(n, T);

        pub const len = n;

        vals: ValsType,

        pub fn init(data: @Vector(n, T)) Self {
            return Self{ .vals = data };
        }

        pub fn initAll(value: T) Self {
            return Self{ .vals = @splat(value) };
        }

        pub fn x(self: Self) T {
            if (n < 1) {
                @compileError("Vector must have at least one element for x() to be defined");
            }
            return self.vals[0];
        }

        pub fn y(self: Self) T {
            if (n < 2) {
                @compileError("Vector must have at least two elements for y() to be defined");
            }
            return self.vals[1];
        }

        pub fn z(self: Self) T {
            if (n < 3) {
                @compileError("Vector must have at least three elements for z() to be defined");
            }
            return self.vals[2];
        }

        pub fn w(self: Self) T {
            if (n < 4) {
                @compileError("Vector must have at least four elements for w() to be defined");
            }
            return self.vals[3];
        }

        pub fn swizzle(self: Self, comptime components: []const u8) Vec(components.len, T) {
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

            return Vec(components.len, T){
                .vals = @shuffle(
                    T,
                    self.vals,
                    @as(@Vector(1, T), undefined),
                    mask,
                ),
            };
        }

        pub fn normAdv(self: Self, comptime precision: u8) Float(precision) {
            checkPrecision(precision);
            const ResultType = Float(precision);

            const type_info = @typeInfo(T);

            if (type_info == .Int) {
                return std.math.sqrt(
                    @as(
                        ResultType,
                        @floatFromInt(@reduce(
                            .Add,
                            self.vals * self.vals,
                        )),
                    ),
                );
            } else {
                const vals: blk: {
                    if (precision > default_precision) {
                        break :blk @Vector(n, ResultType);
                    } else {
                        break :blk ValsType;
                    }
                } = self.vals;

                return @floatCast(std.math.sqrt(
                    @reduce(
                        .Add,
                        vals * vals,
                    ),
                ));
            }
        }

        pub fn norm(self: Self) Float(default_precision) {
            return self.normAdv(default_precision);
        }

        pub fn normalizeAdv(self: Self, ReturnT: type) Vec(n, ReturnT) {
            const precision = switch (@typeInfo(ReturnT)) {
                .Float => @typeInfo(ReturnT).Float.bits,
                .Int => @typeInfo(ReturnT).Int.bits,
                else => @compileError("unsupported type: ReturnT type must be of type integer or float"),
            };

            const self_norm = castEnsureType(ReturnT, self.normAdv(precision));

            if (self_norm == 0) {
                return Vec(n, ReturnT).initAll(0);
            }

            return .{
                .vals = castEnsureType(@Vector(n, ReturnT), self.vals) /
                    @as(@Vector(n, ReturnT), @splat(self_norm)),
            };
        }

        pub fn normalize(self: Self) Self {
            return self.normalizeAdv(T);
        }

        pub fn dotAdv(self: Self, other: Self, comptime precision: u8) Float(precision) {
            checkPrecision(precision);
            switch (@typeInfo(T)) {
                .Float => return @reduce(.Add, self.vals * other.vals),
                .Int => return @floatFromInt(@reduce(.Add, self.vals * other.vals)),
                else => unreachable,
            }
        }

        pub fn dot(self: Self, other: Self) Float(default_precision) {
            return self.dotAdv(other, default_precision);
        }

        pub fn cross(self: Self, other: Self) Self {
            if (n != 3) {
                @compileError("self Vector must have three elements for cross() to be defined");
            }
            if (other.len != 3) {
                @compileError("other Vector must have three elements for cross() to be defined");
            }

            const self1 = @shuffle(T, self.vals, self.vals, [3]u8{ 1, 2, 0 });
            const self2 = @shuffle(T, self.vals, self.vals, [3]u8{ 2, 0, 1 });
            const other1 = @shuffle(T, other.vals, other.vals, [3]u8{ 2, 0, 1 });
            const other2 = @shuffle(T, other.vals, other.vals, [3]u8{ 1, 2, 0 });

            return .{
                .values = self1 * other2 - self2 * other1,
            };
        }

        pub fn distanceAdv(self: Self, other: Self, comptime precision: u8) Float(precision) {
            const sub = Self{
                .vals = self.vals - other.vals,
            };
            return sub.norm(precision);
        }

        pub fn distance(self: Self, other: Self) T {
            return self.distanceAdv(other, default_precision);
        }

        pub fn angleAdv(self: Self, other: Self, comptime precision: u8) Float(precision) {
            const dotProduct = self.dotAdv(other, precision);
            return std.math.acos(dotProduct / (self.normAdv(precision) * other.normAdv(precision)));
        }

        pub fn angle(self: Self, other: Self) T {
            return self.angleAdv(other, default_precision);
        }

        pub fn reflect(self: Self, normal: Self) Self {
            const dot_product = switch (@typeInfo(T)) {
                .Float => self.dot(normal),
                .Int => @as(T, @intFromFloat(self.dot(normal))),
                else => unreachable,
            };
            return Self{
                .vals = self.vals - (normal.vals *
                    @as(ValsType, @splat(2)) *
                    @as(ValsType, @splat(dot_product))),
            };
        }

        pub fn max(self: Self) T {
            return @reduce(.Max, self.vals);
        }

        pub fn min(self: Self) T {
            return @reduce(.Min, self.vals);
        }

        pub fn sum(self: Self) T {
            return @reduce(.Add, self.vals);
        }

        pub fn format(value: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = fmt;
            _ = options;
            try std.fmt.format(writer, "{}", .{value});
        }

        fn checkPrecision(comptime precision: u8) void {
            comptime {
                if (precision > 128) {
                    @compileError("precision must be less or equal to 128");
                }
                if (precision == 0) {
                    @compileError("precision must be greater than 0");
                }
            }
        }
    };
}

fn castEnsureType(comptime T: type, value: anytype) T {
    const type_info = switch (@typeInfo(T)) {
        .Float, .Int => @typeInfo(T),
        .Vector => |vec_info| @typeInfo(vec_info.child),
        else => @compileError("unsupported 'T: type' type: " ++ @typeName(T)),
    };

    const value_type_info = switch (@typeInfo(@TypeOf(value))) {
        .Float, .Int => @typeInfo(@TypeOf(value)),
        .Vector => |vec_info| @typeInfo(vec_info.child),
        else => @compileError("unsupported value 'value: anytype' type: " ++ @typeName(@TypeOf(value))),
    };

    return switch (type_info) {
        .Float => switch (value_type_info) {
            .Float => @floatCast(value),
            .Int => @floatFromInt(value),
            else => unreachable,
        },
        .Int => switch (value_type_info) {
            .Float => @intFromFloat(value),
            .Int => @intCast(value),
            else => unreachable,
        },
        else => unreachable,
    };
}

test "normAdv" {
    const v = Vec(2, f64).init(.{ 1, 0 });
    try std.testing.expectEqual(@as(f32, 1.0), v.normAdv(32));
    const v2 = Vec(2, f16).init(.{ 1, 2 });
    const result = v2.normAdv(64);
    try std.testing.expect(@TypeOf(result) == f64);
    const expected: f64 = 2.2360679774997896964091736687;
    try std.testing.expectApproxEqRel(expected, v2.normAdv(16), 0.001);
    try std.testing.expectApproxEqRel(expected, v2.normAdv(32), 0.0000001);
    try std.testing.expectApproxEqRel(expected, v2.normAdv(64), 0.00000000001);
    const v3 = Vec(2, i8).init(.{ 1, 2 });
    try std.testing.expect(@TypeOf(v3.normAdv(64)) == f64);
    try std.testing.expectApproxEqRel(expected, v3.normAdv(16), 0.001);
    try std.testing.expectApproxEqRel(expected, v3.normAdv(32), 0.0000001);
    try std.testing.expectApproxEqRel(expected, v3.normAdv(64), 0.00000000001);
    const v4 = Vec(2, u8).init(.{ 1, 2 });
    try std.testing.expect(@TypeOf(v4.normAdv(64)) == f64);
    try std.testing.expectApproxEqRel(expected, v4.normAdv(16), 0.001);
    try std.testing.expectApproxEqRel(expected, v4.normAdv(32), 0.0000001);
    try std.testing.expectApproxEqRel(expected, v4.normAdv(64), 0.00000000001);
}

test "normalizeAdv" {
    const v = Vec(2, i32).init(.{ 1, 2 });
    const expected = Vec(2, f64).init(.{
        0.4472135954999579392818,
        0.8944271909999158785636,
    });
    try std.testing.expectApproxEqAbs(expected.x(), v.normalizeAdv(f32).x(), 0.0000001);
    try std.testing.expectApproxEqAbs(expected.y(), v.normalizeAdv(f32).y(), 0.0000001);
    try std.testing.expectApproxEqAbs(expected.x(), v.normalizeAdv(f64).x(), 0.00000000001);
    try std.testing.expectApproxEqAbs(expected.y(), v.normalizeAdv(f64).y(), 0.00000000001);
    const expected_int = Vec(2, i32).init(.{
        0,
        1,
    });
    try std.testing.expectEqual(expected_int.x(), v.normalizeAdv(i32).x());
    try std.testing.expectEqual(expected_int.y(), v.normalizeAdv(i32).y());
}

test "Vec f32" {
    const Vec2 = Vec(2, f32);
    const v = Vec2.init(.{ 1, 2 });
    try std.testing.expectEqual(@as(f32, 3.0), v.sum());
    try std.testing.expectEqual(@as(f32, 1.0), v.x());
    try std.testing.expectEqual(@as(f32, 2.0), v.y());
    const v2 = Vec2.init(.{ 1, 0 });
    try std.testing.expectEqual(@as(f32, 1.0), v2.norm());
    try std.testing.expectEqual(@as(f32, 1.0), v2.normalize().norm());
    const v3 = Vec2.init(.{ 0, 1 });
    try std.testing.expectEqual(@as(f32, 0), v3.dot(v2));
    try std.testing.expectApproxEqAbs(@as(f32, std.math.pi) / 2, v2.angle(v3), 0.001);
    try std.testing.expectEqual(v2, v2.reflect(v3));
}

test "Vec i32" {
    const Vec2 = Vec(2, i32);
    const v = Vec2{ .vals = .{ 1, 2 } };
    try std.testing.expectEqual(@as(i32, 3), v.sum());
    try std.testing.expectEqual(@as(i32, 1), v.x());
    try std.testing.expectEqual(@as(i32, 2), v.y());
    const v2 = Vec2{ .vals = .{ 1, 0 } };
    try std.testing.expectEqual(@as(i32, 1), v2.norm());
    try std.testing.expectEqual(@as(i32, 1), v2.normalize().norm());
    const v3 = Vec2{ .vals = .{ 0, 1 } };
    try std.testing.expectEqual(@as(i32, 0), v3.dot(v2));
    try std.testing.expectEqual(v2, v2.reflect(v3));
}

test "swizzle" {
    const v = Vec(2, f32).init(.{ 1, 2 });
    try std.testing.expectEqual(@as(f32, 2), v.swizzle("yx").x());
    try std.testing.expectEqual(@as(f32, 1), v.swizzle("yx").y());
    const v2 = Vec(3, f32).init(.{ 1, 2, 3 });
    const v2_expected = Vec(3, f32).init(.{ 2, 3, 1 });
    try std.testing.expectEqual(v2_expected, v2.swizzle("yzx"));
}
