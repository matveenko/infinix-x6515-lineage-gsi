#!/bin/sh
set -eu
. "$(dirname "$0")/_common.sh"

adb="$(find_tool ADB adb "$repo_root/platform-tools/adb")"
fastboot="$(find_tool FASTBOOT fastboot "$repo_root/platform-tools/fastboot")"

echo "adb:      $adb"
"$adb" version | head -n 2
echo "fastboot: $fastboot"
"$fastboot" --version | head -n 1
echo

"$adb" get-state >/dev/null 2>&1 || die "Android device is not available over ADB"

model="$("$adb" shell getprop ro.product.model | tr -d '\r')"
hardware="$("$adb" shell getprop ro.hardware | tr -d '\r')"
fingerprint="$("$adb" shell getprop ro.vendor.build.fingerprint | tr -d '\r')"
slot="$("$adb" shell getprop ro.boot.slot_suffix | tr -d '\r')"
treble="$("$adb" shell getprop ro.treble.enabled | tr -d '\r')"
abi="$("$adb" shell getprop ro.product.cpu.abi | tr -d '\r')"

printf '%-18s %s\n' model "$model" hardware "$hardware" slot "$slot" treble "$treble" abi "$abi"
printf '%-18s %s\n' vendor_fingerprint "$fingerprint"

[ "$hardware" = mt6761 ] || die "Expected ro.hardware=mt6761"
[ "$slot" = _b ] || die "This tested workflow requires active slot B"
[ "$treble" = true ] || die "Project Treble is not reported as enabled"
echo "$fingerprint" | grep -qi '^Infinix/X6515-' || die "Not the tested X6515 vendor"

echo "Device matches the tested X6515 family. No data was changed."
