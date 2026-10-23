#!/usr/bin/env bash
######################################################################################
# Coyote V80 APU phase A2: build TF-A (BL31) + U-Boot + the board device tree.
#
#   bash fw/apu_v80/a2/build_a2.sh            # run on the HOST, not inside versal-shell
#
# Sources: Xilinx forks at tag xilinx-v2025.1 (matches the 2025.1 PLM/XilPM API that
# TF-A talks to over IPI0), cloned under $APU_SW_DIR (default /scratch/anubhav/apu_sw).
# Outputs: fw/apu_v80/a2/build/{bl31.elf,u-boot.elf,v80-coyote-apu.dtb}
#
# Two-stage on purpose: the host stage realizes flex/bison/bc from nix (U-Boot's kconfig
# needs them; versal-shell lacks them), then re-execs inside versal-shell, whose FHS env
# the Xilinx gcc wrappers (#!/bin/bash scripts) require.
######################################################################################
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
W="${APU_SW_DIR:-/scratch/anubhav/apu_sw}"
OUT="$HERE/build"
TAG=xilinx-v2025.1

if [[ -z "${_A2_INNER:-}" ]]; then
    mkdir -p "$W"
    for r in arm-trusted-firmware u-boot-xlnx; do
        [[ -d "$W/$r/.git" ]] || git clone --depth 1 --branch "$TAG" "https://github.com/Xilinx/$r.git" "$W/$r"
    done
    EXTRA=""
    for pkg in bison flex bc; do
        p=$(nix-build '<nixpkgs>' -A "$pkg" --no-out-link | tail -1)
        EXTRA="$p/bin:$EXTRA"
    done
    exec versal-shell -c "export LD_LIBRARY_PATH=/usr/lib64:\$LD_LIBRARY_PATH; \
        export _A2_INNER=1 A2_EXTRA_PATH='$EXTRA' APU_SW_DIR='$W'; bash '$HERE/build_a2.sh'"
fi

export PATH="$A2_EXTRA_PATH$PATH"
GNU=/share/xilinx/2025.1/gnu/aarch64/lin
BM="$GNU/aarch64-none/bin/aarch64-none-elf-"     # bare metal: TF-A
LX="$GNU/aarch64-linux/bin/aarch64-linux-gnu-"   # U-Boot
JOBS=$(nproc)
mkdir -p "$OUT"

echo "*** [1/3] TF-A BL31 (PLAT=versal, console=pl011 UART0, default OCM placement 0xFFFE0000)"
# Default placement is safe in the current design: nothing else uses OCM (no ocm_mbx, R5
# provider runs from TCM, PS_USE_S_AXI_LPD 0). If EN_AMC's OCM mailbox at 0xFFFFF000 ever
# returns, rebuild with VERSAL_ATF_MEM_BASE=0xFFFE0000 VERSAL_ATF_MEM_SIZE=0x1F000.
make -C "$W/arm-trusted-firmware" -j"$JOBS" \
    CROSS_COMPILE="$BM" PLAT=versal RESET_TO_BL31=1 VERSAL_CONSOLE=pl011 bl31
cp "$W/arm-trusted-firmware/build/versal/release/bl31/bl31.elf" "$OUT/bl31.elf"

echo "*** [2/3] U-Boot (xilinx_versal_virt_defconfig + uboot.fragment)"
UB="$OUT/uboot"
make -C "$W/u-boot-xlnx" O="$UB" CROSS_COMPILE="$LX" xilinx_versal_virt_defconfig
cat "$HERE/uboot.fragment" >> "$UB/.config"
make -C "$W/u-boot-xlnx" O="$UB" CROSS_COMPILE="$LX" olddefconfig
make -C "$W/u-boot-xlnx" O="$UB" CROSS_COMPILE="$LX" -j"$JOBS"
cp "$UB/u-boot" "$OUT/u-boot.elf"

echo "*** [3/3] device tree"
"$UB/scripts/dtc/dtc" -I dts -O dtb -o "$OUT/v80-coyote-apu.dtb" "$HERE/v80-coyote-apu.dts"

ls -la "$OUT"/bl31.elf "$OUT"/u-boot.elf "$OUT"/v80-coyote-apu.dtb
