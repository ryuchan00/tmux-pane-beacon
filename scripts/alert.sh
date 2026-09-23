#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/resolve-binary.sh
source "$project_root/scripts/resolve-binary.sh"
if ! pane_beacon_resolve "$project_root"; then
  printf 'tmux-pane-beacon: no usable binary; run make build in %s\n' "$project_root" >&2
  exit 1
fi
exec "$PANE_BEACON_BINARY" alert "$@"
