pub const vec = @import("vector.zig");
pub const Mat = @import("matrix.zig").Mat;

test {
    @import("std").testing.refAllDeclsRecursive(@This());
}
