pub const Vec = @import("vector.zig").Vec;

const std = @import("std");
test {
    std.testing.refAllDeclsRecursive(@This());
}
