const std = @import("std");
const vec = @import("./root.zig").vec;
const meta = @import("meta.zig");
/// column major generic matrix type
pub fn Mat(comptime T: type, comptime cols_: usize, comptime rows_: usize) type {
    return extern struct {
        const Self = @This();
        pub const rows: comptime_int = rows_;
        pub const cols: comptime_int = cols_;
        pub const Type: type = T;
        pub const is_square: bool = rows == cols;

        items: [cols][rows]T,


        pub inline fn from_column_major_array(values: [cols][rows]T) Self {
            return .{ .items = values };
        }

        /// performs a transpose operation, usefull for more human readable mat literals
        pub inline fn from_row_major_array(values: [rows][cols]T) Self {
            return Mat(T, rows, cols).from_column_major_array(values).transpose();
        }

        // generated code seams fast but tbd
        pub fn transpose(self: Self) Mat(T, rows, cols) {
            var result: Mat(T, rows, cols) = .from_column_major_array(undefined);
            for (0..cols) |c| {
                for (0..rows) |r| {
                    result.items[r][c] = self.items[c][r];
                }
            }
            return result;
        }

        /// Scalar multiplication
        pub fn scalar_mul(self: Self, scalar: T) Self {
            const items: [rows * cols]T = @bitCast(self.items);
            var result_items: [rows * cols]T = undefined;
            for (&result_items, items) |*result_item, item| {
                result_item.* = item * scalar;
            }
            return .from_column_major_array(@bitCast(result_items));
        }

        // `other` must be a matrix with the same number of rows as the numbers of columns of `self`
        pub fn mul(self: Self, other: anytype) Mat(T, @TypeOf(other).cols, Self.rows) {
            if (Self.cols != @TypeOf(other).rows) @compileError("number of columns of self must be equal to number of rows of other");
            if (Self.Type != @TypeOf(other).Type) @compileError("type of self must be equal to Type of other");
            const Wt = @Vector(rows, T);

            var result: Mat(T, @TypeOf(other).cols, Self.rows) = undefined;
            for (0..@TypeOf(result).cols) |i| {
                result.items[i] = @as(Wt, self.items[0]) * @as(Wt, @splat(other.items[i][0]));
                for (1..Self.cols) |j| {
                    result.items[i] = @as(Wt, result.items[i]) + @as(Wt, self.items[j]) * @as(Wt, @splat(other.items[i][j]));
                }
            }
            return result;
        }

        pub fn add(self: Self, other: Self) Self {
            var result = Self{ .items = undefined };
            for (0..cols) |c| {
                for (0..rows) |r| {
                    result.items[c][r] = self.items[c][r] + other.items[c][r];
                }
            }
            return result;
        }

        pub inline fn modify_row(self: Self, index: usize, v: anytype) Self {
            const num_elements = meta.array_vector_length(@TypeOf(v));
            if (num_elements > cols) @compileError("row length must be less than or equal to number of columns");
            var result = self;
            for (0..num_elements) |i| {
                result.items[i][index] = v[i];
            }
            return result;
        }

        pub inline fn modify_column(self: Self, index: usize, v: anytype) Self {
            //const info = vec.info(@TypeOf(v));
            const num_elements = meta.array_vector_length(@TypeOf(v));
            if (num_elements > rows) @compileError("column length must be less than or equal to number of rows");
            var result = self;
            for (0..num_elements) |i| {
                result.items[index][i] = v[i];
            }
            return result;
        }

        pub inline fn column(self: Self, index: usize) @Vector(rows, T) {
            return self.items[index];
        }

        pub inline fn row(self: Self, index: usize) @Vector(cols, T) {
            var result: @Vector(cols, T) = undefined;
            for (0..cols) |c| {
                result[c] = self.items[c][index];
            }
            return result;
        }

        pub fn extract(self: Self, comptime sub_col: usize, comptime sub_row: usize) Mat(T, sub_col, sub_row) {
            if (sub_col > cols or sub_row > rows) @compileError("sub matrix dimensions must be less than or equal to matrix dimensions");
            var result: Mat(T, sub_col, sub_row) = .from_column_major_array(undefined);
            for (0..sub_col) |c| {
                for (0..sub_row) |r| {
                    result.items[c][r] = self.items[c][r];
                }
            }
            return result;
        }

        pub fn sub(self: Self, other: Self) Self {
            var result: Self = .{ .items = undefined };
            for (0..cols) |c| {
                for (0..rows) |r| {
                    result.items[c][r] = self.items[c][r] - other.items[c][r];
                }
            }
            return result;
        }

        /// create a perspective projection matrix
        pub fn perspective(fovy: T, aspect: T, near: T, far: T) Self {
            if (rows != 4 or cols != 4) @compileError("Perspective matrix must be 4x4");

            const tanHalfFovy = std.math.tan(fovy / 2);

            var result: Self = .zero;
            result.items[0][0] = 1.0 / (aspect * tanHalfFovy);
            result.items[1][1] = 1.0 / tanHalfFovy;
            result.items[2][2] = far / (near - far);
            result.items[2][3] = -1.0;
            result.items[3][2] = -(far * near) / (far - near);

            return result;
        }

        /// create a look-at view matrix
        pub fn lookAt(eye: @Vector(3, T), center: @Vector(3, T), up: @Vector(3, T)) Self {
            if (rows != 4 or cols != 4) @compileError("Look-at matrix must be 4x4");

            const f = vec.normalize(center - eye);
            const s = vec.normalize(vec.cross(f, up));
            const u = vec.cross(s, f);

            var result: Self = .identity;
            result.items[0][0] = s[0];
            result.items[1][0] = s[1];
            result.items[2][0] = s[2];

            result.items[0][1] = u[0];
            result.items[1][1] = u[1];
            result.items[2][1] = u[2];

            result.items[0][2] = -f[0];
            result.items[1][2] = -f[1];
            result.items[2][2] = -f[2];

            result.items[3][0] = -vec.dot(s, eye);
            result.items[3][1] = -vec.dot(u, eye);
            result.items[3][2] = vec.dot(f, eye);

            return result;
        }

        pub fn translate(self: Self, vector: @Vector(rows - 1, T)) Self {
            comptime {
                std.debug.assert(rows == cols);
            }
            var result = self;
            result.items[cols - 1][0 .. rows - 1].* = self.items[cols - 1][0 .. rows - 1].* + vector;
            return result;
        }

        pub inline fn position(self: Self) @Vector(rows - 1, T) {
            if (rows != cols) @compileError("Transform matrix must be square");
            return self.items[cols - 1][0 .. rows - 1].*;
        }

        /// Scaling transform matrix
        pub fn scale(self: Self, factors: @Vector(rows - 1, T)) Self {
            if (rows != cols) @compileError("Transform matrix must be square");

            var result = self;
            inline for (0..rows - 1) |i| {
                result.items[i][0 .. rows - 1].* = self.items[i][0 .. rows - 1].* * @as(@Vector(rows - 1, T), @splat(factors[i]));
            }

            return result;
        }

        pub fn rotate(self: Self, angle: T, axis: @Vector(3, T)) Self {
            if (rows != cols) @compileError("Transform matrix must be square");
            if (rows != 4 or cols != 4) @compileError("unsuported dimensions, only suports 4x4");

            const a = vec.normalize(axis);
            const c = std.math.cos(angle);
            const s = std.math.sin(angle);
            const t = 1.0 - c;

            const rot: Self = .{
                .items = .{
                    .{ t * a[0] * a[0] + c, t * a[0] * a[1] + s * a[2], t * a[0] * a[2] - s * a[1], 0 },
                    .{ t * a[0] * a[1] - s * a[2], t * a[1] * a[1] + c, t * a[1] * a[2] + s * a[0], 0 },
                    .{ t * a[0] * a[2] + s * a[1], t * a[1] * a[2] - s * a[0], t * a[2] * a[2] + c, 0 },
                    .{ 0, 0, 0, 1 },
                },
            };

            return self.mul(rot);
        }

        pub const identity = blk: {
            if (rows != cols) @compileError("Identity matrix must be square");
            var result: Self = .zero;
            for (0..cols) |i| {
                result.items[i][i] = 1;
            }
            break :blk result;
        };

        pub const zero: Self = .from_column_major_array(@splat(@splat(0)));

        pub fn format(self: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
            var max_widths: [cols]usize = [_]usize{0} ** cols;
            for (0..cols) |c| {
                for (0..rows) |r| {
                    const len = std.fmt.count("{d}", .{self.items[c][r]});
                    max_widths[c] = @max(max_widths[c], len);
                }
            }

            for (0..rows) |r| {
                try writer.writeAll("[");
                for (0..cols) |c| {
                    const len = std.fmt.count("{d}", .{self.items[c][r]});
                    for (0..max_widths[c] - len) |_| {
                        try writer.writeByte(' ');
                    }
                    try writer.print("{d}", .{self.items[c][r]});
                    if (c < cols - 1) try writer.writeAll(", ");
                }
                try writer.writeByte(']');
                if (r != rows - 1) try writer.writeByte('\n');
            }
        }

        pub fn eql(self: Self, other: Self) bool {
            for (0..cols) |c| {
                for (0..rows) |r| {
                    if (self.items[c][r] != other.items[c][r]) {
                        return false;
                    }
                }
            }
            return true;
        }
    };
}

test "format" {
    const c: Mat(f32, 3, 3) = .from_row_major_array(.{
        .{ 9, 12, 15 },
        .{ 19, 26, 33 },
        .{ 29, 40, 51 },
    });
    var buff: [128]u8 = undefined;
    const result = try std.fmt.bufPrint(&buff, "{f}", .{c});
    try std.testing.expectEqualStrings(
        \\[ 9, 12, 15]
        \\[19, 26, 33]
        \\[29, 40, 51]
    , result);
}

test "translate" {
    const c = Mat(f32, 4, 4).identity.translate(.{ 1, 2, 3 });
    const expected: Mat(f32, 4, 4) = .from_row_major_array(.{
        .{ 1, 0, 0, 1 },
        .{ 0, 1, 0, 2 },
        .{ 0, 0, 1, 3 },
        .{ 0, 0, 0, 1 },
    });
    try std.testing.expectEqual(expected, c);
}

test "modify_column" {
    var m = Mat(f32, 4, 4).zero;
    m = m.modify_column(0, @Vector(4, f32){ 1, 2, 3, 4 });
    try std.testing.expectEqual(m.column(0), .{ 1, 2, 3, 4 });
    m = m.modify_column(0, @Vector(3, f32){ 5, 6, 7 });
    try std.testing.expectEqual(m.column(0), .{ 5, 6, 7, 4 });

    m = m.modify_column(0, @Vector(4, f32){ 8, 9, 10, 0 });
    m = m.modify_column(1, @Vector(4, f32){ 11, 12, 13, 0 });
    m = m.modify_column(2, @Vector(4, f32){ 14, 15, 16, 0 });
    m = m.modify_column(3, @Vector(4, f32){ 17, 18, 19, 0 });

    try std.testing.expectEqual(m.column(0), .{ 8, 9, 10, 0 });
    try std.testing.expectEqual(m.column(1), .{ 11, 12, 13, 0 });
    try std.testing.expectEqual(m.column(2), .{ 14, 15, 16, 0 });
    try std.testing.expectEqual(m.position(), .{ 17, 18, 19 });
}

test "mul" {
    {
        const a = Mat(f32, 2, 2).from_column_major_array(.{
            .{ 1, 2 },
            .{ 3, 4 },
        });
        const b = Mat(f32, 2, 2).from_column_major_array(.{
            .{ 5, 6 },
            .{ 7, 8 },
        });
        const c = a.mul(b);

        const excpected_c = Mat(f32, 2, 2).from_column_major_array(.{
            .{ 23, 34 },
            .{ 31, 46 },
        });
        try std.testing.expectEqual(excpected_c, c);
    }

    {
        const a = Mat(f32, 2, 3).from_column_major_array(.{
            .{ 1, 2, 3 },
            .{ 4, 5, 6 },
        });
        const b = Mat(f32, 3, 2).from_column_major_array(.{
            .{ 1, 2 },
            .{ 3, 4 },
            .{ 5, 6 },
        });
        const c = a.mul(b);

        const excpected_c = Mat(f32, 3, 3).from_column_major_array(.{
            .{ 9, 12, 15 },
            .{ 19, 26, 33 },
            .{ 29, 40, 51 },
        });
        try std.testing.expectEqual(excpected_c, c);
    }

    {
        const a = Mat(f32, 4, 4).from_column_major_array(.{
            .{ 1, 2, 3, 4 },
            .{ 5, 6, 7, 8 },
            .{ 9, 10, 11, 12 },
            .{ 13, 14, 15, 16 },
        });
        const b = Mat(f32, 4, 4).from_column_major_array(.{
            .{ 17, 18, 19, 20 },
            .{ 21, 22, 23, 24 },
            .{ 25, 26, 27, 28 },
            .{ 29, 30, 31, 32 },
        });
        const c = a.mul(b);

        const excpected_c = Mat(f32, 4, 4).from_column_major_array(.{
            .{ 538, 612, 686, 760 },
            .{ 650, 740, 830, 920 },
            .{ 762, 868, 974, 1080 },
            .{ 874, 996, 1118, 1240 },
        });
        try std.testing.expectEqual(excpected_c, c);
    }
}

test "scale" {
    {
        const mat: Mat(f32, 4, 4) = .from_row_major_array(.{
            .{ 1, 0, 0, 5 },
            .{ 0, 1, 0, 6 },
            .{ 0, 0, 1, 7 },
            .{ 0, 0, 0, 1 },
        });
        const scaled = mat.scale(.{ 2, 3, 4 });

        const expected: Mat(f32, 4, 4) = .from_row_major_array(.{
            .{ 2, 0, 0, 5 },
            .{ 0, 3, 0, 6 },
            .{ 0, 0, 4, 7 },
            .{ 0, 0, 0, 1 },
        });
        try std.testing.expectEqual(expected, scaled);
    }

    {
        const mat: Mat(f32, 3, 3) = .from_row_major_array(.{
            .{ 0.707, -0.707, 0 },
            .{ 0.707, 0.707, 0 },
            .{ 0, 0, 1 },
        });

        const scaled = mat.scale(.{ 2, 3 });

        const expected: Mat(f32, 3, 3) = .from_row_major_array(.{
            .{ 1.414, -2.121, 0 },
            .{ 1.414, 2.121, 0 },
            .{ 0, 0, 1 },
        });

        for (0..3) |c| {
            for (0..3) |r| {
                try std.testing.expectApproxEqAbs(expected.items[c][r], scaled.items[c][r], 0.001);
            }
        }
    }
}
