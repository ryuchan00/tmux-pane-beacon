#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/helpers.sh
source "$SCRIPT_DIR/helpers.sh"

assign_color() {
  local pane_id="$1"
  local next color window_target

  next="$(tmux show-option -gqv @pane_beacon_next)"
  if [[ ! "$next" =~ ^[0-9]+$ ]]; then
    next=0
  fi

  next=$((next % ${#PANE_BEACON_PALETTE[@]}))
  color="colour${PANE_BEACON_PALETTE[$next]}"
  tmux set-option -p -t "$pane_id" @pane_beacon_color "$color"
  tmux set-option -g @pane_beacon_next "$(((next + 1) % ${#PANE_BEACON_PALETTE[@]}))"

  if [[ "$(tmux display-message -p -t "$pane_id" '#{pane_active}')" == "1" ]]; then
    window_target="$(tmux display-message -p -t "$pane_id" '#{session_name}:#{window_index}')"
    tmux set-window-option -t "$window_target" pane-active-border-style "fg=$color,bg=terminal"
  fi
}

palette_to_array "$(get_tmux_option @pane_beacon_palette "$PANE_BEACON_DEFAULT_PALETTE")"

if [[ "$#" -gt 0 ]]; then
  assign_color "$1"
  exit 0
fi

tmux set-option -g @pane_beacon_next 0
while IFS= read -r pane_id; do
  assign_color "$pane_id"
done < <(tmux list-panes -a -F '#{pane_id}')
