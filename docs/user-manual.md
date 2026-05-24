# Ghostty Code Editor Studio — User Manual

**版数:** 0.1 (initial draft — MVP 未実装段階の構想)
**最終更新:** 2026-05-23
**位置付け:** ユーザー視点の取説。**機能追加・変更があるたびに即時更新**するライブドキュメント。

> ⚠️ 現状はまだ MVP 開発前のため、本書の内容は **構想と仕様** を記述したものです。実装と乖離が生じた場合は本書を優先的に更新します。

---

## 目次

1. [インストール](#1-インストール)
2. [最初の起動](#2-最初の起動)
3. [設定の書き方](#3-設定の書き方)
4. [LLM CLI を追加するには](#4-llm-cli-を追加するには)
5. [プラグインを入れるには](#5-プラグインを入れるには)
6. [URL タブ / ローカルプレビュー](#6-url-タブ--ローカルプレビュー)
7. [タブの drag 分離・分割](#7-タブの-drag-分離分割)
8. [ターミナルペイン](#8-ターミナルペイン)
9. [LLM Chat panel](#9-llm-chat-panel)
10. [キーバインド一覧](#10-キーバインド一覧)
11. [CCAGI 連携の仕組み](#11-ccagi-連携の仕組み)
12. [トラブルシューティング](#12-トラブルシューティング)

---

## 1. インストール

### 1.1 推奨: Homebrew (個人 tap)

```sh
brew tap rick/tap
brew install ghostty-editor
```

### 1.2 直接ダウンロード

[GitHub Releases](https://github.com/dngwkim0357-ai/Ghostty-editor-studio/releases) から `Ghostty-Editor-vX.Y.Z.dmg` を取得して `/Applications/` に配置。

### 1.3 ビルドから

```sh
git clone https://github.com/dngwkim0357-ai/Ghostty-editor-studio
cd Ghostty-editor-studio
git submodule update --init --recursive
./scripts/build-macos.sh
open Ghostty-Editor.app
```

### 1.4 要求環境

- macOS 13 (Ventura) 以上
- (Linux v1.0): Ubuntu 22.04 / Fedora 38 以上、GTK4 4.10+
- (Windows v2.0): Windows 11 22H2 以上

### 1.5 アンインストール

```sh
brew uninstall ghostty-editor   # Homebrew 経由の場合
rm -rf /Applications/Ghostty-Editor.app
rm -rf ~/.config/ghostty-editor
rm -rf ~/.local/share/ghostty-editor
```

設定とユーザーデータが残らないクリーンアンインストールです。アカウントもサーバーもないので、これで完全に痕跡が消えます。

---

## 2. 最初の起動

### 2.1 起動

Dock の Ghostty Editor アイコン、または `open -a Ghostty-Editor` で起動します。

**「ようこそ」画面・ツアーはありません**。起動直後はフォルダ選択ダイアログが出ます。

### 2.2 フォルダを選ぶ

Cursor 同様、まずプロジェクトフォルダを選択します:

- ⌘O で `File → Open Folder...` を起動
- 任意のフォルダを選択
- 選択後、左サイドバー ① にファイルツリーが表示される

### 2.3 ファイルを開く

ファイルツリーでファイルをクリック → エディタペインで開きます。

複数のファイルはタブで並びます (リポジトリ内タブ、上から 3 層目)。

### 2.4 macOS menubar

画面最上部の menubar から多くの操作にアクセスできます:

- **Ghostty Editor**: About / Quit
- **File**: New Window / Open Folder / Save / Save All
- **Edit**: Undo / Redo / Cut / Copy / Paste / Find / Replace
- **View**: Toggle Terminal / Toggle Chat Panel / Toggle Sidebar
- **Window**: Minimize / Zoom / Bring All to Front
- **Help**: User Manual (本書) / Open Config File / Visit Project Page

**新しいウィンドウは `File → New Window` または Dock アイコン右クリックから**開きます。アプリ内に独自のウィンドウ管理 UI はありません (macOS の挙動に従う Ghostty 哲学)。

---

## 3. 設定の書き方

設定は `~/.config/ghostty-editor/config` というテキストファイルです。**設定 GUI は存在しません**。

### 3.1 開く

```sh
$EDITOR ~/.config/ghostty-editor/config
# または、menubar の Help → Open Config File
```

ファイルが存在しなければ何も書かなくても動きます (デフォルトで使えるのが哲学)。

### 3.2 構文

Ghostty 互換の `key = value` フラット形式:

```
# ── 例: ~/.config/ghostty-editor/config ──

# Ghostty 由来 (ターミナル + フォント関連、Ghostty 本家と完全互換)
font-family = "JetBrains Mono"
font-size = 13
theme = "github-dark"
cursor-style = "block"

# Editor 専用 (editor.* prefix)
editor.line-numbers = true
editor.tab-size = 4
editor.word-wrap = false
editor.theme = "solarized-dark"           # syntax color (~/.config/ghostty-editor/themes/ から)

# LLM Chat 関連
editor.llm.default = "claude"             # 起動時に選ばれる CLI
editor.llm.cli.claude = "/usr/local/bin/claude"  # 手動パス指定 (任意、自動検出で十分なら省略可)
editor.llm.cli.codex = "/opt/homebrew/bin/codex"
```

### 3.3 reload

設定ファイルを保存すると、エディタが自動 reload します (file watch)。再起動不要。

### 3.4 「Ghostty 由来」と「Editor 専用」の区別

- **prefix なし** のキーは Ghostty 本家の config キーをそのまま継承 (font, theme, cursor 等)
- **`editor.*` prefix** のキーは本エディタ独自の設定

Ghostty 本家の全 config キーは [Ghostty Documentation](https://ghostty.org/docs/config) を参照してください。

---

## 4. LLM CLI を追加するには

### 4.1 自動検出

起動時に PATH を scan し、以下を**自動検出**します:

- `claude` (Anthropic Claude Code CLI)
- `codex` (OpenAI Codex CLI)
- `gemini` (Google Gemini CLI)
- `qwen` (Alibaba Qwen CLI)

検出された CLI は LLM Chat panel の `+` ボタン右の dropdown に表示されます。

### 4.2 各 CLI の認証

**各 CLI で `/login` 等を各自実行してください**。本エディタはアカウント情報を管理しません。

```sh
claude /login
codex auth
gemini auth login
qwen login
```

### 4.3 手動追加

PATH 外、または独自の CLI を追加したい場合は config に書きます:

```
editor.llm.cli.my-custom-llm = "/Users/rick/bin/my-llm"
```

dropdown に `my-custom-llm` が出ます。

### 4.4 デフォルト CLI 切替

```
editor.llm.default = "codex"
```

起動時に選ばれる CLI を設定します。

---

## 5. プラグインを入れるには

**重要**: 本エディタには **Marketplace はありません**。プラグインは dotfile に script を置く方式です。

### 5.1 ディレクトリ構成

```
~/.config/ghostty-editor/
├── config
├── keybindings.toml
├── hooks/           ← イベント発火時に呼ばれる script
├── commands/        ← /<name> で呼べるカスタムコマンド
└── themes/          ← syntax color theme
```

### 5.2 hook を追加する

例: ファイル保存時に prettier を走らせる:

```sh
# ~/.config/ghostty-editor/hooks/on-file-save.sh
#!/bin/sh
if [[ "$EDITOR_FILE" == *.ts ]] || [[ "$EDITOR_FILE" == *.tsx ]]; then
    npx prettier --write "$EDITOR_FILE"
fi
```

`chmod +x ~/.config/ghostty-editor/hooks/on-file-save.sh` を忘れずに。

**サポートする hook 一覧**:

| Hook | 起動タイミング | 渡される情報 (env) |
|---|---|---|
| `on-project-open` | フォルダ open 直後 | `EDITOR_PROJECT` (path) |
| `on-file-open` | ファイル open | `EDITOR_FILE` |
| `on-file-save` | 保存直後 | `EDITOR_FILE`, `EDITOR_DIFF` |
| `on-llm-prompt` | LLM 送信前 | stdin: prompt → stdout: 加工後 prompt |
| `on-llm-response` | LLM 応答後 | stdin: response → stdout: 加工後 response |
| `on-terminal-start` | ターミナル起動 | `EDITOR_CWD` |

### 5.3 カスタムコマンドを追加する

```sh
# ~/.config/ghostty-editor/commands/format-all.sh
#!/bin/sh
find . -name '*.zig' -exec zig fmt {} \;
echo "Formatted all .zig files"
```

→ command palette を `⌘⇧P` で開いて `/format-all` で呼べます。

### 5.4 テーマを追加する

```toml
# ~/.config/ghostty-editor/themes/dracula.toml
[colors]
background = "#282a36"
foreground = "#f8f8f2"

[syntax]
keyword = "#ff79c6"
string = "#f1fa8c"
comment = "#6272a4"
function = "#50fa7b"
type = "#8be9fd"
```

config で:
```
editor.theme = "dracula"
```

### 5.5 サポートする script 言語

| 拡張子 | 実行方法 |
|---|---|
| `.sh` | `/bin/sh` |
| `.ts` / `.js` | `bun run` か `node` (検出された方) |
| `.lua` | `luajit` |
| `.zig` (precompiled `.so`) | `dlopen` (上級者向け) |

### 5.6 信頼性

初回 hook ロード時に script の hash を `~/.local/share/ghostty-editor/trusted-hooks.txt` に記録します。**変更があれば確認ダイアログが出ます**。信頼できない script を勝手に動かしません。

---

## 6. URL タブ / ローカルプレビュー

### 6.1 URL タブを開く

リポジトリ内タブの **`+` ボタン**をクリック → popover が出ます:

- `/` で始まる入力 → ファイル選択 (file path)
- それ以外 → URL として扱われ、webview タブとして開く

例:
- `http://127.0.0.1:7878/` (cr の dev server)
- `http://localhost:3000/` (Next.js dev server)
- `https://docs.anthropic.com/`

### 6.2 用途

- ローカル dev server のプレビュー (リロード ⌘R)
- ドキュメントを並べて編集
- gRAG / vRAG / 他の MCP server の UI

### 6.3 ⌘R / Back / Forward

タブ上で:
- `⌘R`: リロード
- `⌘[` / `⌘]`: 戻る / 進む

---

## 7. タブの drag 分離・分割

### 7.1 タブを別 split に分離

リポジトリ内タブをエディタペインの**端**に drag → split が作られ、そちらに表示されます。

### 7.2 タブを別ウィンドウに分離

タブをウィンドウ**外**に drag → 新しいウィンドウとして独立します。

### 7.3 元に戻す

別ウィンドウ化したタブを drag で元のウィンドウに戻すと、再統合されます。

### 7.4 LLM Chat panel の分離

LLM Chat panel ヘッダを drag → 別ウィンドウ化。これにより縦長モニタの右側を Chat 専用にできます。

---

## 8. ターミナルペイン

### 8.1 開く

- menubar: `View → Toggle Terminal`
- キーバインド: `⌃\`` (default)

### 8.2 これは Ghostty です

下部ターミナルペインの中身は **Ghostty 本家そのもの**です。font / theme / keybinding / Kitty Graphics / ANSI truecolor 全てが本家と完全互換。

CCAGI の statusline (`MCP •gRAG •vRAG ... | CTX:60%` のような表示) もそのまま動きます。

### 8.3 設定共有

`~/.config/ghostty-editor/config` の Ghostty 由来キー (font, theme 等) はこのターミナルに適用されます。

Ghostty 本家を別途使っている場合、本家の `~/.config/ghostty/config` とは別ファイルなので注意。意図的に内容を統一したければ symlink を貼ってください:

```sh
ln -sf ~/.config/ghostty/config ~/.config/ghostty-editor/config
```

### 8.4 分割・タブ化

ターミナルペインは画面下部固定 (デフォルト) ですが、設定で:
```
editor.terminal.placement = "bottom" | "right" | "tab"
```
で位置を変えられます。

---

## 9. LLM Chat panel

### 9.1 開く

右上の Chat アイコンをクリック、または `⌘⇧L`。

### 9.2 操作

- Chat 入力欄にプロンプトを書く → `⌘Enter` で送信
- panel ヘッダの `+` で新規 Chat タブ
- `+` 右の dropdown で CLI を切替 (claude / codex / gemini / qwen / 自分が追加したもの)

### 9.3 context の渡し方

- 現在開いているファイルが自動で context に含まれます
- 選択範囲があれば、それも context に含まれます
- ファイルツリーで複数選択した状態で Chat を開くと、それらのファイルが context として渡されます

### 9.4 別ウィンドウ化

panel ヘッダを drag → 別 NSWindow として独立。縦長モニタや 2 枚目のモニタに置きたいときに使います。

### 9.5 hook で介入する

- `on-llm-prompt`: 送信前 prompt を加工
- `on-llm-response`: 応答を加工 (例: code block を自動コピー、特定キーワードで通知)

詳細は §5.2。

---

## 10. キーバインド一覧

### 10.1 デフォルト

| キー | アクション |
|---|---|
| ⌘O | フォルダ open |
| ⌘N | 新規ファイル (現在のフォルダ内) |
| ⌘S | 保存 |
| ⌘⌥S | すべて保存 |
| ⌘W | タブを閉じる |
| ⌘⇧W | ウィンドウを閉じる |
| ⌘T | 新規タブ (リポジトリ内タブ) |
| ⌘⇧T | 直前に閉じたタブを復元 |
| ⌘F | ファイル内検索 |
| ⌘⇧F | 全プロジェクト検索 |
| ⌘P | ファイルを名前で開く (Quick Open) |
| ⌘⇧P | コマンドパレット |
| ⌘\\ | エディタを左右に分割 |
| ⌃` | ターミナル開閉 |
| ⌘⇧L | LLM Chat panel 開閉 |
| ⌘Enter | LLM Chat 送信 |
| ⌘Z / ⌘⇧Z | undo / redo |
| ⌘D | 次の同じ単語を選択 (multi-cursor) |
| ⌘/ | コメントトグル |

### 10.2 カスタム

`~/.config/ghostty-editor/keybindings.toml`:

```toml
[bindings]
"cmd+shift+e" = "toggle-sidebar"
"cmd+k cmd+t" = "select-theme"
```

action 一覧は `⌘⇧P` → `Show all actions` で確認できます。

---

## 11. CCAGI 連携の仕組み

CCAGI ユーザー向け追加機能。CCAGI を使っていない方は本章をスキップしてください。

### 11.1 自動 scan

起動時に以下を scan します:

| Path | 内容 |
|---|---|
| `~/.claude/hooks/*` | 全体 CCAGI hook |
| `~/.claude/skills/*` | スキル一覧 |
| `~/.claude/commands/*` | コマンド一覧 |
| `<project>/.claude/*` | プロジェクト固有 (上書き) |

### 11.2 何が起きるか

- CCAGI の hooks (23個前後) → editor の hook engine に登録され、対応するタイミングで発火
- CCAGI の skills (112個前後) → command palette に `/<skill-name>` で出現
- CCAGI の commands (263個前後) → 同上

### 11.3 .ccagi.yml

プロジェクトルートの `.ccagi.yml` も読み込み、`CCAGI_PROJECT_TYPE` 等の環境変数を hook に渡します。

### 11.4 bridge_send / receive

CCAGI agent からの通知 (例: 別 CLI で起動した agent の進捗) を LLM Chat panel に流せます。詳細は `tech-spec.md` §7.3。

### 11.5 オフ

CCAGI 連携を切るには:
```
editor.ccagi.enabled = false
```

---

## 12. トラブルシューティング

### 12.1 起動しない

- macOS のセキュリティで止められている場合:
  - `System Settings → Privacy & Security → Open Anyway`
- 設定ファイルが壊れている場合:
  ```sh
  mv ~/.config/ghostty-editor/config ~/.config/ghostty-editor/config.broken
  open -a Ghostty-Editor
  ```

### 12.2 ファイルが開けない

- 権限エラー: `ls -la <file>` で確認
- 1GB 超のファイル: MVP では未対応 (将来 streaming open を検討)

### 12.3 LLM Chat が動かない

- dropdown に CLI が表示されない:
  - `which claude` 等で PATH を確認
  - `~/.config/ghostty-editor/config` に `editor.llm.cli.<name> = /path` を追加
- 認証エラー: 各 CLI で `/login` を実行
- timeout: CLI の応答が遅い場合、log を確認 (`~/.local/share/ghostty-editor/logs/chat.log`)

### 12.4 ターミナルが Ghostty 本家と動作が違う

- 本書を疑うより、`Ghostty/` submodule の commit を確認
- `git submodule status` で固定 commit を確認
- 必要なら upstream を更新: `cd Ghostty && git fetch && git checkout <new-sha>`

### 12.5 plugin (hook/command) が動かない

- `chmod +x` を付けたか確認
- shebang (`#!/bin/sh` 等) が正しいか確認
- `~/.local/share/ghostty-editor/logs/ext.log` で実行ログを確認
- `~/.local/share/ghostty-editor/trusted-hooks.txt` から該当 hash を削除 → 再 scan で trust し直す

### 12.6 重くなった気がする

- `~/.local/share/ghostty-editor/logs/perf.log` を見る
- `View → Show Memory Usage` で RAM 内訳を表示
- Issue を起票してください: https://github.com/dngwkim0357-ai/Ghostty-editor-studio/issues

### 12.7 リセットしたい

```sh
# 設定 + キャッシュを全て消す (アカウントはないので痕跡ゼロ)
rm -rf ~/.config/ghostty-editor
rm -rf ~/.local/share/ghostty-editor
```

---

## 改訂履歴

| 版数 | 日付 | 変更 | 起票者 |
|---|---|---|---|
| 0.1 | 2026-05-23 | 初版作成 (MVP 未実装段階の構想ベース) | Rick + Claude |

---

*Generated by CCAGI SDK Phase 1 — User Manual is a living document. Update on every feature change.*
