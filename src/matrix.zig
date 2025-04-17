const std = @import("std");

pub fn Mat(comptime T: type, comptime cols: usize, comptime rows: usize) type {
    return struct {
        const Self = @This();

        const alignement = @alignOf(@Vector(rows, T));

        items: [cols][rows]T align(alignement),

        comptime rows: comptime_int = rows,
        comptime cols: comptime_int = cols,
        comptime Type: type = T,

        pub fn init(values: [cols][rows]T) Self {
            return Self{
                .items = values,
            };
        }

        pub fn mul(self: Self, other: anytype) Mat(T, other.cols, self.rows) {
            if (self.cols != other.rows) @compileError("Number of columns of self must be equal to number of rows of other");
            if (self.Type != other.Type) @compileError("Type of self must be equal to Type of other");

            const Wt = @Vector(rows, T);

            var result: Mat(T, other.cols, self.rows) = undefined;

            for (0..result.cols) |i| {
                result.items[i] = @as(Wt, self.items[0]) * @as(Wt, @splat(other.items[i][0]));
                for (1..self.cols) |j| {
                    result.items[i] = @as(Wt, result.items[i]) + @as(Wt, self.items[j]) * @as(Wt, @splat(other.items[i][j]));
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
            .{ 1, 2 },
            .{ 3, 4 },
        });
        const b = Mat(f32, 2, 2).init(.{
            .{ 5, 6 },
            .{ 7, 8 },
        });
        const c = a.mul(b);

        const excpected_c = Mat(f32, 2, 2).init(.{
            .{ 23, 34 },
            .{ 31, 46 },
        });
        try std.testing.expectEqual(excpected_c, c);
    }

    {
        const a = Mat(f32, 2, 3).init(.{
            .{ 1, 2, 3 },
            .{ 4, 5, 6 },
        });
        const b = Mat(f32, 3, 2).init(.{
            .{ 1, 2 },
            .{ 3, 4 },
            .{ 5, 6 },
        });
        const c = a.mul(b);

        const excpected_c = Mat(f32, 3, 3).init(.{
            .{ 9, 12, 15 },
            .{ 19, 26, 33 },
            .{ 29, 40, 51 },
        });
        try std.testing.expectEqual(excpected_c, c);
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
        const c = a.mul(b);

        const excpected_c = Mat(f32, 4, 4).init(.{
            .{ 538, 612, 686, 760 },
            .{ 650, 740, 830, 920 },
            .{ 762, 868, 974, 1080 },
            .{ 874, 996, 1118, 1240 },
        });
        try std.testing.expectEqual(excpected_c, c);
    }
}
