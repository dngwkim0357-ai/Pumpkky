// swift-tools-version:5.9
//
// Ghostty Code Editor Studio — macOS UI
//
// Phase 4.A Wave 1.3-1.4: AppDelegate + NSWindow + Zig↔Swift FFI bridge.

import PackageDescription

let package = Package(
    name: "GhosttyEditor",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ghostty-editor", targets: ["App"]),
    ],
    targets: [
        // C-header bridge to editor-layer/zig-out/lib/libeditor.a
        .target(
            name: "EditorBridge",
            path: "Sources/EditorBridge",
            exclude: [],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
            ],
            linkerSettings: [
                // Resolve at build time from the repo root.
                .unsafeFlags([
                    "-L", "../editor-layer/zig-out/lib",
                    "-leditor",
                ]),
            ]
        ),
        .executableTarget(
            name: "App",
            dependencies: ["EditorBridge"],
            path: "Sources/App"
        ),
    ]
)
