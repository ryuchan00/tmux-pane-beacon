#!/usr/bin/env bash
# pane-beacon バイナリの在りかを解決する。無ければ GitHub Releases から取得する。
# pane-beacon.tmux と scripts/alert.sh の両方から source される。
# 解決順: $PANE_BEACON_BIN → bin/pane-beacon (Releases から取得したもの)
#         → target/release/pane-beacon (開発中の cargo build 成果物) → ダウンロード

PANE_BEACON_REPO="${PANE_BEACON_REPO:-ryuchan00/tmux-pane-beacon}"

pane_beacon_target() {
  local os arch
  os="$(uname -s)"
  arch="$(uname -m)"

  case "$os/$arch" in
    Linux/x86_64) printf 'x86_64-unknown-linux-gnu' ;;
    Linux/aarch64 | Linux/arm64) printf 'aarch64-unknown-linux-gnu' ;;
    Darwin/x86_64) printf 'x86_64-apple-darwin' ;;
    Darwin/arm64) printf 'aarch64-apple-darwin' ;;
    *) return 1 ;;
  esac
}

pane_beacon_version() {
  local dir="$1"
  # Cargo.toml の version をそのままタグ名に使う (v0.2.0 形式)
  sed -n 's/^version = "\(.*\)"/\1/p' "$dir/Cargo.toml" | head -1
}

pane_beacon_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | cut -d' ' -f1
  else
    return 1
  fi
}

# Releases からバイナリを取得し、SHA256SUMS と突き合わせてから配置する
pane_beacon_download() {
  local dir="$1" dest="$2" target version base tmp expected actual

  target="$(pane_beacon_target)" || {
    printf 'tmux-pane-beacon: unsupported platform %s/%s; build from source with make build\n' "$(uname -s)" "$(uname -m)" >&2
    return 1
  }
  version="$(pane_beacon_version "$dir")"
  [ -n "$version" ] || return 1

  command -v curl >/dev/null 2>&1 || {
    printf 'tmux-pane-beacon: curl not found; build from source with make build\n' >&2
    return 1
  }

  base="https://github.com/$PANE_BEACON_REPO/releases/download/v$version"
  tmp="$(mktemp -d)" || return 1

  if ! curl -fsSL "$base/pane-beacon-$target" -o "$tmp/pane-beacon"; then
    printf 'tmux-pane-beacon: failed to download %s/pane-beacon-%s\n' "$base" "$target" >&2
    rm -rf "$tmp"
    return 1
  fi

  # チェックサムは取得できたときだけ検証する。ネットワーク経由の取り違えを弾くのが目的
  if curl -fsSL "$base/SHA256SUMS" -o "$tmp/SHA256SUMS" 2>/dev/null; then
    expected="$(awk -v name="pane-beacon-$target" '$2 == name || $2 == "*"name {print $1}' "$tmp/SHA256SUMS" | head -1)"
    actual="$(pane_beacon_sha256 "$tmp/pane-beacon")" || actual=''
    if [ -n "$expected" ] && [ -n "$actual" ] && [ "$expected" != "$actual" ]; then
      printf 'tmux-pane-beacon: checksum mismatch for pane-beacon-%s\n' "$target" >&2
      rm -rf "$tmp"
      return 1
    fi
  fi

  chmod +x "$tmp/pane-beacon"
  mkdir -p "$(dirname "$dest")"
  mv "$tmp/pane-beacon" "$dest"
  rm -rf "$tmp"
}

# 解決したパスを PANE_BEACON_BINARY に入れる。呼び出し元で参照する共有変数なので、
# このファイル内には参照がない
# shellcheck disable=SC2034
pane_beacon_resolve() {
  local dir="$1" candidate

  if [ -n "${PANE_BEACON_BIN:-}" ] && [ -x "${PANE_BEACON_BIN}" ]; then
    PANE_BEACON_BINARY="$PANE_BEACON_BIN"
    return 0
  fi

  for candidate in "$dir/bin/pane-beacon" "$dir/target/release/pane-beacon"; do
    if [ -x "$candidate" ]; then
      PANE_BEACON_BINARY="$candidate"
      return 0
    fi
  done

  if pane_beacon_download "$dir" "$dir/bin/pane-beacon"; then
    PANE_BEACON_BINARY="$dir/bin/pane-beacon"
    return 0
  fi

  return 1
}
