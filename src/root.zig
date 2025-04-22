pub const vec = @import("vector.zig");
pub const Mat = @import("matrix.zig").Mat;

test {
    @import("std").testing.refAllDeclsRecursive(@This());
}

const std = @import("std");

pub fn toRadians(degrees: anytype) @TypeOf(degrees) {
    return degrees * (std.math.pi / 180);
}

pub fn toDegrees(radians: anytype) @TypeOf(radians) {
    return radians * (1 / (std.math.pi / 180));
}
