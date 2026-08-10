#!/usr/bin/env bash
# Standalone protocol simulation -- no GT, no Coyote, no bitstream.
set -e
cd "$(dirname "$0")"
rm -rf xsim.dir *.log *.jou *.pb 2>/dev/null || true
xvlog -sv tb_braid.sv \
      ../hw/src/hdl/braid_link_tx.sv \
      ../hw/src/hdl/braid_link_rx.sv \
      ../../../hw/hdl/braid/braid_framer.sv
xelab -debug typical tb_braid -s tb_braid_sim
xsim tb_braid_sim -R
