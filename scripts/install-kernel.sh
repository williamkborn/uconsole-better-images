#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
project=$PWD
root=${1:-$project/mnt/root}
[[ $EUID == 0 ]] || { echo 'Run with sudo'; exit 1; }
release=$(cat build/kernel-release.txt)
[[ $release == 6.12.*-uconsole* && $release != *$'\n'* ]] || exit 1
[[ -f build/kernel-install/lib/modules/$release/modules.dep ]] || exit 1
boot=$root/boot/firmware/uconsole
mkdir -p "$boot/overlays" "$root/usr/lib/modules"
rsync -a --chown=root:root --chmod=D755,F644 build/kernel-install/lib/modules/"$release" "$root/usr/lib/modules/"
# Avoid dangling absolute build-machine links in a target installation.
rm -f "$root/usr/lib/modules/$release/build" "$root/usr/lib/modules/$release/source"
cp build/kernel/arch/arm64/boot/Image.gz "$boot/kernel8.img"
cp build/kernel/arch/arm64/boot/dts/broadcom/*.dtb "$boot/"
cp build/kernel/arch/arm64/boot/dts/overlays/*.dtbo "$boot/overlays/"
cp sources/clockworkpi-linux/arch/arm/boot/dts/overlays/README "$boot/overlays/"
cp build/kernel/.config "$root/boot/config-$release"
cp build/kernel/System.map "$root/boot/System.map-$release"
cp build/kernel/arch/arm64/boot/Image.gz "$root/boot/vmlinuz-$release"
chroot "$root" depmod -a "$release"
chroot "$root" dracut --force --no-hostonly --no-hostonly-cmdline \
 --add-drivers 'vc4 panel_cwu50 ocp8178_bl axp20x_battery axp20x_ac_power' \
 "/boot/initrd.img-$release" "$release"
cp "$root/boot/initrd.img-$release" "$boot/initramfs"
cat > "$root/boot/firmware/config.txt" <<'EOF'
# Ubuntu uConsole CM4: kernel, DTBs and initramfs are one tested set.
# Stock Ubuntu kernel updates use current/ and do not replace this directory.
[all]
os_prefix=uconsole/
arm_64bit=1
kernel=kernel8.img
cmdline=cmdline.txt
initramfs initramfs followkernel
ignore_lcd=1
max_framebuffers=2
disable_overscan=1
dtparam=audio=on
dtparam=spi=on
dtparam=ant2
enable_uart=1
dtoverlay=clockworkpi-uconsole
dtoverlay=vc4-kms-v3d-pi4,cma-384
dtoverlay=audremap,pins_12_13
dtoverlay=dwc2,dr_mode=host
dtoverlay=spi0-0cs
gpio=10=ip,np
gpio=9=op,dh
EOF
printf '%s\n' 'console=serial0,115200 console=tty1 root=LABEL=writable rootfstype=ext4 rootwait fsck.repair=yes net.ifnames=0' > "$boot/cmdline.txt"
printf '%s\n' "$release" > "$root/usr/share/uconsole-kernel-release"
