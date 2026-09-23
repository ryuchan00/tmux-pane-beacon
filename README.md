# tmux-pane-beacon

[![CI](https://github.com/ryuchan00/tmux-pane-beacon/actions/workflows/ci.yml/badge.svg)](https://github.com/ryuchan00/tmux-pane-beacon/actions/workflows/ci.yml)
[![release](https://github.com/ryuchan00/tmux-pane-beacon/actions/workflows/release.yml/badge.svg)](https://github.com/ryuchan00/tmux-pane-beacon/releases/latest)

Give every tmux pane its own color, and print the pane index and title on the
top border in that color. Coding agents can publish a concise task summary and
status to their pane. External tools can also raise an alert on a background
pane; the alert clears automatically when you select that pane. Core commands
are implemented in Rust.

![Six stacked panes running coding agents, each with its own border color and task summary. One pane shows an alert instead.](docs/screenshot.png)

Six panes, each running a coding agent. Every pane has its own color, and its
border shows the task summary that agent published, so you can tell at a glance
which session is doing what. Pane 2 has an alert on it, so it shows the alert
instead of its summary. Completion, waiting, and error alerts remain visible
until you select the pane.

## Requirements

- tmux 3.0 or later (the plugin uses per-pane options, `set-option -p`, and
  indexed hooks)
- bash and curl (the TPM entry point and the binary download)
- Rust 1.85 or later, only if you build from source instead of using a release

Verified on tmux 3.7b (macOS) and tmux 3.2a (Ubuntu on WSL).

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

TPM follows the default branch. To pin a version instead, append the tag:

```tmux
set -g @plugin 'ryuchan00/tmux-pane-beacon#v0.2.2'
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
~/.tmux/plugins/tmux-pane-beacon/bin/pane-beacon update "$TMUX_PANE" \
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
