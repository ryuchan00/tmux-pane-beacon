[README に戻る](../README.ja.md)

# コーディングエージェント

### 作業要約の表示に設定は要らない

Claude Code と Codex は、いま取り組んでいる作業の短い要約を、端末タイトルを変える標準の制御文字列 (`ESC ] 2 ; タイトル BEL`) で出力しています。tmux の中ではこれを tmux がペインの `pane_title` として保持し、このプラグインの `pane-border-format` が枠線に表示します。要約を出すためにエージェント側からこのプラグインを呼ぶ必要はなく、エージェントがタイトルを変えると枠線の表示もすぐ追従します。

| エージェント | タイトルの例 | 出どころ |
|---|---|---|
| Claude Code | `✳ tmuxペインの仕組みの解説` | 会話の内容から Claude Code が作るトピック名。`/rename` で手動で付けられ、`CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1` で止められる |
| Codex | `確認する .NET Coreのメモリ管理 \| my-project` | Codex の TUI がスレッドとプロジェクト名から組み立てる。表示する項目は `tui.terminal_title` の設定で選べる |

タイトルがホスト名のままのペインは、どのプログラムもタイトルを付けていないため、代わりに `@pane_beacon_title_fallback` を表示します。

### エージェントの hook から実行状態とアラートを送る

エージェントがまだ動いているのか、背景のペインで終わったのか、入力を待っているのかは、タイトルだけでは分かりません。これはエージェントの hook から `update` で送ります。`--summary` を付けなければ、`update` はエージェントが付けたタイトルには触れず、状態だけを記録します。

| hook | 状態 | 枠線 | 背景のペインへのアラート |
|---|---|---|---|
| `UserPromptSubmit`、`PostToolUse` | `working` | 緑の `●` | なし |
| `PermissionRequest` | `waiting` | マゼンタの `●` | あり |
| `Stop` | `completed` | 記号なし | あり |

`PostToolUse` は、権限の確認を承認したあとに状態を `working` へ戻し、古くなった入力待ちのアラートを消すために使います。ほかのツールが出したアラートは残します。hook はエージェントのペインの中で実行されるので、`$TMUX_PANE` がそのペインを指します。`scripts/pane-beacon.sh` は、バイナリがどこに置かれていても探して実行します。先頭の条件は、tmux の外でエージェントを動かしたときに呼び出しを飛ばすためのものです。

Claude Code (`~/.claude/settings.json`):

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "[ -z \"$TMUX_PANE\" ] || ~/.tmux/plugins/tmux-pane-beacon/scripts/pane-beacon.sh update \"$TMUX_PANE\" --agent claude --status working || true"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "[ -z \"$TMUX_PANE\" ] || ~/.tmux/plugins/tmux-pane-beacon/scripts/pane-beacon.sh update \"$TMUX_PANE\" --agent claude --status working || true"
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
            "command": "[ -z \"$TMUX_PANE\" ] || ~/.tmux/plugins/tmux-pane-beacon/scripts/pane-beacon.sh update \"$TMUX_PANE\" --agent claude --status waiting || true"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "[ -z \"$TMUX_PANE\" ] || ~/.tmux/plugins/tmux-pane-beacon/scripts/pane-beacon.sh update \"$TMUX_PANE\" --agent claude --status completed || true"
          }
        ]
      }
    ]
  }
}
```

Codex (`~/.codex/hooks.json`) も同じ形式です。追加した hook は、Codex で一度 `/hooks` を実行して信頼済みにしてください。

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "[ -z \"$TMUX_PANE\" ] || ~/.tmux/plugins/tmux-pane-beacon/scripts/pane-beacon.sh update \"$TMUX_PANE\" --agent codex --status working || true"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "[ -z \"$TMUX_PANE\" ] || ~/.tmux/plugins/tmux-pane-beacon/scripts/pane-beacon.sh update \"$TMUX_PANE\" --agent codex --status working || true"
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
            "command": "[ -z \"$TMUX_PANE\" ] || ~/.tmux/plugins/tmux-pane-beacon/scripts/pane-beacon.sh update \"$TMUX_PANE\" --agent codex --status waiting || true"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "[ -z \"$TMUX_PANE\" ] || ~/.tmux/plugins/tmux-pane-beacon/scripts/pane-beacon.sh update \"$TMUX_PANE\" --agent codex --status completed || true"
          }
        ]
      }
    ]
  }
}
```

記号は、状態を送ったときと同じコマンドがペインで動いている間だけ表示します。`Stop` hook が来ないままエージェントが終わっても、シェルに戻れば記号は消えます。Claude Code で Esc を押してターンを中断した場合は hook が呼ばれないため、次のプロンプトを送るまで `working` のまま表示されます。

### 要約を自分で送る

端末タイトルを出さないツールは、`--summary` で要約も送れます。`--summary` はペインのタイトルを上書きするため、Claude Code や Codex の hook では付けないでください。エージェント自身が付けたタイトルが置き換わります。

```bash
~/.tmux/plugins/tmux-pane-beacon/scripts/pane-beacon.sh update "$TMUX_PANE" \
  --agent my-tool --status working --summary "マイグレーションを実行中"
```

状態は `working`、`waiting`、`completed`、`error` を指定できます。`waiting`、`completed`、`error` は、対象ペインが表示されていない場合にアラートも設定します。状態とアラートを消すには `clear <pane_id>` を使います。
