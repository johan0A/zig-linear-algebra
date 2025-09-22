const std = @import("std");
const vector = @import("vector.zig");
const info = vector.info;

const Quat4f32 = @Vector(4, f32);
const Quat4f64 = @Vector(4, f64);

pub fn identity(comptime T: type) @Vector(4, T) {
    return .{ 0, 0, 0, 1 };
}

pub fn zero(comptime T: type) @Vector(4, T) {
    return .{ 0, 0, 0, 0 };
}

pub fn from_to(from: anytype, to: @TypeOf(from)) @Vector(4, info(@TypeOf(from)).child) {
    if (info(@TypeOf(from)).len != 3) @compileError("Expected a 3D vector type got: " ++ @typeName(@TypeOf(from)));
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
            return identity(info(@TypeOf(from)).child);
        } else {
            const norm_perp = vector.norm_perpendicular(from);
            return .{ norm_perp[0], norm_perp[1], norm_perp[2], 0 };
        }
    }
    const v = vector.cross(from, to);
    return vector.norm(@Vector(4, info(@TypeOf(from)).child){ v[0], v[1], v[2], w });
}

//pub fn from_eular_angles(inAngles: anytype) @Vector(4, info(@TypeOf(inAngles)).child) {
//    if (info(@TypeOf(inAngles)).len != 3)  @compileError("vector must have three elements for from_eular_angles() to be defined");
//    const half = @as(@TypeOf(inAngles), @splat(0.5)) * inAngles;
//    std.math.sin
//
//    const half = @as(@TypeOf(inAngles), @splat(0.5));
//    const c1 = std.math.cos(inAngles[0] * half);
//    const c2 = std.math.cos(inAngles[1] * half);
//    const c3 = std.math.cos(inAngles[2] * half);
//    const s1 = std.math.sin(inAngles[0] * half);
//    const s2 = std.math.sin(inAngles[1] * half);
//    const s3 = std.math.sin(inAngles[2] * half);
//
//    return .{
//        s1 * c2 * c3 - c1 * s2 * s3,
//        c1 * s2 * c3 + s1 * c2 * s3,
//        c1 * c2 * s3 - s1 * s2 * c3,
//        c1 * c2 * c3 + s1 * s2 * s3,
//    };
//}
