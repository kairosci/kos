# ISO

The `iso` component builds a bootable image from the latest stable upstream base image. Each published image contains the complete tracked repository at `/opt/os`, a release commit marker at `/opt/os-release.txt`, and the cyan KMono icon at `/usr/share/pixmaps/os.png`. The same icon source is kept in `modules/iso/assets/kmono-cyan.png`.

The image name is `os-vX.Y.iso`. Releases use the version alone as the release heading, for example `v1.0`. GitHub Releases stores the ISO as numbered parts to stay within the per-file upload limit, alongside `os-vX.Y.iso.sha256` and the `download-release.sh` helper.

## Download the latest image

The helper is a small Bash script. It discovers the latest release, downloads all parts and the checksum, assembles the ISO, and verifies it before writing the image and checksum to the current directory. It requires `curl`, `jq`, and `sha256sum`.

```bash
curl -fsSL https://github.com/kairosci/os/releases/latest/download/download-release.sh | bash
```

Choose an output directory by downloading and running the helper directly:

```bash
curl -fsSLo download-release.sh https://github.com/kairosci/os/releases/latest/download/download-release.sh
bash download-release.sh v1.0 /path/to/output
```

Omit the tag to select the latest release. The optional tag is useful for reproducible downloads.

## Apply the configuration

The complete tracked repository is available on the live image at `/opt/os`. The image does not silently provision or overwrite an installed system. After installation, copy `/opt/os` to persistent storage and run `make setup` from that copy. The setup pipeline applies the repository configuration and preserves the supported base desktop runtime.

The image is rebuilt from an upstream installer image. Its upstream checksum is verified before modification, but the upstream signature does not cover the rebuilt image. Verify downloaded release files with the included SHA-256 checksum.

## Publish a release

Create and push a signed `vX.Y` tag from a reviewed, merged commit. GitHub Actions builds the image and publishes assets to the release with that exact heading:

```bash
git switch main
git pull --rebase origin main
git tag -s v1.0
git push origin v1.0
```

If a tagged build fails before publishing, rerun the `ISO` workflow from `main` with the existing tag:

```bash
gh workflow run iso.yml --ref main -f release_tag=v1.0
```

## Build locally

Run `make iso` to rebuild the latest stable upstream image using `modules/iso/overlay/`. Overlay paths are relative to the image root. The default output is `os-X.Y.Z.iso` and its SHA-256 checksum. To choose another overlay and output path:

```bash
bash modules/iso/scripts/customize.sh --overlay /path/to/overlay --output /path/to/os-v1.0.iso
```

The original upstream image is cached under `${XDG_CACHE_HOME:-$HOME/.cache}/os/iso/`. Upstream source names remain in the build script only where required to locate and verify the base image.

## Boot menu

The current installed system uses Limine for snapshot entries and recovery. systemd-boot provides a simple text menu and its documented configuration has no graphical theme settings ([systemd-boot documentation](https://systemd.io/BOOT/)). Replacing the bootloader would also require replacing the project's snapshot synchronization and recovery path. Keep the current boot path until that migration can preserve and verify those recovery behaviors; do not advertise a full systemd-boot theme as supported.
