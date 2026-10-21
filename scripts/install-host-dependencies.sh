#!/usr/bin/env bash
set -euo pipefail
[[ $EUID == 0 ]] || { echo 'Run with sudo'; exit 1; }
apt-get update
apt-get install -y git curl python3 build-essential gcc-aarch64-linux-gnu \
 qemu-user qemu-user-binfmt binfmt-support bc bison flex libssl-dev libelf-dev \
 libncurses-dev device-tree-compiler rsync dosfstools e2fsprogs parted \
 cloud-guest-utils xz-utils bzip2 7zip zstd dracut-core
