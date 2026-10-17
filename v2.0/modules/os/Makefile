.PHONY: setup verify test clean help

SHELL := /bin/bash

help:
	@printf '%s\n' "setup       Run full setup (root)"
	@printf '%s\n' "verify      Run verification checks"
	@printf '%s\n' "test        Run comprehensive test suites"
	@printf '%s\n' "clean       Remove setup log"

setup:
	$(MAKE) -C ../.. setup

verify:
	$(MAKE) -C ../.. verify

test:
	lua -E ../../tests/main.lua "$(abspath ../..)" --group os

clean:
	rm -f setup.log
