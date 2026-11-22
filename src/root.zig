pub const vec = @import("vector.zig");
pub const matrix = @import("matrix.zig");
pub const Mat = matrix.Mat;
pub const Quat = @import("quaternion.zig").Quat;
/// All angles in this library are in turns (1 turn = 360 degrees).
pub const turn = @import("turn/turn.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
