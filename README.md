# tmux-pane-beacon

[![CI](https://github.com/ryuchan00/tmux-pane-beacon/actions/workflows/ci.yml/badge.svg)](https://github.com/ryuchan00/tmux-pane-beacon/actions/workflows/ci.yml)
[![release](https://github.com/ryuchan00/tmux-pane-beacon/actions/workflows/release.yml/badge.svg)](https://github.com/ryuchan00/tmux-pane-beacon/releases/latest)

English | [日本語](README.ja.md)

Give each tmux pane its own color and show its number and terminal title on the top border. Find the right terminal or coding-agent session when several panes are open.

- Pane colors stay with their panes when you rearrange the layout.
- Terminal titles set by your applications appear on the border.
- Optional agent hooks add working/waiting indicators and completion alerts.

![Colored pane borders with task titles; pane 2 shows an alert](docs/screenshot.png)

[Install](#install) · [Agent status](#agent-status-and-notifications) · [Options](#options) · [Troubleshooting](#troubleshooting)

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
before the line that starts TPM:

```tmux
set -g @plugin 'ryuchan00/tmux-pane-beacon'

# Keep your existing TPM startup line at the end
run '~/.tmux/plugins/tpm/tpm'
```

Save the file, run the following inside tmux, then press `prefix + I` (uppercase I). The default tmux prefix is `Ctrl+b`.

```bash
tmux source-file ~/.tmux.conf
```

On first load the plugin downloads the prebuilt binary for your
platform from the matching GitHub release, verifies it against the published
`SHA256SUMS`, and stores it in `bin/pane-beacon` inside the plugin directory.
Releases cover Intel and Arm Linux and macOS.

### Check the display

Split a tmux pane: each pane should have a colored number and title along its top border. To try a title from your shell, run:

```bash
printf '\033]2;beacon demo\007'
```

Your shell or application may replace it when it next updates the terminal title.

### Build from source

If your platform has no prebuilt binary, or you prefer building yourself,
run the build once and reload tmux:

```bash
cd ~/.tmux/plugins/tmux-pane-beacon
make build
tmux source-file ~/.tmux.conf
```

`PANE_BEACON_BIN=/path/to/pane-beacon` overrides the lookup entirely.

### Update or pin a version

After `prefix + U` updates the plugin, it downloads a new binary whenever
neither `bin/pane-beacon` nor a local `target/release/pane-beacon` build matches
the version in `Cargo.toml`. If that download
fails, it keeps using the old binary and prints a warning.

TPM follows the default branch. To pin a version instead, append the tag:

```tmux
set -g @plugin 'ryuchan00/tmux-pane-beacon#v0.3.1'
```

### Local development

To hack on the plugin locally, symlink your working copy into TPM's plugin
directory. TPM treats an existing directory as already installed, so the
`@plugin` line above keeps working:

```bash
ln -s /path/to/tmux-pane-beacon ~/.tmux/plugins/tmux-pane-beacon
```

Reload your tmux configuration after changing any option.

## Agent status and notifications

Pane colors and terminal titles appear as soon as the plugin loads. Running and waiting indicators and completion alerts require hooks in your agent's settings.

| Display | Meaning |
|---|---|
| Each pane's border color | Identifies the pane; does not indicate task status |
| Green `●` | Working (`working`) |
| Magenta `●` | Waiting for input or approval (`waiting`) |
| Red `●` | Error (`error`) |
| `🔔` and a message | An unread alert; selecting the pane clears it |

See the [agent integration guide](docs/agents.md) for Claude Code and Codex hook examples, status limitations, and integration with your own tools.

## Options

| Option | Default | Description |
|---|---|---|
| `@pane_beacon_palette` | `196 46 203 226 201 51 208 118 215 199 214 82 192 220 165 50 202 154 223 129 190 48 210 93 197 45 213 159 87 228` | 256-color numbers assigned to panes in a cycle |
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

## Troubleshooting

- **No border labels:** check that TPM runs at the end of `~/.tmux.conf`, then reload with `tmux source-file ~/.tmux.conf`.
- **Binary download fails:** check access to GitHub. If Rust is available, run `make build` in the plugin directory and reload tmux.
- **No working/waiting indicator:** configure hooks using the [agent integration guide](docs/agents.md). Terminal titles alone do not update agent status.
- **No completion alert:** the currently active pane is not alerted. Select another pane before trying the notification.

See [how the plugin loads](docs/how-it-works.md) for the loading order and registered hooks.

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
