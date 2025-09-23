pub inline fn array_vector_length(T: type) usize {
    return switch (@typeInfo(T)) {
        .vector => |v| v.len,
        .array => |a| a.len,
        else => @compileError("Expected a vector or array type, got: " ++ @typeName(T)),
    };
}
