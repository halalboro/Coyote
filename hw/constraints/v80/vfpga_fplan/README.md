# V80 SLR-aware vFPGA floorplans

Default floorplans that place vFPGAs in regions distributed across the V80's
three SLRs. Designed to reduce routing congestion and improve timing for
multi-vFPGA Coyote designs on the V80.

## Why this exists

On the U280, Coyote builds typically run out of routing headroom past ~4
vFPGAs because all vFPGAs end up fighting for placement around the
soft-IP-heavy static shell. The V80 has structural headroom for more vFPGAs:
its static shell uses much less PL (CPM5, HBM controllers, NoC are all
hardened), so most of the dynamic region is available — *if* you stop
Vivado's placer from clumping everything into one SLR.

This directory provides a default floorplan that explicitly distributes
vFPGAs across SLR0/SLR1/SLR2.

## What's here

| File | Purpose | Requires |
|---|---|---|
| `v80_vfpga_slr_floorplan.xdc` | **Phase 1** — works with shipped (pre-Phase-2) static. Thin SLR1 strips (~4 CRs each). | Shipped DCP |
| `v80_vfpga_slr_floorplan_phase2.xdc` | **Phase 2 Strategy A** — assumes narrow-corridor static rebuild. SLR1 vFPGAs ~6-12 CRs. | Strategy A static rebuild |
| `v80_vfpga_mesh_floorplan.xdc` | **Phase 2 Strategy B + parametric mesh** — picks one of 3 profiles (or a recipe) based on `N_REGIONS` or `CYT_MESH_PROFILE` env. | Strategy B static rebuild |
| `example_recipe_mixed.tcl` | Example custom recipe — 3 large + 6 medium vFPGAs of mixed sizes. Source it via `CYT_MESH_RECIPE`. | Strategy B static rebuild |
| `README.md` | This file. |

## Which floorplan to use

Match the floorplan to the static checkpoint you're building against:

```
   Have you rebuilt the static?
              │
   ┌──────────┴────────────────┐
   │ No  (shipped DCP)         │ Yes
   ▼                           ▼
   v80_vfpga_slr_floorplan     ┌─ Which static? ─┐
                               ▼                 ▼
                            Strategy A       Strategy B
                            (corridor)       (SLR0-only shell)
                               │                 │
                               ▼                 ▼
                v80_vfpga_slr_floorplan_phase2   v80_vfpga_mesh_floorplan
```

For new V80 work, Strategy B + parametric mesh is the recommended target. It gives:

- **Choice of granularity** — 9 large vFPGAs, 18 medium, or 32 small, picked
  per build (or a fully custom recipe)
- **NoC tap pairing** — each cell either contains its own NMU+NSU NoC tiles
  (X3/X5/X7 columns) or sits adjacent to them, positioning vFPGAs for
  low-latency NoC access
- **Static checkpoint is N-agnostic** — same DCP underneath every profile.
  Re-stripe by changing the floorplan, not the static.
- **Headroom for inter-vFPGA streaming** — NoC tiles are already inside (or
  next to) each pblock, ready for Milestone B work to add `axis_p2p_*` ports

### Parametric mesh — picking a profile

The mesh floorplan auto-selects a profile based on `N_REGIONS`:

| N_REGIONS | Auto profile | Cell size | Per-vFPGA workload class |
|---|---|---|---|
| 1–9   | `large`  | ~4 CRs (2×2) | Substantial accelerators (HLS, RDMA stack) |
| 10–18 | `medium` | ~2 CRs (2×1) | Mid-size kernels (DSP, packet processors) |
| 19–32 | `small`  | ~1 CR (1×1)  | Control vFPGAs, sniffers, tiny pipelines  |

Override the auto-selection via env var:

```bash
export CYT_MESH_PROFILE=medium   # force medium regardless of N
```

### Custom recipes (the parking-lot escape hatch)

For mixed-size builds (e.g., 3 big + 6 small), provide a recipe file:

```bash
export CYT_MESH_PROFILE=recipe
export CYT_MESH_RECIPE=$(realpath hw/constraints/v80/vfpga_fplan/example_recipe_mixed.tcl)
```

A recipe is a Tcl source file that calls `cyt_mesh_pblock idx x0 y0 x1 y1`
once per vFPGA. See `example_recipe_mixed.tcl` for a template. Any CR
rectangle inside the free area (X0..X8, Y5..Y11) is valid.

## Building with the mesh

Once the Strategy B static is rebuilt and copied into
`hw/checkpoints/static_routed_locked_v80_gen5.dcp`:

```bash
cd examples/03_multitenancy/hw   # or any multi-vFPGA example
mkdir build_mesh && cd build_mesh
cmake .. \
    -DFDEV_NAME=v80 \
    -DBUILD_APP=1 \
    -DEN_PR=1 \
    -DN_REGIONS=8 \
    -DFPLAN_PATH=$(realpath ../../../../hw/constraints/v80/vfpga_fplan/v80_vfpga_mesh_floorplan.xdc)
make project
make bitgen
```

The XDC introspects the design hierarchy and pblocks only the `user_wrapper_<idx>`
cells that exist, and picks the profile automatically from `N_REGIONS`. Same
file serves all values 1–32 without edits.

## Examples

**9 substantial accelerators:**
```bash
cmake .. -DFDEV_NAME=v80 -DBUILD_APP=1 -DEN_PR=1 -DN_REGIONS=9 \
    -DFPLAN_PATH=$(realpath ../../../../hw/constraints/v80/vfpga_fplan/v80_vfpga_mesh_floorplan.xdc)
```

**18 medium kernels:**
```bash
cmake .. -DFDEV_NAME=v80 -DBUILD_APP=1 -DEN_PR=1 -DN_REGIONS=18 \
    -DFPLAN_PATH=$(realpath ../../../../hw/constraints/v80/vfpga_fplan/v80_vfpga_mesh_floorplan.xdc)
```

**32 small control vFPGAs:**
```bash
cmake .. -DFDEV_NAME=v80 -DBUILD_APP=1 -DEN_PR=1 -DN_REGIONS=32 \
    -DFPLAN_PATH=$(realpath ../../../../hw/constraints/v80/vfpga_fplan/v80_vfpga_mesh_floorplan.xdc)
```

**Mixed (3 large + 6 medium) — using a recipe:**
```bash
export CYT_MESH_PROFILE=recipe
export CYT_MESH_RECIPE=$(realpath ../../../../hw/constraints/v80/vfpga_fplan/example_recipe_mixed.tcl)
cmake .. -DFDEV_NAME=v80 -DBUILD_APP=1 -DEN_PR=1 -DN_REGIONS=9 \
    -DFPLAN_PATH=$(realpath ../../../../hw/constraints/v80/vfpga_fplan/v80_vfpga_mesh_floorplan.xdc)
```

## Scaling limits

| Constraint | Number | Bites at N≈ |
|---|---|---|
| NMU+NSU tap supply | 76 pairs | never (huge headroom) |
| Free PL CRs after Strategy B | ~55 | 50+ with min-size cells |
| QDMA active queues (2 per vFPGA H2C+C2H) | 64 | 30 |
| Soft control fabric (`axi_main`) timing | empirical | 16–20 |
| Driver / runtime overhead | unknown | needs measurement |

The realistic ceiling is **~30 vFPGAs**. The 32-cell `small` profile is at
the edge; beyond that the QDMA queue budget and control fabric timing become
binding before NoC tap supply does.

## Static checkpoint is N-agnostic

The Strategy B static checkpoint reserves the full SLR1+SLR2 region for
"some number of vFPGAs" but doesn't bake in how many or what size. Different
builds over the same static can use different mesh profiles. Re-stripe the
parking lot without rebuilding the lot itself.

## Which one to use

```
                       Have you rebuilt the static?
                                  │
              ┌───────────────────┴──────────────────┐
              │ No (default — using shipped DCP)     │ Yes (Phase 2 build)
              ▼                                      ▼
   v80_vfpga_slr_floorplan.xdc        v80_vfpga_slr_floorplan_phase2.xdc
   - vFPGAs 3, 4 in SLR1 = ~4 CRs     - vFPGAs 2, 3 in SLR1 = ~12 + ~6 CRs
   - 2 substantial slots total        - 4 substantial slots total
```

The Phase 2 path requires running `BUILD_STATIC=1, BUILD_SHELL=0` to regenerate
`hw/checkpoints/static_routed_locked_v80_gen5.dcp` against the updated
`hw/constraints/v80/fplan/v80_static_floorplan.xdc`. That is a multi-hour
Vivado static rebuild and is left to the user.

## Usage

The Versal PR flow requires a floorplan via `FPLAN_PATH`:

```bash
cd examples/03_multitenancy/hw      # or any multi-vFPGA example
mkdir build && cd build
cmake .. \
    -DFDEV_NAME=v80 \
    -DBUILD_APP=1 \
    -DEN_PR=1 \
    -DN_REGIONS=6 \
    -DFPLAN_PATH=$(realpath ../../../../hw/constraints/v80/vfpga_fplan/v80_vfpga_slr_floorplan.xdc)
make project
make bitgen
```

The XDC inspects the design hierarchy and pblocks only the wrappers that
actually exist, so the same file works whether you build with
`N_REGIONS=1`, `=3`, or `=6`.

## How the layout was chosen

V80 clock-region grid is 11×12 (X0–X10, Y0–Y11). The 3 SLRs map to four
CR rows each:

```
SLR2  →  Y8..Y11
SLR1  →  Y4..Y7
SLR0  →  Y0..Y3
```

The shipped V80 static shell (see `../fplan/v80_static_floorplan.xdc`)
occupies the following CRs:

```
   X→ 0   1   2   3   4   5   6   7   8   9  10
Y↓ ─────────────────────────────────────────────
11  .   S   S   S   S   S   S   S   .   .   .       SLR2
10  .   S   S   S   S   S   S   S   S   .   .
 9  .   S   S   S   S   S   S   S   S   .   .
 8  .   S   S   S   S   S   S   S   S   .   .
 7  .   S   S   S   S   S   S   S   S   .   .       SLR1
 6  .   S   S   S   S   S   S   S   S   S   .
 5  .   S   S   S   S   S   S   S   S   S   .
 4  .   .   .   .   .   S   S   S   S   S   .
 3  .   .   .   .   .   S   S   S   S   S   .       SLR0
 2  .   .   .   .   S   S   S   S   S   .   .
 1  .   .   .   .   S   S   S   S   S   .   .
 0  .   .   .   .   .   S   S   S   S   S   S
```

`S` = shell, `.` = free.

What this tells us:

* **SLR0 has the largest contiguous free region** (~20 CRs in the lower
  left) because the shell only reaches up to X4 in that quadrant. This
  becomes the home of vFPGA 0.
* **SLR2 has a useful right-side block** (X8..X10, Y8..Y11). vFPGA 1 lands
  here.
* **SLR1 is mostly shell** — the static shell traverses SLR1 to route
  between the CPM/HBM in SLR0 and the upper PL. Only thin left (X0) and
  right (X9..X10) columns are free in SLR1.

The partition table in the XDC assigns indices in order of region quality:

| vFPGA idx | SLR  | CR range          | Size class |
|-----------|------|-------------------|------------|
| 0         | SLR0 | X0Y0  :  X4Y3     | big (~20 CRs) |
| 1         | SLR2 | X8Y8  : X10Y11    | medium (~12 CRs) |
| 2         | SLR2 | X0Y8  :  X0Y11    | small (thin column) |
| 3         | SLR1 | X9Y4  : X10Y7     | small |
| 4         | SLR1 | X0Y4  :  X0Y7     | small (thin column) |
| 5         | SLR0 | X9Y1  : X10Y2     | small |

Low-`N_REGIONS` builds get the best regions: `N_REGIONS=1` places vFPGA 0
in the big SLR0 block, `N_REGIONS=2` adds vFPGA 1 in SLR2's medium block,
and so on.

## Limits and caveats

* **SLR1 is the bottleneck.** The shipped static shell occupies most of
  SLR1's interior. The two SLR1 vFPGA slots (indices 3 and 4) are thin
  column strips and won't fit large accelerators. They are best used for
  small/control vFPGAs.
* **Resource asymmetry across SLRs.** URAM and DSP58 columns are
  unevenly distributed in V80's CR grid. A vFPGA that needs lots of
  URAM may not fit cleanly in an SLR2 right block even though SLICE
  count is fine. Inspect actual resource availability per pblock in the
  Vivado GUI if your design is URAM/DSP-heavy.
* **Locked sites are still locked.** `SNAPPING_MODE ON` snaps boundaries
  to whole CRs; sites already routed by the shell in those CRs remain
  unavailable to the placer (which is what we want — the user pblock
  just defines the area where Vivado *can* place new logic).
* **Past N_REGIONS=6**, you have two paths:
  1. Split index 0's large SLR0 region into multiple sub-rectangles.
  2. Rebuild the static shell with a tighter pblock that frees more
     SLR1 area. This is the proper way to unlock SLR1 for substantial
     vFPGAs and is tracked as Phase 2 of the V80 multi-vFPGA work.

## Comparison with `examples/10_app_reconfiguration/hw/floorplans/example_fplan_v80.xdc`

The example floorplan there places a single `user_wrapper_0` in
`SLICE_X204Y192:SLICE_X323Y383`. That rectangle spans the SLR0/SLR1
boundary (SLICE_Y192 is in SLR0, SLICE_Y383 is in SLR1) and is therefore
not SLR-affined. It's fine as a small single-vFPGA demo but doesn't
generalise.

This directory's floorplan keeps every vFPGA strictly within one SLR.

## Verification suggestions

When trying this for the first time:

1. Build `examples/01_hello_world/hw` with `N_REGIONS=2`, `EN_PR=1`,
   and `FPLAN_PATH=$(realpath this_xdc)`. Confirm bitstream generation
   succeeds (timing closes).
2. Open the routed checkpoint and check that each user_wrapper landed
   entirely within its target SLR (use the Device window and the SLR
   highlight overlay).
3. Scale up to `N_REGIONS=6` with a small per-vFPGA design (e.g., a few
   AXI registers plus a counter) to confirm placement and timing.
4. Once that closes, run with realistic per-vFPGA logic and measure
   Total Negative Slack vs. an unconstrained build for the same
   design — the SLR-partitioned build should improve TNS significantly
   for designs with ≥3 vFPGAs.
