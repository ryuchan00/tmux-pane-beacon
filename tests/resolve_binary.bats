#!/usr/bin/env bats
# tmux を使わず、バイナリの解決順だけを検証する。ネットワークには出ない

PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
  unset PANE_BEACON_BIN
  # Debian の bats 1.2 には BATS_TEST_TMPDIR が無いため自前で作る
  BATS_TEST_TMPDIR="$(mktemp -d)"
  plugin="$BATS_TEST_TMPDIR/plugin"
  mkdir -p "$plugin/bin" "$plugin/target/release" "$BATS_TEST_TMPDIR/path"
  printf 'version = "1.2.3"\n' > "$plugin/Cargo.toml"

  # curl と wget をどちらも失敗させ、ダウンロードできない状況を作る。
  # 取得を試みたかどうかは attempted ファイルの有無で確かめる
  for tool in curl wget; do
    printf '#!/bin/sh\ntouch "%s/attempted"\nexit 22\n' "$BATS_TEST_TMPDIR" > "$BATS_TEST_TMPDIR/path/$tool"
    chmod +x "$BATS_TEST_TMPDIR/path/$tool"
  done
  PATH="$BATS_TEST_TMPDIR/path:$PATH"

  # shellcheck source=scripts/resolve-binary.sh
  source "$PROJECT_ROOT/scripts/resolve-binary.sh"
}

teardown() {
  rm -rf "$BATS_TEST_TMPDIR"
}

fake_binary() {
  printf '#!/bin/sh\necho "pane-beacon %s"\n' "$2" > "$1"
  chmod +x "$1"
}

@test "uses a downloaded binary that matches Cargo.toml" {
  fake_binary "$plugin/bin/pane-beacon" 1.2.3
  fake_binary "$plugin/target/release/pane-beacon" 9.9.9

  pane_beacon_resolve "$plugin"
  [ "$PANE_BEACON_BINARY" = "$plugin/bin/pane-beacon" ]
}

@test "prefers a local build over a stale downloaded binary" {
  fake_binary "$plugin/bin/pane-beacon" 1.0.0
  fake_binary "$plugin/target/release/pane-beacon" 1.2.3

  pane_beacon_resolve "$plugin"
  [ "$PANE_BEACON_BINARY" = "$plugin/target/release/pane-beacon" ]
}

@test "tries to download instead of using a stale local build" {
  fake_binary "$plugin/target/release/pane-beacon" 1.0.0

  run pane_beacon_resolve "$plugin"
  [ -e "$BATS_TEST_TMPDIR/attempted" ]
  [ "$status" -eq 0 ]
  [[ "$output" == *"pane-beacon 1.0.0, which does not match v1.2.3"* ]]
}

@test "does not download when a local build matches" {
  fake_binary "$plugin/target/release/pane-beacon" 1.2.3

  pane_beacon_resolve "$plugin"
  [ "$PANE_BEACON_BINARY" = "$plugin/target/release/pane-beacon" ]
  [ ! -e "$BATS_TEST_TMPDIR/attempted" ]
}

@test "keeps a stale binary when the download fails" {
  fake_binary "$plugin/bin/pane-beacon" 1.0.0

  run pane_beacon_resolve "$plugin"
  [ "$status" -eq 0 ]
  [[ "$output" == *"does not match v1.2.3"* ]]
}

@test "fails with a hint when nothing is available" {
  run pane_beacon_resolve "$plugin"
  [ "$status" -eq 1 ]
  [[ "$output" == *"v1.2.3"* ]]
}

@test "PANE_BEACON_BIN overrides everything" {
  fake_binary "$plugin/bin/pane-beacon" 1.2.3
  fake_binary "$BATS_TEST_TMPDIR/custom" 0.0.1

  PANE_BEACON_BIN="$BATS_TEST_TMPDIR/custom" pane_beacon_resolve "$plugin"
  [ "$PANE_BEACON_BINARY" = "$BATS_TEST_TMPDIR/custom" ]
}
