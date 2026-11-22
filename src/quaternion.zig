const std = @import("std");
const vec = @import("root.zig").vec;
const matrix = @import("root.zig").matrix;
const turn = @import("root.zig").turn;

pub fn Quat(comptime T: type) type {
    return extern struct {
        const Self = @This();

        v: [4]T,

        pub const identity: Self = .{ .v = .{ 0, 0, 0, 1 } };

        pub inline fn init(xv: T, yv: T, zv: T, wv: T) Self {
            return .{ .v = .{ xv, yv, zv, wv } };
        }

        pub inline fn x(self: Self) T {
            return self.v[0];
        }

        pub inline fn y(self: Self) T {
            return self.v[1];
        }

        pub inline fn z(self: Self) T {
            return self.v[2];
        }

        pub inline fn w(self: Self) T {
            return self.v[3];
        }

        pub inline fn imaginary(self: Self) [3]T {
            return .{ self.v[0], self.v[1], self.v[2] };
        }

        pub fn fromAxisAngle(axis: [3]T, angle_turns: T) Self {
            const half = angle_turns * 0.5;
            const s = turn.sin(half);
            const a = vec.normalize(axis);
            return .{ .v = .{
                a[0] * s,
                a[1] * s,
                a[2] * s,
                turn.cos(half),
            } };
        }

        /// Returned angle is in the range [0, 1].
        pub fn axisAngle(self: Self) struct { axis: [3]T, angle_turns: T } {
            const n = self.normalize();
            const w_clamped = std.math.clamp(n.w(), @as(T, -1.0), @as(T, 1.0));
            const angle_turns = 2.0 * turn.acos(w_clamped);
            const sin_half_squared = 1.0 - w_clamped * w_clamped;
            if (sin_half_squared < 1e-8) {
                return .{ .axis = .{ 1, 0, 0 }, .angle_turns = angle_turns };
            }
            const sin_half_inverse: T = 1.0 / std.math.sqrt(sin_half_squared);
            return .{
                .axis = .{ n.x() * sin_half_inverse, n.y() * sin_half_inverse, n.z() * sin_half_inverse },
                .angle_turns = angle_turns,
            };
        }

        pub fn fromEuler(pitch_turns: T, yaw_turns: T, roll_turns: T) Self {
            const hp = pitch_turns * 0.5;
            const hy = yaw_turns * 0.5;
            const hr = roll_turns * 0.5;
            const sp = turn.sin(hp);
            const cp = turn.cos(hp);
            const sy = turn.sin(hy);
            const cy = turn.cos(hy);
            const sr = turn.sin(hr);
            const cr = turn.cos(hr);
            return .{ .v = .{
                cr * cy * sp - sr * sy * cp,
                cr * sy * cp + sr * cy * sp,
                sr * cy * cp - cr * sy * sp,
                cr * cy * cp + sr * sy * sp,
            } };
        }

        pub fn euler(self: Self) struct { pitch_turns: T, yaw_turns: T, roll_turns: T } {
            const n = self.normalize();
            const sin_yaw = 2.0 * (n.w() * n.y() - n.z() * n.x());

            // gimbal lock
            if (@abs(sin_yaw) >= 1.0 - 1e-6) {
                const sign: T = if (sin_yaw >= 0) 1.0 else -1.0;
                return .{
                    .pitch_turns = -sign * 2.0 * turn.atan2(n.x(), n.w()),
                    .yaw_turns = sign * 0.25,
                    .roll_turns = 0,
                };
            }

            return .{
                .pitch_turns = turn.atan2(
                    2.0 * (n.w() * n.x() + n.y() * n.z()),
                    1.0 - 2.0 * (n.x() * n.x() + n.y() * n.y()),
                ),
                .yaw_turns = turn.asin(std.math.clamp(sin_yaw, @as(T, -1.0), @as(T, 1.0))),
                .roll_turns = turn.atan2(
                    2.0 * (n.w() * n.z() + n.x() * n.y()),
                    1.0 - 2.0 * (n.y() * n.y() + n.z() * n.z()),
                ),
            };
        }

        pub fn fromMat(m: anytype) Self {
            const M = @TypeOf(m);
            if (M.row_count < 3 or M.column_count < 3) @compileError("fromMat requires at least a 3x3 matrix");

            const m00 = m.at(0, 0);
            const m01 = m.at(0, 1);
            const m02 = m.at(0, 2);
            const m10 = m.at(1, 0);
            const m11 = m.at(1, 1);
            const m12 = m.at(1, 2);
            const m20 = m.at(2, 0);
            const m21 = m.at(2, 1);
            const m22 = m.at(2, 2);

            const trace = m00 + m11 + m22;

            if (trace > 0) {
                const r = std.math.sqrt(1.0 + trace);
                const s: T = 0.5 / r;
                return .{ .v = .{
                    (m21 - m12) * s,
                    (m02 - m20) * s,
                    (m10 - m01) * s,
                    0.5 * r,
                } };
            } else if (m00 > m11 and m00 > m22) {
                const r = std.math.sqrt(1.0 + m00 - m11 - m22);
                const s: T = 0.5 / r;
                return .{ .v = .{
                    0.5 * r,
                    (m01 + m10) * s,
                    (m02 + m20) * s,
                    (m21 - m12) * s,
                } };
            } else if (m11 > m22) {
                const r = std.math.sqrt(1.0 - m00 + m11 - m22);
                const s: T = 0.5 / r;
                return .{ .v = .{
                    (m01 + m10) * s,
                    0.5 * r,
                    (m12 + m21) * s,
                    (m02 - m20) * s,
                } };
            } else {
                const r = std.math.sqrt(1.0 - m00 - m11 + m22);
                const s: T = 0.5 / r;
                return .{ .v = .{
                    (m02 + m20) * s,
                    (m12 + m21) * s,
                    0.5 * r,
                    (m10 - m01) * s,
                } };
            }
        }

        /// Square rotation matrix, the rest of the matrix is identity.
        pub fn mat(self: Self, comptime layout: matrix.Layout, comptime dimension: usize) matrix.Mat(layout, T, dimension, dimension) {
            if (dimension < 3) @compileError("mat requires at least 3x3");
            const n = self.normalize();

            const xx = n.x() * n.x();
            const yy = n.y() * n.y();
            const zz = n.z() * n.z();
            const xy = n.x() * n.y();
            const xz = n.x() * n.z();
            const yz = n.y() * n.z();
            const wx = n.w() * n.x();
            const wy = n.w() * n.y();
            const wz = n.w() * n.z();

            var result: matrix.Mat(layout, T, dimension, dimension) = .identity;
            result.put(0, 0, 1.0 - 2.0 * (yy + zz));
            result.put(1, 0, 2.0 * (xy + wz));
            result.put(2, 0, 2.0 * (xz - wy));

            result.put(0, 1, 2.0 * (xy - wz));
            result.put(1, 1, 1.0 - 2.0 * (xx + zz));
            result.put(2, 1, 2.0 * (yz + wx));

            result.put(0, 2, 2.0 * (xz + wy));
            result.put(1, 2, 2.0 * (yz - wx));
            result.put(2, 2, 1.0 - 2.0 * (xx + yy));

            return result;
        }

        pub fn mul(self: Self, other: Self) Self {
            return .{ .v = .{
                self.w() * other.x() + self.x() * other.w() + self.y() * other.z() - self.z() * other.y(),
                self.w() * other.y() - self.x() * other.z() + self.y() * other.w() + self.z() * other.x(),
                self.w() * other.z() + self.x() * other.y() - self.y() * other.x() + self.z() * other.w(),
                self.w() * other.w() - self.x() * other.x() - self.y() * other.y() - self.z() * other.z(),
            } };
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
            return .{ .v = -@as(@Vector(4, T), self.v) };
        }

        pub fn conjugate(self: Self) Self {
            return .{ .v = .{ -self.x(), -self.y(), -self.z(), self.w() } };
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
            return .{ .v = self.v / @as(@Vector(4, T), @splat(n)) };
        }

        pub fn inverse(self: Self) Self {
            const norm_squared = self.normSquared();
            if (norm_squared < 1e-15) return .identity;
            return .{ .v = self.conjugate().v / @as(@Vector(4, T), @splat(norm_squared)) };
        }

        pub fn dot(self: Self, other: Self) T {
            return vec.dot(self.v, other.v);
        }

        /// Assume the quaternion is normalized.
        pub fn rotateVec(self: Self, point: [3]T) [3]T {
            const u = self.imaginary();
            const uv = vec.cross(u, point);
            const uuv = vec.cross(u, uv);
            return vec.add(point, vec.add(vec.scale(uv, 2.0 * self.w()), vec.scale(uuv, 2.0)));
        }

        pub fn nlerp(self: Self, other: Self, t: T) Self {
            var b = other;
            // take the shorter path
            if (self.dot(b) < 0) b.v = -@as(@Vector(4, T), b.v);
            const t_splat: @Vector(4, T) = @splat(t);
            const one_minus_t: @Vector(4, T) = @splat(1.0 - t);
            return (Self{ .v = self.v * one_minus_t + b.v * t_splat }).normalize();
        }

        pub fn slerp(self: Self, other: Self, t: T) Self {
            var b = other;
            var d = self.dot(b);
            // take the shorter path
            if (d < 0) {
                b.v = -@as(@Vector(4, T), b.v);
                d = -d;
            }
            // nearly parallel, sin(theta) would divide by ~0
            if (d > 1.0 - 1e-6) return self.nlerp(b, t);

            const theta = std.math.acos(std.math.clamp(d, @as(T, -1.0), @as(T, 1.0)));
            const sin_theta = std.math.sin(theta);
            const s0: T = std.math.sin((1.0 - t) * theta) / sin_theta;
            const s1: T = std.math.sin(t * theta) / sin_theta;
            return .{ .v = self.v * @as(@Vector(4, T), @splat(s0)) + b.v * @as(@Vector(4, T), @splat(s1)) };
        }

        pub fn eql(self: Self, other: Self) bool {
            return std.mem.eql(T, &self.v, &other.v);
        }

        pub fn approxEql(self: Self, other: Self, tolerance: T) bool {
            const difference = @abs(@as(@Vector(4, T), self.v) - @as(@Vector(4, T), other.v));
            return @reduce(.And, difference <= @as(@Vector(4, T), @splat(tolerance)));
        }

        /// `q` and `-q` represent the same rotation.
        pub fn rotationEql(self: Self, other: Self, tolerance: T) bool {
            return self.approxEql(other, tolerance) or self.negate().approxEql(other, tolerance);
        }

        pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("Quat({d}, {d}, {d}, {d})", .{ self.x(), self.y(), self.z(), self.w() });
        }
    };
}

test "Quat arithmetic" {
    const Q = Quat(f32);
    const a: Q = .init(1, 2, 3, 4);
    const b: Q = .init(5, 6, 7, 8);
    try std.testing.expect(a.add(b).eql(.init(6, 8, 10, 12)));
    try std.testing.expect(b.sub(a).eql(.init(4, 4, 4, 4)));
    try std.testing.expect(a.scalarMul(2).eql(.init(2, 4, 6, 8)));
    try std.testing.expect(a.negate().eql(.init(-1, -2, -3, -4)));
    try std.testing.expectEqual(@as(f32, 70), a.dot(b));
    try std.testing.expectEqual(@as(f32, 30), a.normSquared());
    try std.testing.expect(a.mul(a.inverse()).approxEql(.identity, 1e-6));
}

test "Quat rotateVec" {
    const Q = Quat(f32);
    const q: Q = .fromAxisAngle(.{ 0, 0, 1 }, 0.25);
    try expectVecApproxEql(.{ 0, 1, 0 }, q.rotateVec(.{ 1, 0, 0 }));

    const m = q.mat(.cm, 3);
    try expectVecApproxEql(m.mulVec(.{ 1, 2, 3 }), q.rotateVec(.{ 1, 2, 3 }));
}

test "Quat matrix roundtrip" {
    const Q = Quat(f32);
    const q = Q.fromAxisAngle(.{ 1, 2, 3 }, 0.4);
    try std.testing.expect(Q.fromMat(q.mat(.cm, 4)).rotationEql(q, 1e-5));
    try std.testing.expect(Q.fromMat(q.mat(.rm, 3)).rotationEql(q, 1e-5));
}

test "Quat axis angle roundtrip" {
    const Q = Quat(f32);
    const q = Q.fromAxisAngle(.{ 0, 3, 4 }, 0.2);
    const axis_angle = q.axisAngle();
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), axis_angle.angle_turns, 1e-6);
    try expectVecApproxEql(.{ 0, 0.6, 0.8 }, axis_angle.axis);
}

test "Quat euler roundtrip" {
    const Q = Quat(f32);
    const q = Q.fromEuler(0.05, -0.11, 0.18);
    const e = q.euler();
    try std.testing.expectApproxEqAbs(@as(f32, 0.05), e.pitch_turns, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, -0.11), e.yaw_turns, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 0.18), e.roll_turns, 1e-6);
}

test "Quat slerp" {
    const Q = Quat(f32);
    const a: Q = .identity;
    const b = Q.fromAxisAngle(.{ 0, 1, 0 }, 0.16);
    try std.testing.expect(a.slerp(b, 0.5).rotationEql(.fromAxisAngle(.{ 0, 1, 0 }, 0.08), 1e-5));
    try std.testing.expect(a.slerp(b, 0).rotationEql(a, 1e-5));
    try std.testing.expect(a.slerp(b, 1).rotationEql(b, 1e-5));
    try std.testing.expect(a.nlerp(b, 1).rotationEql(b, 1e-5));
}

fn expectVecApproxEql(expected: [3]f32, actual: [3]f32) !void {
    for (expected, actual) |e, a| try std.testing.expectApproxEqAbs(e, a, 1e-5);
}
