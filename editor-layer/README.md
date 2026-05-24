# editor-layer (Zig)

Cross-platform editor core for Ghostty Code Editor Studio.

- **Language:** Zig 0.13+
- **Output:** `libeditor.a` (static C-ABI library, linked from ui-macos / future ui-linux / ui-windows)
- **FFI contract:** see [`docs/ffi-design.md`](../docs/ffi-design.md)

## Build

```sh
zig build                 # build libeditor.a -> zig-out/lib/
zig build test            # run unit tests
```

## Source tree

| Path | Phase | Purpose |
|---|---|---|
| `src/ffi.zig` | 4.A | C-ABI export entry points |
| `src/editor.zig` | 4.A | Top-level Editor singleton |
| `src/core/buffer.zig` | 4.B | Rope buffer |
| `src/core/tree_sitter.zig` | 4.B | tree-sitter binding |
| `src/core/lsp_client.zig` | 4.B | LSP JSON-RPC client |
| `src/editor/edit_ops.zig` | 4.B | Edit operations |
| `src/chat/cli_detector.zig` | 4.E | PATH scan for LLM CLIs |
| `src/chat/cli_bridge.zig` | 4.E | Subprocess bridge |
| `src/ext/loader.zig` | 4.G | Extension Point + CCAGI loader |
| `src/proj/workspace.zig` | 4.B | Project root + file tree |
| `src/proj/config.zig` | 4.G | Ghostty-compatible config parser |

See [`docs/tech-spec.md`](../docs/tech-spec.md) §4 for module details.
