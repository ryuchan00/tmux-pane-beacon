#!/usr/bin/env bats

load test_helper

border_text() {
  tmux display-message -p -t "$1" '#{E:pane-border-format}'
}

wait_for_command() {
  local pane_id="$1" expected="$2"

  for _ in {1..100}; do
    if [ "$(tmux display-message -p -t "$pane_id" '#{pane_current_command}')" = "$expected" ]; then
      return 0
    fi
    sleep 0.05
  done
  return 1
}

@test "working status shows the working icon" {
  pane_id="$(tmux split-window -d -P -F '#{pane_id}')"

  "$PROJECT_ROOT/scripts/pane-beacon.sh" update "$pane_id" --agent claude --status working

  [[ "$(border_text "$pane_id")" == *"#[fg=green]● "* ]]
}

@test "waiting and error use their own icons" {
  pane_id="$(tmux split-window -d -P -F '#{pane_id}')"

  "$PANE_BEACON_TEST_BIN" update "$pane_id" --status waiting
  [[ "$(border_text "$pane_id")" == *"#[fg=magenta]● "* ]]

  "$PANE_BEACON_TEST_BIN" update "$pane_id" --status error
  [[ "$(border_text "$pane_id")" == *"#[fg=red]● "* ]]
}

@test "completed status shows no icon" {
  pane_id="$(tmux split-window -d -P -F '#{pane_id}')"

  "$PANE_BEACON_TEST_BIN" update "$pane_id" --status completed

  [[ "$(border_text "$pane_id")" != *"●"* ]]
}

@test "status without a summary keeps the agent's own title" {
  pane_id="$(tmux split-window -d -P -F '#{pane_id}')"
  tmux select-pane -t "$pane_id" -T "✳ Title from the agent"

  "$PANE_BEACON_TEST_BIN" update "$pane_id" --agent claude --status working

  [ "$(tmux display-message -p -t "$pane_id" '#{pane_title}')" = "✳ Title from the agent" ]
}

@test "waiting without a summary names the agent in the alert" {
  pane_id="$(tmux split-window -d -P -F '#{pane_id}')"

  "$PANE_BEACON_TEST_BIN" update "$pane_id" --agent codex --status waiting

  [ "$(tmux show-option -pqv -t "$pane_id" @pane_beacon_alert)" = "codex: waiting for input" ]
}

@test "icon hides once the pane runs a different command" {
  # シェルは環境ごとに名前や起動の速さが違うため、コマンドを直接起動して入れ替える
  pane_id="$(tmux split-window -d -P -F '#{pane_id}' 'sleep 60')"
  wait_for_command "$pane_id" sleep
  "$PANE_BEACON_TEST_BIN" update "$pane_id" --status working
  [[ "$(border_text "$pane_id")" == *"●"* ]]

  tmux respawn-pane -k -t "$pane_id" 'cat'
  wait_for_command "$pane_id" cat
  [[ "$(border_text "$pane_id")" != *"●"* ]]
}

@test "clear removes the status icon" {
  pane_id="$(tmux split-window -d -P -F '#{pane_id}')"
  "$PANE_BEACON_TEST_BIN" update "$pane_id" --status working

  "$PANE_BEACON_TEST_BIN" clear "$pane_id"

  [[ "$(border_text "$pane_id")" != *"●"* ]]
  [ -z "$(tmux show-option -pqv -t "$pane_id" @pane_beacon_status_command)" ]
}

@test "working icon can be customized" {
  pane_id="$(tmux split-window -d -P -F '#{pane_id}')"
  tmux set-option -g @pane_beacon_working_icon '#[fg=cyan]>'
  load_plugin

  "$PANE_BEACON_TEST_BIN" update "$pane_id" --status working

  [[ "$(border_text "$pane_id")" == *"#[fg=cyan]> "* ]]
}

@test "returning to work clears the waiting alert" {
  pane_id="$(tmux split-window -d -P -F '#{pane_id}')"
  "$PANE_BEACON_TEST_BIN" update "$pane_id" --agent claude --status waiting
  [ -n "$(tmux show-option -pqv -t "$pane_id" @pane_beacon_alert)" ]

  "$PANE_BEACON_TEST_BIN" update "$pane_id" --agent claude --status working

  [ -z "$(tmux show-option -pqv -t "$pane_id" @pane_beacon_alert)" ]
}

@test "working keeps an alert raised by another tool" {
  pane_id="$(tmux split-window -d -P -F '#{pane_id}')"
  "$PROJECT_ROOT/scripts/alert.sh" "$pane_id" "build finished"

  "$PANE_BEACON_TEST_BIN" update "$pane_id" --status working

  [ "$(tmux show-option -pqv -t "$pane_id" @pane_beacon_alert)" = "build finished" ]
}
