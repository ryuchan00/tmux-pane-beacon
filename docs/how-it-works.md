[Back to README](../README.md)

# How tmux loads the plugin

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
