// EditorPaneView — Phase 4.C scaffold.
//
// Hosts the editor area (currently a read-only-ish NSTextView wired to
// editor_open_file / editor_get_buffer_view via EditorBridge). Phase 4.B
// Wave 2.4 already provides apply_edit & save on the Zig side; full
// bi-directional sync (typing → Buffer.insert → reparse) lands in a
// follow-up Wave when we wire NSTextStorage delegates.

import AppKit
import EditorBridge

final class EditorPaneView: NSViewController {
    private let scrollView = NSScrollView()
    private let textView = NSTextView()
    private var currentFileId: UInt64 = 0

    let editorHandle: UInt64
    var titleChanged: ((String?) -> Void)?

    init(editorHandle: UInt64) {
        self.editorHandle = editorHandle
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))

        textView.isEditable = true
        textView.isRichText = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.backgroundColor = NSColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
        textView.textColor = NSColor(red: 0.91, green: 0.91, blue: 0.91, alpha: 1.0)
        textView.insertionPointColor = NSColor(red: 0.89, green: 0.49, blue: 0.16, alpha: 1.0) // Pumpkky Orange #e37e29
        textView.autoresizingMask = [.width]
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.documentView = textView

        // Placeholder content
        textView.string = "Pumpkky — pick a file from the sidebar to open it."

        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    func open(url: URL) {
        // Close previously open file
        if currentFileId != 0 {
            _ = editor_close_file(editorHandle, currentFileId)
            currentFileId = 0
        }

        var errPtr: UnsafeMutablePointer<CChar>? = nil
        let fileId = url.path.withCString { cPath in
            editor_open_file(editorHandle, cPath, &errPtr)
        }
        if fileId == 0 {
            let msg = errPtr.map { String(cString: $0) } ?? "unknown error"
            if let e = errPtr { editor_free_string(e) }
            textView.string = "// Failed to open \(url.lastPathComponent): \(msg)"
            return
        }
        currentFileId = fileId

        let view = editor_get_buffer_view(editorHandle, fileId)
        defer { editor_release_buffer_view(view) }
        if let textPtr = view.text {
            textView.string = String(cString: textPtr)
        } else {
            textView.string = ""
        }
        titleChanged?(url.lastPathComponent)
    }
}
