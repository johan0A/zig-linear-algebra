pub const Vec = @import("vector.zig").Vec;
pub const Mat = @import("matrix.zig").Mat;

const std = @import("std");
test {
    std.testing.refAllDeclsRecursive(@This());
}
