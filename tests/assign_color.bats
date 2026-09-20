#!/usr/bin/env bats

load test_helper

@test "assigns distinct colors to all panes" {
  tmux split-window -d
  tmux split-window -d
  tmux split-window -d

  run "$PROJECT_ROOT/scripts/assign-color.sh"
  [ "$status" -eq 0 ]

  colors=()
  while IFS= read -r color; do
    colors+=("$color")
  done < <(tmux list-panes -a -F '#{@pane_beacon_color}')
  [ "${#colors[@]}" -eq 4 ]
  [ "$(printf '%s\n' "${colors[@]}" | sort -u | wc -l | tr -d ' ')" -eq 4 ]
}

@test "cycles back to the first palette color" {
  tmux set-option -g @pane_beacon_palette "10 20"
  load_plugin
  # split-window は新ペインを現在ペインの直後に挿入するので、list-panes の並びは作成順と一致しない。
  # 作成順に色が循環することを確かめるため、pane_id を控えて id ごとに検証する
  first_pane="$(tmux display-message -p '#{pane_id}')"
  second_pane="$(tmux split-window -d -P -F '#{pane_id}')"
  third_pane="$(tmux split-window -d -P -F '#{pane_id}')"

  first="$(wait_for_pane_option "$first_pane" @pane_beacon_color)"
  second="$(wait_for_pane_option "$second_pane" @pane_beacon_color)"
  third="$(wait_for_pane_option "$third_pane" @pane_beacon_color)"

  [ "$first" = "colour10" ]
  [ "$second" = "colour20" ]
  [ "$third" = "$first" ]
}

@test "reload applies a changed palette to all panes" {
  tmux split-window -d
  tmux set-option -g @pane_beacon_palette "10 20"

  run load_plugin
  [ "$status" -eq 0 ]

  colors=()
  while IFS= read -r color; do
    colors+=("$color")
  done < <(tmux list-panes -F '#{@pane_beacon_color}')
  [ "${colors[0]}" = "colour10" ]
  [ "${colors[1]}" = "colour20" ]
}

@test "split-window hook colors the new pane" {
  pane_id="$(tmux split-window -d -P -F '#{pane_id}')"

  color="$(wait_for_pane_option "$pane_id" @pane_beacon_color)"
  [[ "$color" == colour* ]]
}
