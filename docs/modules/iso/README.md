# ISO

The `iso` component builds a bootable image from the latest stable upstream base image. Each published image contains the complete tracked repository at `/opt/os` and the cyan KMono icon at `/usr/share/pixmaps/os.png`. The same icon source is kept in `modules/iso/assets/kmono-cyan.png`.

The image name is `os-vX.Y.iso`. Releases use the version alone as the release heading, for example `v1.4`. GitHub Releases stores the ISO as numbered parts to stay within the per-file upload limit, alongside `os-vX.Y.iso.sha256`, `download-release.sh`, and `download-release.ps1`. Published versions are immutable; changes to a release asset require a new version.

## Download the latest image

The helper is a small Bash script. It discovers the latest release, downloads all parts and the checksum, assembles the ISO, and verifies it before writing the image and checksum to the current directory. It requires `curl`, `jq`, and `sha256sum`.

Temporary downloads are stored in a private directory inside the output directory, avoiding RAM-backed `/tmp`. Parts are appended to the staged ISO and removed one at a time, so allow free space for the complete ISO plus one release part. Temporary files are removed when the helper exits.

```bash
curl -fsSL https://github.com/kairosci/os/releases/latest/download/download-release.sh | bash
```

The ISO and checksum are always saved in the current working directory, even when the helper script is stored elsewhere. To choose a destination, change directory before running it:

```bash
cd /path/to/output
curl -fsSL https://github.com/kairosci/os/releases/latest/download/download-release.sh | bash -s -- v1.6
```

Omit the tag to select the latest release. The optional tag is useful for reproducible downloads.

## Download the latest image on Windows

The PowerShell helper discovers the latest release, downloads every ISO part and the checksum, assembles the image, and verifies SHA-256 before saving it. Windows PowerShell 5.1 or PowerShell 7 is supported.

```powershell
Invoke-WebRequest -Uri https://github.com/kairosci/os/releases/latest/download/download-release.ps1 -OutFile .\download-release.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\download-release.ps1
```

Pass `-Tag v1.6` to select a specific release. The verified ISO, checksum and temporary downloads are saved in the current working directory; change directory before running the helper to choose a destination. The helper refuses to overwrite an ISO or checksum already present in that directory.

## Verify image contents in CI

The ISO workflow verifies the configuration in a dedicated job before publishing. The verify job downloads the built image artifact and runs `modules/iso/scripts/verify-iso.sh`, which extracts `/opt/os` from the finished image and compares every file with the materialized repository tree at the tagged commit. The expected commit must match the tagged commit, so a verification failure blocks the release. This verifies the bundled configuration without booting or installing the image.

Image content verification runs only in the dedicated CI job. A passing run means the repository tree in the image matches the tagged source. Local setup and download commands do not inspect the bundled configuration; download helpers retain SHA-256 integrity verification.

## Apply the configuration

The complete tracked repository is stored at `/opt/os` in the ISO filesystem. The current build adds files to that filesystem; it does not rebuild the compressed live root or arrange for the installer to copy the configuration into the installed system. Mount the ISO or installation medium, copy its `opt/os` directory to persistent storage, and run `make setup` from that copy after installation. The setup pipeline applies the repository configuration and preserves the supported base desktop runtime.

The image is rebuilt from an upstream installer image. Its upstream checksum is verified before modification, but the upstream signature does not cover the rebuilt image. Verify downloaded release files with the included SHA-256 checksum.

## Publish a release

Create and push a signed `vX.Y-rc.N` tag from a reviewed, merged commit for a prerelease candidate. GitHub Actions builds the image and publishes assets to the prerelease with that exact heading. Create and push a signed `vX.Y` tag on the same commit for a stable release; the workflow reuses the newest signed prerelease candidate on that commit without rebuilding and publishes it under the new stable heading:

```bash
git switch main
git pull --rebase origin main
git tag -s v1.7-rc.1
git push origin v1.7-rc.1
```

If a tagged build fails before publishing a release, rerun the `ISO` workflow from `main` with the existing signed tag:

```bash
gh workflow run iso.yml --ref main -f release_tag=v1.7-rc.1
```

The workflow refuses to replace a published release. Publish a corrected image or helper under a new version. Download helpers accept both stable and prerelease tags.

## Build locally

Run `make iso` to rebuild the latest stable upstream image using `modules/iso/overlay/`. Overlay paths are relative to the image root. The default output is `os-X.Y.Z.iso` and its SHA-256 checksum. To choose another overlay and output path:

```bash
bash modules/iso/scripts/customize.sh --overlay /path/to/overlay --output /path/to/os-v1.4.iso
```

The original upstream image and temporary build downloads are stored under `${XDG_CACHE_HOME:-$HOME/.cache}/os/iso/`. Upstream source names remain in the build script only where required to locate and verify the base image.

## Boot menu

The installed system uses GRUB in text mode with cyan selection colors. The `grub-btrfs` package discovers Snapper snapshots and its daemon refreshes menu entries when snapshots change. Its mkinitcpio overlay hook allows read-only snapshots to boot with temporary writes held in memory. Recovery saves user configuration on persistent home storage, then uses Snapper rollback to make the selected snapshot the normal root. The bootloader setup supports UEFI systems with one discoverable EFI System Partition; systems with multiple EFI partitions or BIOS firmware require a separate installation path.

GRUB preloads its TPM module so firmware systems with a TPM can measure GRUB commands and loaded boot files. This setup does not reproduce Limine's hash mismatch panic or provision signed Secure Boot keys, so systems that require those controls must retain their current trusted boot path until signed GRUB artifacts are configured.
