#!/bin/bash
# Stand-alone xsim testbench for the DDR stripe (hw/hdl/stripe/axi_stripe_rd.sv, axi_stripe_wr.sv)
# usage: run.sh <lynx_pkg.sv of a build with EN_MEM_STRIPE> [stripe fragment size]
# e.g.   run.sh examples/01_hello_world/hw/build/<project>_shell/hdl/lynx_pkg.sv 1024
# Needs Vivado (xvlog, xelab, xsim) in the PATH; prints PASS or FAIL.
set -e
PKG=$(realpath "$1")
FRAG=${2:-1024}
H=$(realpath "$(dirname "$0")/../../hw/hdl")
TB=$(realpath "$(dirname "$0")/tb_stripe.sv")
GLBL=$(dirname "$(which vivado)")/../data/verilog/src/glbl.v
W=$(mktemp -d)
cd "$W"
sed "s/STRIPE_FRAG_SIZE = [0-9]*/STRIPE_FRAG_SIZE = $FRAG/" "$PKG" > lynx_pkg.sv
xvlog -sv lynx_pkg.sv $H/pkg/lynx_intf.sv $H/common/queues/fifo.sv $H/common/queues/queue_meta.sv \
    $H/stripe/axi_stripe_rd.sv $H/stripe/axi_stripe_wr.sv "$TB" "$GLBL" > xvlog.log 2>&1 || { grep ERROR xvlog.log; exit 1; }
xelab -L xpm tb_stripe glbl -s sim -timescale 1ns/1ps > xelab.log 2>&1 || { grep ERROR xelab.log; exit 1; }
xsim sim -R > xsim.log 2>&1 || true
grep -E "^round|^max|^bursts|ERROR:|^PASS|^FAIL" xsim.log
echo "(logs in $W)"
