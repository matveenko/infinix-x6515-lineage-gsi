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
