---
name: system-debloat-cleanup
description: >-
  Procedures for removing default Omarchy web application shortcuts, package cleanup, and pacman configuration pinning.
---

# System Debloat Cleanup

## Overview
This skill outlines how to remove default web application launchers, uninstall unwanted packages, and prevent their automatic reinstallation on Arch Linux Omarchy installations.

## Desktop Launcher Cleanup
Web application desktop shortcuts installed under `/usr/share/omarchy/applications` and user desktop menus are cleaned by removing launcher definitions for Basecamp, Google Contacts, Google Maps, Google Messages, Google Photos, Discord, HEY, WhatsApp, X, YouTube, and Zoom.

## Package Removal and Replacement
Unneeded software packages including Chromium, Brave, Zathura, Thunar and its extensions, the retired GNOME applications (Totem, Evince, Eog, Yaru icon theme, Sushi with gtksourceview4 and gst-plugin-gtk), the KDE stack (Dolphin, Okular, Gwenview, xdg-desktop-portal-kde, plasma-integration, breeze, breeze-gtk, Haruna), system-config-printer, Kdenlive, OBS Studio, LibreOffice, Obsidian, Micro, imv, MuPDF, gdu and btop are cleanly removed from the package database. Provision one user-facing application per function: Brave Origin, Nautilus with GVFS, Zed, OnlyOffice, Papers, Loupe, Celluloid, Baobab and Resources. Keep mpv as Celluloid's dependency with its separate launcher hidden; preserve personal configurations of retired tools. GTK handles file and application selection while Hyprland handles screen capture. The container runtime is podman; docker is never provisioned.

## Pacman Persistence
Keep `/etc/pacman.conf` free of `IgnorePkg` entries so `pacman -Syu`, `omarchy update`, and `omarchy refresh pacman` (which rewrites `pacman.conf` from the Omarchy template) flow without held packages. Removed packages stay absent because pacman only upgrades installed packages and the `omarchy` package does not depend on them. The setup pipeline deletes any stale `IgnorePkg` lines and removes `/etc/pacman.d/omaconf/ignore-pkgs.list`, and verification asserts that no `IgnorePkg` entry exists.
