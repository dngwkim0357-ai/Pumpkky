// EditorBridge.h
//
// C-ABI header matching editor-layer/src/ffi.zig.
// Imported by Swift via `import EditorBridge`.
//
// Phase 4.A Wave 1.4 — covers lifecycle + smoke test (zig_add).
// Future Waves extend with file / chat / extension APIs per docs/ffi-design.md.

#ifndef EDITOR_BRIDGE_H
#define EDITOR_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// ──────────────────────────────────────────────────────────────────────
// Lifecycle
// ──────────────────────────────────────────────────────────────────────

/// Initialize the editor and return an opaque handle. Returns 0 on failure.
uint64_t editor_init(void);

/// Destroy the editor and free all associated resources.
void editor_handle_destroy(uint64_t handle);

/// Free a string previously returned by editor-layer via an out-parameter.
void editor_free_string(const char *ptr);

// ──────────────────────────────────────────────────────────────────────
// File operations (Wave 2.4)
// ──────────────────────────────────────────────────────────────────────

#include <stddef.h>

uint64_t editor_open_file(uint64_t handle, const char *path, char **out_err);
int32_t  editor_close_file(uint64_t handle, uint64_t file_id);
int32_t  editor_save_file(uint64_t handle, uint64_t file_id, char **out_err);
int32_t  editor_apply_edit(uint64_t handle, uint64_t file_id, uint32_t start, uint32_t end, const char *replacement, size_t replacement_len);

typedef struct {
    char  *text;             // null-terminated, caller-owned
    size_t length;           // bytes excluding the trailing NUL
    int32_t has_parse_error; // 1 if tree-sitter reported a syntax error, 0 otherwise
} EditorBufferView;

EditorBufferView editor_get_buffer_view(uint64_t handle, uint64_t file_id);
void             editor_release_buffer_view(EditorBufferView view);

// ──────────────────────────────────────────────────────────────────────
// Smoke test (kept across Waves)
// ──────────────────────────────────────────────────────────────────────

int32_t zig_add(int32_t a, int32_t b);

#ifdef __cplusplus
}
#endif

#endif // EDITOR_BRIDGE_H
