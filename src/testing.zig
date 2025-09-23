const vector = @import("vector.zig");
const std = @import("std");

pub fn expect_is_close(vec: anytype, other: @TypeOf(vec), epsilon: std.meta.Child(@TypeOf(vec))) !void{
    if(vector.distance(vec, other) > @as(std.meta.Child(@TypeOf(vec)), epsilon)) {
        std.debug.print("Vectors not close enough: {} vs {}\n", .{vec, other});
        return error.TestExpectedApproxIsClose;
    }
}

