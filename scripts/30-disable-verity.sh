#!/bin/sh
set -eu
. "$(dirname "$0")/_common.sh"

adb="$(find_tool ADB adb "$repo_root/platform-tools/adb")"
"$repo_root/scripts/00-doctor.sh"

printf 'Type DISABLE-VERITY to continue: '
read answer
[ "$answer" = DISABLE-VERITY ] || die "Cancelled"

"$adb" root
"$adb" wait-for-device
"$adb" disable-verity
echo "Reboot required. Run: adb reboot"
