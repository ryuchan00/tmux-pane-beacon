#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
get_tmux_option() {
  local value
  value="$(tmux show-option -gqv "$1")"
  printf '%s\n' "${value:-$2}"
}

title_fallback="$(get_tmux_option @pane_beacon_title_fallback '#{pane_current_command}')"
title_max="$(get_tmux_option @pane_beacon_title_max '60')"
alert_icon="$(get_tmux_option @pane_beacon_alert_icon '🔔')"
working_icon="$(get_tmux_option @pane_beacon_working_icon '#[fg=green]●')"
waiting_icon="$(get_tmux_option @pane_beacon_waiting_icon '#[fg=magenta]●')"
error_icon="$(get_tmux_option @pane_beacon_error_icon '#[fg=red]●')"

# hook が送った状態の記号。送ったときと同じコマンドがまだ前面にいるときだけ出す。
# Stop hook が来ずにエージェントが終わっても、シェルに戻れば記号が消える
status_icon="#{?#{&&:#{@pane_beacon_status},#{==:#{pane_current_command},#{@pane_beacon_status_command}}},#{?#{==:#{@pane_beacon_status},working},$working_icon ,#{?#{==:#{@pane_beacon_status},waiting},$waiting_icon ,#{?#{==:#{@pane_beacon_status},error},$error_icon ,}}}#[fg=#{@pane_beacon_color}],}"

# shellcheck source=scripts/resolve-binary.sh
source "$PLUGIN_DIR/scripts/resolve-binary.sh"
if ! pane_beacon_resolve "$PLUGIN_DIR"; then
  printf 'tmux-pane-beacon: no usable binary; run make build in %s\n' "$PLUGIN_DIR" >&2
  exit 1
fi
binary="$PANE_BEACON_BINARY"

tmux set-option -g pane-border-status top
tmux set-option -g pane-border-format "#[fg=#{@pane_beacon_color}]#{?pane_active,━━,──}[#{pane_index}] $status_icon#{?@pane_beacon_alert,$alert_icon #{@pane_beacon_alert},#{?#{==:#{pane_title},#{host}},$title_fallback,#{=/$title_max/…:pane_title}}} #{?pane_active,━━━━━━━━━━━━━━━━━━━━,────────────────────}"

tmux set-hook -g 'after-split-window[90]' "run-shell \"$binary assign-color #{pane_id}\""
tmux set-hook -g 'after-new-window[90]' "run-shell \"$binary assign-color #{pane_id}\""
tmux set-hook -g 'after-select-pane[90]' 'set-option -p -u @pane_beacon_alert'
tmux set-hook -g 'after-select-pane[91]' 'set-option -w -u window-status-style'
tmux set-hook -g 'after-select-pane[92]' 'set-window-option pane-active-border-style "fg=#{@pane_beacon_color},bg=terminal"'

"$binary" init
