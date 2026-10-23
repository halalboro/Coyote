#!/usr/bin/env bash
######################################################################################
# Coyote V80 APU phase A2: recombine an existing bitstream's base PDI with the A2 APU
# payload (DTB + TF-A + U-Boot). No bitgen. Writes bitstreams/cyt_top_a2.pdi and leaves
# the A0 image (cyt_top.pdi) untouched.
#
#   bash fw/apu_v80/a2/recombine_a2.sh examples/15_amc_ping/hw/build_apu
#   bash program_fpga.sh bitstreams/cyt_top_a2      # from inside that build dir
#
# APU image layout is the standard Versal Linux boot chain:
#   raw DTB at 0x1000 (U-Boot's CONFIG_XILINX_OF_BOARD_DTB_ADDR), BL31 at EL3 with
#   TrustZone, U-Boot at EL2. The PLM builds the ATF handoff table from the exception
#   levels. The same subsystem id 0x1c000000 + delay_handoff as the proven A0 image.
######################################################################################
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BD="$(cd "${1:?usage: recombine_a2.sh <hw build dir>}" && pwd)"
SRC="$HERE/build"
DST="$BD/bitstreams/static_files/a2"

for f in "$BD/bitstreams/cyt_top_base.pdi" "$BD/bitstreams/static_files/r5_provider.elf" \
         "$SRC/bl31.elf" "$SRC/u-boot.elf" "$SRC/v80-coyote-apu.dtb"; do
    [[ -f "$f" ]] || { echo "ERROR: missing $f" >&2; exit 1; }
done
mkdir -p "$DST"
cp "$SRC/bl31.elf" "$SRC/u-boot.elf" "$SRC/v80-coyote-apu.dtb" "$DST/"

cat > "$BD/bitstreams/cyt_top_a2.bif" <<BIF
all:
{
    image
    {
        { type=bootimage, file=bitstreams/cyt_top_base.pdi }
    }
    image
    {
        id = 0x1c000000, name=rpu_subsystem, delay_handoff
        { core=r5-0, file=bitstreams/static_files/r5_provider.elf }
    }
    image
    {
        id = 0x1c000000, name=apu_subsystem, delay_handoff
        { type=raw, load=0x1000, file=bitstreams/static_files/a2/v80-coyote-apu.dtb }
        { core=a72-0, exception_level=el-3, trustzone, file=bitstreams/static_files/a2/bl31.elf }
        { core=a72-0, exception_level=el-2, file=bitstreams/static_files/a2/u-boot.elf }
    }
}
BIF

cd "$BD"
versal-shell -c "export LD_LIBRARY_PATH=/usr/lib64:\$LD_LIBRARY_PATH; cd '$BD' && \
    bootgen -arch versal -image bitstreams/cyt_top_a2.bif -w -o bitstreams/cyt_top_a2.pdi"
[[ -f bitstreams/cyt_top.ltx ]] && cp bitstreams/cyt_top.ltx bitstreams/cyt_top_a2.ltx
ls -la bitstreams/cyt_top_a2.pdi
