const std = @import("std");
const zla = @import("../root.zig");

pub fn aabb_contains_point(a: anytype, pt: @Vector(3, @TypeOf(a).child)) bool {
    comptime {
        std.debug.assert(@TypeOf(a).primative_type == .AABB);
    }
    return @reduce(.And, (pt >= a.min) & (pt <= a.max));
}

//pub fn capsule_contains_point(a: anytype, pt: @Vector(3, @TypeOf(a).child)) bool {
//    comptime {
//        std.debug.assert(@TypeOf(a).primative_type == .Capsule);
//    }
//    const ab = a.hemisphere_centers[1] - a.hemisphere_centers[0];
//    const t = @max(@min(zla.vec.dot(pt - a.hemisphere_centers[0], ab) / zla.vec.dot(ab, ab), @as(@TypeOf(a).child, 1)), @as(@TypeOf(a).child, 0));
//    const closest_point = a.hemisphere_centers[0] + ab * @as(@Vector(3, @TypeOf(a).child), t);
//    return zla.vec.distance_sqr(pt, closest_point) <= a.radius * a.radius;
//} 

test aabb_contains_point {
    const aabb: zla.geom.AABB(f32) = .from_two_points(.{ -1, -1, -1 }, .{ 1, 1, 1 });
    try std.testing.expect(aabb_contains_point(aabb, .{ 0, 0, 0 }));
    try std.testing.expect(!aabb_contains_point(aabb, .{ 2, 0, 0 }));
    try std.testing.expect(!aabb_contains_point(aabb, .{ 0, -2, 0 }));
    try std.testing.expect(!aabb_contains_point(aabb, .{ 0, 0, 2 }));
}

//test capsule_contains_point {
//    const capsule: zla.geom.Capsule(f32) = .{
//        .hemisphere_centers = .{ .{ 0, 0, -1 }, .{ 0, 0, 1 } },
//        .radius = 1,
//    };
//    try std.testing.expect(capsule_contains_point(capsule, .{ 0, 0, 0 }));
//    try std.testing.expect(capsule_contains_point(capsule, .{ 1, 0, 0 }));
//    try std.testing.expect(!capsule_contains_point(capsule, .{ 2, 0, 0 }));
//    try std.testing.expect(!capsule_contains_point(capsule, .{ 0, -2, 0 }));
//    try std.testing.expect(!capsule_contains_point(capsule, .{ 0, 0, 3 }));
//}
