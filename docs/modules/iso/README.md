# ISO

The `iso` component builds a bootable image from the latest stable upstream base image. Each published image contains the complete tracked repository at `/opt/os`, a release commit marker at `/opt/os-release.txt`, and the cyan KMono icon at `/usr/share/pixmaps/os.png`. The same icon source is kept in `modules/iso/assets/kmono-cyan.png`.

The image name is `os-vX.Y.iso`. Releases use the version alone as the release heading, for example `v1.4`. GitHub Releases stores the ISO as numbered parts to stay within the per-file upload limit, alongside `os-vX.Y.iso.sha256`, `download-release.sh`, and `download-release.ps1`. Published versions are immutable; changes to a release asset require a new version.

## Download the latest image

The helper is a small Bash script. It discovers the latest release, downloads all parts and the checksum, assembles the ISO, and verifies it before writing the image and checksum to the current directory. It requires `curl`, `jq`, and `sha256sum`.

```bash
curl -fsSL https://github.com/kairosci/os/releases/latest/download/download-release.sh | bash
```

Choose an output directory by downloading and running the helper directly:

```bash
curl -fsSLo download-release.sh https://github.com/kairosci/os/releases/latest/download/download-release.sh
bash download-release.sh v1.4 /path/to/output
```

Omit the tag to select the latest release. The optional tag is useful for reproducible downloads.

## Download the latest image on Windows

The PowerShell helper discovers the latest release, downloads every ISO part and the checksum, assembles the image, and verifies SHA-256 before saving it. Windows PowerShell 5.1 or PowerShell 7 is supported.

```powershell
Invoke-WebRequest -Uri https://github.com/kairosci/os/releases/latest/download/download-release.ps1 -OutFile .\download-release.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\download-release.ps1
```

Pass `-Tag v1.4` to select a specific release or `-OutputDirectory "$HOME\Downloads"` to choose where the verified ISO and checksum are saved. The helper refuses to overwrite an ISO or checksum already present in the output directory.

## Verify image contents without installing

The ISO workflow verifies the configuration before publishing. It extracts `/opt/os` from the finished image and compares every file with the materialized repository tree at the tagged commit. It also checks the release commit marker. This verifies the bundled configuration without booting or installing the image.

You can inspect a downloaded image locally with `xorriso`. The comparison below uses the signed release tag as the source, follows repository symlinks in the same way as the ISO build, extracts the bundled configuration into a temporary directory, and compares file contents:

```bash
tag=v1.4
temporary_directory="$(mktemp -d)"
mkdir -p "$temporary_directory/source" "$temporary_directory/materialized" "$temporary_directory/image"
git archive "$tag" | tar -x -C "$temporary_directory/source"
cp -aL "$temporary_directory/source/." "$temporary_directory/materialized/"
xorriso -osirrox on -indev "os-${tag}.iso" -extract /opt/os "$temporary_directory/image/os"
diff -qr "$temporary_directory/materialized" "$temporary_directory/image/os"
```

An empty `diff` result means the repository tree in the image matches the tagged source. The workflow also compares the marker at `/opt/os-release.txt` with the commit used to build that release.

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

If a tagged build fails before publishing a release, rerun the `ISO` workflow from `main` with the existing signed tag:

```bash
gh workflow run iso.yml --ref main -f release_tag=v1.4
```

The workflow refuses to replace a published release. Publish a corrected image or helper under a new version.

## Build locally

Run `make iso` to rebuild the latest stable upstream image using `modules/iso/overlay/`. Overlay paths are relative to the image root. The default output is `os-X.Y.Z.iso` and its SHA-256 checksum. To choose another overlay and output path:

```bash
bash modules/iso/scripts/customize.sh --overlay /path/to/overlay --output /path/to/os-v1.4.iso
```

The original upstream image is cached under `${XDG_CACHE_HOME:-$HOME/.cache}/os/iso/`. Upstream source names remain in the build script only where required to locate and verify the base image.

## Boot menu

The installed system uses GRUB in text mode with cyan selection colors. The `grub-btrfs` package discovers Snapper snapshots and its daemon refreshes menu entries when snapshots change. Its mkinitcpio overlay hook allows read-only snapshots to boot with temporary writes held in memory. Recovery saves user configuration on persistent home storage, then uses Snapper rollback to make the selected snapshot the normal root. The bootloader setup supports UEFI systems with one discoverable EFI System Partition; systems with multiple EFI partitions or BIOS firmware require a separate installation path.

GRUB preloads its TPM module so firmware systems with a TPM can measure GRUB commands and loaded boot files. This setup does not reproduce Limine's hash mismatch panic or provision signed Secure Boot keys, so systems that require those controls must retain their current trusted boot path until signed GRUB artifacts are configured.
