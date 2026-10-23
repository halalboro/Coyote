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

# A candidate kernel-dev must match the running kernel on BOTH the release and
# the .config. Release alone is not enough: building against e.g. 7.2.2-dev while
# 7.2.6 runs yields a module whose vermagic insmod refuses.
config_matches() {
  local build=$1
  [ -f "$build/.config" ] || return 1
  [ -r /proc/config.gz ] || return 0   # cannot compare; accept on release match alone
  [ "$(sha256sum "$build/.config" | awk '{print $1}')" \
    = "$(zcat /proc/config.gz | sha256sum | awk '{print $1}')" ]
}

find_kerneldir() {
  local d
  for d in $(ls -dt /nix/store/*-linux-*-dev/lib/modules/"$KREL"/build 2>/dev/null); do
    [ -f "$d/Makefile" ] || continue
    config_matches "$d" || { echo "  (skipping $d: .config differs from running kernel)" >&2; continue; }
    echo "$d"
    return 0
  done
  return 1
}

KERNELDIR=$(find_kerneldir || true)

# Nothing in the store yet? Resolve it from the flake the running system was
# actually built from -- /run/booted-system/flake, pinned in the store by
# modules/register-flake.nix. /nix/store is host-local, so every host needs this
# fetch once after a kernel bump, even though the derivation is identical.
#
# Do NOT use a local checkout of doctor-cluster-config here: it drifts from what
# is deployed. In Oct 2026 the checkout still pinned a custom SEV-SNP kernel
# (6.9) while the booted flake had dropped it for the stock 7.2.6, so
# `nix build .#nixosConfigurations.<host>...` from the checkout silently produced
# headers for an entirely different kernel.
if [ -z "$KERNELDIR" ]; then
  BOOTED_FLAKE=$(readlink -f /run/booted-system/flake 2>/dev/null || true)
  if [ -n "$BOOTED_FLAKE" ] && [ -e "$BOOTED_FLAKE" ]; then
    echo "No kernel headers for $KREL in /nix/store; fetching them from the booted flake:"
    echo "  $BOOTED_FLAKE"
    echo "  (a few hundred MiB of downloads; normally substituted, not compiled)"
    nix build --no-link --print-out-paths \
      "path:$BOOTED_FLAKE#nixosConfigurations.$(hostname).config.boot.kernelPackages.kernel.dev" \
      >/dev/null
    KERNELDIR=$(find_kerneldir || true)
  fi
fi

if [ -z "$KERNELDIR" ] || [ ! -f "$KERNELDIR/Makefile" ]; then
  echo "ERROR: could not find or build kernel headers for $KREL."
  echo "  The running system's own flake is the only reliable source:"
  echo "    nix build --no-link --print-out-paths \\"
  echo "      \"path:\$(readlink -f /run/booted-system/flake)#nixosConfigurations.\$(hostname).config.boot.kernelPackages.kernel.dev\""
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
  echo "=== Building driver for TARGET_PLATFORM=$platform -> $outname ==="
  # The Makefile emits a platform-named module directly (obj-m := $(MODNAME).o),
  # so the .ko is already called $outname -- no post-build rename needed.
  nix-shell -p gcc14 gnumake --run "make -C driver clean && make -C driver TARGET_PLATFORM=$platform KERNELDIR=$KERNELDIR"
  cp "driver/build/$outname" "$STASH/$outname"
  echo "  -> staged $outname"
}

build_one versal          coyote_driver_versal.ko
build_one ultrascale_plus coyote_driver_ultrascale.ko

# Move both .ko files into driver/build/ now that all builds are done.
# No generic coyote_driver.ko: versal and ultrascale are distinct modules
# (distinct KBUILD_MODNAME / pci_driver name) so they can coexist; a generic
# copy would be a silently wrong-platform driver under a neutral name.
mkdir -p driver/build
rm -f driver/build/coyote_driver.ko   # remove any stale generic from older builds
cp "$STASH/coyote_driver_versal.ko"      driver/build/coyote_driver_versal.ko
cp "$STASH/coyote_driver_ultrascale.ko"  driver/build/coyote_driver_ultrascale.ko

echo
echo "Done. Driver binaries:"
ls -l driver/build/coyote_driver_versal.ko driver/build/coyote_driver_ultrascale.ko
