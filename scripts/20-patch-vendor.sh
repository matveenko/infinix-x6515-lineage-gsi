#!/bin/sh
set -eu
. "$(dirname "$0")/_common.sh"

[ "$#" -eq 2 ] || die "Usage: $0 SOURCE_VENDOR.img OUTPUT_VENDOR.img"
source_image="$1"
output_image="$2"
expected_vendor_sha=b0e44ada3b32e8d230f1863ee5e27d0225903765d9ae7e8f3ead857ac4c755e4
expected_size=500649984

debugfs="$(find_homebrew_tool DEBUGFS debugfs)"
e2fsck="$(find_homebrew_tool E2FSCK e2fsck)"
python="$(find_tool PYTHON python3)"

[ -f "$source_image" ] || die "Missing source image: $source_image"
source_sha="$(shasum -a 256 "$source_image" | awk '{print $1}')"
[ "$source_sha" = "$expected_vendor_sha" ] || die "Unknown vendor SHA256: $source_sha"
[ "$(wc -c < "$source_image" | tr -d ' ')" = "$expected_size" ] || die "Unexpected vendor size"

mkdir -p "$(dirname "$output_image")"
cp "$source_image" "$output_image"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM

"$debugfs" -R "dump /bin/hw/android.hardware.lights-service.mediatek $tmpdir/hal.orig" \
    "$output_image" >/dev/null 2>&1
"$python" "$repo_root/tools/patch_hal.py" "$tmpdir/hal.orig" "$tmpdir/hal.patched"
printf 'u:object_r:mtk_hal_light_exec:s0\0' > "$tmpdir/selinux"

commands="$tmpdir/debugfs.cmds"
{
    echo 'rm /bin/hw/android.hardware.lights-service.mediatek'
    printf 'write %s /bin/hw/android.hardware.lights-service.mediatek\n' "$tmpdir/hal.patched"
    echo 'set_inode_field /bin/hw/android.hardware.lights-service.mediatek mode 0100755'
    echo 'set_inode_field /bin/hw/android.hardware.lights-service.mediatek uid 0'
    echo 'set_inode_field /bin/hw/android.hardware.lights-service.mediatek gid 2000'
    printf 'ea_set -f %s /bin/hw/android.hardware.lights-service.mediatek security.selinux\n' "$tmpdir/selinux"
} > "$commands"

"$debugfs" -w -f "$commands" "$output_image"
"$e2fsck" -fy "$output_image"
"$debugfs" -R "dump /bin/hw/android.hardware.lights-service.mediatek $tmpdir/hal.verify" \
    "$output_image" >/dev/null 2>&1
cmp "$tmpdir/hal.patched" "$tmpdir/hal.verify" || die "HAL verification failed"

[ "$(wc -c < "$output_image" | tr -d ' ')" = "$expected_size" ] || die "Output size changed"
echo "Patched vendor image: $output_image"
shasum -a 256 "$output_image"
echo "Keep the original vendor image for rollback."
