.. _zcu216-notes:

ZCU216 notes (experimental)
=====================================

Introduction
------------------------------------------
The ZCU216 is a Zynq UltraScale+ RFSoC evaluation board. Unlike the Alveo cards, it is not attached to an x86 server over PCIe;
the host is the on-chip ARM processing system (PS). Since the programmable logic is UltraScale+, the shell and dynamic layers
(including the MMU, vFPGAs and user logic) are shared with the Alveo cards; only the static layer, the driver platform layer
and a few build options differ.

.. warning:: Support for the ZCU216 is experimental. It has been validated on hardware (PYNQ 2.7, Linux 5.4) with Examples 1, 2, 3, 4, 7, 8 and 13. Host streams, card memory (both PL DDR4 channels, 8 GB) and ADC capture are supported.

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
13 RF capture                ✅ (ZCU216 only; ADC to card memory)
============================ ==============================================

Card memory
------------------------------------------
The board has two 4 GB PL DDR4 channels (C0 and C1, 32-bit DDR4-2666, x8 parts in a two-rank clamshell). With ``EN_MEM=1``,
both are used as card memory, striped into one 8 GB address space. The memory controllers are configured as in the board preset
(``MT40A1G8WE-075E``), which calibrates on a Rev A board. Their pins are in ``hw/constraints/zcu216/ddr``, generated from the
Vivado board files and only added to builds that use the channel. The driver splits the 8 GB into 256 MB that are left unused,
2 GB for regular pages and 5.75 GB for huge pages; this layout is fixed at compile time, so a build with only one channel needs
the driver layout changed as well.

Card memory is striped over the channels in 1 KB fragments. The stripe (``hw/hdl/stripe``) gives every channel its own AXI
ID, because the DDR interconnect holds back a request whose ID is still outstanding at another channel; with one shared ID
the channels take turns (about 2.6 GB/s). Responses can then return out of order, so reads are buffered per channel and
returned in request order, and write responses are counted per channel. Example 1 reaches about 8.2 GB/s with the data read
from and written to card memory at the same time (about 4.5 GB/s with one channel). This applies to every device that
stripes over DDR channels, not only the ZCU216.

RF data converters
------------------
This part is experimental. On a board, a tone played from one DAC channel has been captured on one ADC channel; the other channels have not
been shown to carry a signal, and the tone's level changes each time the DAC starts (see below). ``-DEN_RF=1`` adds the RF data converter to the shell; the default is off, and images built without it
never touch the converters or the clock chips. Do not load such an image, program the clock chips or enable a DAC before
checking what is connected to the RF outputs.

**The DAC tiles start by themselves:** if their reference clock is already running when an image with the converter is loaded, the
tiles go to their running state (state 15) without any software command. Clocks stay programmed across image loads, so this
is the normal case after the first load. The Coyote driver therefore shuts them down when it loads on an image with the converter (tile 3, then tile 2), so they
run only between the bitstream load and ``insmod``. An image with the converter must not be loaded with a driver older than this,
or with one built from a shell that does not report the converter (bit 15 of the shell's memory configuration register).

The build has four ADC channels and four DAC channels, the ones the XM655 card brings to connectors ``JHC7`` and ``JHC3``:

======= ==== ===== ============= =============
Channel Tile Block ADC           DAC
======= ==== ===== ============= =============
0       2    0     ADC226 CH0    DAC230 CH0
1       2    2     ADC226 CH2    DAC230 CH2
2       3    0     ADC227 CH0    DAC231 CH0
3       3    2     ADC227 CH2    DAC231 CH2
======= ==== ===== ============= =============

All sample at the same rate, 2.4576 GS/s by default, from a 245.76 MHz reference clock on BA5/BB5 (ADC) and B5/A5 (DAC), with SYSREF on D2/D1. These clock settings
follow QICK's public ZCU216 design. ``-DRF_RATE_KHZ`` sets the rate when building (for example ``-DRF_RATE_KHZ=1228800``), and the fabric clock is an eighth of it. Vivado accepts multiples of 245.76 MHz from 614.4 MHz
upwards and rejects 500 MHz; on a board, 2.4576 and 1.2288 GS/s have been tested. The rate is shared by all converters and cannot change at run time. The clock chips stay the same at every rate. Tile 3 of each direction takes its reference clock from tile 2 and its fabric clock is tile 2's, so tile 2 must run for
tile 3 to pass data: start tile 2 first and shut it down last. The configuration is in ``hw/bd/zynq_us_plus/cr_rf.tcl``. The converter's control registers
are at ``0xA800_0000`` (256 KB), reached through the shell's control interconnect.
A DAC with zero data is not necessarily silent: once it is running, its output can still carry bias and clock leakage.

The converters connect to one vFPGA, chosen with ``-DRF_VFPGA_ID`` (default 0), through two 512-bit streams on the vFPGA clock:
``axis_rf_recv`` carries samples from the selected ADC channel and ``axis_rf_send`` carries samples to the selected DAC channel; the other DAC channels get zeros.
One channel of each direction is selected at a time. Each channel delivers 8 16-bit samples per
307.2 MHz clock (4.9 GB/s). The vFPGA has to handle both streams, or the build fails in ``opt_design``; ``examples/13_rf_capture`` captures ADC data to
card memory and can play a waveform to the DAC stream. The logic is in ``hw/hdl/rf`` (testbench in ``sim/rf``). Both directions are
off after reset and are enabled through these registers, at ``0xA804_0000``:

====== ===================================================================
Offset Register
====== ===================================================================
0x00   ID, reads ``0x52460001``
0x04   Bit 0 enables the ADC stream, bit 1 the DAC stream, bit 2 replaces ADC samples with a counter (change it while the stream is disabled)
0x08   Bit 0 ADC overflow, bit 1 DAC underflow; sticky until disabled
0x0C   Number of 512-bit words taken from the ADC since it was enabled
0x10   Number of 512-bit words sent to the DAC since it was enabled
0x14   Number of channels; reads 0 on images built before there were four
0x18   Bits 1:0 select the ADC channel, bits 9:8 the DAC channel
0x1C   Sampling rate in kHz; reads 0 on images built before this register, which run at 2457600
====== ===================================================================

If the vFPGA stops accepting ADC data, the 512-entry FIFO fills and words are dropped with the overflow flag set. If the DAC runs out of
data after its first word, it outputs zeros with the underflow flag set. Disabling the DAC stream forces its output to zero at once.

The RF ports need ``IO_BUFFER_TYPE=none`` in synthesis, where the shell is a black box, or Vivado inserts I/O buffers on them.
The property has to be removed again after linking (``scripts/impl/link.tcl.in``), because ``opt_design`` otherwise fails DRC
RPBF-1. The pins are dedicated, so they have no constraints file.

On the board, PYNQ's ``xrfdc`` driver works with this IP version (2.6) when given the parameters from the ``design_rf`` ``.hwh``
and ``XILINX_XRT=/usr`` and ``BOARD=ZCU216`` in the environment. ``xrfclk.set_ref_clks(lmk_freq=245.76, lmx_freq=491.52)``, the
settings QICK uses, brings all four tiles to state 15 with their PLLs locked. The clock chips need programming once after every power cycle: ``cRF::programClocks()`` (``test --program-clocks`` in Example 13, as root) writes the same bytes to the chips as ``xrfclk`` does, and takes about 1.4 s. This has been tested straight after a power cycle: until the chips are programmed the ADC tiles wait in state 6 and Example 13 refuses to capture, and the DAC tiles read off before and after programming (the driver has already shut them down).
The ADC PLLs lose lock while the first chip, the LMK04828, is written and lock again when it is done; writing the LMX2594s has no visible effect on this design.

The ``cRF`` class (``sw/include/coyote/cRF.hpp``) maps these registers and the converter's tile registers through the driver. It reads
tile state and PLL lock, starts and shuts down the ADC and DAC tiles, selects channels and controls the ADC and DAC streams. If it started the DAC tiles, its destructor stops the stream and shuts them down;
a process that is killed leaves them running until the driver is next loaded.
On an image without the converter, the driver refuses the mapping and ``cRF`` throws.

Example 13 captures up to 128 MB to card memory (``test -s <MB> -p <0|1> -c <ADC channel> -o <file>``; 128 MB needs ``vm.nr_hugepages`` of at least 64); ``-p 1`` uses the test pattern, whose samples are consecutive
16-bit values generated on the ADC clock. On a board, 128 MB took 27.31 ms, against 27.31 ms of ADC data, with no broken samples and no overflow in 30 runs. At 1.2288 GS/s it took 54.61 ms, against 54.61 ms of ADC data. The four-channel image passes 8 MB of pattern on each channel, at both rates.
The pattern starts in the ADC clock domain but after the converter, so it shows that no data is lost on the way to card memory, not that the converter or the sample
order within a word is right; that needs a known signal. With nothing driving the input, samples are multiples of 4 (a 14-bit converter), with an RMS of about 25 on all four channels and, on the channel where the spectrum was examined,
spurs at 614.4 and 1228.8 MHz, a quarter and half of the sampling rate.

Only use the next options when you know what the DAC outputs are connected to. ``test -s <MB> -c <ADC channel> -d <DAC channel> -k <bin> -a <amplitude>`` plays a tone of ``bin`` times 1.2 MHz
during the capture and measures it at the ADC. The amplitude defaults to 1/16 of full scale, and the program refuses more than 1/4. ``test --scan`` plays tones from 30 to 1201 MHz on each DAC
channel in turn and measures every ADC channel.

On the board tested, with cables between XM655 ports, the scan at 1/16 of full scale found one connected pair: DAC channel 3 to ADC channel 0, at about 4 dB below the amplitude sent at 30 MHz and about
80 dB above the DAC-off level, with no data lost. The other 15 pairs stayed at the DAC-off level, below about 0.2 of the 2048 sent. This shows that this DAC channel, this ADC channel and the order of samples within a word
work for a sine wave, including across the two tiles. It does not show why the other pairs are silent, and those DAC channels have not been shown to produce a signal, nor those ADC channels to respond to one.
The result describes that board's cabling, which has not been traced; other boards will differ.

The tone's level is steady while the converters run, and through turning the DAC stream off and on, but it moves when any one tile restarts, including the ADC tiles alone. It lands on one of four repeatable
curves (``test --sweep`` and ``test --stability -k <bin>``). At 30 MHz they all read about 1275 of the 2048 sent; at 1228 MHz they read about 976, 776, 730 and 273. The best curve is 4 to 7 dB below the amplitude sent.
The ratio of each other curve to the best one closely fits an ADC sample that mixes two neighbouring DAC samples, with weights of about 0.64/0.36, 0.90/0.10 and 0.89/0.11 (mean error 1 to 2%).
``test --pulse`` shows this directly: a single-sample pulse arrives in one of four shapes depending on the start, for example 0.51 of its height followed by 0.06 on the best curve, and 0.33 followed by 0.21 on the lowest, and the spectrum of the
pulse predicts the tone levels measured in the same start, within the noise of about 70 counts. So each tile restart moves the timing between the ADC and DAC samples by a discrete step. Which side moves, and by how much in time, has not been measured.
Until the offset is controlled, a single capture on this path is not a frequency response, and absolute levels above a few hundred MHz hold only for one start of the tiles. Multi-tile synchronisation might make it repeatable, but has not been tried.
At 1.2288 GS/s the same pair is found and the level still changes with restarts, with at least eight curves instead of four.
At the default rate, the sampling rate only reaches 1.2288 GHz, so only the ``<1GHz`` baluns are suited to it.

Future work includes shell and vFPGA reconfiguration (which requires a floorplan around the RF data converters,
and handing the configuration port over from PCAP to ICAP), and rates or sample widths beyond one shared rate with 8 samples per fabric clock.
