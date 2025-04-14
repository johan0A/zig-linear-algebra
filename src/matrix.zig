const std = @import("std");

pub fn Mat(comptime T: type, comptime rows: usize, comptime cols: usize) type {
    return struct {
        const Self = @This();

        const alignement = @alignOf(@Vector(std.simd.suggestVectorLength(T) orelse 1, T));
        const DataType = [rows][cols]T;

        items: DataType align(alignement),
        comptime rows: comptime_int = rows,
        comptime cols: comptime_int = cols,
        comptime Type: type = T,

        pub fn init(values: DataType) Self {
            return Self{
                .items = values,
            };
        }

        pub fn mul(self: Self, other: anytype) Self {
            if (self.cols != other.rows) @compileError("Number of columns of self must be equal to number of rows of other");
            if (self.Type != other.Type) @compileError("Type of self must be equal to Type of other");

            var result: Self = undefined;
            for (0..result.items.len) |i| {
                for (0..result.items[i].len) |j| {
                    result.items[i][j] = 0;
                    for (0..self.items[i].len) |k| {
                        result.items[i][j] += self.items[i][k] * other.items[k][j];
                    }
                }
            }
            return result;
        }

        pub fn selfMul(self: *Self, other: anytype) void {
            self.* = self.mul(other);
        }
    };
}

test "Matrix multiplication" {
    {
        const a = Mat(f32, 2, 2).init(.{
            .{ 1.0, 2.0 },
            .{ 3.0, 4.0 },
        });
        const b = Mat(f32, 2, 2).init(.{
            .{ 5.0, 6.0 },
            .{ 7.0, 8.0 },
        });
        const excpected_c = Mat(f32, 2, 2).init(.{
            .{ 19.0, 22.0 },
            .{ 43.0, 50.0 },
        });
        const c = a.mul(b);
        try std.testing.expectEqual(excpected_c, c);
    }

    {
        const a = Mat(f32, 2, 3).init(.{
            .{ 1.0, 2.0, 3.0 },
            .{ 4.0, 5.0, 6.0 },
        });
        const b = Mat(f32, 3, 3).init(.{
            .{ 1.0, 2.0, 3.0 },
            .{ 4.0, 5.0, 6.0 },
            .{ 7.0, 8.0, 9.0 },
        });
        const excpected_f = Mat(f32, 2, 3).init(.{
            .{ 30, 36, 42 },
            .{ 66, 81, 96 },
        });
        const c = a.mul(b);
        try std.testing.expectEqual(excpected_f, c);
    }

    {
        const a = Mat(f32, 4, 4).init(.{
            .{ 1, 2, 3, 4 },
            .{ 5, 6, 7, 8 },
            .{ 9, 10, 11, 12 },
            .{ 13, 14, 15, 16 },
        });
        const b = Mat(f32, 4, 4).init(.{
            .{ 17, 18, 19, 20 },
            .{ 21, 22, 23, 24 },
            .{ 25, 26, 27, 28 },
            .{ 29, 30, 31, 32 },
        });
        const excpected_c = Mat(f32, 4, 4).init(.{
            .{ 250, 260, 270, 280 },
            .{ 6.18e2, 6.44e2, 6.7e2, 6.96e2 },
            .{ 9.86e2, 1.028e3, 1.07e3, 1.112e3 },
            .{ 1.354e3, 1.412e3, 1.47e3, 1.528e3 },
        });
        const c = a.mul(b);
        try std.testing.expectEqual(excpected_c, c);
    }
}
