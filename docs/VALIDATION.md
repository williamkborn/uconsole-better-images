# Validation

## First CM4 image — October 21, 2026

- Ubuntu 26.04.1 ARM64, upgraded with no pending packages, including phased updates.
- Raspberry Pi 6.12.113-uconsole+ with the full 19-file ClockworkPi kernel delta.
- 95 offline checks passed, including kernel/DTB/module consistency, firmware,
  package dependencies, system ownership, desktop settings and first-boot identity.
- Audio jack logic and modem GPIO/timing simulations passed.
- Offline ext4 and FAT checks passed after clean unmount.
- All **17,179,869,184 bytes** written to the microSD matched on readback.
- SHA256: `835748c78b4bb0a3676916ecddef5137d05cf3cb9710b98a6a6da5c1724e3e0b`.
- The owner then booted the CM4 uConsole and reported: “it works great.”

The detailed device serial, original-card inventory, local logs and build reports
are deliberately excluded from Git. The checksum identifies the original tested
image; a new build is expected to have a different checksum.

## Scope and limits

The successful hardware report confirms a native boot and satisfactory use, but
does not enumerate tests of charging, both panel revisions, Bluetooth, every game,
or the optional modem. Please record those separately when testing them.

Earlier emulated userland checks exercised Cave Story, LowRes NX, LÖVE and DOSBox.
Obsidian's payload and libraries were verified, but its Electron GUI could not be
validated reliably under QEMU. Its production launcher retains sandboxing.

The publication cleanup adds portable source/asset fetching, an explicit flash
target, build locking and repository checks. It does not modify the tested image
or reflash the owner's card. Those packaging changes are checked independently;
a new end-to-end image build has not been performed for this publication cleanup.
