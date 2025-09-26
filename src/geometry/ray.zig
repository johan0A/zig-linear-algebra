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

// Ray - Axis Aligned Bounding Box intersection
// Note: Can return negative t values if the ray origin is inside the AABB
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

//pub fn ray_aabb(origin: anytype) {
//
//}

//pub fn ray_intersect_aabb() {
//
//}
