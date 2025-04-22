const std = @import("std");
const vec = @import("./root.zig").vec;

/// column major matrix type
pub fn Mat(comptime T: type, comptime cols: usize, comptime rows: usize) type {
    return struct {
        const Self = @This();

        const alignement = @alignOf(@Vector(rows, T));

        items: [cols][rows]T align(alignement),

        comptime rows: comptime_int = rows,
        comptime cols: comptime_int = cols,
        comptime Type: type = T,

        pub inline fn fromCM(values: [cols][rows]T) Self {
            return Self{ .items = values };
        }

        /// performs a transpose operation, usefull for more human readable mat literals
        pub inline fn fromRM(values: [rows][cols]T) Self {
            return Mat(T, rows, cols).fromCM(values).transpose();
        }

        // generated code seams fast but tbd
        pub fn transpose(self: Self) Mat(T, rows, cols) {
            var result: Mat(T, rows, cols) = .fromCM(undefined);
            for (0..cols) |c| {
                for (0..rows) |r| {
                    result.items[r][c] = self.items[c][r];
                }
            }
            return result;
        }

        /// Scalar multiplication
        pub fn scalarMul(self: Self, scalar: T) Self {
            const items: [rows * cols]T = @bitCast(self.items);
            var result_items: [rows * cols]T = undefined;
            for (&result_items, items) |*result_item, item| {
                result_item.* = item * scalar;
            }
            return Self.fromCM(@bitCast(result_items));
        }

        // `other` can be a scalar or a matrix with the same number of rows as the numbers of columns of `self`
        pub fn mul(self: Self, other: anytype) Mat(T, other.cols, self.rows) {
            if (self.cols != other.rows) @compileError("number of columns of self must be equal to number of rows of other");
            if (self.Type != other.Type) @compileError("type of self must be equal to Type of other");
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

        pub inline fn selfMul(self: *Self, other: anytype) void {
            self.* = self.mul(other);
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

        pub inline fn selfAdd(self: *Self, other: Self) void {
            self.* = self.add(other);
        }

        pub fn sub(self: Self, other: Self) Self {
            var result = Self{ .items = undefined };
            for (0..cols) |c| {
                for (0..rows) |r| {
                    result.items[c][r] = self.items[c][r] - other.items[c][r];
                }
            }
            return result;
        }

        pub inline fn selfSub(self: *Self, other: Self) void {
            self.* = self.sub(other);
        }

        /// create a perspective projection matrix
        pub fn perspective(fovy: T, aspect: T, near: T, far: T) Self {
            if (rows != 4 or cols != 4) @compileError("Perspective matrix must be 4x4");

            const tanHalfFovy = std.math.tan(fovy / 2);

            var result = Self.zero;
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

            var result = Self.identity;
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
            if (rows != cols) @compileError("Transform matrix must be square");
            var result = self;
            result.items[cols - 1][0 .. rows - 1].* = self.items[cols - 1][0 .. rows - 1].* + vector;
            return result;
        }

        pub inline fn selfTranslate(self: *Self, vector: @Vector(rows - 1, T)) void {
            self.* = self.translate(vector);
        }

        /// Scaling transform matrix
        pub fn scale(self: Self, factors: @Vector(rows - 1, T)) Self {
            if (rows != cols) @compileError("Transform matrix must be square");

            var result = self;
            for (0..rows - 1) |i| {
                result.items[i][0 .. cols - 1].* = self.items[i][0 .. cols - 1].* * factors;
            }

            return result;
        }

        pub inline fn selfScale(self: *Self, vector: @Vector(rows - 1, T)) void {
            self.* = self.scale(vector);
        }

        pub fn rotate(self: Self, angle: T, axis: @Vector(rows, T)) Self {
            if (rows != cols) @compileError("Transform matrix must be square");
            if (rows != 4 or cols != 4) @compileError("unsuported dimensions, only suports 4x4");

            const a = vec.normalize(axis);
            const c = std.math.cos(angle);
            const s = std.math.sin(angle);
            const t = 1.0 - c;

            const rot = Self{
                .items = .{
                    .{ t * a[0] * a[0] + c, t * a[0] * a[1] + s * a[2], t * a[0] * a[2] - s * a[1], 0 },
                    .{ t * a[0] * a[1] - s * a[2], t * a[1] * a[1] + c, t * a[1] * a[2] + s * a[0], 0 },
                    .{ t * a[0] * a[2] + s * a[1], t * a[1] * a[2] - s * a[0], t * a[2] * a[2] + c, 0 },
                    .{ 0, 0, 0, 1 },
                },
            };

            return self.mul(rot);
        }

        pub inline fn selfRotate(self: *Self, angle: T, axis: @Vector(3, T)) void {
            self.* = self.rotate(angle, axis);
        }

        pub const identity = blk: {
            if (rows != cols) @compileError("Identity matrix must be square");
            var result: Self = .zero;
            for (0..cols) |i| {
                result.items[i][i] = 1;
            }
            break :blk result;
        };

        pub const zero: Self = .fromCM(@splat(@splat(0)));

        // TODO: doc
        pub fn format(
            self: Self,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            const separator_indx = comptime std.mem.lastIndexOfScalar(u8, fmt, '|');
            const scalar_fmt = if (separator_indx) |i| fmt[i + 1 ..] else fmt;
            const grid_fmt = if (separator_indx) |i| fmt[0..i] else "g";

            if (comptime std.mem.eql(u8, grid_fmt, "l")) {
                try writer.writeAll("[");
                for (0..rows) |r| {
                    try writer.writeAll("[");
                    for (0..cols) |c| {
                        try std.fmt.formatType(self.items[c][r], scalar_fmt, options, writer, 0);
                        if (c < cols - 1) try writer.writeAll(", ");
                    }
                    if (r < rows - 1) try writer.writeAll(", ");
                    try writer.writeAll("]");
                }
                try writer.writeAll("]");
            } else if (comptime std.mem.eql(u8, grid_fmt, "g")) {
                for (0..rows) |r| {
                    try writer.writeAll("[");
                    for (0..cols) |c| {
                        try std.fmt.formatType(self.items[c][r], scalar_fmt, options, writer, 0);
                        if (c < cols - 1) try writer.writeAll(", ");
                    }
                    try writer.writeAll("]\n");
                }
            } else @compileError("invalid matrix fmt specificer, specificer must be `l` or `g` but is `" ++ grid_fmt ++ "`");
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

test "translate" {
    const c = Mat(f32, 4, 4).identity.translate(.{ 1, 2, 3 });
    const excpected_c: Mat(f32, 4, 4) = .fromRM(.{
        .{ 1, 0, 0, 1 },
        .{ 0, 1, 0, 2 },
        .{ 0, 0, 1, 3 },
        .{ 0, 0, 0, 1 },
    });
    try std.testing.expectEqual(excpected_c, c);
}

test "mul" {
    {
        const a = Mat(f32, 2, 2).fromCM(.{
            .{ 1, 2 },
            .{ 3, 4 },
        });
        const b = Mat(f32, 2, 2).fromCM(.{
            .{ 5, 6 },
            .{ 7, 8 },
        });
        const c = a.mul(b);

        const excpected_c = Mat(f32, 2, 2).fromCM(.{
            .{ 23, 34 },
            .{ 31, 46 },
        });
        try std.testing.expectEqual(excpected_c, c);
    }

    {
        const a = Mat(f32, 2, 3).fromCM(.{
            .{ 1, 2, 3 },
            .{ 4, 5, 6 },
        });
        const b = Mat(f32, 3, 2).fromCM(.{
            .{ 1, 2 },
            .{ 3, 4 },
            .{ 5, 6 },
        });
        const c = a.mul(b);

        const excpected_c = Mat(f32, 3, 3).fromCM(.{
            .{ 9, 12, 15 },
            .{ 19, 26, 33 },
            .{ 29, 40, 51 },
        });
        try std.testing.expectEqual(excpected_c, c);
    }

    {
        const a = Mat(f32, 4, 4).fromCM(.{
            .{ 1, 2, 3, 4 },
            .{ 5, 6, 7, 8 },
            .{ 9, 10, 11, 12 },
            .{ 13, 14, 15, 16 },
        });
        const b = Mat(f32, 4, 4).fromCM(.{
            .{ 17, 18, 19, 20 },
            .{ 21, 22, 23, 24 },
            .{ 25, 26, 27, 28 },
            .{ 29, 30, 31, 32 },
        });
        const c = a.mul(b);

        const excpected_c = Mat(f32, 4, 4).fromCM(.{
            .{ 538, 612, 686, 760 },
            .{ 650, 740, 830, 920 },
            .{ 762, 868, 974, 1080 },
            .{ 874, 996, 1118, 1240 },
        });
        try std.testing.expectEqual(excpected_c, c);
    }
}
