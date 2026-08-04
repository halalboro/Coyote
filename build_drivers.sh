#!/bin/bash
# Build both Coyote driver flavors and stash them under distinct names so
# program_fpga.sh can pick the right one without rebuilding per platform.
#
# Run this once after cloning, and again whenever driver/ source changes.
#
# NixOS note: there is no /lib/modules/$(uname -r)/build, so we resolve the
# kernel-dev output in /nix/store and pass it as KERNELDIR. We invoke make
# inside `nix-shell -p gcc14 gnumake` so the toolchain matches the one that
# built the running kernel.

set -e

cd "$(dirname "$0")"

if [ ! -d driver ]; then
  echo "ERROR: no driver/ directory in $PWD"
  exit 1
fi

KREL=$(uname -r)

# Locate the kernel headers/build tree in /nix/store.
# Prefer an exact match for the running kernel release; pick the newest if multiple.
KERNELDIR=$(ls -dt /nix/store/*-linux-*-dev/lib/modules/"$KREL"/build 2>/dev/null | head -n1)

if [ -z "$KERNELDIR" ] || [ ! -f "$KERNELDIR/Makefile" ]; then
  echo "ERROR: could not find kernel headers for $KREL in /nix/store."
  echo "  Build them with:"
  echo "    nix build --no-link --print-out-paths .#nixosConfigurations.<host>.config.boot.kernelPackages.kernel.dev"
  exit 1
fi

echo "Using KERNELDIR=$KERNELDIR"

# Stash builds in a sibling dir so `make clean` (which wipes driver/build/)
# can't remove the previous platform's .ko between iterations.
STASH=$(mktemp -d)
trap 'rm -rf "$STASH"' EXIT

build_one() {
  local platform=$1
  local outname=$2
  echo "=== Building driver for TARGET_PLATFORM=$platform ==="
  nix-shell -p gcc14 gnumake --run "make -C driver clean && make -C driver TARGET_PLATFORM=$platform KERNELDIR=$KERNELDIR"
  cp driver/build/coyote_driver.ko "$STASH/$outname"
  echo "  -> staged $outname"
}

build_one versal          coyote_driver_versal.ko
build_one ultrascale_plus coyote_driver_ultrascale.ko

# Move both .ko files into driver/build/ now that all builds are done.
mkdir -p driver/build
cp "$STASH/coyote_driver_versal.ko"      driver/build/coyote_driver_versal.ko
cp "$STASH/coyote_driver_ultrascale.ko"  driver/build/coyote_driver_ultrascale.ko
# Keep a generic .ko in place too, so anything still pointing at the
# default name keeps working (defaults to ultrascale_plus, the prior behavior).
cp "$STASH/coyote_driver_ultrascale.ko"  driver/build/coyote_driver.ko

echo
echo "Done. Driver binaries:"
ls -l driver/build/coyote_driver*.ko
