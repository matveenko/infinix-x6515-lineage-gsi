# Contributing

Reports for another X6515 revision should include only non-sensitive metadata:

- full model and build ID;
- `ro.hardware`, VNDK and partition layout;
- SHA-256 and size of the Lights HAL (not the binary itself);
- brightness setting, current sysfs value and max sysfs value;
- exact test result and a verified rollback path.

Do not upload vendor or stock firmware blobs to issues. Changes to byte offsets
must include disassembly and a new strict source hash check.
