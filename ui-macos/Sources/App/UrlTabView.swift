// UrlTabView — Phase 4.F.
//
// A WKWebView wrapped as an NSViewController so it can be slotted into a
// tab/panel. URL bar + reload + back/forward. Drag-to-detach is deferred
// to a later Wave (needs cross-window NSDraggingDestination wiring).

import AppKit
import WebKit

final class UrlTabView: NSViewController, WKNavigationDelegate {
    private let urlField = NSTextField()
    private let backBtn = NSButton(title: "←", target: nil, action: nil)
    private let fwdBtn = NSButton(title: "→", target: nil, action: nil)
    private let reloadBtn = NSButton(title: "⟳", target: nil, action: nil)
    private let web = WKWebView()

    var initialURL: URL? {
        didSet { if let u = initialURL { load(url: u) } }
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1024, height: 768))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1).cgColor

        // toolbar
        for b in [backBtn, fwdBtn, reloadBtn] {
            b.bezelStyle = .rounded
            b.translatesAutoresizingMaskIntoConstraints = false
        }
        backBtn.target = self; backBtn.action = #selector(goBack(_:))
        fwdBtn.target = self;  fwdBtn.action = #selector(goForward(_:))
        reloadBtn.target = self; reloadBtn.action = #selector(reload(_:))

        urlField.translatesAutoresizingMaskIntoConstraints = false
        urlField.placeholderString = "http://localhost:3000/  または  https://example.com/"
        urlField.target = self
        urlField.action = #selector(loadFromField(_:))

        web.translatesAutoresizingMaskIntoConstraints = false
        web.navigationDelegate = self

        view.addSubview(backBtn); view.addSubview(fwdBtn); view.addSubview(reloadBtn)
        view.addSubview(urlField); view.addSubview(web)

        NSLayoutConstraint.activate([
            backBtn.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            backBtn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            backBtn.widthAnchor.constraint(equalToConstant: 36),

            fwdBtn.centerYAnchor.constraint(equalTo: backBtn.centerYAnchor),
            fwdBtn.leadingAnchor.constraint(equalTo: backBtn.trailingAnchor, constant: 4),
            fwdBtn.widthAnchor.constraint(equalToConstant: 36),

            reloadBtn.centerYAnchor.constraint(equalTo: backBtn.centerYAnchor),
            reloadBtn.leadingAnchor.constraint(equalTo: fwdBtn.trailingAnchor, constant: 4),
            reloadBtn.widthAnchor.constraint(equalToConstant: 36),

            urlField.centerYAnchor.constraint(equalTo: backBtn.centerYAnchor),
            urlField.leadingAnchor.constraint(equalTo: reloadBtn.trailingAnchor, constant: 8),
            urlField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),

            web.topAnchor.constraint(equalTo: backBtn.bottomAnchor, constant: 8),
            web.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            web.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            web.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    func load(url: URL) {
        urlField.stringValue = url.absoluteString
        web.load(URLRequest(url: url))
    }

    @objc private func loadFromField(_ sender: Any?) {
        let raw = urlField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty, let u = URL(string: raw) else { return }
        load(url: u)
    }

    @objc private func goBack(_ sender: Any?) { web.goBack() }
    @objc private func goForward(_ sender: Any?) { web.goForward() }
    @objc private func reload(_ sender: Any?) { web.reload() }
}
