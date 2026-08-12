#!/usr/bin/env bash
# Standalone simulation -- no GT, no Coyote, no bitstream.
#
#   lint_elab      ELABORATES both real hierarchies -- shell and vFPGA
#   tb_braid       protocol: framing, checksums, rounds, misalignment rejection
#   tb_braid_cdc   the clock crossing, at its real 1012-bit width
#   tb_braid_sys   predicted one-way latency, 10.3125 vs 15.625 Gbps
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
      ../hw/src/hdl/braid_link_tx.sv \
      ../hw/src/hdl/braid_link_rx.sv \
      ../hw/src/hdl/braid_cdc_event.sv \
      ../hw/src/hdl/braid_phy_shim.sv \
      ../../../hw/hdl/braid/braid_framer.sv \
      ../../../hw/hdl/braid/braid_phy_gty.sv \
      ../../../hw/hdl/braid/braid_gty_wrapper.sv \
      "$GLBL"
xelab -L xpm -L unisims_ver -timescale 1ns/1ps lint_shell_tb glbl -s lint_shell
xelab -L xpm -L unisims_ver -timescale 1ns/1ps lint_user_tb  glbl -s lint_user
echo "  both hierarchies elaborate"

echo
echo "########## tb_braid: protocol"
xvlog -sv tb_braid.sv \
      ../hw/src/hdl/braid_link_tx.sv \
      ../hw/src/hdl/braid_link_rx.sv \
      ../../../hw/hdl/braid/braid_framer.sv
xelab -debug typical tb_braid -s tb_braid_sim
xsim tb_braid_sim -R

echo
echo "########## tb_braid_cdc: clock crossing"
# -L xpm and glbl are needed because braid_cdc_event wraps xpm_cdc_handshake.
xvlog -sv -L xpm tb_braid_cdc.sv ../hw/src/hdl/braid_cdc_event.sv "$GLBL"
xelab -debug typical -L xpm -L unisims_ver -timescale 1ns/1ps tb_braid_cdc glbl -s tb_cdc
xsim tb_cdc -R

echo
echo "########## tb_braid_sys: system latency model"
xvlog -sv tb_braid_sys.sv
xelab -debug typical tb_braid_sys -s tb_sys
xsim tb_sys -R
