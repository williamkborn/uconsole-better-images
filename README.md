# uConsole Better Images

An Ubuntu **26.04.1 ARM64** image builder for the **ClockworkPi uConsole CM4**,
with Xfce and the vendor's display, backlight, power, audio, keyboard and modem
customizations. The custom Raspberry Pi **6.12.113-uconsole+** kernel carries
all 19 files of the vendor kernel delta, including the newer 0x39 panel revision.

**Hardware status:** the first image was successfully booted on a CM4 uConsole,
and its owner reported that it works great on October 21, 2026. This is a user
smoke-test report, not a claim that every optional peripheral was tested.
See [validation](docs/VALIDATION.md) and the [customization audit](docs/CUSTOMIZATION-AUDIT.md).

## Automated releases

Push a version tag such as `v2026.10.21`, or run **Build and release CM4 image**
from the Actions tab with an existing tag. The workflow builds and verifies the
image, then publishes compressed image assets, checksums, matching kernel source
and build reports to GitHub Releases. See [release instructions](docs/RELEASING.md).
Public release images omit Tyrian's proprietary game data; local full builds
retain it. Hardware and desktop customizations are included in both profiles.

## Build

Use an Ubuntu 26.04 x86-64 host with root access. Allow at least **50 GiB free**
for downloads, source trees, kernel outputs and images. Package configuration
runs through ARM64 emulation and can take considerable time.

```sh
git clone https://github.com/williamkborn/uconsole-better-images.git
cd uconsole-better-images
sudo bash scripts/install-host-dependencies.sh
sudo bash scripts/build-image.sh
```

The output is `../ub2604_uconsole.img`, a 16 GiB image. The build fetches pinned
upstream sources and assets automatically; no sibling checkout is required.
It refreshes Ubuntu packages from the release, updates and security repositories.

An existing output is never overwritten automatically. Move it aside for a fresh
build, or use `sudo bash scripts/build-image.sh --resume` after an interruption.
Read [the build guide](docs/BUILDING.md) before changing kernel revisions or inputs.

## Flash

Choose the **whole USB/removable disk**, unmount its partitions, and use its
stable `/dev/disk/by-id/` path. This command overwrites that disk:

```sh
lsblk -o NAME,SIZE,MODEL,TRAN,MOUNTPOINTS
sudo bash scripts/flash-image.sh --device /dev/disk/by-id/YOUR_CARD --yes
```

The script requires the checksum from a successful local build, rejects mounted
devices and attached image loops, checks capacity, writes and flushes the image,
and verifies all 16 GiB by readback SHA256. It has no default device.

## First boot

- Log in as **cpi / cpi** and change the password when prompted. No autologin.
- The root filesystem expands to fill the card. Machine identity and SSH host
  keys are generated locally; SSH stays disabled. Enable it if desired with
  `sudo systemctl enable --now ssh`.
- Use the panel applets for Wi-Fi, audio and Bluetooth. Fn + `<` / `>` controls
  brightness, and the selected brightness is remembered.
- Power the optional modem with `sudo uconsole-4g enable` or `disable`.
  NetworkManager and ModemManager handle connections.
- Obsidian includes the vendor's writing-vault settings. The vendor games,
  controls and desktop defaults are preserved.
- Firmware tools and instructions are installed under `/usr/share/uconsole`.
  Keyboard and modem firmware updates are manual.

## What is published

This repository contains build scripts, source locks, patches, asset hashes and
documentation. Downloaded operating systems, proprietary applications, game data,
local card backups, generated reports and build outputs stay outside Git.
The release workflow publishes the release-profile image separately as assets.
Third-party assets are extracted locally from hash-pinned vendor images.
See [third-party sources and terms](docs/THIRD-PARTY.md) before redistributing an image.

The procedure is repeatable, but images are **not byte-for-byte reproducible**:
Ubuntu updates, filesystem metadata and password salts vary between builds.
The custom kernel is pinned separately from Ubuntu package updates.

[Build guide](docs/BUILDING.md) · [Hardware audit](docs/CUSTOMIZATION-AUDIT.md) ·
[Validation](docs/VALIDATION.md) · [Lessons learned](docs/LESSONS.md)
