const std = @import("std");
const zla = @import("../root.zig");

pub fn InvDirection(comptime T: type) type {
    return struct {
        inv_direction: @Vector(3, T), // 1 / ray direction
        is_parallel: @Vector(3, bool), // true if ray direction is close to zero

        pub fn from_direction(direction: @Vector(3, T)) @This() {
            return .{
                .is_parallel = @abs(direction) < @as(@Vector(3, T), @splat(1.0e-20)),
                .inv_direction = @as(@Vector(3, T), @splat(1)) / direction,
            };
        }
    };
}

//pub fn ray_cylinder(cylinder: anytype, origin: @Vector(3, @TypeOf(cylinder).child), direction: @Vector(3, @TypeOf(cylinder).child)) std.meta.Float(@bitSizeOf(@TypeOf(cylinder).child)) {
//    comptime {
//        std.debug.assert(@TypeOf(cylinder).primative_type == .Cylinder); // ensure cylinder type
//    }
//
//    const orgin_xz = @select(@TypeOf(cylinder).child, .{ true, false, true }, origin, @as(@Vector(3, @TypeOf(cylinder).child), @splat(0)));
//    const origin_xz_len_sq = zla.vec.norm_sqr(orgin_xz);
//    const r_sq = cylinder.radius * cylinder.radius;
//    if (origin_xz_len_sq > r_sq) {
//        // Ray starts outside the infinite cylinder
//        // Solve: |RayOrigin_xz + fraction * RayDirection_xz|^2 = r^2 to find fraction
//        const direction_xz = @select(@TypeOf(cylinder).child, .{ true, false, true }, direction, @as(@Vector(3, @TypeOf(cylinder).child), @splat(0)));
//        const a = zla.vec.norm_sqr(direction_xz);
//        const b = 2 * zla.vec.dot(orgin_xz, direction_xz);
//        const c = origin_xz_len_sq - r_sq;
//        const root_terms = zla.find_roots(@TypeOf(cylinder).child, a, b, c);
//        if (root_terms.num_roots == 0) {
//            return std.math.floatMax(@TypeOf(cylinder).child);
//        }
//        // Get fraction corresponding to the ray entering the circle
//        const fraction = @min(root_terms.roots[0], root_terms.roots[1]);
//        if (fraction >= 0) {
//            return fraction;
//        }
//    } else {
//        return 0.0;
//    }
//    return std.math.floatMax(@TypeOf(cylinder).child);
//}

// Ray - Axis Aligned Bounding Box intersection
// Note: Can return negative t values if the ray origin is inside the AABB
// return std.math.floatMax(T) if no hit
pub fn ray_aabb(aabb: anytype, origin: @Vector(3, @TypeOf(aabb).child), invDir: InvDirection(@TypeOf(aabb).child)) std.meta.Float(@bitSizeOf(@TypeOf(aabb).child)) {
    comptime {
        std.debug.assert(@TypeOf(aabb).primative_type == .AABB); // ensure aabb type
    }
    const flt_min = @as(@Vector(3, @TypeOf(aabb).child), @splat(-std.math.floatMax(@TypeOf(aabb).child)));
    const flt_max = @as(@Vector(3, @TypeOf(aabb).child), @splat(std.math.floatMax(@TypeOf(aabb).child)));

    // Test against all three axes simultaneously.
    const t1 = (aabb.min - origin) * invDir.inv_direction;
    const t2 = (aabb.max - origin) * invDir.inv_direction;

    // Compute the max of min(t1,t2) and the min of max(t1,t2) ensuring we don't
    // use the results from any directions parallel to the slab.
    var t_min = @select(@TypeOf(aabb).child, invDir.is_parallel, flt_min, @min(t1, t2));
    var t_max = @select(@TypeOf(aabb).child, invDir.is_parallel, flt_max, @max(t1, t2));

    // t_min.xyz = maximum(t_min.x, t_min.y, t_min.z);
    t_min = @max(t_min, @shuffle(@TypeOf(aabb).child, t_min, t_min, [3]u8{ 1, 2, 0 }));
    t_min = @max(t_min, @shuffle(@TypeOf(aabb).child, t_min, t_min, [3]u8{ 2, 0, 1 }));

    // t_max.xyz = minimum(t_max.x, t_max.y, t_max.z);
    t_max = @min(t_max, @shuffle(@TypeOf(aabb).child, t_max, t_max, [3]u8{ 1, 2, 0 }));
    t_max = @min(t_max, @shuffle(@TypeOf(aabb).child, t_max, t_max, [3]u8{ 2, 0, 1 }));

    // if (t_min > t_max) return FLT_MAX;
    var no_intersection = t_min > t_max;

    // if (t_max < 0.0f) return FLT_MAX;
    no_intersection = no_intersection | (t_max < @as(@TypeOf(t_max), @splat(0)));

    // if (inInvDirection.mIsParallel && !(Min <= inOrigin && inOrigin <= Max)) return FLT_MAX; else return t_min;
    const no_parallel_overlap = (origin < aabb.min) | (origin > aabb.max);
    no_intersection = no_intersection | (invDir.is_parallel & no_parallel_overlap);
    no_intersection = no_intersection | @as(@TypeOf(no_intersection), @splat(no_intersection[1]));
    no_intersection = no_intersection | @as(@TypeOf(no_intersection), @splat(no_intersection[2]));

    return @select(@TypeOf(aabb).child, no_intersection, flt_max, t_min)[0];
}

// Ray - Axis Aligned Bounding Box intersection
// Note: Can return negative t values if the ray origin is inside the AABB
// return -std.math.floatMax(T) and std.math.floatMax(T) if no hit 
pub fn ray_aabb_with_enter_exit(aabb: anytype, origin: @Vector(3, @TypeOf(aabb).child), invDir: InvDirection(@TypeOf(aabb).child)) struct {
    min: std.meta.Float(@bitSizeOf(@TypeOf(aabb).child)),
    max: std.meta.Float(@bitSizeOf(@TypeOf(aabb).child))
} {
    comptime {
        std.debug.assert(@TypeOf(aabb).primative_type == .AABB); // ensure aabb type
    }
    const flt_min = @as(@Vector(3, @TypeOf(aabb).child), @splat(-std.math.floatMax(@TypeOf(aabb).child)));
    const flt_max = @as(@Vector(3, @TypeOf(aabb).child), @splat(std.math.floatMax(@TypeOf(aabb).child)));

    // Test against all three axes simultaneously.
    const t1 = (aabb.min - origin) * invDir.inv_direction;
    const t2 = (aabb.max - origin) * invDir.inv_direction;

    // Compute the max of min(t1,t2) and the min of max(t1,t2) ensuring we don't
    // use the results from any directions parallel to the slab.
    var t_min = @select(@TypeOf(aabb).child, invDir.is_parallel, flt_min, @min(t1, t2));
    var t_max = @select(@TypeOf(aabb).child, invDir.is_parallel, flt_max, @max(t1, t2));

    // t_min.xyz = maximum(t_min.x, t_min.y, t_min.z);
    t_min = @max(t_min, @shuffle(@TypeOf(aabb).child, t_min, t_min, [3]u8{ 1, 2, 0 }));
    t_min = @max(t_min, @shuffle(@TypeOf(aabb).child, t_min, t_min, [3]u8{ 2, 0, 1 }));

    // t_max.xyz = minimum(t_max.x, t_max.y, t_max.z);
    t_max = @min(t_max, @shuffle(@TypeOf(aabb).child, t_max, t_max, [3]u8{ 1, 2, 0 }));
    t_max = @min(t_max, @shuffle(@TypeOf(aabb).child, t_max, t_max, [3]u8{ 2, 0, 1 }));

    // if (t_min > t_max) return FLT_MAX;
    var no_intersection = t_min > t_max;

    // if (t_max < 0.0f) return FLT_MAX;
    no_intersection = no_intersection | (t_max < @as(@TypeOf(t_max), @splat(0)));

    // if (inInvDirection.mIsParallel && !(Min <= inOrigin && inOrigin <= Max)) return FLT_MAX; else return t_min;
    const no_parallel_overlap = (origin < aabb.min) | (origin > aabb.max);
    no_intersection = no_intersection | (invDir.is_parallel & no_parallel_overlap);
    no_intersection = no_intersection | @as(@TypeOf(no_intersection), @splat(no_intersection[1]));
    no_intersection = no_intersection | @as(@TypeOf(no_intersection), @splat(no_intersection[2]));

    return .{
        .min = @select(@TypeOf(aabb).child, no_intersection, flt_max, t_min)[0],
        .max = @select(@TypeOf(aabb).child, no_intersection, flt_max, t_max)[0],
    };

}

/// Intersect ray with triangle, returns closest point or FLT_MAX if no hit (branch less version)
/// Adapted from: http://en.wikipedia.org/wiki/M%C3%B6ller%E2%80%93Trumbore_intersection_algorithm
pub fn ray_triangle(comptime T: type, origin: @Vector(3, T), direction: @Vector(3, T), v0: @Vector(3, T), v1: @Vector(3, T), v2: @Vector(3, T)) T {
    const epsilon: @Vector(3, T) = @as(@Vector(3, T), @splat(1.0e-12));

    const zero: @Vector(3, T) = @as(@Vector(3, T), @splat(0));
    const one: @Vector(3, T) = @as(@Vector(3, T), @splat(1));

    // Find vectors for two edges sharing v0
    const e1 = v1 - v0;
    const e2 = v2 - v0;

    // Begin calculating determinant - also used to calculate u parameter
    const p = zla.vec.cross(direction, e2);

    // If determinant is near zero, ray lies in plane of triangle
    var det = @as(@Vector(3, T), @splat(zla.vec.dot(e1, p)));

    // Check if determinant is near zero
    const det_near_zero = @abs(det) < epsilon;

    // when the determinant is near zero, return no intersection
    det = @select(T, det_near_zero, one, det);

    // Calculate distance from v0 to ray origin
    const s = origin - v0;

    // Calculate u parameter and test bounds
    const u = @as(@Vector(3, T), @splat(zla.vec.dot(s, p))) / det;

    // Prepare to test v parameter
    const q = zla.vec.cross(s, e1);

    // Calculate v parameter and test bounds
    const v = @as(@Vector(3, T), @splat(zla.vec.dot(direction, q))) / det;

    // get intersection point
    const t = @as(@Vector(3, T), @splat(zla.vec.dot(e2, q))) / det;

    const no_intersection =
        (det_near_zero | (u < zero)) | ((v < zero) | ((u + v) > one)) | (t < zero);

    return @select(T, no_intersection, @as(@Vector(3, T), @splat(std.math.floatMax(T))), t)[0];
}

test ray_aabb {
    const aabb: zla.geom.AABB(f32) = .from_two_points(.{ -1, -1, -1 }, .{ 1, 1, 1 });
    inline for (0..3) |axis| {
        {
            // Ray starting in the center of the box, pointing high
            const origin = @Vector(3, f32){ 0, 0, 0 };
            var direction = @Vector(3, f32){ 0, 0, 0 };
            direction[axis] = 1;
            const fraction = ray_aabb(aabb, origin, .from_direction(direction));
            try std.testing.expectApproxEqRel(-1.0, fraction, 1.0e-6);
        }
    }
}

test ray_triangle {
    const v0 = @Vector(3, f32){ 0, 0, 0 };
    const v1 = @Vector(3, f32){ 1, 0, 0 };
    const v2 = @Vector(3, f32){ 0, 1, 0 };

    {
        // Ray starting above the triangle, pointing down
        const origin = @Vector(3, f32){ 0.25, 0.25, 1 };
        const direction = @Vector(3, f32){ 0, 0, -1 };
        const fraction = ray_triangle(f32, origin, direction, v0, v1, v2);
        try std.testing.expectApproxEqRel(1.0, fraction, 1.0e-6);
    }
    {
        // Ray starting below the triangle, pointing up
        const origin = @Vector(3, f32){ 0.25, 0.25, -1 };
        const direction = @Vector(3, f32){ 0, 0, 1 };
        const fraction = ray_triangle(f32, origin, direction, v0, v1, v2);
        try std.testing.expectApproxEqRel(1.0, fraction, 1.0e-6);
    }
    {
        // Ray starting to the side of the triangle pointing away
        const origin = @Vector(3, f32){ -1, -1, 0 };
        const direction = @Vector(3, f32){ -1, -1, 0 };
        const fraction = ray_triangle(f32, origin, direction, v0, v1, v2);
        try std.testing.expectEqual(std.math.floatMax(f32), fraction);
    }
    {
        // Ray starting to the side of the triangle pointing towards
        const origin = @Vector(3, f32){ -1, -1, 0 };
        const direction = @Vector(3, f32){ 1, 1, 0 };
        const fraction = ray_triangle(f32, origin, direction, v0, v1, v2);
        try std.testing.expectEqual(std.math.floatMax(f32), fraction);
    }
}

//test ray_cylinder {
//    const cylinder: zla.geom.Cylinder(f32) = .from_two_points_radius(.{ 0, 0, 0 }, .{ 0, 0, 2 }, 1.0);
//    {
//        // Ray starting outside the cylinder, pointing towards
//        const origin = @Vector(3, f32){ 2, 0, 1 };
//        const direction = @Vector(3, f32){ -1, 0, 0 };
//        const fraction = ray_cylinder(cylinder, origin, direction);
//        try std.testing.expectApproxEqRel(1.0, fraction, 1.0e-6);
//    }
//    {
//        // Ray starting outside the cylinder, pointing away
//        const origin = @Vector(3, f32){ 2, 0, 1 };
//        const direction = @Vector(3, f32){ 1, 0, 0 };
//        const fraction = ray_cylinder(cylinder, origin, direction);
//        try std.testing.expectEqual(std.math.floatMax(f32), fraction);
//    }
//    {
//        // Ray starting inside the cylinder
//        const origin = @Vector(3, f32){ 0.5, 0, 1 };
//        const direction = @Vector(3, f32){ 1, 0, 0 };
//        const fraction = ray_cylinder(cylinder, origin, direction);
//        try std.testing.expectApproxEqRel(0.0, fraction, 1.0e-6);
//    }
//}

//pub fn ray_aabb(origin: anytype) {
//
//}

//pub fn ray_intersect_aabb() {
//
//}
