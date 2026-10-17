SHELL := /bin/bash
PROJECT_ROOT := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

.DEFAULT_GOAL := help
BACKEND ?= gnome-keyring
REBUILD_PREVIEWS ?= 0
RESTORE_OMARCHY ?= 0
RESET_SNAPSHOTS ?= 0
RUN_MIGRATIONS ?= 0
SCOPE ?= full
PREVIEW_INTERFACE ?= 0

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

.PHONY: help launch run-setup entry setup keyring verify test hook icons theme zed cli herdr os changelog editors clean lang i18n-status lint iso

lint:
	@cd "$(PROJECT_ROOT)" && if ! command -v shellcheck &> /dev/null; then \
		echo "shellcheck not found. Install with: pkexec pacman -S shellcheck (or use CI)"; \
		exit 1; \
	fi
	cd "$(PROJECT_ROOT)" && shellcheck --severity=style \
		scripts/*.sh scripts/lib/*.sh scripts/lib/modules/*.sh \
		modules/theme-previews/scripts/*.sh modules/theme-previews/scripts/lib/*.sh \
		hooks/theme-set.d/* hooks/pre-refresh-pacman.d/* hooks/post-update.d/* \
		modules/conf/*/*.sh \
		modules/conf/*/scripts/*.sh \
		tests/*.sh \
		modules/clean/scripts/*.sh modules/clean/scripts/lib/modules/*.sh \
		modules/obscure/scripts/*.sh modules/obscure/scripts/lib/modules/*.sh \
		modules/slop/scripts/*.sh modules/slop/scripts/lib/modules/*.sh \
		modules/performance/scripts/*.sh modules/performance/scripts/lib/modules/*.sh \
		modules/iso/scripts/*.sh \
		script/*

help:
	@cd "$(PROJECT_ROOT)" && script/os-lua project-help

launch:
	@cd "$(PROJECT_ROOT)" && script/os-lua project-launch

run-setup:
	@cd "$(PROJECT_ROOT)" && script/os-lua project-run-setup

entry:
	@cd "$(PROJECT_ROOT)" && script/os-lua project-entry

setup:
	cd "$(PROJECT_ROOT)" && pkexec bash $(PROJECT_ROOT)/scripts/setup.sh --scope "$(SCOPE)" $(if $(filter 1,$(REBUILD_PREVIEWS)),--rebuild-previews) $(if $(filter 1,$(RESTORE_OMARCHY)),--restore-omarchy) $(if $(filter 1,$(RESET_SNAPSHOTS)),--reset-snapshots) $(if $(filter 1,$(RUN_MIGRATIONS)),--run-migrations) $(if $(filter 1,$(PREVIEW_INTERFACE)),--preview-interface)

keyring:
	cd "$(PROJECT_ROOT)" && script/os-lua project-keyring "$(KEYRING_BACKEND)"

verify:
	cd "$(PROJECT_ROOT)" && bash scripts/verify.sh

test:
	cd "$(PROJECT_ROOT)" && lua -E tests/main.lua "$(PROJECT_ROOT)" --group full

hook:
	@cd "$(PROJECT_ROOT)" && mkdir -p ~/.config/omarchy/hooks/theme-set.d ~/.config/omarchy/hooks/i18n/messages
	cd "$(PROJECT_ROOT)" && cp hooks/theme-set.d/* ~/.config/omarchy/hooks/theme-set.d/
	cd "$(PROJECT_ROOT)" && chmod +x ~/.config/omarchy/hooks/theme-set.d/*
	cd "$(PROJECT_ROOT)" && cp scripts/lib/i18n.sh scripts/lib/i18n-boot.sh ~/.config/omarchy/hooks/i18n/
	cd "$(PROJECT_ROOT)" && cp data/catalog/*.msg ~/.config/omarchy/hooks/i18n/messages/

icons:
	@cd "$(PROJECT_ROOT)" && bash hooks/theme-set.d/folder-color

theme:
	@cd "$(PROJECT_ROOT)" && bash hooks/theme-set.d/folder-color
	@cd "$(PROJECT_ROOT)" && bash hooks/theme-set.d/zed-theme

zed:
	cd "$(PROJECT_ROOT)" && bash modules/conf/zed/install.sh

cli:
	+$(MAKE) -C "$(PROJECT_ROOT)" setup SCOPE=terminal

herdr:
	+$(MAKE) -C "$(PROJECT_ROOT)" setup SCOPE=herdr

os:
	+$(MAKE) -C "$(PROJECT_ROOT)" setup SCOPE=cli

changelog:
	@cd "$(PROJECT_ROOT)" && bash $(PROJECT_ROOT)/script/os changelog

editors: zed cli

lang:
	@cd "$(PROJECT_ROOT)" && script/os-lua project-languages

i18n-status:
	@cd "$(PROJECT_ROOT)" && script/os-lua project-locale-status

iso:
	cd "$(PROJECT_ROOT)" && bash modules/iso/scripts/customize.sh

clean:
	cd "$(PROJECT_ROOT)" && rm -f setup.log
