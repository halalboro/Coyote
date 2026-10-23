/*
 * Coyote Example 15 — R5 co-processor ABI (firmware view).
 * Mirror of examples/15_amc_ping/hw/src/hdl/coprocessor_abi.svh and
 * examples/15_amc_ping/sw/src/coprocessor_verdict.hpp — keep in lock-step.
 *
 * One 512-bit beat (64 bytes) per request/response, little-endian:
 *   REQUEST  [0]=opcode [4]=operand_a [8]=operand_b [12]=seq
 *   RESPONSE [0]=status [4]=result    [8]=opcode(echo) [12]=seq(echo)
 *
 * vFPGA MMIO aperture (byte offsets; R5 writes via app_write64):
 *   0x00 MAGIC(RO)  0x08 {passed|total<<32}  0x10 {first_fail|done<<32}
 *   0x18 {lat_min|lat_max<<32}  0x20 {lat_avg|r5_mhz<<32}
 */
#ifndef COYOTE_EX15_COPROCESSOR_ABI_H
#define COYOTE_EX15_COPROCESSOR_ABI_H

#include <stdint.h>

#define COP_OP_PING 0u
#define COP_OP_INC  1u
#define COP_OP_ADD  2u
#define COP_OP_SUM  3u

#define COP_ST_OK          0u
#define COP_ST_BAD_OPCODE  1u

/* request/response field byte offsets within the 64-byte beat */
#define COP_REQ_OPCODE   0u
#define COP_REQ_OPA      4u
#define COP_REQ_OPB      8u
#define COP_REQ_SEQ      12u
#define COP_RSP_STATUS   0u
#define COP_RSP_RESULT   4u
#define COP_RSP_OPCODE   8u
#define COP_RSP_SEQ      12u

#define COP_BEAT_BYTES   64u

/* vFPGA MMIO application offsets (must match the RTL register file) */
#define COP_MMIO_OFF_MAGIC 0x00u
#define COP_MMIO_OFF_VERD0 0x08u
#define COP_MMIO_OFF_VERD1 0x10u
#define COP_MMIO_OFF_VERD2 0x18u
#define COP_MMIO_OFF_VERD3 0x20u
#define COP_MMIO_MAGIC_VALUE 0x52355650u  /* "R5VP" */

#endif
