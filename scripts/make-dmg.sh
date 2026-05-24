#!/bin/sh
#
# Pack dist/Ghostty-Editor.app into a (unsigned) dmg for GitHub Releases / Pages.
#
# Phase 4.A Wave 1.5 — invoked by ./scripts/build-macos.sh manually or by CI on tag push.
#
# Usage:
#   ./scripts/make-dmg.sh [VERSION]
#   ./scripts/make-dmg.sh v0.1.0-mvp
#
# Output:
#   dist/Ghostty-Editor-<VERSION>.dmg

set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
VERSION="${1:-dev}"

APP="$ROOT/dist/Pumpkky.app"
DMG_VERSIONED="$ROOT/dist/Pumpkky-$VERSION.dmg"
DMG_LATEST="$ROOT/dist/Pumpkky.dmg"   # 固定名: GitHub releases/latest/download/Pumpkky.dmg で永続リンクできる

test -d "$APP" || {
    echo "ERROR: $APP not found. Run ./scripts/build-macos.sh first."
    exit 1
}

# Re-apply ad-hoc codesign in case the .app was modified after build.
echo "==> Ensure ad-hoc codesign on $APP"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "==> Packing $APP into dmg ($VERSION)"
rm -f "$DMG_VERSIONED" "$DMG_LATEST"

# Create a read-write dmg, then convert to read-only / compressed.
TMP_DMG="$ROOT/dist/.tmp-pumpkky.dmg"
hdiutil create -srcfolder "$APP" -volname "Pumpkky" \
    -fs HFS+ -fsargs "-c c=64,a=16,e=16" \
    -format UDRW -size 200m "$TMP_DMG" >/dev/null
hdiutil convert "$TMP_DMG" -format UDZO -o "$DMG_VERSIONED" >/dev/null
rm -f "$TMP_DMG"

# Provide a stable, version-less symlink/copy so download URLs never break.
cp "$DMG_VERSIONED" "$DMG_LATEST"

echo "✅ DMG created:"
echo "   versioned: $DMG_VERSIONED ($(du -h "$DMG_VERSIONED" | cut -f1))"
echo "   latest:    $DMG_LATEST    ($(du -h "$DMG_LATEST" | cut -f1))"
