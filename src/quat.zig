const std = @import("std");
const vector = @import("vector.zig");
const meta = @import("meta.zig");

const Quat4f32 = @Vector(4, f32);
const Quat4f64 = @Vector(4, f64);

pub fn identity(comptime T: type) @Vector(4, T) {
    return .{ 0, 0, 0, 1 };
}

pub fn zero(comptime T: type) @Vector(4, T) {
    return .{ 0, 0, 0, 0 };
}

fn map_to_vector(vec: anytype) @Vector(meta.array_vector_length(@TypeOf(vec)), std.meta.Child(@TypeOf(vec))) {
    const type_info = @typeInfo(@TypeOf(vec));
    if (type_info != .vector and type_info != .array) @compileError("Expected vector or array type, got: " ++ @typeName(@TypeOf(vec)));
    return vec;
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
    return vector.norm(@Vector(4, std.meta.Child(@TypeOf(from))){ v[0], v[1], v[2], w });
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

pub fn norm(q: anytype) @TypeOf(q) {
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
