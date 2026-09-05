# X6515 brightness fix

## Symptom and diagnosis

LineageOS 19.1 worked, but maximum brightness was far below XOS. Android
reported `255`, while the driver received only `37` of `4095`. Writing `4095`
directly to `/sys/class/leds/lcd-backlight/brightness` proved that the panel and
kernel driver supported the full range.

PHH's **Force alternative backlight scale** is not a fix for this MediaTek HAL.
It places `4095` in `LightState.color`; the HAL treats it as RGB `0x00000fff`
and calculates about 37. Disable it before testing:

```sh
adb shell setprop persist.sys.phh.backlight.scale 0
```

## Vendor HAL and patch

```text
/vendor/bin/hw/android.hardware.lights-service.mediatek
source SHA256 798a48b2ecf51cdfc73017d01c2de748764cbcebaf4ab85bec83edb7747f316f
```

The HAL computes `(29*B + 150*G + 77*R) >> 8`. Since the weights total 256,
white produces 255, but this panel has 4095 levels. At offset `0x3ecc`, the
patch changes only the final AArch64 shift:

```diff
- 15 7d 08 53    lsr w21, w8, #8
+ 15 7d 04 53    lsr w21, w8, #4
```

This preserves the vendor curve and multiplies it by 16, reaching `4080/4095`.

## Why no daemon is used

An early prototype copied Android brightness to sysfs every 200 ms. It proved
the range but raced the Lights HAL and caused visible jumps. Stopping the HAL
triggered a framework watchdog reboot. The final fix runs inside the normal
Binder HAL only when brightness changes, with no polling or wakeups.

## dm-verity and FEC

After the first modified `vendor_b` flash, FEC supplied the original block
because vendor verity detected the change. On the tested root/userdebug GSI:

```sh
adb root
adb disable-verity
adb reboot
```

The patched mounted HAL must have SHA-256:

```text
619f0f16b5869a4d9ec4e234643258151b41471b8af8a941b4089e59bc9ab02a
```

## Using the scripts

Run this stage **only after the rooted LineageOS variant has booted
successfully**. The Mac needs Android Platform Tools, Python 3, and `e2fsprogs`:

```sh
brew install e2fsprogs
```

From the cloned repository root, connect the booted phone with root debugging
enabled, validate it, and dump its own vendor partition:

```sh
./scripts/00-doctor.sh
./scripts/10-dump-vendor.sh
```

This creates `backups/vendor_b.img` only if its size and V1307 SHA-256 match.
Copy that original backup to another safe location, then build the patch:

```sh
./scripts/20-patch-vendor.sh \
  backups/vendor_b.img \
  builds/vendor_b-x6515-brightness.img
```

Disable verity; the script requires the literal confirmation
`DISABLE-VERITY`:

```sh
./scripts/30-disable-verity.sh
adb reboot
```

After Android fully boots and ADB reconnects, enter **fastbootd**, not classic
bootloader fastboot:

```sh
adb reboot fastboot
fastboot getvar is-userspace
# expected: is-userspace: yes
```

Flash the built image. The script revalidates its size and patched HAL,
fastbootd mode, slot B, and partition size, then requires
`FLASH-VENDOR-B`:

```sh
./scripts/40-flash-vendor.sh builds/vendor_b-x6515-brightness.img
```

After Android fully boots, run the automated check. It disables PHH alternative
scale, selects manual brightness, and temporarily sets maximum brightness:

```sh
./scripts/50-verify-brightness.sh
```

Success means the patched HAL is running and sysfs reports `4080/4095`. Also
test the full slider, minimum, midpoint, sleep/wake, and touch. If anything
fails, use the [recovery guide](RECOVERY-EN.md).

## Verification

```sh
adb root
adb shell settings put system screen_brightness_mode 0
adb shell settings put system screen_brightness 255
adb shell cat /sys/class/leds/lcd-backlight/brightness
# 4080
```

Also test minimum and midpoint, slider travel in both directions, sleep/wake,
touch, and the absence of `vendor.light-default` restarts.
