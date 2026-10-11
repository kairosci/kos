# kos distribution

The canonical runtime is `data/rootfs`. The provisioning and release pipeline remains native Bash; imported desktop programs retain their original implementation languages. `data/runtime-packages.list` declares their runtime dependencies. Copyright and license notices are retained.

`make setup SCOPE=release` builds a pacman package and an installation ISO from the Archiso releng profile. Build work runs in a pinned Arch container when Archiso is unavailable on the host. The image contains repository configuration, never the host home directories, authentication material or application profiles. `data/default-theme` selects the release palette explicitly.

BIOS and UEFI boot checks run in disposable QEMU instances. The release workflow signs verified artifacts with Sigstore and publishes their verification bundles and checksums. `kos update` verifies the publisher identity, signed package manifest, checksums and exact package versions before installing the runtime, kernel and headers together; it does not require GitHub login.

The live medium provides `archinstall`. After installing the Arch base into mounted partitions, run `kos-install-system /mnt USER` with the account created by Archinstall. It installs the kos runtime and enables first boot provisioning. Network access is required for package provisioning. Disk partitioning, encryption and bootloader selection stay in Archinstall, where the person installing the system selects them explicitly.

The `preview` channel follows public prereleases; `stable` follows stable releases. An empty release channel is handled explicitly as no update.

The initial release is experimental until both live boot checks and installation tests complete. A successful live boot does not establish hardware compatibility or prove the installed desktop works on every device.

The migration package declarations contain previous package names solely so pacman can replace their ownership in one transaction. They are not shipped as desktop commands or provisioning configuration.
