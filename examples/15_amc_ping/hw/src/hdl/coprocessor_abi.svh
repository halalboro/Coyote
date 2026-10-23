/**
 * Coyote Example 15 — R5 co-processor ABI (shared HW/FW/host contract).
 *
 * Mirrors fw/r5_provider_v80/src/coprocessor_abi.h and
 * examples/15_amc_ping/sw/src/coprocessor_verdict.hpp — keep the three in lock-step.
 *
 * Datapath: one 512-bit AXIS beat per request/response, tlast=1. Fields sit in
 * the low 32-bit lanes, little-endian, the rest zero.
 *
 *   REQUEST  lane0=opcode  lane1=operand_a  lane2=operand_b  lane3=seq
 *   RESPONSE lane0=status  lane1=result     lane2=opcode(echo) lane3=seq(echo)
 *
 * MMIO (64-bit words in the co-processor aperture; R5 writes, host mirrors via
 * axi_ctrl):
 *   0x00 MAGIC (RO)   0x08 passed|total   0x10 first_fail|done
 *   0x18 lat_min|lat_max   0x20 lat_avg|r5_mhz   0x28 scratch (R5 rw / host r)
 */

`ifndef COPROCESSOR_ABI_SVH
`define COPROCESSOR_ABI_SVH

// Opcodes (request lane0)
localparam logic [31:0] COP_OP_PING = 32'd0;  // result = operand_a (echo); resets SUM accumulator
localparam logic [31:0] COP_OP_INC  = 32'd1;  // result = operand_a + 1
localparam logic [31:0] COP_OP_ADD  = 32'd2;  // result = operand_a + operand_b
localparam logic [31:0] COP_OP_SUM  = 32'd3;  // accumulator += operand_a; result = accumulator

// Response status (response lane0)
localparam logic [31:0] COP_ST_OK          = 32'd0;
localparam logic [31:0] COP_ST_BAD_OPCODE  = 32'd1;

// MMIO aperture: register index = byte_offset / 8
localparam int unsigned COP_MMIO_MAGIC   = 0;  // 0x00
localparam int unsigned COP_MMIO_VERD0   = 1;  // 0x08  {passed[31:0], total[63:32]}
localparam int unsigned COP_MMIO_VERD1   = 2;  // 0x10  {first_fail[31:0], done[63:32]}
localparam int unsigned COP_MMIO_VERD2   = 3;  // 0x18  {lat_min[31:0], lat_max[63:32]}
localparam int unsigned COP_MMIO_VERD3   = 4;  // 0x20  {lat_avg[31:0], r5_mhz[63:32]}
localparam int unsigned COP_MMIO_SCRATCH = 5;  // 0x28
localparam int unsigned COP_MMIO_N_REGS  = 8;

// MAGIC = "R5VP"
localparam logic [31:0] COP_MMIO_MAGIC_VALUE = 32'h5235_5650;

`endif
