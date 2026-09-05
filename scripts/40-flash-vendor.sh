#!/bin/sh
set -eu
. "$(dirname "$0")/_common.sh"

[ "$#" -eq 1 ] || die "Usage: $0 PATCHED_VENDOR.img"
image="$1"
expected_size=500649984
expected_hal_sha=619f0f16b5869a4d9ec4e234643258151b41471b8af8a941b4089e59bc9ab02a
fastboot="$(find_tool FASTBOOT fastboot "$repo_root/platform-tools/fastboot")"
debugfs="$(find_homebrew_tool DEBUGFS debugfs)"

[ -f "$image" ] || die "Missing image: $image"
size="$(wc -c < "$image" | tr -d ' ')"
[ "$size" = "$expected_size" ] || die "Image size is $size, expected $expected_size"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM
"$debugfs" -R "dump /bin/hw/android.hardware.lights-service.mediatek $tmpdir/hal" \
    "$image" >/dev/null 2>&1 || die "Cannot extract Lights HAL from image"
hal_sha="$(shasum -a 256 "$tmpdir/hal" | awk '{print $1}')"
[ "$hal_sha" = "$expected_hal_sha" ] || die "Unexpected patched HAL SHA256: $hal_sha"

"$fastboot" devices | grep -q . || die "No fastboot device"
userspace="$("$fastboot" getvar is-userspace 2>&1 | sed -n 's/^is-userspace: //p')"
slot="$("$fastboot" getvar current-slot 2>&1 | sed -n 's/^current-slot: //p')"
partition_hex="$("$fastboot" getvar partition-size:vendor_b 2>&1 | sed -n 's/^partition-size:vendor_b: //p')"
[ "$userspace" = yes ] || die "Use fastbootd (is-userspace must be yes)"
[ "$slot" = b ] || die "This tested workflow requires active slot B"
partition_size=$((partition_hex))
[ "$partition_size" = "$size" ] || die "Partition/image size mismatch: $partition_size vs $size"

echo "About to overwrite vendor_b on an unlocked X6515."
echo "Verified original backup must already exist outside the phone."
printf 'Type FLASH-VENDOR-B to continue: '
read answer
[ "$answer" = FLASH-VENDOR-B ] || die "Cancelled"

"$fastboot" flash vendor_b "$image"
"$fastboot" reboot
