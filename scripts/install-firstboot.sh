#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
project=$PWD
root=${1:-$project/mnt/root}
[[ $EUID == 0 ]] || exit 1
mkdir -p "$root/usr/local/sbin" "$root/etc/systemd/system" "$root/etc/netplan" "$root/etc/cloud"
cat > "$root/usr/local/sbin/uconsole-firstboot" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
rootdev=$(readlink -f "$(findmnt -n -o SOURCE /)")
part=$(cat "/sys/class/block/$(basename "$rootdev")/partition")
parent=$(lsblk -dn -o PKNAME "$rootdev")
[[ -b /dev/$parent && $part =~ ^[0-9]+$ ]] || exit 1
result=$(growpart "/dev/$parent" "$part" 2>&1) || {
 [[ $result == *NOCHANGE:* ]] || { printf '%s\n' "$result" >&2; exit 1; }
}
resize2fs "$rootdev"
ssh-keygen -A
mkdir -p /var/lib/uconsole
touch /var/lib/uconsole/firstboot-complete
EOF
chmod 755 "$root/usr/local/sbin/uconsole-firstboot"
cat > "$root/etc/systemd/system/uconsole-firstboot.service" <<'EOF'
[Unit]
Description=Expand uConsole root filesystem and create unique host keys
After=local-fs.target
Before=display-manager.service
ConditionPathExists=!/var/lib/uconsole/firstboot-complete

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/uconsole-firstboot
RemainAfterExit=yes
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF
touch "$root/etc/cloud/cloud-init.disabled"
cat > "$root/etc/netplan/01-uconsole.yaml" <<'EOF'
network:
  version: 2
  renderer: NetworkManager
EOF
chmod 600 "$root/etc/netplan/01-uconsole.yaml"
printf '%s\n' uconsole > "$root/etc/hostname"
cat > "$root/etc/hosts" <<'EOF'
127.0.0.1 localhost
127.0.1.1 uconsole
::1 localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF
for group in gpio spi i2c; do chroot "$root" groupadd -f "$group"; done
if ! chroot "$root" id cpi >/dev/null 2>&1; then
 chroot "$root" useradd -m -s /bin/bash -G adm,sudo,dialout,audio,video,plugdev,netdev,input,render,gpio,spi,i2c cpi
 printf 'cpi:cpi\n' | chroot "$root" chpasswd
 chroot "$root" chage -d 0 cpi
fi
cp -an "$root/etc/skel/." "$root/home/cpi/"
chroot "$root" chown -R cpi:cpi /home/cpi
systemctl --root="$root" enable uconsole-firstboot.service
# Create identity at first actual boot, not on the build workstation.
rm -f "$root/etc/ssh/ssh_host_"* "$root/var/lib/systemd/random-seed"
truncate -s 0 "$root/etc/machine-id"
rm -f "$root/var/lib/dbus/machine-id"
ln -s /etc/machine-id "$root/var/lib/dbus/machine-id"

mkdir -p "$root/usr/local/bin" "$root/etc/xdg/autostart"
cat > "$root/usr/local/bin/uconsole-welcome" <<'EOF'
#!/bin/sh
set -eu
marker="$HOME/.config/uconsole-welcomed"
[ ! -f "$marker" ] || exit 0
zenity --info --title="Ubuntu on ClockworkPi uConsole" --width=600 --text='Welcome to your uConsole.

Fn + < and > adjusts display brightness. Use the panel applets for Wi-Fi, sound and Bluetooth. SSH is disabled by default.

Open Obsidian from the desktop to start writing.

Community: https://forum.clockworkpi.com'
mkdir -p "$HOME/.config"
touch "$marker"
EOF
chmod 755 "$root/usr/local/bin/uconsole-welcome"
cat > "$root/etc/xdg/autostart/uconsole-welcome.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=uConsole welcome
Exec=/usr/local/bin/uconsole-welcome
OnlyShowIn=XFCE;
EOF
