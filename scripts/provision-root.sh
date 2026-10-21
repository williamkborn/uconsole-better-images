#!/usr/bin/env bash
# Run inside the mounted ARM64 image using chroot and qemu-user-binfmt.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y -o APT::Get::Always-Include-Phased-Updates=true full-upgrade
apt-get install -y xfce4 xfce4-goodies lightdm lightdm-gtk-greeter \
 network-manager network-manager-gnome modemmanager ppp pppoe usb-modeswitch \
 bluez blueman pipewire pipewire-pulse wireplumber alsa-utils \
 xbindkeys brightnessctl upower polkitd gpiod python3-libgpiod \
 xvfb zenity dbus-x11 raspi-utils dfu-util libusb-1.0-0 python3-serial git curl wget nano geany \
 usbview gparted retroarch dosbox openttd \
 libsdl2-2.0-0 libsdl2-gfx-1.0-0 libsdl2-image-2.0-0 \
 libsdl2-mixer-2.0-0 libsdl2-net-2.0-0 libsdl2-ttf-2.0-0 \
 libglu1-mesa libglvnd0 libasound2t64 libslirp0 libopusfile0 libspeexdsp1 \
 libfreetype6 libmodplug1 libopenal1 libgl1-mesa-dev libtheora1 libvorbis0a \
 libmpg123-0t64 libluajit-5.1-2 dracut cloud-guest-utils
