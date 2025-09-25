const std = @import("std");
const zla = @import("../root.zig");
const Mat = @import("../matrix.zig").Mat;
const geometry = @import("../geometry.zig");
const Sphere = @import("sphere.zig").Sphere;
const vector = @import("../vector.zig");

// aabb
pub fn overlap_sphere_sphere(a: anytype, b: anytype) bool {
    if (@TypeOf(a).primative_type != .Sphere) @compileError("Expected Sphere" ++ @typeName(@TypeOf(a)));
    if (@TypeOf(b).primative_type != .Sphere) @compileError("Expected Sphere" ++ @typeName(@TypeOf(b)));
    if (@TypeOf(a).inner_type != @TypeOf(b).inner_type) @compileError("Expected same type: " ++ @typeName(@TypeOf(a).inner_type) ++ " " ++ @typeName(@TypeOf(b).inner_type));
    return vector.norm_sqr(a.center - b.center) <= (a.radius + b.radius) * (a.radius + b.radius);
}

pub fn overlap_aabb_aabb(a: anytype, b: anytype) bool {
    if (@TypeOf(a).primative_type != .AABB) @compileError("Expected AABB" ++ @typeName(@TypeOf(a)));
    if (@TypeOf(b).primative_type != .AABB) @compileError("Expected AABB" ++ @typeName(@TypeOf(b)));
    return !@reduce(.Or, (a.min > b.max) | (a.max < b.min));
}

pub fn overlap_aabb_plane(a: anytype, b: anytype) bool {
    if (@TypeOf(a).primative_type != .AABB) @compileError("Expected AABB" ++ @typeName(@TypeOf(a)));
    if (@TypeOf(b).primative_type != .Plane) @compileError("Expected Plane" ++ @typeName(@TypeOf(b)));
    const dist_normal = b.signed_distance(a.get_support(b.normal));
    const dist_min_normal = b.signed_distance(a.get_support(-b.normal));
    return dist_normal * dist_min_normal <= 0;
}

pub fn overlap_aabb_aabb_4(a: anytype, minX: @Vector(4, @TypeOf(a).inner_type), maxX: @Vector(4, @TypeOf(a).inner_type), minY: @Vector(4, @TypeOf(a).inner_type), maxY: @Vector(4, @TypeOf(a).inner_type), minZ: @Vector(4, @TypeOf(a).inner_type), maxZ: @Vector(4, @TypeOf(a).inner_type)) @Vector(4, bool) {
    if (@TypeOf(a).primative_type != .AABB) @compileError("Expected AABB" ++ @typeName(@TypeOf(a)));
    const box1_minx = @as(@Vector(4, @TypeOf(a).inner_type), @splat(a.min[0]));
    const box1_miny = @as(@Vector(4, @TypeOf(a).inner_type), @splat(a.min[1]));
    const box1_minz = @as(@Vector(4, @TypeOf(a).inner_type), @splat(a.min[2]));
    const box1_maxx = @as(@Vector(4, @TypeOf(a).inner_type), @splat(a.max[0]));
    const box1_maxy = @as(@Vector(4, @TypeOf(a).inner_type), @splat(a.max[1]));
    const box1_maxz = @as(@Vector(4, @TypeOf(a).inner_type), @splat(a.max[2]));

    const nooverlap_x = (box1_minx > maxX) | (box1_maxx < minX);
    const nooverlap_y = (box1_miny > maxY) | (box1_maxy < minY);
    const nooverlap_z = (box1_minz > maxZ) | (box1_maxz < minZ);
    return !(nooverlap_x | nooverlap_y | nooverlap_z);
}

// generic overlap function
pub inline fn overlap(a: anytype, b: anytype) bool {
    const a_primative: geometry.Primative = @TypeOf(a).primative_type;
    const b_primative: geometry.Primative = @TypeOf(b).primative_type;
    if (a_primative == .Sphere and b_primative == .Sphere) return overlap_sphere_sphere(a, b);
    if (a_primative == .AABB and b_primative == .AABB) return overlap_aabb_aabb(a, b);
    @compileError("Unsupported primative overlap: " ++ @typeName(a_primative) ++ " " ++ @typeName(b_primative));
}

test overlap_sphere_sphere {
    const s1: Sphere(f32) = .from_center_radius(.{ 0, 0, 0 }, 1);
    const s2: Sphere(f32) = .from_center_radius(.{ 0, 0, 1.5 }, 1);
    const s3: Sphere(f32) = .from_center_radius(.{ 0, 0, 3 }, 1);
    try std.testing.expect(overlap_sphere_sphere(s1, s2));
    try std.testing.expect(!overlap_sphere_sphere(s1, s3));
    // Symmetric
    try std.testing.expect(overlap(s1, s2));
    try std.testing.expect(overlap(s2, s1));
}

test overlap_aabb_aabb {
    const aabb1: geometry.AABB(f32) = .from_two_points(.{ 0, 0, 0 }, .{ 2, 2, 2 });
    const aabb2: geometry.AABB(f32) = .from_two_points(.{ 1, 1, 1 }, .{ 3, 3, 3 }); // Overlapping
    const aabb3: geometry.AABB(f32) = .from_two_points(.{ 5, 5, 5 }, .{ 7, 7, 7 }); // Non-overlapping
    const aabb4: geometry.AABB(f32) = .from_two_points(.{ 2, 0, 0 }, .{ 4, 2, 2 }); // Edge touching

    try std.testing.expect(overlap_aabb_aabb(aabb1, aabb2)); // Overlapping boxes should return true
    try std.testing.expect(!overlap_aabb_aabb(aabb1, aabb3)); // Non-overlapping boxes should return false
    try std.testing.expect(overlap_aabb_aabb(aabb1, aabb4)); // Edge touching boxes should return true

    // Symmetric - test the generic overlap function
    try std.testing.expect(overlap(aabb1, aabb2));
    try std.testing.expect(!overlap(aabb1, aabb3));
    try std.testing.expect(overlap(aabb2, aabb1));
}
