const std = @import("std");

/// A generic vector type. Floats and integers are supported.
///
/// the `items` field is of type `@Vector(T, n)` and is meant to be used directly for the basic operations available for @Vector types.
/// for example vector additions can be achieved with `vec.items + other_vec.items`.
///
/// Adv at the end of some function is short for "advanced", those functions give more control over the output.
pub fn Vec(comptime len: usize, comptime T: type) type {
    switch (@typeInfo(T)) {
        .int => {},
        .float => {},
        else => @compileError("Vec: unsupported type, T must be an integer type or float type not " ++ @typeName(T)),
    }

    return struct {
        const Self = @This();
        const Float = std.meta.Float;

        /// the default precision of the Vector type T.
        pub const default_precision = switch (@typeInfo(T)) {
            .int => |int| int.bits,
            .float => |float| float.bits,
            else => unreachable,
        };

        const ItemsType: type = @Vector(len, T);

        /// this field is meant to be used directly for the basic operations available for @Vector types.
        /// for example vector additions can be achieved with `vec.items + other_vec.items`.
        items: @Vector(len, T),
        comptime len: comptime_int = len,
        comptime Type: type = T,

        pub fn init(data: @Vector(len, T)) Self {
            return Self{ .items = data };
        }

        /// returns a mutable reference to the x component
        pub inline fn rX(self: *Self) *T {
            if (len < 1) @compileError("Vector must have at least one element for rX() to be defined");
            return &self.items[0];
        }

        /// returns a mutable reference to the y component
        pub inline fn rY(self: *Self) *T {
            if (len < 2) @compileError("Vector must have at least two elements for rY() to be defined");
            return &self.items[1];
        }

        /// returns a mutable reference to the z component
        pub inline fn rZ(self: *Self) *T {
            if (len < 3) @compileError("Vector must have at least three elements for rZ() to be defined");
            return &self.items[2];
        }

        /// returns a mutable reference to the w component
        pub inline fn rW(self: *Self) *T {
            if (len < 4) @compileError("Vector must have at least four elements for rW() to be defined");
            return &self.items[3];
        }

        /// returns the value of the x component
        pub inline fn x(self: Self) T {
            if (len < 1) @compileError("Vector must have at least one element for x() to be defined");
            return self.items[0];
        }

        /// returns the value of the y component
        pub inline fn y(self: Self) T {
            if (len < 2) @compileError("Vector must have at least two elements for y() to be defined");
            return self.items[1];
        }

        /// returns the value of the z component
        pub inline fn z(self: Self) T {
            if (len < 3) @compileError("Vector must have at least three elements for z() to be defined");
            return self.items[2];
        }

        /// returns the value of the w component
        pub inline fn w(self: Self) T {
            if (len < 4) @compileError("Vector must have at least four elements for w() to be defined");
            return self.items[3];
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
        pub fn sw(self: Self, comptime components: []const u8) Vec(components.len, T) {
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
                .items = @shuffle(
                    T,
                    self.items,
                    @as(@Vector(1, T), undefined),
                    mask,
                ),
            };
        }

        /// Returns the norm of the vector as a Float.
        ///
        /// the precsion parameter is the number of bits of the output.
        /// the precision of the calculations will match the precision of the output type.
        pub fn normAdv(self: Self, comptime precision: u8) Float(precision) {
            checkPrecision(precision);
            const ResultType = Float(precision);

            const type_info = @typeInfo(T);

            if (type_info == .int) {
                return std.math.sqrt(
                    @as(
                        ResultType,
                        @floatFromInt(@reduce(
                            .Add,
                            self.items * self.items,
                        )),
                    ),
                );
            } else {
                const items: blk: {
                    if (precision > default_precision) {
                        break :blk @Vector(len, ResultType);
                    } else {
                        break :blk ItemsType;
                    }
                } = self.items;

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
        pub fn norm(self: Self) Float(default_precision) {
            return @call(.always_inline, normAdv, .{ self, default_precision });
        }

        /// Returns a new vector with the same direction as the original vector, but with a norm closest to 1.
        pub fn normalize(self: Self) Self {
            const self_norm = switch (@typeInfo(T)) {
                .float => self.norm(),
                .int => @as(T, @intFromFloat(self.norm())),
                else => unreachable,
            };
            return .{
                .items = self.items / @as(
                    @Vector(len, T),
                    @splat(self_norm),
                ),
            };
        }

        /// Modifies the vector in place to have a norm of 1.
        pub fn selfNormalize(self: *Self) void {
            const self_norm = self.norm();
            self.items = self.items / @as(@Vector(len, T), @splat(self_norm));
        }

        /// Returns the dot product of the two vectors.
        pub fn dot(self: Self, other: Self) T {
            return @reduce(.Add, self.items * other.items);
        }

        /// Returns the cross product of two vectors.
        pub fn cross(self: Self, other: Self) Self {
            if (len != 3) @compileError("self Vector must have three elements for cross() to be defined");
            if (other.len != 3) @compileError("other Vector must have three elements for cross() to be defined");

            const self1 = @shuffle(T, self.items, self.items, [3]u8{ 1, 2, 0 });
            const self2 = @shuffle(T, self.items, self.items, [3]u8{ 2, 0, 1 });
            const other1 = @shuffle(T, other.items, other.items, [3]u8{ 2, 0, 1 });
            const other2 = @shuffle(T, other.items, other.items, [3]u8{ 1, 2, 0 });

            return .{
                .items = self1 * other2 - self2 * other1,
            };
        }

        /// Returns the distance between two vectors.
        ///
        /// the precsion parameter is the number of bits of the Vector type T.
        /// the precision of the calculations will match the precision of the output type.
        pub fn distanceAdv(self: Self, other: Self, comptime precision: u8) Float(precision) {
            const sub = Self{
                .items = self.items - other.items,
            };
            return sub.normAdv(precision);
        }

        /// Returns the distance between two vectors.
        ///
        /// the precision of the output is the number of bits of the Vector type T.
        /// see `distanceAdv` for more information.
        pub fn distance(self: Self, other: Self) T {
            return @call(.always_inline, distanceAdv, .{ self, other, default_precision });
        }

        /// Returns the angle between two vectors.
        ///
        /// the precsion parameter is the number of bits of the Vector type T.
        /// the precision of the calculations will match the precision of the output type.
        pub fn angleAdv(self: Self, other: Self, comptime precision: u8) Float(precision) {
            const dotProduct = self.dot(other);
            return std.math.acos(dotProduct / (self.normAdv(precision) * other.normAdv(precision)));
        }

        /// Returns the angle between two vectors.
        ///
        /// the precision of the output is the number of bits of the output.
        /// see `angleAdv` for more information.
        pub fn angle(self: Self, other: Self) T {
            return @call(.always_inline, angleAdv, .{ self, other, default_precision });
        }

        /// Returns a new vector that is the reflection of the original vector on the given normal.
        pub fn reflect(self: Self, normal: Self) Self {
            const dot_product = self.dot(normal);
            return Self.init(
                self.items - (normal.items *
                    @as(@TypeOf(normal.items), @splat(2)) *
                    @as(@TypeOf(normal.items), @splat(dot_product))),
            );
        }

        /// Returns the maximum value in the vector.
        pub fn max(self: Self) T {
            return @reduce(.Max, self.items);
        }

        /// Returns the minimum value in the vector.
        pub fn min(self: Self) T {
            return @reduce(.Min, self.items);
        }

        /// Returns the sum of all the values in the vector.
        pub fn sum(self: Self) T {
            return @reduce(.Add, self.items);
        }

        /// Returns a new vector with a direction closest to the original vector, but with a magnitude scaled by the given value.
        pub inline fn scale(self: Self, value: T) Self {
            return Self.init(self.items * @as(@Vector(len, T), @splat(value)));
        }

        /// Modifies the vector in place to have a direction closest to the original vector, but with a magnitude scaled by the given value.
        pub fn selfScale(self: *Self, value: T) void {
            self.* = self.scale(value);
        }

        // TODO: doc
        pub fn append(self: Self, value: T) Vec(len + 1, T) {
            var result: Vec(len + 1, T) = undefined;
            for (0..len) |i| {
                result.items[i] = self.items[i];
            }
            result.items[len] = value;
            return result;
        }

        // TODO: doc
        pub fn appendVec(self: Self, other: anytype) Vec(len + other.len, T) {
            var result: Vec(len + other.len, T) = undefined;
            for (0..len) |i| {
                result.items[i] = self.items[i];
            }
            for (0..other.len) |i| {
                result.items[len + i] = other.items[i];
            }
            return result;
        }

        /// casts the vector to a new vector with a different type.
        pub fn cast(self: Self, comptime ReturnT: type) Vec(len, ReturnT) {
            return .{
                .items = castEnsureType(@Vector(len, ReturnT), self.items),
            };
        }

        pub fn format(value: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = fmt;
            _ = options;
            try std.fmt.format(writer, "{}", .{value.items});
        }
    };
}

fn checkPrecision(comptime precision: u8) void {
    if (precision == 0) @compileError("precision must be greater than 0");
}

fn castEnsureType(comptime T: type, value: anytype) T {
    const type_info = switch (@typeInfo(T)) {
        .float, .int => @typeInfo(T),
        .Vector => |vec_info| @typeInfo(vec_info.child),
        else => @compileError("unsupported 'T: type' type: " ++ @typeName(T)),
    };

    const value_type_info = switch (@typeInfo(@TypeOf(value))) {
        .float, .int => @typeInfo(@TypeOf(value)),
        .Vector => |vec_info| @typeInfo(vec_info.child),
        else => @compileError("unsupported value 'value: anytype' type: " ++ @typeName(@TypeOf(value))),
    };

    return switch (type_info) {
        .float => switch (value_type_info) {
            .float => @floatCast(value),
            .int => @floatFromInt(value),
            else => unreachable,
        },
        .int => switch (value_type_info) {
            .float => @intFromFloat(value),
            .int => @intCast(value),
            else => unreachable,
        },
        else => unreachable,
    };
}

test "scale" {
    const v = Vec(2, f32).init(.{ 1, 2 });
    try std.testing.expectEqual(Vec(2, f32).init(.{ 2, 4 }), v.scale(2));
    try std.testing.expectEqual(Vec(2, f32).init(.{ 0.5, 1 }), v.scale(0.5));
}

test "append" {
    const v = Vec(2, f32).init(.{ 1, 2 });
    const v2 = Vec(3, f32).init(.{ 3, 4, 3 });
    try std.testing.expectEqual(Vec(3, f32).init(.{ 1, 2, 3 }), v.append(3));
    try std.testing.expectEqual(Vec(5, f32).init(.{ 3, 4, 3, 3, 3 }), v2.append(3).append(3));
}

test "appendVec" {
    const v = Vec(2, f32).init(.{ 1, 2 });
    const v2 = Vec(3, f32).init(.{ 3, 4, 3 });
    try std.testing.expectEqual(Vec(5, f32).init(.{ 1, 2, 3, 4, 3 }), v.appendVec(v2));
}

test "normAdv" {
    const v = Vec(2, f64).init(.{ 1, 0 });
    try std.testing.expectEqual(@as(f32, 1.0), v.normAdv(32));
    const v2 = Vec(2, f16).init(.{ 1, 2 });
    const result = v2.normAdv(64);
    try std.testing.expect(@TypeOf(result) == f64);
    const expected = 2.2360679774997896964091736687;
    try std.testing.expectEqual(@as(f16, expected), v2.normAdv(16));
    try std.testing.expectEqual(@as(f32, expected), v2.normAdv(32));
    try std.testing.expectEqual(@as(f64, expected), v2.normAdv(64));
    const v3 = Vec(2, i8).init(.{ 1, 2 });
    try std.testing.expect(@TypeOf(v3.normAdv(64)) == f64);
    try std.testing.expectEqual(@as(f16, expected), v3.normAdv(16));
    try std.testing.expectEqual(@as(f32, expected), v3.normAdv(32));
    try std.testing.expectEqual(@as(f64, expected), v3.normAdv(64));
    const v4 = Vec(2, u8).init(.{ 1, 2 });
    try std.testing.expect(@TypeOf(v4.normAdv(64)) == f64);
    try std.testing.expectEqual(@as(f16, expected), v4.normAdv(16));
    try std.testing.expectEqual(@as(f32, expected), v4.normAdv(32));
    try std.testing.expectEqual(@as(f64, expected), v4.normAdv(64));
}

test "angleAdv" {
    const v1 = Vec(2, f32).init(.{ 1, 0 });
    const v2 = Vec(2, f32).init(.{ 0, 1 });
    const expected: f64 = @as(f64, std.math.pi) / @as(f64, 2);
    try std.testing.expectApproxEqAbs(expected, v1.angleAdv(v2, 32), 0.0000001);
    try std.testing.expectApproxEqAbs(expected, v1.angleAdv(v2, 64), 0.00000000001);
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
    const v = Vec2{ .items = .{ 1, 2 } };
    try std.testing.expectEqual(@as(i32, 3), v.sum());
    try std.testing.expectEqual(@as(i32, 1), v.x());
    try std.testing.expectEqual(@as(i32, 2), v.y());
    const v2 = Vec2{ .items = .{ 1, 0 } };
    try std.testing.expectEqual(@as(i32, 1), v2.norm());
    try std.testing.expectEqual(@as(i32, 1), v2.normalize().norm());
    const v3 = Vec2{ .items = .{ 0, 1 } };
    try std.testing.expectEqual(@as(i32, 0), v3.dot(v2));
    try std.testing.expectEqual(v2, v2.reflect(v3));
}

test "swizzle" {
    const v = Vec(2, f32).init(.{ 1, 2 });
    try std.testing.expectEqual(@as(f32, 2), v.sw("yx").x());
    try std.testing.expectEqual(@as(f32, 1), v.sw("yx").y());
    const v2 = Vec(3, f32).init(.{ 1, 2, 3 });
    const v2_expected = Vec(3, f32).init(.{ 2, 3, 1 });
    try std.testing.expectEqual(v2_expected, v2.sw("yzx"));
}
