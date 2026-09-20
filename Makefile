.PHONY: test lint

test:
	bats tests

lint:
	shellcheck scripts/*.sh pane-beacon.tmux tests/*.bash
