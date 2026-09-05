#!/usr/bin/env python3
"""Strict one-byte backlight patcher for the tested X6515 MTK Lights HAL."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

SOURCE_SHA256 = "798a48b2ecf51cdfc73017d01c2de748764cbcebaf4ab85bec83edb7747f316f"
PATCHED_SHA256 = "619f0f16b5869a4d9ec4e234643258151b41471b8af8a941b4089e59bc9ab02a"
OFFSET = 0x3ECC
BEFORE = bytes.fromhex("15 7d 08 53")  # lsr w21, w8, #8
AFTER = bytes.fromhex("15 7d 04 53")   # lsr w21, w8, #4


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="original extracted HAL")
    parser.add_argument("output", type=Path, help="patched HAL output")
    args = parser.parse_args()

    data = bytearray(args.source.read_bytes())
    digest = sha256(data)
    if digest != SOURCE_SHA256:
        raise SystemExit(
            f"Refusing unknown HAL: SHA256 {digest}, expected {SOURCE_SHA256}"
        )
    if data[OFFSET : OFFSET + len(BEFORE)] != BEFORE:
        actual = data[OFFSET : OFFSET + len(BEFORE)].hex(" ")
        raise SystemExit(f"Unexpected bytes at 0x{OFFSET:x}: {actual}")

    data[OFFSET : OFFSET + len(BEFORE)] = AFTER
    patched_digest = sha256(data)
    if patched_digest != PATCHED_SHA256:
        raise SystemExit(f"Internal verification failed: {patched_digest}")

    args.output.write_bytes(data)
    args.output.chmod(0o755)
    print(f"Patched 0x{OFFSET:x}: {BEFORE.hex(' ')} -> {AFTER.hex(' ')}")
    print(f"SHA256 {patched_digest}  {args.output}")


if __name__ == "__main__":
    main()
