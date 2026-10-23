#!/usr/bin/env bash
######################################################################################
# Coyote V80 APU phase A3: build the Linux kernel, its device tree and a busybox initramfs.
#
#   bash fw/apu_v80/a3/build_a3.sh            # run on the HOST, not inside versal-shell
#
# Sources: linux-xlnx at tag xilinx-v2025.1 (same release as the A2 TF-A/U-Boot), cloned
# under $APU_SW_DIR (default /scratch/anubhav/apu_sw). busybox is the static aarch64 musl
# build from nixpkgs (a binary-cache fetch, no compile).
# Outputs: fw/apu_v80/a3/build/{Image,v80-coyote-apu-linux.dtb,initramfs.cpio}
#
# Needs no PDI change: boot_a3.py pushes these into DDR over PCIe and boots them from the
# A2 U-Boot prompt. Same two-stage layout as a2/build_a2.sh.
######################################################################################
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
W="${APU_SW_DIR:-/scratch/anubhav/apu_sw}"
OUT="$HERE/build"
TAG=xilinx-v2025.1

if [[ -z "${_A3_INNER:-}" ]]; then
    mkdir -p "$W"
    [[ -d "$W/linux-xlnx/.git" ]] || \
        git clone --depth 1 --branch "$TAG" https://github.com/Xilinx/linux-xlnx.git "$W/linux-xlnx"
    EXTRA=""
    for pkg in bison flex bc; do
        p=$(nix-build '<nixpkgs>' -A "$pkg" --no-out-link | tail -1)
        EXTRA="$p/bin:$EXTRA"
    done
    BUSYBOX=$(nix-build '<nixpkgs>' -A pkgsCross.aarch64-multiplatform-musl.pkgsStatic.busybox \
        --no-out-link | tail -1)/bin/busybox
    exec versal-shell -c "export LD_LIBRARY_PATH=/usr/lib64:\$LD_LIBRARY_PATH; \
        export _A3_INNER=1 A3_EXTRA_PATH='$EXTRA' A3_BUSYBOX='$BUSYBOX' APU_SW_DIR='$W'; \
        bash '$HERE/build_a3.sh'"
fi

export PATH="$A3_EXTRA_PATH$PATH"
LX=/share/xilinx/2025.1/gnu/aarch64/lin/aarch64-linux/bin/aarch64-linux-gnu-
KSRC="$W/linux-xlnx"
KB="$OUT/linux"
JOBS=$(nproc)
KMAKE=(make -C "$KSRC" O="$KB" ARCH=arm64 CROSS_COMPILE="$LX" -j"$JOBS")
mkdir -p "$OUT" "$KB"

echo "*** [1/3] kernel (xilinx_defconfig + linux.fragment)"
"${KMAKE[@]}" xilinx_defconfig
"$KSRC/scripts/kconfig/merge_config.sh" -m -O "$KB" "$KB/.config" "$HERE/linux.fragment"
"${KMAKE[@]}" olddefconfig
# Fail if a fragment line was silently overridden by a select/depends.
while read -r line; do
    case "$line" in
        CONFIG_*=*)            grep -qx "$line" "$KB/.config" || { echo "fragment not honoured: $line"; exit 1; } ;;
        "# CONFIG_"*" is not set") sym=${line#\# }; sym=${sym%% *}
                               ! grep -q "^$sym=" "$KB/.config" || { echo "fragment not honoured: $line"; exit 1; } ;;
    esac
done < "$HERE/linux.fragment"
"${KMAKE[@]}" Image     # also builds usr/gen_init_cpio (for the built-in default initramfs)
cp "$KB/arch/arm64/boot/Image" "$OUT/Image"

echo "*** [2/3] device tree"
"$KB/scripts/dtc/dtc" -I dts -O dtb -o "$OUT/v80-coyote-apu-linux.dtb" "$HERE/v80-coyote-apu-linux.dts"

echo "*** [3/3] initramfs (busybox $A3_BUSYBOX + a72_vfpga)"
# On-target vFPGA + host-mailbox utility. Static (the initramfs has no shared libc);
# glibc -static is fine here — it needs only the kernel, not busybox's musl.
"${LX}gcc" -static -O2 -Wall -Wextra -o "$OUT/a72_vfpga" "$HERE/rootfs/a72_vfpga.c"
cat > "$OUT/initramfs.list" <<EOF
dir /dev 0755 0 0
nod /dev/console 0600 0 0 c 5 1
dir /proc 0755 0 0
dir /sys 0755 0 0
dir /tmp 1777 0 0
dir /root 0700 0 0
dir /etc 0755 0 0
dir /bin 0755 0 0
dir /sbin 0755 0 0
dir /usr 0755 0 0
dir /usr/bin 0755 0 0
dir /usr/sbin 0755 0 0
file /bin/busybox $A3_BUSYBOX 0755 0 0
slink /bin/sh busybox 0777 0 0
file /init $HERE/rootfs/init 0755 0 0
file /etc/profile $HERE/rootfs/profile 0644 0 0
file /usr/bin/a72_vfpga $OUT/a72_vfpga 0755 0 0
EOF
"$KB/usr/gen_init_cpio" "$OUT/initramfs.list" > "$OUT/initramfs.cpio"

ls -la "$OUT"/Image "$OUT"/v80-coyote-apu-linux.dtb "$OUT"/initramfs.cpio
