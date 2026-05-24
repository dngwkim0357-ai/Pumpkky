//! editor-layer build script
//!
//! Build a static C-ABI library (libeditor.a) that ui-macos links against,
//! plus `zig test` runners.
//!
//! Phase 4.A Wave 1.2 — minimum scaffold.
//! Phase 4.B Wave 2.1 — buffer test target.
//! Phase 4.B Wave 2.2 — tree-sitter + tree-sitter-zig C library integration
//!   via vendor/ git submodules (tree-sitter's own build.zig is pre-0.14 API
//!   and incompatible with Zig 0.16, so we compile its C source ourselves).

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ──────────────────────────────────────────────────────────
    // Main library module (editor-layer libeditor.a)
    // ──────────────────────────────────────────────────────────
    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/ffi.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    addTreeSitterSources(b, lib_mod);

    const lib = b.addLibrary(.{
        .name = "editor",
        .root_module = lib_mod,
        .linkage = .static,
    });
    b.installArtifact(lib);

    // ──────────────────────────────────────────────────────────
    // Test targets
    // ──────────────────────────────────────────────────────────
    const ffi_tests = b.addTest(.{ .root_module = lib_mod });
    const run_ffi_tests = b.addRunArtifact(ffi_tests);

    // Wave 2.1: buffer
    const buffer_mod = b.createModule(.{
        .root_source_file = b.path("src/core/buffer.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const buffer_tests = b.addTest(.{ .root_module = buffer_mod });
    const run_buffer_tests = b.addRunArtifact(buffer_tests);

    // Wave 2.4: editor (Buffer + tree-sitter integration)
    const editor_mod = b.createModule(.{
        .root_source_file = b.path("src/editor.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    addTreeSitterSources(b, editor_mod);
    const editor_tests = b.addTest(.{ .root_module = editor_mod });
    const run_editor_tests = b.addRunArtifact(editor_tests);

    // Wave 2.2: tree-sitter
    const ts_mod = b.createModule(.{
        .root_source_file = b.path("src/core/tree_sitter.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    addTreeSitterSources(b, ts_mod);
    const ts_tests = b.addTest(.{ .root_module = ts_mod });
    const run_ts_tests = b.addRunArtifact(ts_tests);

    // Wave 2.3: LSP client
    const lsp_mod = b.createModule(.{
        .root_source_file = b.path("src/core/lsp_client.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const lsp_tests = b.addTest(.{ .root_module = lsp_mod });
    const run_lsp_tests = b.addRunArtifact(lsp_tests);

    const test_step = b.step("test", "Run unit tests");
    // Phase 4.G: config + ext loader
    const config_mod = b.createModule(.{
        .root_source_file = b.path("src/proj/config.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const config_tests = b.addTest(.{ .root_module = config_mod });
    const run_config_tests = b.addRunArtifact(config_tests);

    const ext_mod = b.createModule(.{
        .root_source_file = b.path("src/ext/loader.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const ext_tests = b.addTest(.{ .root_module = ext_mod });
    const run_ext_tests = b.addRunArtifact(ext_tests);

    test_step.dependOn(&run_ffi_tests.step);
    test_step.dependOn(&run_buffer_tests.step);
    test_step.dependOn(&run_ts_tests.step);
    test_step.dependOn(&run_lsp_tests.step);
    test_step.dependOn(&run_editor_tests.step);
    test_step.dependOn(&run_config_tests.step);
    test_step.dependOn(&run_ext_tests.step);
}

/// Attach tree-sitter core + tree-sitter-zig grammar as C sources on `mod`.
/// Both come from git submodules under editor-layer/vendor/.
/// tree-sitter ships an amalgamated `lib/src/lib.c` that #includes every
/// other .c, so a single TU compile is enough.
fn addTreeSitterSources(b: *std.Build, mod: *std.Build.Module) void {
    // tree-sitter core public headers (consumed by @cImport in tree_sitter.zig)
    mod.addIncludePath(b.path("vendor/tree-sitter/lib/include"));

    // tree-sitter core (amalgamation)
    mod.addCSourceFile(.{
        .file = b.path("vendor/tree-sitter/lib/src/lib.c"),
        .flags = &.{
            "-std=c11",
            "-fvisibility=hidden",
            "-Wno-unused-parameter",
            "-Wno-unused-but-set-variable",
        },
    });
    // lib.c #includes from lib/src/, so add that path too
    mod.addIncludePath(b.path("vendor/tree-sitter/lib/src"));

    // tree-sitter-zig grammar (generated parser.c, single TU)
    mod.addCSourceFile(.{
        .file = b.path("vendor/tree-sitter-zig/src/parser.c"),
        .flags = &.{
            "-std=c11",
            "-Wno-unused-parameter",
        },
    });
    mod.addIncludePath(b.path("vendor/tree-sitter-zig/src"));
}
