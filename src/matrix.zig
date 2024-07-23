const std = @import("std");

pub fn Mat(comptime T: type, comptime rows: usize, comptime cols: usize) type {
    return struct {
        const Self = @This();

        const rows_count = rows;
        const cols_count = cols;

        pub const Type = T;

        const DataType = [rows][cols]T;
        data: DataType,

        pub fn init(values: DataType) Self {
            return Self{
                .data = values,
            };
        }

        pub fn mul(self: Self, other: anytype) Self {
            if (@TypeOf(self).cols_count != @TypeOf(other).rows_count) {
                @compileError("Number of columns of self must be equal to number of rows of other");
            }

            var result: Self = undefined;
            for (0..result.data.len) |i| {
                for (0..result.data[i].len) |j| {
                    result.data[i][j] = 0;
                    for (0..self.data[i].len) |k| {
                        result.data[i][j] += self.data[i][k] * other.data[k][j];
                    }
                }
            }

            return result;
        }
    };
}

test "Matrix multiplication" {
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

    const d = Mat(f32, 2, 3).init(.{
        .{ 1.0, 2.0, 3.0 },
        .{ 4.0, 5.0, 6.0 },
    });
    const e = Mat(f32, 3, 3).init(.{
        .{ 1.0, 2.0, 3.0 },
        .{ 4.0, 5.0, 6.0 },
        .{ 7.0, 8.0, 9.0 },
    });
    const excpected_f = Mat(f32, 2, 3).init(.{
        .{ 30, 36, 42 },
        .{ 66, 81, 96 },
    });
    const f = d.mul(e);
    try std.testing.expectEqual(excpected_f, f);
}
