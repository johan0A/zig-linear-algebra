const std = @import("std");

pub fn BufferView(comptime T: type) type {
    return struct {
        pub const inner_type = switch (@typeInfo(T)) { 
            .vector => |v| [v.len]std.meta.Child(T),
            .array => |a| [a.len]std.meta.Child(T),
            else => @compileError("Expected a vector or array type, got: " ++ @typeName(T)),
        };
        pub const num_elements = switch (@typeInfo(T)) {
            .vector => |v| v.len,
            .array => |a| a.len,
            else => @compileError("Expected a vector or array type, got: " ++ @typeName(T)),
        };
    };
}
