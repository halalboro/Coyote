#!/bin/bash
# Switch the V80 on rose from Coyote driver back to AMI/AVED tooling.
# Inverse of program_fpga.sh's post-program state.

set -e

cd "$(dirname "$0")"

V80_BDF="61:00.0"
AMI_KO=/share/xilinx/aved/ami.ko

if [ ! -f "$AMI_KO" ]; then
  echo "ERROR: $AMI_KO not found. Is AVED installed on this host?"
  exit 1
fi

if lsmod | grep -q "^coyote_driver"; then
  echo "Removing coyote_driver..."
  sudo rmmod coyote_driver
fi

# Hot-reset so the V80 comes up clean before AMI binds to it.
sudo bash sw/util/hot_reset.sh "$V80_BDF"

if lsmod | grep -q "^ami"; then
  echo "ami already loaded."
else
  echo "Loading ami..."
  sudo insmod "$AMI_KO"
fi

# Sanity check
if command -v ami_tool >/dev/null 2>&1; then
  ami_tool overview
else
  echo "(ami_tool not on PATH — add /share/xilinx/aved/bin to PATH to use it)"
fi
