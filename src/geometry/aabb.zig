const std = @import("std");
const vec = @import("../vector.zig");

pub fn AABB(comptime T: type) type {
    return struct {
        min: @Vector(3, T),
        max: @Vector(3, T),
        const Self = @This();

        pub const InvDirection = struct {
            inv_direction: @Vector(3, T), // 1 / ray direction
            is_parallel: @Vector(3, bool), // true if ray direction is close to zero

            pub fn from_direction(direction: @Vector(3, T)) @This() {
                return .{
                    .is_parallel = @abs(direction) < @as(@Vector(3, T), @splat(1.0e-20)),
                    .inv_direction = @as(@Vector(3, T), @splat(1)) / direction,
                };
            }
        };

        /// Test overlap of this box with 4 other boxes in parallel, returns a vector of bools indicating overlap for each box
        pub fn test_4_boxes(self: Self, minX: @Vector(4, T), maxX: @Vector(4, T), minY: @Vector(4, T), maxY: @Vector(4, T), minZ: @Vector(4, T), maxZ: @Vector(4, T)) @Vector(4, bool) {
            const box1_minx = @as(@TypeOf(@Vector(4, T)), @splat(self.min[0]));
            const box1_miny = @as(@TypeOf(@Vector(4, T)), @splat(self.min[1]));
            const box1_minz = @as(@TypeOf(@Vector(4, T)), @splat(self.min[2]));
            const box1_maxx = @as(@TypeOf(@Vector(4, T)), @splat(self.max[0]));
            const box1_maxy = @as(@TypeOf(@Vector(4, T)), @splat(self.max[1]));
            const box1_maxz = @as(@TypeOf(@Vector(4, T)), @splat(self.max[2]));

            const nooverlap_x = (box1_minx > maxX) | (box1_maxx < minX);
            const nooverlap_y = (box1_miny > maxY) | (box1_maxy < minY);
            const nooverlap_z = (box1_minz > maxZ) | (box1_maxz < minZ);
            return !(nooverlap_x | nooverlap_y | nooverlap_z);
        }

        pub fn ray_intersection_with_inverse(self: Self, origin: @Vector(3, T), inv_direction: InvDirection) T {
            const flt_min: @Vector(3, T) = @as(@Vector(3, T), @splat(-std.math.floatMax(T)));
            const flt_max: @Vector(3, T) = @as(@Vector(3, T), @splat(std.math.floatMax(T)));

            // test against all three axes simultaneously
            const t1 = (self.min - origin) * inv_direction.inv_direction;
            const t2 = (self.max - origin) * inv_direction.inv_direction;

            // Compute the max of min(t1,t2) and the min of max(t1,t2) ensuring we don't
            // use the results from any directions parallel to the slab.
            var t_min = @select(T, @min(t1, t2), flt_min, inv_direction.is_parallel);
            var t_max = @select(T, @max(t1, t2), flt_max, inv_direction.is_parallel);

            // t_min.xyz = maximum(t_min.x, t_min.y, t_min.z);
            t_min = @max(t_min, vec.swizzle(t_min, "yzx"));
            t_min = @max(t_min, vec.swizzle(t_min, "zxy"));

            // t_max.xyz = minimum(t_max.x, t_max.y, t_max.z);
            t_max = @min(t_max, vec.swizzle(t_max, "yzx"));
            t_max = @min(t_max, vec.swizzle(t_max, "zxy"));

            // if (t_min > t_max) return FLT_MAX;
            var no_intersections: @Vector(3, bool) = t_min > t_max;

            // if (t_max < 0.0f) return FLT_MAX;
            no_intersections = no_intersections | (t_max < @as(@Vector(3, T), @splat(0)));

            // if (inInvDirection.mIsParallel && !(Min <= inOrigin && inOrigin <= Max)) return FLT_MAX; else return t_min;
            const no_parallel_overlap = (origin < self.min) | (origin > self.max);
            no_intersections = no_intersections | (inv_direction.is_parallel & no_parallel_overlap);
            no_intersections = no_intersections | @as(@Vector(3, bool), @splat(no_intersections[1]));
            no_intersections = no_intersections | @as(@Vector(3, bool), @splat(no_intersections[2]));

            return @select(T, t_min, flt_max, no_intersections)[0];
        }

        pub fn from_two_points(p1: @Vector(3, T), p2: @Vector(3, T)) @This() {
            return @This(){
                .min = @min(p1, p2),
                .max = @max(p1, p2),
            };
        }

        pub fn get_center(self: @This()) @Vector(3, T) {
            return (self.min + self.max) * (@as(T, 0.5));
        }

        pub fn get_size(self: @This()) @Vector(3, T) {
            return self.max - self.min;
        }

        pub fn encapsulate_aabb(self: Self, inRHS: Self) Self {
            return .{ .min = @min(self.min, inRHS.min), .max = @max(self.max, inRHS.max) };
        }

        pub fn intersect(self: Self, inRHS: Self) Self {
            return Self{
                .min = @max(self.min, inRHS.min),
                .max = @min(self.max, inRHS.max),
            };
        }

        pub fn expand_by(self: *Self, in: @Vector(3, T)) void {
            self.min -= in;
            self.max += in;
        }
    };
}

test "InvDirection" {
    const AABBf32 = AABB(f32);
    const dir = @Vector(3, f32){ 1.0, 0.0, -1.0 };
    const invDir = AABBf32.InvDirection.from_direction(dir);
    try std.testing.expectEqual(invDir.is_parallel, @Vector(3, bool){ false, true, false });
    try std.testing.expectApproxEqRel(invDir.inv_direction[0], 1.0, 1.0e-6);
    try std.testing.expectApproxEqRel(invDir.inv_direction[1], 0.0, 1.0e-6);
    try std.testing.expectApproxEqRel(invDir.inv_direction[2], -1.0, 1.0e-6);
}

//const Plane = struct {
//    normal: @Vector(3, f32),
//    distance: f32,
//
//    pub fn getNormal(self: @This()) @Vector(3, f32) {
//        return self.normal;
//    }
//
//    pub fn signedDistance(self: @This(), point: @Vector(3, f32)) f32 {
//        return @reduce(.Add, self.normal * point) + self.distance;
//    }
//};
//
//const AABox = @This();
//min: @Vector(3, f32),
//max: @Vector(3, f32),
//
///// Create box from 2 points
//pub fn from_two_points(p1: @Vector(3, f32), p2: @Vector(3, f32)) AABox {
//    return AABox{
//        .min = @min(p1, p2),
//        .max = @min(p1, p2),
//    };
//}
//
///// Create box from indexed triangle
//pub fn from_triangles(vertices: []f32, indexes: []u32) AABox {
//    var box = from_two_points(vertices[indexes[0]], vertices[indexes[1]]);
//    box.encapsulate(vertices[indexes[2]]);
//    return box;
//}
//
///// Get bounding box of size FLT_MAX
//pub fn biggest() AABox {
//    // Max half extent of AABox is 0.5 * FLT_MAX so that getSize() remains finite
//    const half_max = 0.5 * math.floatMax(f32);
//    return AABox{
//        .min = vec3Replicate(-half_max),
//        .max = vec3Replicate(half_max),
//    };
//}
//
///// Comparison operators
//pub fn eql(self: AABox, other: AABox) bool {
//    return @reduce(.And, self.min == other.min) and @reduce(.And, self.max == other.max);
//}
//
//pub fn neql(self: AABox, other: AABox) bool {
//    return !self.eql(other);
//}
//
///// Reset the bounding box to an empty bounding box
//pub fn setEmpty(self: *AABox) void {
//    self.min = vec3Replicate(math.floatMax(f32));
//    self.max = vec3Replicate(-math.floatMax(f32));
//}
//
///// Check if the bounding box is valid (max >= min)
//pub fn isValid(self: AABox) bool {
//    return self.min[0] <= self.max[0] and
//           self.min[1] <= self.max[1] and
//           self.min[2] <= self.max[2];
//}
//
///// Encapsulate point in bounding box
//pub fn encapsulate(self: *AABox, pos: Vec3) void {
//    self.min = vec3Min(self.min, pos);
//    self.max = vec3Max(self.max, pos);
//}
//
///// Encapsulate bounding box in bounding box
//pub fn encapsulateBox(self: *AABox, other: AABox) void {
//    self.min = vec3Min(self.min, other.min);
//    self.max = vec3Max(self.max, other.max);
//}
//
///// Encapsulate triangle in bounding box
//pub fn encapsulateTriangle(self: *AABox, triangle: Triangle) void {
//    self.encapsulate(Vec3{ triangle.v[0][0], triangle.v[0][1], triangle.v[0][2] });
//    self.encapsulate(Vec3{ triangle.v[1][0], triangle.v[1][1], triangle.v[1][2] });
//    self.encapsulate(Vec3{ triangle.v[2][0], triangle.v[2][1], triangle.v[2][2] });
//}
//
///// Encapsulate indexed triangle in bounding box
//pub fn encapsulateIndexedTriangle(self: *AABox, vertices: VertexList, triangle: IndexedTriangle) void {
//    for (triangle.idx) |idx| {
//        self.encapsulate(vertices[idx]);
//    }
//}
//
///// Intersect this bounding box with other, returns the intersection
//pub fn intersect(self: AABox, other: AABox) AABox {
//    return AABox{
//        .min = vec3Max(self.min, other.min),
//        .max = vec3Min(self.max, other.max),
//    };
//}
//
///// Make sure that each edge of the bounding box has a minimal length
//pub fn ensureMinimalEdgeLength(self: *AABox, min_edge_length: f32) void {
//    const min_length = vec3Replicate(min_edge_length);
//    const size = self.max - self.min;
//    const mask = vec3Less(size, min_length);
//    self.max = vec3Select(mask, self.min + min_length, self.max);
//}
//
///// Widen the box on both sides by vector
//pub fn expandBy(self: *AABox, vector: Vec3) void {
//    self.min -= vector;
//    self.max += vector;
//}
//
///// Get center of bounding box
//pub fn getCenter(self: AABox) Vec3 {
//    return (self.min + self.max) * vec3Replicate(0.5);
//}
//
///// Get extent of bounding box (half of the size)
//pub fn getExtent(self: AABox) Vec3 {
//    return (self.max - self.min) * vec3Replicate(0.5);
//}
//
///// Get size of bounding box
//pub fn getSize(self: AABox) Vec3 {
//    return self.max - self.min;
//}
//
///// Get surface area of bounding box
//pub fn getSurfaceArea(self: AABox) f32 {
//    const extent = self.max - self.min;
//    return 2.0 * (extent[0] * extent[1] + extent[0] * extent[2] + extent[1] * extent[2]);
//}
//
///// Get volume of bounding box
//pub fn getVolume(self: AABox) f32 {
//    const extent = self.max - self.min;
//    return extent[0] * extent[1] * extent[2];
//}
//
///// Check if this box contains another box
//pub fn contains(self: AABox, other: AABox) bool {
//    return testAllXYZTrue(vec3LessOrEqual(self.min, other.min)) and
//           testAllXYZTrue(vec3GreaterOrEqual(self.max, other.max));
//}
//
///// Check if this box contains a point
//pub fn containsPoint(self: AABox, point: Vec3) bool {
//    return testAllXYZTrue(vec3LessOrEqual(self.min, point)) and
//           testAllXYZTrue(vec3GreaterOrEqual(self.max, point));
//}
//
///// Check if this box contains a double precision point
//pub fn containsPointD(self: AABox, point: DVec3) bool {
//    const point_f32 = Vec3{ @floatCast(point[0]), @floatCast(point[1]), @floatCast(point[2]) };
//    return self.containsPoint(point_f32);
//}
//
///// Check if this box overlaps with another box
//pub fn overlaps(self: AABox, other: AABox) bool {
//    return !testAnyXYZTrue(vec3Greater(self.min, other.max)) and
//           !testAnyXYZTrue(vec3Less(self.max, other.min));
//}
//
///// Check if this box overlaps with a plane
//pub fn overlapsPlane(self: AABox, plane: Plane) bool {
//    const normal = plane.getNormal();
//    const dist_normal = plane.signedDistance(self.getSupport(normal));
//    const dist_min_normal = plane.signedDistance(self.getSupport(-normal));
//    return dist_normal * dist_min_normal <= 0.0; // If both support points are on the same side of the plane we don't overlap
//}
//
///// Translate bounding box
//pub fn translate(self: *AABox, translation: Vec3) void {
//    self.min += translation;
//    self.max += translation;
//}
//
///// Translate bounding box with double precision
//pub fn translateD(self: *AABox, translation: DVec3) void {
//    const min_d = DVec3{ self.min[0], self.min[1], self.min[2] } + translation;
//    const max_d = DVec3{ self.max[0], self.max[1], self.max[2] } + translation;
//
//    // Round down for min, round up for max to ensure conservative bounds
//    self.min = Vec3{ @floatCast(min_d[0]), @floatCast(min_d[1]), @floatCast(min_d[2]) };
//    self.max = Vec3{ @floatCast(max_d[0]), @floatCast(max_d[1]), @floatCast(max_d[2]) };
//}
//
///// Transform bounding box by 4x4 matrix
//pub fn transformed(self: AABox, matrix: Mat44) AABox {
//    // Start with the translation of the matrix
//    var new_min = Vec3{ matrix[3][0], matrix[3][1], matrix[3][2] };
//    var new_max = new_min;
//
//    // Now find the extreme points by considering the product of the min and max with each column of matrix
//    var c: u32 = 0;
//    while (c < 3) : (c += 1) {
//        const col = Vec3{ matrix[0][c], matrix[1][c], matrix[2][c] };
//
//        const a = col * vec3Replicate(self.min[c]);
//        const b = col * vec3Replicate(self.max[c]);
//
//        new_min += vec3Min(a, b);
//        new_max += vec3Max(a, b);
//    }
//
//    return AABox{ .min = new_min, .max = new_max };
//}
//
///// Transform bounding box by double precision 4x4 matrix
//pub fn transformedD(self: AABox, matrix: DMat44) AABox {
//    // Extract rotation part as f32 matrix
//    var rotation: Mat44 = undefined;
//    for (0..3) |i| {
//        for (0..3) |j| {
//            rotation[i][j] = @floatCast(matrix[i][j]);
//        }
//    }
//    rotation[3] = .{ 0, 0, 0, 1 };
//
//    var result = self.transformed(rotation);
//    const translation = DVec3{ matrix[3][0], matrix[3][1], matrix[3][2] };
//    result.translateD(translation);
//    return result;
//}
//
///// Scale this bounding box, can handle non-uniform and negative scaling
//pub fn scaled(self: AABox, scale: Vec3) AABox {
//    return fromTwoPoints(self.min * scale, self.max * scale);
//}
//
///// Calculate the support vector for this convex shape
//pub fn getSupport(self: AABox, direction: Vec3) Vec3 {
//    return vec3Select(vec3Less(direction, vec3Zero()), self.min, self.max);
//}
//
///// Get the vertices of the face that faces direction the most
//pub fn getSupportingFace(self: AABox, direction: Vec3, vertices: *[4]Vec3) void {
//    const axis = getHighestComponentIndex(direction);
//
//    if (direction[axis] < 0.0) {
//        switch (axis) {
//            0 => {
//                vertices[0] = Vec3{ self.max[0], self.min[1], self.min[2] };
//                vertices[1] = Vec3{ self.max[0], self.max[1], self.min[2] };
//                vertices[2] = Vec3{ self.max[0], self.max[1], self.max[2] };
//                vertices[3] = Vec3{ self.max[0], self.min[1], self.max[2] };
//            },
//            1 => {
//                vertices[0] = Vec3{ self.min[0], self.max[1], self.min[2] };
//                vertices[1] = Vec3{ self.min[0], self.max[1], self.max[2] };
//                vertices[2] = Vec3{ self.max[0], self.max[1], self.max[2] };
//                vertices[3] = Vec3{ self.max[0], self.max[1], self.min[2] };
//            },
//            2 => {
//                vertices[0] = Vec3{ self.min[0], self.min[1], self.max[2] };
//                vertices[1] = Vec3{ self.max[0], self.min[1], self.max[2] };
//                vertices[2] = Vec3{ self.max[0], self.max[1], self.max[2] };
//                vertices[3] = Vec3{ self.min[0], self.max[1], self.max[2] };
//            },
//            else => unreachable,
//        }
//    } else {
//        switch (axis) {
//            0 => {
//                vertices[0] = Vec3{ self.min[0], self.min[1], self.min[2] };
//                vertices[1] = Vec3{ self.min[0], self.min[1], self.max[2] };
//                vertices[2] = Vec3{ self.min[0], self.max[1], self.max[2] };
//                vertices[3] = Vec3{ self.min[0], self.max[1], self.min[2] };
//            },
//            1 => {
//                vertices[0] = Vec3{ self.min[0], self.min[1], self.min[2] };
//                vertices[1] = Vec3{ self.max[0], self.min[1], self.min[2] };
//                vertices[2] = Vec3{ self.max[0], self.min[1], self.max[2] };
//                vertices[3] = Vec3{ self.min[0], self.min[1], self.max[2] };
//            },
//            2 => {
//                vertices[0] = Vec3{ self.min[0], self.min[1], self.min[2] };
//                vertices[1] = Vec3{ self.min[0], self.max[1], self.min[2] };
//                vertices[2] = Vec3{ self.max[0], self.max[1], self.min[2] };
//                vertices[3] = Vec3{ self.max[0], self.min[1], self.min[2] };
//            },
//            else => unreachable,
//        }
//    }
//}
//
///// Get the closest point on or in this box to point
//pub fn getClosestPoint(self: AABox, point: Vec3) Vec3 {
//    return vec3Min(vec3Max(point, self.min), self.max);
//}
//
///// Get the squared distance between point and this box (will be 0 if point is inside the box)
//pub fn getSqDistanceTo(self: AABox, point: Vec3) f32 {
//    const closest = self.getClosestPoint(point);
//    return vec3LengthSq(closest - point);
//}
//
//// Tests
//test "AABox basic functionality" {
//    const testing = std.testing;
//
//    // Test creation from two points
//    const p1 = Vec3{ 0, 0, 0 };
//    const p2 = Vec3{ 1, 1, 1 };
//    const box = fromTwoPoints(p1, p2);
//
//    try testing.expectEqual(Vec3{ 0, 0, 0 }, box.min);
//    try testing.expectEqual(Vec3{ 1, 1, 1 }, box.max);
//
//    // Test center calculation
//    const center = box.getCenter();
//    try testing.expectEqual(Vec3{ 0.5, 0.5, 0.5 }, center);
//
//    // Test size calculation
//    const size = box.getSize();
//    try testing.expectEqual(Vec3{ 1, 1, 1 }, size);
//
//    // Test contains point
//    try testing.expect(box.containsPoint(Vec3{ 0.5, 0.5, 0.5 }));
//    try testing.expect(!box.containsPoint(Vec3{ 2, 2, 2 }));
//}
//
//test "AABox encapsulation" {
//    const testing = std.testing;
//
//    var box = fromTwoPoints(Vec3{ 0, 0, 0 }, Vec3{ 1, 1, 1 });
//    box.encapsulate(Vec3{ 2, 0.5, 0.5 });
//
//    try testing.expectEqual(Vec3{ 0, 0, 0 }, box.min);
//    try testing.expectEqual(Vec3{ 2, 1, 1 }, box.max);
//}
//
