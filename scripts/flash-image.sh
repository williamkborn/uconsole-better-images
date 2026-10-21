#!/usr/bin/env bash
# Explicit target selection is mandatory. Never guess a user's SD card.
set -euo pipefail
cd "$(dirname "$0")/.."
project=$PWD
image=$project/../ub2604_uconsole.img
target=
confirmed=0
usage() {
 echo 'Usage: sudo bash scripts/flash-image.sh --device /dev/disk/by-id/DEVICE --yes [--image FILE]'
 echo 'Overwrites the selected USB/removable disk, then verifies the entire image by SHA256.'
 echo 'Unmount all target partitions first. Requires docs/image.sha256 from a successful build.'
}
while (($#)); do
 case $1 in
  --device|--image)
   (($# >= 2)) || { usage >&2; exit 2; }
   if [[ $1 == --device ]]; then target=$2; else image=$2; fi
   shift 2 ;;
  --yes) confirmed=1; shift ;;
  --help|-h) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
 esac
done
[[ -n $target && $confirmed == 1 ]] || { usage >&2; exit 2; }
[[ $EUID == 0 ]] || { echo 'Run with sudo' >&2; exit 1; }
[[ -f $image && -b $target ]] || { echo 'Image or device not found' >&2; exit 1; }
device=$(readlink -f "$target")
[[ $(lsblk -dn -o TYPE "$device") == disk ]] || { echo 'Select a whole disk' >&2; exit 1; }
[[ $(lsblk -dn -o TRAN "$device") == usb || $(lsblk -dn -o RM "$device") == 1 ]] || {
 echo 'Refusing a non-removable, non-USB disk' >&2; exit 1;
}
while read -r part; do
 if findmnt -rn -S "$part" >/dev/null; then
  echo "Unmount $part before flashing" >&2; exit 1
 fi
done < <(lsblk -lnpo NAME "$device")
python3 - "$device" <<'PY'
import os, sys
fd = os.open(sys.argv[1], os.O_RDONLY | os.O_EXCL)
os.close(fd)
PY
size=$(stat -c %s "$image")
(( $(blockdev --getsize64 "$device") >= size )) || { echo 'Device too small' >&2; exit 1; }
expected=$(cut -d' ' -f1 docs/image.sha256)
[[ $expected =~ ^[0-9a-f]{64}$ ]] || exit 1
[[ $(sha256sum "$image" | cut -d' ' -f1) == "$expected" ]] || { echo 'Image checksum mismatch' >&2; exit 1; }
[[ -z $(losetup -j "$image") ]] || { echo 'Detach image loop devices first' >&2; exit 1; }
lsblk -o NAME,SIZE,MODEL,TRAN,MOUNTPOINTS "$device"
[[ $(readlink -f "$target") == "$device" ]] || { echo 'Target identity changed' >&2; exit 1; }
dd if="$image" of="$device" bs=16M conv=fsync status=progress
sync
blockdev --flushbufs "$device"
actual=$(head -c "$size" "$device" | sha256sum | cut -d' ' -f1)
[[ $actual == "$expected" ]] || { echo 'Readback mismatch' >&2; exit 1; }
printf 'Image: %s\nDevice: %s\nBytes verified: %s\nSHA256: %s\nVerified UTC: %s\n' \
 "$image" "$target" "$size" "$actual" "$(date -u --iso-8601=seconds)" | tee docs/flash-verification.txt
blockdev --rereadpt "$device"
