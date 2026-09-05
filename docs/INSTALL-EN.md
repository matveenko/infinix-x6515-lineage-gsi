# Complete LineageOS 19.1 GSI and brightness-fix installation for X6515

This is a sequential clean-Mac-to-working-phone guide. It was tested only on
the **Infinix Smart 7 X6515 / MT6761**, stock build
`X6515-H6127JAk-S-RU-231117V1307`, active slot B.

> [!CAUTION]
> Unlocking the bootloader erases all data. A wrong partition name can make the
> phone unbootable. Stop if the model, fingerprint, hash, or slot differs.

## 1. Download everything

Clone this project and create the download directory:

```sh
git clone https://github.com/matveenko/infinix-x6515-lineage-gsi.git
cd infinix-x6515-lineage-gsi
mkdir -p downloads
```

Alternatively, use **Code → Download ZIP** on the
[project page](https://github.com/matveenko/infinix-x6515-lineage-gsi), extract
it, and open the resulting directory in Terminal.

Download **SDK Platform-Tools for Mac** from the
[official Google page](https://developer.android.com/tools/releases/platform-tools),
move the ZIP to Downloads, then run:

```sh
unzip ~/Downloads/platform-tools-latest-darwin.zip -d .
chmod +x platform-tools/adb platform-tools/fastboot
./platform-tools/adb version
./platform-tools/fastboot --version
```

For the full workflow, download the tested rooted image:

**[lineage-19.1-20250606-UNOFFICIAL-arm64_bvS.img.gz](https://sourceforge.net/projects/andyyan-gsi/files/lineage-19.x/lineage-19.1-20250606-UNOFFICIAL-arm64_bvS.img.gz/download)**

Use exactly `arm64_bvS`, without `vndklite`: ARM64, A/B system-as-root,
vanilla/no GApps, with PHH Superuser. Move it into `downloads`, then:

```sh
gunzip downloads/lineage-19.1-20250606-UNOFFICIAL-arm64_bvS.img.gz
shasum -a 256 downloads/lineage-19.1-20250606-UNOFFICIAL-arm64_bvS.img
```

Expected uncompressed IMG SHA-256:

```text
49792f857b54c6c950bacc6e7c742b39a3dea672aa08072c70878743fb062f76
```

The non-root [`arm64_bvN`](https://sourceforge.net/projects/andyyan-gsi/files/lineage-19.x/lineage-19.1-20250606-UNOFFICIAL-arm64_bvN.img.gz/download)
also booted, but cannot run `10-dump-vendor.sh`. Its uncompressed IMG SHA-256
is `65ae1cc41d48c15bdf40d159ece55b473fafcdc8596e127ffab13cf0b36a0e5b`.

Install the Mac-side brightness tools:

```sh
brew install e2fsprogs
python3 --version
```

If `brew` is unavailable, install it from the
[official Homebrew site](https://brew.sh/).

## 2. Check the stock phone with `00-doctor.sh`

Charge to at least 70%, back up all data, and enable OEM unlocking and USB
debugging. Connect the phone, accept its RSA prompt, and run:

```sh
./scripts/00-doctor.sh
```

This script changes nothing. It checks ADB/Fastboot, MT6761, Treble, ARM64,
vendor fingerprint, and slot B. Continue only after:

```text
Device matches the tested X6515 family. No data was changed.
```

## 3. Unlock the bootloader

This erases userdata:

```sh
./platform-tools/adb reboot bootloader
./platform-tools/fastboot devices
./platform-tools/fastboot flashing unlock
```

Confirm with the phone buttons. Boot XOS and enable USB debugging again.

## 4. Enter fastbootd and flash the GSI

```sh
./platform-tools/adb reboot fastboot
./platform-tools/fastboot getvar is-userspace
./platform-tools/fastboot getvar current-slot
```

Require `is-userspace: yes` and `current-slot: b`. Then run the tested slot-B
layout commands:

```sh
./platform-tools/fastboot delete-logical-partition product_b-cow
./platform-tools/fastboot resize-logical-partition system_b 2121457664
./platform-tools/fastboot flash system_b downloads/lineage-19.1-20250606-UNOFFICIAL-arm64_bvS.img
./platform-tools/fastboot reboot
```

The byte count applies only to the named image.

## 5. Factory reset and enable root ADB

If LineageOS remains on its boot animation, enter recovery. At `No command`,
hold Power and tap Volume Up once, then choose **Factory reset / Wipe data** and
**Reboot system now**.

After LineageOS boots, enable Developer options and root debugging in PHH
settings. Verify `./platform-tools/adb root` followed by
`./platform-tools/adb shell id`; expect `uid=0(root)`. Test touch, Wi-Fi, audio,
Bluetooth, fingerprint, rotation, sleep/wake, camera, and SIM.

## 6. Save vendor with `10-dump-vendor.sh`

Phone state: fully booted LineageOS with root ADB.

```sh
./scripts/10-dump-vendor.sh
```

It reads `/dev/block/mapper/vendor_b`, creates `backups/vendor_b.img`, and
requires size `500649984` plus SHA-256
`b0e44ada3b32e8d230f1863ee5e27d0225903765d9ae7e8f3ead857ac4c755e4`.
Copy this rollback image to another safe location.

## 7. Build the patch with `20-patch-vendor.sh`

Phone state: irrelevant; this runs entirely on the Mac.

```sh
./scripts/20-patch-vendor.sh \
  backups/vendor_b.img \
  builds/vendor_b-x6515-brightness.img
```

It validates the source image and HAL, changes one AArch64 instruction,
restores metadata, checks the filesystem, and creates a separate patched image.

## 8. Disable verity with `30-disable-verity.sh`

Phone state: fully booted and available through root ADB.

```sh
./scripts/30-disable-verity.sh
```

Enter `DISABLE-VERITY`, then reboot and wait for Android:

```sh
./platform-tools/adb reboot
```

## 9. Flash the fix with `40-flash-vendor.sh`

Enter fastbootd and require `is-userspace: yes`:

```sh
./platform-tools/adb reboot fastboot
./platform-tools/fastboot getvar is-userspace
./scripts/40-flash-vendor.sh builds/vendor_b-x6515-brightness.img
```

The script validates the image, patched HAL, fastbootd, slot B, and partition
size. Enter `FLASH-VENDOR-B` only after those checks pass. It flashes and
reboots the phone.

## 10. Verify with `50-verify-brightness.sh`

Phone state: LineageOS has fully booted and ADB is available.

```sh
./scripts/50-verify-brightness.sh
```

It disables the incompatible PHH alternative scale, temporarily selects manual
maximum brightness, and verifies the mounted HAL, service, and `4080/4095`
hardware value. Success ends with:

```text
X6515 brightness patch verified.
```

Manually test minimum, midpoint, both slider directions, touch, and sleep/wake.
See [the technical explanation](BRIGHTNESS-FIX-EN.md) and
[the recovery guide](RECOVERY-EN.md) for more detail.
