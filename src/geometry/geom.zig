const std = @import("std");
const vec = @import("../vector.zig");

pub const AABB = @import("aabb.zig").AABB;
pub const Plane = @import("plane.zig").Plane;

pub fn get_vector_from_buffer(comptime T: type, vertex_index: usize, buffer: []align(4) const u8, byte_offset: usize, byte_stride: usize) T {
    const info = vec.info(T);
    var arr: [info.len]info.child = undefined;
    const element_size = @sizeOf(info.child);
    
    // Copy bytes and cast to the correct type
    const total_bytes = info.len * element_size;
    const begin = byte_offset + vertex_index * byte_stride;
    const byte_slice = buffer[begin..begin + total_bytes];
    @memcpy(std.mem.asBytes(&arr), byte_slice);
    
    const res: T = arr;
    return res;
}

test {
    @import("std").testing.refAllDeclsRecursive(@This());
}


test "vector_from_buffer - basic 2D f32 vector extraction" {
    // Create a buffer with 2D f32 vectors: [1.0, 2.0], [3.0, 4.0], [5.0, 6.0]
    const data = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0 };
    const buffer = std.mem.sliceAsBytes(&data);
    
    // Extract first vector (index 0)
    const vec1 = get_vector_from_buffer(@Vector(2, f32), 0, buffer, 0, 2 * @sizeOf(f32));
    try std.testing.expectEqual(@as(f32, 1.0), vec1[0]);
    try std.testing.expectEqual(@as(f32, 2.0), vec1[1]);
    
    // Extract second vector (index 1)
    const vec2 = get_vector_from_buffer(@Vector(2, f32), 1, buffer, 0, 2 * @sizeOf(f32));
    try std.testing.expectEqual(@as(f32, 3.0), vec2[0]);
    try std.testing.expectEqual(@as(f32, 4.0), vec2[1]);
    
    // Extract third vector (index 2)
    const vec3 = get_vector_from_buffer(@Vector(2, f32), 2, buffer, 0, 2 * @sizeOf(f32));
    try std.testing.expectEqual(@as(f32, 5.0), vec3[0]);
    try std.testing.expectEqual(@as(f32, 6.0), vec3[1]);
}

test "vector_from_buffer - 3D f32 vector extraction" {
    // Create a buffer with 3D f32 vectors: [1.0, 2.0, 3.0], [4.0, 5.0, 6.0]
    var data = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0 };
    const buffer = std.mem.sliceAsBytes(data[0..]);
    
    // Extract first 3D vector
    const vec1 = get_vector_from_buffer(@Vector(3, f32), 0, buffer, 0, 3 * @sizeOf(f32));
    try std.testing.expectEqual(@as(f32, 1.0), vec1[0]);
    try std.testing.expectEqual(@as(f32, 2.0), vec1[1]);
    try std.testing.expectEqual(@as(f32, 3.0), vec1[2]);
    
    // Extract second 3D vector
    const vec2 = get_vector_from_buffer(@Vector(3, f32), 1, buffer, 0, 3 * @sizeOf(f32));
    try std.testing.expectEqual(@as(f32, 4.0), vec2[0]);
    try std.testing.expectEqual(@as(f32, 5.0), vec2[1]);
    try std.testing.expectEqual(@as(f32, 6.0), vec2[2]);
}

test "vector_from_buffer - 4D f32 vector extraction" {
    // Create a buffer with 4D f32 vectors: [1.0, 2.0, 3.0, 4.0], [5.0, 6.0, 7.0, 8.0]
    const buffer = std.mem.asBytes(&[_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0 });
    
    // Extract first 4D vector
    const vec1 = get_vector_from_buffer(@Vector(4, f32), 0, buffer, 0, 4 * @sizeOf(f32));
    try std.testing.expectEqual(@as(f32, 1.0), vec1[0]);
    try std.testing.expectEqual(@as(f32, 2.0), vec1[1]);
    try std.testing.expectEqual(@as(f32, 3.0), vec1[2]);
    try std.testing.expectEqual(@as(f32, 4.0), vec1[3]);
    
    // Extract second 4D vector
    const vec2 = get_vector_from_buffer(@Vector(4, f32), 1, buffer, 0, 4 * @sizeOf(f32));
    try std.testing.expectEqual(@as(f32, 5.0), vec2[0]);
    try std.testing.expectEqual(@as(f32, 6.0), vec2[1]);
    try std.testing.expectEqual(@as(f32, 7.0), vec2[2]);
    try std.testing.expectEqual(@as(f32, 8.0), vec2[3]);
}

test "vector_from_buffer - integer vectors" {
    // Create a buffer with i32 vectors: [1, 2], [3, 4], [5, 6]
    const buffer = std.mem.asBytes(&[_]i32{ 1, 2, 3, 4, 5, 6 });
    
    // Extract vectors
    const vec1 = get_vector_from_buffer(@Vector(2, i32), 0, buffer, 0, 2 * @sizeOf(i32));
    try std.testing.expectEqual(@as(i32, 1), vec1[0]);
    try std.testing.expectEqual(@as(i32, 2), vec1[1]);
    
    const vec2 = get_vector_from_buffer(@Vector(2, i32), 1, buffer, 0, 2 * @sizeOf(i32));
    try std.testing.expectEqual(@as(i32, 3), vec2[0]);
    try std.testing.expectEqual(@as(i32, 4), vec2[1]);
}

test "vector_from_buffer - with byte offset" {
    // Create a buffer with some padding at the beginning
    const data = [_]f32{ 999.0, 888.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0 }; // First two are padding
    const buffer = std.mem.asBytes(&data);
    
    // Start reading from offset (skip the padding)
    const offset = 2 * @sizeOf(f32);
    
    const vec1 = get_vector_from_buffer(@Vector(2, f32), 0, buffer, offset, 2 * @sizeOf(f32));
    try std.testing.expectEqual(@as(f32, 1.0), vec1[0]);
    try std.testing.expectEqual(@as(f32, 2.0), vec1[1]);
    
    const vec2 = get_vector_from_buffer(@Vector(2, f32), 1, buffer, offset, 2 * @sizeOf(f32));
    try std.testing.expectEqual(@as(f32, 3.0), vec2[0]);
    try std.testing.expectEqual(@as(f32, 4.0), vec2[1]);
}

test "vector_from_buffer - interleaved data with larger stride" {
    // Create interleaved position and normal data: [pos_x, pos_y, norm_x, norm_y, pos_x, pos_y, norm_x, norm_y, ...]
    const data = [_]f32{ 
        1.0, 2.0, 0.1, 0.2,  // vertex 0: pos(1,2), normal(0.1,0.2)
        3.0, 4.0, 0.3, 0.4,  // vertex 1: pos(3,4), normal(0.3,0.4)  
        5.0, 6.0, 0.5, 0.6   // vertex 2: pos(5,6), normal(0.5,0.6)
    };
    const buffer = std.mem.asBytes(&data);
    
    // Extract positions (stride = 4 * f32, offset = 0)
    const stride = 4 * @sizeOf(f32);
    
    const pos1 = get_vector_from_buffer(@Vector(2, f32), 0, buffer, 0, stride);
    try std.testing.expectEqual(@as(f32, 1.0), pos1[0]);
    try std.testing.expectEqual(@as(f32, 2.0), pos1[1]);
    
    const pos2 = get_vector_from_buffer(@Vector(2, f32), 1, buffer, 0, stride);
    try std.testing.expectEqual(@as(f32, 3.0), pos2[0]);
    try std.testing.expectEqual(@as(f32, 4.0), pos2[1]);
    
    // Extract normals (stride = 4 * f32, offset = 2 * f32)
    const normal_offset = 2 * @sizeOf(f32);
    
    const norm1 = get_vector_from_buffer(@Vector(2, f32), 0, buffer, normal_offset, stride);
    try std.testing.expectEqual(@as(f32, 0.1), norm1[0]);
    try std.testing.expectEqual(@as(f32, 0.2), norm1[1]);
    
    const norm2 = get_vector_from_buffer(@Vector(2, f32), 1, buffer, normal_offset, stride);
    try std.testing.expectEqual(@as(f32, 0.3), norm2[0]);
    try std.testing.expectEqual(@as(f32, 0.4), norm2[1]);
}

test "vector_from_buffer - f64 vectors" {
    // Test with double precision floats
    const buffer = std.mem.asBytes(&[_]f64{ 1.5, 2.5, 3.5, 4.5 });
    
    const vec1 = get_vector_from_buffer(@Vector(2, f64), 0, buffer, 0, 2 * @sizeOf(f64));
    try std.testing.expectEqual(@as(f64, 1.5), vec1[0]);
    try std.testing.expectEqual(@as(f64, 2.5), vec1[1]);
    
    const vec2 = get_vector_from_buffer(@Vector(2, f64), 1, buffer, 0, 2 * @sizeOf(f64));
    try std.testing.expectEqual(@as(f64, 3.5), vec2[0]);
    try std.testing.expectEqual(@as(f64, 4.5), vec2[1]);
}

test "vector_from_buffer - mixed data types with padding" {
    // Test extracting from a buffer where vectors are not tightly packed
    const VtxData = extern struct {
        pos: @Vector(3, f32),
        padding1: u32, // 4 bytes padding
        normal: @Vector(3, f32),
        padding2: u32, // 4 bytes padding
    };
    
    const vertices = [_]VtxData{
        .{ .pos = .{ 1.0, 2.0, 3.0 }, .padding1 = 0, .normal = .{ 0.1, 0.2, 0.3 }, .padding2 = 0 },
        .{ .pos = .{ 4.0, 5.0, 6.0 }, .padding1 = 0, .normal = .{ 0.4, 0.5, 0.6 }, .padding2 = 0 },
    };
    
    const buffer = std.mem.asBytes(&vertices);
    const vertex_stride = @sizeOf(VtxData);
    
    // Extract positions
    const pos_offset = @offsetOf(VtxData, "pos");
    const pos1 = get_vector_from_buffer(@Vector(3, f32), 0, buffer, pos_offset, vertex_stride);
    try std.testing.expectEqual(@as(f32, 1.0), pos1[0]);
    try std.testing.expectEqual(@as(f32, 2.0), pos1[1]);
    try std.testing.expectEqual(@as(f32, 3.0), pos1[2]);
    
    const pos2 = get_vector_from_buffer(@Vector(3, f32), 1, buffer, pos_offset, vertex_stride);
    try std.testing.expectEqual(@as(f32, 4.0), pos2[0]);
    try std.testing.expectEqual(@as(f32, 5.0), pos2[1]);
    try std.testing.expectEqual(@as(f32, 6.0), pos2[2]);
    
    // Extract normals
    const normal_offset = @offsetOf(VtxData, "normal");
    const norm1 = get_vector_from_buffer(@Vector(3, f32), 0, buffer, normal_offset, vertex_stride);
    try std.testing.expectEqual(@as(f32, 0.1), norm1[0]);
    try std.testing.expectEqual(@as(f32, 0.2), norm1[1]);
    try std.testing.expectEqual(@as(f32, 0.3), norm1[2]);
    
    const norm2 = get_vector_from_buffer(@Vector(3, f32), 1, buffer, normal_offset, vertex_stride);
    try std.testing.expectEqual(@as(f32, 0.4), norm2[0]);
    try std.testing.expectEqual(@as(f32, 0.5), norm2[1]);
    try std.testing.expectEqual(@as(f32, 0.6), norm2[2]);
}
