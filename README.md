# tmux-pane-beacon

Give every tmux pane its own color, and print the pane index and title on the
top border in that color. Coding agents can publish a concise task summary and
status to their pane. External tools can also raise an alert on a background
pane; the alert clears automatically when you select that pane. Core commands
are implemented in Rust.

![Four panes, each with its own border color. Pane 3 shows an alert instead of its title.](docs/screenshot.png)

Panes 0-2 show their titles; pane 3 has an alert raised on it, so it shows
`🔔 deploy finished` and its window is highlighted until you select it.

## Requirements

- tmux 3.0 or later (the plugin uses per-pane options, `set-option -p`, and
  indexed hooks)
- Rust 1.85 or later
- bash (TPM entry point only)

Verified on tmux 3.7b (macOS) and tmux 3.2a (Ubuntu on WSL).

## Install

With [TPM](https://github.com/tmux-plugins/tpm), add this line to `~/.tmux.conf`
and press `prefix + I`:

```tmux
set -g @plugin 'ryuchan00/tmux-pane-beacon'
```

TPM clones the source. Build the native binary once, then reload tmux:

```bash
cd ~/.tmux/plugins/tmux-pane-beacon
make build
tmux source-file ~/.tmux.conf
```

CI builds native artifacts for Intel and Arm Linux and macOS.

To hack on the plugin locally, symlink your working copy into TPM's plugin
directory. TPM treats an existing directory as already installed, so the
`@plugin` line above keeps working:

```bash
ln -s /path/to/tmux-pane-beacon ~/.tmux/plugins/tmux-pane-beacon
```

Reload your tmux configuration after changing any option.

## Options

| Option | Default | Description |
|---|---|---|
| `@pane_beacon_palette` | `196 46 21 226 201 51 208 118 27 199 214 82 39 220 165 50 202 154 33 129 190 48 57 93 197 45 213 159 87 228` | 256-color numbers assigned to panes in a cycle |
| `@pane_beacon_title_fallback` | `#{pane_current_command}` | Format shown when the pane title is still the host name |
| `@pane_beacon_title_max` | `60` | Maximum title width; longer titles are truncated with `…` |
| `@pane_beacon_alert_icon` | `🔔` | Symbol printed in front of an alert |

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

Agents and hooks can update the pane title with a short summary and publish a
machine-readable status:

```bash
~/.tmux/plugins/tmux-pane-beacon/target/release/pane-beacon update "$TMUX_PANE" \
  --agent codex --status working --summary "Porting the plugin to Rust"
```

Supported statuses are `working`, `waiting`, `completed`, and `error`.
`waiting`, `completed`, and `error` also raise an alert when the pane is not
currently visible. Use `clear <pane_id>` to remove its status and alert.

## Note

`pane-active-border-style` is overridden per window so the active pane's own
color shows up immediately. A global setting of that option therefore does not
apply to the active pane's border.

## Tests

Rust unit tests and behavior tests run against an isolated tmux server; the
remaining shell entry points are checked statically. Requires bats-core and
shellcheck.

```bash
make test
make lint
```

## License

MIT. See [LICENSE](LICENSE).

日本語版は [README.ja.md](README.ja.md) を参照してください。
