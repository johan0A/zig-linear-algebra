const Mat = @import("../matrix.zig").Mat; 
const geometry = @import("../geometry.zig");

pub fn OrientedBoundedBox(comptime T: type) type {
    return struct {
        pub const primative_type = geometry.Primative.OrientedBox; 
        orientation: Mat(4,4, T),
        half_extent: @Vector(3, T),
    };
}

