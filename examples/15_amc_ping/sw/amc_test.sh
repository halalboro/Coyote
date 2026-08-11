#!/usr/bin/env bash
# Read live AMC state from the V80 over PCIe BAR4.  Run with sudo:
#     sudo bash examples/15_amc_ping/sw/amc_test.sh [BDF]
#
# coyote_driver claims BAR4 (pci_request_regions), blocking the sysfs mmap, and
# /dev/mem is STRICT_DEVMEM-blocked — so we detach coyote_driver, force the PCI
# COMMAND memory/bus-master bits, dump AMC shared memory, then restore the
# driver. The AMC runs on the FPGA R5 independently, so its DDR4 data persists.
#
# Must run as root; do NOT use nested sudo here (a nested sudo between setpci
# and the mmap lets the driver's async remove re-clear memory-decode -> EINVAL).
set -u
[ "$(id -u)" -eq 0 ] || { echo "run me with sudo"; exit 1; }
BDF="${1:-0000:61:00.0}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"

had_drv=0
if lsmod | grep -q "^coyote_driver"; then had_drv=1; rmmod coyote_driver; fi

# The BAR needs a few seconds to settle after the driver detaches before the
# sysfs mmap succeeds; this settle must happen BEFORE the first read attempt.
sleep 3
ok=0
for _ in 1 2 3; do
  setpci -s "${BDF#0000:}" COMMAND=0x06 >/dev/null 2>&1 || true
  if python3 "$HERE/amc_dump.py" "$BDF"; then ok=1; break; fi
  sleep 2
done
[ "$ok" = 1 ] || echo "amc_test: could not read BAR4 after retries"

if [ "$had_drv" = 1 ]; then
  insmod "$ROOT/driver/build/coyote_driver_versal.ko" 2>/dev/null \
    || insmod "$ROOT/driver/build/coyote_driver.ko" 2>/dev/null || true
  echo "(coyote_driver restored)"
fi
