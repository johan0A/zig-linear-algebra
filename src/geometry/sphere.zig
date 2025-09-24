const std = @import("std");
const vector = @import("../vector.zig");
const meta = @import("../meta.zig");


pub fn Sphere(comptime T: type) type {
    return struct {
        center: @Vector(3, T),
        radius: T,

        pub fn from_center_radius(center: anytype, radius: T) Sphere(T) {
            return .{
                .center = meta.map_to_vector(center),
                .radius = radius,
            };
        }
    };
}
