SHELL := bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -O globstar -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

.PHONY: default clean

default: packages

clean:
	# remove anything in .gitignore, including directories
	git clean -fdX

package = cmdsync
version = 1.1
release = 1
architecture = all
maintainer = Eric Johannesson <eric@ericjohannesson.com>
homepage = https://github.com/ericjohannesson/cmdsync
description = A bash-script for making the file structure of a *destination directory* identical to the file structure of a *source directory* (without changing the source), where each destination file is the result of applying a user-specified *shell command* to the corresponding source file.
depends = bash, coreutils, findutils, diffutils, grep, sed

directory = ${package}_${version}-${release}_${architecture}

define control
Package: ${package}
Version: ${version}
Maintainer: ${maintainer}
Depends: ${depends}
Architecture: ${architecture}
Homepage: ${homepage}
Description: ${description}
endef

${directory}/DEBIAN/control:
	mkdir -p ${directory}/DEBIAN
	echo "${control}" > ${directory}/DEBIAN/control

${directory}/usr/bin/cmdsync: ../bin/cmdsync
	mkdir -p ${directory}/usr/bin
	cp ../bin/cmdsync ${directory}/usr/bin/cmdsync

${directory}: ${directory}/DEBIAN/control ${directory}/usr/bin/cmdsync

packages: ${directory}
	dpkg-deb --root-owner-group --build ${directory}
	mkdir -p packages
	mv *.deb packages/
