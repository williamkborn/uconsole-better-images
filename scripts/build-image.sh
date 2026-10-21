#!/usr/bin/env bash
# Build only. Flashing is a separate, explicitly targeted operation.
set -euo pipefail
if [[ $EUID != 0 ]]; then
 exec sudo --preserve-env=JOBS,UCONSOLE_BUILD_PROFILE bash "$0" "$@"
fi
export UCONSOLE_BUILD_PROFILE=${UCONSOLE_BUILD_PROFILE:-full}
[[ $UCONSOLE_BUILD_PROFILE == full || $UCONSOLE_BUILD_PROFILE == release ]] || exit 2
if [[ ${UCONSOLE_PRIVATE_MOUNTS:-0} != 1 ]]; then
 exec unshare --mount --propagation private env UCONSOLE_PRIVATE_MOUNTS=1 bash "$0" "$@"
fi
cd "$(dirname "$0")/.."
project=$PWD
image=$project/../ub2604_uconsole.img
root=$project/mnt/root
mkdir -p build docs
exec 9>build/image-build.lock
flock -n 9 || { echo "Another build is running" >&2; exit 1; }
[[ $EUID == 0 ]] || { echo 'Run with sudo'; exit 1; }
[[ ${1:-} == '' || ${1:-} == --resume ]] || exit 2
if mountpoint -q "$root"; then
 echo "Build root already mounted: $root. Finish or unmount the existing build first." >&2
 exit 1
fi
if [[ -e $image && ${1:-} != --resume ]]; then
 echo 'Image exists. Use --resume to continue, or move it aside for a fresh build.' >&2
 exit 1
fi
if [[ -n $(losetup -j "$image") ]]; then
 echo 'Image is still attached to a loop device; refusing duplicate attachment.' >&2
 exit 1
fi
rm -f docs/image.sha256 docs/flash-verification.txt
bash scripts/fetch-sources.sh
bash scripts/build-kernel.sh
if [[ ! -e $image ]]; then
 cp --reflink=auto --sparse=always downloads/ubuntu-26.04.1-preinstalled-server-arm64+raspi.img "$image"
 truncate -s 16G "$image"
fi
loop=$(losetup --find --show --partscan "$image")
cleanup() {
 sync
 if mountpoint -q "$root"; then umount -R "$root" || return; fi
 losetup -d "$loop"
}
trap cleanup EXIT
growpart "$loop" 2 || [[ ${1:-} == --resume ]]
e2fsck -pf "${loop}p2" || [[ $? == 1 ]]
resize2fs "${loop}p2"
mkdir -p "$root"
mount "${loop}p2" "$root"
printf '%s\n' "$UCONSOLE_BUILD_PROFILE" > "$root/etc/uconsole-build-profile"
mkdir -p "$root/boot/firmware"
mount "${loop}p1" "$root/boot/firmware"
mount --rbind /dev "$root/dev"
mount --make-rslave "$root/dev"
mount -t proc proc "$root/proc"
mount -t sysfs sysfs "$root/sys"
cp --remove-destination /etc/resolv.conf "$root/etc/resolv.conf"
printf '#!/bin/sh\nexit 101\n' > "$root/usr/sbin/policy-rc.d"
chmod 755 "$root/usr/sbin/policy-rc.d"
sed -i 's/^Suites: resolute$/Suites: resolute resolute-updates/' "$root/etc/apt/sources.list.d/ubuntu.sources"
if [[ -d downloads/ubuntu-debs ]]; then
 cp -an downloads/ubuntu-debs/*.deb "$root/var/cache/apt/archives/" 2>/dev/null || true
fi
cp scripts/provision-root.sh "$root/tmp/provision-root.sh"
chroot "$root" bash /tmp/provision-root.sh
bash scripts/install-customizations.sh "$root"
bash scripts/install-obsidian.sh "$root"
bash scripts/install-firstboot.sh "$root"
bash scripts/install-kernel.sh "$root"
bash scripts/finalize-root.sh "$root"
sync
umount -R "$root"
python3 - "$loop" <<'PY'
import os, sys
for suffix in ('p1', 'p2'):
    fd = os.open(sys.argv[1] + suffix, os.O_RDONLY | os.O_EXCL)
    os.close(fd)
PY
e2fsck -f -n "${loop}p2"
fsck.vfat -n "${loop}p1"
losetup -d "$loop"
trap - EXIT
sha256sum "$image" > docs/image.sha256
echo 'Image built and checked. Use scripts/flash-image.sh with an explicit target device.'
