// Application delegate — Phase 4.A → 4.C wiring (open folder, save, etc.)

import AppKit
import EditorBridge

class AppDelegate: NSObject, NSApplicationDelegate {
    var mainWindow: MainWindowController?
    var editorHandle: UInt64 = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        MenuBuilder.install()

        editorHandle = editor_init()
        precondition(editorHandle != 0, "editor_init() returned 0")

        // FFI sanity (Wave 1.4 smoke test, kept across Waves)
        precondition(zig_add(2, 3) == 5, "zig_add smoke failed")

        let win = MainWindowController(editorHandle: editorHandle)
        win.showWindow(nil)
        win.window?.makeKeyAndOrderFront(nil)
        mainWindow = win
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        if editorHandle != 0 {
            editor_handle_destroy(editorHandle)
            editorHandle = 0
        }
    }

    // ────────────────────────────────────────────────────────
    // Menu actions
    // ────────────────────────────────────────────────────────

    @objc func openFolder(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        mainWindow?.openFolder(url)
    }

    @objc func saveCurrentFile(_ sender: Any?) {
        // Editor pane handles its own save (TODO Wave 2.4+: surface result).
        // For Phase 4.C scaffold we just no-op so the menu doesn't beep.
    }

    @objc func toggleChatPanel(_ sender: Any?) {
        mainWindow?.toggleChatPanel()
    }

    @objc func toggleTerminal(_ sender: Any?) {
        mainWindow?.toggleTerminal()
    }

    @objc func openProjectPage(_ sender: Any?) {
        if let url = URL(string: "https://github.com/dngwkim0357-ai/Pumpkky") {
            NSWorkspace.shared.open(url)
        }
    }
}
