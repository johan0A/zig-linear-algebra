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

pub fn find_roots(comptime T: type, a: T, b: T, c: T) struct {
    num_roots: u8,
    roots: [2]T,
} {
    // Check if this is a linear equation
    if (a == 0) {
        // Check if this is a constant equation
        if (b == 0)
            return .{
                .num_roots = 0,
                .roots = .{ 0, 0 },
            };

        // Linear equation with 1 solution
        const r1 = -c / b;
        return .{
            .num_roots = 1,
            .roots = .{ r1, r1 },
        };
    }

    // See Numerical Recipes in C, Chapter 5.6 Quadratic and Cubic Equations
    const det: T = (b * b) - 4 * a * c;
    if (det < 0)
        return .{
            .num_roots = 0,
            .roots = .{ 0, 0 },
        };

    const q: T = (b + std.math.sign(b) * std.math.sqrt(det)) / -2;
    const r1 = q / a;
    if (q == 0) {
        return .{
            .num_roots = 1,
            .roots = .{ r1, r1 },
        };
    }
    const r2 = c / q;
    return .{
        .num_roots = 2,
        .roots = .{ r1, r2 },
    };
}
