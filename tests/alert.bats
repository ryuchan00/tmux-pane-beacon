#!/usr/bin/env bats

load test_helper

@test "clears a detached session alert when selected" {
  pane_id="$(tmux split-window -d -P -F '#{pane_id}')"

  run "$PROJECT_ROOT/scripts/alert.sh" "$pane_id" "Done"
  [ "$status" -eq 0 ]
  [ "$(tmux show-option -pqv -t "$pane_id" @pane_beacon_alert)" = "Done" ]
  [ "$(tmux show-window-option -v window-status-style)" = "fg=yellow,bold" ]

  tmux select-pane -t "$pane_id"

  [ -z "$(tmux show-option -pqv -t "$pane_id" @pane_beacon_alert)" ]
  ! tmux show-window-options | grep -q '^window-status-style '
}

@test "accepts a custom window alert style" {
  pane_id="$(tmux split-window -d -P -F '#{pane_id}')"

  run "$PROJECT_ROOT/scripts/alert.sh" "$pane_id" "Waiting" "fg=magenta,bold"
  [ "$status" -eq 0 ]
  [ "$(tmux show-window-option -v window-status-style)" = "fg=magenta,bold" ]
}

@test "fails with usage when arguments are missing" {
  run "$PROJECT_ROOT/scripts/alert.sh"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "agent update sets title and status" {
  pane_id="$(tmux split-window -d -P -F '#{pane_id}')"

  run "$PROJECT_ROOT/target/release/pane-beacon" update "$pane_id" \
    --agent codex --status working --summary "Porting to Rust"

  [ "$status" -eq 0 ]
  [ "$(tmux display-message -p -t "$pane_id" '#{pane_title}')" = "codex: Porting to Rust" ]
  [ "$(tmux show-option -pqv -t "$pane_id" @pane_beacon_status)" = "working" ]
}

@test "completed agent update raises an alert" {
  pane_id="$(tmux split-window -d -P -F '#{pane_id}')"

  run "$PROJECT_ROOT/target/release/pane-beacon" update "$pane_id" \
    --agent claude --status completed --summary "Review finished"

  [ "$status" -eq 0 ]
  [ "$(tmux show-option -pqv -t "$pane_id" @pane_beacon_alert)" = "Review finished" ]
  [ "$(tmux show-window-option -v window-status-style)" = "fg=yellow,bold" ]
}
