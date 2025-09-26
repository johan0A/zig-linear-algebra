const geometry = @import("../geometry.zig");

pub fn Capsule(comptime T: type) type {
    return struct {
        pub const child: type = T;
        pub const primative_type = geometry.Primative.Capsule;

        hemisphere_centers: [2]@Vector(3, T), // the two hemisphere centers
        radius: T, // radius of the capsule
    };
}

