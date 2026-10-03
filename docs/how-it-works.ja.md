[README に戻る](../README.ja.md)

# tmux がプラグインを読み込む仕組み

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
