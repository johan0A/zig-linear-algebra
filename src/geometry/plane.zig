const vec = @import("../vector.zig");
const Mat = @import("../matrix.zig").Mat;

pub fn Plane(comptime T: type) type {
    return struct {
        normal: @Vector(3, T),
        c: T, // Distance from origin along the normal

        const Self = @This();

        //pub fn from_normal_and_constant(normal: @Vector(3, T), c: T) Self {
        //    return .{ .normal = normal, .c = c };
        //}

        //pub fn from_point_and_normal(point: @Vector(3, T), normal: @Vector(3, T)) Self {
        //    return .{ .normal = normal, .c = -vec.dot(normal, point) };
        //}

        //pub fn distance_to_point(self: Self, point: @Vector(3, f64)) T {
        //    return vec.dot(self.normal, point) + self.c;
        //}

        //pub fn get_transformed(self: Self, transform: Mat(3,3,T)) Self {
        //    transform.mul(Mat(T, 3, 1).from_column_major(&self.normal)) ;
        //}


    };
}

