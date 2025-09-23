# Zig Linear Algebra (ZLA)

[![CI](https://github.com/flying-swallow/zig-linear-algebra/actions/workflows/ci.yml/badge.svg)](https://github.com/flying-swallow/zig-linear-algebra/actions/workflows/ci.yml)

A high-performance linear algebra library for Zig, providing vector, matrix, quaternion, and geometry operations.

## Installation

```zig
zig fetch --save "git+https://github.com/flying-swallow/zig-linear-algebra.git"
```

Then in your `build.zig`:

```zig
const zla = b.dependency("zla", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("zla", zla.module("zla"));
```

