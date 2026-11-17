//! Angles in turns: 1 turn = 360 degrees = 2*pi radians.

const std = @import("std");

const tau = std.math.tau;

pub fn fromRadians(radians: anytype) @TypeOf(radians) {
    return radians / tau;
}

pub fn toRadians(turns: anytype) @TypeOf(turns) {
    return turns * tau;
}

pub fn fromDegrees(degrees: anytype) @TypeOf(degrees) {
    return degrees / 360.0;
}

pub fn toDegrees(turns: anytype) @TypeOf(turns) {
    return turns * 360.0;
}

/// Sine of an angle in turns. Accepts floats and vectors of floats.
// TODO: placeholder implementation
pub fn sin(turns: anytype) @TypeOf(turns) {
    return @sin(turns * splat(@TypeOf(turns), tau));
}

/// Cosine of an angle in turns. Accepts floats and vectors of floats.
// TODO: placeholder implementation
pub fn cos(turns: anytype) @TypeOf(turns) {
    return @cos(turns * splat(@TypeOf(turns), tau));
}

inline fn splat(comptime V: type, comptime value: comptime_float) V {
    return if (comptime @typeInfo(V) == .vector) @splat(value) else value;
}

/// Tangent of an angle in turns.
// TODO: placeholder implementation
pub fn tan(turns: anytype) @TypeOf(turns) {
    return sin(turns) / cos(turns);
}

/// Arcsine in turns, in the range [-0.25, 0.25].
// TODO: placeholder implementation
pub fn asin(x: anytype) @TypeOf(x) {
    return std.math.asin(x) / tau;
}

/// Arccosine in turns, in the range [0, 0.5].
// TODO: placeholder implementation
pub fn acos(x: anytype) @TypeOf(x) {
    return std.math.acos(x) / tau;
}

/// Arctangent of y/x in turns, in the range [-0.5, 0.5].
// TODO: placeholder implementation
pub fn atan2(y: anytype, x: @TypeOf(y)) @TypeOf(y) {
    return std.math.atan2(y, x) / tau;
}
