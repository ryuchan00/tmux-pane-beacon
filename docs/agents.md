[Back to README](../README.md)

# Coding agents

### Task summaries need no setup

Claude Code and Codex already write a short summary of the current task into
the terminal title with the standard escape sequence (`ESC ] 2 ; title BEL`).
Inside tmux, tmux stores that title as the pane's `pane_title`, and this
plugin's `pane-border-format` prints it. Nothing on the agent side has to call
this plugin for the summary to appear, and the border follows the title as
soon as the agent changes it.

| Agent | Example title | Where it comes from |
|---|---|---|
| Claude Code | `✳ Explain the tmux pane setup` | A topic Claude Code generates from the conversation. `/rename` sets it by hand, and `CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1` turns it off |
| Codex | `Checking memory usage \| my-project` | The Codex TUI builds it from the thread and project name. The `tui.terminal_title` setting chooses the items |

A pane whose title is still the host name has not been given a title by any
program, so the border shows `@pane_beacon_title_fallback` instead.

### Running state and alerts from agent hooks

The title does not tell you whether an agent is still running, or when an
agent in a background pane finished or is waiting for you. Send that from the
agent's hooks with `update`. Without `--summary`, `update` leaves the title the
agent set alone and only records the state.

| Hook | State | Border | Alert on a background pane |
|---|---|---|---|
| `UserPromptSubmit`, `PostToolUse` | `working` | green `●` | no |
| `PermissionRequest` | `waiting` | magenta `●` | yes |
| `Stop` | `completed` | no icon | yes |

`PostToolUse` puts the pane back to `working` after you approve a permission
request, and removes the waiting alert that is no longer true. Alerts raised by
other tools stay. Hooks run inside the agent's pane, so `$TMUX_PANE` points at the right
pane, and `scripts/pane-beacon.sh` finds the binary wherever it is installed.
The guard skips the call when the agent runs outside tmux.

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

Codex (`~/.codex/hooks.json`) uses the same shape. Run `/hooks` in Codex once
to trust the new hooks:

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

The icon is shown only while the pane still runs the command it ran when the
state was sent. If the agent exits without a `Stop` hook, the icon disappears
once the pane is back at the shell. An interrupted turn (Esc in Claude Code)
fires no hook, so the pane keeps showing `working` until the next prompt.

### Publishing a summary yourself

Tools that do not set the terminal title can also publish a summary with
`--summary`. This overwrites the pane title, so leave it out in Claude Code and
Codex hooks; their own titles would be replaced.

```bash
~/.tmux/plugins/tmux-pane-beacon/scripts/pane-beacon.sh update "$TMUX_PANE" \
  --agent my-tool --status working --summary "Running the migration"
```

Supported statuses are `working`, `waiting`, `completed`, and `error`.
`waiting`, `completed`, and `error` also raise an alert when the pane is not
currently visible. Use `clear <pane_id>` to remove its status and alert.
