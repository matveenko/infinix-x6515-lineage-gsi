# Security notes

- Never publish `vendor.img`, device serial numbers, recovery logs containing
  identifiers, or proprietary firmware.
- The HAL patcher is intentionally locked to one source SHA-256. Add support
  for another build only after independent disassembly and hardware testing.
- Report a dangerous command, incorrect hash, or secret exposure through a
  private GitHub security advisory rather than a public issue.
