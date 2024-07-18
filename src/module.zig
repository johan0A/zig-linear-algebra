pub const Vec = @import("vector.zig").Vec;
pub const Matrix = @import("matrix.zig").Matrix;

const std = @import("std");
test {
    std.testing.refAllDeclsRecursive(@This());
}
