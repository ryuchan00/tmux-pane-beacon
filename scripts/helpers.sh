#!/usr/bin/env bash
set -euo pipefail

# 暗い背景で見分けやすい 30 色。隣り合うペインが似た色にならないよう色相を飛ばして並べてある。
# このファイルを source する側で参照するため、ここでは未使用に見える
# shellcheck disable=SC2034
PANE_BEACON_DEFAULT_PALETTE="196 46 21 226 201 51 208 118 27 199 214 82 39 220 165 50 202 154 33 129 190 48 57 93 197 45 213 159 87 228"

get_tmux_option() {
  local option_name="$1"
  local default_value="$2"
  local value

  value="$(tmux show-option -gqv "$option_name")"
  if [[ -n "$value" ]]; then
    printf '%s\n' "$value"
  else
    printf '%s\n' "$default_value"
  fi
}

palette_to_array() {
  local palette="$1"

  # 呼び出し元で参照する共有配列なので、このファイル内には参照がない。
  # shellcheck disable=SC2034
  read -r -a PANE_BEACON_PALETTE <<< "$palette"
}
