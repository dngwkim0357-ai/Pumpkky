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

APP="$ROOT/dist/Ghostty-Editor.app"
DMG="$ROOT/dist/Ghostty-Editor-$VERSION.dmg"

test -d "$APP" || {
    echo "ERROR: $APP not found. Run ./scripts/build-macos.sh first."
    exit 1
}

echo "==> Packing $APP into $DMG"
rm -f "$DMG"

# Create a read-write dmg, then convert to read-only / compressed.
TMP_DMG="$ROOT/dist/.tmp-ghostty.dmg"
hdiutil create -srcfolder "$APP" -volname "Ghostty Editor" \
    -fs HFS+ -fsargs "-c c=64,a=16,e=16" \
    -format UDRW -size 200m "$TMP_DMG" >/dev/null
hdiutil convert "$TMP_DMG" -format UDZO -o "$DMG" >/dev/null
rm -f "$TMP_DMG"

echo "✅ DMG created: $DMG ($(du -h "$DMG" | cut -f1))"
