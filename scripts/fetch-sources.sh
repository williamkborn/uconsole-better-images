#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p sources downloads logs
clone_pin() {
 local url=$1 name=$2 revision=$3
 if [[ ! -d sources/$name/.git ]]; then
  git init "sources/$name"
  git -C "sources/$name" remote add origin "$url"
  git -C "sources/$name" fetch --depth=1 origin "$revision"
  git -C "sources/$name" checkout --detach FETCH_HEAD
 fi
}
clone_pin https://github.com/clockworkpi/uConsole.git uconsole 53a05efca806ca024aab4fbfd28a680688c2541c
clone_pin https://github.com/cuu/pi-gen.git pi-gen aa8c1871f689c51750601bebe34c6033ffc9f7a1
clone_pin https://github.com/cuu/ClockworkPi-linux.git clockworkpi-linux 03436f4117533693d608b10eb4b3965987230b68
clone_pin https://github.com/cuu/skel.git vendor-skel 295e0439c6da3467f736b6c72c980c31671029e5
for pair in 'uconsole 53a05efca806ca024aab4fbfd28a680688c2541c' 'pi-gen aa8c1871f689c51750601bebe34c6033ffc9f7a1' 'vendor-skel 295e0439c6da3467f736b6c72c980c31671029e5'; do
 read -r name revision <<< "$pair"
 [[ $(git -c safe.directory="$PWD/sources/$name" -C "sources/$name" rev-parse HEAD) == "$revision" ]] || {
  echo "Unexpected source revision: $name" >&2; exit 1;
 }
 [[ -z $(git -c safe.directory="$PWD/sources/$name" -C "sources/$name" status --porcelain) ]] || {
  echo "Source tree has local changes: $name" >&2; exit 1;
 }
done
src=sources/clockworkpi-linux
if [[ $(git -c safe.directory="$PWD/$src" -C "$src" rev-parse HEAD) != 58b28eeef87abfb49e52591ceae6af89a29242aa ]]; then
 # Three-way application needs the original pre-vendor blobs, including
 # Kconfig context that changed between the two Raspberry Pi revisions.
 git -c safe.directory="$PWD/$src" -C "$src" fetch --depth=1 origin a1073743767f9e7fdc7017ababd2a07ea0c97c1c
 git -c safe.directory="$PWD/$src" -C "$src" fetch --depth=1 https://github.com/raspberrypi/linux.git 58b28eeef87abfb49e52591ceae6af89a29242aa
 git -c safe.directory="$PWD/$src" -C "$src" checkout --detach FETCH_HEAD
 git -c safe.directory="$PWD/$src" -C "$src" apply --3way ../../patches/clockworkpi-6.12.patch
fi
base=ubuntu-26.04.1-preinstalled-server-arm64+raspi.img.xz
python3 scripts/fetch-artifacts.py
if [[ ! -f downloads/${base%.xz} ]]; then xz -dk "downloads/$base"; fi

bash scripts/prepare-assets.sh
