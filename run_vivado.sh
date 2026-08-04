#!/bin/bash
# Pass-through invocation of auto_fpga.tcl. Caller passes a path *without*
# the .bit/.pdi extension; auto_fpga.tcl picks the right one.
vivado -mode tcl -source ./auto_fpga.tcl -tclargs "$1"
