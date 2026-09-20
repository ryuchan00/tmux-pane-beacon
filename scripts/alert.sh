#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -lt 2 ]]; then
  printf 'Usage: %s <pane_id> <message> [window-status-style]\n' "$0" >&2
  exit 1
fi

pane_id="$1"
message="$2"
style="${3:-fg=yellow,bold}"

visible="$(tmux display-message -p -t "$pane_id" '#{&&:#{session_attached},#{&&:#{window_active},#{pane_active}}}')"
if [[ "$visible" == "1" ]]; then
  exit 0
fi

window_target="$(tmux display-message -p -t "$pane_id" '#{session_name}:#{window_index}')"
tmux set-option -p -t "$pane_id" @pane_beacon_alert "$message"
tmux set-window-option -t "$window_target" window-status-style "$style"
