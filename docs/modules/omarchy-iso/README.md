# Omarchy Custom ISO

The `omarchy-iso` module rebuilds the latest stable Omarchy ISO with this repository's complete, tracked configuration tree embedded at `/opt/os-custom`. The result is a bootable Omarchy installer carrying the OS configuration and setup tools.

## Create a release

After the change is merged, create and push a signed version tag from the current `main` commit:

```bash
git switch main
git pull --rebase origin main
git tag -s omarchy-custom-v1.0.0 -m "Omarchy Custom 1.0.0"
git push origin omarchy-custom-v1.0.0
```

The `Omarchy Custom ISO` GitHub Actions workflow validates the tag, downloads and verifies the latest stable upstream Omarchy ISO, overlays the repository at `/opt/os-custom`, rebuilds the image, and publishes a GitHub release with the ISO and its SHA-256 checksum. The custom release version identifies this repository configuration. The upstream Omarchy version appears in the ISO filename and release notes.

## Install the configuration

Boot the released ISO and complete the native Omarchy installation. The installed desktop starts with the stock Omarchy configuration. The complete OS configuration is available on the live ISO at `/opt/os-custom`; copy that directory to persistent storage before rebooting, then run `make setup` from the copied directory after installation. Setup applies the repository's system and desktop configuration through its privileged provisioning pipeline.

The overlay contains only tracked repository files. It does not contain user credentials, private keys, or machine-specific installation answers. Keep those out of the repository and configure them through Omarchy's normal installer.

## Build locally

Add files to `modules/omarchy-iso/overlay/` to override or add paths in the upstream ISO. Paths are relative to the ISO root. For example, `overlay/boot/grub/grub.cfg` replaces `/boot/grub/grub.cfg`.

Run `make iso-customize` to build with the default overlay, or choose a different overlay and output path:

```bash
bash modules/omarchy-iso/scripts/customize.sh --overlay /path/to/overlay --output /path/to/omarchy-custom.iso
```

The original ISO is cached under `${XDG_CACHE_HOME:-$HOME/.cache}/os/omarchy-iso/`. A SHA-256 checksum is written beside the rebuilt ISO. The upstream signature does not cover the modified image.
