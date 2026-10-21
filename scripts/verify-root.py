#!/usr/bin/env python3
"""Offline image checks. These do not claim physical CM4 boot validation."""
import gzip
import hashlib
import json
import pathlib
import subprocess
import sys
import xml.etree.ElementTree as ET

project = pathlib.Path(__file__).resolve().parent.parent
root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else project / 'mnt/root').resolve()
checks = []

def check(condition, message):
    if not condition:
        raise RuntimeError(message)
    checks.append(message)

def run(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT)

def chroot(*args):
    return run('chroot', str(root), *args)

check('VERSION_ID="26.04"' in (root / 'etc/os-release').read_text(), 'Ubuntu 26.04 release')
check(chroot('dpkg', '--print-architecture').strip() == 'arm64', 'ARM64 package architecture')
check(not chroot('dpkg', '--audit').strip(), 'No incomplete dpkg transactions')
chroot('apt-get', 'check')
checks.append('APT dependency consistency')
release = (project / 'build/kernel-release.txt').read_text().strip()
boot = root / 'boot/firmware/uconsole'
check((boot / 'kernel8.img').read_bytes() == (project / 'build/kernel/arch/arm64/boot/Image.gz').read_bytes(), 'Installed kernel matches build')
check(gzip.decompress((boot / 'kernel8.img').read_bytes())[56:60] == b'ARM\x64', 'Valid ARM64 kernel image header')
check((boot / 'initramfs').read_bytes() == (root / f'boot/initrd.img-{release}').read_bytes(), 'Boot initramfs matches custom kernel initramfs')
config = (root / f'boot/config-{release}').read_text()
for option in ('CONFIG_MMC_BCM2835=y', 'CONFIG_MMC_SDHCI_BRCMSTB=y', 'CONFIG_EXT4_FS=y', 'CONFIG_BLK_DEV_INITRD=y', 'CONFIG_DRM_PANEL_CWU50=m', 'CONFIG_BACKLIGHT_OCP8178=m', 'CONFIG_BATTERY_AXP20X=m', 'CONFIG_SECURITY_APPARMOR=y', 'CONFIG_FW_LOADER_COMPRESS=y', 'CONFIG_FW_LOADER_COMPRESS_ZSTD=y', 'CONFIG_FW_LOADER_COMPRESS_XZ=y'):
    check(option in config.splitlines(), option)
for directory in (root / f'usr/lib/modules/{release}', root / 'etc/skel', root / 'usr/share/uconsole'):
    check(all(p.lstat().st_uid == 0 for p in directory.rglob('*')), f'Root ownership: {directory.relative_to(root)}')
for firmware in ('brcmfmac43455-sdio.raspberrypi,4-compute-module.bin.zst', 'brcmfmac43455-sdio.raspberrypi,4-compute-module.txt.zst', 'brcmfmac43455-sdio.raspberrypi,4-compute-module.clm_blob.zst', 'BCM4345C0.raspberrypi,4-compute-module.hcd.zst'):
    check(chroot('test', '-s', '/usr/lib/firmware/brcm/' + firmware) == '', f'CM4 firmware {firmware}')
for module in ('vc4', 'panel-cwu50', 'ocp8178_bl', 'axp20x_battery'):
    paths = list((root / f'usr/lib/modules/{release}').rglob(module + '.ko.xz'))
    check(len(paths) == 1 and run('modinfo', '-F', 'vermagic', str(paths[0])).split()[0] == release, f'Module ABI {module}')
for filename in ('bcm2711-rpi-cm4.dtb' , 'overlays/clockworkpi-uconsole.dtbo', 'overlays/vc4-kms-v3d-pi4.dtbo'):
    source = project / 'build/kernel/arch/arm64/boot/dts' / (filename if filename.startswith('overlays/') else 'broadcom/' + filename)
    check((boot / filename).read_bytes() == source.read_bytes(), f'Matching DT file {filename}')
bootcfg = (root / 'boot/firmware/config.txt').read_text().splitlines()
for line in ('os_prefix=uconsole/', 'arm_64bit=1', 'kernel=kernel8.img', 'initramfs initramfs followkernel', 'dtoverlay=clockworkpi-uconsole', 'dtoverlay=vc4-kms-v3d-pi4,cma-384', 'dtoverlay=audremap,pins_12_13', 'dtoverlay=dwc2,dr_mode=host', 'dtparam=ant2', 'gpio=9=op,dh', 'gpio=10=ip,np'):
    check(line in bootcfg, f'Boot directive {line}')
for service in ('clockworkpi-audio-patch', 'clockworkpi-audio-shutdown', 'NetworkManager', 'ModemManager', 'lightdm', 'uconsole-firstboot'):
    check(run('systemctl', '--root=' + str(root), 'is-enabled', service + '.service').strip() == 'enabled', f'{service} enabled')
for name in ('xfce4', 'lightdm', 'network-manager', 'modemmanager', 'bluez', 'pipewire', 'wireplumber', 'raspi-utils', 'dfu-util', 'opentyrian', 'openttd', 'retroarch', 'clockworkpi-audio', 'devterm-backlight-rpi-cm4', 'devterm-wiringpi-cm4-cpi', 'devterm-cavestory-cpi-cm4', 'devterm-tic80-cpi', 'uconsole-4g-util-cm4', 'uconsole-dosbox-staging', 'uconsole-love2d', 'uconsole-liko12', 'uconsole-lowresnx'):
    check(chroot('dpkg-query', '-W', '-f=${db:Status-Status}', name) == 'installed', f'Package {name}')
executables = list(json.loads((project / 'config/vendor-elf-dependencies.json').read_text()))
executables += ['usr/bin/gpio', 'usr/lib/libwiringPi.so.2.50', 'opt/obsidian/obsidian', 'usr/share/uconsole/firmware-tools/uconsole_keyboard_flash/upload-reset.elf']
for executable in executables:
    result = chroot('ldd', '/' + executable)
    check('not found' not in result, f'Dynamic libraries for {executable}')
for xml in (root / 'etc/skel/.config/xfce4').rglob('*.xml'):
    ET.parse(xml)
checks.append('Vendor Xfce settings parse as XML')
profile = (root / 'etc/uconsole-build-profile').read_text().strip()
check(profile in ('full', 'release'), 'Recognized build profile')
if profile == 'release':
    check(not (root / 'usr/share/games/tyrian').exists(), 'Release excludes proprietary Tyrian data')
else:
    check((root / 'usr/share/games/tyrian/tyrian1.lvl').exists(), 'Tyrian game data')
check((root / 'etc/cloud/cloud-init.disabled').exists(), 'Cloud-init disabled for local first-boot flow')
check((root / 'etc/machine-id').stat().st_size == 0, 'Machine identity will be created at boot')
check(not list((root / 'etc/ssh').glob('ssh_host_*')), 'No shared SSH host keys')
check(not (root / 'var/lib/uconsole/firstboot-complete').exists(), 'Root expansion pending first physical boot')
check((root / 'home/cpi/Documents/Obsidian Vault/README.md').exists(), 'Local user writing setup')
check((root / 'home/cpi/Documents/Obsidian Vault/.obsidian/appearance.json').exists(), 'Vendor writing appearance settings')
check((root / 'opt/obsidian/chrome-sandbox').stat().st_mode & 0o4777 == 0o4755, 'Obsidian sandbox permissions')
check('--no-sandbox' not in (root / 'usr/local/bin/obsidian').read_text(), 'Obsidian production sandbox enabled')
check('lightdm' in (root / 'etc/X11/default-display-manager').read_text(), 'LightDM selected as display manager')
check('cpi:' in (root / 'etc/passwd').read_text(), 'Local user exists')
report = dict(kernel=release, build_profile=profile, checks=checks, physical_boot_tested=False)
(project / 'docs/root-verification.json').write_text(json.dumps(report, indent=2) + '\n')
print(f'{len(checks)} offline checks passed')
