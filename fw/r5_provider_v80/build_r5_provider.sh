#!/usr/bin/env bash
######################################################################################
# Coyote Example 15 — R5-0 co-processor provider firmware build (freestanding).
#
# Bare-metal Cortex-R5 image (no BSP, no XSA): links start.S + our service loop +
# the transport-independent provider library + the R5 MMIO transport. Modeled on
# fw/apu_v80/build.sh.
#
# Usage:  build_r5_provider.sh <output_elf_path>
# Env:    CC  — override the armr5 gcc (default = Vitis 2025.1 on /share). A bare
#              CC=gcc leaked from a nix-shell/stdenv is ignored (see below).
######################################################################################
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <output_elf_path>" >&2
    exit 1
fi
OUT_ELF="$1"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CYT_DIR="$(cd "$HERE/../.." && pwd)"
PROV="$CYT_DIR/sw/firmware/coprocessor"

# Running `make bitgen` inside the coyote nix-shell exports CC=gcc (stdenv), and
# that host x86 gcc rejects -mcpu=cortex-r5 / -mfpu=vfpv3-d16. Only honor $CC when
# it is itself an ARM bare-metal cross-compiler; otherwise use the armr5 default.
case "${CC:-}" in
    *armr5-none-eabi-gcc | *arm-none-eabi-gcc) ;;  # explicit cross override, keep
    *) CC=/share/xilinx/2025.1/gnu/armr5/lin/gcc-arm-none-eabi/bin/armr5-none-eabi-gcc ;;
esac
if ! command -v "$CC" >/dev/null 2>&1 && [[ ! -x "$CC" ]]; then
    echo "ERROR: armr5 gcc not found at '$CC' (override with CC=...)" >&2
    exit 1
fi

mkdir -p "$(dirname "$OUT_ELF")"

"$CC" \
    -mcpu=cortex-r5 -mfloat-abi=hard -mfpu=vfpv3-d16 \
    -O2 -ffreestanding -nostdlib -nostartfiles \
    -Wall -Wextra \
    -fno-tree-loop-distribute-patterns \
    -I "$PROV" -I "$HERE/src" \
    -Wl,-z,max-page-size=4096 \
    -Wl,-T,"$HERE/src/lscript.ld" \
    -o "$OUT_ELF" \
    "$HERE/src/start.S" \
    "$HERE/src/main.c" \
    "$HERE/src/libc_shim.c" \
    "$HERE/src/identity.c" \
    "$PROV/provider.c" \
    "$PROV/provider_transport_r5.c"

echo "*** R5 provider firmware built: $OUT_ELF ($(stat -c %s "$OUT_ELF") bytes)"
