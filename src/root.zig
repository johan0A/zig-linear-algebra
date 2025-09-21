pub const vec = @import("vector.zig");
pub const Mat = @import("matrix.zig").Mat;

pub const geom = @import("geometry/geom.zig");

test {
    @import("std").testing.refAllDeclsRecursive(@This());
}

const std = @import("std");

pub fn to_radians(degrees: anytype) @TypeOf(degrees) {
    return degrees * (std.math.pi / 180);
}

pub fn to_degrees(radians: anytype) @TypeOf(radians) {
    return radians * (1 / (std.math.pi / 180));
}
