.PHONY: build test lint

build:
	cargo build --release

test: build
	cargo test
	bats tests

lint:
	cargo fmt --check
	cargo clippy --all-targets -- -D warnings
	shellcheck scripts/*.sh pane-beacon.tmux tests/*.bash
