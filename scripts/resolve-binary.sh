#!/usr/bin/env bash
# pane-beacon バイナリの在りかを解決する。無ければ GitHub Releases から取得する。
# pane-beacon.tmux と scripts/alert.sh の両方から source される。
# 解決順: $PANE_BEACON_BIN → bin/pane-beacon → target/release/pane-beacon
#         (開発中の cargo build 成果物) → ダウンロード。bin と target は
#         Cargo.toml と同じ版のときだけ使い、版が古いものは取得に失敗したときの
#         予備に回す

PANE_BEACON_REPO="${PANE_BEACON_REPO:-ryuchan00/tmux-pane-beacon}"

# 試す順にターゲット名を並べて返す。Linux は musl (静的リンク) を優先し、
# musl 版を持たない古いリリース向けに gnu も候補に残す
pane_beacon_targets() {
  local os arch
  os="$(uname -s)"
  arch="$(uname -m)"

  case "$os/$arch" in
    Linux/x86_64) printf 'x86_64-unknown-linux-musl x86_64-unknown-linux-gnu' ;;
    Linux/aarch64 | Linux/arm64) printf 'aarch64-unknown-linux-musl aarch64-unknown-linux-gnu' ;;
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

# curl が無い最小構成の Debian でも取得できるよう wget にフォールバックする
pane_beacon_fetch() {
  local url="$1" dest="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --connect-timeout 10 --retry 2 "$url" -o "$dest"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -T 10 -t 3 -O "$dest" "$url"
  else
    return 127
  fi
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
  local dir="$1" dest="$2" targets target candidate version base tmp expected actual

  targets="$(pane_beacon_targets)" || {
    printf 'tmux-pane-beacon: unsupported platform %s/%s; build from source with make build\n' "$(uname -s)" "$(uname -m)" >&2
    return 1
  }
  version="$(pane_beacon_version "$dir")"
  [ -n "$version" ] || return 1

  if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    printf 'tmux-pane-beacon: neither curl nor wget found; build from source with make build\n' >&2
    return 1
  fi

  base="https://github.com/$PANE_BEACON_REPO/releases/download/v$version"
  tmp="$(mktemp -d)" || return 1

  target=''
  for candidate in $targets; do
    if pane_beacon_fetch "$base/pane-beacon-$candidate" "$tmp/pane-beacon" 2>/dev/null; then
      target="$candidate"
      break
    fi
  done
  if [ -z "$target" ]; then
    # main が次の版へ進み、リリースのビルドがまだ終わっていない間もここに来る
    printf 'tmux-pane-beacon: failed to download a binary for v%s from %s (the release may not be published yet)\n' "$version" "$base" >&2
    rm -rf "$tmp"
    return 1
  fi

  # チェックサムは取得できたときだけ検証する。ネットワーク経由の取り違えを弾くのが目的
  if pane_beacon_fetch "$base/SHA256SUMS" "$tmp/SHA256SUMS" 2>/dev/null; then
    expected="$(awk -v name="pane-beacon-$target" '$2 == name || $2 == "*"name {print $1}' "$tmp/SHA256SUMS" | head -1)"
    actual="$(pane_beacon_sha256 "$tmp/pane-beacon")" || actual=''
    if [ -n "$expected" ] && [ -n "$actual" ] && [ "$expected" != "$actual" ]; then
      printf 'tmux-pane-beacon: checksum mismatch for pane-beacon-%s\n' "$target" >&2
      rm -rf "$tmp"
      return 1
    fi
  fi

  chmod +x "$tmp/pane-beacon"
  # 動的リンクの不一致(GLIBC_x.yz not found など)はここで弾く。置いてから
  # 気付くと、以降ずっと壊れたバイナリを使い続けることになる
  if ! "$tmp/pane-beacon" --version >/dev/null 2>&1; then
    printf 'tmux-pane-beacon: downloaded binary does not run here; build from source with make build\n' >&2
    rm -rf "$tmp"
    return 1
  fi
  mkdir -p "$(dirname "$dest")"
  mv "$tmp/pane-beacon" "$dest"
  rm -rf "$tmp"
}

# 解決したパスを PANE_BEACON_BINARY に入れる。呼び出し元で参照する共有変数なので、
# このファイル内には参照がない
# shellcheck disable=SC2034
pane_beacon_resolve() {
  local dir="$1" bin="$1/bin/pane-beacon" version candidate

  if [ -n "${PANE_BEACON_BIN:-}" ] && [ -x "${PANE_BEACON_BIN}" ]; then
    PANE_BEACON_BINARY="$PANE_BEACON_BIN"
    return 0
  fi

  # TPM の更新 (prefix + U) はスクリプトだけを新しくするため、手元のバイナリは
  # Cargo.toml の版と一致するときだけ使う。以前 make test などでビルドした
  # target/release の成果物も、版がずれていれば同じく古いものとして扱う
  version="$(pane_beacon_version "$dir")"
  for candidate in "$bin" "$dir/target/release/pane-beacon"; do
    if [ -x "$candidate" ] && [ "$("$candidate" --version 2>/dev/null)" = "pane-beacon $version" ]; then
      PANE_BEACON_BINARY="$candidate"
      return 0
    fi
  done

  if pane_beacon_download "$dir" "$bin"; then
    PANE_BEACON_BINARY="$bin"
    return 0
  fi

  for candidate in "$bin" "$dir/target/release/pane-beacon"; do
    if [ -x "$candidate" ] && "$candidate" --version >/dev/null 2>&1; then
      printf 'tmux-pane-beacon: using %s, which does not match v%s\n' "$("$candidate" --version)" "$version" >&2
      PANE_BEACON_BINARY="$candidate"
      return 0
    fi
  done

  return 1
}
