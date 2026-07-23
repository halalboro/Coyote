# V80 vFPGA mesh design

## Goal

Support **many** vFPGAs (target: 8–16, with headroom to 30+) on V80, each with
its own NoC tap, arranged in a 2-D mesh that exploits V80's four-column NoC
fabric for inter-vFPGA streaming.

## V80 NoC topology (measured)

The V80 has 76 NMU_512 + 76 NSU_512 tiles plus 152 NPS_VNOC packet switches,
arranged in four vertical columns at fabric CR X1, X3, X5, X7. Each NoC-column
CR holds 2 NMU + 2 NSU tiles (1+1 at the SLR0/SLR1 boundary row Y4).

```
       CR column X→  X0  X1  X2  X3  X4  X5  X6  X7  X8  X9  X10
   row Y11           .   .   .   .   .   .   .   .   .   .   .
       Y10           .   4   .   4   .   4   .   4   .   .   .
       Y9            .   4   .   4   .   4   .   4   .   .   .    SLR2
       Y8            .   4   .   4   .   4   .   4   .   .   .
       Y7            .   4   .   4   .   4   .   4   .   .   .
       Y6            .   4   .   4   .   4   .   4   .   .   .    SLR1
       Y5            .   4   .   4   .   4   .   4   .   .   .
       Y4            .   2   .   2   .   2   .   2   .   .   .  ← boundary
       Y3            .   4   .   4   .   4   .   4   .   .   .
       Y2            .   4   .   4   .   4   .   4   .   .   .    SLR0
       Y1            .   4   .   4   .   4   .   4   .   .   .
       Y0            .   .   .   .   .   .   .   .   .   .   .
```

Per-SLR NMU+NSU pair counts: SLR0 = 28, SLR1 = 24, SLR2 = 24.

## Design principle: pair each vFPGA with a local NoC tap

Each vFPGA pblock spans **two CR columns**: one NoC-column CR (X1/X3/X5/X7) and
one adjacent fabric CR (X0/X2/X4/X6 or X8). The NoC-column CR provides the
NMU/NSU tile for that vFPGA's outbound/inbound p2p AXI-Stream traffic. The
fabric CR provides SLICE/DSP/BRAM/URAM area for user logic.

```
   ┌─────────────────────────────────────┐
   │  vFPGA pblock                       │
   │  ┌──────────────┬───────────────┐   │
   │  │ Fabric CR    │ NoC-column CR │   │
   │  │ (X0/X2/X4/   │ (X1/X3/X5/X7) │   │
   │  │  X6/X8)      │               │   │
   │  │              │               │   │
   │  │  SLICE       │  NMU_512  ────┼───┼──→ to peer vFPGAs
   │  │  DSP58       │  NSU_512  ←───┼───┼── from peer vFPGAs
   │  │  RAMB36      │  NPS_VNOC     │   │
   │  │  URAM288     │  (switches)   │   │
   │  └──────────────┴───────────────┘   │
   └─────────────────────────────────────┘
```

## Per-vFPGA mesh layout

After Strategy B (drop shell from SLR1/SLR2 entirely), all of SLR1+SLR2 is
available. Plus parts of SLR0 left of the shell.

Proposed default mesh: **12 vFPGAs** organized as a **4-wide × 3-tall grid**
covering SLR1 and SLR2. Each cell is 2 CR cols × 2 CR rows. Each cell gets
2-4 NMU+NSU pairs (more than it needs — gives Vivado placer freedom).

```
   PROPOSED 12-vFPGA MESH (post-Strategy-B):

          X0-1   X2-3   X4-5   X6-7   X8+
   Y10-11 [vF8 ] [vF9 ] [vF10] [vF11] (free)
   Y8-9   [vF4 ] [vF5 ] [vF6 ] [vF7 ] (free)
   Y6-7   [vF0 ] [vF1 ] [vF2 ] [vF3 ] (free)
   Y4-5   ──────── shell SLR0/SLR1 boundary ────
   Y0-3   ──────── shell ─────────────────────
```

Each `[vFi]` is a 2×2 CR pblock = ~4 CRs of fabric + 2 NoC tiles' worth of
taps. Plenty of area for substantial accelerators (each cell has ~1k-2k SLICE,
~30 BRAM, ~12 URAM).

## Parameterization

The floorplan is parameterized on `N_REGIONS`. The generator algorithm:

```
mesh_cols = 4              # fixed: X0-1, X2-3, X4-5, X6-7
mesh_rows_max = 3          # Y4-5 (SLR1 boundary, optional), Y6-7, Y8-9, Y10-11
                           # → up to 3 full rows above SLR0

if N_REGIONS <= 4:
    use 1 row at Y6-7  (medium-size, SLR1 only)
elif N_REGIONS <= 8:
    use 2 rows at Y6-7 and Y8-9
else:
    use 3 rows at Y6-7, Y8-9, Y10-11  (full 12-vFPGA mesh)

# 1-3 vFPGAs land in the SLR2-top row first (best taps)
# 4-8 grow downward
# 9-12 fill SLR1
```

For N_REGIONS > 12, the next expansion is to split each 2×2 cell into 2
sub-tiles (1×2 each), trading per-vFPGA area for vFPGA count. Goes to ~24
slots. Beyond that, NMU tap supply (76) and PL-area floor (~2 CRs per vFPGA)
become the wall, around 30-40 vFPGAs maximum.

## NoC connectivity model

**Full mesh AXIS routing**: every NMU can stream to every NSU. TDEST encodes
the destination vFPGA index.

Per-vFPGA AXIS interface contract:

```
   axis_p2p_send : master AXI4-Stream from user logic → NMU_512
       TDATA  : 512 bits
       TKEEP  : 64 bits
       TLAST  : 1 bit
       TDEST  : log2(N_REGIONS) bits  (peer vFPGA index)

   axis_p2p_recv : slave AXI4-Stream from NSU_512 → user logic
       TDATA  : 512 bits
       TKEEP  : 64 bits
       TLAST  : 1 bit
       (TDEST not exposed — receiver's local NSU is its own destination)
```

The shell's NoC instance declares N×N connectivity at synthesis time. The NoC
compiler builds the routing table.

## Trade-offs and limits

| Limit | Number | When it bites |
|---|---|---|
| PL area (Phase 2 free area) | ~70 CRs | N_REGIONS > 30 with min-size tiles |
| NMU_512 tiles | 76 | N_REGIONS > 38 (one NMU per vFPGA) |
| NSU_512 tiles | 76 | same |
| NPS_VNOC switches | 152 | not the wall — plenty |
| QDMA queues per direction | 64 | N_REGIONS > 30 if each gets its own queue |
| Control fabric (axi_main soft) | ~few hundred MHz timing | N_REGIONS > 16 may stress this |
| Driver overhead | unknown | not measured |

**Practical sweet spot: 8–12 vFPGAs.** Beyond that the marginal vFPGA gets
smaller without much benefit, and the control fabric starts pushing back.

## Implementation steps

1. **Strategy B static-floorplan update** — drop SLR1/SLR2 from the shell pblock entirely. Shell didn't use them in the build_test, so this is empirically safe.
2. **Parameterized mesh floorplan generator** — single XDC that takes N_REGIONS and creates the right number of mesh-cell pblocks.
3. **Shell template additions** — per-vFPGA NMU/NSU instantiation, p2p AXIS ports on user_wrapper, NoC connectivity declaration.
4. **Static rebuild** — with Strategy B + per-vFPGA NMU declarations.
5. **App build test** — N_REGIONS=8 or 12, verify routes through NoC mesh.

## Open questions to resolve during implementation

- **NoC AXIS routing limits** (PG313): can the NoC route TDEST-based AXIS between any pair of NMU/NSU on V80, or are there topology constraints? Need to verify before generalizing to N=12.
- **NMU instantiation method**: instantiate `axi_noc` IP per vFPGA (each with one NMU and one NSU), or one big `axi_noc` with N+M ports? Big-NoC is cleaner; per-vFPGA-NoC is more modular.
- **TDEST width**: log2(N) bits in user contract, but NoC IP wants a fixed TDEST width at synthesis. Round up to 4 bits (supports up to 16 peers).
- **Backpressure semantics**: skid buffers in user_wrapper before NMU? Need ~16 entries to absorb NoC latency.
- **Isolation**: should the shell enforce TDEST whitelisting per vFPGA, or trust the user logic? Whitelisting needs a soft AXIS gate; not free.
