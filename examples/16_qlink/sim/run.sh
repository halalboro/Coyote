#!/usr/bin/env bash
# Standalone simulation -- no GT, no Coyote, no bitstream.
#
#   lint_elab      ELABORATES both real hierarchies -- shell and vFPGA
#   tb_qlink_scram scrambler: self-sync round-trip, DC balance on all-zeros
#   tb_qlink_align ALIGN pattern: unique rotation, DC balance, transition-rich
#   tb_qlink_raw   qlink_framer_raw: aligner converges from all 32 bit offsets
#   tb_qlink       protocol: framing, checksums, rounds, misalignment recovery
#   tb_qlink_cdc   the clock crossing, at its real 1012-bit width
#   tb_qlink_sys   predicted one-way latency, 10.3125 vs 15.625 Gbps
#
# Run this before every bitgen. All three are seconds, a bitgen is hours.
set -e
cd "$(dirname "$0")"
rm -rf xsim.dir *.log *.jou *.pb 2>/dev/null || true

GLBL="$XILINX_VIVADO/data/verilog/src/glbl.v"

# FIRST, because it is the cheapest and it catches the class of error that has
# actually reached a bitgen: a module in the middle of a hierarchy missing ports
# its neighbours were given. xvlog alone does NOT catch that -- it parses, and
# port mismatches are an elaboration error.
echo "########## lint_elab: does the design still connect together"
xvlog -sv -L xpm -i ../hw/src lint_elab.sv \
      ../hw/src/hdl/qlink_link_tx.sv \
      ../hw/src/hdl/qlink_link_rx.sv \
      ../hw/src/hdl/qlink_cdc_event.sv \
      ../hw/src/hdl/qlink_phy_shim.sv \
      ../../../hw/hdl/qlink/qlink_framer_raw.sv \
      ../../../hw/hdl/qlink/qlink_scrambler.sv \
      ../../../hw/hdl/qlink/qlink_framer.sv \
      ../../../hw/hdl/qlink/qlink_phy_gty.sv \
      ../../../hw/hdl/qlink/qlink_gty_wrapper.sv \
      "$GLBL"
xelab -L xpm -L unisims_ver -timescale 1ns/1ps lint_shell_tb glbl -s lint_shell
xelab -L xpm -L unisims_ver -timescale 1ns/1ps lint_user_tb  glbl -s lint_user
echo "  both hierarchies elaborate"

echo
echo "########## tb_qlink_scram: scrambler"
xvlog -sv tb_qlink_scram.sv ../../../hw/hdl/qlink/qlink_scrambler.sv
xelab -debug typical tb_qlink_scram -s tb_scram
xsim tb_scram -R

echo
echo "########## tb_qlink_align: ALIGN pattern properties"
xvlog -sv tb_qlink_align.sv
xelab tb_qlink_align -s tb_align
xsim tb_align -R

echo
echo "########## tb_qlink_raw: alignment from all 32 offsets"
xvlog -sv tb_qlink_raw.sv ../../../hw/hdl/qlink/qlink_scrambler.sv \
          ../../../hw/hdl/qlink/qlink_framer_raw.sv
xelab -debug typical tb_qlink_raw -s tb_raw
xsim tb_raw -R

echo
echo "########## tb_qlink: protocol"
xvlog -sv tb_qlink.sv \
      ../hw/src/hdl/qlink_link_tx.sv \
      ../hw/src/hdl/qlink_link_rx.sv \
      ../../../hw/hdl/qlink/qlink_framer_raw.sv \
      ../../../hw/hdl/qlink/qlink_scrambler.sv
xelab -debug typical tb_qlink -s tb_qlink_sim
xsim tb_qlink_sim -R

echo
echo "########## tb_qlink_cdc: clock crossing"
# -L xpm and glbl are needed because qlink_cdc_event wraps xpm_cdc_handshake.
xvlog -sv -L xpm tb_qlink_cdc.sv ../hw/src/hdl/qlink_cdc_event.sv "$GLBL"
xelab -debug typical -L xpm -L unisims_ver -timescale 1ns/1ps tb_qlink_cdc glbl -s tb_cdc
xsim tb_cdc -R

echo
echo "########## tb_qlink_sys: system latency model"
xvlog -sv tb_qlink_sys.sv
xelab -debug typical tb_qlink_sys -s tb_sys
xsim tb_sys -R
