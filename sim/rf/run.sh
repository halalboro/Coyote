#!/bin/bash
# Stand-alone xsim testbenches for the RF service (hw/hdl/rf) and the capture logic of Example 13
# usage: run.sh <lynx_pkg.sv of any Coyote build>
# Needs Vivado (xvlog, xelab, xsim) in the PATH; prints each check, then PASS or FAIL for each testbench.
set -e
PKG=$(realpath "$1")
H=$(realpath "$(dirname "$0")/../../hw/hdl")
TB=$(realpath "$(dirname "$0")/tb_rf.sv")
GLBL=$(dirname "$(which vivado)")/../data/verilog/src/glbl.v
W=$(mktemp -d)
cd "$W"
C=$H/../../examples/13_rf_capture/hw/src/hdl/rf_capture.sv
xvlog -sv "$PKG" $H/pkg/axi_intf.sv $H/rf/*.sv "$C" "$TB" "$(dirname "$TB")/tb_capture.sv" "$GLBL" > xvlog.log 2>&1 || { grep ERROR xvlog.log; exit 1; }
for top in tb_rf tb_capture; do
    echo "== $top"
    xelab -L xpm -L unisims_ver $top glbl -s sim_$top -timescale 1ns/1ps > xelab_$top.log 2>&1 || { grep ERROR xelab_$top.log; exit 1; }
    xsim sim_$top -R > xsim_$top.log 2>&1 || true
    grep -E "^ok|^ERROR|ERROR:|^PASS|^FAIL|Fatal" xsim_$top.log
done
echo "(logs in $W)"
