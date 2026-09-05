#!/bin/sh
set -eu
. "$(dirname "$0")/_common.sh"

adb="$(find_tool ADB adb "$repo_root/platform-tools/adb")"
expected_hal_sha=619f0f16b5869a4d9ec4e234643258151b41471b8af8a941b4089e59bc9ab02a

"$adb" root
"$adb" wait-for-device
"$adb" shell setprop persist.sys.phh.backlight.scale 0
"$adb" shell settings put system screen_brightness_mode 0
"$adb" shell settings put system screen_brightness 255
sleep 1

hal_sha="$("$adb" shell sha256sum /vendor/bin/hw/android.hardware.lights-service.mediatek | awk '{print $1}' | tr -d '\r')"
brightness="$("$adb" shell cat /sys/class/leds/lcd-backlight/brightness | tr -d '\r')"
maximum="$("$adb" shell cat /sys/class/leds/lcd-backlight/max_brightness | tr -d '\r')"
lights="$("$adb" shell getprop init.svc.vendor.light-default | tr -d '\r')"

echo "HAL SHA256: $hal_sha"
echo "Lights HAL: $lights"
echo "Brightness: $brightness/$maximum"
[ "$hal_sha" = "$expected_hal_sha" ] || die "Patched HAL is not active"
[ "$lights" = running ] || die "Lights HAL is not running"
[ "$brightness" = 4080 ] || die "Expected brightness 4080"
[ "$maximum" = 4095 ] || die "Expected hardware maximum 4095"
echo "X6515 brightness patch verified."
