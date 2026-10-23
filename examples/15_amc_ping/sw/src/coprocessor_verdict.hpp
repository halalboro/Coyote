/*
 * Coyote Example 15 — host/firmware/RTL shared verdict + control-target layout.
 * Mirror of hw/src/hdl/coprocessor_abi.svh and fw/r5_provider_v80/src/coprocessor_abi.h.
 */
#pragma once
#include <cstdint>

namespace ex15 {

// vFPGA MMIO / axi_ctrl verdict registers (64-bit word index into the user region)
constexpr std::uint32_t VMAGIC_WORD = 0;   // 0x00  low32 = MAGIC
constexpr std::uint32_t VERD0_WORD  = 1;   // 0x08  {passed[31:0], total[63:32]}
constexpr std::uint32_t VERD1_WORD  = 2;   // 0x10  {first_fail[31:0], done[63:32]}
constexpr std::uint32_t VERD2_WORD  = 3;   // 0x18  {lat_min[31:0], lat_max[63:32]}
constexpr std::uint32_t VERD3_WORD  = 4;   // 0x20  {lat_avg[31:0], r5_mhz[63:32]}
constexpr std::uint32_t MMIO_MAGIC  = 0x52355650u; // "R5VP"

// Co-processor control target: BAR4 + 0x2000 (axi_main + axil_address_splitter SERVICE_BASE).
// main.cpp maps this from the raw BAR4 resource; the offsets below are within its aperture.
constexpr std::uint32_t COPROC_CTRL_BASE = 0x2000u; // = SERVICE_BASE = BAR4 offset of the control target
constexpr std::uint32_t CT_MAGIC   = 0x000; // RO {version<<32 | 0x54435043}
constexpr std::uint32_t CT_PROV    = 0x008; // RO provider status {..fault,idle,healthy,avail}
constexpr std::uint32_t CT_PROVGEN = 0x010; // RO provider_generation
constexpr std::uint32_t CT_BINDGEN = 0x020; // RO binding_generation
constexpr std::uint32_t CT_CMD     = 0x028; // WO {endpoint[31:16] | opcode[2:0]}
constexpr std::uint32_t CT_BGEN    = 0x030; // WO command_binding_generation
constexpr std::uint32_t CT_EGEN    = 0x038; // WO command_endpoint_generation
constexpr std::uint32_t CT_SUBMIT  = 0x040; // RW read token, write token to submit
constexpr std::uint32_t CT_STATUS  = 0x048; // RO status/completion
constexpr std::uint32_t CT_ACK     = 0x050; // WO write completion_token to ack

constexpr std::uint32_t CT_MAGIC_VALUE = 0x54435043u; // control target MAGIC

// opcodes / states (from coprocessor_port_gateway.sv)
constexpr std::uint32_t OP_BIND = 1u;
constexpr std::uint16_t ENDPOINT_ID = 1u;

// CT_STATUS bit layout
inline std::uint32_t st_result(std::uint64_t s)   { return  s        & 0xFu; }
inline bool st_inflight(std::uint64_t s)          { return (s >> 4)  & 1u;   }
inline bool st_done(std::uint64_t s)              { return (s >> 5)  & 1u;   }
inline std::uint32_t st_completion(std::uint64_t s){ return (std::uint32_t)(s >> 32); }

// CT_PROV bit layout
inline bool prov_available(std::uint64_t p) { return  p       & 1u; }
inline bool prov_healthy(std::uint64_t p)   { return (p >> 1) & 1u; }

} // namespace ex15
