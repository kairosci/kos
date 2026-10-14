.PHONY: debloat-slop test help

SHELL := /bin/bash

help:
	@printf '%s\n' "debloat-slop  Opt-in AI debloat (explicit request only)"
	@printf '%s\n' "test        Run integrity checks"

debloat-slop:
	sudo bash scripts/debloat-slop.sh --yes

test:
	bash tests/check.sh
