#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMUX_TEST_LABEL="pane-beacon-test"
# CI ではリリースと同じ静的リンク版を PANE_BEACON_BIN で渡して検証する
PANE_BEACON_TEST_BIN="${PANE_BEACON_BIN:-$PROJECT_ROOT/target/release/pane-beacon}"
export PANE_BEACON_TEST_BIN
# ソケットのパスは 104 バイト程度までしか使えず、macOS の長い TMPDIR
# (/var/folders/.../T/) の下では作れない。短い /tmp を使い、macOS で /tmp が
# /private/tmp への symlink である点は pwd -P で解決して、tmux が返す
# socket_path と一致させる
TMUX_TEST_TMPDIR="$(cd /tmp && pwd -P)/tpb-tests-$(id -u)"
export TMUX_TEST_TMPDIR
export TMUX_TMPDIR="$TMUX_TEST_TMPDIR"

start_test_server() {
  mkdir -p "$TMUX_TEST_TMPDIR"
  TMUX='' tmux -L "$TMUX_TEST_LABEL" kill-server 2>/dev/null || true
  TMUX='' tmux -L "$TMUX_TEST_LABEL" -f /dev/null new-session -d -x 200 -y 50

  local socket_path
  socket_path="$(TMUX='' tmux -L "$TMUX_TEST_LABEL" display-message -p '#{socket_path}')"
  export TMUX="${socket_path},0,0"
}

stop_test_server() {
  TMUX='' tmux -L "$TMUX_TEST_LABEL" kill-server 2>/dev/null || true
  unset TMUX
  # kill-server 直後はソケットが残ることがあり rmdir では消せないため、テスト専用ディレクトリごと消す
  rm -rf "$TMUX_TEST_TMPDIR"
}

load_plugin() {
  "$PROJECT_ROOT/pane-beacon.tmux"
}

wait_for_pane_option() {
  local pane_id="$1"
  local option="$2"
  local value

  for _ in {1..100}; do
    value="$(tmux show-option -pqv -t "$pane_id" "$option")"
    if [[ -n "$value" ]]; then
      printf '%s\n' "$value"
      return 0
    fi
    sleep 0.02
  done

  return 1
}

setup() {
  start_test_server
  load_plugin
}

teardown() {
  stop_test_server
}
