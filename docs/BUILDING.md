# Building and maintaining the image

## Inputs and output

Run scripts from a clone on Ubuntu 26.04 x86-64. `install-host-dependencies.sh`
installs the ARM64 cross compiler, QEMU user emulation, filesystem utilities,
device-tree tools and build dependencies. Scripts locate the project from their
own paths, so the clone's directory name does not matter.

`sources.lock.json` pins artifact URLs and SHA256 values. `fetch-sources.sh` pins
ClockworkPi's uConsole firmware/tools, pi-gen, desktop skeleton and Linux source
revisions. The kernel starts at Raspberry Pi commit
`58b28eeef87abfb49e52591ceae6af89a29242aa`, with
`patches/clockworkpi-6.12.patch` applied using the original pre-vendor blobs for
three-way merge context. The keyboard reset patch repairs the old C utility
and lets the ARM64 cross compiler build it.

`prepare-assets.sh` extracts the icon, desktop defaults and game data from the
two pinned CM4 vendor images. `config/assets.json` verifies every regular file
and the expected relative symlink; archives themselves are not published.
The script verifies cached assets too. Remove or move a failed cache entry and
rerun rather than bypassing validation.

The output is always `../ub2604_uconsole.img`. Generated diagnostics remain in
`docs/` locally and are ignored by Git, including:

| File | Purpose |
| --- | --- |
| `installed-packages.tsv` | Exact installed package versions |
| `root-verification.json` | Offline image checks |
| `final-upgrade-check.txt` | Pending package upgrade check |
| `hardware-helper-tests.txt` | Simulated GPIO/timing checks |
| `image.sha256` | Checksum after clean unmount and filesystem checks |
| `flash-verification.txt` | Full device readback result |

Keep `downloads/ubuntu-debs/`, the base image, locks and package manifest when
archiving a build. Ubuntu repositories are refreshed, so this is not a frozen
package snapshot or a promise of bit-identical output.

## Build isolation and recovery

The top-level builder uses a private mount namespace and an exclusive build
lock. It refuses another loop attachment of its output and requires exclusive
partition access before running offline ext4/FAT checks. The build itself never
writes a physical card. Exit cleanup unmounts the build root and detaches its loop.

If interrupted, inspect the error and resume with `--resume`. If the image is
still attached or mounted, resolve that state first. Do not force filesystem
checks against a mounted image, and do not edit a script while it is running.
A fresh build is preferable when filesystem integrity is uncertain.

## Updating the custom kernel

The selected kernel, DTBs, overlays, modules and initramfs form one matching set
under `/boot/firmware/uconsole/`. Ubuntu's stock kernel packages stay updated,
but do not replace this selected set.

To update it, change the pinned Raspberry Pi revision, port the complete vendor
delta, rebuild and verify. The cleanest approach is a new clone or a fresh source
cache; the fetcher refuses unexpected pinned source revisions. Review patch
conflicts and the resulting diff, retain compressed-firmware support and AppArmor,
and run the offline checks and a native CM4 smoke test before publishing results.

## Lightweight project checks

```sh
bash scripts/check-project.sh
```

This checks script syntax, Python compilation without writing bytecode, JSON
inputs, required project files and the flash command's safe argument handling.
It does not build an image or access a physical disk. Once assets are available,
`python3 scripts/verify-assets.py` checks their contents independently.
