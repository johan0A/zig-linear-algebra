const std = @import("std");
const Mat = @import("../matrix.zig").Mat;
const geometry = @import("../geometry.zig");
const Sphere = @import("sphere.zig").Sphere;
const vector = @import("../vector.zig");

pub fn overlap_sphere_sphere(a: anytype, b: anytype) bool {
    if (@TypeOf(a).primative_type != .Sphere) @compileError("Expected Sphere" ++ @typeName(@TypeOf(a)));
    if (@TypeOf(b).primative_type != .Sphere) @compileError("Expected Sphere" ++ @typeName(@TypeOf(b)));
    if (@TypeOf(a).inner_type != @TypeOf(b).inner_type) @compileError("Expected same type: " ++ @typeName(@TypeOf(a).inner_type) ++ " " ++ @typeName(@TypeOf(b).inner_type));
    return vector.norm_sqr(a.center - b.center) <= (a.radius + b.radius) * (a.radius + b.radius);
}

pub inline fn overlap(a: anytype, b: anytype) bool {
    const a_primative: geometry.Primative = @TypeOf(a).primative_type;
    const b_primative: geometry.Primative = @TypeOf(b).primative_type;
    if (a_primative == .Sphere and b_primative == .Sphere) {
        return overlap_sphere_sphere(a, b);
    }
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
