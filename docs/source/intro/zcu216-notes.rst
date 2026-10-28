.. _zcu216-notes:

ZCU216 notes (experimental)
=====================================

Introduction
------------------------------------------
The ZCU216 is a Zynq UltraScale+ RFSoC evaluation board. Unlike the Alveo cards, it is not attached to an x86 server over PCIe;
the host is the on-chip ARM processing system (PS). Since the programmable logic is UltraScale+, the shell and dynamic layers
(including the MMU, vFPGAs and user logic) are shared with the Alveo cards; only the static layer, the driver platform layer
and a few build options differ.

.. warning:: Support for the ZCU216 is experimental and has not yet been validated on hardware. Currently, only host streams are supported.

Architecture
------------------------------------------
The static layer exposes the same interface to the shell as on PCIe platforms (``hw/templates/zynq_us_plus/static_top_tmplt.txt``, ``hw/bd/zynq_us_plus/cr_ps.tcl``):

================================================= =============================================================
PCIe platforms (XDMA)                             ZCU216 (PS)
================================================= =============================================================
AXI-Lite BAR (``axi_cnfg``, ``BAR_STAT_CONFIG``)  ``M_AXI_HPM1_FPD``, 1 MB at ``0xB000_0000``
Bypass BAR (``axi_main``, ``BAR_SHELL_CONFIG``)   ``M_AXI_HPM0_FPD``, 256 MB at ``0xA000_0000``
XDMA descriptor bypass (host DMA)                 One AXI DataMover per host channel (``hw/hdl/static/zynq_dma_wrapper.sv``), on the coherent ``S_AXI_HPC0/1_FPD`` ports
MSI-X vectors                                     ``pl_ps_irq0/1`` (GIC SPIs 89-96, 104-111), level-sensitive
PCIe reference clock                              ``pl_clk0`` (100 MHz) and a clocking wizard
================================================= =============================================================

.. note:: The Coyote driver maps user buffers once and never syncs caches explicitly. Host memory is therefore accessed through
    the coherent (HPC) ports, with snoopable AXI cache attributes, and the device must be marked ``dma-coherent`` in the device tree.
    See AR# 69446 for the PS-side requirements of HPC port coherency.

Building the hardware
------------------------------------------
There is no pre-built static layer checkpoint or shell floorplan for the ZCU216, so the full design is built with the static flow.
For example, for Example 7:

.. code-block:: bash

    cd examples/07_perf_fpga/hw && mkdir build && cd build
    cmake ../ -DFDEV_NAME=zcu216 -DBUILD_STATIC=1 -DBUILD_SHELL=0 -DEN_SHELL_PBLOCK=0
    make project && make bitgen

The build produces ``bitstreams/cyt_top.bin``, which can be loaded from Linux.

Building and loading the driver
------------------------------------------
The driver is built for the ARM host, against the kernel running on the board:

.. code-block:: bash

    cd driver && make TARGET_PLATFORM=zynq

The bitstream is loaded and the Coyote device is described to the kernel with a device tree overlay (``driver/dts/coyote_zcu216.dtso``),
which must match the addresses and interrupts of the static layer. Hugepages (2 MB) must be reserved as on other platforms.

.. code-block:: bash

    cp cyt_top.bin /lib/firmware/
    dtc -@ -I dts -O dtb -o coyote_zcu216.dtbo driver/dts/coyote_zcu216.dtso
    mkdir /sys/kernel/config/device-tree/overlays/coyote
    cat coyote_zcu216.dtbo > /sys/kernel/config/device-tree/overlays/coyote/dtbo
    insmod driver/build/coyote_driver.ko

The software library is built as usual on the board; AVX is disabled automatically on ARM.

Supported features
------------------------------------------

============================ ==============================================
Example                      Status
============================ ==============================================
1 Hello World                ❌ (card memory)
2 HLS Vector Add             Untested
3 Multi-tenancy              Untested
4 User interrupts            Untested
5 Shell reconfiguration      ❌
6 GPU P2P                    ❌
7 FPGA-initiated DMA         Untested
8 Multi-threading            Untested
9 RDMA                       ❌
10 vFPGA reconfiguration     ❌
11 Traffic sniffer           ❌
============================ ==============================================

Future work includes the PL-side DDR4 as card memory, shell and vFPGA reconfiguration (which requires a floorplan around the RF data converters,
and handing the configuration port over from PCAP to ICAP), and exposing the RF data converters as a shell service.
