# Coyote Example 16: V80 200G DCMAC raw Ethernet echo

Brings the Versal DCMAC up on the Alveo V80's QSFP56 cage and echoes whole
Ethernet frames back to the peer with the source and destination MAC addresses
swapped.

The Coyote network stack is bypassed (`EN_NET_RAW=1`): the vFPGA is the MAC
client and owns the entire frame, header included. Nothing in the datapath
touches the host, so the software here is purely a bring-up and monitoring
tool.

## Why the stack is bypassed

`network_stack` is built from four HLS cores — `ip_handler`, `icmp_server`,
`mac_ip_encode` and `arp_server_subnet` — that live in the `fpga-network-stack`
submodule and have not been built for a Versal part. `EN_NET_RAW` skips them,
which is what makes networking possible on the V80 at all today. CMake enforces
this: `EN_NET` on Versal without `EN_NET_RAW` is a hard error.

## Requirements

- Vivado **2025.1** or newer (the DCMAC block design needs it)
- A 200GAUI-4 peer, or a QSFP56 loopback module in the cage
- The cage powered up and out of low-power mode. On the V80 that belongs to the
  AVED satellite controller (`ami_tool`), not to the PL — there are no
  `qsfp0_*` sideband pins in this design for that reason.

## Build

```
cd hw && mkdir build && cd build
cmake .. && make project && make bitgen
```

The build is flat: `BUILD_STATIC=1` with `EN_SHELL_PBLOCK=0`. That is not a
preference but a requirement — the DCMAC hard block and its GT quad cannot sit
inside a reconfigurable partition, and those settings are what keep `inst_shell`
static. CMake rejects `EN_NET` on Versal with `EN_SHELL_PBLOCK=1`.

Note that `make bitgen` does **not** re-render the Jinja templates. After
editing anything under `hw/templates/` or `scripts/**/*.in`, re-run
`make project` first.

```
cd sw && mkdir build && cd build
cmake .. && make
```

## Run

```
./test --status              # decode the MAC bring-up status and stop
./test --echo --watch 30     # enable echo, poll counters for 30 s
./test --sink --watch 10     # accept and discard, to measure receive alone
./test --mac                 # DCMAC PHY/MAC status, statistics, segment monitor
./test --gen 64 --clear      # burst + stage-by-stage frame count (see below)
```

Start with `--status`. It decodes `mac_status`, which is the DCMAC reset FSM
state plus the GT reset-done flags, promoted out of the block design
specifically so bring-up is not blind:

```
MAC status (0xed)
  reset FSM   : ST_DONE (13)
  rst_done    : yes
  gt_done_tx  : yes
  gt_done_rx  : yes
```

`gt_done_*` low means the transceivers never finished their reset handshake —
look at the module and the reference clock. `gt_done_*` high with `rst_done`
low means the transceivers came up but the DCMAC reset sequence stalled, and
the state name says where.

## Finding where frames are lost

The shell exposes a register port into the MAC (`mac_reg_*`, threaded through
the templates to the raw-Ethernet vFPGA). Behind it, on Versal, sit two
windows (`hw/hdl/network/dcmac_cyt/dcmac_debug.sv`):

- `0x000000-0x00FFFF`: the DCMAC's own PG369 register space: configuration,
  PHY/MAC status, and the hard block's statistics counters. The block design
  builds with `dcmac_axil=1`, and a two-clock SmartConnect keeps the DCMAC side
  on its 100 MHz APB clock.
- `0x100000-`: a segment monitor at the DCMAC pins (dclk). It holds
  SOP/EOP/error/framing-violation counters for both directions, frame counters
  at the block design boundary, a counter of RX frames flagged by the MAC's
  `tuser` error bit (which the 512-bit Coyote stream drops), and a capture of
  the first 16 segment cycles each way.

Every `--gen` run zeroes all of it, sends the burst, and prints the frame count
at each stage in path order. It also names the first stage that comes up short:

```
vFPGA generator -> vFPGA TX -> shell->BD -> DCMAC TX pins -> STAT_TX_TOTAL_PACKETS
-> STAT_RX_TOTAL_PACKETS -> STAT_RX_TOTAL_GOOD_PACKETS -> DCMAC RX pins -> BD->shell -> vFPGA RX
```

The tool reads the DCMAC statistics with a "tick", which latches the counters
and also zeroes them. The tick can come from a pin or from a register,
depending on a mode bit, so the tool tries the pin first and the register
second and reports which one took effect. `--mac` reads the same registers
with no traffic: it prints the latched and current status registers, every
nonzero statistics counter by offset (look the offset up in PG369), and the
captures. A capture entry shows each of the four segments as `S` (sop), `E`
(eop), `!` (err) and `mN` (empty bytes on the eop segment).

## Register map

Host CSR index = byte offset / 8. See `hw/src/vfpga_top.svh`.

| Reg | Name | Access | Meaning |
|-----|------|--------|---------|
| 0 | `CTRL` | RW | bit0 echo enable, bit1 sink mode, bit2 clear counters, bit3 generate burst (rising edge) |
| 1 | `STATUS` | RO | bits[7:0] `mac_status`, bit8 `tx_valid_q`, bit9 `sof`, bit10 `rx_tvalid`, bit11 `tx_tready` |
| 2 | `RX_FRAMES` | RO | frames received |
| 3 | `RX_BYTES` | RO | bytes received |
| 4 | `TX_FRAMES` | RO | frames transmitted |
| 5 | `TX_BYTES` | RO | bytes transmitted |
| 6 | `RX_FIRST` | RO | low 64 bits of the most recent first beat |
| 7 | `RX_RUNTS` | RO | received frames shorter than 60 bytes |
| 8 | `TX_BURST` | RW | frames per generator burst |
| 9 | `GEN_SENT` | RO | frames emitted by the current/last burst |
| 10 | `MREG_ADDR` | RW | MAC register port address |
| 11 | `MREG_WDATA` | RW | MAC register port write data |
| 12 | `MREG_CMD` | W | any write issues one access; bit0 = write |
| 13 | `MREG_RESP` | RO | [31:0] read data, [33:32] resp, [34] busy, [63:48] completion count |
| 14-15 | `SCRATCH` | RW | unused; targets for probing the CSR write path |

The receive counters are pipelined and settle a few cycles after the last beat.
The first build computed them combinationally and failed timing on `RX_BYTES`
and `RX_RUNTS` at 400 MHz.

## Clocking

`NCLK_F=400`, giving 512 b × 400 MHz = 204.8 Gb/s on the user side — above the
DCMAC's 200 Gb/s, so a sustained full-rate receive burst cannot overrun the
block design's RX CDC FIFO. There is no frame-drop logic on this path, so
running `NCLK_F` below 391 MHz will lose frames under load; CMake warns if you
do.

## What is not covered

- Only DCMAC index 0 (`DCMAC_X1Y1`) is wired up. The block design's module name
  embeds the index and a module name cannot be parameterised, so index 1 needs
  a second wrapper rather than a parameter. `EN_NET_1` is rejected on Versal.
- Dual-QSFP56 mode is untested upstream and is not exposed.
- The DCMAC's registers are reachable only through the raw-Ethernet vFPGA's
  register port (above), not from Coyote's control address map.
