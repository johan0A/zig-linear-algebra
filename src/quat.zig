const std = @import("std");
const vector = @import("vector.zig");
const meta = @import("meta.zig");

const Quat4f32 = @Vector(4, f32);
const Quat4f64 = @Vector(4, f64);

fn map_to_vector(a: anytype) @Vector(meta.array_vector_length(@TypeOf(a)), std.meta.Child(@TypeOf(a))) {
    const type_info = @typeInfo(@TypeOf(a));
    if (type_info != .vector and type_info != .array) @compileError("Expected vector or array type, got: " ++ @typeName(@TypeOf(a)));
    return a;
}

fn Quat(comptime T: type) type {
    return @Vector(4, T);
}

pub fn identity(comptime T: type) @Vector(4, T) {
    return .{ 0, 0, 0, 1 };
}

pub fn zero(comptime T: type) @Vector(4, T) {
    return .{ 0, 0, 0, 0 };
}

pub fn x_axis(comptime T: type) @Vector(3, T) {
    return .{ 1, 0, 0 };
}

pub fn y_axis(comptime T: type) @Vector(3, T) {
    return .{ 0, 1, 0 };
}

pub fn z_axis(comptime T: type) @Vector(3, T) {
    return .{ 0, 0, 1 };
}

// Create quaternion that rotates a vector from the direction of inFrom to the direction of inTo along the shortest path
// @see https://www.euclideanspace.com/maths/algebra/vectors/angleBetween/index.htm
pub fn from_to(from: anytype, to: @TypeOf(from)) @Vector(4, std.meta.Child(@TypeOf(from))) {
    if (meta.array_vector_length(@TypeOf(from)) != 3) @compileError("Expected a 3D vector type got: " ++ @typeName(@TypeOf(from)));
    //Uses (inFrom = v1, inTo = v2):

    //angle = arcos(v1 . v2 / |v1||v2|)
    //axis = normalize(v1 x v2)

    //Quaternion is then:

    //s = sin(angle / 2)
    //x = axis.x * s
    //y = axis.y * s
    //z = axis.z * s
    //w = cos(angle / 2)

    //Using identities:

    //sin(2 * a) = 2 * sin(a) * cos(a)
    //cos(2 * a) = cos(a)^2 - sin(a)^2
    //sin(a)^2 + cos(a)^2 = 1

    //This reduces to:

    //x = (v1 x v2).x
    //y = (v1 x v2).y
    //z = (v1 x v2).z
    //w = |v1||v2| + v1 . v2

    //which then needs to be normalized because the whole equation was multiplied by 2 cos(angle / 2)
    const len_v1_v2 = std.math.sqrt(vector.norm_sqr(from) * vector.norm_sqr(to));
    const w = len_v1_v2 + vector.dot(from, to);
    if (w == 0.0) {
        if (len_v1_v2 == 0.0) {
            return identity(std.meta.Child(@TypeOf(from)));
        } else {
            const norm_perp = vector.norm_perpendicular(from);
            return .{ norm_perp[0], norm_perp[1], norm_perp[2], 0 };
        }
    }
    const v = vector.cross(from, to);
    return vector.normalize(@Vector(4, std.meta.Child(@TypeOf(from))){ v[0], v[1], v[2], w });
}

pub fn get_twist(inAxis: anytype) @Vector(4, std.meta.Child(@TypeOf(inAxis))) {
    if (meta.array_vector_length(@TypeOf(inAxis)) != 4) @compileError("vector must have four elements for get_twist() to be defined");

    const dir = vector.dot(vector.extract(inAxis, 3), inAxis) * inAxis;
    const twist: @Vector(4, std.meta.Child(@TypeOf(inAxis))) = .{ dir[0], dir[1], dir[2], inAxis[3] };
    const twist_len = vector.norm_sqr(twist);
    if (twist_len == 0.0) {
        return twist / @as(@Vector(4, std.meta.Child(@TypeOf(inAxis))), @splat(std.math.sqrt(twist_len)));
    }
    return identity(std.meta.Child(@TypeOf(inAxis)));
}

//TODO: optimize with simd
pub fn mul(a: anytype, b: @TypeOf(a)) @TypeOf(a) {
    if (meta.array_vector_length(@TypeOf(a)) != 4) @compileError("quaternion must have 4 elements");
    const inner_a = map_to_vector(a);
    const inner_b = map_to_vector(b);

    const lx = inner_a[0];
    const ly = inner_a[1];
    const lz = inner_a[2];
    const lw = inner_a[3];

    const rx = inner_b[0];
    const ry = inner_b[1];
    const rz = inner_b[2];
    const rw = inner_b[3];

    return @TypeOf(a){ lw * rx + lx * rw + ly * rz - lz * ry, lw * ry - lx * rz + ly * rw + lz * rx, lw * rz + lx * ry - ly * rx + lz * rw, lw * rw - lx * rx - ly * ry - lz * rz };
}

pub fn norm(q: anytype) std.meta.Float(@bitSizeOf(std.meta.Child(@TypeOf(q)))) {
    return vector.norm(q);
}

//pub fn to_axis_angle(q: anytype) struct {
//    axis: @Vector(3, info(@TypeOf(q)).child),
//    angle: info(@TypeOf(q)).child,
//} {
//    if (info(@TypeOf(q)).len != 4) @compileError("vector must have four elements for to_axis_angle() to be defined");
//    const qw_clamped = std.math.clamp(q[3], -1.0, 1.0);
//    const angle = 2.0 * std.math.acos(qw_clamped);
//    const s = std.math.sqrt(1.0 - qw_clamped * qw_clamped);
//    if (s < 0.001) { // If s is close to zero then direction of axis is not important
//        return .{ .axis = .{ 1, 0, 0 }, .angle = angle };
//    } else {
//        return .{ .axis = .{ q[0] / s, q[1] / s, q[2] / s }, .angle = angle };
//    }
//}

pub fn conjugate(q: anytype) @TypeOf(q) {
    if (meta.array_vector_length(@TypeOf(q)) != 4) @compileError("vector must have four elements for conjugate() to be defined");
    return q * @Vector(4, std.meta.Child(@TypeOf(q))){ -1, -1, -1, 1 };
}

pub fn inverse(q: anytype) @TypeOf(q) {
    if (meta.array_vector_length(@TypeOf(q)) != 4) @compileError("vector must have four elements for inverse() to be defined");
    return conjugate(q) / @as(@TypeOf(q), @splat(vector.norm(q)));
}

pub fn slerp(a: anytype, b: anytype, factor: std.meta.Child(@TypeOf(a))) Quat(std.meta.Child(@TypeOf(a))) {
    if (std.meta.Child(@TypeOf(a)) != std.meta.Child(@TypeOf(b))) @compileError("arg1 and arg2 must be of the same child type");
    if (meta.array_vector_length(@TypeOf(a)) != 4) @compileError("quaternion must have 4 elements");
    if (meta.array_vector_length(@TypeOf(b)) != 4) @compileError("quaternions must have 4 elements");
    const inner_a = map_to_vector(a);
    const inner_b = map_to_vector(b);
    const delta: std.meta.Child(@TypeOf(a)) = 0.0001;

    var sign_scale1: std.meta.Child(@TypeOf(a)) = 1.0;
    var cos_omega = vector.dot(inner_a, inner_b);

    if (cos_omega < 0.0) {
        cos_omega = -cos_omega;
        sign_scale1 = -1.0;
    }

    // Calculate coefficients
    var scale0: std.meta.Child(@TypeOf(a)) = undefined;
    var scale1: std.meta.Child(@TypeOf(a)) = undefined;
    if (1.0 - cos_omega > delta) {
        // Standard case (slerp)
        const omega = std.math.acos(cos_omega);
        const sin_omega = std.math.sin(omega);
        scale0 = std.math.sin((1.0 - factor) * omega) / sin_omega;
        scale1 = sign_scale1 * std.math.sin(factor * omega) / sin_omega;
    } else {
        // Quaternions are very close so we can do a linear interpolation
        scale0 = 1.0 - factor;
        scale1 = sign_scale1 * factor;
    }

    return vector.normalize(@as(Quat(std.meta.Child(@TypeOf(a))), @splat(scale0)) * inner_a +
        @as(Quat(std.meta.Child(@TypeOf(a))), @splat(scale1)) * inner_b);
}

pub fn lerp(a: anytype, b: anytype, factor: std.meta.Child(@TypeOf(a))) Quat(std.meta.Child(@TypeOf(a))) {
    if (std.meta.Child(@TypeOf(a)) != std.meta.Child(@TypeOf(b))) @compileError("arg1 and arg2 must be of the same child type");
    if (meta.array_vector_length(@TypeOf(a)) != 4) @compileError("quaternion must have 4 elements");
    if (meta.array_vector_length(@TypeOf(b)) != 4) @compileError("quaternions must have 4 elements");

    return @as(Quat(std.meta.Child(@TypeOf(a))), @splat(1.0 - factor)) * map_to_vector(a) +
        @as(Quat(std.meta.Child(@TypeOf(a))), @splat(factor)) * map_to_vector(b);
}

pub fn from_eular_angles(inAngles: anytype) @Vector(4, std.meta.Child(@TypeOf(inAngles))) {
    if (meta.array_vector_length(@TypeOf(inAngles)) != 3) @compileError("vector must have three elements for from_eular_angles() to be defined");

    const half = @as(@TypeOf(inAngles), @splat(0.5)) * inAngles;
    const res = vector.sin_cos(half);

    const cx = res.cos_out[0];
    const sx = res.sin_out[0];
    const cy = res.cos_out[1];
    const sy = res.sin_out[1];
    const cz = res.cos_out[2];
    const sz = res.sin_out[2];

    return .{ cz * sx * cy - sz * cx * sy, cz * cx * sy + sz * sx * cy, sz * cx * cy - cz * sx * sy, cz * cx * cy + sz * sx * sy };
}

pub fn from_rotation(axis: anytype, angle: std.meta.Child(@TypeOf(axis))) @Vector(4, std.meta.Child(@TypeOf(axis))) {
    if (meta.array_vector_length(@TypeOf(axis)) != 3) @compileError("axis must be a 3D vector");
    const in_axis = map_to_vector(axis);
    std.debug.assert(vector.is_normalized_default(in_axis));
    return .{ 
        in_axis[0] * std.math.sin(angle * 0.5), 
        in_axis[1] * std.math.sin(angle * 0.5), 
        in_axis[2] * std.math.sin(angle * 0.5), 
        std.math.cos(angle * 0.5) };
}

pub fn to_eular_angles(q: anytype) @Vector(3, std.meta.Child(@TypeOf(q))) {
    if (meta.array_vector_length(@TypeOf(q)) != 4) @compileError("vector must have four elements for to_eular_angles() to be defined");

    const ysqr = q[1] * q[1];

    // roll (x-axis rotation)
    const t0 = 2.0 * (q[3] * q[0] + q[1] * q[2]);
    const t1 = 1.0 - 2.0 * (q[0] * q[0] + ysqr);
    const roll = std.math.atan2(t0, t1);

    // pitch (y-axis rotation)
    var t2 = 2.0 * (q[3] * q[1] - q[2] * q[0]);
    t2 = if (t2 > 1.0) 1.0 else if (t2 < -1.0) -1.0 else t2;
    const pitch = std.math.asin(t2);

    // yaw (z-axis rotation)
    const t3 = 2.0 * (q[3] * q[2] + q[0] * q[1]);
    const t4 = 1.0 - 2.0 * (ysqr + q[2] * q[2]);
    const yaw = std.math.atan2(t3, t4);

    return .{ roll, pitch, yaw };
}

test from_to {
    try std.testing.expect(vector.is_close_default(from_to(@Vector(3, f32){ 10, 0, 0 }, @Vector(3, f32){ 20, 0, 0 }), identity(f32)));
}

test mul {
    try std.testing.expect(vector.is_close_default(mul(Quat4f32{ 0, 1, 0, 0 }, Quat4f32{ 1, 0, 0, 0 }), Quat4f32{ 0, 0, -1, 0 }));
    try std.testing.expect(vector.is_close_default(mul(Quat4f32{ 1, 0, 0, 0 }, Quat4f32{ 0, 1, 0, 0 }), Quat4f32{ 0, 0, 1, 0 }));
    try std.testing.expect(vector.is_close_default(mul(Quat4f32{ 2, 3, 4, 1 }, Quat4f32{ 6, 7, 8, 5 }), Quat4f32{ 12, 30, 24, -60 }));
}

test slerp {
    const v1 = identity(f32);
    const v2: Quat4f32 = from_rotation(x_axis(f32), 0.99 * std.math.pi);
    try std.testing.expect(vector.is_close_default(slerp(v1, v2, 0.25), from_rotation(x_axis(f32), 0.25 * 0.99 * std.math.pi)));

    const v3 = vector.normalize(Quat4f32{1, 2, 3, 4});
    try std.testing.expect(vector.is_close_default(slerp(v3, -v3, 0.5), v3));
}

test lerp {
    const v1: Quat4f32 = .{ 1, 2, 3, 4 };
    const v2: Quat4f32 = .{ 5, 6, 7, 8 };
    try std.testing.expect(vector.is_close_default(lerp(v1, v2, 0.25), Quat4f32{ 2, 3, 4, 5 }));
}

//test to_eular_angles {
//    var qx: Quat4f32 = from_eular_angles(from_rotation(x_axis(f32), std.math.degreesToRadians(-10)));
//    var qy: Quat4f32 = from_eular_angles(from_rotation(y_axis(f32), std.math.degreesToRadians(-20)));
//    var qz: Quat4f32 = from_eular_angles(from_rotation(z_axis(f32), std.math.degreesToRadians(-30)));
//}
