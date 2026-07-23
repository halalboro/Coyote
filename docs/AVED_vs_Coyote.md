# AVED V80 features vs. Coyote-upstream — integration analysis

This document maps the AMD AVED V80 reference design (24.1 release,
`amd_v80_gen5x8_24.1_20241002`) feature-by-feature against the Coyote-upstream
shell, identifies what's already covered, where the gaps are, and what the
integration hooks look like.

Source for AVED claims: <https://xilinx.github.io/AVED/amd_v80_gen5x8_24.1_20241002/>.
Source for Coyote claims: this repo (`Coyote-upstream/`).

---

## 1. Architecture map — points of interest on the V80

```
                                                ┌──────────────────────────────────────────┐
                                                │   HOST x86 server                         │
                                                │  ┌──────────┐  ┌────────────┐             │
                              SMBus 3.2         │  │ ami.ko   │  │ qdma.ko    │  user apps  │
                       ┌──── (2-wire) ────────┐ │  │ ami_tool │  │ /dev/qdma* │  dma-ctl    │
                       │  PLDM/MCTP, FRU      │ │  └────┬─────┘  └─────┬──────┘             │
                       ▼                      │ └───────┼──────────────┼────────────────────┘
                ┌──────────────┐              │         │ PF0  mgmt    │ PF1  data
                │  Server BMC  │              │         │ 256 MB BAR   │ QDMA BARs
                └──────────────┘              │         │              │
                                              │      ═══╪══════════════╪═══ PCIe Gen5 x8 32 GT/s ═══
══════════════════════════════════════════════╪═════════╪══════════════╪══════════════════════════════
                            ALVEO V80 (Versal HBM)      ▼              ▼
                                              │   ┌─────────────────────────────────────────┐
   ┌───────────── CIPS (hard) ───────────┐    │   │   CPM5  (PCIe controller 1, x8 Gen5)    │
   │  APU: 2× Cortex-A72       (idle)    │    │   │   PF0 mgmt           PF1 QDMA           │
   │  RPU: 2× Cortex-R5F  ◀── AMC FW ────┘    │   │  ┌──────┐         ┌──────────────┐      │
   │       FreeRTOS, 5 proxy drivers          │   │  │ BAR0 │         │ H2C/C2H MM+ST│      │
   │       (AMI/APC/ASC/AXC/BMC)              │   │  │256 MB│         │ ≤2048 queues │      │
   │  PMC: boot, multiboot, OSPI loader       │   │  └───┬──┘         └──────┬───────┘      │
   │  Sysmon: die temp/voltage                │   └──────┼───────────────────┼──────────────┘
   │  Boot: 2 Gb OSPI + 64 GB eMMC            │          │ 300 MHz           │
   │  IPI: R5↔PMC/PSM                         │          ▼                   ▼
   └────────────┬──────────┬──────────────────┘     ┌─────────────────────────────────────────┐
                │ LPD AXI  │ PMC AXI 100 MHz        │             NoC  (axi_noc_cips)         │
                │ 100 MHz  │                        │  QoS Best-Effort                        │
                ▼          ▼                        │  S00 PCIe 300M  S01 PMC  S02 LPD  S03 DDR
        ┌─────────────────────────────────┐        │  M00→PL mgmt SC 300M, 5 MB/s AXI-Lite   │
        │  rpu_sc  (RPU SmartConnect 100M)│        │  4×INI→DDR/DIMM 800 MB/s ea             │
        │  → gcq_m2r  (CQ side, S01_AXI)  │        │  16×HBM PCs 250 MB/s ea                 │
        │  → axi_smbus_rpu (target/ctrlr) │        └────┬───────────┬────────────┬───────────┘
        └─────────────────────────────────┘             │           │            │
                │              │                       ▼           ▼            ▼
                │              │           ┌────────────────┐ ┌───────────┐ ┌──────────────┐
                │              │           │ DDR4 onboard   │ │ DDR4 DIMM │ │  HBM   32 GB │
                │              │           │ 4 GB @200 MHz  │ │ 32 GB     │ │ 2 stacks ×   │
                │              │           │ APU/RPU/IPC    │ │ @200 MHz  │ │ 8 ctrls ×    │
                │              │           │ 128 MB shared  │ │ user/host │ │ 2 PCs        │
                │              │           │ window for GCQ │ └───────────┘ │ 1 GB/PC slice│
                │              │           │ payload        │               └──────────────┘
                │              │           └────────────────┘
                ▼              ▼
   ┌─────────────────────────────────────────────────────────────────────────────────────────┐
   │                       PL — Base Logic (soft IPs)  @ 100 MHz mgmt domain                 │
   │                                                                                         │
   │  pcie_slr0_mgmt_sc (SmartConnect, M from NoC M00)                                       │
   │   ├─► uuid_rom         BAR0+0x0100_1000..0x0100_1FFF   (type 0x50 in HW-Disc table)     │
   │   ├─► gcq_m2r          BAR0+0x0101_0000..0x0101_0FFF   (type 0x54)  irq → LPD IRQ 0     │
   │   │     S00_AXI = producer (host)   S01_AXI = consumer (RPU)                            │
   │   │     SQ/CQ rings live in 128 MB DDR window                                           │
   │   ├─► hw_discovery     PCIe VSEC @ ext-cap 0x600, up to 14 endpoints × 4 PFs            │
   │   └─► axi_noc_cips remapper  BAR0+0x0800_0000..0x0FFF_FFFF (128 MB → 0x000_3800_0000)   │
   │                                                                                         │
   │  axi_smbus_rpu  (SMBus 3.2 ctrl+target, AXI4-Lite)  irq → LPD IRQ 1 ────► server BMC    │
   │                                                                                         │
   │  ┌─ user clock wizard ───┐    ┌─ user logic region (PF1 / QDMA AXI not yet wired) ─┐    │
   │  │ clk_usr_0  299.997 MHz│    │  pins via create_bd_design.tcl + impl.pins.xdc     │    │
   │  │ clk_usr_1  499.995 MHz│    │  MCIO + QSFP exposed                               │    │
   │  └───────────────────────┘    └────────────────────────────────────────────────────┘    │
   │                                                                                         │
   │  GTs:  CPM5 ×8 (PCIe Gen5), MCIO, 4× QSFP-DD                                            │
   └─────────────────────────────────────────────────────────────────────────────────────────┘

   Boot/program flow:  PMC ──► OSPI page 0 = FPT (magic 0x92F7A516)
                                ├─ partition 0  base 0x0000_8000  size 0x07E0_0000  (~126 MB PDI A)
                                └─ partition 1  base 0x07E0_8000  size 0x07E0_0000  (~126 MB PDI B)
                       AMC sets PMC_MULTIBOOT + reset → A/B swap.   eMMC 64 GB = secondary.
```

---

## 2. Dense reference table — every AVED feature with exact numbers

| # | Subsystem | Where it lives | Exact numbers / addresses / IDs | Role | Hook for Coyote |
|---|---|---|---|---|---|
| 1 | **CPM5 PCIe** | Versal hard block, controller 1 | Gen5 ×8, 32 GT/s; PF0=mgmt (1× 64-bit BAR, 256 MB), PF1=DMA; user PF not enabled | Host link | Replace XDMA path; clean PF mgmt/data split |
| 2 | **QDMA** | PF1 | ≤2048 queues; MM + ST; H2C/C2H; `/dev/qdma<bbddf>-<mode>-<qid>`; libaio via `dma-perf`; `dma-ctl` mgmt | Bulk DMA | Drop-in DMA for POS/Coyote dataplane |
| 3 | **GCQ v2.0** (`gcq_m2r`) | PL, 100 MHz mgmt SC | S00_AXI producer, S01_AXI consumer; regs 0x000–0x010 tail/doorbell, 0x100–0x110 head/status; 64-bit addr split HIGH/LOW; INTERRUPT_TYPE 0x0 doorbell / 0x1 manual; irq `irq_sq` & `irq_cq`; payload in 128 MB DDR window; BAR0+0x0101_0000..0x0101_0FFF; LPD IRQ 0 | Host↔RPU mailbox | Generic mailbox IP — reuse in vFPGAs |
| 4 | **Hardware Discovery** | PL, VSEC | PCIe ext-cap base 0x600, next-ptr 0x000; header at 0x0/0x4/0x8 (fmt id, len, entry size); 16-byte slots from 0x10; type/BAR-idx/48-bit offset/version; types: 0x50 UUID, 0x54 GCQ, 0x55 remapper; ≤14 endpoints × ≤4 PFs; AXI4-Lite per-PF (s_axi_ctrl_pf0..3) | Self-describing BAR map | Pattern for endpoint auto-discovery |
| 5 | **SMBus IP v1.1** (`axi_smbus_rpu`) | PL, 100 MHz | SMBus 3.2 spec; ctrlr + target (target can emulate 8 devices); AXI4-Lite; regs: version 0x000–0x038, irq 0x020–0x038, PHY 0x200–0x830, target 0x600+, controller 0xA00+; PEC supported; Quick Cmd unsupported as target; LPD IRQ 1 | OOB to server BMC | Free OOB telemetry; PLDM/MCTP |
| 6 | **UUID ROM** | PL | 128-bit MD5 of design; BAR0+0x0100_1000..0x0100_1FFF; HW-Disc type 0x50 | Design ID | Sanity check loaded PDI matches host driver |
| 7 | **NoC remapper** | PL/NoC | BAR0+0x0800_0000..0x0FFF_FFFF (128 MB) → physical 0x000_3800_0000 | PCIe→DDR window | The 128 MB GCQ payload region lives here |
| 8 | **NoC** (`axi_noc_cips`) | hard | S00 PCIe 300 MHz, S01 PMC 100 MHz, S02 LPD 100 MHz, S03 DDR 200 MHz; M00→PL mgmt SC 300 MHz, AXI4-Lite, QoS 5 MB/s; 4× INI→DDR/DIMM @ 800 MB/s ea; 16× HBM PC @ 250 MB/s ea; all traffic class Best-Effort | Global interconnect | Adjust QoS for dataplane bandwidth |
| 9 | **DDR onboard** (`axi_noc_mc_ddr4_0`) | hard | 4 GB DDR4 @200 MHz; 4 ports, 2 used; DDR_LOW0 0x000_0000_0000..0x000_7FFF_FFFF; DDR_CH1 0x500_8000_0000..0x500_FFFF_FFFF; serves APU/RPU/IPC; carries 128 MB GCQ shared region | Mgmt/RTOS DRAM | Off-limits to user logic by convention |
| 10 | **DIMM** (`axi_noc_mc_ddr4_1`) | hard | 32 GB DDR4 DIMM @200 MHz; 4 ports, 2 used; DDR_CH2 0x600_0000_0000..0x67F_FFFF_FFFF | Bulk capacity | Main user DRAM |
| 11 | **HBM** | hard, on-die | 32 GB total; 2 stacks × 8 AXI HBM controllers × 2 PCs = 16 PCs; 1 GB direct slice per PC; cross-PC OK but slow; All-Bank Refresh; ECC off, DBI on, WDM on, temp-comp refresh off | High-BW memory | Honor PC affinity |
| 12 | **APU** | CIPS hard | 2× Cortex-A72; idle in stock AMC | — | Free CPU cores on the card |
| 13 | **RPU + AMC** | CIPS hard | 2× Cortex-R5F; FreeRTOS (OSAL swap to Linux possible); round-robin sched; main task + 5 proxy tasks (AMI/APC/ASC/AXC/BMC); FAL + OSAL; CMake profiles; AMC v2.3.0 | Board mgmt FW | Host control plane on-card |
| 14 | **PMC** | CIPS hard | Boots from OSPI; multiboot via `PMC_MULTIBOOT` reg + reset; IPI to R5/PSM | Boot/secure | A/B image swap mechanism |
| 15 | **OSPI flash** | board | 2 Gb @200 MHz; page 0 = FPT magic `0x92F7A516`; partition 0 base 0x0000_8000 size 0x07E0_0000; partition 1 base 0x07E0_8000 size 0x07E0_0000; 32 KB align | PDI storage A/B | In-system update via APC proxy |
| 16 | **eMMC** | board | 64 GB, 8-bit, 200 MHz | Secondary | Logs/large blobs |
| 17 | **Clocks** | PL | pl0_ref 100 MHz, pl1_ref 33.333 MHz, PCIe 250 MHz, PCIe-DMA 249.999 985 MHz, clk_usr_0 299.997 MHz, clk_usr_1 499.995 MHz, CPM_TOPSW 1 GHz | Clocking | Use pl1 as free-running; usr_0/1 for user logic |
| 18 | **Resets** | PL | `pl0_resetn` from CIPS; `usr_0_psr`, `usr_1_psr` keyed to clk-wiz `dcm_locked`; `pcie_psr` synchronous to 250 MHz | Reset tree | |
| 19 | **Sensors / ASDM** | mixed | Card-level (PCB power/temp), QSFP component, Versal sysmon + HBM monitor; ASC proxy on AMC; ASDM abstraction; in-band via AMI, OOB via BMC/PLDM | Telemetry | Reuse ASDM schema for dashboards |
| 20 | **AMI driver/tool** | host | Kernel module + `ami_tool` userspace; AMI v2.3.0; talks GCQ over PF0; cmds: sensor read, PDI flash, FPT update, reset, partition select | Host mgmt UX | Model for host CLI |
| 21 | **GTs / I/O** | board | CPM5 ×8 PCIe, MCIO, 4× QSFP-DD (pins exposed via `create_bd_design.tcl` + `impl.pins.xdc`) | Off-chip | Network/MCIO available to user logic |
| 22 | **Tools / OS** | host | Vivado 2024.1 (24.1 release) or 2025.1 (25.1); RHEL 9.4 k5.14 or Ubuntu 24.04 k6.8; XBTEST 7.0-4064028; newer drop `exdes_1_20251113` exists | Build matrix | Bump when porting |
| 23 | **DDR isolation caveat** | — | Docs: *"no active control prohibits unintended access to the DDR"* | Multi-tenancy risk | Relevant for multi-tenant isolation guarantees |

---

## 3. Per-row analysis — Coyote-upstream vs. AVED

### Row 1 — CPM5 PCIe Gen5×8

#### What AVED defines
| Spec | AVED |
|---|---|
| Controller | CPM5 controller **1** (PCIE1), ×8 Gen5 @ 32 GT/s |
| Why PCIE1 | PCI-SIG compliance for a single Gen5×8 controller |
| **PF0** | Management, single 64-bit BAR, **256 MB**, AXI-bridge to mgmt SmartConnect; carries UUID ROM / GCQ / HW-Discovery / NoC-remap |
| **PF1** | Data, QDMA, application DMA path |
| User PF | Hook exists but not enabled by stock AVED |

#### What Coyote-upstream does
| Spec | Coyote |
|---|---|
| Controller | ✅ CPM5 controller **1** (`CPM_PCIE1_MODES {DMA}`), matches AVED's SIG-compliance note (comment in `cr_pci.tcl` even links to the AVED doc) |
| Speed | ✅ `CPM_PCIE1_MAX_LINK_SPEED {32.0_GT/s}` |
| **PF0** | **Repurposed as QDMA**, not mgmt. `CPM_PCIE1_PF0_BAR0_QDMA_TYPE {AXI_Bridge_Master}` 1 MB at `0x0201_0000_0000` — Coyote's shell control window. `BAR2 QDMA_TYPE {DMA}`. `BAR4 AXI_Bridge_Master` 256 MB at `0x0208_0000_0000` |
| **PF1 / mgmt PF** | ❌ Does not exist. CPM_PCIE0 disabled (`CPM_PCIE0_MODES {None}`). Single PF only. |
| User PF | n/a (only one PF) |
| MSIX | `MSIX_CAP_TABLE_SIZE 0x1F` (32 vectors) |
| Driver IDs | `0xB03F / 0xB13F / 0xB23F / 0xB33F` (Coyote-defined, not AVED's) |

#### Done vs. open

✅ **Done well**
- CPM5 controller selection identical to AVED (and Coyote even cites the AVED doc explaining *why*).
- Gen5×8 link speed.
- BAR0 used as 1 MB AXI-bridge for control + BAR2/BAR4 for DMA/large windows — this is essentially AVED's PF0 mgmt-BAR pattern reused for *Coyote's* control.

⚠️ **Architecturally diverges from AVED**
- **One PF instead of two.** AVED's separation (PF0 mgmt / PF1 data) is collapsed in Coyote — all traffic, control and data, goes through one PF with QDMA. Pros: simpler driver. Cons: no isolation between mgmt and dataplane; can't bind one PF to a VM/container and reserve the other for the host.
- **BAR layout is hand-coded**, not advertised. AVED uses HW-Discovery VSEC to publish it; Coyote hardcodes the layout in driver (`pci_qdma.c` device-ID table + assumed BARs).

🟡 **Hooks worth integrating from AVED**
1. **Enable a second PF for management.** CPM5 supports up to 4 PFs in the QDMA endpoint; today Coyote uses only PF0. Adding PF1 with an AXI-bridge BAR (≤256 MB, AVED's exact pattern) gives a clean mgmt channel separate from data queues. This is the single most useful AVED hook for row 1 — it would also be the BAR home for GCQ/HW-Discovery/UUID-ROM (rows 3/4/6).
2. **PCIe VSEC for HW Discovery.** Even keeping one PF, attaching a VSEC capability removes the need to hardcode `0xB?3F` device IDs and BAR offsets in the driver.
3. **AXI-bridge MMIO size.** AVED's PF0 is 256 MB; Coyote's PF0/BAR0 is 1 MB. If you want to map vFPGA control regs *and* fold in mgmt IPs (GCQ regs, UUID, sensor mailboxes), you'll outgrow 1 MB. Consider bumping BAR0 to 16 MB or splitting onto a second PF.

#### Concrete next move for row 1
The minimal patch to `cr_pci.tcl` to add a mgmt PF (no software work yet):

```tcl
CPM_PCIE1_NUM_PF {2}
CPM_PCIE1_PF1_DEVICE_ID {<new id, e.g. 0xB04F>}
CPM_PCIE1_PF1_BAR0_QDMA_TYPE {AXI_Bridge_Master}
CPM_PCIE1_PF1_BAR0_QDMA_SIZE {256}  ;# matches AVED
CPM_PCIE1_PF1_PCIEBAR2AXIBAR_QDMA_0 {0x0202_0000_0000}
```

Then route a new NoC master from `CPM_PCIE_NOC_x` to a dedicated `pcie_mgmt_sc` SmartConnect — that becomes the home for AVED-derived mgmt IPs in future steps.

---

### Row 2 — QDMA

#### What AVED defines
| Spec | AVED |
|---|---|
| Queues | up to **2048 per device** |
| Modes | MM + ST, H2C and C2H |
| Userland | `/dev/qdma<bbddf>-<mode>-<qid>`, `dma-ctl`, `dma-perf` (libaio) |
| Driver | Upstream Xilinx `qdma` Linux driver, optional DPDK PMD |
| PFs / VFs | Multi-PF, multi-VF supported by IP; AVED itself uses 1 data PF |

#### What Coyote-upstream does
| Spec | Coyote |
|---|---|
| IP integration | ✅ MM + ST, both directions, full descriptor bypass (`dsc_bypass_h2c`, `dsc_bypass_c2h`, `dsc_pr`), user IRQ (`usr_irq`), queue status (`h2c_status`, `c2h_status`) |
| **Active queues** | `QDMA_N_ACTIVE_QUEUES = 64` per direction (so 128 streaming queues used out of 2048 the IP supports); + 1 PR/reconfig queue |
| Driver | **Custom** `driver/src/platform/pci_qdma.c` (1033 LOC, not the upstream Xilinx QDMA driver). Allocates queues at probe time into `bd_data->queues[2*64 + 1]` |
| Userland | Not `/dev/qdma*` style. Uses Coyote's vFPGA char devs (`vfpga_ops.c`) — application talks to a vFPGA, the driver maps it to a queue |
| Descriptor bypass | ✅ Used — that's how Coyote routes user requests through its MMU/CDMA stack rather than relying on QDMA descriptor formats |
| PFs / VFs | Single PF, no SR-IOV |
| Verification IPs | Dedicated `register_slice_qdma_{data,h2c_cmd,c2h_cmd}` + ECC IP (`qdma_ecc`, 57b) — Versal-only path |

#### Done vs. open

✅ **Done — and actually deeper than AVED**
- Coyote uses **descriptor bypass**, which AVED does *not* enable. Bypass lets Coyote keep its own request format and route through its TLB/MMU/CDMA — fundamentally a different model from AVED's "give me a queue, dma-ctl handles the rest."
- Both directions, both modes (MM/ST), per-queue IRQs, ECC scrubbing on QDMA inputs.

⚠️ **Limits relative to what the IP can do**
- Only **64 of 2048 queues** are active. Fine for current vFPGA counts (typically ≤4) but caps scale if you want per-vFPGA-per-thread queues for multi-tenancy.
- **No SR-IOV.** AVED doesn't use it either, but the IP supports it. For multi-tenant scenarios this is the cleanest path to per-tenant DMA isolation.
- **No `dma-ctl` / DPDK story.** AVED-style userland tooling (`dma-perf`) isn't compatible because Coyote doesn't expose `/dev/qdma*`. If a user wants raw QDMA benchmarking on a Coyote bitstream, they currently can't.

🟡 **Hooks worth taking from AVED**
1. **Optional `dma-ctl`-compatible queue subset.** Reserve, say, queues 128–255 for "raw" use, expose them as `/dev/qdma*`, leaving 0–127 for Coyote's bypass path. Useful for debug/benchmarking and would let you run `dma-perf` directly against your bitstreams.
2. **SR-IOV.** AVED's example flow shows the BAR2 DMA region is VF-capable. If multi-tenancy ever needs hardware-isolated tenants, turning on VFs in the same CPM_PCIE1 controller is mostly a CIPS-config change. Driver-side is the hard part.
3. **Increase `QDMA_N_ACTIVE_QUEUES`.** Trivial config knob (capped at 64 by a comment about an internal arithmetic constraint — `>= N_OUTSTANDING * 3`). If `N_OUTSTANDING` allows, bump to 256+ to support more concurrent vFPGAs.
4. **C2H/H2C status reporting to userspace.** AVED exposes per-queue stats via `dma-ctl`; Coyote consumes the status streams internally but doesn't surface them. Worth a sysfs entry.

#### Concrete next move for row 2
Nothing structural to change — Coyote's QDMA integration is already richer than AVED's in the dimensions that matter for an FPGA shell (bypass + per-vFPGA routing). The only changes worth making are *quantitative* (more active queues) or *additive* (SR-IOV, dual-mode raw queue subset) — not corrections.

---

### Row 3 — Generic Command Queue (GCQ) IP v2.0

#### AVED spec recap
- Dual-AXI4-Lite ring-buffer mailbox: S00_AXI=producer (host), S01_AXI=consumer (R5)
- Regs: 0x000–0x010 tail/doorbell, 0x100–0x110 head/status, 64-bit addr HIGH/LOW split
- IRQ modes: `INTERRUPT_TYPE=0x0` doorbell, `0x1` manual; outputs `irq_sq` + `irq_cq`
- Payload (SQ/CQ entries) lives in shared DDR (AVED puts 128 MB in onboard DDR4)
- AVED instance `gcq_m2r` is at BAR0+0x0101_0000..0x0101_0FFF, IRQ→LPD IRQ 0

#### What Coyote-upstream has today
**Nothing.** Searched: no `gcq`, no "command queue" IP, no comparable mailbox primitive.

What Coyote *does* have for host↔shell control:
- `axi_main` AXI4-MM master (512-bit) emerging from `smartconnect_1`, fed by **either** PCIe (CPM_PCIE_NOC_0) **or** APU/R5 (M_AXI_FPD). Goes into the shell's vFPGA control fabric.
- Per-vFPGA `axi_cnfg` register file for config/status reads.
- Doorbell pattern in Coyote is "host writes a control register, vFPGA polls or interrupts." This is a *bus-mastered* model, not a ring-buffer mailbox.

So the equivalent of "submit a command, await completion" is built into the QDMA descriptor path (with bypass) — there's no dedicated control mailbox.

#### Done vs. open

❌ **Not present.** GCQ is genuinely missing.

🟡 **Why this matters specifically**

The use cases are subtle because Coyote *already has* a host↔shell control path:

| Use case | Already covered? | Would GCQ add value? |
|---|---|---|
| Host → vFPGA register write | ✅ via `axi_main` MMIO | Marginal — adds latency unless batched |
| Host ↔ on-card R5/APU (running firmware) | ❌ no path exists today | **Yes — this is the killer use case.** PS-side firmware can't be reached over `axi_main` without a poll loop; GCQ gives it interrupt-driven SQ/CQ semantics |
| Command batching, async completions | ❌ Coyote driver waits inline on MMIO | Yes — SQ/CQ rings naturally support depth>1 with completions |
| Multi-tenant control multiplexing | ❌ shared `axi_main` register space | Yes — one GCQ instance per tenant gives lockless isolation |

The dominant reason to integrate GCQ is **once you have firmware on the R5 or APU** (row 13). Without on-card firmware, GCQ is solving a problem Coyote doesn't quite have — the existing MMIO path is faster for stateless register access.

#### Concrete integration sketch
1. **Where it attaches in BD**
   - Producer side (S00_AXI): hang off `smartconnect_1` (i.e., reachable from PCIe and from APU). Address it at, say, `0x4_0001_0000` in the FPD window, mirrored on PCIe BAR0.
   - Consumer side (S01_AXI): needs an AXI master on the R5/APU side. Today *no LPD AXI is enabled in CIPS*; you'd add `PS_USE_M_AXI_LPD` to the `PS_PMC_CONFIG` block and route it through a new `rpu_sc` SmartConnect (AVED's exact pattern).
2. **Payload buffer**
   - AVED uses 128 MB of onboard DDR4. Coyote already instantiates `axi_noc_mc_ddr4_0` (the 32 GB DIMM) — carve out a fixed window, e.g., `0x600_0000_0000 + 128 MB`, accessible to both PCIe and R5.
3. **IRQ wiring**
   - `irq_sq` → CIPS LPD PL-PS IRQ 0 (matches AVED).
   - `irq_cq` → host MSI-X via QDMA `usr_irq` bundle.
4. **Driver work**
   - Add a `gcq_dev` ops set in Coyote driver alongside `pci_qdma.c`. ~300 LOC for a basic SQ producer.
   - Userspace API: probably extend `cyt_thread`'s notification to optionally use GCQ instead of inline MMIO.

#### Status verdict for row 3
| | Coyote-upstream | AVED |
|---|---|---|
| GCQ IP present | ❌ | ✅ |
| Host↔shell control | ✅ (different mechanism — MMIO) | ✅ (GCQ + MMIO) |
| Host↔on-card firmware | ❌ | ✅ (GCQ to R5 AMC) |
| **Integration effort** | — | **Low for HW, medium for driver. Blocked-by row 13 (firmware) to be useful.** |

---

### Row 4 — Hardware Discovery IP v1.0 (PCIe VSEC)

#### AVED spec recap
- Soft IP that injects a **PCIe vendor-specific extended capability** (VSEC) into the PCIe config space
- Ext-cap base 0x600, next-ptr 0x000, header at 0x0/0x4/0x8 (fmt id, len, entry size)
- 16-byte slot entries from offset 0x10: type (e.g., 0x50 UUID, 0x54 GCQ, 0x55 NoC remapper), BAR index (3-bit), 48-bit byte offset, major/minor version
- Up to 14 endpoints × 4 PFs (so card describes its own BAR layout to the host driver)
- AXI4-Lite per-PF (`s_axi_ctrl_pf0..3`); two modes: manual table population or auto-propagation from system metadata

#### What Coyote-upstream has today
**Nothing**, but with significant existing scaffolding for the same *purpose*:

| Discovery mechanism in Coyote | How it works |
|---|---|
| **PCI device IDs** (`pci_qdma.c`) | Hardcoded table `{0xB03F, 0xB13F, 0xB23F, 0xB33F}` — each ID corresponds to a different shell variant. Driver picks behavior by ID. |
| **`axi_cnfg` shell config registers** | Static-region register block, MMIO-readable. Holds shell version, vFPGA count, capability bits (HBM, network, etc.). Coyote driver reads this at probe to learn what features the bitstream has. |
| **`cnfg` package** (`hw/hdl/pkg/`) | Build-time SV parameters — number of regions, channels, IDs — burned into the bitstream and mirrored in driver `coyote_defs.h`. |
| **UUID-like ID** | Not present — closest is the device-ID-encoded shell variant. |

So Coyote already does *runtime* discovery via `axi_cnfg`, but it's a custom register block, not the PCIe VSEC pattern. The advantage of VSEC is the driver finds it **without knowing the BAR layout first** — pure PCIe config-space walk, before any MMIO.

#### Done vs. open

🟡 **Partially solved by a different mechanism.** Coyote's `axi_cnfg` registers solve "what's in this bitstream" once the BAR is mapped. AVED's HW-Discovery solves it *before* mapping. The two are complementary.

Where AVED's approach beats Coyote's:
1. **Bootstrap independence.** Coyote driver needs to know which BAR holds `axi_cnfg` to read shell version. With VSEC, the driver finds endpoint addresses by walking PCI config space — no hardcoded BARs. Means a single Coyote driver could probe arbitrary Coyote bitstreams (current code branches on device ID).
2. **Multi-PF self-description.** If you ever add a mgmt PF (row 1 recommendation), VSEC describes both PFs uniformly. With hardcoded IDs you need a new ID per PF combination.
3. **Compatibility checking before MMIO.** VSEC type fields let the driver refuse incompatible bitstreams cleanly, without doing a (potentially crashing) MMIO probe.

Where Coyote's `axi_cnfg` already wins:
- Holds parameters too rich for a VSEC (16-byte slots). Coyote exposes ~20 fields including queue counts, MTU, MMU page size — that's a register-block job.

#### Concrete integration sketch
1. **Add HW-Discovery IP into CIPS PCIe ext-cap.** Tcl knob in `versal_cips_0`'s `CPM_CONFIG`: `CPM_PCIE1_PF0_VENDOR_ID_EXT_CAPABILITY {1}`, set base 0x600 (AVED default).
2. **Populate two entries to start:**
   - Type 0x60 (custom Coyote): UUID ROM → BAR0 offset of new UUID block
   - Type 0x61 (custom Coyote): `axi_cnfg` shell register block → BAR0 offset of current static config region
3. **Future entries** when rows 3/6 land: GCQ, mgmt mailbox, etc.
4. **Driver change in `pci_qdma.c`:** before mapping BARs, walk `pdev->pcie_capability_present()` for the VSEC; pull endpoint offsets from the table; **delete the four hardcoded device IDs** and use one wildcard ID with VSEC-driven feature detection.

This is genuinely the **lowest-effort, highest-leverage** AVED hook for Coyote, because:
- Pure HW addition (~50 lines Tcl), no firmware needed
- Driver simplification (delete the device-ID branching)
- Sets up the discovery framework for everything else AVED-derived
- Doesn't depend on on-card firmware (unlike GCQ being interesting)

#### Status verdict for row 4
| | Coyote-upstream | AVED |
|---|---|---|
| Runtime feature discovery | ✅ via `axi_cnfg` MMIO | ✅ via VSEC + table |
| Pre-MMIO BAR layout discovery | ❌ (hardcoded) | ✅ |
| Multi-PF self-description | ❌ | ✅ |
| **Integration effort** | — | **Very low. Pure HW + driver simplification. No firmware dependency.** |

---

### Row 5 — SMBus IP v1.1

#### AVED spec recap
- AXI4-Lite, SMBus 3.2 conformant, dual-role (controller + target, target can emulate 8 devices)
- Reg map: version 0x000–0x038, IRQ 0x020–0x038, PHY 0x200–0x830, target 0x600+, controller 0xA00+
- PEC supported; Quick Command unsupported as target
- AVED uses it for **out-of-band** path: card ↔ server BMC over the SMBus pins exposed on the V80 PCIe edge connector
- AVED instance `axi_smbus_rpu` lives at LPD-SmartConnect, IRQ → LPD IRQ 1, driven by R5 firmware (BMC proxy)

#### What Coyote-upstream has today
**Nothing.** No SMBus IP, no I²C/SMBus driver, no PLDM/MCTP code, no SMBus pin assignments in `v80_static_base.xdc`.

This is the **most isolated** of all AVED features — it has no host-side driver story at all in AVED (it's strictly card↔BMC), and it depends on:
- Board-level pin constraints (SMBus is on the PCIe edge connector pins — Coyote's V80 XDC doesn't expose them)
- Firmware on the R5 to run the SMBus stack (target mode is reactive, needs interrupt servicing)
- Server BMC actually wanting to talk to the card (i.e., a real datacenter chassis with a BMC, like a Dell/HPE/Supermicro server with iDRAC/iLO/IPMI)

#### Done vs. open

❌ **Not present, and notably the gap matters less than rows 3/4.**

🟡 **Why it's interesting anyway**
- **OOB survival.** SMBus stays alive when PCIe link drops, kernel panics, or the bitstream is being reloaded. For doctor-cluster style lab use this is irrelevant (you just SSH and look at the host). For production datacenter use this is *the* reason you can find/recover bricked cards remotely.
- **Telemetry off the dataplane.** Card-side power/thermal stats to BMC without consuming any PCIe bandwidth. Decoupling control telemetry from the host kernel is a clean architecture.
- **Conformance.** A "real" datacenter accelerator card supports PLDM-over-MCTP-over-SMBus. AVED demonstrates the full stack. Coyote-as-a-research-shell skips it.

#### Concrete integration sketch
1. **HW side** (~1 day work)
   - Instantiate `axi_smbus_rpu` (AVED's exact instance) on a new `lpd_mgmt_sc` SmartConnect
   - Wire SMBus pins through new XDC entries on the V80 edge connector pins (need to look up the board pinout — AVED's `impl.pins.xdc` lists them explicitly)
   - Connect IRQ to LPD PL-PS IRQ 1 (requires LPD AXI from row 3 work)
2. **FW side** (~weeks of work, this is where it gets expensive)
   - SMBus driver + PLDM/MCTP stack on the R5. AVED's BMC proxy + OOB Telemetry Application are the source — but they assume the AMC scaffolding (FreeRTOS, OSAL, FAL) which Coyote doesn't have.
   - This is **fully blocked by row 13** (AMC firmware on R5). Without firmware, the SMBus IP is just dead silicon.
3. **No host-side work.** Strictly card↔BMC.

#### When to bother
- ❌ Not now. Coyote development/testing happens over SSH; OOB has no immediate value.
- ❌ Even after row 3/4 land. Those are useful in their own right; SMBus is only useful with firmware.
- ✅ Only worth doing once AMC/firmware (row 13) is on the table — at which point SMBus + PLDM is the natural OOB story to bolt on.

#### Status verdict for row 5
| | Coyote-upstream | AVED |
|---|---|---|
| SMBus IP present | ❌ | ✅ |
| Board-level SMBus pins | ❌ (XDC missing) | ✅ |
| OOB management story | ❌ | ✅ (full PLDM/MCTP/BMC stack) |
| **Integration effort** | — | **High and depends on row 13. Not worth doing in isolation.** |

---

## 4. Cross-row summary so far (rows 1–5)

| Row | Coyote status | Real gap | Effort | When to do it |
|---|---|---|---|---|
| **1 CPM5 PCIe** | Same controller, same speed; single PF instead of mgmt/data split | No mgmt PF → no clean home for AVED mgmt IPs | Low (Tcl-only HW change) | Prerequisite for rows 3/4/6 mgmt-side work |
| **2 QDMA** | More sophisticated than AVED (descriptor bypass + MMU); narrower (64 queues, no SR-IOV, no raw `/dev/qdma*`) | Active queue count, no SR-IOV | Quantitative knobs only | Mostly leave alone |
| **3 GCQ** | Absent; partly replaced by MMIO `axi_main` | No interrupt-driven host↔R5/APU mailbox → blocks on-card firmware | Low HW + medium driver | After row 1 (mgmt PF) + paired with row 13 |
| **4 HW Discovery** | Absent; partly replaced by `axi_cnfg` MMIO | No pre-MMIO BAR self-description; driver hardcodes 4 device IDs | **Very low, no firmware dep** | **Do this first** — easiest AVED hook with real benefit |
| **5 SMBus** | Absent entirely | No OOB path at all | High HW + very high FW (PLDM stack) | Only after row 13 (firmware) lands |

### The ordering pattern that emerges
Two families of AVED features for Coyote:

1. **Firmware-independent HW IPs** (rows 4, 6 UUID, 7 NoC remapper) — quick wins, no R5 work needed
2. **Firmware-dependent HW IPs** (rows 3 GCQ, 5 SMBus, 19 sensors) — block on AMC scaffolding existing

Recommended tactical plan: do row 4 (HW Discovery) first because it's standalone and simplifies the driver immediately. Then queue rows 3/5/19 behind the bigger row 13 (AMC on R5) decision.

---

### Row 6 — UUID ROM

#### AVED spec recap
- Tiny PL block holding a **128-bit MD5 hash** of the bitstream/design at `BAR0+0x0100_1000..0x0100_1FFF` (4 KB window).
- Type `0x50` in the HW-Discovery table.
- Read-only; written once at bitstream generation time (Vitis/Vivado flow generates the MD5 over the PDI).
- Role: host driver reads it to verify the loaded design matches what the driver was compiled against.

#### What Coyote-upstream has today
**Nothing equivalent.** The closest mechanism is the PCI device ID branching in `pci_qdma.c` (`0xB03F` / `0xB13F` / `0xB23F` / `0xB33F`) — but that's a 4-bit selector, not a per-build identifier. Two different bitstreams compiled with the same Coyote config produce the same device ID, so the driver cannot tell them apart.

Some weaker identifiers exist:
- The shell version field in `axi_cnfg` (bumped manually when the shell HDL changes — not a hash).
- The build-time SV parameters in `hw/hdl/pkg/` and `coyote_defs.h`, which must match between bitstream and driver (mismatch → silent corruption today).

#### Done vs. open

❌ **Not present.** Coyote has no design-identity mechanism beyond a 4-bit device ID.

🟡 **Why it matters for Coyote**
- **Driver/bitstream skew** is a real recurring pain on V80 (the README explicitly calls out checkpoint compatibility across Vivado versions). A UUID ROM lets `coyote_driver` refuse to bind to an unknown bitstream cleanly instead of crashing on a layout mismatch.
- **PR/reconfig safety.** Coyote's reconfiguration flow (examples 05, 10) loads partial bitstreams at runtime. A per-PR-bitstream UUID would catch "wrong PR loaded into wrong shell slot."
- **Cluster diagnostics.** On doctor-cluster, knowing which exact bitstream is currently programmed on which V80 is currently a Slack-message-and-prayer affair. UUID readout via `cyt_tool` would fix that.

#### Concrete integration sketch
1. **HW**: drop a 32×32 ROM (or AXI BRAM Ctrl + initialized BRAM) on the shell mgmt SmartConnect (`smartconnect_1`). 4 KB aperture, AXI4-Lite.
2. **Generation**: hook into `scripts/main/`, after `write_bitstream`, compute MD5 of the resulting PDI and patch the init values via `updatemem` (Vitis flow does exactly this for AVED's UUID ROM).
3. **Driver**: read the 128 bits at probe; print to dmesg; expose via `/sys/class/fpga/coyote0/uuid`. Optionally check against a per-driver-build compatibility list.
4. **Pairs naturally with row 4 (HW Discovery)**: UUID ROM is a discovery type 0x50 entry, so it slots in as the first HW-Disc consumer.

#### Status verdict
| | Coyote-upstream | AVED |
|---|---|---|
| Per-bitstream identifier | ❌ | ✅ (MD5 in ROM) |
| Driver-bitstream mismatch detection | ❌ (silent) | ✅ |
| **Integration effort** | — | **Very low.** ~50 lines BD + ~30 lines driver. No firmware. **Do this alongside row 4.** |

---

### Row 7 — NoC remapper / PCIe→DDR window

#### AVED spec recap
- AVED maps **128 MB** of card DDR into the host's PCIe BAR0 view at `BAR0+0x0800_0000..0x0FFF_FFFF`.
- This window is physically the region at `0x000_3800_0000` in the V80 system address map — addresses **the onboard 4 GB DDR4** at a specific offset.
- Purpose: the host wants to read/write GCQ ring entries directly in DDR (because the AMC firmware on R5 is the other end of those rings).
- Implemented inside `axi_noc_cips` as an address remap rule, not a separate IP.

#### What Coyote-upstream has today
**No equivalent**, by deliberate design choice (see row 9 below — Coyote doesn't even use the onboard 4 GB DDR; `DDR_SIZE 0` in cmake).

What Coyote *does* expose to the host through PCIe BAR-to-AXI bridges:
| Coyote BAR | Size | AXI target | Purpose |
|---|---|---|---|
| BAR0 (`AXI_Bridge_Master`) | 1 MB @ `0x0201_0000_0000` | shell control fabric via `axi_main` | vFPGA/shell register access |
| BAR2 (`DMA`) | QDMA-managed | QDMA descriptors | Bulk DMA |
| BAR4 (`AXI_Bridge_Master`) | 256 MB @ `0x0208_0000_0000` | NoC | Larger MMIO window |

So Coyote already has a generic "PCIe address → AXI" mapping mechanism via the CPM5 `PCIEBAR2AXIBAR_QDMA_*` knobs; it just doesn't point one at DDR.

#### Done vs. open

🟡 **Mechanism present, target absent.** The Tcl pattern (`CPM_PCIE1_PF0_PCIEBAR2AXIBAR_QDMA_4 {0x0208_0000_0000}`) is the same one AVED uses; Coyote just hasn't aimed any of its BARs at a DRAM region.

⚠️ **What changes if/when GCQ lands**
If row 3 (GCQ) gets integrated, you need exactly this: a PCIe BAR window onto a chunk of DRAM where SQ/CQ entries live. AVED's design choice is reasonable — 128 MB carved from onboard 4 GB DDR — but on Coyote you'd carve it from the 32 GB DIMM instead (because Coyote doesn't enable the onboard DDR controller).

#### Concrete integration sketch — only needed alongside row 3
1. Pick a 128 MB region in the DIMM physical address range (`0x600_0000_0000`–`0x67F_FFFF_FFFF` per AVED's V80 map).
2. Add a BAR (or reuse BAR4's 256 MB) to map to that region: `CPM_PCIE1_PF0_PCIEBAR2AXIBAR_QDMA_4 {0x600_0000_0000}`.
3. NoC routing rule already exists (BAR4 already lands on the NoC via `axi_noc_0`). Add a connectivity entry in `axi_noc_0` from the BAR4-side NMU to the DIMM controller (`axi_noc_mc_ddr4_1` — though this isn't currently enabled either; see row 9).

#### Status verdict
| | Coyote-upstream | AVED |
|---|---|---|
| BAR→AXI remap mechanism | ✅ (different BARs/targets) | ✅ |
| BAR window onto DRAM specifically | ❌ | ✅ (128 MB onto DDR) |
| **Integration effort** | — | **Trivial Tcl change, but only useful as part of row 3 work.** |

---

### Row 8 — NoC (`axi_noc_cips`)

#### AVED spec recap
- Single NoC instance interfaces every master on the chip
- 4 AXI slaves from CIPS: S00 PCIe @ 300 MHz, S01 PMC @ 100 MHz, S02 LPD @ 100 MHz, S03 DDR ctrl @ 200 MHz
- 1 AXI master to PL mgmt SmartConnect (M00 @ 300 MHz, AXI4-Lite, 5 MB/s QoS)
- 4 INI masters to DDR/DIMM controllers @ 800 MB/s each
- 16 HBM pseudo-channels @ 250 MB/s each
- All traffic class **Best Effort**

#### What Coyote-upstream does
| NoC slave (input) | Coyote | Bandwidth target |
|---|---|---|
| S00 from `CPM_PCIE_NOC_0` (PCIe shell control) | ✅ | `read_bw 8, write_bw 8` (8 MB/s — control-plane only) |
| S01 from `CPM_PCIE_NOC_1` (PCIe DMA data) | ✅ | `read_bw 6400, write_bw 6400` (6.4 GB/s — **much higher than AVED**) |
| S02 from `PMC_NOC_AXI_0` (debug hub) | ✅ | `read_bw 1500, write_bw 1500` |
| S03 from DDR ctrl | ❌ — Coyote doesn't enable the onboard DDR controller |
| LPD AXI input | ❌ — `PS_USE_M_AXI_LPD` not set |

| NoC master (output) | Coyote |
|---|---|
| M00 → PL mgmt SmartConnect (`smartconnect_0`) | ✅ |
| M01 → shell control fabric SmartConnect (`smartconnect_1`) | ✅ |
| M02 → `versal_cips_0/NOC_PMC_AXI_0` (debug hub bringup) | ✅ |
| M03 → reserved | ✅ |
| INI to DDR controllers | ❌ |
| HBM PCs | ✅ via separate `inst_hbm_noc` (see row 11) |

#### Done vs. open

✅ **Already heavily customized for Coyote's needs**
- Coyote tunes per-link QoS aggressively (6.4 GB/s for dataplane, 8 MB/s for control). AVED's NoC is comparatively naive (default Best-Effort everywhere, low bandwidth allocations because the AMC firmware only does control-plane traffic).
- Two SmartConnects (`smartconnect_0` for mgmt path, `smartconnect_1` for shell control) — cleaner topology than AVED's single `pcie_slr0_mgmt_sc`.
- Already has `DEST_IDS` set explicitly per master (`M00_AXI:0x40`, `M01_AXI:0x0`, etc.) for NoC routing.

⚠️ **Two NoC paths exist on the chip but Coyote uses neither**
- **LPD AXI path** (CIPS → NoC `S02_AXI`): exists in AVED to give the R5 access to PCIe-mapped IPs (GCQ, SMBus). Coyote doesn't enable it because there's no R5 firmware to need it.
- **DDR controller path** (`S03_AXI` + INI masters): exists in AVED to bind the onboard 4 GB DDR4 into the NoC address space. Coyote skips this; the 4 GB DDR4 sits unused.

#### Hooks worth taking
1. **Enable LPD AXI** when row 3 (GCQ) or row 13 (firmware) lands. ~5 lines of Tcl in the `versal_cips_0` config block.
2. **Enable DDR controller** if you want the onboard 4 GB for IPC/scratch. Worth it only paired with row 13.
3. **Revisit QoS for HBM** once row 11 use cases stabilize — AVED uses 250 MB/s per pseudo-channel which is dramatically under-provisioned for a real workload; Coyote's HBM NoC has its own QoS table (see `cr_hbm.tcl`).

#### Status verdict
| | Coyote-upstream | AVED |
|---|---|---|
| NoC primary instance | ✅ | ✅ |
| QoS tuning | ✅ aggressive | ⚠️ minimal |
| LPD AXI path enabled | ❌ | ✅ |
| DDR controller path enabled | ❌ | ✅ |
| **Integration effort** | — | **Low.** Enable LPD path when GCQ/firmware lands. DDR path on demand. |

---

### Row 9 — Onboard DDR4 (`axi_noc_mc_ddr4_0`, 4 GB)

#### AVED spec recap
- 4 GB DDR4 @ 200 MHz, 4 ports (2 used)
- Address ranges: `DDR_LOW0 0x000_0000_0000..0x000_7FFF_FFFF`, `DDR_CH1 0x500_8000_0000..0x500_FFFF_FFFF`
- **Reserved for APU/RPU/IPC**: hosts AMC firmware stack + 128 MB GCQ shared region
- Off-limits to user logic by convention (no hardware enforcement — see row 23)

#### What Coyote-upstream does
```cmake
# cmake/FindCoyoteHW.cmake, V80 block:
# TODO (Versal): The V80 also includes DDR memory, which we could support in the future
set(DDR_SIZE 0)
set(N_DDR_CHAN 0)
```

**Explicitly disabled.** Coyote V80 builds skip the onboard 4 GB DDR entirely. The HBM is the only card-side memory. The 32 GB DIMM (row 10) is also disabled.

#### Done vs. open

❌ **Not present, and intentionally so** — but the TODO comment is honest about it being a deferred feature, not an "AVED uses it differently" thing.

🟡 **Why it matters**
- **Without onboard DDR**, putting AMC-style firmware on the R5 (row 13) has nowhere to store data. The R5 has only its TCM (256 KB) and OCM (256 KB) — fine for code but not for buffers/logs/SQ-CQ payload.
- **GCQ payload region** (row 7) is conventionally in onboard DDR per AVED. On Coyote you'd either need to enable this, or carve from the DIMM (which is also currently disabled — see row 10), or carve from HBM (wastes a high-BW resource).

#### Hooks worth taking
1. **Enable `axi_noc_mc_ddr4_0`** in `memory_infrastructure.tcl`. The IP is already invoked for U250/U280; needs the V80 branch added with the right physical pin mapping (AVED's `impl.pins.xdc` is the reference).
2. **Carve into two regions**: one for R5 firmware data (~256 MB), one for GCQ payload (128 MB), rest reserved.
3. Likely **prerequisite for row 13** to be useful at all.

#### Status verdict
| | Coyote-upstream | AVED |
|---|---|---|
| Onboard 4 GB DDR4 controller | ❌ (cmake `DDR_SIZE 0`) | ✅ |
| **Integration effort** | — | **Medium.** Enable IP, route NoC, add XDC pin map. Worth doing only with row 13. |

---

### Row 10 — DIMM (`axi_noc_mc_ddr4_1`, 32 GB)

#### AVED spec recap
- 32 GB DDR4 RDIMM @ 200 MHz, 4 ports (2 used)
- Address range `DDR_CH2 0x600_0000_0000..0x67F_FFFF_FFFF`
- General-purpose user memory (host- and PL-accessible)

#### What Coyote-upstream does
Same `DDR_SIZE 0` / `N_DDR_CHAN 0` as row 9 — the DIMM is **disabled** in current V80 builds. The HBM is treated as the only large memory.

This is despite `memory_infrastructure.tcl` already containing fully-elaborated `ddr4` IP instantiation blocks (for U250/U280 — same IP works on V80 with different pin maps).

#### Done vs. open

❌ **Not present.** The IP support exists in the codebase but the V80 branch in cmake hardwires it off.

🟡 **Why it matters**
- 32 GB is **bigger than HBM** (32 GB on V80) but cheaper per byte and doesn't compete for HBM bandwidth with user accelerators. Many ML workloads want both.
- For host-side memory expansion (CXL-like patterns), DIMM is the right answer, not HBM.
- AVED uses this address range as the "user" memory; Coyote presents HBM in that role instead.

#### Hooks worth taking
1. **Enable DIMM controller** + add it to the memory channel count exposed to vFPGAs. The existing `cdma`/striping infrastructure (see `hw/hdl/cdma/`, `hw/hdl/stripe/`) can already handle multiple memory destinations.
2. Decide on **memory model**: should DIMM appear as a separate "card memory" pool from HBM, or be transparently striped together? AVED keeps them separate (HBM = high-BW slice, DIMM = capacity); for Coyote that probably matches user expectations.
3. **Lower priority than row 9.** Row 9 enables firmware; row 10 is purely a capacity feature.

#### Status verdict
| | Coyote-upstream | AVED |
|---|---|---|
| 32 GB DIMM controller | ❌ | ✅ |
| **Integration effort** | — | **Medium-low.** IP support already in tree; just needs cmake/Tcl enabling for V80. Useful independent of firmware. |

---

### Row 11 — HBM

#### AVED spec recap
- 32 GB total, 2 stacks × 8 AXI HBM controllers × 2 pseudo-channels (PCs) = 16 PCs
- Each PC owns a 1 GB direct slice; cross-PC OK but slow
- All-Bank Refresh, ECC off, DBI on, WDM on, temp-comp refresh off
- AVED exposes HBM but the AMC firmware doesn't use it heavily — it's there for the user

#### What Coyote-upstream does
**Fully integrated and configurable**, this is one of Coyote's most developed V80 features:
- `cr_hbm.tcl` instantiates the full HBM NoC (`inst_hbm_noc`) with 16 channels / 64 ports
- Two implementation modes via `HBM_IMPL` cmake var:
  - **`unified`** (default): each card stream can hit every PC (striped via `axi_stripe` SV module, splits requests across all PCs)
  - **`block`**: each card stream pinned to one PC (AVED-style affinity model, higher single-stream BW, no cross-PC overhead)
- `HBM_SIZE=35` → 2³⁵ B = 32 GB (matches AVED)
- HBM channel configuration matches AVED almost line-for-line: `HBM_REORDER_EN FALSE`, `HBM_MAINTAIN_COHERENCY TRUE`, `HBM_REFRESH_MODE SINGLE_BANK_REFRESH` (note: AVED uses All-Bank), `HBM_RD_DBI TRUE`, `HBM_WR_DBI TRUE`, `HBM_WRITE_DATA_MASK TRUE`, ECC off
- `MC_SIZE 30`, `N_STRIPE_CHAN 32`, `MEM_OFFSET 0x4000000000` (256 GiB)
- HBM clock `HCLK_F=400` MHz

#### Done vs. open

✅ **Stronger than AVED in this dimension.** Coyote has:
- A choice of striped (unified) vs. affinity (block) HBM models. AVED only offers the equivalent of "block" through documentation; software has to manage placement.
- A dedicated `axi_stripe` SV module to transparently fan out one request across all 16 PCs — this is non-trivial logic that AVED doesn't ship.
- Configurable HBM size (the same TCL serves any HBM-equipped Versal).

⚠️ **Two minor divergences vs. AVED**
- **`HBM_REFRESH_MODE`**: Coyote uses `SINGLE_BANK_REFRESH`, AVED uses `ALL_BANK_REFRESH`. SINGLE has lower latency penalty but slightly more refresh overhead — probably the better choice for streaming workloads. Worth noting if you ever debug refresh-related stalls.
- **`HBM_PCx_PAGE_HIT 100`** in Coyote (assumes everything is row-buffer-hit) — this is just a constraint hint for the NoC's bandwidth estimation; AVED doesn't expose it.

🟡 **Possible hooks from AVED**
- AVED doesn't really add anything Coyote doesn't have. The only thing AVED has more of is **HBM thermal/health monitoring** integrated into the ASC proxy on AMC (sensor proxy — row 19). Coyote ignores HBM temperature today.

#### Status verdict
| | Coyote-upstream | AVED |
|---|---|---|
| HBM controller config | ✅ (richer) | ✅ |
| Striped/affinity choice | ✅ | ❌ (block only) |
| HBM temp monitoring | ❌ | ✅ via ASC proxy |
| **Integration effort** | — | **None needed.** Coyote already at parity-or-better. |

---

### Row 12 — APU (2× Cortex-A72)

#### AVED spec recap
- Two Cortex-A72 cores in the CIPS
- **Idle in stock AVED** — AMC firmware uses the R5 (RPU) only
- Available for application use (a real Linux can run here, Versal supports it)

#### What Coyote-upstream does
- `M_AXI_FPD` from APU is **routed into `smartconnect_1`**, meaning the APU has AXI master access to the shell control fabric at `0x4_0000_0000` (8 GB FPD window).
- `cr_pci.tcl` comment explicitly mentions this:
  > `# APU/R5 view via M_AXI_FPD: vFPGA control regs at 0x4_0000_0000 (8G FPD window).`
- **But**: no APU firmware is shipped. The `M_AXI_FPD` is wired but the cores never boot user code (only PMC/PSM bringup, which is hard-Versal stuff).

#### Done vs. open

🟡 **Infrastructure present, payload missing.** This is the same shape as row 13 below — the wires are there, the firmware isn't.

Why bother running anything on the APU at all:
- **Per-card control plane**. Move latency-sensitive control loops (scheduling, runtime reconfig decisions, sensor-driven gating) from host to card.
- **Networking offload host**. Linux on APU + DPDK on a small QSFP slice could do per-flow steering before traffic hits the user logic.
- **Free CPU cycles**. Each V80 has two idle A72s that show up in *nobody's* CPU budget. Even running a tiny gRPC server here for vFPGA control would be cheaper than burning host cycles.

#### Concrete integration sketch
1. **Lightweight**: bare-metal Vitis app on APU0, basic UART out, MMIO to vFPGA control regs via the already-wired `M_AXI_FPD` path. Effort: ~1 week.
2. **Heavier**: PetaLinux on APU pair, with `coyote_apu.ko` running there talking down to the shell. Effort: many weeks (PetaLinux build setup, root filesystem, networking).
3. **Most useful**: pair with row 13 (R5 firmware) so APU + R5 cooperate — R5 does fast control loops, APU runs higher-level logic.

#### Status verdict
| | Coyote-upstream | AVED |
|---|---|---|
| APU AXI path to shell | ✅ (M_AXI_FPD wired) | ✅ |
| Firmware running on APU | ❌ | ❌ (AVED also doesn't use it) |
| **Integration effort** | — | **Medium-high.** Pure greenfield. Useful long-term but not a quick win. |

---

### Row 13 — RPU + AMC firmware

This is the **single biggest gap**, and the one with the most leverage.

#### AVED spec recap
- 2× Cortex-R5F in lockstep or split mode
- AMC v2.3.0 firmware: FreeRTOS, OSAL/FAL/EVL abstraction layers, 5 proxy drivers (AMI/APC/ASC/AXC/BMC), round-robin task scheduler, CMake profile system
- Communicates with host via GCQ (row 3), with BMC via SMBus (row 5), with sensors via ASDM, with OSPI via APC
- Full open-source on GitHub at `Xilinx/AVED`

#### What Coyote-upstream has today
**Nothing on R5.** PSM firmware (Versal hard-block helper) is generated as a stock ELF in every build (`psm_fw.elf`), and PLM (Platform Loader Manager, the boot ROM extension) is generated as `plm.elf`. Neither is AMC; both are minimal stock-Versal binaries.

The only AMC interaction in Coyote is **as an alternative**: `use_ami.sh` and `program_fpga.sh` *swap between* the Coyote driver and AVED's `ami.ko` on rose. So today on rose you can either run Coyote, *or* run AMI — never both. That's because AMI is currently used as a programming/recovery path: load AMI's bitstream to update the V80, then swap back to Coyote.

#### Done vs. open

❌ **The single biggest absence.**

🟡 **Why it's so high-leverage**
- Every other firmware-dependent AVED row collapses to "easy" once this exists: rows 3 (GCQ), 5 (SMBus), 15 (FPT/multiboot), 19 (sensors), 20 (AMI driver/tool) all need *something* running on the R5.
- AVED hands you 80% of the scaffolding: OSAL is FreeRTOS-or-Linux portable, FAL abstracts the hardware, proxy drivers are loose-coupled. You can subset AMC down to just the proxies you need.
- The plumbing is already present: `M_AXI_FPD` reaches the shell from the PS side. The missing piece is the *consumer* — code running on R5/APU that does anything with that access.

#### Concrete integration sketch
**Phase A — Minimal AMC port** (probably 2–3 weeks for someone familiar with Vitis embedded):
1. Clone `Xilinx/AVED` AMC source. Take only OSAL, FAL, EVL, AMI proxy + APC proxy.
2. Add a Coyote CMake profile (AVED's profile system is designed for this — there are existing profiles for different Alveo cards).
3. Strip out V80-specific board mgmt (the BMC proxy is V80-OOB stuff; cut it for now).
4. Build as `amc_coyote.elf`; have PMC boot it on RPU0 via the BIF.
5. First milestone: GCQ ping-pong between host driver and AMC.

**Phase B — Useful AMC** (months of work, parallel to other stuff):
- Add sensor proxy (ASC) → row 19 lights up
- Add OSPI/programming proxy (APC) → row 15 lights up, JTAG-less reprogramming becomes possible
- Add BMC proxy (BMC) once SMBus IP is in → row 5 lights up

**Phase C — Coyote-specific firmware** (the real prize):
Once the AMC scaffolding is in place, write proxies that don't exist in AVED:
- vFPGA control proxy: GCQ commands to start/stop/reset vFPGAs, manipulate TLB entries from card-side
- vIO Switch proxy (POS-style): card-side software dataplane router
- P4 runtime stub

#### Status verdict
| | Coyote-upstream | AVED |
|---|---|---|
| R5 firmware | ❌ | ✅ (AMC v2.3.0, ~150K LOC C) |
| **Integration effort** | — | **High but tractable.** AVED gives you most of the code. Phase-A milestone is reachable in weeks. |

This is the **gateway feature**: rows 3, 5, 15, 19, 20 all become unblocked the moment a minimal AMC lands.

---

### Row 14 — PMC (Platform Management Controller)

#### AVED spec recap
- Hard block inside the Versal CIPS that's responsible for boot, multiboot, secure boot, OSPI loading, IPI routing to R5/PSM
- AVED uses it for: initial PDI load from OSPI partition 0, multiboot switching via `PMC_MULTIBOOT` reg (driven by AMC's APC proxy), IPI to R5 for AMC startup

#### What Coyote-upstream does
- `PMC_USE_PMC_NOC_AXI0 {1}` is set in the CIPS config — so the PMC NoC is wired (Coyote uses it for Debug Hub access during ILA bringup).
- `plm.elf` (PLM = Platform Loader Manager, the PMC firmware) is **generated per build** automatically by Vitis as part of `make project`.
- No multiboot use, no OSPI partitioning. Coyote programs via JTAG (`program_fpga.sh` calls Vivado's `run_vivado.sh` to do JTAG download), so the PMC's flash-loading path is unused.

#### Done vs. open

✅ **PMC is "used" but only by virtue of being the boot agent.** Coyote doesn't drive any of its runtime-mgmt features.

🟡 **What changes with row 15 (FPT/multiboot)**
The PMC becomes interesting only once you start using its multiboot mechanism. The PMC itself doesn't need integration work; the wrapper (FPT in flash, APC proxy in AMC) does.

#### Status verdict
| | Coyote-upstream | AVED |
|---|---|---|
| PMC instantiated | ✅ (auto, Versal hard block) | ✅ |
| `plm.elf` generated | ✅ | ✅ |
| Multiboot / runtime reload driven by PMC | ❌ | ✅ |
| **Integration effort** | — | **Zero standalone work for PMC itself.** Becomes interesting via row 15. |

---

### Row 15 — OSPI flash + FPT + multiboot

#### AVED spec recap
- 2 Gb OSPI flash on the V80 board, accessed via PMC at boot, and via APC proxy at runtime
- Page 0 = Flash Partition Table (magic `0x92F7A516`), defines 2 partition slots of ~126 MB each
- Primary slot at offset `0x0000_8000`, backup at `0x07E0_8000`
- AMC's APC proxy can program either slot at runtime, then trigger multiboot via `PMC_MULTIBOOT` + reset to swap
- Result: no JTAG needed for field updates. Image A/B fallback for safety.

#### What Coyote-upstream does
- **Programming is JTAG-only**: `program_fpga.sh` invokes Vivado (`run_vivado.sh`) which connects to the V80 via `hw_server` over JTAG cable
- **No OSPI use whatsoever**: the OSPI flash is fully managed by AVED — you have to swap between Coyote's driver and AMI on rose if you want to use OSPI features (`use_ami.sh`)
- **Workflow**: build PDI → JTAG-program → load Coyote driver → run. If something breaks, JTAG again.

#### Done vs. open

❌ **Coyote bypasses the entire OSPI/FPT/multiboot infrastructure.** It's deferred to AVED tooling, which the user is expected to invoke separately (see `use_ami.sh`).

🟡 **Why it matters**
- **Dev loop time**: JTAG programming is slow (~minutes per cycle) and requires a physical cable. OSPI + AMI programming is faster.
- **Deployment**: on doctor-cluster or any rack-mounted setup, JTAG is *impossible* (no physical access). Field updates require the OSPI path.
- **Recovery**: A/B partitioning is the standard datacenter pattern for safe firmware updates. Coyote has no story here.

🟡 **Why Coyote can ignore it right now**
The current Coyote workflow is "swap to AMI when you need to flash, swap back when you want to run Coyote." That works on rose because rose is a dev box with JTAG access *and* AMI installed. It's not viable for production deployment, but for research it's fine.

#### Concrete integration sketch
1. **Cheap option**: keep the AMI-swap dance. Document it. Done.
2. **Medium**: add a Coyote-side OSPI partition (slot 3?) reserved for Coyote PDIs. Still uses AMI for programming.
3. **Full**: integrate AVED's APC proxy into a Coyote AMC build (depends on row 13). Then `cyt_tool program` writes to OSPI directly via PCIe + AMC, no JTAG.

The full path needs:
- Row 13 (AMC scaffolding on R5)
- AVED's APC proxy ported into Coyote AMC
- An FPT in OSPI with at least one Coyote slot
- Host-side `cyt_program` tool that talks to AMC via GCQ to drive the flash

#### Status verdict
| | Coyote-upstream | AVED |
|---|---|---|
| OSPI integration | ❌ (delegated to AMI) | ✅ |
| Field update without JTAG | ❌ | ✅ |
| A/B partition / fallback | ❌ | ✅ |
| **Integration effort** | — | **High.** Worth it only after row 13 + GCQ + AMI-equivalent host tool. |

---

### Row 16 — eMMC (64 GB secondary storage)

#### AVED spec recap
- 64 GB eMMC, 8-bit, 200 MHz, accessible via PMC SD/eMMC controller
- AVED uses it as secondary storage (logs, large blobs, alternate boot path)

#### What Coyote-upstream does
**Untouched.** Coyote has no eMMC driver, no use case, no references in the codebase. The eMMC IP is hard so it's physically present, just inaccessible without firmware to drive it.

#### Done vs. open

❌ **Not present.** Honestly, **not particularly important either**. The eMMC is useful for:
- Persistent logs from card-side firmware (depends on row 13 anyway)
- Storing alternate PDIs as a third boot path beyond OSPI's two slots
- Hosting a small root filesystem if you ever run Linux on the APU (row 12)

None of these are needs Coyote has today.

#### Status verdict
| | Coyote-upstream | AVED |
|---|---|---|
| eMMC support | ❌ | ✅ (referenced but lightly used) |
| **Integration effort** | — | **Low-medium**, but no urgent use case. **Skip.** |

---

### Row 17 — Clocks

#### AVED spec recap
- `pl0_ref_clk` 100 MHz, `pl1_ref_clk` 33.333 MHz (free-running), PCIe 250 MHz, PCIe-DMA 249.999985 MHz, `clk_usr_0` 299.997 MHz, `clk_usr_1` 499.995 MHz, CPM_TOPSW 1 GHz
- All driven from CIPS or `usr_clk_wiz`

#### What Coyote-upstream does
| Coyote name | Default | Source | Equivalent in AVED |
|---|---|---|---|
| `sclk_f` (system clock) | **333 MHz** for V80 (forced when building shell) | `clk_wiz_0` driven by `pl0_ref_clk` | ~`pl0_ref_clk` (100 MHz) — Coyote up-clocks it |
| `aclk_f` (AXI clock) | 400 MHz | derived from `sclk_f` | ~`clk_usr_0` (300 MHz) — Coyote uses higher |
| `nclk_f` (network clock) | 250 MHz | clk_wiz | ~PCIe clock |
| `uclk_f` (user clock) | 250 MHz | clk_wiz | ~`clk_usr_1` |
| `hclk_f` (HBM clock) | 400 MHz | clk_wiz | n/a (HBM-specific) |

Coyote also has the hard constraint that **`SCLK_F=333` MHz must match the shipped static checkpoint** — there's an explicit cmake message about this:
> ` ** V80 with BUILD_SHELL=1 or BUILD_APP=1 selected, defaulting SCLK_F to 333 MHz to match the shipped static checkpoint`

#### Done vs. open

✅ **Coyote has its own clock tree and runs it faster than AVED.** This is a strength, not a gap.

⚠️ **No structural overlap with AVED's clock plan**
- AVED targets 300/500 MHz user clocks; Coyote targets 400 MHz aclk. Numbers differ but the *infrastructure* (clk_wiz fed from CIPS) is identical.
- No reason to align with AVED here — the AMC firmware doesn't care what clock the PL fabric runs at.

#### Status verdict
| | Coyote-upstream | AVED |
|---|---|---|
| Clock tree | ✅ richer, higher freq | ✅ |
| **Integration effort** | — | **None.** Already independent. |

---

### Row 18 — Resets

#### AVED spec recap
- `pl0_resetn` from CIPS, `usr_0_psr` / `usr_1_psr` keyed to clk-wiz `dcm_locked`, `pcie_psr` synchronous to 250 MHz PCIe clock

#### What Coyote-upstream does
- Has `proc_sys_reset_a`, `proc_sys_reset_n`, `proc_sys_reset_u` (one per clock domain — `aclk`, `nclk`, `uclk`) in `cr_ctrl.tcl`
- All driven by `clk_wiz_0/locked` (same pattern as AVED's `dcm_locked`)
- Plus dedicated reset for PCIe clock domain

Effectively identical pattern to AVED, scaled to Coyote's three clock domains.

#### Status verdict
| | Coyote-upstream | AVED |
|---|---|---|
| Reset tree | ✅ (3-domain) | ✅ (3-domain) |
| **Integration effort** | — | **None.** |

---

### Row 19 — Sensors / ASDM telemetry

#### AVED spec recap
- Three sensor categories: card-level (PCB power, temp), component (QSFP serials), FPGA (Versal sysmon + HBM monitors)
- ASDM (Alveo Sensor Data Model) abstraction layer
- ASC proxy on AMC samples and exposes sensors
- Two access paths: in-band via AMI/GCQ to host, out-of-band via BMC/PLDM
- Threshold monitoring → AMC can throttle clocks if sensors trip

#### What Coyote-upstream does
**Nothing.** No sysmon access, no QSFP I²C, no HBM temp monitoring, no telemetry interface to host.

The Versal sysmon IP block exists on every V80 (hard primitive); Coyote just doesn't instantiate an access path to it.

#### Done vs. open

❌ **Telemetry is a clean blank slate in Coyote.**

🟡 **Why it matters**
- **Thermal awareness for vFPGA scheduling**: if your placement decisions don't account for card temp, you'll thermally throttle without knowing why. POS-style multi-tenant scheduling is much more interesting if it has thermal input.
- **Power capping**: datacenter cards must be able to throttle to stay in power envelope. AVED has this loop; Coyote doesn't.
- **Diagnostics**: "is the card okay?" is currently answered by `dmesg | grep coyote` and squinting at LED colors. ASDM-style sensor readout via `cyt_tool sensors` would be a quality-of-life win.

#### Concrete integration sketch
- **Without AMC**: instantiate a sysmon AXI4-Lite IP in PL, expose registers via `axi_main`, expose via sysfs. Effort: ~1 day. Covers FPGA die temp + supply voltages.
- **With AMC** (row 13): port AVED's ASC proxy + ASDM. Covers all three sensor categories. Effort: included in row 13 Phase B.

#### Status verdict
| | Coyote-upstream | AVED |
|---|---|---|
| Die-temp sensor access | ❌ | ✅ |
| Power/board sensors | ❌ | ✅ |
| HBM temp | ❌ | ✅ |
| QSFP serials | ❌ | ✅ |
| **Integration effort** | — | **Low for sysmon alone; full ASDM requires row 13.** |

---

### Row 20 — AMI driver + ami_tool

#### AVED spec recap
- Host-side: AMI Linux kernel module + `ami_tool` userspace
- Talks to AMC over GCQ on PF0
- Commands: sensor read, PDI flash, FPT update, reset, partition select
- Replaces Xilinx's older `xrt` for V80

#### What Coyote-upstream does
- `coyote_driver` is Coyote's own kernel module — distinct from AMI, talks QDMA directly
- `cyt_tool` and example userspace are Coyote-specific (no AMI compatibility)
- On rose specifically, **the user is expected to swap between Coyote driver and AMI driver** depending on whether they want to *run* the FPGA (Coyote) or *administer* it (AMI). `use_ami.sh` automates the swap.

#### Done vs. open

🟡 **Coexists with AMI rather than replacing it.** Coyote takes the QDMA dataplane; AMI handles administration (flashing, sensors, reset). Two drivers, two userspaces, two cohabitating roles.

⚠️ **The split is ugly because**:
- You can't run them simultaneously (only one driver binds at a time on the V80 PF)
- You have to remember which mode the card is in
- Anything you'd want to do *while* Coyote is running (e.g., read sensor while a vFPGA workload runs) requires either swapping out (and losing state) or building it into Coyote

#### Hooks worth taking
1. **Subset AMI behaviors into Coyote**: implement sensor read, hot-reset, programming, in Coyote driver. Then `use_ami.sh` becomes unnecessary. Depends on row 13 (AMC needs to exist to *answer* these queries).
2. **Or**: enable a second PF (row 1 recommendation) and let AMI bind to PF1 while Coyote keeps PF0. Cleaner but needs HW + driver work on both sides.

#### Status verdict
| | Coyote-upstream | AVED |
|---|---|---|
| Host admin tool | ⚠️ delegated to AMI | ✅ ami_tool |
| Drivers can coexist | ❌ (swap-only on single PF) | ✅ (single AMI on its own PF) |
| **Integration effort** | — | **High.** Tied to row 1 + row 13. Real fix is to make Coyote driver subsume admin functions. |

---

### Row 21 — GTs / I/O (PCIe, MCIO, 4× QSFP-DD)

#### AVED spec recap
- CPM5 ×8 for PCIe Gen5
- MCIO connector for chip-to-chip
- 4× QSFP-DD cages for networking
- AVED only uses PCIe; the QSFPs and MCIO are exposed pins for user logic

#### What Coyote-upstream does
| GT use | Status |
|---|---|
| PCIe via CPM5 | ✅ Gen5×8 (row 1) |
| QSFP-DD cages | ⚠️ **Partial**. `EN_NET_0` enables CMAC on QSFP0; `EN_NET_1` on QSFP1 (mutually exclusive with `EN_AURORA_1`); `EN_AURORA_1` adds Aurora 64B/66B alongside CMAC. But the README still says *"V80 currently without networking"* — which means RDMA/TCP stacks (which depend on CMAC) aren't actually wired up for V80 yet. Aurora-only example (`14_aurora_loopback`) works. |
| MCIO | ❌ — exposed pins via `create_bd_design.tcl` but no Coyote-side use |

`program_fpga.sh` even has an explicit comment:
> `V80: no IP assigned yet, RDMA/TCP not yet supported on V80 in Coyote.`

#### Done vs. open

🟡 **Partial.** CMAC is half-wired, Aurora works, RDMA/TCP blocked, MCIO untouched.

This is one of the **biggest non-AVED-related gaps** in V80 support. AVED doesn't help here because AVED itself doesn't ship networking IP — both Coyote and AVED treat QSFP as user-exposed.

#### Hooks
- Not AVED-derived. Pure Coyote development work.
- The relevant gap is hooking the existing RDMA/TCP stacks (which work on UltraScale+) into V80's CMAC + AXI plumbing. Likely a `EN_RDMA + EN_NET_0 + FDEV_NAME=v80` build path that doesn't currently exist.

#### Status verdict
| | Coyote-upstream | AVED |
|---|---|---|
| PCIe | ✅ | ✅ |
| QSFP CMAC | ⚠️ partial | ❌ (AVED doesn't ship CMAC) |
| QSFP RDMA/TCP | ❌ (V80) | ❌ |
| Aurora | ✅ | ❌ |
| MCIO | ❌ | ❌ |
| **Integration effort** | — | **Independent of AVED — Coyote-internal work.** |

---

### Row 22 — Tools / OS support matrix

#### AVED spec recap
- 24.1 release: Vivado 2024.1, AMC 2.3.0, AMI 2.3.0, XBTEST 7.0-4064028
- 25.1 release: Vivado 2025.1, RHEL 9.4 / Ubuntu 24.04 kernel 6.8
- 25.11 latest exists: `amd_v80_gen5x8_exdes_1_20251113`

#### What Coyote-upstream supports
- Vivado **2024.2 or newer**, **extensively tested 2024.2 / 2025.1** for V80
- Linux kernels tested: 5.4, 5.15, 6.2, 6.8
- CMake ≥ 3.5, C++17
- NixOS support via `shell.nix` and the rose-specific `xilinx-shell` FHS env (NOTES.md has the rose-specific recipe)

#### Done vs. open

✅ **Coyote's tool matrix is broader than AVED's**: tested on multiple Vivado versions, multiple kernels, Nix + non-Nix.

⚠️ **One alignment concern**: when Coyote consumes AVED-derived components (AMC source, AMI driver), it should pin to the AVED release Coyote is using. Right now `use_ami.sh` assumes whatever AMI is at `/share/xilinx/aved/ami.ko` on rose — no version check.

#### Status verdict
| | Coyote-upstream | AVED |
|---|---|---|
| Vivado matrix | ✅ wider | ✅ |
| OS matrix | ✅ wider | ✅ |
| AVED version pinning | ⚠️ implicit | ✅ explicit |
| **Integration effort** | — | **Just document the AVED version Coyote tests against.** |

---

### Row 23 — DDR isolation caveat

#### AVED spec recap
- AVED docs state: *"there is no active control that prohibits unintended access to the DDR"*
- Isolation between APU/RPU memory regions, GCQ payload, and user regions is **by convention only**

#### What Coyote-upstream does
- Coyote has its own isolation mechanism via the **MMU and TLB** (in `hw/hdl/mmu/`) — per-vFPGA virtual memory, page-table walks, fault handling.
- This is **stronger than AVED's "by convention"** model — vFPGAs literally can't address memory outside their TLB mappings.
- But: Coyote's MMU protects user vFPGAs from each other and from host. It doesn't protect any *card-side firmware regions* because none exist (row 13).

#### Done vs. open

✅ **Coyote already has the better isolation story for its current scope.**

⚠️ **What changes if AMC firmware lands** (row 13)
- AMC code/data regions in DDR would need protection from user vFPGAs.
- Versal does have hardware-level memory protection (XMPU/XPPU) — AVED doesn't use them, but Coyote could.
- This is forward-looking; not a current gap.

#### Status verdict
| | Coyote-upstream | AVED |
|---|---|---|
| User-tenant isolation | ✅ MMU-enforced | ❌ "by convention" |
| Firmware region isolation | n/a (no firmware) | ❌ "by convention" |
| **Integration effort** | — | **None now.** Watch when row 13 lands. |

---

## 5. Final cross-row summary (all 23 rows)

### By status

| Status | Rows | Notes |
|---|---|---|
| ✅ Coyote at parity or better | 1 (CPM5), 2 (QDMA), 8 (NoC), 11 (HBM), 17 (clocks), 18 (resets), 22 (tools), 23 (isolation) | Coyote-upstream already handles these; AVED doesn't add anything. |
| 🟡 Partial — Coyote uses different mechanism | 4 (HW-Discovery vs `axi_cnfg`), 14 (PMC — present but unused for mgmt), 20 (AMI coexists), 21 (networking — partial) | Coyote has *something*, AVED's pattern would improve or generalize. |
| ❌ Coyote missing, AVED has it | 3 (GCQ), 5 (SMBus), 6 (UUID), 7 (NoC remap to DDR), 9 (onboard DDR), 10 (DIMM), 12 (APU FW), 13 (AMC FW), 15 (FPT/multiboot), 16 (eMMC), 19 (sensors) | Real gaps. Most depend on row 13. |

### By integration priority

| Priority | Rows | Why |
|---|---|---|
| **🟢 Tier 1 — do soon, independent, low effort** | 4 (HW Discovery), 6 (UUID ROM) | Pure HW IP drops, simplify the driver, no firmware needed. Should be done together. |
| **🟡 Tier 2 — gateway feature, biggest leverage** | 13 (AMC firmware on R5) | Unlocks rows 3, 5, 15, 19, 20. Many weeks of work but each subsequent row collapses to "easy." |
| **🟠 Tier 3 — needs row 13, but high value once available** | 3 (GCQ), 19 (sensors), 20 (AMI replacement) | Direct firmware consumers. Build these onto AMC as Phase B. |
| **🟠 Tier 4 — capacity / deployment features** | 9 (onboard DDR), 10 (DIMM), 15 (FPT/multiboot), 7 (BAR-to-DDR remap) | Useful but not critical. Most need row 13 or capacity decisions. |
| **🔴 Tier 5 — skip for now** | 1 second PF (medium effort, blocks on use case), 5 (SMBus — needs FW + chassis), 12 (APU firmware), 16 (eMMC), 21 (network — Coyote-internal not AVED-related) | Niche or out-of-scope. |

### Recommended sequencing

1. **First**: Tier 1 — rows 4 + 6. Single PR. Adds VSEC + UUID ROM. Driver simplification.
2. **Then**: Decide whether to commit to Tier 2 (row 13, AMC firmware port). This is the strategic question.
   - If **yes**: scope a 4-week Phase A milestone (GCQ ping-pong between host and minimal AMC).
   - If **no**: stop. Tier 3+ all blocked. Coyote stays as-is for V80.
3. **If Tier 2 commits**: rows 3 → 19 → 20 → 15 in roughly that order, as proxies in the growing AMC.
4. **Independently**: row 21 (V80 networking) — Coyote's own roadmap, AVED has nothing to offer.

### The big picture

The AVED reference design adds **two things** that Coyote-upstream doesn't have:

1. **A self-describing PCIe device** (HW-Discovery + UUID + VSEC) — *cheap*, immediate driver hygiene win.
2. **A real card-side software stack** (AMC firmware ecosystem) — *expensive*, but turns the V80 from "an FPGA on a PCIe card" into "a co-processor with its own management plane" and unlocks every other AVED feature.

Coyote already wins on raw FPGA dataplane (QDMA bypass, HBM striping, MMU isolation, multi-clock-domain tuning) and on networking ambition (CMAC/RDMA/Aurora roadmap). The integration question for the foreseeable future is whether Coyote should also adopt AVED's *card-side software* dimension — because every interesting AVED feature beyond Tier 1 lives or dies there.

---

# Part 2 — V80-specific research directions

This part is independent of AVED. It captures architectural research
opportunities that the V80's hardened-NoC + 3-SLR layout enables but that
Coyote-upstream doesn't yet exploit.

## 6. SLR-partitioned vFPGAs — scaling vFPGA count past U280's ceiling

### Motivation

Multi-vFPGA Coyote builds on U280 typically run out of routing past ~4
vFPGAs. The reason isn't fabric area — it's that Vivado's placer clumps
vFPGAs together because the soft-IP-heavy U280 shell already occupies
most of one SLR, and SLL crossings between the rest of the SLRs are
costly. V80 changes the situation:

| Property | U280 | V80 |
|---|---|---|
| SLR count | 3 | 3 |
| Static-shell footprint | XDMA + CMAC + DDR all soft IP, fills most of one SLR | CPM5 PCIe is hard, HBM controllers are hard, NoC is hard — shell fabric usage is small |
| Inter-SLR fabric crossings | Soft AXI through SLL pblocks (timing pain) | NoC absorbs cross-SLR traffic |
| Free PL area for vFPGAs | ~60% of one SLR plus scraps | Most of SLR1+SLR2 plus much of SLR0 |

The structural advantage is real: V80's static shell uses much less PL
because the dataplane plumbing is hardened. That headroom is the
substrate for many vFPGAs — *provided you tell Vivado where to put them*.

### What Coyote-upstream already has

Floorplan infrastructure is in place:

| Mechanism | Status | Reference |
|---|---|---|
| `EN_SHELL_PBLOCK` cmake knob | ✅ | `cmake/FindCoyoteHW.cmake` |
| `FPLAN_PATH` user-supplied vFPGA floorplan, **mandatory** in V80 PR flow | ✅ | `scripts/dyn/flow_dyn_versal.tcl.in:85` |
| `link_design -reconfig_partitions` per-vFPGA | ✅ | same file, lines 96–100 |
| `N_REGIONS` ≥ 15 supported by build logic | ✅ | `cmake/FindCoyoteHW.cmake` |
| Versal PR forces `EN_SHELL_PBLOCK=0` (no nested DFX) | ✅ enforced | `cmake/FindCoyoteHW.cmake:560` |
| V80 dynamic-region floorplan (out-of-box) | ❌ before this work | — |

The existing `examples/10_app_reconfiguration/hw/floorplans/example_fplan_v80.xdc`
demonstrates one vFPGA in a hand-tuned rectangle but it crosses an SLR
boundary (SLICE_X204Y192:Y383 straddles SLR0/SLR1) — not a general
solution.

### Phase 1 — ✅ implemented in this repo

A default SLR-aware floorplan that distributes up to 6 vFPGAs across all
three SLRs while respecting the shipped routed-locked static checkpoint.

**Deliverables added:**

* [`hw/constraints/v80/vfpga_fplan/v80_vfpga_slr_floorplan.xdc`](../hw/constraints/v80/vfpga_fplan/v80_vfpga_slr_floorplan.xdc)
  — introspective XDC that creates pblocks only for the
  `user_wrapper_<idx>` cells that exist. Same file serves any
  `N_REGIONS` in 1..6.
* [`hw/constraints/v80/vfpga_fplan/README.md`](../hw/constraints/v80/vfpga_fplan/README.md)
  — full layout map, per-vFPGA region table, usage example, caveats.

**V80 CR map (after subtracting the shipped shell pblock):**

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

**Per-vFPGA assignment (priority order: largest first):**

| idx | SLR  | CR range          | size class |
|-----|------|-------------------|------------|
| 0   | SLR0 | X0Y0  :  X4Y3     | big (~20 CRs) |
| 1   | SLR2 | X8Y8  : X10Y11    | medium (~12 CRs) |
| 2   | SLR2 | X0Y8  :  X0Y11    | small (thin column) |
| 3   | SLR1 | X9Y4  : X10Y7     | small |
| 4   | SLR1 | X0Y4  :  X0Y7     | small (thin column) |
| 5   | SLR0 | X9Y1  : X10Y2     | small |

**Usage:**

```bash
cmake .. -DFDEV_NAME=v80 -DBUILD_APP=1 -DEN_PR=1 -DN_REGIONS=6 \
    -DFPLAN_PATH=$(realpath hw/constraints/v80/vfpga_fplan/v80_vfpga_slr_floorplan.xdc)
```

**Known limitations:**

* **SLR1 is the bottleneck** — the shipped static shell traverses SLR1
  to route between the SLR0-anchored CPM/HBM and the upper PL. Only
  thin left (X0) and right (X9..X10) column strips are free. SLR1 vFPGA
  slots (idx 3, 4) won't fit large accelerators.
* Layout assumes the shipped V80 static checkpoint
  (`hw/checkpoints/static_routed_locked_v80_gen5.dcp`). If the static
  is rebuilt with different pblocks, this floorplan must be updated.
* Past `N_REGIONS=6`, you must extend the partition table or unlock
  more area via Phase 2 (rebuild static shell).

### Phase 2 — audit completed, proposal below

Initial hypothesis: the shell pblock occupies wide CR ranges across all
three SLRs partly to keep AXI routing from CPM5 → NoC → upper PL
inside a single pblock, with most of those CRs *not actually used* by
shell logic.

**Audit method.** I opened the shipped routed-locked DCP
(`hw/checkpoints/static_routed_locked_v80_gen5.dcp`) plus a minimal
post-route shell DCP
(`examples/01_hello_world/hw/build/checkpoints/shell_routed.dcp`) in
Vivado 2025.1 and ran `report_utilization -pblocks pblock_inst_shell`
plus pblock property introspection.

#### Audit findings

**1. The pblock is a DFX reconfigurable partition, not routing reserve.**

```
pblock_inst_shell properties:
  HD.RECONFIGURABLE      = 1          ← shell is a DFX partition
  EXCLUDE_PLACEMENT      = 1          ← static cannot place inside
  CONTAIN_ROUTING        = 1          ← nets inside pblock must stay inside
  IS_SOFT                = 0          ← hard boundary
  CELL_COUNT             = 1          ← only inst_shell
  RECTANGLE_SITES_COUNT  = 486 823    ← reserved sites
  SLR(s) covered         = SLR0,SLR1,SLR2
```

The "wide pblock = routing reservation" hypothesis is **partly right but
the right framing is DFX**. Vivado isn't reserving routing wires — it's
reserving a physical region for the future `inst_shell` partition. The
shell logic *must* fit inside, and no static or user cells can be placed
in there. So the audit question is: **how much of that reserved area
does the shell actually need?**

**2. The shell uses ~10% of the device, 20% of SLR0, and almost nothing
   in SLR1 / SLR2.**

Post-route utilization (from `report_utilization` on `shell_routed.dcp`,
minimal `hello_world` example, `N_REGIONS=1`):

```
17. SLR CLB Logic and Dedicated Block Utilization
                       SLR0     SLR1   SLR2   SLR0%   SLR1%   SLR2%
SLICE                  22 663    960   2 019  20.14    0.94    1.89
  SLICEL               11 461    578     954  20.37    1.13    1.79
  SLICEM               11 202    382   1 065  19.91    0.75    2.00
CLB LUTs               88 260  2 445   6 369   9.80    0.30    0.75
CLB Registers         190 306  7 144  11 532  10.57    0.44    0.68
Block RAM Tile (RAMB36+B18)
                        101.5      0       0   7.57    0.00    0.00
URAM                        0      0       0      0       0       0
DSP Slices                  0      0       0      0       0       0

Total shell SLICE = 25 642  →  9.56 % of device-wide SLICEs
```

Headline numbers:

* **SLR0:** 22 663 SLICEs (88 % of all shell SLICEs) — this is where the
  CPM5/HBM-anchored shell logic lives.
* **SLR1:** **960 SLICEs (0.94 % of SLR1's slices, 3.7 % of all shell
  SLICEs).** The shell barely uses SLR1.
* **SLR2:** 2 019 SLICEs (7.9 % of all shell SLICEs).
* **All shell BRAM is in SLR0.** Shell uses no URAM and no DSP.

For comparison, the pblock reserves ~32 CRs per SLR (×3 SLRs ≈ 100 CRs
total). Per-CR shell utilization tops out at 1.6 %, with the SLR1 portion
at uniform 1.0–1.5 %. That means tens of slices per CR — easy to compact.

**3. Cross-SLR connectivity (SLLs) is light.**

```
15. SLR Connectivity
                 Used   Available   Util%
SLR2 ↔ SLR1     1 274      18 870    6.75
SLR1 ↔ SLR0     1 275      18 870    6.76
Total SLLs used 2 549
```

The shell uses ~6.7 % of available SLLs in each direction. Plenty of
headroom; not a routing bottleneck.

**4. SLR1's 960 shell SLICEs are distributed thin across the entire
   SLR.** No "hotspot" pinning all the SLR1 logic into one corner —
the placer spread it. This is fixable with placement directives or by
shrinking the SLR1 pblock area (forcing the placer to pack).

#### Quantitative reclaim opportunity

Given:

* Shell needs 960 SLR1 SLICEs.
* One V80 CR holds roughly 600–2 200 SLICEs depending on column type.
* So **the entire SLR1 shell footprint could fit in 1–2 CRs.**
* The current pblock reserves ~30 CRs of SLR1.

**Reclaim potential: ~28 CRs of SLR1**, plus modest gains in SLR2 (the
shell uses 2 019 SLICEs in SLR2 vs. ~32 CRs reserved). Total: roughly
**30–40 additional CRs of vFPGA-usable area** if Phase 2 succeeds.

That converts the Phase 1 "two thin column strips in SLR1" into "an
entire mid-band of SLR1 available for substantial vFPGAs."

#### Caveats from the audit

* The audit was done on `hello_world`'s minimal shell config (no
  networking, no extra services). A shell with `EN_RDMA=1` or
  `EN_TCP=1` will be larger. The 25 k SLICE figure is a lower bound;
  realistic shells are perhaps 1.5–2× bigger but should still fit
  comfortably in SLR0+SLR2.
* The 960 SLR1 SLICEs are spread uniformly across SLR1's CRs in the
  pblock. Vivado placed them there because it had the space, not
  because they had to be there. Constraining the pblock will force
  the placer to consolidate — generally this is fine, but it may
  surface new timing edges (cross-SLR pipeline-register insertion
  may be needed if the placer can no longer find local registers).
* `CONTAIN_ROUTING = 1` means cross-SLR shell nets must stay inside
  the pblock. If the pblock is narrowed in SLR1 to a single column,
  routes between SLR0 and SLR2 shell logic must funnel through that
  column. This is fine for ~2 549 SLL nets (6.7 % SLL utilization)
  but worth re-measuring after pblock shrink.
* All shell BRAM lives in SLR0. Good — no relocation needed.
* No DSP / URAM in the shell. The audit confirms the shell is
  pure glue logic (AXI register slices, FIFOs, MMU page tables in
  BRAM, control state). It can be made very compact in principle.

#### Proposed tighter `v80_static_floorplan.xdc`

Concrete strawman based on the audit. Two strategies:

**Strategy A — narrow SLR1 corridor (recommended).**

Replace the existing SLR1 CR ranges in `v80_static_floorplan.xdc`:

```diff
- resize_pblock [get_pblocks pblock_inst_shell] -add \
-     {CLOCKREGION_X1Y5:CLOCKREGION_X9Y6 \
-      CLOCKREGION_X1Y7:CLOCKREGION_X8Y10 \
-      CLOCKREGION_X5Y3:CLOCKREGION_X9Y4}
+ # SLR1 corridor: 2-CR wide vertical strip (X5..X6, Y5..Y6) for ~960
+ # shell SLICEs + cross-SLR routing. Keep SLR0/2 boundary rows wide
+ # enough for SLL ingress/egress.
+ resize_pblock [get_pblocks pblock_inst_shell] -add \
+     {CLOCKREGION_X5Y3:CLOCKREGION_X9Y4 \
+      CLOCKREGION_X5Y5:CLOCKREGION_X6Y6 \
+      CLOCKREGION_X5Y7:CLOCKREGION_X8Y7 \
+      CLOCKREGION_X1Y8:CLOCKREGION_X8Y10}
```

This frees roughly:

* SLR1 left half (X1..X4, Y5..Y6): 8 CRs
* SLR1 right half (X7..X9, Y5..Y6): 6 CRs
* SLR1 left strip (X1..X4, Y7): 4 CRs

**~18 SLR1 CRs become available** for vFPGAs. Combined with Phase 1's
already-free X0, X9, X10 strips, the SLR1 vFPGA area grows from ~8 thin
CRs to ~26 CRs of usable space — turning SLR1 from "small vFPGAs only"
into a host for substantial accelerators.

**Strategy B — SLR1 logic absorption into SLR0/SLR2.**

The bolder option: drop SLR1 from the pblock entirely (except for SLL
crossings), force-relocate the 960 SLR1 SLICEs into SLR0 (which already
hosts 22 k SLICEs) or SLR2 (currently 2 k). SLR0 has plenty of
headroom (it's at 20 % SLICE utilization out of its share). This frees
**all of SLR1** for vFPGAs.

Risk: SLR0 becomes more congested. The placer may struggle to fit the
extra 960 SLICEs alongside the existing 22 663 in SLR0 without timing
degradation. Worth trying after Strategy A is empirically validated.

#### Status

| Step | Status |
|---|---|
| 1. Audit shipped static + routed shell DCPs | ✅ done |
| 2. Apply Strategy A to `v80_static_floorplan.xdc` | ✅ done (this repo) |
| 3. Add `v80_vfpga_slr_floorplan_phase2.xdc` for the post-Phase-2 layout | ✅ done (this repo) |
| 4. Rebuild static (`BUILD_STATIC=1, BUILD_SHELL=0`) to regenerate the routed-locked DCP | ⏳ user action — multi-hour build |
| 5. Validate against `examples/{01,03,07,10}` to confirm no regressions | ⏳ user action |
| 6. Replace shipped `static_routed_locked_v80_gen5.dcp` | ⏳ user action after step 5 |

#### What changed in this repo

**`hw/constraints/v80/fplan/v80_static_floorplan.xdc`** — the SLR1
portion of the pblock's CR rectangle was narrowed:

```diff
- CLOCKREGION_X1Y5:CLOCKREGION_X9Y6   (SLR1 middle, ~14 CRs)
- CLOCKREGION_X1Y7:CLOCKREGION_X8Y10  (SLR1 upper + SLR2)
+ CLOCKREGION_X5Y5:CLOCKREGION_X6Y6   (SLR1 corridor, ~4 CRs)
+ CLOCKREGION_X5Y7:CLOCKREGION_X8Y7   (SLR1 top transition row)
+ CLOCKREGION_X1Y8:CLOCKREGION_X8Y10  (SLR2 unchanged)
  (SLR0 lines unchanged: Y0..Y4)
```

NoC tile assignments (`NOC_NMU512_X1Y4:Y6`, `NOC_NSU512_X1Y4:Y6`,
`NOC_NPS_VNOC_X1Y8:Y13`, `NOC_NMU_HBM2E_X0..5/X61..63`) were already
explicitly listed in the original XDC — they carry forward verbatim and
keep the shell connected to PCIe / HBM / DDR irrespective of the smaller
CR rectangle.

**`hw/constraints/v80/vfpga_fplan/v80_vfpga_slr_floorplan_phase2.xdc`**
— new file. Counterpart of `v80_vfpga_slr_floorplan.xdc` that uses the
freed SLR1 area. SLR1 vFPGAs grow from ~4-CR thin strips to a 12-CR
left block (X1..X4, Y5..Y7) plus a 6-CR right block (X7..X9, Y5..Y6).

#### Expected outcome once rebuilt

The audit predicts:

* SLR1 shell SLICE usage stays at ~960 SLICEs, but compacts into the
  X5..X6 corridor (~12% density there, comfortable).
* SLL utilization remains under ~10% in each direction (was 6.7%).
* Static timing should close at SCLK_F=333 MHz; minor pipeline-register
  additions may be needed if cross-SLR shell paths suffer.
* Phase 2 vFPGA floorplan unlocks **4 substantial vFPGA slots** (≥10 CRs)
  vs. Phase 1's 2 — a +58% vFPGA fabric area win for the V80.

#### How to commit (or revert)

The XDC change is the only persistent artifact; nothing has been
rebuilt. To undo, revert the `v80_static_floorplan.xdc` diff. To commit
the win, rebuild the static, validate the examples, replace the shipped
DCP. The two vFPGA floorplan files coexist — users choose by which
`FPLAN_PATH` they pass to CMake.

The audit is the load-bearing claim. The numbers above turn Phase 2
from "speculative" to "supported with hard data": SLR1 is over-reserved
by roughly 30×, the shell has the structural properties needed to
compact (no URAM/DSP, no SLR1 BRAM, modest SLL count), and a tighter
pblock should yield a substantial vFPGA-area win.

### Phase 3 — research evaluation

Once Phase 1 + 2 are in place, the research contribution is:

* **Headline claim**: Coyote V80 supports 6–12 vFPGAs cleanly with timing
  closure, vs. U280's ~4-vFPGA practical ceiling. Demonstrate by
  building the same multi-tenant example on both boards with matching
  per-vFPGA logic complexity.
* **Per-vFPGA performance comparison**: thanks to the hardened NoC
  absorbing cross-SLR traffic, per-vFPGA bandwidth/latency to HBM
  should *not* degrade as you add more vFPGAs (unlike U280 where
  SLL contention does degrade it). This is the falsifiable claim
  worth measuring.

---

## 7. NoC-mediated inter-vFPGA streaming — pipelining across vFPGAs

### Motivation

Coyote's current vFPGA boundary exposes:

* `axi_ctrl_*` (host control)
* `axis_host_sink/src` (host DMA)
* `axis_card_<i>_sink/src` (card memory)
* descriptor queues (`host_sq`, `bpss_*`)
* `notify_*` (interrupt back to host)

There is **no `axis_vfpga_<j>` port**. Today, vFPGA-to-vFPGA data
movement must go through card memory (HBM/DDR ping-pong) or worse,
through the host. The memory route costs:

* ≥1 full DRAM round-trip per data unit (~hundreds of ns)
* memory bandwidth in both directions
* explicit application-managed synchronisation (no AXI-S flow control)

This rules out fine-grained pipelining across vFPGAs — exactly the
pattern you'd want for `(preprocess → model → postprocess)` chains,
partial-reconfiguration of one pipeline stage, or
producer/filter/consumer compositions.

### Why the Versal NoC is well-suited to fix this

The Versal NoC isn't just a memory interconnect. The NMU_512 and NSU_512
tiles support both AXI4-MM and AXI4-Stream (128–512 bit). It is
*physically a mesh* (~1 GHz hard switches) with:

* `Isochronous` and `Low Latency` traffic classes beyond `Best Effort`
* Dedicated AXIS channels separate from memory traffic
* No fabric routing cost — it's a hard switch fabric
* AMD-quoted 2.2 Tb/s total on-chip bandwidth; Coyote uses well under
  10% of that today

So architecturally: instead of building a soft N×N AXIS crossbar in
PL (O(N²) area, hostile to timing), instantiate one NMU per vFPGA and
let the hard NoC route between them.

### Proposed design

```
Today:                          Proposed:

┌─ vFPGA 0 ─┐  ┌─ vFPGA 1 ─┐    ┌─ vFPGA 0 ─┐  ┌─ vFPGA 1 ─┐  ┌─ vFPGA 2 ─┐
│ axis_host │  │ axis_host │    │ axis_host │  │ axis_host │  │ axis_host │
│ axis_card │  │ axis_card │    │ axis_card │  │ axis_card │  │ axis_card │
│           │  │           │    │ axis_p2p ◀┼──┼▶ axis_p2p ◀┼──┼▶ axis_p2p│ ← new
└───────────┘  └───────────┘    └─────┬─────┘  └─────┬─────┘  └─────┬─────┘
                                      │              │              │
   no path between them               └────── NoC mesh (hard) ──────┘
                                       TDEST-routed stream switch
```

**Concrete pieces:**

1. New vFPGA ports in `hw/templates/common/user_wrapper_tmplt.txt`:
   `axis_p2p_send_*` (master) + `axis_p2p_recv_*` (slave), TDEST-bearing.
2. One NMU_512 (stream mode) per vFPGA, instantiated in the shell
   template (`shell_top_tmplt.txt`).
3. NoC connectivity matrix in `cr_pci.tcl` (or new `cr_p2p.tcl`):
   every NMU has every NSU as destination, TDEST decoding the routing.
4. Software API: `cyt::vfpga.connect_to(peer_id)` returning an AXIS
   handle the user RTL writes to.

### Open questions before commitment

Before scoping this seriously, the following need verification against
**PG313 (Versal ACAP Programmable Network on Chip)**:

1. **Is NoC AXIS routing general enough?** TDEST is configurable but the
   route table is fixed at synthesis. Worst case may require a small
   soft AXIS switch in addition to the NoC.
2. **NMU_512 count.** XCV80 has a finite supply of NMU_512 instances.
   If it's e.g. 16 total and the existing CIPS uses 4, the upper bound
   on inter-vFPGA NoC links is ~12.
3. **Backpressure latency across NoC hops.** AXIS ready/valid works
   over NoC but the internal buffering depth needs measurement —
   probably want skid buffers in the wrapper.
4. **NoC AXIS vs HBM contention.** Even with 2.2 Tb/s aggregate, NMU
   instances on the HBM side and PL side may share physical switches.
   Needs stress-testing under combined load.
5. **Isolation between p2p tenants.** Coyote's MMU/TLB doesn't cover
   p2p traffic. A TDEST-whitelist per vFPGA is the obvious story but
   needs design.

### Phasing relative to §6

| Phase | Work | Status |
|---|---|---|
| 1 | SLR-aware vFPGA floorplan (§6) | ✅ done |
| 2 | Tighter static-shell pblock to free SLR1 (§6) | proposed |
| 3 | PG313 review + 2-vFPGA NoC AXIS prototype (§7) | proposed |
| 4 | Generalise to N×N + API + isolation (§7) | proposed |
| 5 | Measurement + paper (both) | proposed |

### Research framing

The combination ("more vFPGAs per V80" + "vFPGAs pipeline through
the NoC") is a genuinely novel contribution:

* **Existing multi-vFPGA shells** (Coyote, Galapagos, AmorphOS) use
  shared memory or soft NoCs — both with known scaling problems.
* **Academic NoC-on-FPGA work** (DiNoC, ANCEL) synthesises soft NoCs,
  paying area and timing.
* **AMD's own use of the Versal NoC** is for memory and AIE traffic,
  not for inter-PL-tenant streaming.

The paper claim writes itself: *"Hardened-NoC-mediated inter-vFPGA
streaming on Versal HBM."* Falsifiable:

1. Inter-vFPGA latency drops from hundreds of ns (memory round-trip)
   to tens of ns (NoC hop).
2. Inter-vFPGA bandwidth is provisioned independently from memory
   bandwidth — measurable lack of contention.
3. Pipelined multi-vFPGA workloads (DSP chains, ML inference splits,
   packet processing pipelines) become viable at high vFPGA counts.
4. Partial reconfiguration of a single pipeline stage in isolation.

