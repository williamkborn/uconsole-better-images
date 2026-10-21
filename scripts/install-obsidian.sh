#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
project=$PWD
root=${1:-$project/mnt/root}
[[ $EUID == 0 ]] || exit 1
archive=downloads/obsidian-1.14.4-arm64.tar.gz
echo "fc212804515713ed85fe5ef5bc4b009872bcc01847c4be4fcc14971deee2a42d  $archive" | sha256sum -c
mkdir -p "$root/opt/obsidian" "$root/usr/local/bin" "$root/usr/share/applications"
tar -xzf "$archive" --strip-components=1 -C "$root/opt/obsidian"
chown -R root:root "$root/opt/obsidian"
chmod 4755 "$root/opt/obsidian/chrome-sandbox"
rm -f "$root/usr/local/bin/obsidian"
cat > "$root/usr/local/bin/obsidian" <<'EOF_LAUNCHER'
#!/bin/sh
set -eu
python3 - <<'PY_VAULT'
import json, pathlib, time
home = pathlib.Path.home()
config = home / '.config/obsidian/obsidian.json'
vault = home / 'Documents/Obsidian Vault'
if not config.exists() and vault.is_dir():
    config.parent.mkdir(parents=True, exist_ok=True)
    config.write_text(json.dumps({'vaults': {'01b412de86f13b51': {'path': str(vault), 'ts': int(time.time()*1000), 'open': True}}}))
PY_VAULT
exec /opt/obsidian/obsidian "$@"
EOF_LAUNCHER
chmod 755 "$root/usr/local/bin/obsidian"
cat > "$root/usr/share/applications/obsidian.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Obsidian
Comment=Write and organize notes
Exec=obsidian %U
Icon=obsidian
Terminal=false
Categories=Office;
MimeType=x-scheme-handler/obsidian;
EOF
mkdir -p "$root/usr/share/icons/hicolor/256x256/apps" "$root/etc/skel/Documents/Obsidian Vault"
cp assets/obsidian.png "$root/usr/share/icons/hicolor/256x256/apps/obsidian.png"
cat > "$root/etc/skel/Documents/Obsidian Vault/README.md" <<'EOF'
Welcome to Ubuntu 26.04 on ClockworkPi uConsole CM4.

The initial local account is cpi, with initial password cpi. Change it when
first logging in. SSH is disabled; enable it if needed with:

    sudo systemctl enable --now ssh

Use the network applet for Wi-Fi and Bluetooth Manager for Bluetooth.
Fn + < / > adjusts backlight brightness. The optional 4G module can be powered
on with `sudo uconsole-4g enable` and managed with ModemManager/NetworkManager.
Firmware tools and vendor instructions are in /usr/share/uconsole.

Community: https://forum.clockworkpi.com
EOF
mkdir -p "$root/etc/skel/Desktop"
cp -a 'sources/vendor-skel/Documents/Obsidian Vault/.obsidian' "$root/etc/skel/Documents/Obsidian Vault/"
mkdir -p "$root/etc/skel/.config/obsidian"
cp sources/vendor-skel/.config/obsidian/Preferences "$root/etc/skel/.config/obsidian/Preferences"
chown -R root:root "$root/etc/skel"
cp "$root/usr/share/applications/obsidian.desktop" "$root/etc/skel/Desktop/Obsidian.desktop"
