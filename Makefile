SHELL := bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -O globstar -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

.PHONY: default clean test install

default:
	@echo 'no default target'

bin/cmd-sync: src/cmd-sync.sh
	mkdir -p bin
	cp src/cmd-sync.sh bin/cmd-sync
	chmod +x bin/cmd-sync

test: bin/cmd-sync
	cd tests
	bash test.sh
	cd -

clean:
	git clean -fdX

install: test
	mkdir -p ~/bin
	cp bin/cmd-sync ~/bin/cmd-sync

debian/packages: debian test
	cd debian
	make packages
	cd -
