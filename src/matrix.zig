const std = @import("std");

pub fn Matrix(comptime T: type, comptime rows: usize, comptime cols: usize) type {
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
    };
}
