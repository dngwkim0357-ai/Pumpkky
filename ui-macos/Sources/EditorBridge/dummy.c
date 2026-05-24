// Swift Package Manager requires at least one source file in a `target`,
// even if the target is purely a C-header bridge to an external static library.
// All real symbols live in editor-layer/zig-out/lib/libeditor.a, linked via
// `linkerSettings` in Package.swift.
