#!/bin/sh

set -eu

die() {
    echo "ERROR: $*" >&2
    exit 1
}

find_tool() {
    var_name="$1"
    command_name="$2"
    fallback="${3:-}"
    eval explicit="\${$var_name:-}"
    if [ -n "$explicit" ]; then
        [ -x "$explicit" ] || die "$var_name is not executable: $explicit"
        printf '%s\n' "$explicit"
    elif command -v "$command_name" >/dev/null 2>&1; then
        command -v "$command_name"
    elif [ -n "$fallback" ] && [ -x "$fallback" ]; then
        printf '%s\n' "$fallback"
    else
        die "Missing tool: $command_name"
    fi
}

repo_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
