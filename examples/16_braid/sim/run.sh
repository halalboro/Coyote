#!/usr/bin/env bash
# Standalone simulation -- no GT, no Coyote, no bitstream.
#
#   tb_braid       protocol: framing, checksums, rounds, misalignment rejection
#   tb_braid_cdc   the clock crossing, at its real 1012-bit width
#   tb_braid_sys   system latency model, pre- vs post-Task-2b
#
# Run this before every bitgen. All three are seconds, a bitgen is hours.
set -e
cd "$(dirname "$0")"
rm -rf xsim.dir *.log *.jou *.pb 2>/dev/null || true

GLBL="$XILINX_VIVADO/data/verilog/src/glbl.v"

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
