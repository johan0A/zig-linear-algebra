const meta = @import("meta.zig");
const std = @import("std");

pub inline fn array_vector_length(T: type) usize {
    return switch (@typeInfo(T)) {
        .vector => |v| v.len,
        .array => |a| a.len,
        else => @compileError("Expected a vector or array type, got: " ++ @typeName(T)),
    };
}

pub fn expect_vector_of_length(comptime T: type, comptime expected_len: usize) void {
    const type_info = @typeInfo(T);
    if (type_info != .vector) @compileError("Expected vector or array type, got: " ++ @typeName(T));
    const actual_len = array_vector_length(T);
    if (actual_len != expected_len) @compileError("Expected vector or array of length " ++ std.fmt.bufPrint("{d}", .{expected_len}) ++ ", got length " ++ std.fmt.bufPrint("{d}", .{actual_len}));
}

pub fn map_to_vector(a: anytype) @Vector(meta.array_vector_length(@TypeOf(a)), std.meta.Child(@TypeOf(a))) {
    const type_info = @typeInfo(@TypeOf(a));
    if (type_info != .vector and type_info != .array) @compileError("Expected vector or array type, got: " ++ @typeName(@TypeOf(a)));
    return a;
}
