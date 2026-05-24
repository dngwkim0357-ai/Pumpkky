// Main window — Phase 4.C scaffold.
//
// Layout (left → right):
//   [ FileTreeView ] [ EditorPaneView ]
//   (NSSplitView)
//
// Phase 4.D/4.E/4.F will add Terminal, Chat panel, URL tab.

import AppKit
import EditorBridge

class MainWindowController: NSWindowController {
    let editorHandle: UInt64
    private(set) var fileTree: FileTreeView!
    private(set) var editorPane: EditorPaneView!
    private(set) var terminal: TerminalPlaceholderView!
    private(set) var chat: ChatPanelView!
    private var splitVC: NSSplitViewController!
    private var terminalItem: NSSplitViewItem!
    private var chatItem: NSSplitViewItem!

    init(editorHandle: UInt64) {
        self.editorHandle = editorHandle

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Pumpkky"
        window.center()
        window.setFrameAutosaveName("MainWindow")

        super.init(window: window)
        configureContent()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func configureContent() {
        fileTree = FileTreeView()
        editorPane = EditorPaneView(editorHandle: editorHandle)
        terminal = TerminalPlaceholderView()
        chat = ChatPanelView()
        editorPane.titleChanged = { [weak self] name in
            self?.window?.title = name.map { "\($0) — Pumpkky" } ?? "Pumpkky"
        }
        fileTree.onSelect = { [weak self] url in
            self?.editorPane.open(url: url)
        }

        // Vertical split inside the center: editor on top, terminal on bottom.
        let centerSplit = NSSplitViewController()
        centerSplit.splitView.isVertical = false
        let editorItem = NSSplitViewItem(viewController: editorPane)
        terminalItem = NSSplitViewItem(viewController: terminal)
        terminalItem.canCollapse = true
        terminalItem.isCollapsed = true  // default off; ⌃` toggles
        centerSplit.splitViewItems = [editorItem, terminalItem]

        // Outer split: sidebar | centerSplit | chat panel
        splitVC = NSSplitViewController()
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: fileTree)
        sidebarItem.minimumThickness = 180
        sidebarItem.maximumThickness = 400
        let centerItem = NSSplitViewItem(viewController: centerSplit)
        chatItem = NSSplitViewItem(viewController: chat)
        chatItem.canCollapse = true
        chatItem.isCollapsed = true   // default off; ⌘⇧L toggles
        chatItem.minimumThickness = 280
        chatItem.maximumThickness = 600
        splitVC.splitViewItems = [sidebarItem, centerItem, chatItem]

        window?.contentViewController = splitVC
    }

    func openFolder(_ url: URL) {
        fileTree.loadProject(at: url)
        window?.representedURL = url
        window?.title = "\(url.lastPathComponent) — Pumpkky"
    }

    func toggleTerminal() {
        terminalItem.animator().isCollapsed.toggle()
    }

    func toggleChatPanel() {
        chatItem.animator().isCollapsed.toggle()
    }
}
