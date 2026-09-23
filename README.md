# tmux-pane-beacon

[![CI](https://github.com/ryuchan00/tmux-pane-beacon/actions/workflows/ci.yml/badge.svg)](https://github.com/ryuchan00/tmux-pane-beacon/actions/workflows/ci.yml)
[![release](https://github.com/ryuchan00/tmux-pane-beacon/actions/workflows/release.yml/badge.svg)](https://github.com/ryuchan00/tmux-pane-beacon/releases/latest)

Give every tmux pane its own color, and print the pane index and title on the
top border in that color. The task summary that Claude Code and Codex already
put in the terminal title appears on the border with no extra setup. With a few
agent hooks, the border also shows whether the agent is running or waiting for
you, and a background pane gets an alert when its agent finishes; the alert
clears automatically when you select that pane. Core commands are implemented in Rust.

![Six stacked panes running coding agents, each with its own border color and task summary. One pane shows an alert instead.](docs/screenshot.png)

Six panes, each running a coding agent. Every pane has its own color, and its
border shows the task summary that agent published, so you can tell at a glance
which session is doing what. Pane 2 has an alert on it, so it shows the alert
instead of its summary. Completion, waiting, and error alerts remain visible
until you select the pane.

## Requirements

- tmux 3.0 or later (the plugin uses per-pane options, `set-option -p`, and
  indexed hooks)
- bash, and curl or wget (the TPM entry point and the binary download)
- Rust 1.85 or later, only if you build from source instead of using a release

CI runs the test suite on macOS (Intel and Apple Silicon), Ubuntu, and Debian
bookworm and trixie (with the released static binary). It has also been used
day to day on tmux 3.7b (macOS) and tmux 3.2a (Ubuntu on WSL).

## Install

With [TPM](https://github.com/tmux-plugins/tpm), add this line to `~/.tmux.conf`
and press `prefix + I`:

```tmux
set -g @plugin 'ryuchan00/tmux-pane-beacon'
```

That is all: on first load the plugin downloads the prebuilt binary for your
platform from the matching GitHub release, verifies it against the published
`SHA256SUMS`, and stores it in `bin/pane-beacon` inside the plugin directory.
Releases cover Intel and Arm Linux and macOS.

If your platform has no prebuilt binary, or you prefer building yourself,
run the build once and reload tmux:

```bash
cd ~/.tmux/plugins/tmux-pane-beacon
make build
tmux source-file ~/.tmux.conf
```

`PANE_BEACON_BIN=/path/to/pane-beacon` overrides the lookup entirely.

After `prefix + U` updates the plugin, it downloads a new binary whenever
neither `bin/pane-beacon` nor a local `target/release/pane-beacon` build matches
the version in `Cargo.toml`. If that download
fails, it keeps using the old binary and prints a warning.

TPM follows the default branch. To pin a version instead, append the tag:

```tmux
set -g @plugin 'ryuchan00/tmux-pane-beacon#v0.3.0'
```

To hack on the plugin locally, symlink your working copy into TPM's plugin
directory. TPM treats an existing directory as already installed, so the
`@plugin` line above keeps working:

```bash
ln -s /path/to/tmux-pane-beacon ~/.tmux/plugins/tmux-pane-beacon
```

Reload your tmux configuration after changing any option.

## How tmux loads the plugin

The `@plugin` option only registers the repository with TPM. The final TPM line
in `tmux.conf` finds each registered plugin and executes its `*.tmux` entry
point, so it must appear after all `@plugin` options:

```tmux
set -g @plugin 'ryuchan00/tmux-pane-beacon'
run '~/.tmux/plugins/tpm/tpm'
```

TPM executes `pane-beacon.tmux`. That entry point configures the border format,
registers tmux hooks, and runs `pane-beacon init` to color existing panes. It
does not start a daemon. Later, pane and window events invoke the Rust binary
through the registered hooks.

`prefix + I` clones the repository into `~/.tmux/plugins/tmux-pane-beacon`. The
native binary is not committed, so the entry point resolves it on first load, in
this order: `$PANE_BEACON_BIN`, `bin/pane-beacon` (downloaded from a release),
`target/release/pane-beacon` (your own build), and finally a download from the
release matching the version in `Cargo.toml`. A downloaded binary is checked
against `SHA256SUMS` and run once with `--version` before it is kept, so a
binary built against a newer libc is rejected rather than stored.

Inspect the active hooks with:

```bash
tmux show-hooks -g | grep pane-beacon
```

## Options

| Option | Default | Description |
|---|---|---|
| `@pane_beacon_palette` | `196 46 21 226 201 51 208 118 27 199 214 82 39 220 165 50 202 154 33 129 190 48 57 93 197 45 213 159 87 228` | 256-color numbers assigned to panes in a cycle |
| `@pane_beacon_title_fallback` | `#{pane_current_command}` | Format shown when the pane title is still the host name |
| `@pane_beacon_title_max` | `60` | Maximum title width; longer titles are truncated with `…` |
| `@pane_beacon_alert_icon` | `🔔` | Symbol printed in front of an alert |
| `@pane_beacon_working_icon` | `#[fg=green]●` | Shown while the pane is `working`. Do not use commas in it |
| `@pane_beacon_waiting_icon` | `#[fg=magenta]●` | Shown while the pane is `waiting` |
| `@pane_beacon_error_icon` | `#[fg=red]●` | Shown after `error` |

Example:

```tmux
set -g @pane_beacon_palette '10 20 30'
set -g @pane_beacon_title_max '40'
set -g @pane_beacon_alert_icon '!'
```

## Alerts

```text
scripts/alert.sh <pane_id> <message> [window-status-style]
```

The third argument defaults to `fg=yellow,bold`. If the target pane is the
active pane of the active window of an attached session, it is already on
screen, so nothing is set.

Notify the current pane that a long job finished:

```bash
~/.tmux/plugins/tmux-pane-beacon/scripts/alert.sh "$TMUX_PANE" "build finished"
```

With a custom window style:

```bash
~/.tmux/plugins/tmux-pane-beacon/scripts/alert.sh "$TMUX_PANE" "waiting for input" "fg=magenta,bold"
```

An alert is cleared when you select the pane.

## Coding agents

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
~/.tmux/plugins/tmux-pane-beacon/bin/pane-beacon update "$TMUX_PANE" \
  --agent my-tool --status working --summary "Running the migration"
```

Supported statuses are `working`, `waiting`, `completed`, and `error`.
`waiting`, `completed`, and `error` also raise an alert when the pane is not
currently visible. Use `clear <pane_id>` to remove its status and alert.

## Note

`pane-active-border-style` is overridden per window so the active pane's own
color shows up immediately. A global setting of that option therefore does not
apply to the active pane's border.

## Tests

Rust unit tests and behavior tests run against an isolated tmux server, and the
shell entry points are checked statically. Running them needs a Rust toolchain
(`cargo`, `clippy`, `rustfmt`), bats-core, and shellcheck. Just using the
plugin needs none of these.

```bash
make test
make lint
```

CI runs the suite on macOS (Intel and Apple Silicon) and Ubuntu from source,
and on Debian bookworm and trixie with the same static binary the release
ships.

## Similar projects

Several plugins track coding agents in tmux. They differ mainly in where the
state is shown and how it is detected.

| Project | Where state is shown | How state is detected |
|---|---|---|
| [tmux-agent-indicator](https://github.com/accessd/tmux-agent-indicator) | Pane border color, window title colors, status bar icons | Agent hooks (its installer edits the Claude Code and Codex settings), with process detection as a fallback |
| [tmux-agent-sidebar](https://github.com/hiroppy/tmux-agent-sidebar) | A sidebar pane with status, prompts, tool calls, Git state, and worktrees | Agent hooks, or a Claude Code plugin |
| [tmux-handlr](https://github.com/CRThaze/tmux-handlr) | Status-line dots, a switcher menu, a dashboard, a sidebar, ntfy pushes | A background daemon that reads each pane's title and rendered screen |
| [tmux-agent-status](https://github.com/RatulMaharaj/tmux-agent-status) | Badges in the window chooser and status bar, window renaming, desktop notifications | Scans the processes on each pane's tty |

tmux-pane-beacon keeps a narrower scope. It runs no daemon and does not
inspect processes or screen contents. The summary comes from the terminal title
the agents already set, and hooks are needed only for the running state and
alerts. What it adds is a
fixed color per pane, so a pane stays easy to find after you rearrange the
layout.

## License

MIT. See [LICENSE](LICENSE).

日本語版は [README.ja.md](README.ja.md) を参照してください。
