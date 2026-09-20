#!/usr/bin/env bats

load test_helper

border_text() {
  tmux display-message -p -t "$1" '#{E:pane-border-format}'
}

@test "border includes the pane index" {
  pane_id="$(tmux display-message -p '#{pane_id}')"
  pane_index="$(tmux display-message -p '#{pane_index}')"

  [[ "$(border_text "$pane_id")" == *"[$pane_index]"* ]]
}

@test "border prioritizes alert icon and message" {
  pane_id="$(tmux display-message -p '#{pane_id}')"
  tmux set-option -p -t "$pane_id" @pane_beacon_alert "Build done"

  [[ "$(border_text "$pane_id")" == *"🔔 Build done"* ]]
}

@test "border includes an explicitly set title" {
  pane_id="$(tmux display-message -p '#{pane_id}')"
  tmux select-pane -t "$pane_id" -T "My Title"

  [[ "$(border_text "$pane_id")" == *"My Title"* ]]
}

@test "border expands fallback for a host title" {
  pane_id="$(tmux display-message -p '#{pane_id}')"
  host="$(tmux display-message -p '#{host}')"
  command="$(tmux display-message -p '#{pane_current_command}')"
  tmux select-pane -t "$pane_id" -T "$host"

  text="$(border_text "$pane_id")"
  [[ "$text" == *"$command"* ]]
}

@test "border truncates a long title at title_max" {
  pane_id="$(tmux display-message -p '#{pane_id}')"
  tmux set-option -g @pane_beacon_title_max 8
  load_plugin
  tmux select-pane -t "$pane_id" -T "A very long pane title"

  text="$(border_text "$pane_id")"
  [[ "$text" == *"…"* ]]
  [[ "$text" != *"A very long pane title"* ]]
}

@test "selected pane uses its color for the active border" {
  pane_id="$(tmux split-window -d -P -F '#{pane_id}')"
  color="$(wait_for_pane_option "$pane_id" @pane_beacon_color)"

  tmux select-pane -t "$pane_id"

  style="$(tmux display-message -p -t "$pane_id" '#{E:pane-active-border-style}')"
  [[ "$style" == *"$color"* ]]
}

@test "teardown leaves no isolated server" {
  stop_test_server

  run env TMUX= TMUX_TMPDIR="$TMUX_TEST_TMPDIR" tmux -L "$TMUX_TEST_LABEL" has-session
  [ "$status" -ne 0 ]
}
