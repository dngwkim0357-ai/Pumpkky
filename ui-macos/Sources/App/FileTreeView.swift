// FileTreeView — Phase 4.C scaffold.
//
// Shallow file list of the currently-opened project root, rendered with
// NSTableView (one column, file name only). Recursive tree comes in a later
// Wave; MVP just needs "click a file, open it in the editor".

import AppKit

class FileTreeView: NSViewController {
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private var files: [URL] = []

    var onSelect: ((URL) -> Void)?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 600))

        let column = NSTableColumn(identifier: .init("name"))
        column.title = "Files"
        column.width = 220
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.action = #selector(rowClicked(_:))
        tableView.backgroundColor = NSColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
        tableView.intercellSpacing = NSSize(width: 0, height: 2)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.documentView = tableView
        scrollView.drawsBackground = false

        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    func loadProject(at root: URL) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            files = []
            tableView.reloadData()
            return
        }
        // Files first (alphabetical), directories not expanded yet (MVP).
        files = contents
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == false }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        tableView.reloadData()
    }

    @objc private func rowClicked(_ sender: Any) {
        let row = tableView.selectedRow
        guard row >= 0, row < files.count else { return }
        onSelect?(files[row])
    }
}

extension FileTreeView: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int { files.count }
}

extension FileTreeView: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("FileCell")
        let cell = tableView.makeView(withIdentifier: id, owner: nil) as? NSTableCellView ?? {
            let c = NSTableCellView()
            c.identifier = id
            let tf = NSTextField(labelWithString: "")
            tf.translatesAutoresizingMaskIntoConstraints = false
            tf.font = .systemFont(ofSize: 12)
            tf.textColor = NSColor(red: 0.91, green: 0.91, blue: 0.91, alpha: 1.0)
            tf.lineBreakMode = .byTruncatingMiddle
            c.addSubview(tf)
            c.textField = tf
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 10),
                tf.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -6),
                tf.centerYAnchor.constraint(equalTo: c.centerYAnchor),
            ])
            return c
        }()
        cell.textField?.stringValue = files[row].lastPathComponent
        return cell
    }
}
