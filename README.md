# Pumpkky

> Ghostty の哲学を継ぐ、開発者が信じられる軽量コードエディタ (macOS native)

Pumpkky is a lightweight code editor built on top of [Ghostty](https://github.com/ghostty-org/ghostty)'s terminal engine. Zig core + Swift AppKit UI, no Electron, no account, no telemetry, no marketplace — just dotfiles and you.

## Status

**Pre-MVP** (M3 — Bootstrap complete, editor core in progress).
The repo compiles, links, and launches a window. Open Folder / file tree /
LLM Chat / Toggle Terminal & Chat all wired. Real terminal embed + grammar
coverage land in v1.0.

## Download

Pre-built **unsigned** dmg from [GitHub Releases](https://github.com/dngwkim0357-ai/Pumpkky/releases).
First launch: right-click → Open (Gatekeeper bypass), or `System Settings → Privacy & Security → Open Anyway`.

We don't notarize (Apple Developer ID = $99/y) — it's a deliberate
Ghostty-philosophy choice. If you don't trust the binary, build from source ↓.

## Build from source

```sh
git clone --recursive https://github.com/dngwkim0357-ai/Pumpkky
cd Pumpkky
./scripts/build-macos.sh
open dist/Pumpkky.app
```

Requirements: macOS 13+, Xcode (full, not just CLT), Zig 0.16+ (`brew install zig`).

## Philosophy (8 principles)

1. 余分を削る (Ghostty の精神)
2. デフォルトで使える、設定は任意
3. 設定は必ずファイル (GUI 設定画面なし)
4. アカウント不要・telemetry なし
5. dotfile / Extension Point 文化 (Marketplace なし)
6. GPU加速 native、Web エンジン非介在
7. upstream への敬意 (Ghostty 本家へ還元の道を残す)
8. OS ごとに Best な UI (core 共通、UI 各 OS native)

## License

MIT — same as Ghostty. See [LICENSE](LICENSE).

## Contributing

Issues and PRs welcome on this repo. The dev-side architecture / Plan / ADR
live in a separate private repo; what you see here is the production tree.
