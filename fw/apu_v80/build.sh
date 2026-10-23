#!/usr/bin/env bash
# Build the A72 first-light ELF.
#
# MUST run inside versal-shell: the Xilinx gcc wrappers are #!/bin/bash scripts
# and NixOS has no /bin/bash.
#
#   versal-shell -c 'bash fw/apu_v80/build.sh'
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CC=${CC:-/share/xilinx/2025.1/gnu/aarch64/lin/aarch64-none/bin/aarch64-none-elf-gcc}
OUT="$HERE/build"
mkdir -p "$OUT"
# -Wl,-z,max-page-size=4096 is REQUIRED: the default 64 KB alignment back-aligns
# the LOAD segment to 0xFFFC0000, below the intended 0xFFFC1000 base.
"$CC" -march=armv8-a -O2 -ffreestanding -nostdlib -nostartfiles \
      -Wall -Wextra \
      -Wl,-z,max-page-size=4096 \
      -Wl,-T,"$HERE/src/lscript.ld" \
      -o "$OUT/apu_first_light.elf" \
      "$HERE/src/start.S" "$HERE/src/first_light.c"
echo "built $OUT/apu_first_light.elf"
