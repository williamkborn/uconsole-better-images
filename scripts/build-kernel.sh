#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
project=$PWD
src=$project/sources/clockworkpi-linux
out=$project/build/kernel
mkdir -p "$out"
# Allow only this explicitly selected source tree when rebuilding via sudo.
config_index=${GIT_CONFIG_COUNT:-0}
export "GIT_CONFIG_KEY_${config_index}=safe.directory"
export "GIT_CONFIG_VALUE_${config_index}=$src"
export GIT_CONFIG_COUNT=$((config_index + 1))
export ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
export KBUILD_BUILD_USER=uconsole KBUILD_BUILD_HOST=ubuntu
export KBUILD_BUILD_TIMESTAMP='2026-10-20 00:00:00 UTC'
make -C "$src" O="$out" bcm2711_defconfig
"$src/scripts/config" --file "$out/.config" --set-str LOCALVERSION '-uconsole' --disable LOCALVERSION_AUTO --enable FW_LOADER_COMPRESS --enable FW_LOADER_COMPRESS_XZ --enable FW_LOADER_COMPRESS_ZSTD --enable SECURITY_APPARMOR --enable SECURITY_APPARMOR_HASH --enable SECURITY_APPARMOR_HASH_DEFAULT --enable DEFAULT_SECURITY_APPARMOR --set-str DEFAULT_SECURITY apparmor
make -C "$src" O="$out" olddefconfig
make -C "$src" O="$out" -j"${JOBS:-12}" Image.gz modules dtbs
make -C "$src" O="$out" INSTALL_MOD_PATH="$project/build/kernel-install" modules_install
make -s -C "$src" O="$out" kernelrelease > "$project/build/kernel-release.txt"
