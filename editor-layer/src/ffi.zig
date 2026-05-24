//! editor-layer C-ABI entry points.
//!
//! All functions intended to be called from Swift (or any other host language)
//! are `export fn` and follow the contract defined in docs/ffi-design.md.
//!
//! Phase 4.A Wave 1.2 — minimum scaffold.
//! Phase 4.B Wave 2.4 — file open/close/save/edit + buffer view FFI.

const std = @import("std");

const editor_mod = @import("editor.zig");
const Editor = editor_mod.Editor;
const FileId = editor_mod.FileId;

/// Process-wide allocator for FFI lifetimes.
const gpa: std.mem.Allocator = std.heap.c_allocator;

// ──────────────────────────────────────────────────────────
// Lifecycle
// ──────────────────────────────────────────────────────────

export fn editor_init() callconv(.c) u64 {
    const editor = gpa.create(Editor) catch return 0;
    editor.* = Editor.init(gpa);
    return @intFromPtr(editor);
}

export fn editor_handle_destroy(handle: u64) callconv(.c) void {
    if (handle == 0) return;
    const editor: *Editor = @ptrFromInt(handle);
    editor.deinit();
    gpa.destroy(editor);
}

export fn editor_free_string(ptr: ?[*:0]u8) callconv(.c) void {
    if (ptr) |p| {
        const slice = std.mem.span(p);
        gpa.free(slice);
    }
}

// ──────────────────────────────────────────────────────────
// File operations (Wave 2.4)
// ──────────────────────────────────────────────────────────

/// Open file by path. Returns FileId > 0 on success, 0 on failure.
/// On failure, *out_err is set to a caller-owned UTF-8 error message
/// (free with `editor_free_string`).
export fn editor_open_file(
    handle: u64,
    path: [*:0]const u8,
    out_err: *?[*:0]u8,
) callconv(.c) u64 {
    out_err.* = null;
    if (handle == 0) {
        out_err.* = dupErr("editor handle is null");
        return 0;
    }
    const editor: *Editor = @ptrFromInt(handle);
    const p = std.mem.span(path);
    const id = editor.openFile(p) catch |err| {
        out_err.* = dupErr(@errorName(err));
        return 0;
    };
    return id;
}

/// Close an open file. Returns 0 on success, -1 if file_id was unknown.
export fn editor_close_file(handle: u64, file_id: u64) callconv(.c) i32 {
    if (handle == 0) return -1;
    const editor: *Editor = @ptrFromInt(handle);
    return if (editor.closeFile(file_id)) 0 else -1;
}

/// Save the current buffer back to disk.
export fn editor_save_file(handle: u64, file_id: u64, out_err: *?[*:0]u8) callconv(.c) i32 {
    out_err.* = null;
    if (handle == 0) {
        out_err.* = dupErr("editor handle is null");
        return -1;
    }
    const editor: *Editor = @ptrFromInt(handle);
    editor.saveFile(file_id) catch |err| {
        out_err.* = dupErr(@errorName(err));
        return -1;
    };
    return 0;
}

/// Apply a text edit. Returns 0 on success, -1 on failure.
export fn editor_apply_edit(
    handle: u64,
    file_id: u64,
    start: u32,
    end: u32,
    replacement: [*]const u8,
    replacement_len: usize,
) callconv(.c) i32 {
    if (handle == 0) return -1;
    const editor: *Editor = @ptrFromInt(handle);
    editor.applyEdit(file_id, start, end, replacement[0..replacement_len]) catch return -1;
    return 0;
}

/// BufferView returned to the UI. `text` is caller-owned and must be released
/// with `editor_release_buffer_view`.
pub const EditorBufferView = extern struct {
    text: [*:0]u8,
    length: usize,
    has_parse_error: i32, // 1 = tree-sitter reported syntax error, 0 = clean
};

export fn editor_get_buffer_view(handle: u64, file_id: u64) callconv(.c) EditorBufferView {
    const empty: EditorBufferView = .{
        .text = @ptrCast(@constCast(emptyZ())),
        .length = 0,
        .has_parse_error = 0,
    };
    if (handle == 0) return empty;
    const editor: *Editor = @ptrFromInt(handle);
    const open = editor.getFile(file_id) orelse return empty;

    const text = open.buffer.getAll(gpa) catch return empty;
    // Allocate one extra byte for the trailing 0.
    var with_nul = gpa.alloc(u8, text.len + 1) catch {
        gpa.free(text);
        return empty;
    };
    @memcpy(with_nul[0..text.len], text);
    with_nul[text.len] = 0;
    gpa.free(text);

    var has_err: i32 = 0;
    if (open.tree) |t| {
        if (t.rootNode().hasError()) has_err = 1;
    }

    return .{
        .text = @ptrCast(with_nul.ptr),
        .length = text.len,
        .has_parse_error = has_err,
    };
}

export fn editor_release_buffer_view(view: EditorBufferView) callconv(.c) void {
    if (view.length == 0) return;
    const span = view.text[0 .. view.length + 1];
    gpa.free(span);
}

// ──────────────────────────────────────────────────────────
// Smoke (kept across Waves for FFI sanity)
// ──────────────────────────────────────────────────────────

export fn zig_add(a: i32, b: i32) callconv(.c) i32 {
    return a + b;
}

// ──────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────

fn dupErr(msg: []const u8) [*:0]u8 {
    var buf = gpa.allocSentinel(u8, msg.len, 0) catch return @constCast(emptyZ());
    @memcpy(buf[0..msg.len], msg);
    return buf.ptr;
}

fn emptyZ() [*:0]const u8 {
    return @ptrCast("");
}

// ──────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────

test "zig_add returns sum" {
    try std.testing.expectEqual(@as(i32, 5), zig_add(2, 3));
}

test "editor_init / destroy round-trip" {
    const h = editor_init();
    try std.testing.expect(h != 0);
    editor_handle_destroy(h);
}

// editor_open_file の end-to-end test は src/editor.zig 側 (POSIX 直接) で
// 既にカバーしているので、ffi.zig では smoke のみ。FFI 越境の挙動 (handle
// validity, error sentinel) を確認。
test "editor_init/destroy with null handle is safe" {
    editor_handle_destroy(0); // 何も起きない、crash しない
    try std.testing.expectEqual(@as(i32, -1), editor_close_file(0, 1));
}
