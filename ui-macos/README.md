# ui-macos (Swift + AppKit)

macOS native UI for Ghostty Code Editor Studio.

- **Language:** Swift 5.9+ (Swift 6.0 toolchain available, target macOS 13+)
- **UI Framework:** AppKit (per `vision.md` §5.6 / `tech-spec.md` §4.6)
- **Backend:** links against `editor-layer/zig-out/lib/libeditor.a` via C bridging header

## Build

```sh
# Build editor-layer first (Wave 1.2)
cd ../editor-layer && zig build

# Then ui-macos
cd ../ui-macos && swift build --configuration release

# Run the executable (no .app bundle yet; Wave 1.5 wraps it)
swift run ghostty-editor
```

## Source tree

| Path | Phase | Purpose |
|---|---|---|
| `Sources/App/main.swift` | 4.A | Entry point (`NSApplication.run()`) |
| `Sources/App/AppDelegate.swift` | 4.A | `NSApplicationDelegate` |
| `Sources/App/MenuBuilder.swift` | 4.A → 4.C | macOS menubar |
| `Sources/App/MainWindowController.swift` | 4.A → 4.C | Main `NSWindow` |
| (Wave 1.4) `Sources/FFI/EditorBridge-Bridging.h` | 4.A | C header for libeditor.a |
| (Phase 4.C) `Sources/MainWindow/`, `Sources/EditorView/`, `Sources/ChatPanel/`, `Sources/UrlTab/`, `Sources/TerminalView/` | 4.C+ | feature views |

See [`docs/tech-spec.md`](../docs/tech-spec.md) §4.6 for module details.
