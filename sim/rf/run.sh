#!/bin/bash
# Stand-alone xsim testbench for the RF service (hw/hdl/rf)
# usage: run.sh <lynx_pkg.sv of any Coyote build>
# Needs Vivado (xvlog, xelab, xsim) in the PATH; prints each check, then PASS or FAIL.
set -e
PKG=$(realpath "$1")
H=$(realpath "$(dirname "$0")/../../hw/hdl")
TB=$(realpath "$(dirname "$0")/tb_rf.sv")
GLBL=$(dirname "$(which vivado)")/../data/verilog/src/glbl.v
W=$(mktemp -d)
cd "$W"
xvlog -sv "$PKG" $H/pkg/axi_intf.sv $H/rf/*.sv "$TB" "$GLBL" > xvlog.log 2>&1 || { grep ERROR xvlog.log; exit 1; }
xelab -L xpm -L unisims_ver tb_rf glbl -s sim -timescale 1ns/1ps > xelab.log 2>&1 || { grep ERROR xelab.log; exit 1; }
xsim sim -R > xsim.log 2>&1 || true
grep -E "^ok|^ERROR|ERROR:|^PASS|^FAIL|Fatal" xsim.log
echo "(logs in $W)"
