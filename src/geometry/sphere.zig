const meta = @import("../meta.zig");
const zla = @import("../root.zig");
const geometry = zla.geom;

pub fn Sphere(comptime T: type) type {
    return struct {
        pub const inner_type: type = T;
        pub const primative_type: geometry.Primative = .Sphere;

        center: @Vector(3, T),
        radius: T,

        pub fn from_center_radius(center: @Vector(3, T), radius: T) Sphere(T) {
            return .{
                .center = meta.map_to_vector(center),
                .radius = radius,
            };
        }
    };
}
