const meta = @import("meta.zig");
const std = @import("std");

pub inline fn array_vector_length(T: type) usize {
    return switch (@typeInfo(T)) {
        .vector => |v| v.len,
        .array => |a| a.len,
        else => @compileError("Expected a vector or array type, got: " ++ @typeName(T)),
    };
}

pub fn map_to_vector(a: anytype) @Vector(meta.array_vector_length(@TypeOf(a)), std.meta.Child(@TypeOf(a))) {
    const type_info = @typeInfo(@TypeOf(a));
    if (type_info != .vector and type_info != .array) @compileError("Expected vector or array type, got: " ++ @typeName(@TypeOf(a)));
    return a;
}
