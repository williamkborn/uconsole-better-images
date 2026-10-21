# Third-party sources and redistribution

This repository publishes build tooling and patches, not downloadable disk images
or bundled applications. It does not grant rights to third-party payloads.

| Component | Source / handling |
| --- | --- |
| Ubuntu ARM64 image and packages | Canonical release and Ubuntu repositories; archive hashes pinned in `sources.lock.json` |
| Raspberry Pi Linux | `raspberrypi/linux`; kernel licensing and file-specific notices apply |
| ClockworkPi kernel changes | `cuu/ClockworkPi-linux`; complete vendor delta retained as a patch |
| Firmware, keyboard utilities, documentation | Pinned `clockworkpi/uConsole` checkout, fetched during the build |
| Desktop skeleton and integration | Pinned `cuu/skel` and `cuu/pi-gen` checkouts |
| Vendor packages | Hash-pinned packages from `clockworkpi/apt` |
| Theora compatibility libraries | Hash-pinned Debian stable packages; no Debian repository added to Ubuntu |
| Obsidian | Official ARM64 release; application and icon obtained locally, not committed |
| Tyrian game data | Extracted locally from the pinned older vendor image; not committed |

The bundled Tyrian data notice explicitly says the generated package contains
proprietary game data and must not be redistributed. Other applications, games,
firmware and branding have their own terms. Review the payloads' notices before
sharing a built image; do not assume a build recipe licenses its output.

Upstream copyright and license notices remain in fetched sources and installed
packages. Kernel and keyboard patches remain subject to the licensing of their
upstream files. No blanket license is asserted over third-party material or the
complete generated image.
