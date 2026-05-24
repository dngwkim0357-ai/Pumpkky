#!/bin/sh
#
# make-dmg.sh — Pumpkky の dmg を「ちゃんとした」見た目で生成。
#
# - .app 本体 + /Applications シンボリックリンクを 1 つの volume に並べる
# - 背景画像 (.background/background.tiff) を貼り、ドラッグ動線を視覚化
# - .VolumeIcon.icns でかぼちゃのアイコンを Finder volume 表示に
# - AppleScript で .DS_Store にウィンドウサイズ + アイコン配置を保存
# - 最後に ULFO (lzfse) 圧縮で .dmg を仕上げ (Ghostty と同じ format、小さく速い)
#
# Usage:
#   ./scripts/make-dmg.sh [VERSION]
#   ./scripts/make-dmg.sh v0.1.0-mvp

set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
VERSION="${1:-dev}"

APP="$ROOT/dist/Pumpkky.app"
DMG_VERSIONED="$ROOT/dist/Pumpkky-$VERSION.dmg"
DMG_LATEST="$ROOT/dist/Pumpkky.dmg"
VOLNAME="Pumpkky"

ASSETS="$ROOT/scripts/dmg-assets"
BG_TIFF="$ASSETS/background.tiff"
VOL_ICNS="$ASSETS/Pumpkky.icns"

test -d "$APP" || {
    echo "ERROR: $APP not found. Run ./scripts/build-macos.sh first."
    exit 1
}
test -f "$BG_TIFF" || { echo "ERROR: missing $BG_TIFF"; exit 1; }
test -f "$VOL_ICNS" || { echo "ERROR: missing $VOL_ICNS"; exit 1; }

# Re-apply ad-hoc codesign before packing.
echo "==> Ensure ad-hoc codesign on $APP"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

# ─────────────────────────────────────────────────────────────
# 1. Stage the dmg contents
# ─────────────────────────────────────────────────────────────
STAGE="$ROOT/dist/.dmg-stage"
echo "==> Stage at $STAGE"
rm -rf "$STAGE"
mkdir -p "$STAGE/.background"

# copy app (rsync to preserve symlinks + xattr)
ditto "$APP" "$STAGE/Pumpkky.app"

# /Applications シンボリックリンク (ドラッグで install 用)
ln -s /Applications "$STAGE/Applications"

# 暫定の install.command:
#   未署名 binary なので Sequoia の Gatekeeper が silent fail することがある。
#   ダブルクリックで /Applications にコピー + quarantine 削除 + 起動まで自動化。
#   Apple Developer ID 取得 + notarize 自動化が稼働したらこの fallback は不要。
cat > "$STAGE/install.command" <<'INSTALL_EOF'
#!/bin/bash
# Pumpkky 暫定インストーラ
# (Apple Developer ID で notarize していないため、macOS Sequoia 以降での
#  silent fail を回避するためのスクリプト。本来は不要。)
set -e

VOL=$(cd "$(dirname "$0")" && pwd)
SRC="$VOL/Pumpkky.app"
DST="/Applications/Pumpkky.app"

if [ ! -d "$SRC" ]; then
  echo "ERROR: $SRC が見つかりません。dmg をマウントしたまま実行してください。"
  read -p "Enter キーで閉じます…"
  exit 1
fi

echo "==> Pumpkky.app を /Applications にコピー中…"
[ -d "$DST" ] && rm -rf "$DST"
cp -R "$SRC" "$DST"

echo "==> quarantine 属性を削除中…"
xattr -cr "$DST" 2>/dev/null || true

echo "==> 起動します…"
open "$DST"

echo ""
echo "✅ インストール完了 — Pumpkky が起動します。"
echo "   このターミナルは閉じて OK です。"
sleep 2
INSTALL_EOF
chmod +x "$STAGE/install.command"

# Finder で確実に hidden 扱いにする (".dotfile" だけでは Finder の "Show
# Hidden Files" ON 時に丸見えになる。chflags hidden は ON/OFF を問わず効く)
chflags hidden "$STAGE/.background" "$STAGE/.VolumeIcon.icns" 2>/dev/null || true

# macOS の Finder に「カスタム volume icon あり」を伝える
SetFile -a C "$STAGE" 2>/dev/null || true   # SetFile が無い環境では skip

# ─────────────────────────────────────────────────────────────
# 2. Create a read-write dmg
# ─────────────────────────────────────────────────────────────
TMP_DMG="$ROOT/dist/.tmp-pumpkky.dmg"
echo "==> Create RW dmg"
rm -f "$TMP_DMG"
hdiutil create -srcfolder "$STAGE" -volname "$VOLNAME" \
    -fs HFS+ -fsargs "-c c=64,a=16,e=16" \
    -format UDRW -size 200m "$TMP_DMG" >/dev/null

# ─────────────────────────────────────────────────────────────
# 3. Mount, apply window layout via AppleScript, unmount
# ─────────────────────────────────────────────────────────────
echo "==> Mount and apply layout"
MOUNT_DIR="/Volumes/$VOLNAME"
# unmount lingering volume if any
hdiutil detach "$MOUNT_DIR" -quiet >/dev/null 2>&1 || true
hdiutil attach "$TMP_DMG" -nobrowse -mountpoint "$MOUNT_DIR" -quiet

# Tell Finder where to put each icon, set window size, hide chrome
osascript <<APPLESCRIPT >/dev/null 2>&1 || echo "    (AppleScript layout step skipped — Automation permission?)"
tell application "Finder"
    tell disk "${VOLNAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 800, 520}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 112
        set text size of viewOptions to 13
        try
            set background picture of viewOptions to file ".background:background.tiff"
        end try
        set position of item "Pumpkky.app" of container window to {160, 220}
        set position of item "Applications" of container window to {440, 220}
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT

# Wait briefly for Finder to flush .DS_Store
sync; sleep 1

# Blessing the volume so the custom icon sticks (best-effort)
bless --folder "$MOUNT_DIR" --openfolder "$MOUNT_DIR" 2>/dev/null || true

hdiutil detach "$MOUNT_DIR" -quiet
sleep 1

# ─────────────────────────────────────────────────────────────
# 4. Convert to read-only, ULFO (lzfse) compressed
# ─────────────────────────────────────────────────────────────
echo "==> Convert to ULFO (lzfse) compressed dmg"
rm -f "$DMG_VERSIONED" "$DMG_LATEST"
hdiutil convert "$TMP_DMG" -format ULFO -o "$DMG_VERSIONED" >/dev/null
cp "$DMG_VERSIONED" "$DMG_LATEST"
rm -f "$TMP_DMG"
rm -rf "$STAGE"

echo ""
echo "✅ DMG created:"
echo "   versioned: $DMG_VERSIONED ($(du -h "$DMG_VERSIONED" | cut -f1))"
echo "   latest:    $DMG_LATEST    ($(du -h "$DMG_LATEST" | cut -f1))"
