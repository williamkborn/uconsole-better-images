#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
project=$PWD
root=${1:-$project/mnt/root}
[[ $EUID == 0 ]] || exit 1
# Keep downloaded package inputs and the exact resulting version inventory.
mkdir -p downloads/ubuntu-debs docs "$root/usr/share/uconsole/build"
cp -an "$root/var/cache/apt/archives/"*.deb downloads/ubuntu-debs/ 2>/dev/null || true
chroot "$root" dpkg-query -W -f='${binary:Package}\t${Version}\t${Architecture}\n' > docs/installed-packages.tsv
chroot "$root" apt-get -s -o APT::Get::Always-Include-Phased-Updates=true full-upgrade > docs/final-upgrade-check.txt
if grep -Eq '^(Inst|Remv) ' docs/final-upgrade-check.txt; then
 echo 'Pending package updates/removals remain; resolve before finalization.' >&2
 exit 1
fi
python3 scripts/verify-root.py "$root"
python3 scripts/check-hardware-helpers.py "$root" > docs/hardware-helper-tests.txt
cp sources.lock.json docs/installed-packages.tsv docs/root-verification.json "$root/usr/share/uconsole/build/"
rm -f "$root/usr/sbin/policy-rc.d" "$root/tmp/provision-root.sh"
find "$root/tmp" "$root/var/tmp" -xdev -mindepth 1 -delete
rm -f "$root/etc/passwd-" "$root/etc/shadow-" "$root/etc/group-" "$root/etc/gshadow-"
rm -f "$root/etc/resolv.conf"
ln -s /run/systemd/resolve/stub-resolv.conf "$root/etc/resolv.conf"
chroot "$root" apt-get clean
find "$root/var/log" -type f -exec truncate -s 0 {} +
rm -rf "$root/var/lib/cloud/instances" "$root/var/lib/cloud/instance" "$root/var/lib/cloud/sem"
rm -f "$root/var/lib/systemd/random-seed" "$root/root/.bash_history"
sync
echo 'Root verification and cleanup complete; unmount and check both filesystems next.'
