# Rollback and recovery

Before patching, keep your own complete `vendor_b.img` and SHA-256 outside the
phone. Never use a vendor image from another X6515 revision or build.

## Roll back the brightness patch

Enter fastbootd with `adb reboot fastboot`, or use hardware recovery if Android
does not boot. Verify the mode, slot, and partition size:

```sh
fastboot devices
fastboot getvar is-userspace
fastboot getvar current-slot
fastboot getvar partition-size:vendor_b
```

The backup size must match the partition. Then flash your own backup:

```sh
fastboot flash vendor_b backups/vendor_b.img
fastboot reboot
```

For the tested V1307 device only:

```text
size    500649984 bytes
SHA256  b0e44ada3b32e8d230f1863ee5e27d0225903765d9ae7e8f3ead857ac4c755e4
```

This hash identifies one tested backup; it is not permission to download a
random image with the same filename.

## Roll back the GSI and verity

Keep the original `bvS`/`bvN` system image. Reflash it to `system_b` from
fastbootd. A boot loop caused by incompatible userdata may require a factory
reset from recovery.

After restoring completely original system and vendor partitions, verity may
be re-enabled:

```sh
adb root
adb enable-verity
adb reboot
```

Do not enable verity while the HAL remains modified; FEC may reject or replace
the changed block.
