#!/usr/bin/env bash
# エージェントの hook から呼ぶ入口。バイナリの置き場所 (bin/ か target/release/ か)
# を呼び出し側が知らなくてよいように、解決してから引数をそのまま渡す
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/resolve-binary.sh
source "$project_root/scripts/resolve-binary.sh"
if ! pane_beacon_resolve "$project_root"; then
  printf 'tmux-pane-beacon: no usable binary; run make build in %s\n' "$project_root" >&2
  exit 1
fi
exec "$PANE_BEACON_BINARY" "$@"
