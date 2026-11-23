const std = @import("std");
const vec = @import("root.zig").vec;
const matrix = @import("root.zig").matrix;
const turn = @import("root.zig").turn;

/// Components are ordered by the number of axes in their name, then alphabetically,
/// so in 3D they are `1, XY, XZ, YZ` and in 4D `1, XY, XZ, XW, YZ, YW, ZW, XYZW`.
pub fn Rotor(comptime T: type, comptime dimension_count_: usize) type {
    if (dimension_count_ == 0) @compileError("rotor requires at least one dimension");

    return extern struct {
        const Self = @This();

        v: [blade_count]T,

        pub const dimension_count: comptime_int = dimension_count_;
        pub const blade_count: comptime_int = 1 << (dimension_count - 1);
        pub const identity: Self = blk: {
            var result: Self = .{ .v = @splat(0) };
            result.v[0] = 1;
            break :blk result;
        };

        /// Each component as a bitmask of its axes, X = 1, Y = 2, Z = 4, so XZ = 0b101.
        const blades: [blade_count]usize = blk: {
            var result: [blade_count]usize = undefined;
            var index: usize = 0;
            for (0..dimension_count + 1) |grade| {
                if (grade % 2 != 0) continue;
                for (0..1 << dimension_count) |i| {
                    const reversed: usize = (1 << dimension_count) - 1 - i;
                    const blade = @bitReverse(reversed) >> (@bitSizeOf(usize) - dimension_count);
                    if (@popCount(blade) != grade) continue;
                    result[index] = blade;
                    index += 1;
                }
            }
            break :blk result;
        };

        const index_from_blade: [1 << dimension_count]usize = blk: {
            var result: [1 << dimension_count]usize = @splat(0);
            for (blades, 0..) |blade, i| result[blade] = i;
            break :blk result;
        };

        /// Sign of the geometric product of any two basis blades.
        const product_signs: [1 << dimension_count][1 << dimension_count]T = blk: {
            @setEvalBranchQuota(1000 + 4 * (1 << (3 * dimension_count)));
            var result: [1 << dimension_count][1 << dimension_count]T = undefined;
            for (0..1 << dimension_count) |a| {
                for (0..1 << dimension_count) |b| {
                    var swap_count = 0;
                    var shifted = a >> 1;
                    while (shifted != 0) : (shifted >>= 1) swap_count += @popCount(shifted & b);
                    result[a][b] = if (swap_count % 2 == 0) 1 else -1;
                }
            }
            break :blk result;
        };

        const reverse_signs: [blade_count]T = blk: {
            var result: [blade_count]T = undefined;
            for (blades, 0..) |blade, i| result[i] = if (@popCount(blade) % 4 == 0) 1 else -1;
            break :blk result;
        };

        /// Rotation in the plane spanned by `from` and `to`, turning `from` towards `to`.
        /// Assume `from` and `to` are not parallel.
        pub fn fromPlaneAngle(from: [dimension_count]T, to: [dimension_count]T, angle_turns: T) Self {
            if (dimension_count < 2) @compileError("fromPlaneAngle requires at least 2 dimensions");
            const half_angle_turns = angle_turns * 0.5;
            var result = vecProduct(from, to);
            result.v[0] = 0;
            result = result.scalarMul(-turn.sin(half_angle_turns) / result.norm());
            result.v[0] = turn.cos(half_angle_turns);
            return result;
        }

        /// Shortest rotation turning the direction of `from` into the direction of `to`.
        /// Assume `from` and `to` are not opposite.
        pub fn fromRotationBetween(from: [dimension_count]T, to: [dimension_count]T) Self {
            var result = vecProduct(to, from);
            result.v[0] += std.math.sqrt(vec.normSquared(from) * vec.normSquared(to));
            return result.normalize();
        }

        pub fn fromAxisAngle(axis: [3]T, angle_turns: T) Self {
            if (dimension_count != 3) @compileError("fromAxisAngle requires 3 dimensions");
            const half_angle_turns = angle_turns * 0.5;
            const axis_scaled = vec.scale(vec.normalize(axis), turn.sin(half_angle_turns));
            return .{ .v = .{ turn.cos(half_angle_turns), -axis_scaled[2], axis_scaled[1], -axis_scaled[0] } };
        }

        /// Returned angle is in the range [0, 1].
        pub fn axisAngle(self: Self) struct { axis: [3]T, angle_turns: T } {
            if (dimension_count != 3) @compileError("axisAngle requires 3 dimensions");
            const axis_scaled = [3]T{ -self.v[3], self.v[2], -self.v[1] };
            const sin_half = vec.norm(axis_scaled);
            const angle_turns = 2.0 * turn.atan2(sin_half, self.v[0]);
            if (sin_half == 0) return .{ .axis = .{ 1, 0, 0 }, .angle_turns = angle_turns };
            return .{ .axis = vec.scale(axis_scaled, 1.0 / sin_half), .angle_turns = angle_turns };
        }

        pub fn fromEuler(pitch_turns: T, yaw_turns: T, roll_turns: T) Self {
            if (dimension_count != 3) @compileError("fromEuler requires 3 dimensions");
            const x = [3]T{ 1, 0, 0 };
            const y = [3]T{ 0, 1, 0 };
            const z = [3]T{ 0, 0, 1 };
            const pitch = fromPlaneAngle(y, z, pitch_turns);
            const yaw = fromPlaneAngle(z, x, yaw_turns);
            const roll = fromPlaneAngle(x, y, roll_turns);
            return roll.mul(yaw).mul(pitch);
        }

        pub fn euler(self: Self) struct { pitch_turns: T, yaw_turns: T, roll_turns: T } {
            if (dimension_count != 3) @compileError("euler requires 3 dimensions");
            const r = self.normalize();
            const s = r.v[0];
            const xy = r.v[1];
            const xz = r.v[2];
            const yz = r.v[3];
            const sin_yaw = 2.0 * (s * xz - xy * yz);

            if (@abs(sin_yaw) >= 1.0 - 1e-6) {
                const sign: T = if (sin_yaw >= 0) 1.0 else -1.0;
                return .{
                    .pitch_turns = sign * 2.0 * turn.atan2(yz, s),
                    .yaw_turns = sign * 0.25,
                    .roll_turns = 0,
                };
            }

            return .{
                .pitch_turns = turn.atan2(-2.0 * (s * yz + xy * xz), 1.0 - 2.0 * (yz * yz + xz * xz)),
                .yaw_turns = turn.asin(std.math.clamp(sin_yaw, @as(T, -1.0), @as(T, 1.0))),
                .roll_turns = turn.atan2(-2.0 * (s * xy + xz * yz), 1.0 - 2.0 * (xz * xz + xy * xy)),
            };
        }

        /// Uses the top left `dimension_count` square of `m`.
        /// Assume it is a rotation matrix.
        pub fn fromMat(m: anytype) Self {
            const M = @TypeOf(m);
            if (M.row_count < dimension_count or M.column_count < dimension_count) {
                @compileError("fromMat requires at least a dimension_count square matrix");
            }

            var columns: [dimension_count][dimension_count]T = undefined;
            inline for (0..dimension_count) |col| {
                inline for (0..dimension_count) |row| columns[col][row] = m.at(row, col);
            }

            var normals: [2 * dimension_count][dimension_count]T = undefined;
            var normal_count: usize = 0;
            for (0..dimension_count) |i| {
                var normal: [dimension_count]T = @splat(0);
                for (i..dimension_count) |row| normal[row] = columns[i][row];
                normal[i] += if (normal[i] >= 0) vec.norm(normal) else -vec.norm(normal);
                normal = vec.normalize(normal);
                for (i..dimension_count) |col| columns[col] = vec.reflect(columns[col], normal);
                normals[normal_count] = normal;
                normal_count += 1;
            }
            for (0..dimension_count) |i| {
                if (columns[i][i] > 0) continue;
                normals[normal_count] = @splat(0);
                normals[normal_count][i] = 1;
                normal_count += 1;
            }

            var result: Self = .identity;
            var i: usize = 0;
            while (i + 1 < normal_count) : (i += 2) result = result.mul(vecProduct(normals[i], normals[i + 1]));
            result = result.normalize();
            return if (result.v[0] < 0) result.negate() else result;
        }

        /// Square rotation matrix, the rest of the matrix is identity.
        /// Assume the rotor is normalized.
        pub fn mat(self: Self, comptime layout: matrix.Layout, comptime mat_dimension_count: usize) matrix.Mat(layout, T, mat_dimension_count, mat_dimension_count) {
            if (mat_dimension_count < dimension_count) @compileError("mat requires at least a dimension_count square matrix");
            const coefficients: [dimension_count][dimension_count][blade_count][blade_count]T = comptime blk: {
                @setEvalBranchQuota(1000 + 4 * dimension_count * dimension_count * blade_count * blade_count);
                var result: [dimension_count][dimension_count][blade_count][blade_count]T = @splat(@splat(@splat(@splat(0))));
                for (0..dimension_count) |col| {
                    for (blades, 0..) |a, i| {
                        for (blades, 0..) |b, j| {
                            const blade = a ^ (1 << col) ^ b;
                            if (@popCount(blade) != 1) continue;
                            const sign = product_signs[a][1 << col] * product_signs[a ^ (1 << col)][b] * reverse_signs[j];
                            result[@ctz(blade)][col][@min(i, j)][@max(i, j)] += sign;
                        }
                    }
                }
                break :blk result;
            };
            var result: matrix.Mat(layout, T, mat_dimension_count, mat_dimension_count) = .identity;
            inline for (0..dimension_count) |col| {
                inline for (0..dimension_count) |row| {
                    var ones: T = -0.0;
                    var twos: T = -0.0;
                    inline for (0..blade_count) |i| {
                        inline for (i..blade_count) |j| {
                            const coefficient = coefficients[row][col][i][j];
                            if (@abs(coefficient) == 1) ones += coefficient * self.v[i] * self.v[j];
                            if (@abs(coefficient) == 2) twos += coefficient * 0.5 * self.v[i] * self.v[j];
                        }
                    }
                    result.put(row, col, ones + 2 * twos);
                }
            }
            return result;
        }

        /// Applies `other` first, then `self`.
        pub fn mul(self: Self, other: Self) Self {
            var result: Self = .{ .v = @splat(-0.0) };
            inline for (blades, 0..) |a, i| {
                inline for (blades, 0..) |b, j| {
                    result.v[index_from_blade[a ^ b]] += product_signs[a][b] * self.v[i] * other.v[j];
                }
            }
            return result;
        }

        pub inline fn selfMul(self: *Self, other: Self) void {
            self.* = self.mul(other);
        }

        pub fn add(self: Self, other: Self) Self {
            return .{ .v = vec.add(self.v, other.v) };
        }

        pub fn sub(self: Self, other: Self) Self {
            return .{ .v = vec.sub(self.v, other.v) };
        }

        pub fn scalarMul(self: Self, scalar: T) Self {
            return .{ .v = vec.scale(self.v, scalar) };
        }

        pub fn negate(self: Self) Self {
            return .{ .v = vec.negate(self.v) };
        }

        /// Inverse rotation of a normalized rotor.
        pub fn reverse(self: Self) Self {
            return .{ .v = vec.mul(self.v, reverse_signs) };
        }

        pub fn normSquared(self: Self) T {
            return vec.dot(self.v, self.v);
        }

        pub fn norm(self: Self) T {
            return std.math.sqrt(self.normSquared());
        }

        pub fn normalize(self: Self) Self {
            const n = self.norm();
            if (n < 1e-15) return .identity;
            return .{ .v = vec.scale(self.v, 1.0 / n) };
        }

        /// Assume `self` is a scaled rotor, as `reverse` only inverts those.
        pub fn inverse(self: Self) Self {
            const norm_squared = self.normSquared();
            if (norm_squared < 1e-15) return .identity;
            return .{ .v = vec.scale(self.reverse().v, 1.0 / norm_squared) };
        }

        pub fn dot(self: Self, other: Self) T {
            return vec.dot(self.v, other.v);
        }

        /// Assume the rotor is normalized.
        pub fn rotateVec(self: Self, point: [dimension_count]T) [dimension_count]T {
            if (dimension_count == 3) {
                const axis = [3]T{ -self.v[3], self.v[2], -self.v[1] };
                const t = vec.scale(vec.cross(axis, point), 2);
                return vec.add(vec.add(point, vec.scale(t, self.v[0])), vec.cross(axis, t));
            }
            var product: [1 << dimension_count]T = @splat(-0.0);
            inline for (blades, 0..) |a, i| {
                inline for (0..dimension_count) |axis| {
                    product[a ^ (1 << axis)] += product_signs[a][1 << axis] * self.v[i] * point[axis];
                }
            }
            var result: [dimension_count]T = @splat(-0.0);
            inline for (0..1 << dimension_count) |a| {
                if (@popCount(a) % 2 == 0) continue;
                inline for (blades, 0..) |b, j| {
                    if (@popCount(a ^ b) != 1) continue;
                    const sign = comptime product_signs[a][b] * reverse_signs[j];
                    result[@ctz(a ^ b)] += sign * product[a] * self.v[j];
                }
            }
            return result;
        }

        pub fn nlerp(self: Self, other: Self, t: T) Self {
            var target = other;
            if (self.dot(target) < 0) target = target.negate();
            return (Self{ .v = vec.add(vec.scale(self.v, 1.0 - t), vec.scale(target.v, t)) }).normalize();
        }

        pub fn slerp(self: Self, other: Self, t: T) Self {
            var target = other;
            var cos_angle = self.dot(target);
            if (cos_angle < 0) {
                target = target.negate();
                cos_angle = -cos_angle;
            }
            if (cos_angle > 1.0 - 1e-6) return self.nlerp(target, t);

            const angle_turns = turn.acos(cos_angle);
            const sin_angle = turn.sin(angle_turns);
            const weight_self = turn.sin((1.0 - t) * angle_turns) / sin_angle;
            const weight_target = turn.sin(t * angle_turns) / sin_angle;
            return .{ .v = vec.add(vec.scale(self.v, weight_self), vec.scale(target.v, weight_target)) };
        }

        pub fn eql(self: Self, other: Self) bool {
            return std.mem.eql(T, &self.v, &other.v);
        }

        pub fn approxEql(self: Self, other: Self, tolerance: T) bool {
            return vec.approxEql(self.v, other.v, tolerance);
        }

        /// `r` and `-r` represent the same rotation.
        pub fn rotationEql(self: Self, other: Self, tolerance: T) bool {
            return self.approxEql(other, tolerance) or self.negate().approxEql(other, tolerance);
        }

        pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.writeAll("Rotor(");
            for (self.v, 0..) |value, i| {
                if (i != 0) try writer.writeAll(", ");
                try writer.print("{d}", .{value});
            }
            try writer.writeByte(')');
        }

        fn vecProduct(a: [dimension_count]T, b: [dimension_count]T) Self {
            var result: Self = .{ .v = @splat(0) };
            result.v[0] = vec.dot(a, b);
            inline for (0..dimension_count) |i| {
                inline for (i + 1..dimension_count) |j| {
                    result.v[index_from_blade[(1 << i) | (1 << j)]] = a[i] * b[j] - a[j] * b[i];
                }
            }
            return result;
        }
    };
}

test "arithmetic" {
    const R = Rotor(f32, 3);
    const a: R = .{ .v = .{ 1, 2, 3, 4 } };
    const b: R = .{ .v = .{ 5, 6, 7, 8 } };
    try std.testing.expect(a.add(b).eql(.{ .v = .{ 6, 8, 10, 12 } }));
    try std.testing.expect(b.sub(a).eql(.{ .v = .{ 4, 4, 4, 4 } }));
    try std.testing.expect(a.scalarMul(2).eql(.{ .v = .{ 2, 4, 6, 8 } }));
    try std.testing.expect(a.negate().eql(.{ .v = .{ -1, -2, -3, -4 } }));
    try std.testing.expect(a.reverse().eql(.{ .v = .{ 1, -2, -3, -4 } }));
    try std.testing.expectEqual(@as(f32, 70), a.dot(b));
    try std.testing.expectEqual(@as(f32, 30), a.normSquared());
    try std.testing.expect(a.mul(a.inverse()).approxEql(.identity, 1e-6));
}

test "rotateVec" {
    const R = Rotor(f32, 3);
    const r: R = .fromAxisAngle(.{ 0, 0, 1 }, 0.25);
    try expectVecApproxEql(&.{ 0, 1, 0 }, &r.rotateVec(.{ 1, 0, 0 }));
    try std.testing.expect(r.approxEql(.fromPlaneAngle(.{ 1, 0, 0 }, .{ 0, 1, 0 }, 0.25), 1e-6));

    const m = r.mat(.cm, 3);
    try expectVecApproxEql(&m.mulVec(.{ 1, 2, 3 }), &r.rotateVec(.{ 1, 2, 3 }));
}

test "fromRotationBetween" {
    const R = Rotor(f32, 3);
    const r: R = .fromRotationBetween(.{ 2, 0, 0 }, .{ 0, 3, 0 });
    try std.testing.expect(r.approxEql(.fromPlaneAngle(.{ 1, 0, 0 }, .{ 0, 1, 0 }, 0.25), 1e-6));

    const from = [3]f32{ 1, 2, 3 };
    const to = [3]f32{ -2, 0.5, 1 };
    try expectVecApproxEql(&vec.normalize(to), &vec.normalize(R.fromRotationBetween(from, to).rotateVec(from)));

    const R4 = Rotor(f32, 4);
    const from4 = [4]f32{ 1, 2, 3, 4 };
    const to4 = [4]f32{ 4, -3, 2, 1 };
    const r4 = R4.fromRotationBetween(from4, to4);
    try expectVecApproxEql(&vec.normalize(to4), &vec.normalize(r4.rotateVec(from4)));
    try expectVecApproxEql(&.{ 1, 0, 0, 0 }, &R4.fromRotationBetween(.{ 0, 1, 0, 0 }, .{ 0, 0, 1, 0 }).rotateVec(.{ 1, 0, 0, 0 }));
}

test "matrix roundtrip" {
    const R = Rotor(f32, 3);
    const r = R.fromAxisAngle(.{ 1, 2, 3 }, 0.4);
    try std.testing.expect(R.fromMat(r.mat(.cm, 4)).rotationEql(r, 1e-5));
    try std.testing.expect(R.fromMat(r.mat(.rm, 3)).rotationEql(r, 1e-5));
    try std.testing.expect(R.fromMat(R.identity.mat(.cm, 3)).approxEql(.identity, 1e-6));
}

test "axis angle roundtrip" {
    const R = Rotor(f32, 3);
    const r = R.fromAxisAngle(.{ 0, 3, 4 }, 0.2);
    const axis_angle = r.axisAngle();
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), axis_angle.angle_turns, 1e-6);
    try expectVecApproxEql(&.{ 0, 0.6, 0.8 }, &axis_angle.axis);
}

test "euler roundtrip" {
    const R = Rotor(f32, 3);
    try std.testing.expect(R.fromEuler(0.1, 0, 0).approxEql(.fromAxisAngle(.{ 1, 0, 0 }, 0.1), 1e-6));
    const r = R.fromEuler(0.05, -0.11, 0.18);
    const e = r.euler();
    try std.testing.expectApproxEqAbs(@as(f32, 0.05), e.pitch_turns, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, -0.11), e.yaw_turns, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 0.18), e.roll_turns, 1e-6);
}

test "slerp" {
    const R = Rotor(f32, 3);
    const a: R = .identity;
    const b = R.fromAxisAngle(.{ 0, 1, 0 }, 0.16);
    try std.testing.expect(a.slerp(b, 0.5).rotationEql(.fromAxisAngle(.{ 0, 1, 0 }, 0.08), 1e-5));
    try std.testing.expect(a.slerp(b, 0).rotationEql(a, 1e-5));
    try std.testing.expect(a.slerp(b, 1).rotationEql(b, 1e-5));
    try std.testing.expect(a.nlerp(b, 1).rotationEql(b, 1e-5));
}

test "2d" {
    const R = Rotor(f32, 2);
    const r: R = .fromPlaneAngle(.{ 1, 0 }, .{ 0, 1 }, 0.25);
    try expectVecApproxEql(&.{ 0, 1 }, &r.rotateVec(.{ 1, 0 }));
    try std.testing.expect(R.fromMat(r.mat(.rm, 2)).rotationEql(r, 1e-6));
}

test "4d" {
    const R = Rotor(f32, 4);
    const a: R = .fromPlaneAngle(.{ 1, 0, 0, 0 }, .{ 0, 1, 0, 0 }, 0.1);
    const b: R = .fromPlaneAngle(.{ 0, 0, 1, 0 }, .{ 0, 0, 0, 1 }, 0.25);
    const c: R = .fromPlaneAngle(.{ 1, 2, 0, -1 }, .{ 0, 1, 3, 1 }, 0.2);
    const r = a.mul(b).mul(c);
    try std.testing.expect(@abs(r.v[7]) > 0.1);
    try expectVecApproxEql(&.{ 0, 0, 0, 1 }, &b.rotateVec(.{ 0, 0, 1, 0 }));

    const m = a.mat(.cm, 4).mul(b.mat(.cm, 4)).mul(c.mat(.cm, 4));
    try std.testing.expect(r.mat(.cm, 4).approxEql(m, 1e-5));
    try std.testing.expect(R.fromMat(r.mat(.cm, 5)).rotationEql(r, 1e-5));
    try std.testing.expect(r.mul(r.inverse()).approxEql(.identity, 1e-6));
}

fn expectVecApproxEql(expected: []const f32, actual: []const f32) !void {
    for (expected, actual) |e, a| try std.testing.expectApproxEqAbs(e, a, 1e-5);
}
