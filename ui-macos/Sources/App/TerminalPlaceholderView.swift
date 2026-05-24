// TerminalPlaceholderView — Phase 4.D.
//
// Embedding Ghostty's actual NSView is non-trivial (Ghostty's macOS apprt
// doesn't yet expose a public "give me a TerminalView" surface). For MVP we
// ship a clearly-labeled placeholder so the layout, menu wiring, and toggle
// shortcut all work end-to-end. Replacing this with a real Ghostty embed is
// tracked as a v1.0 task.

import AppKit

final class TerminalPlaceholderView: NSViewController {
    private let scrollView = NSScrollView()
    private let textView = NSTextView()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 200))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(red: 0.02, green: 0.02, blue: 0.02, alpha: 1).cgColor

        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = NSColor(red: 0.02, green: 0.02, blue: 0.02, alpha: 1)
        textView.textColor = NSColor(red: 0.89, green: 0.49, blue: 0.16, alpha: 1) // Pumpkky Orange
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.string = """
        $ pumpkky terminal (placeholder)

        Ghostty 本体の NSView embed は v1.0+ の作業 (ADR-XXXX 予定)。
        MVP では layout / menu wiring / toggle shortcut だけ通します。

        実装 ToDo:
          - Ghostty submodule の apprt/macos を参照
          - TerminalView を public surface として切り出す PR (upstream への寄与)
          - もしくは libghostty-vt stable 後に embed

        当面の代替: \\Cmd+Tab で本物の Ghostty.app に行ってください。
        """

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.documentView = textView

        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}
