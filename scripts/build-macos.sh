#!/bin/sh
#
# Build Ghostty Code Editor Studio for macOS.
#
# Phase 4.A Wave 1.5 — minimum end-to-end build (no codesign / no notarize).
# Produces:
#   - editor-layer/zig-out/lib/libeditor.a
#   - ui-macos/.build/release/ghostty-editor (Mach-O executable)
#   - dist/Ghostty-Editor.app (unsigned .app bundle)
#
# Run from repo root:
#   ./scripts/build-macos.sh
#
# Requirements:
#   - Zig 0.15.2+   (brew install zig)
#   - Swift 5.9+    (Command Line Tools or Xcode)

set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

echo "==> [1/4] Ensure Ghostty submodule is initialized"
git submodule update --init --recursive

echo "==> [2/4] Build editor-layer (Zig static library)"
cd "$ROOT/editor-layer"
zig build -Doptimize=ReleaseSafe
test -f zig-out/lib/libeditor.a || {
    echo "ERROR: libeditor.a not produced"
    exit 1
}

# Zig 0.16 + C-mixed static libraries sometimes produce object members that
# fail macOS ld's 8-byte alignment check ("not 8-byte aligned"). Repack with
# the system /usr/bin/ar to normalize alignment before the Swift link step.
# (Only needed on macOS; Linux/Windows ld are tolerant.)
echo "    Repacking libeditor.a with /usr/bin/ar (macOS alignment fix)"
cd zig-out/lib
rm -rf .repack
mkdir .repack && cd .repack
/usr/bin/ar -x ../libeditor.a
chmod -R u+rw .                  # ar -x 後の .o は read-only な場合があるので緩和
/usr/bin/ar rcs ../libeditor.repacked.a ./*.o
mv ../libeditor.repacked.a ../libeditor.a
cd .. && rm -rf .repack
cd "$ROOT"

echo "==> [3/4] Build ui-macos (Swift Package executable)"
cd "$ROOT/ui-macos"
swift build --configuration release
EXE="$ROOT/ui-macos/.build/release/ghostty-editor"
test -x "$EXE" || {
    echo "ERROR: ghostty-editor executable not produced"
    exit 1
}

echo "==> [4/4] Pack into Ghostty-Editor.app (unsigned)"
APP="$ROOT/dist/Ghostty-Editor.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$EXE" "$APP/Contents/MacOS/ghostty-editor"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>ghostty-editor</string>
    <key>CFBundleIdentifier</key><string>dev.ghostty-editor.app</string>
    <key>CFBundleName</key><string>Ghostty Editor</string>
    <key>CFBundleDisplayName</key><string>Ghostty Editor</string>
    <key>CFBundleVersion</key><string>0.0.1</string>
    <key>CFBundleShortVersionString</key><string>0.0.1</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

echo ""
echo "✅ Build complete."
echo "    Bundle: $APP"
echo "    Run:    open '$APP'"
