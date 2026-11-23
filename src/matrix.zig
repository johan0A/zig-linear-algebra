const std = @import("std");
const vec = @import("root.zig").vec;
const turn = @import("root.zig").turn;

pub const ClipDepth = enum {
    /// OpenGL
    negative_one_to_one,
    /// Vulkan, DirectX, Metal
    zero_to_one,
};

pub const YDirection = enum {
    /// OpenGL, DirectX
    up,
    /// Vulkan
    down,
};

pub const Layout = enum {
    /// Column major, `items[column][row]`. OpenGL, Vulkan, GLM.
    cm,
    /// Row major, `items[row][column]`. DirectX.
    rm,
};

pub const Config = struct {
    clip_depth: ClipDepth = .zero_to_one,
    y_direction: YDirection = .down,
};

pub fn Mat(
    comptime layout: Layout,
    comptime T: type,
    comptime column_count_: usize,
    comptime row_count_: usize,
) type {
    const cm = layout == .cm;

    return extern struct {
        const Self = @This();

        items: [major_count][minor_count]T,

        pub const row_count: comptime_int = row_count_;
        pub const column_count: comptime_int = column_count_;
        pub const Element: type = T;

        pub const major_count: comptime_int = if (cm) column_count else row_count;
        pub const minor_count: comptime_int = if (cm) row_count else column_count;

        pub const identity: Self = blk: {
            if (row_count != column_count) @compileError("identity matrix must be square");
            var result: Self = .zero;
            for (0..row_count) |i| {
                result.items[i][i] = 1;
            }
            break :blk result;
        };

        pub const zero: Self = .{ .items = @splat(@splat(0)) };

        pub inline fn at(self: Self, row_index: usize, column_index: usize) T {
            return if (cm) self.items[column_index][row_index] else self.items[row_index][column_index];
        }

        pub inline fn put(self: *Self, row_index: usize, column_index: usize, value: T) void {
            if (cm) {
                self.items[column_index][row_index] = value;
            } else {
                self.items[row_index][column_index] = value;
            }
        }

        pub inline fn fromColumnMajorArray(values: [column_count][row_count]T) Self {
            if (cm) {
                return .{ .items = values };
            } else {
                var result: Self = undefined;
                for (0..column_count) |c| {
                    for (0..row_count) |r| {
                        result.items[r][c] = values[c][r];
                    }
                }
                return result;
            }
        }

        pub inline fn fromRowMajorArray(values: [row_count][column_count]T) Self {
            if (cm) {
                var result: Self = undefined;
                for (0..row_count) |r| {
                    for (0..column_count) |c| {
                        result.items[c][r] = values[r][c];
                    }
                }
                return result;
            } else {
                return .{ .items = values };
            }
        }

        pub fn transpose(self: Self) Mat(layout, T, row_count, column_count) {
            var result: Mat(layout, T, row_count, column_count) = undefined;
            for (0..column_count) |c| {
                for (0..row_count) |r| {
                    result.put(c, r, self.at(r, c));
                }
            }
            return result;
        }

        pub fn scalarMul(self: Self, scalar: T) Self {
            var result: Self = undefined;
            for (0..major_count) |i| {
                const s: @Vector(minor_count, T) = self.items[i];
                result.items[i] = s * @as(@Vector(minor_count, T), @splat(scalar));
            }
            return result;
        }

        pub fn scalarDiv(self: Self, scalar: T) Self {
            var result: Self = undefined;
            for (0..major_count) |i| {
                const s: @Vector(minor_count, T) = self.items[i];
                result.items[i] = s / @as(@Vector(minor_count, T), @splat(scalar));
            }
            return result;
        }

        pub fn negate(self: Self) Self {
            var result: Self = undefined;
            for (0..major_count) |i| {
                const s: @Vector(minor_count, T) = self.items[i];
                result.items[i] = -s;
            }
            return result;
        }

        pub fn add(self: Self, other: Self) Self {
            var result: Self = undefined;
            for (0..major_count) |i| {
                const a: @Vector(minor_count, T) = self.items[i];
                const b: @Vector(minor_count, T) = other.items[i];
                result.items[i] = a + b;
            }
            return result;
        }

        pub fn sub(self: Self, other: Self) Self {
            var result: Self = undefined;
            for (0..major_count) |i| {
                const a: @Vector(minor_count, T) = self.items[i];
                const b: @Vector(minor_count, T) = other.items[i];
                result.items[i] = a - b;
            }
            return result;
        }

        pub inline fn selfAdd(self: *Self, other: Self) void {
            self.* = self.add(other);
        }

        pub inline fn selfSub(self: *Self, other: Self) void {
            self.* = self.sub(other);
        }

        pub fn mul(self: Self, other: anytype) Mat(layout, T, @TypeOf(other).column_count, Self.row_count) {
            const Other = @TypeOf(other);
            if (Self.column_count != Other.row_count) @compileError("column count of lhs must equal row count of rhs");
            if (Self.Element != Other.Element) @compileError("element types must match");

            const Result = Mat(layout, T, Other.column_count, Self.row_count);
            var result: Result = undefined;

            if (cm) {
                for (0..Result.column_count) |i| {
                    var strip: @Vector(Self.row_count, T) = @as(@Vector(Self.row_count, T), self.items[0]) *
                        @as(@Vector(Self.row_count, T), @splat(other.items[i][0]));
                    for (1..Self.column_count) |j| {
                        strip += @as(@Vector(Self.row_count, T), self.items[j]) *
                            @as(@Vector(Self.row_count, T), @splat(other.items[i][j]));
                    }
                    result.items[i] = strip;
                }
            } else {
                for (0..Result.row_count) |i| {
                    var strip: @Vector(Other.column_count, T) = @as(@Vector(Other.column_count, T), other.items[0]) *
                        @as(@Vector(Other.column_count, T), @splat(self.items[i][0]));
                    for (1..Self.column_count) |k| {
                        strip += @as(@Vector(Other.column_count, T), other.items[k]) *
                            @as(@Vector(Other.column_count, T), @splat(self.items[i][k]));
                    }
                    result.items[i] = strip;
                }
            }
            return result;
        }

        pub fn mulVec(self: Self, v: [column_count]T) [row_count]T {
            if (cm) {
                var result: @Vector(row_count, T) = @as(@Vector(row_count, T), self.items[0]) *
                    @as(@Vector(row_count, T), @splat(v[0]));
                inline for (1..column_count) |j| {
                    result += @as(@Vector(row_count, T), self.items[j]) *
                        @as(@Vector(row_count, T), @splat(v[j]));
                }
                return result;
            } else {
                var result: [row_count]T = undefined;
                inline for (0..row_count) |i| {
                    result[i] = vec.dot(self.items[i], v);
                }
                return result;
            }
        }

        pub inline fn selfMul(self: *Self, other: anytype) void {
            self.* = self.mul(other);
        }

        pub fn determinant(self: Self) T {
            if (row_count != column_count) @compileError("determinant requires a square matrix");
            return cofactorDeterminant(row_count, self.items);
        }

        pub fn inverse(self: Self) ?Self {
            if (row_count != column_count) @compileError("inverse requires a square matrix");

            const d = self.determinant();
            if (d == 0) return null;
            const determinant_inverse = 1.0 / d;

            var result: Self = undefined;
            inline for (0..row_count) |r| {
                inline for (0..column_count) |c| {
                    const sign: T = if ((c + r) % 2 == 0) 1 else -1;
                    const minor = if (cm)
                        rawSubmatrix(row_count, self.items, r, c)
                    else
                        rawSubmatrix(row_count, self.items, c, r);
                    result.put(r, c, sign * cofactorDeterminant(row_count - 1, minor) * determinant_inverse);
                }
            }
            return result;
        }

        fn cofactorDeterminant(comptime n: usize, items: [n][n]T) T {
            if (n == 0) @compileError("matrix dimensions must be > 0");
            if (n == 1) return items[0][0];

            var result: T = 0;
            inline for (0..n) |i| {
                const sign: T = if (i % 2 == 0) 1 else -1;
                result += sign * items[i][0] * cofactorDeterminant(n - 1, rawSubmatrix(n, items, i, 0));
            }
            return result;
        }

        fn rawSubmatrix(
            comptime n: usize,
            items: [n][n]T,
            comptime skip_outer: usize,
            comptime skip_inner: usize,
        ) [n - 1][n - 1]T {
            var result: [n - 1][n - 1]T = undefined;
            inline for (0..n - 1) |a| {
                const sa = if (a < skip_outer) a else a + 1;
                inline for (0..n - 1) |b| {
                    const sb = if (b < skip_inner) b else b + 1;
                    result[a][b] = items[sa][sb];
                }
            }
            return result;
        }

        /// `fov_y_turns` is the vertical field of view.
        pub fn perspective(fov_y_turns: T, aspect: T, near: T, far: T, config: Config) Self {
            if (row_count != 4 or column_count != 4) @compileError("perspective matrix must be 4x4");

            const f = 1.0 / turn.tan(fov_y_turns / 2.0);
            const y_sign: T = if (config.y_direction == .down) -1.0 else 1.0;

            var result: Self = .zero;
            result.put(0, 0, f / aspect);
            result.put(1, 1, f * y_sign);
            result.put(3, 2, -1.0);

            switch (config.clip_depth) {
                .zero_to_one => {
                    result.put(2, 2, far / (near - far));
                    result.put(2, 3, -(far * near) / (far - near));
                },
                .negative_one_to_one => {
                    result.put(2, 2, -(far + near) / (far - near));
                    result.put(2, 3, -(2.0 * far * near) / (far - near));
                },
            }

            return result;
        }

        /// `fov_y_turns` is the vertical field of view.
        /// Assert `config.clip_depth` is `.zero_to_one`.
        pub fn perspectiveReverseZ(fov_y_turns: T, aspect: T, near: T, config: Config) Self {
            if (row_count != 4 or column_count != 4) @compileError("perspective matrix must be 4x4");
            std.debug.assert(config.clip_depth == .zero_to_one);

            const f = 1.0 / turn.tan(fov_y_turns / 2.0);
            const y_sign: T = if (config.y_direction == .down) -1.0 else 1.0;

            var result: Self = .zero;
            result.put(0, 0, f / aspect);
            result.put(1, 1, f * y_sign);
            result.put(3, 2, -1.0);
            result.put(2, 3, near);
            return result;
        }

        pub fn orthographic(left: T, right: T, bottom: T, top: T, near: T, far: T, config: Config) Self {
            if (row_count != 4 or column_count != 4) @compileError("orthographic matrix must be 4x4");

            const y_sign: T = if (config.y_direction == .down) -1.0 else 1.0;
            const width = right - left;
            const height = top - bottom;
            const depth = far - near;

            var result: Self = .zero;
            result.put(0, 0, 2.0 / width);
            result.put(1, 1, y_sign * 2.0 / height);
            result.put(0, 3, -(right + left) / width);
            result.put(1, 3, y_sign * -(top + bottom) / height);
            result.put(3, 3, 1.0);

            switch (config.clip_depth) {
                .zero_to_one => {
                    result.put(2, 2, -1.0 / depth);
                    result.put(2, 3, -near / depth);
                },
                .negative_one_to_one => {
                    result.put(2, 2, -2.0 / depth);
                    result.put(2, 3, -(far + near) / depth);
                },
            }

            return result;
        }

        pub fn lookAt(eye: [3]T, center: [3]T, up: [3]T) Self {
            if (row_count != 4 or column_count != 4) @compileError("lookAt matrix must be 4x4");

            const forward = vec.normalize(vec.sub(center, eye));
            const right = vec.normalize(vec.cross(forward, up));
            const camera_up = vec.cross(right, forward);

            var result: Self = .identity;
            result.put(0, 0, right[0]);
            result.put(0, 1, right[1]);
            result.put(0, 2, right[2]);

            result.put(1, 0, camera_up[0]);
            result.put(1, 1, camera_up[1]);
            result.put(1, 2, camera_up[2]);

            result.put(2, 0, -forward[0]);
            result.put(2, 1, -forward[1]);
            result.put(2, 2, -forward[2]);

            result.put(0, 3, -vec.dot(right, eye));
            result.put(1, 3, -vec.dot(camera_up, eye));
            result.put(2, 3, vec.dot(forward, eye));

            return result;
        }

        pub fn translate(self: Self, offset: [row_count - 1]T) Self {
            if (row_count != column_count) @compileError("transform matrix must be square");

            var result = self;
            inline for (0..row_count) |r| {
                var sum: T = self.at(r, column_count - 1);
                inline for (0..row_count - 1) |i| {
                    sum += self.at(r, i) * offset[i];
                }
                result.put(r, column_count - 1, sum);
            }
            return result;
        }

        pub inline fn selfTranslate(self: *Self, offset: [row_count - 1]T) void {
            self.* = self.translate(offset);
        }

        pub inline fn position(self: Self) [row_count - 1]T {
            if (row_count != column_count) @compileError("transform matrix must be square");
            var result: [row_count - 1]T = undefined;
            inline for (0..row_count - 1) |r| {
                result[r] = self.at(r, column_count - 1);
            }
            return result;
        }

        pub fn scale(self: Self, factors: [row_count - 1]T) Self {
            if (row_count != column_count) @compileError("transform matrix must be square");

            var result = self;
            inline for (0..row_count - 1) |i| {
                inline for (0..row_count) |r| {
                    result.put(r, i, self.at(r, i) * factors[i]);
                }
            }
            return result;
        }

        pub inline fn selfScale(self: *Self, factors: [row_count - 1]T) void {
            self.* = self.scale(factors);
        }

        pub fn rotate(self: Self, angle_turns: T, axis: [3]T) Self {
            if (row_count != column_count) @compileError("rotate requires a square matrix");
            if (row_count < 3) @compileError("rotate requires at least 3x3");

            const a = vec.normalize(axis);
            const cos = turn.cos(angle_turns);
            const sin = turn.sin(angle_turns);
            const t = 1.0 - cos;

            var rotation: Self = .identity;
            rotation.put(0, 0, t * a[0] * a[0] + cos);
            rotation.put(1, 0, t * a[0] * a[1] + sin * a[2]);
            rotation.put(2, 0, t * a[0] * a[2] - sin * a[1]);
            rotation.put(0, 1, t * a[0] * a[1] - sin * a[2]);
            rotation.put(1, 1, t * a[1] * a[1] + cos);
            rotation.put(2, 1, t * a[1] * a[2] + sin * a[0]);
            rotation.put(0, 2, t * a[0] * a[2] + sin * a[1]);
            rotation.put(1, 2, t * a[1] * a[2] - sin * a[0]);
            rotation.put(2, 2, t * a[2] * a[2] + cos);

            return self.mul(rotation);
        }

        pub inline fn selfRotate(self: *Self, angle_turns: T, axis: [3]T) void {
            self.* = self.rotate(angle_turns, axis);
        }

        pub fn fromAxisAngle(axis: [3]T, angle_turns: T) Self {
            if (row_count != column_count) @compileError("fromAxisAngle requires a square matrix");
            if (row_count < 3) @compileError("fromAxisAngle requires at least 3x3");

            return Self.identity.rotate(angle_turns, axis);
        }

        pub fn eql(self: Self, other: Self) bool {
            for (0..major_count) |i| {
                for (0..minor_count) |j| {
                    if (self.items[i][j] != other.items[i][j]) return false;
                }
            }
            return true;
        }

        pub fn approxEql(self: Self, other: Self, tolerance: T) bool {
            for (0..major_count) |i| {
                for (0..minor_count) |j| {
                    if (@abs(self.items[i][j] - other.items[i][j]) > tolerance) return false;
                }
            }
            return true;
        }

        pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            var widths_max: [column_count]usize = @splat(0);
            for (0..column_count) |c| {
                for (0..row_count) |r| {
                    widths_max[c] = @max(widths_max[c], std.fmt.count("{d}", .{self.at(r, c)}));
                }
            }

            for (0..row_count) |r| {
                try writer.writeAll("[");
                for (0..column_count) |c| {
                    const width = std.fmt.count("{d}", .{self.at(r, c)});
                    try writer.splatByteAll(' ', widths_max[c] - width);
                    try writer.print("{d}", .{self.at(r, c)});
                    if (c < column_count - 1) try writer.writeAll(", ");
                }
                try writer.writeByte(']');
                if (r != row_count - 1) try writer.writeByte('\n');
            }
        }
    };
}

test "format" {
    const c: Mat(.cm, f32, 3, 3) = .fromRowMajorArray(.{
        .{ 9, 12, 15 },
        .{ 19, 26, 33 },
        .{ 29, 40, 51 },
    });
    var buffer: [128]u8 = undefined;
    const result = try std.fmt.bufPrint(&buffer, "{f}", .{c});
    try std.testing.expectEqualStrings(
        \\[ 9, 12, 15]
        \\[19, 26, 33]
        \\[29, 40, 51]
    , result);
}

test "translate" {
    const c: Mat(.cm, f32, 4, 4) = .translate(.identity, .{ 1, 2, 3 });
    const expected: Mat(.cm, f32, 4, 4) = .fromRowMajorArray(.{
        .{ 1, 0, 0, 1 },
        .{ 0, 1, 0, 2 },
        .{ 0, 0, 1, 3 },
        .{ 0, 0, 0, 1 },
    });
    try std.testing.expectEqual(expected, c);
}

test "translate with rotation" {
    const rotation: Mat(.cm, f32, 4, 4) = .fromAxisAngle(.{ 0, 0, 1 }, 0.25);
    const translated = rotation.translate(.{ 1, 0, 0 });

    try std.testing.expectApproxEqAbs(@as(f32, 0), translated.position()[0], 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 1), translated.position()[1], 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0), translated.position()[2], 1e-5);
}

test "mul" {
    {
        const a: Mat(.cm, f32, 2, 2) = .fromRowMajorArray(.{
            .{ 1, 3 },
            .{ 2, 4 },
        });
        const b: Mat(.cm, f32, 2, 2) = .fromRowMajorArray(.{
            .{ 5, 7 },
            .{ 6, 8 },
        });
        const expected: Mat(.cm, f32, 2, 2) = .fromRowMajorArray(.{
            .{ 23, 31 },
            .{ 34, 46 },
        });
        try std.testing.expectEqual(expected, a.mul(b));
    }

    {
        const a: Mat(.cm, f32, 2, 3) = .fromRowMajorArray(.{
            .{ 1, 4 },
            .{ 2, 5 },
            .{ 3, 6 },
        });
        const b: Mat(.cm, f32, 3, 2) = .fromRowMajorArray(.{
            .{ 1, 3, 5 },
            .{ 2, 4, 6 },
        });
        const expected: Mat(.cm, f32, 3, 3) = .fromRowMajorArray(.{
            .{ 9, 19, 29 },
            .{ 12, 26, 40 },
            .{ 15, 33, 51 },
        });
        try std.testing.expectEqual(expected, a.mul(b));
    }

    {
        const a: Mat(.cm, f32, 4, 4) = .fromRowMajorArray(.{
            .{ 1, 5, 9, 13 },
            .{ 2, 6, 10, 14 },
            .{ 3, 7, 11, 15 },
            .{ 4, 8, 12, 16 },
        });
        const b: Mat(.cm, f32, 4, 4) = .fromRowMajorArray(.{
            .{ 17, 21, 25, 29 },
            .{ 18, 22, 26, 30 },
            .{ 19, 23, 27, 31 },
            .{ 20, 24, 28, 32 },
        });
        const expected: Mat(.cm, f32, 4, 4) = .fromRowMajorArray(.{
            .{ 538, 650, 762, 874 },
            .{ 612, 740, 868, 996 },
            .{ 686, 830, 974, 1118 },
            .{ 760, 920, 1080, 1240 },
        });
        try std.testing.expectEqual(expected, a.mul(b));
    }
}

test "mulVec" {
    const m: Mat(.cm, f32, 4, 4) = .fromRowMajorArray(.{
        .{ 1, 0, 0, 5 },
        .{ 0, 1, 0, 6 },
        .{ 0, 0, 1, 7 },
        .{ 0, 0, 0, 1 },
    });
    const v = m.mulVec(.{ 1, 2, 3, 1 });
    try std.testing.expectEqual([4]f32{ 6, 8, 10, 1 }, v);

    const m_rm: Mat(.rm, f32, 4, 4) = .fromRowMajorArray(.{
        .{ 1, 0, 0, 5 },
        .{ 0, 1, 0, 6 },
        .{ 0, 0, 1, 7 },
        .{ 0, 0, 0, 1 },
    });
    try std.testing.expectEqual([4]f32{ 6, 8, 10, 1 }, m_rm.mulVec(.{ 1, 2, 3, 1 }));
}

test "format row major" {
    const c: Mat(.rm, f32, 2, 3) = .fromRowMajorArray(.{
        .{ 1, 2 },
        .{ 30, 4 },
        .{ 5, 60 },
    });
    var buffer: [128]u8 = undefined;
    const result = try std.fmt.bufPrint(&buffer, "{f}", .{c});
    try std.testing.expectEqualStrings(
        \\[ 1,  2]
        \\[30,  4]
        \\[ 5, 60]
    , result);
}

test "orthographic" {
    const M = Mat(.cm, f32, 4, 4);
    inline for (.{ YDirection.up, YDirection.down }) |y_direction| {
        const m: M = .orthographic(-2, 6, 1, 5, 0.5, 10, .{ .y_direction = y_direction });
        const top = m.mulVec(.{ 0, 5, -0.5, 1 });
        const bottom = m.mulVec(.{ 0, 1, -10, 1 });
        const sign: f32 = if (y_direction == .up) 1 else -1;
        try std.testing.expectApproxEqAbs(sign, top[1], 1e-5);
        try std.testing.expectApproxEqAbs(-sign, bottom[1], 1e-5);
        try std.testing.expectApproxEqAbs(@as(f32, 0), top[2], 1e-5);
        try std.testing.expectApproxEqAbs(@as(f32, 1), bottom[2], 1e-5);
    }
}

test "lookAt" {
    const M = Mat(.cm, f32, 4, 4);
    const m: M = .lookAt(.{ 1, 2, 3 }, .{ 1, 2, 0 }, .{ 0, 1, 0 });
    const p = m.mulVec(.{ 1, 2, 0, 1 });
    try std.testing.expectApproxEqAbs(@as(f32, 0), p[0], 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0), p[1], 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, -3), p[2], 1e-5);
}

test "scale" {
    {
        const m: Mat(.cm, f32, 4, 4) = .fromRowMajorArray(.{
            .{ 1, 0, 0, 5 },
            .{ 0, 1, 0, 6 },
            .{ 0, 0, 1, 7 },
            .{ 0, 0, 0, 1 },
        });
        const expected: Mat(.cm, f32, 4, 4) = .fromRowMajorArray(.{
            .{ 2, 0, 0, 5 },
            .{ 0, 3, 0, 6 },
            .{ 0, 0, 4, 7 },
            .{ 0, 0, 0, 1 },
        });
        try std.testing.expectEqual(expected, m.scale(.{ 2, 3, 4 }));
    }

    {
        const m: Mat(.cm, f32, 3, 3) = .fromRowMajorArray(.{
            .{ 0.707, -0.707, 0 },
            .{ 0.707, 0.707, 0 },
            .{ 0, 0, 1 },
        });
        const expected: Mat(.cm, f32, 3, 3) = .fromRowMajorArray(.{
            .{ 1.414, -2.121, 0 },
            .{ 1.414, 2.121, 0 },
            .{ 0, 0, 1 },
        });
        try std.testing.expect(m.scale(.{ 2, 3 }).approxEql(expected, 0.001));
    }
}

test "determinant" {
    const m: Mat(.cm, f32, 3, 3) = .fromRowMajorArray(.{
        .{ 1, 2, 3 },
        .{ 0, 1, 4 },
        .{ 5, 6, 0 },
    });
    try std.testing.expectApproxEqAbs(@as(f32, 1), m.determinant(), 1e-5);
}

test "inverse 4x4" {
    const M = Mat(.cm, f32, 4, 4);
    const m: M = .fromRowMajorArray(.{
        .{ 1, 0, 0, 3 },
        .{ 0, 2, 0, 0 },
        .{ 0, 0, 1, -1 },
        .{ 0, 0, 0, 1 },
    });
    const inverse = m.inverse() orelse return error.Singular;
    try std.testing.expect(m.mul(inverse).approxEql(M.identity, 1e-5));
}
