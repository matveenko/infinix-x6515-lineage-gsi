#!/bin/sh
set -eu
. "$(dirname "$0")/_common.sh"

adb="$(find_tool ADB adb "$repo_root/platform-tools/adb")"
output="${1:-$repo_root/backups/vendor_b.img}"
expected_size=500649984
expected_sha=b0e44ada3b32e8d230f1863ee5e27d0225903765d9ae7e8f3ead857ac4c755e4

"$repo_root/scripts/00-doctor.sh"
mkdir -p "$(dirname "$output")"

"$adb" root
"$adb" wait-for-device
uid="$("$adb" shell id -u | tr -d '\r')"
[ "$uid" = 0 ] || die "Root ADB is required to read the logical block device"

block=/dev/block/mapper/vendor_b
"$adb" shell test -b "$block" || die "Missing block device: $block"
"$adb" pull "$block" "$output"

size="$(wc -c < "$output" | tr -d ' ')"
sha="$(shasum -a 256 "$output" | awk '{print $1}')"
echo "size=$size"
echo "sha256=$sha"
[ "$size" = "$expected_size" ] || die "Unexpected vendor size"
[ "$sha" = "$expected_sha" ] || die "Vendor SHA does not match tested V1307 image"
echo "Verified backup: $output"
