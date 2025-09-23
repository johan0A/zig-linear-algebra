const std = @import("std");
const vec = @import("../vector.zig");
const Mat = @import("../matrix.zig").Mat;

pub fn Plane(comptime T: type) type {
    return struct {
        normal: @Vector(3, T), // normal vector
        c: T, // constant

        const Self = @This();

        pub fn normal_and_constant(self: Self) @Vector(4, T) {
            return .{ self.normal[0], self.normal[1], self.normal[2], self.c };
        }

        pub fn from_point_and_normal(point: @Vector(3, T), normal: @Vector(3, T)) Self {
            return .{ .normal = normal, .c = -vec.dot(normal, point) };
        }

        pub fn from_points_ccw(a: @Vector(3, T), b: @Vector(3, T), c: @Vector(3, T)) Self {
            return from_point_and_normal(a, vec.normalize(vec.cross((b - a), (c - a))));
        }

        pub fn offset(self: Self, distance: T) Self {
            return .{
                .normal = self.normal,
                .c = self.c - distance,
            };
        }

        pub fn transform(self: Self, m: Mat(T, 4, 4)) Self {
            const transformed_normal = m.extract(3, 3).mul(vec.to_mat(self.normal));
            return .{ .normal = transformed_normal.column(0), .c = self.c - vec.dot(m.position(), transformed_normal.column(0)) };
        }

        pub fn scaled(self: Self, scale: @Vector(3, T)) Self {
            const scaled_normal = self.normal / scale;
            const scaled_normal_length = vec.norm(scaled_normal);
            return .{
                .normal = self.normal / @as(@Vector(3, T), @splat(scaled_normal_length)),
                .c = self.c / scaled_normal_length,
            };
        }

        // distance point to plane
        pub fn signed_distance(self: Self, pt: @Vector(3, T)) T {
            return vec.dot(self.normal, pt) + self.c;
        }

        pub fn project_point_plane(self: Self, pt: @Vector(3, T)) @Vector(3, T) {
            return pt - self.normal * @as(@Vector(3, T), @splat(self.signed_distance(pt)));
        }

        pub fn intersect_plane(p1: Self, p2: Self, p3: Self) ?@Vector(3, T) {
            // We solve the equation:
            // |ax, ay, az, aw|   | x |   | 0 |
            // |bx, by, bz, bw| * | y | = | 0 |
            // |cx, cy, cz, cw|   | z |   | 0 |
            // |0,   0,  0,  1|   | 1 |   | 1 |
            // Where normal of plane 1 = (ax, ay, az), plane constant of 1 = aw, normal of plane 2 = (bx, by, bz) etc.
            // This involves inverting the matrix and multiplying it with [0, 0, 0, 1]

            // Fetch the normals and plane constants for the three planes
            const a = p1.normal_and_constant();
            const b = p2.normal_and_constant();
            const c = p3.normal_and_constant();

            const denom = vec.dot(p1.normal, vec.cross(p2.normal, p3.normal));
            if (denom == 0) return null;

            // The numerator is:
            // [aw*(bz*cy-by*cz)+ay*(bw*cz-bz*cw)+az*(by*cw-bw*cy)]
            // [aw*(bx*cz-bz*cx)+ax*(bz*cw-bw*cz)+az*(bw*cx-bx*cw)]
            // [aw*(by*cx-bx*cy)+ax*(bw*cy-by*cw)+ay*(bx*cw-bw*cx)]
            const numerator =
                @as(@Vector(3, T), @splat(p1.c)) * (vec.swizzle(b, "zxy") * vec.swizzle(c, "yzx") - vec.swizzle(b, "yzx") * vec.swizzle(c, "zxy")) + vec.swizzle(a, "yxx") * (vec.swizzle(b, "wzw") * vec.swizzle(c, "zwy") - vec.swizzle(b, "zwy") * vec.swizzle(c, "wzw")) + vec.swizzle(a, "zzy") * (vec.swizzle(b, "ywx") * vec.swizzle(c, "wxw") - vec.swizzle(b, "wxw") * vec.swizzle(c, "ywx"));
            return numerator / @as(@Vector(3, T), @splat(denom));
        }
    };
}

test "transformed" {
    const transform = Mat(f32, 4, 4)
        .rotate(.identity, 0.1 * std.math.pi, vec.normalize(@Vector(3, f32){ 1, 2, 3 }))
        .translate(@Vector(3, f32){ 5, -7, 9 });

    const point = @Vector(3, f32){ 11.0, 13.0, 15.0 };
    const normal = vec.normalize(@Vector(3, f32){ -3.0, 5.0, -7.0 });

    const p1 = Plane(f32).from_point_and_normal(point, normal).transform(transform);
    const p2 = Plane(f32).from_point_and_normal(vec.extract(transform.mul(
        vec.to_mat(@Vector(4, f32){ point[0], point[1], point[2], 1.0 })).column(0), 3), 
        transform.extract(3, 3).mul(vec.to_mat(normal)).column(0));

    try std.testing.expectApproxEqAbs(p1.normal[0], p2.normal[0], 0.000001);
    try std.testing.expectApproxEqAbs(p1.normal[1], p2.normal[1], 0.000001);
    try std.testing.expectApproxEqAbs(p1.normal[2], p2.normal[2], 0.000001);
}

test "signed_distance" {
    const plane = Plane(f32).from_point_and_normal(.{ 0, 2, 0 }, .{ 0, 1, 0 });
    try std.testing.expectApproxEqRel(plane.signed_distance(.{ 5, 7, 0 }), 5.0, 0.0001);
    try std.testing.expectApproxEqRel(plane.signed_distance(.{ 5, -3, 0 }), -5.0, 0.0001);
}

test "intersect_plane" {
    const p1 = Plane(f32).from_point_and_normal(.{ 0, 2, 0 }, .{ 0, 1, 0 });
    const p2 = Plane(f32).from_point_and_normal(.{ 3, 0, 0 }, .{ 1, 0, 0 });
    const p3 = Plane(f32).from_point_and_normal(.{ 0, 0, 4 }, .{ 0, 0, 1 });
    {
        const point = Plane(f32).intersect_plane(p1, p2, p3);
        try std.testing.expect(point != null);
        try std.testing.expectEqual(point.?, .{ 3, 2, 4 });
    }
    {
        const p4 = Plane(f32).from_point_and_normal(.{ 0, 3, 0 }, .{ 0, 1, 0 });
        const point = Plane(f32).intersect_plane(p1, p2, p4);
        try std.testing.expect(point == null);
    }
}
