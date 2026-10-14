SHELL := /bin/bash
PROJECT_ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

.DEFAULT_GOAL := help
BACKEND ?= gnome-keyring
REBUILD_PREVIEWS ?= 0
RESTORE_OMARCHY ?= 0
RESET_SNAPSHOTS ?= 0
RUN_MIGRATIONS ?= 0
SCOPE ?= full

ifeq ($(filter $(REBUILD_PREVIEWS),0 1),)
$(error REBUILD_PREVIEWS must be 0 or 1)
endif

ifeq ($(filter $(RESTORE_OMARCHY),0 1),)
$(error RESTORE_OMARCHY must be 0 or 1)
endif

ifeq ($(filter $(RESET_SNAPSHOTS),0 1),)
$(error RESET_SNAPSHOTS must be 0 or 1)
endif

ifeq ($(filter $(RUN_MIGRATIONS),0 1),)
$(error RUN_MIGRATIONS must be 0 or 1)
endif

ifeq ($(BACKEND),gnome-keyring)
KEYRING_BACKEND := gnome-keyring
else
$(error BACKEND must be gnome-keyring)
endif

.PHONY: help setup keyring verify test hook icons theme zed cli herdr editors clean lang i18n-status lint

lint:
	@if ! command -v shellcheck &> /dev/null; then \
		echo "shellcheck not found. Install with: pkexec pacman -S shellcheck (or use CI)"; \
		exit 1; \
	fi
	shellcheck --severity=style \
		scripts/*.sh scripts/lib/*.sh scripts/lib/modules/*.sh \
		hooks/theme-set.d/* hooks/pre-refresh-pacman.d/* hooks/post-update.d/* \
		conf/*/*.sh \
		tests/*.sh

help:
	@bash scripts/lib/help.sh

setup:
	pkexec bash $(PROJECT_ROOT)/scripts/setup.sh --scope "$(SCOPE)" $(if $(filter 1,$(REBUILD_PREVIEWS)),--rebuild-previews) $(if $(filter 1,$(RESTORE_OMARCHY)),--restore-omarchy) $(if $(filter 1,$(RESET_SNAPSHOTS)),--reset-snapshots) $(if $(filter 1,$(RUN_MIGRATIONS)),--run-migrations)

keyring:
	bash $(PROJECT_ROOT)/scripts/keyring-switch.sh "$(KEYRING_BACKEND)"

verify:
	bash scripts/verify.sh

test:
	bash tests/run-all.sh

hook:
	@mkdir -p ~/.config/omarchy/hooks/theme-set.d ~/.config/omarchy/hooks/i18n/messages
	cp hooks/theme-set.d/* ~/.config/omarchy/hooks/theme-set.d/
	chmod +x ~/.config/omarchy/hooks/theme-set.d/*
	cp scripts/lib/i18n.sh scripts/lib/i18n-boot.sh ~/.config/omarchy/hooks/i18n/
	cp scripts/lib/messages/*.msg ~/.config/omarchy/hooks/i18n/messages/

icons:
	@bash hooks/theme-set.d/folder-color

theme:
	@bash hooks/theme-set.d/folder-color
	@bash hooks/theme-set.d/zed-theme

zed:
	bash conf/zed/install.sh

cli:
	bash conf/cli/install.sh

herdr:
	bash conf/herdr/install.sh

editors: zed cli

lang:
	@bash scripts/lib/i18n.sh --list

i18n-status:
	@bash scripts/lib/i18n.sh

clean:
	rm -f setup.log
