const vector = @import("vector.zig");
const std = @import("std");

pub fn expect_is_close(vec: anytype, other: @TypeOf(vec), epsilon: vector.info(@TypeOf(vec)).child) !void{
    if(vector.distance(vec, other) > @as(vector.info(@TypeOf(vec)).child, epsilon)) {
        std.debug.print("Vectors not close enough: {} vs {}\n", .{vec, other});
        return error.TestExpectedApproxIsClose;
    }
}

