const std = @import("std");
const sin_module = @import("sin.zig");

pub const sin = sin_module.sin;
pub const cos = sin_module.cos;

pub fn fromRadians(radians: anytype) @TypeOf(radians) {
    return radians / std.math.tau;
}

pub fn toRadians(turns: anytype) @TypeOf(turns) {
    return turns * std.math.tau;
}

pub fn fromDegrees(degrees: anytype) @TypeOf(degrees) {
    return degrees / 360.0;
}

pub fn toDegrees(turns: anytype) @TypeOf(turns) {
    return turns * 360.0;
}

// TODO: placeholder implementation
pub fn tan(turns: anytype) @TypeOf(turns) {
    return sin(turns) / cos(turns);
}

/// In turns, in the range [-0.25, 0.25].
// TODO: placeholder implementation
pub fn asin(x: anytype) @TypeOf(x) {
    return std.math.asin(x) / std.math.tau;
}

/// In turns, in the range [0, 0.5].
// TODO: placeholder implementation
pub fn acos(x: anytype) @TypeOf(x) {
    return std.math.acos(x) / std.math.tau;
}

/// Arctangent of y/x in turns, in the range [-0.5, 0.5].
// TODO: placeholder implementation
pub fn atan2(y: anytype, x: @TypeOf(y)) @TypeOf(y) {
    return std.math.atan2(y, x) / std.math.tau;
}

test {
    _ = sin_module;
}
