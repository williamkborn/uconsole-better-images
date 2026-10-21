#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
project=$PWD
root=${1:-$project/mnt/root}
[[ $EUID == 0 ]] || { echo 'Run with sudo'; exit 1; }
[[ $(findmnt -n -o FSTYPE --target "$root") == ext4 ]] || exit 1
mkdir -p "$root/tmp/vendor-debs"
for pkg in libtheora0 libtheoradec1 libtheoraenc1 clockworkpi-audio devterm-backlight-rpi-cm4 devterm-wiringpi-cm4-cpi devterm-cavestory-cpi-cm4 devterm-tic80-cpi uconsole-4g-util-cm4 uconsole-dosbox-staging uconsole-love2d uconsole-liko12 uconsole-lowresnx; do
 cp downloads/vendor-debs/"${pkg}"_*.deb "$root/tmp/vendor-debs/"
done
chroot "$root" /bin/bash -c 'DEBIAN_FRONTEND=noninteractive apt-get install -y /tmp/vendor-debs/*.deb'

# The vendor unit places After in [Install], where systemd ignores it.
python3 - "$root/etc/systemd/system/uconsole-4g-cm4.service" <<'PY_UNIT'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
s = p.read_text().replace('After=NetworkManager.service', '').replace('ConditionFileExecutable=', 'ConditionFileIsExecutable=')
s = s.replace('[Unit]', '[Unit]\nAfter=NetworkManager.service')
p.write_text(s)
PY_UNIT

# Copy intentional desktop and game defaults, excluding browser caches/identity.
mkdir -p "$root/etc/skel/.config" "$root/etc/skel/.local/share" "$root/etc/skel/Desktop"
for name in xfce4 retroarch dosbox openttd; do
 cp -a "sources/vendor-skel/.config/$name" "$root/etc/skel/.config/"
done
tar -xzf assets/vendor-skel-current.tar.gz -C "$root/etc/skel"
cp -a sources/vendor-skel/.dosbox sources/vendor-skel/.opentyrian "$root/etc/skel/"
cp -a sources/vendor-skel/.local/share/com.nesbox.tic sources/vendor-skel/.local/share/nxengine "$root/etc/skel/.local/share/"
# Old image hard-codes a 480x1280 DevTerm mode. Detect the connected panel instead.
rm -f "$root/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/displays.xml"
python3 scripts/adapt-desktop.py "$root"
cp sources/vendor-skel/Desktop/Terminal.desktop "$root/etc/skel/Desktop/"
mkdir -p "$root/usr/local/bin" "$root/etc/lightdm/lightdm.conf.d" "$root/etc/xdg/autostart"
cat > "$root/usr/local/bin/uconsole-display" <<'EOF'
#!/bin/sh
set -eu
for output in $(xrandr --query | awk '/^DSI-[0-9]+ connected/ {print $1}'); do
 xrandr --output "$output" --auto --rotate right
done
EOF
chmod 755 "$root/usr/local/bin/uconsole-display"
cat > "$root/etc/lightdm/lightdm.conf.d/90-uconsole.conf" <<'EOF'
[Seat:*]
user-session=xfce
greeter-session=lightdm-gtk-greeter
display-setup-script=/usr/local/bin/uconsole-display
EOF
cat > "$root/etc/lightdm/lightdm-gtk-greeter.conf" <<'EOF'
[greeter]
background=#000000
font-name=Sans 12
EOF
cat > "$root/etc/xdg/autostart/uconsole-display.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=uConsole display
Exec=/usr/local/bin/uconsole-display
OnlyShowIn=XFCE;
EOF
cp sources/pi-gen/stage4/02-tweaks/files/etc/xdg/autostart/first-touch.desktop "$root/etc/xdg/autostart/"
sed -i '/^NotShowIn=/d' "$root/etc/xdg/autostart/first-touch.desktop"
cat > "$root/etc/xdg/autostart/xbindkeys.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=uConsole brightness keys
Exec=xbindkeys_autostart
OnlyShowIn=XFCE;
EOF
mkdir -p "$root/etc/udev/rules.d" "$root/etc/modprobe.d"
printf '%s\n' 'KERNEL=="axp20x-battery", ATTR{constant_charge_current_max}="2200000", ATTR{constant_charge_current}="2000000"' > "$root/etc/udev/rules.d/99-uconsole-charging.rules"
printf '%s\n' 'blacklist qmi_wwan' 'blacklist cdc_wdm' > "$root/etc/modprobe.d/blacklist-qmi.conf"

if [[ ${UCONSOLE_BUILD_PROFILE:-full} != release ]]; then
 tar -xzf assets/tyrian-data.tar.gz -C "$root"
fi
chroot "$root" /bin/bash -c 'DEBIAN_FRONTEND=noninteractive apt-get install -y opentyrian greybird-gtk-theme lxterminal galculator qt5ct'

# Keep keyboard/modem firmware and flashing tools available without flashing them.
mkdir -p "$root/usr/share/uconsole"
cp -a sources/uconsole/Bin "$root/usr/share/uconsole/firmware-tools"
cp sources/uconsole/Bin/uconsole_keyboard_flash/upload-reset/upload-reset.c build/upload-reset.c
patch build/upload-reset.c < patches/keyboard-reset-modern-c.patch
aarch64-linux-gnu-gcc -O2 -Wall -o "$root/usr/share/uconsole/firmware-tools/uconsole_keyboard_flash/upload-reset.elf" build/upload-reset.c
cp -a sources/uconsole/wiki "$root/usr/share/uconsole/"
printf '%s\n' 'lightdm shared/default-x-display-manager select lightdm' | chroot "$root" debconf-set-selections
printf '%s\n' /usr/sbin/lightdm > "$root/etc/X11/default-display-manager"
systemctl --root="$root" disable gdm3.service || true
systemctl --root="$root" enable --force lightdm.service
systemctl --root="$root" enable clockworkpi-audio-patch.service clockworkpi-audio-shutdown.service NetworkManager.service ModemManager.service
systemctl --root="$root" disable ssh.service ssh.socket || true
systemctl --root="$root" set-default graphical.target

chown -R root:root "$root/etc/skel" "$root/usr/share/uconsole"
