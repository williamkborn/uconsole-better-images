# Lessons from the CM4 port

- **Isolate mounts.** Host service and snap namespaces can retain hidden writable
  image mounts after the visible build root is unmounted. A second loop attachment
  is unsafe. Build in a private namespace, reject duplicate attachments and require
  exclusive partition access before offline checks. The first affected output was
  quarantined; the delivered image was rebuilt from the official base.
- **Treat boot files as one set.** Kernel, DTBs, overlays, modules and initramfs must
  match. Keep the custom set separate from Ubuntu's stock kernel update directory.
- **Enable compressed firmware.** Ubuntu's Wi-Fi/Bluetooth firmware uses XZ or
  Zstandard compression; the vendor kernel defaults did not enable both loaders.
- **Install system files as root.** Cross-build output ownership must not leak into
  modules, the desktop skeleton or system payloads.
- **Adapt desktop behavior.** Remove the inherited DevTerm 480x1280 mode, select the
  panel's preferred mode and rotate DSI-1/DSI-2 with `xrandr --rotate right`.
  Keep readable fonts and a black background. Select LightDM explicitly because
  recommended dependencies can otherwise select GDM.
- **Fix integration errors.** The vendor brightness autostart excluded Xfce.
  The modem unit put ordering in `[Install]` and used an invalid condition name.
- **Check GPIO numbering.** Vendor WiringPi uses BCM mode on CM4, so its pins 24/15
  correspond to the newer pinctrl scripts. Preserve the modem's original timings.
- **Check binary ABI dependencies.** Vendor LÖVE needs the older Theora ABI;
  separately pinned compatibility packages can coexist with Ubuntu's new ABI.
  The supplied keyboard reset executable was x86-64 and needed an ARM64 rebuild.
- **Preserve intent, not account state.** Keep desktop settings, controls and
  writing defaults; exclude cookies, SSH keys, cached sessions and machine identity.
- **Distinguish validation levels.** Offline checks and emulated application tests
  complement a native boot report. They cannot prove all hardware behavior.
