.. _zcu216-notes:

ZCU216 notes (experimental)
=====================================

Introduction
------------------------------------------
The ZCU216 is a Zynq UltraScale+ RFSoC evaluation board. Unlike the Alveo cards, it is not attached to an x86 server over PCIe;
the host is the on-chip ARM processing system (PS). Since the programmable logic is UltraScale+, the shell and dynamic layers
(including the MMU, vFPGAs and user logic) are shared with the Alveo cards; only the static layer, the driver platform layer
and a few build options differ.

.. warning:: Support for the ZCU216 is experimental. It has been validated on hardware (PYNQ 2.7, Linux 5.4) with Examples 1, 2, 3, 4, 7 and 8. Host streams and card memory (both PL DDR4 channels, 8 GB) are supported.

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

.. note:: Host memory is accessed through the coherent (HPC) ports, with snoopable AXI cache attributes. These are only coherent
    if the boot image sets ``brdc_inner`` in ``LPD_SLCR.lpd_apu`` (``0xFF41A040``) while the APU is in reset (AR# 69446),
    for example with the register init entry ``.set. 0xFF41A040 = 0x3;`` in the BIF. Then the device is marked ``dma-coherent``
    in the device tree, as in ``driver/dts/coyote_zcu216.dtso``. Boot images without it (such as the stock PYNQ 2.7 image) must drop
    ``dma-coherent``; the Coyote library then cleans and invalidates CPU caches around ``invoke()``, and FPGA-initiated transfers
    need ``cThread::syncForDevice()`` and ``cThread::syncForCpu()``.

Building the hardware
------------------------------------------
There is no pre-built static layer checkpoint or shell floorplan for the ZCU216, so the full design is built with the static flow.
For example, for Example 7:

.. code-block:: bash

    cd examples/07_perf_fpga/hw && mkdir build && cd build
    cmake ../ -DFDEV_NAME=zcu216 -DBUILD_STATIC=1 -DBUILD_SHELL=0 -DEN_SHELL_PBLOCK=0
    make project && make bitgen

The build produces ``bitstreams/cyt_top.bin``, which can be loaded from Linux. It is converted with ``bootgen`` to the byte-swapped
format expected by the ZynqMP FPGA manager.

Building and loading the driver
------------------------------------------
The driver is built for the ARM host, against the kernel running on the board:

.. code-block:: bash

    cd driver && make TARGET_PLATFORM=zynq

The bitstream is loaded and the Coyote device is described to the kernel with a device tree overlay (``driver/dts/coyote_zcu216.dtso``),
which must match the addresses and interrupts of the static layer. The overlay also sets the PS-PL port widths to 128 bits
(these reset on reboot and are not part of the bitstream) and, on PYNQ images, disables the generic-uio device that holds the
first PL interrupt. The PL clock (``pl0_ref``) cannot be set from the overlay on kernels without ``CONFIG_XILINX_FCLK``;
check that ``/sys/kernel/debug/clk/pl0_ref/clk_rate`` reads 100 MHz before loading the driver. Hugepages (2 MB) must be reserved
as on other platforms.

.. code-block:: bash

    cp cyt_top.bin /lib/firmware/
    dtc -@ -I dts -O dtb -o coyote_zcu216.dtbo driver/dts/coyote_zcu216.dtso
    mkdir /sys/kernel/config/device-tree/overlays/coyote
    cat coyote_zcu216.dtbo > /sys/kernel/config/device-tree/overlays/coyote/dtbo
    insmod driver/build/coyote_driver.ko

The software library is built as usual on the board; AVX is disabled automatically on ARM. The driver logs every
TLB mapping and interrupt by default; build it with ``make TARGET_PLATFORM=zynq COYOTE_DEBUG=0`` to turn that off.

.. note:: Several processes using the same vFPGA at the same time are not reliable yet: with a single host stream,
    results can end up in the other process' buffers, and four processes starting at the same moment on separate
    streams (Example 8) have been seen to stall the vFPGA until it is reloaded. Use one process per vFPGA; several
    threads within one process (as in Example 8) are fine. Processes on separate vFPGAs are isolated.

Supported features
------------------------------------------

============================ ==============================================
Example                      Status
============================ ==============================================
1 Hello World                ✅ (card memory)
2 HLS Vector Add             ✅
3 Multi-tenancy              ✅ (4 vFPGAs)
4 User interrupts            ✅
5 Shell reconfiguration      ❌
6 GPU P2P                    ❌
7 FPGA-initiated DMA         ✅
8 Multi-threading            ✅
9 RDMA                       ❌
10 vFPGA reconfiguration     ❌
11 Traffic sniffer           ❌
============================ ==============================================

Card memory
------------------------------------------
The board has two 4 GB PL DDR4 channels (C0 and C1, 32-bit DDR4-2666, x8 parts in a two-rank clamshell). With ``EN_MEM=1``,
both are used as card memory, striped into one 8 GB address space. The memory controllers are configured as in the board preset
(``MT40A1G8WE-075E``), which calibrates on a Rev A board. Their pins are in ``hw/constraints/zcu216/ddr``, generated from the
Vivado board files and only added to builds that use the channel. The driver splits the 8 GB into 256 MB that are left unused,
2 GB for regular pages and 5.75 GB for huge pages; this layout is fixed at compile time, so a build with only one channel needs
the driver layout changed as well.

The stripe fragment size defaults to 4 KB on the ZCU216 (1 KB on the other devices). The DDR interconnect holds back a request
whose AXI ID is still outstanding on the other channel, and the stripe keeps the ID, so with 1 KB fragments the two channels take
turns: Example 1 reaches about 2.6 GB/s with 1 KB fragments and about 4.5 GB/s with 4 KB fragments, with the data read from and
written to card memory at the same time.

Future work includes shell and vFPGA reconfiguration (which requires a floorplan around the RF data converters,
and handing the configuration port over from PCAP to ICAP), and exposing the RF data converters as a shell service.
