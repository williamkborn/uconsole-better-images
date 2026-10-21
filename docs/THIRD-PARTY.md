# Third-party sources and redistribution

The Git tree contains build tooling and patches. The release workflow can publish
separate disk-image assets using the release profile described in
[RELEASING.md](RELEASING.md). It does not grant rights to third-party payloads.

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
| Tyrian game data | Extracted for local full builds; omitted from public release images |

The bundled Tyrian data notice explicitly says the generated package contains
proprietary game data and must not be redistributed. The release profile excludes
that data, and the release verifier and packager require the exclusion. Other applications, games,
firmware and branding have their own terms. Review the payloads' notices before
sharing a built image; do not assume a build recipe licenses its output.

Upstream copyright and license notices remain in fetched sources and installed
packages. Kernel and keyboard patches remain subject to the licensing of their
upstream files. No blanket license is asserted over third-party material or the
complete generated image.
