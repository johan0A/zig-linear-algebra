const geometry = @import("../geometry.zig");
const zla = @import("../root.zig");

pub fn Capsule(comptime T: type) type {
    return struct {
        pub const child: type = T;
        pub const primative_type = geometry.Primative.Capsule;
        const Self = @This();

        hemisphere_centers: [2]@Vector(3, T), // the two hemisphere centers
        radius: T, // radius of the capsule

        pub fn center(self: Self) @Vector(3, T) {
            return (self.hemisphere_centers[0] + self.hemisphere_centers[1]) * @as(@Vector(3, T), @splat(0.5));
        }

        pub fn get_cylinder_height(self: Self) T {
            return zla.vec.distance(self.hemisphere_centers[0], self.hemisphere_centers[1]);
        }

        pub fn get_total_height(self: Self) T {
            return self.get_cylinder_height() + self.radius * @as(T, 2);
        }
    };
}

