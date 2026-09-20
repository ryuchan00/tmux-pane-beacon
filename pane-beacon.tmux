#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/helpers.sh
source "$PLUGIN_DIR/scripts/helpers.sh"

title_fallback="$(get_tmux_option @pane_beacon_title_fallback '#{pane_current_command}')"
title_max="$(get_tmux_option @pane_beacon_title_max '60')"
alert_icon="$(get_tmux_option @pane_beacon_alert_icon '🔔')"

tmux set-option -g pane-border-status top
tmux set-option -g pane-border-format "#[fg=#{@pane_beacon_color}]#{?pane_active,━━,──}[#{pane_index}] #{?@pane_beacon_alert,$alert_icon #{@pane_beacon_alert},#{?#{==:#{pane_title},#{host}},$title_fallback,#{=/$title_max/…:pane_title}}} #{?pane_active,━━━━━━━━━━━━━━━━━━━━,────────────────────}"

assign_script="$PLUGIN_DIR/scripts/assign-color.sh"
tmux set-hook -g 'after-split-window[90]' "run-shell \"$assign_script #{pane_id}\""
tmux set-hook -g 'after-new-window[90]' "run-shell \"$assign_script #{pane_id}\""
tmux set-hook -g 'after-select-pane[90]' 'set-option -p -u @pane_beacon_alert'
tmux set-hook -g 'after-select-pane[91]' 'set-option -w -u window-status-style'
tmux set-hook -g 'after-select-pane[92]' 'set-window-option pane-active-border-style "fg=#{@pane_beacon_color},bg=terminal"'

"$assign_script"
