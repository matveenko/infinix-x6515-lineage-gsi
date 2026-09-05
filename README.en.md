# Infinix Smart 7 X6515: LineageOS GSI and brightness fix

An experimental, reproducible toolkit for the MediaTek MT6761 variant of the
Infinix Smart 7 **X6515**. It documents a LineageOS 19.1 GSI installation and
fixes the incorrect `0..255` backlight range on a panel exposing `0..4095`.

On the tested phone, Wi-Fi, audio, Bluetooth, fingerprint, rotation,
sleep/wake, touch, and the full smooth brightness range work. The SIM is
detected; mobile data still needs testing with an active SIM.

## Start here

The complete step-by-step installation is in
**[docs/INSTALL-EN.md](docs/INSTALL-EN.md)**. Read it in full before copying
commands, especially the model checks, active slot B, bootloader unlock,
`fastbootd`, and factory-reset sections.

After LineageOS boots successfully, continue with the
**[brightness fix](docs/BRIGHTNESS-FIX-EN.md)**. If the phone no longer boots,
follow the **[recovery guide](docs/RECOVERY-EN.md)**.

> [!CAUTION]
> Unlocking the bootloader erases all user data. Flashing the wrong dynamic
> partition can make the phone unbootable. This project was tested only on the
> X6515 and the V1307 vendor family shown below.

## Tested configuration

```text
Model:                 Infinix Smart 7 X6515
Stock build:           X6515-H6127JAk-S-RU-231117V1307
Vendor fingerprint:    Infinix/X6515-OP/Infinix-X6515:12/.../231117V1060:user/release-keys
SoC:                   MediaTek MT6761
Android / VNDK:        12 / 31
Architecture:          ARM64, Binder64
Partition layout:      A/B, dynamic partitions, system-as-root
Tested slot:           B
GSI:                   LineageOS 19.1 arm64_bvS / arm64_bvN
```

## Repository contents

- [Installation guide](docs/INSTALL-EN.md): XOS to LineageOS GSI;
- [Brightness analysis](docs/BRIGHTNESS-FIX-EN.md): diagnosis and the fix;
- [Recovery guide](docs/RECOVERY-EN.md): tested vendor rollback;
- `scripts/`: guarded dump, patch, flash, and verification scripts;
- `tools/patch_hal.py`: strict one-byte patcher.

Russian version: [README.md](README.md).

## Quick reference: brightness fix

This assumes a booted root/userdebug GSI, unlocked bootloader, official Android
Platform Tools, Python 3, and `e2fsprogs`. Run from the repository root:

```sh
brew install e2fsprogs
./scripts/00-doctor.sh
./scripts/10-dump-vendor.sh
./scripts/20-patch-vendor.sh backups/vendor_b.img builds/vendor_b-x6515-brightness.img
./scripts/30-disable-verity.sh
adb reboot
# After Android has fully booted:
adb reboot fastboot
./scripts/40-flash-vendor.sh builds/vendor_b-x6515-brightness.img
# After Android has fully booted:
./scripts/50-verify-brightness.sh
```

The scripts validate the model, fingerprint, slot, image size, and SHA-256
hashes and stop on any mismatch.

## Why no ready-made `vendor.img` is included

The vendor partition contains proprietary manufacturer components. This
project does not redistribute them or claim that one binary is universal. Each
user dumps their own `vendor_b`; the patcher accepts only the known source hash
and changes one known AArch64 instruction.

## Patch result

```text
With PHH alternative scale: Android 255 -> sysfs 37/4095
Without alternative scale:  Android 255 -> sysfs 255/4095
After the HAL patch:         Android 255 -> sysfs 4080/4095
```

At file/virtual offset `0x3ecc`:

```diff
- 15 7d 08 53    lsr w21, w8, #8
+ 15 7d 04 53    lsr w21, w8, #4
```

## Credits and license

This work was produced collaboratively. Andrew Snow supplied the device,
performed all physical operations, and tested behavior. OpenAI Codex assisted
with diagnosis, reverse engineering, automation, and documentation.

Author: [Andrew Snow](https://t.me/andrew_snoww). Keep this attribution and
link when using or redistributing the project.

Original scripts and documentation are released under the included permissive
license. It does not cover third-party firmware or proprietary binaries.
