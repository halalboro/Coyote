/**
 * This file is part of the Coyote <https://github.com/fpgasystems/Coyote>
 *
 * MIT Licence
 * Copyright (c) 2026, Systems Group, ETH Zurich
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

`timescale 1ns / 1ps

/**
 * DCMAC debug port: register access to the DCMAC itself plus a segment-level
 * monitor of both sides of the MAC client interface.
 *
 * One request/response register port (nclk, see reg_port_ccross for the
 * contract) serves two windows, split on address bit 20:
 *
 *   0x000000 - 0x0FFFFF  forwarded as AXI4-Lite to the DCMAC's own register
 *                        space (PG369): configuration, PHY/MAC status and the
 *                        hard block's statistics counters.
 *   0x100000 - 0x1FFFFF  local monitor registers, below.
 *
 * The monitor watches the segmented interface at the DCMAC pins, in the DCMAC
 * AXIS clock (dclk), i.e. downstream of every Coyote/AMD converter on TX and
 * upstream of all of them on RX. Comparing it against the hard block's own
 * counters and against the vFPGA's counters locates a loss to one stage:
 *
 *   vFPGA TX -> [BD TX frames] -> converters -> [TX seg sop/eop] -> DCMAC TX
 *   -> PHY/loopback -> DCMAC RX -> [RX seg sop/eop/err] -> converters
 *   -> [BD RX frames] -> vFPGA RX
 *
 * Local window (byte offsets from 0x100000; all 32-bit, read-only unless noted):
 *   0x000 ID            0xDC4D0001
 *   0x004 CTRL      RW  bit0 clear monitor (level), bit1 TX stats tick,
 *                       bit2 RX stats tick (both level; the DCMAC latches on the
 *                       rising edge and also zeroes its internal counters;
 *                       PG369 "Per-Port Statistics Monitoring")
 *   0x008 DCLK_CYC      free-running dclk cycle count (liveness of the snapshot)
 *   0x00C NCLK_CYC      free-running nclk cycle count
 *   0x010 RX_VLD        dclk cycles with rx_axis_tvalid and any segment enabled
 *   0x014 RX_SOP        start-of-packet segments
 *   0x018 RX_EOP        end-of-packet segments
 *   0x01C RX_EOP_ERR    end-of-packet segments with tuser_err (bad FCS, etc.)
 *   0x020 RX_MSOP       cycles carrying two or more SOPs
 *   0x024 RX_PROTO      cycles with a framing violation (SOP inside a packet,
 *                       or data/EOP outside one)
 *   0x028 RX_SEGS       enabled segments (x16 = bytes, give or take mty)
 *   0x030 TX_VLD        dclk cycles with tx_axis_tvalid
 *   0x034 TX_ACC        cycles with tvalid && tready
 *   0x038 TX_SOP        accepted SOP segments
 *   0x03C TX_EOP        accepted EOP segments
 *   0x040 TX_STALL      cycles with tvalid && !tready
 *   0x044 TX_PROTO      accepted cycles with a framing violation
 *   0x048 TX_SEGS       accepted enabled segments
 *   0x04C RX_CAP_N      entries in the RX capture (saturates at 16)
 *   0x050 BD_TX_FRAMES  nclk, frames into the block design (after the padder)
 *   0x054 BD_TX_BEATS
 *   0x058 BD_RX_FRAMES  nclk, frames out of the block design
 *   0x05C BD_RX_BEATS
 *   0x060 BD_RX_STALL   cycles the block design offered RX data that was not taken
 *   0x064 BD_TX_STALL   cycles TX data was offered and the block design refused it
 *   0x068 TX_CAP_N      entries in the TX capture (saturates at 16)
 *   0x06C BD_RX_ERR     frames out of the block design whose last beat carries
 *                       tuser (the RX converter's error flag, i.e. the MAC's
 *                       tuser_err; Coyote's 512-bit stream has no tuser, so
 *                       these frames reach the vFPGA looking good)
 *   0x100-0x13C RX_CAP[0..15]  first 16 RX cycles with any segment enabled
 *   0x140-0x17C TX_CAP[0..15]  first 16 accepted TX cycles
 *
 * A capture entry packs one byte per segment, segment i in bits [8i+7:8i]:
 *   {ena, sop, eop, err, mty[3:0]}
 * Clearing the monitor re-arms both captures.
 *
 * Counters live in dclk and reach nclk as one coherent snapshot through a
 * free-running xpm_cdc_handshake loop, refreshed every few tens of cycles.
 */
module dcmac_debug (
    input  logic            nclk,
    input  logic            nresetn,

    // Register port, nclk
    input  logic            reg_req,
    input  logic            reg_wr,
    input  logic [31:0]     reg_addr,
    input  logic [31:0]     reg_wdata,
    output logic            reg_rsp,
    output logic [31:0]     reg_rdata,
    output logic [1:0]      reg_resp,

    // AXI4-Lite master to the DCMAC register space, nclk
    output logic [31:0]     m_axil_awaddr,
    output logic            m_axil_awvalid,
    input  logic            m_axil_awready,
    output logic [31:0]     m_axil_wdata,
    output logic [3:0]      m_axil_wstrb,
    output logic            m_axil_wvalid,
    input  logic            m_axil_wready,
    input  logic [1:0]      m_axil_bresp,
    input  logic            m_axil_bvalid,
    output logic            m_axil_bready,
    output logic [31:0]     m_axil_araddr,
    output logic            m_axil_arvalid,
    input  logic            m_axil_arready,
    input  logic [31:0]     m_axil_rdata,
    input  logic [1:0]      m_axil_rresp,
    input  logic            m_axil_rvalid,
    output logic            m_axil_rready,

    // Statistics tick pins of the DCMAC. The hard block times these against
    // APB3_CLK, which is the block design's 100 MHz sys_clk (the same clock
    // its register port runs on), so they are driven from flops on apb_clk.
    input  logic            apb_clk,
    output logic [5:0]      tx_port_pm_tick,
    output logic [5:0]      rx_port_pm_tick,
    output logic            tx_all_channel_mac_pm_tick,
    output logic            rx_all_channel_mac_pm_tick,

    // Block design boundary streams, nclk (observed only)
    input  logic            bd_tx_tvalid,
    input  logic            bd_tx_tready,
    input  logic            bd_tx_tlast,
    input  logic            bd_rx_tvalid,
    input  logic            bd_rx_tready,
    input  logic            bd_rx_tlast,
    input  logic            bd_rx_tuser_any,

    // Segmented interface taps at the DCMAC pins, dclk
    input  logic            dclk,
    input  logic            rx_tvalid,
    input  logic [3:0]      rx_ena,
    input  logic [3:0]      rx_sop,
    input  logic [3:0]      rx_eop,
    input  logic [3:0]      rx_err,
    input  logic [15:0]     rx_mty,
    input  logic            tx_tvalid,
    input  logic            tx_tready,
    input  logic [3:0]      tx_ena,
    input  logic [3:0]      tx_sop,
    input  logic [3:0]      tx_eop,
    input  logic [3:0]      tx_err,
    input  logic [15:0]     tx_mty
);

localparam logic [31:0] MON_ID   = 32'hDC4D_0001;
localparam integer      N_CAP    = 16;
localparam integer      N_DCNT   = 17;     // dclk counters in the snapshot
localparam integer      TIMEOUT  = 1 << 20; // ~2.6 ms at 400 MHz

// ===========================================================================
// Control register (nclk) and its crossings into dclk
// ===========================================================================
logic [2:0] mon_ctrl;

logic       clr_d;
logic       tx_tick_a;
logic       rx_tick_a;

// All three bits are independent levels held by software for milliseconds, so
// per-bit synchronisation is exact enough.
xpm_cdc_single #(
    .DEST_SYNC_FF   (4),
    .INIT_SYNC_FF   (0),
    .SIM_ASSERT_CHK (0),
    .SRC_INPUT_REG  (1)
) inst_cdc_clr (
    .src_clk  (nclk),
    .src_in   (mon_ctrl[0]),
    .dest_clk (dclk),
    .dest_out (clr_d)
);

xpm_cdc_array_single #(
    .DEST_SYNC_FF   (4),
    .INIT_SYNC_FF   (0),
    .SIM_ASSERT_CHK (0),
    .SRC_INPUT_REG  (1),
    .WIDTH          (2)
) inst_cdc_tick (
    .src_clk  (nclk),
    .src_in   (mon_ctrl[2:1]),
    .dest_clk (apb_clk),
    .dest_out ({rx_tick_a, tx_tick_a})
);

// The DCMAC latches on the rising edge, so drive the pins from flops to give
// it clean edges.
always_ff @(posedge apb_clk) begin
    tx_port_pm_tick            <= {6{tx_tick_a}};
    rx_port_pm_tick            <= {6{rx_tick_a}};
    tx_all_channel_mac_pm_tick <= tx_tick_a;
    rx_all_channel_mac_pm_tick <= rx_tick_a;
end

// ===========================================================================
// Segment monitor (dclk)
// ===========================================================================
// One register stage on every tap: they come straight off the hard block and
// the converters, and are high-fanout nets in their own right.
logic        rx_v_q,  tx_v_q, tx_r_q;
logic [3:0]  rx_ena_q, rx_sop_q, rx_eop_q, rx_err_q;
logic [3:0]  tx_ena_q, tx_sop_q, tx_eop_q, tx_err_q;
logic [15:0] rx_mty_q, tx_mty_q;

always_ff @(posedge dclk) begin
    rx_v_q   <= rx_tvalid;
    rx_ena_q <= rx_ena;
    rx_sop_q <= rx_sop;
    rx_eop_q <= rx_eop;
    rx_err_q <= rx_err;
    rx_mty_q <= rx_mty;
    tx_v_q   <= tx_tvalid;
    tx_r_q   <= tx_tready;
    tx_ena_q <= tx_ena;
    tx_sop_q <= tx_sop;
    tx_eop_q <= tx_eop;
    tx_err_q <= tx_err;
    tx_mty_q <= tx_mty;
end

function automatic logic [2:0] pop4(input logic [3:0] v);
    return {2'b0, v[0]} + {2'b0, v[1]} + {2'b0, v[2]} + {2'b0, v[3]};
endfunction

function automatic logic [31:0] cap_entry(input logic [3:0] ena, input logic [3:0] sop,
                                          input logic [3:0] eop, input logic [3:0] err,
                                          input logic [15:0] mty);
    logic [31:0] e;
    for (int i = 0; i < 4; i++) begin
        e[8*i +: 8] = {ena[i], sop[i], eop[i], err[i], mty[4*i +: 4]};
    end
    return e;
endfunction

// Walk the four segments in wire order and report whether any of them breaks
// framing, given whether a packet was open at the start of the cycle. Returns
// {violation, packet_open_at_end}.
function automatic logic [1:0] walk(input logic in_pkt, input logic [3:0] ena,
                                    input logic [3:0] sop, input logic [3:0] eop);
    logic open, bad;
    open = in_pkt;
    bad  = 1'b0;
    for (int i = 0; i < 4; i++) begin
        if (ena[i]) begin
            if (sop[i]) begin
                if (open) bad = 1'b1;
                open = 1'b1;
            end else if (!open) begin
                bad = 1'b1;
            end
            if (eop[i]) open = 1'b0;
        end
    end
    return {bad, open};
endfunction

// Stage 1: per-cycle increments.
wire [3:0] rx_e = rx_v_q ? rx_ena_q : 4'b0;
wire [3:0] tx_e = (tx_v_q && tx_r_q) ? tx_ena_q : 4'b0;

logic       rx_in_pkt, tx_in_pkt;
wire  [1:0] rx_walk = walk(rx_in_pkt, rx_e, rx_sop_q, rx_eop_q);
wire  [1:0] tx_walk = walk(tx_in_pkt, tx_e, tx_sop_q, tx_eop_q);

logic       i_rx_vld, i_rx_msop, i_rx_proto;
logic [2:0] i_rx_sop, i_rx_eop, i_rx_err, i_rx_segs;
logic       i_tx_vld, i_tx_acc, i_tx_stall, i_tx_proto;
logic [2:0] i_tx_sop, i_tx_eop, i_tx_segs;

always_ff @(posedge dclk) begin
    if (clr_d) begin
        rx_in_pkt <= 1'b0;
        tx_in_pkt <= 1'b0;
        {i_rx_vld, i_rx_msop, i_rx_proto} <= '0;
        {i_rx_sop, i_rx_eop, i_rx_err, i_rx_segs} <= '0;
        {i_tx_vld, i_tx_acc, i_tx_stall, i_tx_proto} <= '0;
        {i_tx_sop, i_tx_eop, i_tx_segs} <= '0;
    end else begin
        rx_in_pkt  <= rx_walk[0];
        tx_in_pkt  <= tx_walk[0];

        i_rx_vld   <= |rx_e;
        i_rx_sop   <= pop4(rx_e & rx_sop_q);
        i_rx_eop   <= pop4(rx_e & rx_eop_q);
        i_rx_err   <= pop4(rx_e & rx_eop_q & rx_err_q);
        i_rx_msop  <= pop4(rx_e & rx_sop_q) >= 3'd2;
        i_rx_proto <= rx_walk[1];
        i_rx_segs  <= pop4(rx_e);

        i_tx_vld   <= tx_v_q;
        i_tx_acc   <= tx_v_q && tx_r_q;
        i_tx_stall <= tx_v_q && !tx_r_q;
        i_tx_sop   <= pop4(tx_e & tx_sop_q);
        i_tx_eop   <= pop4(tx_e & tx_eop_q);
        i_tx_proto <= tx_walk[1];
        i_tx_segs  <= pop4(tx_e);
    end
end

// Stage 2: accumulate.
// Free-running, so given power-up values rather than a reset.
logic [31:0] c_dcyc = '0;
logic [31:0] c_rx_vld, c_rx_sop, c_rx_eop, c_rx_err, c_rx_msop, c_rx_proto, c_rx_segs;
logic [31:0] c_tx_vld, c_tx_acc, c_tx_sop, c_tx_eop, c_tx_stall, c_tx_proto, c_tx_segs;

always_ff @(posedge dclk) begin
    c_dcyc <= c_dcyc + 1;
    if (clr_d) begin
        {c_rx_vld, c_rx_sop, c_rx_eop, c_rx_err, c_rx_msop, c_rx_proto, c_rx_segs} <= '0;
        {c_tx_vld, c_tx_acc, c_tx_sop, c_tx_eop, c_tx_stall, c_tx_proto, c_tx_segs} <= '0;
    end else begin
        c_rx_vld   <= c_rx_vld   + i_rx_vld;
        c_rx_sop   <= c_rx_sop   + i_rx_sop;
        c_rx_eop   <= c_rx_eop   + i_rx_eop;
        c_rx_err   <= c_rx_err   + i_rx_err;
        c_rx_msop  <= c_rx_msop  + i_rx_msop;
        c_rx_proto <= c_rx_proto + i_rx_proto;
        c_rx_segs  <= c_rx_segs  + i_rx_segs;
        c_tx_vld   <= c_tx_vld   + i_tx_vld;
        c_tx_acc   <= c_tx_acc   + i_tx_acc;
        c_tx_sop   <= c_tx_sop   + i_tx_sop;
        c_tx_eop   <= c_tx_eop   + i_tx_eop;
        c_tx_stall <= c_tx_stall + i_tx_stall;
        c_tx_proto <= c_tx_proto + i_tx_proto;
        c_tx_segs  <= c_tx_segs  + i_tx_segs;
    end
end

// Capture of the first N_CAP cycles each way, straight from the stage-0 taps.
logic [N_CAP-1:0][31:0] rx_cap, tx_cap;
logic [4:0]             rx_cap_n, tx_cap_n;

always_ff @(posedge dclk) begin
    if (clr_d) begin
        rx_cap_n <= '0;
        tx_cap_n <= '0;
        rx_cap   <= '0;
        tx_cap   <= '0;
    end else begin
        if (|rx_e && rx_cap_n < N_CAP) begin
            rx_cap[rx_cap_n[3:0]] <= cap_entry(rx_e, rx_sop_q, rx_eop_q, rx_err_q, rx_mty_q);
            rx_cap_n <= rx_cap_n + 1;
        end
        if (tx_v_q && tx_r_q && tx_cap_n < N_CAP) begin
            tx_cap[tx_cap_n[3:0]] <= cap_entry(tx_e, tx_sop_q, tx_eop_q, tx_err_q, tx_mty_q);
            tx_cap_n <= tx_cap_n + 1;
        end
    end
end

// ===========================================================================
// Snapshot dclk -> nclk
// ===========================================================================
localparam integer SNAP_BITS = N_DCNT * 32 + 2 * N_CAP * 32;

wire [SNAP_BITS-1:0] snap_d = {
    tx_cap, rx_cap,
    {27'b0, tx_cap_n}, {27'b0, rx_cap_n},
    c_tx_segs, c_tx_proto, c_tx_stall, c_tx_eop, c_tx_sop, c_tx_acc, c_tx_vld,
    c_rx_segs, c_rx_proto, c_rx_msop, c_rx_err, c_rx_eop, c_rx_sop, c_rx_vld,
    c_dcyc
};

// xpm_cdc_handshake is limited to 1024 bits, so the snapshot is split in two
// transfers that run in lockstep off the same send/receive loop.
localparam integer SNAP_LO = 1024;
localparam integer SNAP_HI = SNAP_BITS - SNAP_LO;

logic [SNAP_BITS-1:0] snap_src;
logic [SNAP_BITS-1:0] snap_dst;
logic                 snap_send  = 1'b0;
logic [1:0]           snap_rcv;
logic [1:0]           snap_vld;
logic [1:0]           snap_state = 2'd0;

always_ff @(posedge dclk) begin
    case (snap_state)
        2'd0: begin
            snap_src   <= snap_d;
            snap_send  <= 1'b1;
            snap_state <= 2'd1;
        end
        2'd1: if (&snap_rcv) begin
            snap_send  <= 1'b0;
            snap_state <= 2'd2;
        end
        2'd2: if (~|snap_rcv) begin
            snap_state <= 2'd0;
        end
        default: begin
            snap_send  <= 1'b0;
            snap_state <= 2'd2;
        end
    endcase
end

xpm_cdc_handshake #(
    .DEST_EXT_HSK (0), .DEST_SYNC_FF (4), .INIT_SYNC_FF (0),
    .SIM_ASSERT_CHK (0), .SRC_SYNC_FF (4), .WIDTH (SNAP_LO)
) inst_snap_lo (
    .src_clk (dclk), .src_in (snap_src[SNAP_LO-1:0]), .src_send (snap_send), .src_rcv (snap_rcv[0]),
    .dest_clk (nclk), .dest_req (snap_vld[0]), .dest_ack (1'b0), .dest_out (snap_dst[SNAP_LO-1:0])
);

xpm_cdc_handshake #(
    .DEST_EXT_HSK (0), .DEST_SYNC_FF (4), .INIT_SYNC_FF (0),
    .SIM_ASSERT_CHK (0), .SRC_SYNC_FF (4), .WIDTH (SNAP_HI)
) inst_snap_hi (
    .src_clk (dclk), .src_in (snap_src[SNAP_BITS-1:SNAP_LO]), .src_send (snap_send), .src_rcv (snap_rcv[1]),
    .dest_clk (nclk), .dest_req (snap_vld[1]), .dest_ack (1'b0), .dest_out (snap_dst[SNAP_BITS-1:SNAP_LO])
);

// dest_out holds between transfers, so it can be read directly. The two
// halves may be one refresh apart from each other for a few cycles; for a
// debug readout taken after traffic has stopped that is immaterial.
wire [N_DCNT-1:0][31:0]       s_cnt = snap_dst[N_DCNT*32-1:0];
wire [N_CAP-1:0][31:0]        s_rx_cap = snap_dst[N_DCNT*32 +: N_CAP*32];
wire [N_CAP-1:0][31:0]        s_tx_cap = snap_dst[N_DCNT*32 + N_CAP*32 +: N_CAP*32];

// ===========================================================================
// Block design boundary counters (nclk)
// ===========================================================================
logic        bd_tx_v_q, bd_tx_r_q, bd_tx_l_q, bd_rx_v_q, bd_rx_r_q, bd_rx_l_q, bd_rx_u_q;
logic        clr_n;
logic [31:0] c_ncyc = '0;
logic [31:0] c_bd_tx_frames, c_bd_tx_beats, c_bd_rx_frames, c_bd_rx_beats;
logic [31:0] c_bd_rx_stall, c_bd_tx_stall, c_bd_rx_err;

assign clr_n = mon_ctrl[0];

always_ff @(posedge nclk) begin
    bd_tx_v_q <= bd_tx_tvalid;
    bd_tx_r_q <= bd_tx_tready;
    bd_tx_l_q <= bd_tx_tlast;
    bd_rx_v_q <= bd_rx_tvalid;
    bd_rx_r_q <= bd_rx_tready;
    bd_rx_l_q <= bd_rx_tlast;
    bd_rx_u_q <= bd_rx_tuser_any;

    c_ncyc <= c_ncyc + 1;
    if (clr_n) begin
        {c_bd_tx_frames, c_bd_tx_beats, c_bd_rx_frames, c_bd_rx_beats} <= '0;
        {c_bd_rx_stall, c_bd_tx_stall, c_bd_rx_err} <= '0;
    end else begin
        c_bd_tx_beats  <= c_bd_tx_beats  + (bd_tx_v_q && bd_tx_r_q);
        c_bd_tx_frames <= c_bd_tx_frames + (bd_tx_v_q && bd_tx_r_q && bd_tx_l_q);
        c_bd_rx_beats  <= c_bd_rx_beats  + (bd_rx_v_q && bd_rx_r_q);
        c_bd_rx_frames <= c_bd_rx_frames + (bd_rx_v_q && bd_rx_r_q && bd_rx_l_q);
        c_bd_rx_stall  <= c_bd_rx_stall  + (bd_rx_v_q && !bd_rx_r_q);
        c_bd_tx_stall  <= c_bd_tx_stall  + (bd_tx_v_q && !bd_tx_r_q);
        c_bd_rx_err    <= c_bd_rx_err    + (bd_rx_v_q && bd_rx_r_q && bd_rx_l_q && bd_rx_u_q);
    end
end

// ===========================================================================
// Local window read mux (nclk)
// ===========================================================================
function automatic logic [31:0] local_read(input logic [19:0] a);
    logic [31:0] r;
    r = 32'hBAD0_ADD0;
    if (a[19:8] == 12'h001) begin
        r = a[6] ? s_tx_cap[a[5:2]] : s_rx_cap[a[5:2]];
    end else if (a[19:8] == 12'h000) begin
        case (a[7:0])
            8'h00: r = MON_ID;
            8'h04: r = {29'b0, mon_ctrl};
            8'h08: r = s_cnt[0];
            8'h0C: r = c_ncyc;
            8'h10: r = s_cnt[1];   // rx_vld
            8'h14: r = s_cnt[2];   // rx_sop
            8'h18: r = s_cnt[3];   // rx_eop
            8'h1C: r = s_cnt[4];   // rx_err
            8'h20: r = s_cnt[5];   // rx_msop
            8'h24: r = s_cnt[6];   // rx_proto
            8'h28: r = s_cnt[7];   // rx_segs
            8'h30: r = s_cnt[8];   // tx_vld
            8'h34: r = s_cnt[9];   // tx_acc
            8'h38: r = s_cnt[10];  // tx_sop
            8'h3C: r = s_cnt[11];  // tx_eop
            8'h40: r = s_cnt[12];  // tx_stall
            8'h44: r = s_cnt[13];  // tx_proto
            8'h48: r = s_cnt[14];  // tx_segs
            8'h4C: r = s_cnt[15];  // rx_cap_n
            8'h50: r = c_bd_tx_frames;
            8'h54: r = c_bd_tx_beats;
            8'h58: r = c_bd_rx_frames;
            8'h5C: r = c_bd_rx_beats;
            8'h60: r = c_bd_rx_stall;
            8'h64: r = c_bd_tx_stall;
            8'h68: r = s_cnt[16];  // tx_cap_n
            8'h6C: r = c_bd_rx_err;
            default: r = 32'hBAD0_ADD0;
        endcase
    end
    return r;
endfunction

// ===========================================================================
// Request engine (nclk)
//
// Local accesses answer on the next cycle. DCMAC accesses go out as single
// AXI4-Lite transactions with bready/rready held high. If the slave does not
// answer within TIMEOUT cycles the request is failed with resp 2'b11, and the
// engine latches into ST_STUCK: AXI forbids withdrawing a valid, so it keeps
// the stuck channel asserted and from then on fails every DCMAC access
// immediately while the local window keeps working. That is what lets
// software tell "the DCMAC register port is dead" from "the debug path is".
// ===========================================================================
typedef enum logic [2:0] {ST_IDLE, ST_WR, ST_B, ST_RD, ST_STUCK} eng_state_t;

eng_state_t  st;
logic        aw_done, w_done;
logic [20:0] tmo;

assign m_axil_wstrb  = 4'hF;
assign m_axil_bready = 1'b1;
assign m_axil_rready = 1'b1;

always_ff @(posedge nclk) begin
    if (!nresetn) begin
        st             <= ST_IDLE;
        mon_ctrl       <= '0;
        reg_rsp        <= 1'b0;
        reg_rdata      <= '0;
        reg_resp       <= 2'b00;
        m_axil_awvalid <= 1'b0;
        m_axil_wvalid  <= 1'b0;
        m_axil_arvalid <= 1'b0;
        m_axil_awaddr  <= '0;
        m_axil_araddr  <= '0;
        m_axil_wdata   <= '0;
        aw_done        <= 1'b0;
        w_done         <= 1'b0;
        tmo            <= '0;
    end else begin
        reg_rsp <= 1'b0;

        case (st)
            ST_IDLE, ST_STUCK: if (reg_req) begin
                if (reg_addr[20]) begin
                    if (reg_wr && reg_addr[19:0] == 20'h4) begin
                        mon_ctrl <= reg_wdata[2:0];
                    end
                    reg_rdata <= reg_wr ? 32'h0 : local_read(reg_addr[19:0]);
                    reg_resp  <= 2'b00;
                    reg_rsp   <= 1'b1;
                end else if (st == ST_STUCK) begin
                    reg_rdata <= 32'hDEAD_0A1E;
                    reg_resp  <= 2'b11;
                    reg_rsp   <= 1'b1;
                end else if (reg_wr) begin
                    m_axil_awaddr  <= {12'b0, reg_addr[19:0]};
                    m_axil_wdata   <= reg_wdata;
                    m_axil_awvalid <= 1'b1;
                    m_axil_wvalid  <= 1'b1;
                    aw_done        <= 1'b0;
                    w_done         <= 1'b0;
                    tmo            <= '0;
                    st             <= ST_WR;
                end else begin
                    m_axil_araddr  <= {12'b0, reg_addr[19:0]};
                    m_axil_arvalid <= 1'b1;
                    tmo            <= '0;
                    st             <= ST_RD;
                end
            end

            ST_WR: begin
                tmo <= tmo + 1;
                if (m_axil_awvalid && m_axil_awready) begin
                    m_axil_awvalid <= 1'b0;
                    aw_done        <= 1'b1;
                end
                if (m_axil_wvalid && m_axil_wready) begin
                    m_axil_wvalid  <= 1'b0;
                    w_done         <= 1'b1;
                end
                if ((aw_done || (m_axil_awvalid && m_axil_awready)) &&
                    (w_done  || (m_axil_wvalid  && m_axil_wready))) begin
                    st <= ST_B;
                end else if (tmo == TIMEOUT - 1) begin
                    reg_rdata <= 32'hDEAD_0A1E;
                    reg_resp  <= 2'b11;
                    reg_rsp   <= 1'b1;
                    st        <= ST_STUCK;
                end
            end

            ST_B: begin
                tmo <= tmo + 1;
                if (m_axil_bvalid) begin
                    reg_rdata <= 32'h0;
                    reg_resp  <= m_axil_bresp;
                    reg_rsp   <= 1'b1;
                    st        <= ST_IDLE;
                end else if (tmo == TIMEOUT - 1) begin
                    reg_rdata <= 32'hDEAD_0A1E;
                    reg_resp  <= 2'b11;
                    reg_rsp   <= 1'b1;
                    st        <= ST_STUCK;
                end
            end

            ST_RD: begin
                tmo <= tmo + 1;
                if (m_axil_arvalid && m_axil_arready) begin
                    m_axil_arvalid <= 1'b0;
                end
                if (m_axil_rvalid) begin
                    reg_rdata <= m_axil_rdata;
                    reg_resp  <= m_axil_rresp;
                    reg_rsp   <= 1'b1;
                    st        <= ST_IDLE;
                end else if (tmo == TIMEOUT - 1) begin
                    reg_rdata <= 32'hDEAD_0A1E;
                    reg_resp  <= 2'b11;
                    reg_rsp   <= 1'b1;
                    st        <= ST_STUCK;
                end
            end

            default: st <= ST_IDLE;
        endcase
    end
end

endmodule
