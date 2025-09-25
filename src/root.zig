pub const vec = @import("vector.zig");
pub const quat = @import("quat.zig");
pub const Mat = @import("matrix.zig").Mat;
const std = @import("std");

const Vec4f32 = vec.Vec4f32;
const Vec3f32 = vec.Vec3f32;
const Vec2f32 = vec.Vec2f32;

const Vec4f64 = vec.Vec4f64;
const Vec3f64 = vec.Vec3f64;
const Vec2f64 = vec.Vec2f64;

const Quat4f32 = quat.Quat4f32;
const Quat4f64 = quat.Quat4f64;

pub const geom = @import("geometry.zig");

test {
    @import("std").testing.refAllDeclsRecursive(@This());
}


pub fn to_radians(degrees: anytype) @TypeOf(degrees) {
    return degrees * (std.math.pi / 180);
}

pub fn to_degrees(radians: anytype) @TypeOf(radians) {
    return radians * (1 / (std.math.pi / 180));
}
