# All static layer clocks are generated in the static BD (PS pl_clk0 -> clocking wizard), so no external clocks

# Debug
connect_debug_port inst_static/inst_debug_hub/inst/xsdbm/clk [get_nets inst_static/dclk]
