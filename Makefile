SHELL := bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -O globstar -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

.PHONY: default clean test install

default:
	@echo 'no default target'

bin/cmdsync: src/cmdsync.sh
	mkdir -p bin
	cp src/cmdsync.sh bin/cmdsync
	chmod +x bin/cmdsync

test: bin/cmdsync
	cd tests
	bash test.sh
	cd -

clean:
	git clean -fdX

install: test
	mkdir -p ~/bin
	cp bin/cmdsync ~/bin/cmdsync

debian/packages: debian bin/cmdsync src/bash-completion.sh
	cd debian
	make packages
	cd -

share: src/bash-completion.sh
	mkdir -p share/bash-completion/completions
	cp src/bash-completion.sh \
		share/bash-completion/completions/cmdsync

