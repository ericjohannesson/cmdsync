SHELL := bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -O globstar -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

.PHONY: default clean test install uninstall

default:
	@echo 'no default target'

bin: src/cmdsync.sh
	mkdir -p bin
	cp src/cmdsync.sh bin/cmdsync
	chmod +x bin/cmdsync

test: bin
	cd tests
	bash test.sh
	cd -

clean:
	git clean -fdX

install: bin share
	mkdir -p ~/bin
	cp -f bin/* ~/bin/
	mkdir -p ~/.local/share/bash-completion/completions
	cp -f share/bash-completion/completions/* \
		~/.local/share/bash-completion/completions/

uninstall:
	rm -f ~/bin/cmdsync
	rm -f ~/.local/share/bash-completion/completions/cmdsync

debian/packages: debian bin share
	cd debian
	make packages
	cd -

share: src/bash-completion.sh
	mkdir -p share/bash-completion/completions
	cp -f src/bash-completion.sh \
		share/bash-completion/completions/cmdsync

