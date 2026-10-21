#!/usr/bin/env bash
# Extract third-party data locally; none of these payloads belongs in Git.
set -euo pipefail
if [[ ${UCONSOLE_PRIVATE_MOUNTS:-0} != 1 ]]; then
 exec sudo unshare --mount --propagation private env UCONSOLE_PRIVATE_MOUNTS=1 bash "$0" "$@"
fi
cd "$(dirname "$0")/.."
[[ $EUID == 0 ]] || { echo 'Run with sudo'; exit 1; }
if [[ -f assets/obsidian.png && -f assets/tyrian-data.tar.gz && -f assets/vendor-skel-current.tar.gz ]]; then
 exec python3 scripts/verify-assets.py
fi
# Verify the archives before using or unpacking their cached images.
python3 scripts/fetch-artifacts.py
old=downloads/uConsole_CM4_v0.1b_xfce_64bit.img
new=downloads/uConsole_CM4_v3.1_64bit.img
[[ -f $old ]] || 7z x -odownloads "${old}.7z"
if [[ ! -f $new ]]; then
 bzip2 -dc "${new}.bz2" > "${new}.partial"
 mv "${new}.partial" "$new"
fi
mkdir -p build assets
work=$(mktemp -d "$PWD/build/assets.XXXXXX")
loop=
cleanup() {
 if mountpoint -q "$work/root"; then umount "$work/root"; fi
 if [[ -n $loop ]]; then losetup -d "$loop"; fi
}
trap cleanup EXIT
mkdir "$work/root" "$work/output"
loop=$(losetup --find --show --read-only --partscan "$old")
mount -o ro,noload "${loop}p2" "$work/root"
cp "$work/root/opt/obsidian.png" "$work/output/obsidian.png"
tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner -czf "$work/output/tyrian-data.tar.gz" \
 -C "$work/root" usr/share/games/tyrian usr/share/doc/tyrian-data
umount "$work/root"
losetup -d "$loop"
loop=$(losetup --find --show --read-only --partscan "$new")
mount -o ro,noload "${loop}p2" "$work/root"
tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner -czf "$work/output/vendor-skel-current.tar.gz" \
 -C "$work/root/etc/skel" .config/opentyrian .config/geany .config/galculator .config/lxterminal .config/qt5ct
python3 scripts/verify-assets.py "$work/output"
cp "$work/output/"* assets/
cleanup
loop=
trap - EXIT
echo "Assets prepared. Extraction workspace: $work"
