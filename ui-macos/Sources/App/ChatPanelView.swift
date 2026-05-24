// ChatPanelView — Phase 4.E LLM Chat panel.
//
// Right-side panel:
//   ┌────────────┐
//   │ + │ CLI ▼  │  ← dropdown auto-detects claude/codex/gemini/qwen on PATH
//   ├────────────┤
//   │  history   │  ← read-only response log (Pumpkky orange accents)
//   │  ...       │
//   ├────────────┤
//   │ [input]    │
//   │ [⌘Enter ▶] │
//   └────────────┘
//
// CLI subprocess execution is Swift-side (Process API). The Zig cli_bridge
// stub stays for future cross-platform parity but isn't on the critical
// path for macOS MVP.

import AppKit

final class ChatPanelView: NSViewController {
    private let dropdown = NSPopUpButton()
    private let history = NSTextView()
    private let historyScroll = NSScrollView()
    private let input = NSTextField()
    private let sendButton = NSButton()
    private struct CliEntry {
        let name: String
        let path: String
    }
    private var detectedClis: [CliEntry] = []

    private let brandOrange = NSColor(red: 0.89, green: 0.49, blue: 0.16, alpha: 1) // #e37e29
    private let bg = NSColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1)
    private let fg = NSColor(red: 0.91, green: 0.91, blue: 0.91, alpha: 1)

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 600))
        view.wantsLayer = true
        view.layer?.backgroundColor = bg.cgColor

        // ── header ──
        let header = NSView()
        header.translatesAutoresizingMaskIntoConstraints = false

        let plus = NSButton(title: "+", target: nil, action: nil)
        plus.bezelStyle = .rounded
        plus.translatesAutoresizingMaskIntoConstraints = false

        dropdown.translatesAutoresizingMaskIntoConstraints = false
        detectClis()

        header.addSubview(plus)
        header.addSubview(dropdown)
        NSLayoutConstraint.activate([
            plus.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 8),
            plus.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            plus.widthAnchor.constraint(equalToConstant: 32),
            dropdown.leadingAnchor.constraint(equalTo: plus.trailingAnchor, constant: 8),
            dropdown.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -8),
            dropdown.centerYAnchor.constraint(equalTo: header.centerYAnchor),
        ])

        // ── history ──
        history.isEditable = false
        history.isSelectable = true
        history.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        history.backgroundColor = bg
        history.textColor = fg
        history.string = "Pumpkky Chat — choose a CLI above and start prompting.\n"
        historyScroll.translatesAutoresizingMaskIntoConstraints = false
        historyScroll.documentView = history
        historyScroll.hasVerticalScroller = true
        historyScroll.drawsBackground = false
        historyScroll.borderType = .noBorder

        // ── input area ──
        input.translatesAutoresizingMaskIntoConstraints = false
        input.placeholderString = "Ask anything (⌘Enter to send)"
        input.font = .systemFont(ofSize: 13)
        input.target = self
        input.action = #selector(send(_:))

        sendButton.title = "Send"
        sendButton.bezelStyle = .rounded
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.target = self
        sendButton.action = #selector(send(_:))
        sendButton.contentTintColor = brandOrange

        view.addSubview(header)
        view.addSubview(historyScroll)
        view.addSubview(input)
        view.addSubview(sendButton)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 40),

            historyScroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4),
            historyScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            historyScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            historyScroll.bottomAnchor.constraint(equalTo: input.topAnchor, constant: -8),

            input.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            input.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -6),
            input.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),

            sendButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            sendButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
            sendButton.widthAnchor.constraint(equalToConstant: 70),
        ])
    }

    // ────────────────────────────────────────────────────────
    // CLI detection
    // ────────────────────────────────────────────────────────

    private func detectClis() {
        let candidates = ["claude", "codex", "gemini", "qwen"]
        let pathDirs: [String] = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
        var found: [CliEntry] = []
        let fm = FileManager.default
        for name in candidates {
            for dir in pathDirs {
                let p = (dir as NSString).appendingPathComponent(name)
                if fm.isExecutableFile(atPath: p) {
                    found.append(CliEntry(name: name, path: p))
                    break
                }
            }
        }
        detectedClis = found
        dropdown.removeAllItems()
        if found.isEmpty {
            dropdown.addItem(withTitle: "(no CLI detected)")
        } else {
            dropdown.addItems(withTitles: found.map { "\($0.name)  —  \($0.path)" })
        }
    }

    // ────────────────────────────────────────────────────────
    // Send
    // ────────────────────────────────────────────────────────

    @objc private func send(_ sender: Any?) {
        let prompt = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        guard !detectedClis.isEmpty else {
            appendLog("\n— no CLI selected —\n")
            return
        }
        let idx = max(0, min(dropdown.indexOfSelectedItem, detectedClis.count - 1))
        let cli = detectedClis[idx]
        input.stringValue = ""

        appendLog("\n> [\(cli.name)] \(prompt)\n")

        // Fire-and-forget subprocess. MVP: capture full stdout, append in one chunk.
        // Streaming chunked UI lives in a follow-up Wave.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: cli.path)
            proc.arguments = [prompt]
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            proc.standardOutput = stdoutPipe
            proc.standardError = stderrPipe
            do {
                try proc.run()
            } catch {
                DispatchQueue.main.async {
                    self?.appendLog("\nfailed to start \(cli.name): \(error.localizedDescription)\n")
                }
                return
            }
            proc.waitUntilExit()
            let outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let out = String(data: outData, encoding: .utf8) ?? ""
            let err = String(data: errData, encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                if !out.isEmpty { self?.appendLog(out + "\n") }
                if !err.isEmpty { self?.appendLog("[stderr] " + err + "\n") }
            }
        }
    }

    private func appendLog(_ s: String) {
        let storage = history.textStorage!
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: fg,
        ]
        storage.append(NSAttributedString(string: s, attributes: attrs))
        history.scrollToEndOfDocument(nil)
    }
}
