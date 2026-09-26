> このファイルは実装前に書いた設計書で、履歴として残している。当時はこのリポジトリを
> dotfiles のサブディレクトリとして開発しており、処理もシェルスクリプトで書いていた。
> その後、主要処理を Rust 製の `pane-beacon` バイナリへ移し (v0.2)、GitHub Releases
> からバイナリを取得する配布方法に変えたため、配置、公開方針、スクリプト構成の記述は
> 現状と異なる。現在の仕様は [README.ja.md](../README.ja.md) を参照すること。

# tmux-pane-beacon 設計書

## 目的

tmux の各ペインに固有色を割り当て、枠線上部に「ペイン番号とタイトル」または「外部ツールからのアラート」をその色で描く TPM プラグインを作る。
現在 `.tmux.conf.mac` と `tmux/assign-pane-color.sh` に散らばっている仕組みを、設定可能な形で 1 か所にまとめる。

## 範囲

含めるもの。

- ペインごとの固有色の割り当てと、新規ペイン作成時の自動割り当て
- 枠線上部の表示 (`pane-border-status` と `pane-border-format`)
- アラート表示と、フォーカスが戻ったときの自動解除
- 外部ツールがアラートを立てるためのコマンド `scripts/alert.sh`

含めないもの。

- Claude Code のフック本体 (`~/.claude/hooks/*.sh`)
- `~/.claude/sessions.db` と `~/.config/tmux/pane-last-session.sh` (sqlite からセッション名を引く仕組み)
- `window-style` や `pane-border-style` などの配色 (利用者の conf に残す)
- GitHub への公開。ローカルで動かすまでを対象とし、push はしない

## 配置と TPM 連携

`~/ghq/github.com/ryuchan00/dotfiles/tmux-pane-beacon/` に置く。
dotfiles のサブディレクトリだが、独立したプラグインとして完結させ、後日 `git subtree split` で切り出せる構成にする。

```
tmux-pane-beacon/
  pane-beacon.tmux          TPM が実行するエントリ
  scripts/helpers.sh        オプション取得とパレット解析
  scripts/assign-color.sh   固有色の割り当て
  scripts/alert.sh          アラートを立てる公開コマンド
  tests/test_helper.bash    隔離 tmux サーバーの起動と終了
  tests/*.bats              振る舞いテスト
  Makefile                  test と lint
  README.md
  LICENSE                   MIT
  docs/superpowers/specs/   この設計書
```

TPM は `~/.tmux/plugins/<名前>/` に `*.tmux` があればそれを実行する。
`~/.tmux/plugins/tmux-pane-beacon` をこのディレクトリへの symlink にし、conf には `set -g @plugin 'ryuchan00/tmux-pane-beacon'` と書く。
TPM は「ディレクトリが存在し `git remote` が通る」ものを導入済みとみなすため、symlink 先が dotfiles の作業ツリー内にあれば clone を試みない。
後日 GitHub に push しても conf を変える必要はない。

## 公開インターフェース

### グローバルオプション

`pane-beacon.tmux` の実行時に読み取る。値を変えたら `source-file` で再読込する。

| オプション | 既定値 | 用途 |
|---|---|---|
| `@pane_beacon_palette` | 後述の 30 色 | 空白区切りの 256 色番号。ペインにこの順で循環割り当てする |
| `@pane_beacon_title_fallback` | `#{pane_current_command}` | `pane_title` がホスト名のまま (未設定) のときに表示する format |
| `@pane_beacon_title_max` | `60` | タイトルの最大表示幅。超えた分は `…` で切り詰める |
| `@pane_beacon_alert_icon` | `🔔` | アラート表示の先頭に付ける記号 |

既定パレットは暗い背景で見分けやすい 30 色で、隣接ペインが似た色にならないよう色相を飛ばして並べる。

```
196 46 203 226 201 51 208 118 215 199
214 82 192 220 165 50 202 154 223 129
190 48 210 93 197 45 213 159 87 228
```

### ペイン単位の状態

プラグインが読み書きするユーザーオプション。
名前空間を揃えるため、現行の `@pc` `@pane-alert` `@pc_next` から改名する。

| オプション | 種別 | 内容 |
|---|---|---|
| `@pane_beacon_color` | ペイン | `colour196` のような固有色 |
| `@pane_beacon_alert` | ペイン | アラート文字列。空なら通常表示 |
| `@pane_beacon_next` | グローバル | 次に割り当てるパレットの添字 |

### alert.sh

```
scripts/alert.sh <pane_id> <message> [window-status-style]
```

- 対象ペインが「セッションにクライアントが接続中」かつ「ウィンドウがアクティブ」かつ「ペインがアクティブ」なら何もせず 0 で終了する。見えているペインにアラートを出しても意味がないため
- それ以外は `@pane_beacon_alert` に `<message>` を設定し、そのペインが属するウィンドウの `window-status-style` を第 3 引数 (既定 `fg=yellow,bold`) にする
- 解除はプラグインの `after-select-pane` フックが行う。呼び出し側は解除を意識しなくてよい

外部ツールは alert.sh だけを呼べばよく、オプション名やウィンドウ着色の規約を知る必要がない。

## 動作

### 読込時 (`pane-beacon.tmux`)

1. グローバルオプションを既定値付きで読む
2. `pane-border-status top` と `pane-border-format` を設定する。format は次を描く
   - 固有色で、アクティブなら `━━`、非アクティブなら `──` を先頭に置く
   - `[#{pane_index}]`
   - `@pane_beacon_alert` があれば `<icon> <alert>`、なければ `pane_title`。`pane_title` がホスト名と等しければ `@pane_beacon_title_fallback` を展開する
   - 末尾にアクティブなら太線、非アクティブなら細線を置く
3. フックを登録する。添字は 90 番台に固定し、利用者自身のフックを上書きしない
   - `after-split-window[90]` と `after-new-window[90]`: 新規ペインに `assign-color.sh #{pane_id}`
   - `after-select-pane[90]`: `@pane_beacon_alert` を unset
   - `after-select-pane[91]`: ウィンドウの `window-status-style` を unset
   - `after-select-pane[92]`: ウィンドウの `pane-active-border-style` を選択ペインの固有色にする
4. 全ペインに固有色を一括割り当てする。`source-file` で再読込したときも振り直す

`pane-active-border-style` はウィンドウ単位で上書きするため、利用者がグローバルに設定した値はアクティブペインの枠には効かなくなる。
これは現行の挙動と同じで、README に明記する。

### assign-color.sh

- 引数あり: そのペインに次の色を割り当て、`@pane_beacon_next` を進める。対象がアクティブペインなら枠線の色も即時反映する
- 引数なし: `@pane_beacon_next` を 0 に戻し、全セッションの全ペインに順に割り当てる

## テスト

bats-core を使う。未導入のため `brew install bats-core` を前提とする。
テストは `tmux -L pane-beacon-test -f /dev/null` で隔離サーバーを立て、終了時に `kill-server` する。
スクリプトは隔離サーバー経由で実行し、実サーバーには触れない。

検証項目。

- 全ペインへの一括割り当てで色が重複せず、パレット長を超えると先頭に戻る
- `@pane_beacon_palette` を変えると、その色が使われる
- `split-window` で作ったペインにフック経由で色が付く
- detached セッションで `alert.sh` を呼ぶとアラートとウィンドウ色が設定され、`select-pane` で両方消える
- `#{E:pane-border-format}` の展開結果で、タイトル表示とアラート表示とフォールバックの分岐が期待どおりになる
- `shellcheck` が全スクリプトで警告なしに通る (`make lint`)

## dotfiles 側の移行

プラグインのテストが通ってから行う。

1. `ln -s ~/ghq/github.com/ryuchan00/dotfiles/tmux-pane-beacon ~/.tmux/plugins/tmux-pane-beacon`
2. `.tmux.conf.mac` から次を削除し、`set -g @plugin 'ryuchan00/tmux-pane-beacon'` と `@pane_beacon_title_fallback` の設定に置き換える
   - `pane-border-status` と `pane-border-format`
   - `after-select-pane[0..2]` のフック
   - `after-split-window` と `after-new-window` のフック
   - `run-shell '~/.config/tmux/assign-pane-color.sh'`
3. `tmux/assign-pane-color.sh` と `~/.config/tmux/assign-pane-color.sh` を削除する
4. `~/.claude/hooks/notify-stop.sh` と `notify-waiting.sh` の tmux ブロックを `alert.sh` の 1 行呼び出しに置き換える

`@pane_beacon_title_fallback` には現行と同じ `#(~/.config/tmux/pane-last-session.sh "#{pane_id}" "#{pid}" "#{pane_current_command}")` を設定する。

## 規約

- 会社名をコード、コメント、README、パス、コミットの author に出さない
- シェルスクリプトは `set -euo pipefail` を基本とし、shellcheck を通す。ただし枠線の `#()` から呼ばれる経路はエラーで枠が壊れないよう、失敗時もフォールバック出力で 0 終了する
- コメントは WHY だけを書く
- コミットは Conventional Commits に従い、本文は日本語で書く。push はしない
