# Installing a LineageOS 19.1 GSI on the X6515

This guide is for the tested `Infinix X6515`, not similarly named Smart 7
variants with a different SoC or partition layout.

## Requirements

- at least 70% battery and a backup of all user data;
- OEM unlocking and USB debugging enabled;
- a reliable cable and Android Platform Tools;
- an A/B, system-as-root `arm64_bvN` or `arm64_bvS` GSI;
- acceptance that unlocking wipes userdata.

Tested images:

```text
lineage-19.1-20250606-UNOFFICIAL-arm64_bvN.img
SHA256 65ae1cc41d48c15bdf40d159ece55b473fafcdc8596e127ffab13cf0b36a0e5b

lineage-19.1-20250606-UNOFFICIAL-arm64_bvS.img
SHA256 49792f857b54c6c950bacc6e7c742b39a3dea672aa08072c70878743fb062f76
```

`bvN` is vanilla; `bvS` contains PHH-SU/root. These are not VNDKLite or
32-bit-binder builds.

## 1. Inventory

```sh
./scripts/00-doctor.sh
adb devices -l
adb shell getprop ro.product.model
adb shell getprop ro.treble.enabled
adb shell getprop ro.product.cpu.abilist
adb shell getprop ro.boot.slot_suffix
```

Expect X6515, Treble `true`, `arm64-v8a`, and an A/B slot suffix.

## 2. Unlock

This operation wipes userdata:

```sh
adb reboot bootloader
fastboot devices
fastboot flashing unlock
```

Confirm with the phone buttons. Enable USB debugging again after the wipe.

## 3. Enter fastbootd

Dynamic logical partitions must be flashed in userspace fastboot:

```sh
adb reboot fastboot
fastboot getvar is-userspace
fastboot getvar current-slot
```

Expect `is-userspace: yes`. The tested device used slot B. The commands below
intentionally use `_b`; do not reuse them for another active slot or layout.

## 4. Make room and flash system

The tested layout lacked room for the roughly 2 GB system image. Its
`product_b` snapshot/COW partition was removed, then `system_b` was resized.
Save `fastboot getvar all` first and verify every partition name.

```sh
fastboot delete-logical-partition product_b-cow
fastboot resize-logical-partition system_b 2121457664
fastboot flash system_b lineage-19.1-20250606-UNOFFICIAL-arm64_bvS.img
fastboot reboot
```

`2121457664` applies only to that tested image. Use the exact byte size of any
other GSI.

## 5. First boot and factory reset

On this X6515, `fastboot -w` failed in vendor fastboot wipe tasks and LineageOS
hung on old userdata. The tested recovery was:

1. boot recovery;
2. choose `Factory reset / Format data`;
3. reboot System.

The first boot may take a while. Do not remove power during the boot animation
without first diagnosing it through ADB/logcat.

## 6. Root variant and hardware test

The matching `bvS` image was flashed over `bvN` without another wipe. Enable
root ADB in Developer options / PHH settings and verify it:

```sh
adb root
adb shell id
```

Expect `uid=0(root)`. Before adding apps, test Wi-Fi, SIM, audio, Bluetooth,
fingerprint, rotation, power, touch, camera, calls, and mobile data.
