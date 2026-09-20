#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "${PANE_BEACON_BIN:-$project_root/target/release/pane-beacon}" alert "$@"
