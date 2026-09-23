# tmux-pane-beacon

[![CI](https://github.com/ryuchan00/tmux-pane-beacon/actions/workflows/ci.yml/badge.svg)](https://github.com/ryuchan00/tmux-pane-beacon/actions/workflows/ci.yml)
[![release](https://github.com/ryuchan00/tmux-pane-beacon/actions/workflows/release.yml/badge.svg)](https://github.com/ryuchan00/tmux-pane-beacon/releases/latest)

## 概要

tmux の各ペインに固有色を割り当て、上側の枠線にペイン番号とタイトルを表示する TPM プラグインです。Claude Code と Codex が端末タイトルに出している作業要約は、追加の設定なしで枠線に表示されます。エージェントの hook やほかのツールからバックグラウンドのペインへアラートを設定でき、そのペインを選択すると自動で解除されます。主要処理は Rust 製です。

![6つのペインでコーディングエージェントが動作し、各ペインに固有色と作業要約が表示されている。1つのペインには通知が出ている](docs/screenshot.png)

6つのペインでそれぞれコーディングエージェントを動かしている状態です。ペインごとに色が違い、枠にはそのエージェントが送った作業要約が出るため、どのセッションが何をしているかが一目で分かります。ペイン2には通知が立っているため、要約の代わりに通知を表示しています。完了、入力待ち、エラーの通知は、そのペインを選択するまで残ります。

English version: [README.md](README.md)

## 要件

- tmux 3.0 以降 (ペイン単位オプション `set-option -p` と hook の配列指定を使うため)
- bash と、curl または wget (TPM の入口とバイナリの取得に使う)
- Rust 1.85 以降 (リリースを使わず自分でビルドする場合のみ)

CI では macOS (Intel と Apple Silicon)、Ubuntu、Debian bookworm と trixie (リリースと同じ静的リンク版) でテストを実行しています。日常の利用では tmux 3.7b (macOS) と tmux 3.2a (Ubuntu on WSL) で動かしています。

## 導入

TPM の設定に次の行を追加し、`prefix + I` でプラグインを読み込みます。

```tmux
set -g @plugin 'ryuchan00/tmux-pane-beacon'
```

これだけで動きます。初回読み込み時に、実行中のプラットフォーム向けのビルド済みバイナリを対応するGitHubリリースから取得し、公開されている `SHA256SUMS` と突き合わせたうえで、プラグインディレクトリの `bin/pane-beacon` に置きます。リリースは Intel/Arm の Linux と macOS を対象にしています。

ビルド済みバイナリが無いプラットフォームの場合、または自分でビルドしたい場合は、次を一度実行してから tmux を再読込してください。

```bash
cd ~/.tmux/plugins/tmux-pane-beacon
make build
tmux source-file ~/.tmux.conf
```

`PANE_BEACON_BIN=/path/to/pane-beacon` を設定すると、この探索を完全に上書きできます。

`prefix + U` でプラグインを更新すると、取得済みの `bin/pane-beacon` も、手元でビルドした `target/release/pane-beacon` も `Cargo.toml` の版と一致しない場合に、新しい版を取得し直します。取得に失敗したときは、古いバイナリを警告付きで使い続けます。

TPM はデフォルトブランチを追跡します。バージョンを固定したい場合はタグを付けてください。

```tmux
set -g @plugin 'ryuchan00/tmux-pane-beacon#v0.2.2'
```

ローカル開発では、このディレクトリを TPM のプラグインディレクトリへ symlink します。TPM は既存のディレクトリを導入済みとして扱うので、上の `@plugin` 行はそのままで動きます。

```bash
ln -s /path/to/tmux-pane-beacon ~/.tmux/plugins/tmux-pane-beacon
```

設定を変更した場合は tmux の設定ファイルを再読込してください。

## tmux がプラグインを読み込む仕組み

`@plugin` の設定だけではプラグインは実行されません。`tmux.conf` の末尾でTPMを実行すると、TPMが登録済みプラグインを順番に読み込みます。このため、TPMを実行する行は `@plugin` の設定より後に置きます。

```tmux
set -g @plugin 'ryuchan00/tmux-pane-beacon'

# @pluginをすべて設定した後、ファイルの末尾でTPMを実行する
run '~/.tmux/plugins/tpm/tpm'
```

読み込み時の処理は次の順序です。

```mermaid
flowchart TD
    A[tmuxが ~/.tmux.conf を読む] --> B[@plugin にリポジトリ名を登録]
    B --> C[tmux.conf末尾でTPMを実行]
    C --> D[TPMがプラグイン内の *.tmux を実行]
    D --> E[pane-beacon.tmuxが枠表示とhookを設定]
    E --> F[Rustバイナリの init が全ペインへ色を割り当てる]
    F --> G[以後はtmuxのhookがRustバイナリを呼ぶ]
```

TPMの `prefix + I` は、GitHubのリポジトリを `~/.tmux/plugins/tmux-pane-beacon` へ取得します。Rustバイナリはソースに含まれないため、`pane-beacon.tmux` が初回読み込み時に次の順で解決します。`$PANE_BEACON_BIN`、`bin/pane-beacon` (リリースから取得済みのもの)、`target/release/pane-beacon` (自分でビルドしたもの)、最後に `Cargo.toml` のversionに対応するリリースからのダウンロードです。ダウンロードしたバイナリは `SHA256SUMS` と突き合わせ、`--version` で起動できることを確認してから配置します。新しいlibcに対してビルドされたバイナリは、ここで弾かれて保存されません。

`pane-beacon.tmux` は常駐プロセスを起動しません。読み込み時に `pane-border-format` とtmuxのhookを設定し、次のイベントが発生したときだけ Rust バイナリを実行します。

| イベント | Rust CLIの処理 |
|---|---|
| プラグイン読込 | `init` で既存の全ペインへ色を割り当てる |
| ペイン分割 | `assign-color <pane_id>` で新しいペインへ色を割り当てる |
| ウィンドウ作成 | `assign-color <pane_id>` で最初のペインへ色を割り当てる |
| エージェントの状態変更 | 外部hookが `update` を呼び、タイトル・状態・通知を更新する |
| ペイン選択 | tmuxコマンドで通知を消し、選択中の枠色を更新する |

現在登録されているhookは、次のコマンドで確認できます。

```bash
tmux show-hooks -g | grep pane-beacon
```

プラグインを手動で再読込する場合は、通常はtmux設定全体を再読込します。

```bash
tmux source-file ~/.tmux.conf
```

## オプション

| オプション | 既定値 | 説明 |
|---|---|---|
| `@pane_beacon_palette` | `196 46 21 226 201 51 208 118 27 199 214 82 39 220 165 50 202 154 33 129 190 48 57 93 197 45 213 159 87 228` | 循環して割り当てる 256 色番号 |
| `@pane_beacon_title_fallback` | `#{pane_current_command}` | タイトルがホスト名のままの場合に表示する format |
| `@pane_beacon_title_max` | `60` | タイトルの最大表示幅 |
| `@pane_beacon_alert_icon` | `🔔` | アラートの先頭に表示する記号 |

設定例です。

```tmux
set -g @pane_beacon_palette '10 20 30'
set -g @pane_beacon_title_max '40'
set -g @pane_beacon_alert_icon '!'
```

## アラート

公開コマンドの形式は次のとおりです。

```text
scripts/alert.sh <pane_id> <message> [window-status-style]
```

第 3 引数を省略した場合は `fg=yellow,bold` を使います。対象が接続中セッションのアクティブなウィンドウにあるアクティブペインなら、表示済みと判断して何も設定しません。

外部ツールから現在のペインへ完了通知を出す例です。

```bash
~/.tmux/plugins/tmux-pane-beacon/scripts/alert.sh "$TMUX_PANE" "処理が完了しました"
```

独自のウィンドウ表示色も指定できます。

```bash
~/.tmux/plugins/tmux-pane-beacon/scripts/alert.sh "$TMUX_PANE" "入力を待っています" "fg=magenta,bold"
```

アラートは対象ペインを選択すると解除されます。

## コーディングエージェント

### 作業要約の表示に設定は要らない

Claude Code と Codex は、いま取り組んでいる作業の短い要約を、端末タイトルを変える標準の制御文字列 (`ESC ] 2 ; タイトル BEL`) で出力しています。tmux の中ではこれを tmux がペインの `pane_title` として保持し、このプラグインの `pane-border-format` が枠線に表示します。要約を出すためにエージェント側からこのプラグインを呼ぶ必要はなく、エージェントがタイトルを変えると枠線の表示もすぐ追従します。

| エージェント | タイトルの例 | 出どころ |
|---|---|---|
| Claude Code | `✳ tmuxペインの仕組みの解説` | 会話の内容から Claude Code が作るトピック名。`/rename` で手動で付けられ、`CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1` で止められる |
| Codex | `確認する .NET Coreのメモリ管理 \| my-project` | Codex の TUI がスレッドとプロジェクト名から組み立てる。表示する項目は `tui.terminal_title` の設定で選べる |

タイトルがホスト名のままのペインは、どのプログラムもタイトルを付けていないため、代わりに `@pane_beacon_title_fallback` を表示します。

### エージェントの hook からアラートを出す

背景のペインでエージェントが終わったことや、入力を待っていることは、タイトルだけでは分かりません。そのためにはエージェントの hook から `scripts/alert.sh` を呼びます。hook はエージェントのペインの中で実行されるので、`$TMUX_PANE` がそのペインを指します。先頭の条件は、tmux の外でエージェントを動かしたときに呼び出しを飛ばすためのものです。

Claude Code (`~/.claude/settings.json`):

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "[ -z \"$TMUX_PANE\" ] || ~/.tmux/plugins/tmux-pane-beacon/scripts/alert.sh \"$TMUX_PANE\" 'Claude: 完了' || true"
          }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "[ -z \"$TMUX_PANE\" ] || ~/.tmux/plugins/tmux-pane-beacon/scripts/alert.sh \"$TMUX_PANE\" 'Claude: 入力待ち' 'fg=magenta,bold' || true"
          }
        ]
      }
    ]
  }
}
```

Codex (`~/.codex/hooks.json`) も同じ形式です。入力待ちには `PermissionRequest` を使います。追加した hook は、Codex で一度 `/hooks` を実行して信頼済みにしてください。

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "[ -z \"$TMUX_PANE\" ] || ~/.tmux/plugins/tmux-pane-beacon/scripts/alert.sh \"$TMUX_PANE\" 'Codex: 完了' || true"
          }
        ]
      }
    ],
    "PermissionRequest": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "[ -z \"$TMUX_PANE\" ] || ~/.tmux/plugins/tmux-pane-beacon/scripts/alert.sh \"$TMUX_PANE\" 'Codex: 入力待ち' 'fg=magenta,bold' || true"
          }
        ]
      }
    ]
  }
}
```

### 要約を自分で送る

端末タイトルを出さないツールは、`update` で要約と状態を送れます。`update` はペインのタイトルを上書きするため、Claude Code や Codex の hook からは呼ばないでください。エージェント自身が付けたタイトルが置き換わります。

```bash
~/.tmux/plugins/tmux-pane-beacon/bin/pane-beacon update "$TMUX_PANE" \
  --agent my-tool --status working --summary "マイグレーションを実行中"
```

状態は `working`、`waiting`、`completed`、`error` を指定できます。`waiting`、`completed`、`error` は、対象ペインが表示されていない場合にアラートも設定します。状態とアラートを消すには `clear <pane_id>` を使います。

## 注意

`pane-active-border-style` は、選択中のペイン固有色を即時反映するためウィンドウ単位で上書きされます。そのため、このオプションに対する利用者のグローバル設定はアクティブペインの枠には反映されません。

## テスト

Rust の単体テスト、隔離した tmux サーバーを使う振る舞いテスト、シェルの静的検査を実行できます。実行には Rust ツールチェーン (`cargo`、`clippy`、`rustfmt`)、bats-core、shellcheck が必要です。プラグインを使うだけなら、どれも要りません。

```bash
make test
make lint
```

CI では、macOS (Intel と Apple Silicon) と Ubuntu でソースからビルドしてテストし、Debian bookworm と trixie ではリリースと同じ静的リンク版でテストしています。

## 類似プロジェクト

tmux でコーディングエージェントの状態を追うプラグインはほかにもあります。主な違いは、状態をどこに表示するかと、どうやって状態を検出するかです。

| プロジェクト | 状態の表示先 | 状態の検出方法 |
|---|---|---|
| [tmux-agent-indicator](https://github.com/accessd/tmux-agent-indicator) | ペインの枠の色、ウィンドウタイトルの色、ステータスバーのアイコン | エージェントの hook (インストーラが Claude Code と Codex の設定を書き換える)。hook を出さないエージェントはプロセスから検出する |
| [tmux-agent-sidebar](https://github.com/hiroppy/tmux-agent-sidebar) | 専用のサイドバーペイン。状態、プロンプト、ツール呼び出し、Git の状態、worktree を表示する | エージェントの hook、または Claude Code のプラグイン |
| [tmux-handlr](https://github.com/CRThaze/tmux-handlr) | ステータスラインの点、切り替えメニュー、ダッシュボード、サイドバー、ntfy の通知 | 常駐デーモンが各ペインのタイトルと画面の内容を読む |
| [tmux-agent-status](https://github.com/RatulMaharaj/tmux-agent-status) | ウィンドウ選択画面とステータスバーのバッジ、ウィンドウ名の変更、デスクトップ通知 | 各ペインの tty 上のプロセスを調べる |

tmux-pane-beacon は範囲を絞っています。常駐デーモンを持たず、プロセスや画面の内容も調べません。要約はエージェントがすでに出している端末タイトルをそのまま使い、hook が必要なのはアラートだけです。その代わりに、ペインごとに固定の色を付けるので、レイアウトを組み替えても目的のペインを見つけやすくなります。

## ライセンス

MIT ライセンスです。[LICENSE](LICENSE) を参照してください。
