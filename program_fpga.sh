echo "running vivado script"
echo "programming $1"
if [ -n "$2" ]
  then
    cd $2
fi
echo "$PWD"

if [ -z "$1" ]; then
  echo "Usage: $0 <bitstream> [dir]"
  echo "  <bitstream> may be a bare name (cyt_top), a path, and may include"
  echo "  the .bit/.pdi extension. Bare names are looked up in ./bitstreams/."
  exit 1
fi

# Resolve the bitstream to a path stem WITHOUT extension -- auto_fpga.tcl
# appends .pdi/.bit/.ltx itself. Accept all the forms people actually type:
#   cyt_top                 -> bitstreams/cyt_top   (bare name, historic usage)
#   bitstreams/cyt_top.bit  -> bitstreams/cyt_top   (full path with extension)
STEM="${1%.pdi}"
STEM="${STEM%.bit}"
if [ ! -f "${STEM}.bit" ] && [ ! -f "${STEM}.pdi" ]; then
  if [ -f "bitstreams/${STEM}.bit" ] || [ -f "bitstreams/${STEM}.pdi" ]; then
    STEM="bitstreams/${STEM}"
  else
    echo "ERROR: no .bit or .pdi found for '$1'"
    echo "  tried: ${STEM}.{bit,pdi} and bitstreams/${STEM}.{bit,pdi}"
    exit 1
  fi
fi
echo "Bitstream stem: $STEM"

# Auto-detect FPGA type from the RESOLVED stem:
#   - a .pdi on disk, or "v80" in the path -> V80
#   - else -> UltraScale+
# This must run after resolution; testing the raw argument misses the
# bitstreams/ prefix and silently falls through to UltraScale+.
IS_V80=0
if [[ $STEM == *"v80"* ]]; then
  IS_V80=1
elif [ -f "${STEM}.pdi" ] && [ ! -f "${STEM}.bit" ]; then
  IS_V80=1
fi

# Pick the driver .ko built for the matching platform.
# These are produced by build_drivers.sh (one-time, or after driver source changes).
if [[ $IS_V80 -eq 1 ]]; then
  KO=driver/build/coyote_driver_versal.ko
else
  KO=driver/build/coyote_driver_ultrascale.ko
fi
if [ ! -f "$KO" ]; then
  echo "ERROR: $KO not found. Run ./build_drivers.sh to build both driver flavors."
  exit 1
fi

# Set BDF based on host and FPGA type
host=`uname -a`
if [[ $host == *"rose"* ]]; then
  if [[ $IS_V80 -eq 1 ]]; then
    BDF="61:00.0"   # V80 on rose
  else
    BDF="c1:00.0"   # U280 on rose
  fi
else
  BDF="e1:00.0"
fi

# Remove Coyote driver if loaded (graceful DMA shutdown)
if lsmod | grep -q "^coyote_driver"; then
  sudo rmmod coyote_driver
fi

# Remove AMI driver if loaded — needed when programming the V80,
# since rose alternates between coyote_driver and ami (AVED tooling).
# Harmless on hosts without AMI.
if lsmod | grep -q "^ami"; then
  sudo rmmod ami
fi

sudo bash sw/util/hot_reset.sh "$BDF"

# Program the FPGA over JTAG via auto_fpga.tcl.
#
# NOTE: /scratch/anubhav/run_vivado.sh is an *environment launcher* (it execs
# into versal-shell for Vivado 2025.1) -- it is NOT a programming script, and
# calling it bare just drops you into an interactive shell without ever
# programming anything. It must be given `-c "<command>"`.
#
# Version separation:
#   V80 (.pdi) -> Vivado 2025.1, via run_vivado.sh -c
#   U280 (.bit) -> Vivado 2023.2, via xilinx-shell -c
#
# auto_fpga.tcl takes the bitstream path WITHOUT an extension; it appends
# .pdi/.bit/.ltx itself and picks the right JTAG cable per card. $STEM was
# resolved above.
BITSTEM="$STEM"
TCL="$PWD/auto_fpga.tcl"

if [ ! -f "$TCL" ]; then
  echo "ERROR: $TCL not found."
  exit 1
fi

if [[ $IS_V80 -eq 1 ]]; then
  /scratch/anubhav/run_vivado.sh -c \
    "vivado -mode batch -source '$TCL' -tclargs '$BITSTEM'" || exit 1
else
  xilinx-shell -c \
    "vivado -mode batch -source '$TCL' -tclargs '$BITSTEM'" || exit 1
fi

sudo bash sw/util/hot_reset.sh "$BDF"

if [[ $IS_V80 -eq 1 ]]; then
  # V80: no IP assigned yet, RDMA/TCP not yet supported on V80 in Coyote.
  echo "V80 bitstream — installing host driver (no IP/MAC; networking not configured)."
  sudo insmod "$KO"
  sudo sysctl -w vm.nr_hugepages=1024
elif [[ $1 == *"rdma"* ]] || [[ $1 == *"tcp"* ]]; then
  # Network bitstream (RDMA or TCP) on UltraScale+
  if [[ $1 == *"tcp"* ]]; then
    echo "TCP bitstream."
    sudo modprobe ice 2>/dev/null
    sleep 2
  else
    echo "RDMA bitstream."
  fi

  if [[ $host == *"clara"* ]]; then
    echo "Installing driver for clara."
    sudo insmod "$KO" ip_addr=0x0A000002 mac_addr=000A350E24F2
    sudo sysctl -w vm.nr_hugepages=1024
  elif [[ $host == *"amy"* ]]; then
    echo "Installing driver for amy."
    sudo insmod "$KO" ip_addr=0x0A000001 mac_addr=000A350E24D6
    sudo sysctl -w vm.nr_hugepages=1024
  elif [[ $host == *"rose"* ]]; then
    echo "Installing driver for rose."
    sudo insmod "$KO" ip_addr=0x0A000003 mac_addr=000A350E24E6
    sudo sysctl -w vm.nr_hugepages=1024
  fi
else
  echo "Host bitstream."
  sudo insmod "$KO"
  sudo sysctl -w vm.nr_hugepages=1024
fi

# Record who programmed the FPGA (used by monitoring dashboard)
echo "$(whoami)" > /tmp/fpga_programmed_by
