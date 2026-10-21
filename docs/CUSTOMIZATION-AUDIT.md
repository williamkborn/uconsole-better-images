# CM4 customization audit

The owner reports successful native CM4 boot and use; see [validation](VALIDATION.md).
Detailed file inventories and diagnostic logs mentioned below are local build
artifacts, excluded from Git.

Scope: both CM4 images linked by the supplied uConsole README (v0.1b and
v3.1), the local CM4 patch sets, current pi-gen, and firmware/tools in Bin.
A06 and R01 use different CPU architectures; their board drivers cannot run
on CM4. CM5-only boot entries likewise do not change CM4 functionality.

The downloaded images both pass the README's published MD5, and their SHA256
values are pinned in `sources.lock.json`. Read-only filesystem inventories
are `old-custom-files.json` and `vendor-custom-files.json`. These identify
vendor packages, files changed from dpkg's hashes and unowned configuration.
Generated distro configuration and account state are candidates for review,
not automatically hardware customizations.

| Vendor modification | Ubuntu implementation/disposition | Evidence / physical-test limit |
|---|---|---|
| AXP221/223 PMIC, battery, charging, regulators and power key | Full vendor kernel delta applied to 6.12.113 | Kernel built; config/module ABI and DT checks pass; physical power/battery test remains |
| CWU50 display, including 0x39 revision | Full vendor panel driver carried forward | Driver built; matching overlay and offline DT merge verified; physical panel test remains |
| OCP8178 backlight and GPIO9 boot pull-up | Vendor driver, overlay and explicit config.txt | Installed driver/overlay and GPIO9 directive verified |
| GPIO10 jack detection/GPIO11 speaker enable and shutdown mute | clockworkpi-audio 1.1 plus Ubuntu pinctrl | Installed helper simulations and service checks pass; physical audio test remains |
| PWM audio on pins 12/13 | audremap overlay | Required installed boot directives verified; physical peripherals untested |
| USB host, UART, SPI and external antenna | Vendor CM4 config and overlay | Required installed boot directives verified; physical peripherals untested |
| 2.2A max / 2A battery charging udev rule | Same rule as v3.1/pi-gen | Installed vendor rule/config preserved and reviewed |
| Modem power helper, service and GUI | uconsole-4g-util-cm4 0.2 | BCM pins 24/15 confirmed by vendor disassembly; dependencies and simulated sequence pass |
| qmi_wwan/cdc_wdm blacklist | Preserve vendor's serial/PPP modem configuration | Installed vendor rule/config preserved and reviewed |
| Brightness hotkeys and persistence | rpi-backlight 0.2, xbindkeys and first-touch autostart | XFCE exclusion removed; one xbindkeys autostart; physical brightness untested |
| Landscape DSI-1/DSI-2 | Xrandr right rotation before greeter and at Xfce login | Preferred panel mode and right rotation installed; Xrandr present; physical display untested |
| Large desktop, black background, compact panel/keybindings | Vendor Xfce skeleton adapted for Ubuntu | Vendor settings adapted, XML parsed, referenced apps installed |
| Game controls/configuration | Vendor skeleton and game packages | Dependencies resolve; Cave Story reached main loop with dummy audio; LowRes NX opened under Xvfb |
| Cave Story, TIC-80, DOSBox Staging, LÖVE, LIKO-12, LowRes NX | Hash-pinned vendor packages | Pinned packages installed; ELF libraries resolve; LÖVE and DOSBox version commands pass |
| Obsidian and writing setup in v0.1b | Current ARM64 Obsidian 1.14.4, preserved intentional vault/settings | Official ARM64 bytes and dependencies verified; vault settings preserved. QEMU cannot validate Electron GUI/sandbox; native launch untested |
| Keyboard and modem firmware flashing utilities | Local Bin payload plus wiki under /usr/share/uconsole | x86 reset helper rebuilt for ARM64; usage path executed; hardware flashing intentionally manual |
| First-boot welcome, user, SSH off | Ubuntu-specific first-boot setup | Installed scripts/services inspected and enabled; execution on first physical boot remains |
| Root partition expansion | Ubuntu-compatible growpart/resize2fs service | Installed scripts/services inspected and enabled; execution on first physical boot remains |

## Findings requiring adaptations

- The old Xfce skeleton uses a 480x1280 mode inherited from DevTerm. uConsole
  has a 720x1280 panel; select the panel's preferred mode and rotate it.
- v3.1's X11 script incorrectly uses `xrandr --transform 270`, a Wayland-style
  rotation argument. Xrandr needs `--rotate right` for the intended 270-degree
  orientation. Do not preserve a nonfunctional command verbatim.
- The v3.1 brightness sync autostart excludes XFCE. Remove that exclusion in
  the Ubuntu Xfce image, or persistence will silently fail.
- Ubuntu 26.04 replaces policykit-1 with polkitd. LÖVE's vendor binary needs
  `libtheoradec.so.1`, whereas Ubuntu's current Theora provides ABI 2. The
  current Debian stable compatibility packages (1.2.0~alpha1+dfsg-6), with
  distinct SONAMEs, are pinned separately; no Debian apt repository is added
  to the Ubuntu rootfs. Recheck stable/security metadata when updating them.
- Obsidian cookies, machine identity, SSH keys, cached desktop sessions and
  vendor account secrets are not reusable customizations. Preserve intended
  settings and documents rather than copying entire old home directories.
- Raspberry Pi desktop-specific piwiz/labwc integration is replaced by the
  corresponding Xfce/Ubuntu first-boot and desktop behavior. Preserve the
  hardware behavior and intentional UI settings across this adaptation.

The installed-image checks are recorded in `root-verification.json`, with package
versions in `installed-packages.tsv`, helper simulations in
`hardware-helper-tests.txt`, and clean-build/filesystem output in
`../logs/clean-resume.log`. These establish software coverage, not physical
hardware validation. Native boot has since been reported successful by the owner; individual
peripheral tests remain unenumerated.

## GPIO numbering evidence

The vendor WiringPi library is not using its usual wiringPi pin mapping on
Compute Modules. Its `wiringPiSetup` detects models 6, 10, 16 and 20 and sets
`wiringPiMode=1` (BCM); the vendor header identifies CM4 as model 20. See
`wiringpi-setup-disassembly.txt` around addresses 0x6808–0x682c. Thus the old
script's `gpio ... 24/15` and current `pinctrl ... 24/15` address the same
BCM lines. Preserve the vendor's power sequence and timings.


## Build isolation lesson

Host mount propagation can retain hidden writable image mounts in service or
snap namespaces after the visible build mount is unmounted. A second loop
attachment can then expose the same filesystem concurrently. The original
resume output was quarantined, and the delivered image rebuilt from the base
inside a private mount namespace. The builder refuses duplicate attachments
and requires exclusive partition opens before offline filesystem checks.

Kernel patch replay against the pinned pristine Raspberry Pi base matches the
built source index tree exactly; see `kernel-patch-replay.txt`. A fresh fetch
includes the pre-vendor parent blobs required by Git three-way application.
