# os command

The os command mirrors the complete Omarchy command surface while hardening the behavior around delegation. It resolves the Omarchy runtime path and restores the session bus context before forwarding, and it fails visibly when the runtime is absent or when delegation reports an error.

## Index

This guide covers purpose and delegation and changelog reading and installation and verification.

## Purpose and delegation

The dispatcher lives in the module binary directory and is installed to the system executable path through the privileged pipeline. When invoked with a group and an action it forwards the full argument vector to the native Omarchy entrypoint after preparing the environment, so every upstream group keeps working without a duplicated implementation. The help request prints usage guidance, the version request reports the installed versions, and the commands request exposes discovery including validation. Session handling only fills the runtime directory and the message bus address when they are missing and when the current user owns a live runtime, which keeps graphical commands reachable across privilege boundaries without touching service state.

## Changelog reading

The changelog request reads the repository changelog as its single source and prints the matching release narrative in prose. When no release tag is supplied it prints the whole file, and when a tag is supplied it prints that release section. A missing file or an unknown tag produces a visible diagnostic instead of an empty result, which keeps the history honest on installed systems.

## Installation

The setup stage installs the dispatcher to the system executable path and publishes the changelog beside it under the shared system directory, then reconciles a per user copy inside every existing home. Repeated runs converge because installation overwrites managed paths with fixed permissions and ownership while leaving unrelated user content untouched.

## Verification

The module suite checks dispatcher syntax and strict mode and failure handling without suppression, then exercises delegation against a stub runtime and changelog extraction against a fixture file. It also asserts that the tracked changelog keeps its narrative shape with one section per release and without list markers.
