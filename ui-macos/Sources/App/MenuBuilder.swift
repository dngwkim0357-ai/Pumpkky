// macOS menubar — Phase 4.A scaffold → Phase 4.C real "Open Folder…" wiring.
//
// Per requirements.md §2.2: 設定 GUI は作らない、menubar に集約。

import AppKit

enum MenuBuilder {
    static func install() {
        let mainMenu = NSMenu()

        // App menu (Pumpkky)
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Pumpkky", action: nil, keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Pumpkky",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        // File menu
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        let openItem = NSMenuItem(
            title: "Open Folder…",
            action: #selector(AppDelegate.openFolder(_:)),
            keyEquivalent: "o"
        )
        fileMenu.addItem(openItem)
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Save",
                         action: #selector(AppDelegate.saveCurrentFile(_:)),
                         keyEquivalent: "s")
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Close Window",
                         action: #selector(NSWindow.performClose(_:)),
                         keyEquivalent: "w")
        fileMenuItem.submenu = fileMenu

        // View menu
        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(withTitle: "Toggle Sidebar",
                         action: #selector(NSSplitViewController.toggleSidebar(_:)),
                         keyEquivalent: "b")
        viewMenu.addItem(withTitle: "Toggle Chat Panel",
                         action: #selector(AppDelegate.toggleChatPanel(_:)),
                         keyEquivalent: "L")
        viewMenu.addItem(withTitle: "Toggle Terminal",
                         action: #selector(AppDelegate.toggleTerminal(_:)),
                         keyEquivalent: "`")
        viewMenuItem.submenu = viewMenu

        // Window menu (standard)
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize",
                           action: #selector(NSWindow.performMiniaturize(_:)),
                           keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom",
                           action: #selector(NSWindow.performZoom(_:)),
                           keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        NSApplication.shared.windowsMenu = windowMenu

        // Help
        let helpMenuItem = NSMenuItem()
        mainMenu.addItem(helpMenuItem)
        let helpMenu = NSMenu(title: "Help")
        helpMenu.addItem(withTitle: "Pumpkky on GitHub",
                         action: #selector(AppDelegate.openProjectPage(_:)),
                         keyEquivalent: "")
        helpMenuItem.submenu = helpMenu

        NSApplication.shared.mainMenu = mainMenu
    }
}
