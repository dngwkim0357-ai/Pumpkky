// Ghostty Code Editor Studio — entry point.
//
// Phase 4.A Wave 1.3: minimal NSApplication + NSWindow.

import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
