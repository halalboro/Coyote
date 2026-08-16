/**
 * This file is part of the Coyote <https://github.com/fpgasystems/Coyote>
 *
 * MIT Licence
 * Copyright (c) 2026, Systems Group, ETH Zurich
 * All rights reserved.
 */

import lynxTypes::*;

/**
 * ocm_mbx — vFPGA side of the on-card R5 <-> vFPGA channel through OCM.
 *
 * Drives a narrow (32-bit) AXI4 master that reaches the R5's on-chip SRAM (OCM,
 * LPD, base 0xFFFF_F000) through the shell -> CIPS S_AXI_LPD. Implements a small
 * mailbox in OCM (word offsets, little-endian):
 *
 *   0x00 C2V_SEQ   (R5 writes)  R5->vFPGA doorbell: R5 bumps after a command
 *   0x04 OPCODE    (R5)         1 = "+1 over the data window"
 *   0x08 N_WORDS   (R5)         payload length (<= N_DATA)
 *   0x10 V2C_SEQ   (vFPGA)      set = C2V_SEQ when done; also raises irq
 *   0x14 RCODE     (vFPGA)      0 ok, 1 bad opcode, 2 too big
 *   0x18 OUT_WORDS (vFPGA)
 *   0x40 DATA[k]   (both)       R5 writes input; vFPGA overwrites with +1
 *
 * The FSM polls C2V_SEQ; on a new value it reads the command + data window,
 * computes +1, writes the results back, sets V2C_SEQ, and pulses `irq` to the
 * R5 (pl_ps_irq1). Single outstanding AXI transaction (mailbox, not bandwidth).
 * OCM is device/strongly-ordered from the R5, so ordering is simple.
 */
module ocm_mbx #(
  parameter [63:0]  OCM_BASE = 64'h0000_0000_FFFF_F000,
  parameter integer N_DATA   = 32
) (
  input  logic  aclk,
  input  logic  aresetn,

  AXI4.m        m_axi,      // 32-bit data, 64-bit addr master to OCM (via S_AXI_LPD)
  output logic  irq         // -> pl_ps_irq1 (vFPGA -> R5 doorbell)
);

// ---- mailbox byte offsets ------------------------------------------------
localparam [63:0] OFF_C2V_SEQ   = 64'h00;
localparam [63:0] OFF_OPCODE    = 64'h04;
localparam [63:0] OFF_N_WORDS   = 64'h08;
localparam [63:0] OFF_V2C_SEQ   = 64'h10;
localparam [63:0] OFF_RCODE     = 64'h14;
localparam [63:0] OFF_OUT_WORDS = 64'h18;
localparam [63:0] OFF_DATA      = 64'h40;

localparam [31:0] OP_INC        = 32'd1;
localparam [31:0] RC_OK         = 32'd0;
localparam [31:0] RC_BAD_OPCODE = 32'd1;
localparam [31:0] RC_TOO_BIG    = 32'd2;

localparam integer IDX_W = (N_DATA > 1) ? $clog2(N_DATA) : 1;
localparam integer CNT_W = $clog2(N_DATA + 1);

// ---- single-beat AXI4 read/write engine ----------------------------------
// One transaction at a time. rd_go/wr_go pulse to start; rd_done/wr_done pulse
// on completion. addr is byte address; wdata/rdata are 32-bit.
logic         rd_go, wr_go, rd_done, wr_done;
logic [63:0]  axi_addr;
logic [31:0]  axi_wdata;
logic [31:0]  axi_rdata;

typedef enum logic [1:0] { A_IDLE, A_READ, A_WRITE } eng_t;
eng_t eng_state;

always_ff @(posedge aclk) begin
  if (!aresetn) begin
    eng_state          <= A_IDLE;
    rd_done            <= 1'b0;
    wr_done            <= 1'b0;
    axi_rdata          <= 32'd0;
    m_axi.arvalid      <= 1'b0;
    m_axi.rready       <= 1'b0;
    m_axi.awvalid      <= 1'b0;
    m_axi.wvalid       <= 1'b0;
    m_axi.bready       <= 1'b0;
  end
  else begin
    rd_done <= 1'b0;
    wr_done <= 1'b0;
    case (eng_state)
      A_IDLE: begin
        if (rd_go) begin
          m_axi.araddr  <= axi_addr;
          m_axi.arvalid <= 1'b1;
          m_axi.rready  <= 1'b0;
          eng_state     <= A_READ;
        end
        else if (wr_go) begin
          m_axi.awaddr  <= axi_addr;
          m_axi.awvalid <= 1'b1;
          m_axi.wdata   <= axi_wdata;
          m_axi.wvalid  <= 1'b1;
          m_axi.bready  <= 1'b0;
          eng_state     <= A_WRITE;
        end
      end

      A_READ: begin
        if (m_axi.arvalid && m_axi.arready) begin
          m_axi.arvalid <= 1'b0;
          m_axi.rready  <= 1'b1;
        end
        if (m_axi.rvalid && m_axi.rready) begin
          axi_rdata     <= m_axi.rdata[31:0];
          m_axi.rready  <= 1'b0;
          rd_done       <= 1'b1;
          eng_state     <= A_IDLE;
        end
      end

      A_WRITE: begin
        if (m_axi.awvalid && m_axi.awready) m_axi.awvalid <= 1'b0;
        if (m_axi.wvalid  && m_axi.wready ) m_axi.wvalid  <= 1'b0;
        if (!m_axi.awvalid && !m_axi.wvalid) m_axi.bready <= 1'b1;
        if (m_axi.bvalid && m_axi.bready) begin
          m_axi.bready <= 1'b0;
          wr_done      <= 1'b1;
          eng_state    <= A_IDLE;
        end
      end

      default: eng_state <= A_IDLE;
    endcase
  end
end

// Static AXI4 sideband for single 32-bit INCR beats.
always_comb begin
  m_axi.arlen    = 8'd0;   m_axi.awlen    = 8'd0;
  m_axi.arsize   = 3'd2;   m_axi.awsize   = 3'd2;      // 4 bytes
  m_axi.arburst  = 2'b01;  m_axi.awburst  = 2'b01;     // INCR
  m_axi.arlock   = 1'b0;   m_axi.awlock   = 1'b0;
  m_axi.arcache  = 4'd0;   m_axi.awcache  = 4'd0;
  m_axi.arprot   = 3'd0;   m_axi.awprot   = 3'd0;
  m_axi.arqos    = 4'd0;   m_axi.awqos    = 4'd0;
  m_axi.arregion = 4'd0;   m_axi.awregion = 4'd0;
  m_axi.arid     = '0;     m_axi.awid     = '0;
  m_axi.wstrb    = 4'hF;
  m_axi.wlast    = 1'b1;
end

// ---- mailbox FSM ---------------------------------------------------------
typedef enum logic [4:0] {
  S_POLL_REQ, S_POLL_WAIT,
  S_RD_OP,    S_RD_OP_W,
  S_RD_N,     S_RD_N_W,
  S_RD_DATA,  S_RD_DATA_W,
  S_WR_DATA,  S_WR_DATA_W,
  S_WR_OUT,   S_WR_OUT_W,
  S_WR_RC,    S_WR_RC_W,
  S_WR_V2C,   S_WR_V2C_W,
  S_IRQ
} state_t;
state_t state;

logic [31:0]      c2v_last;   // last completed C2V_SEQ
logic [31:0]      c2v_cur;    // C2V_SEQ of the request in flight
logic [31:0]      opcode_r;
logic [CNT_W-1:0] n_r;        // clamped count
logic [IDX_W-1:0] idx;
logic             bad_op, too_big;

// helpers to launch a transaction
task automatic do_read(input [63:0] boff);
  axi_addr <= OCM_BASE + boff; rd_go <= 1'b1;
endtask
task automatic do_write(input [63:0] boff, input [31:0] val);
  axi_addr <= OCM_BASE + boff; axi_wdata <= val; wr_go <= 1'b1;
endtask

always_ff @(posedge aclk) begin
  if (!aresetn) begin
    state    <= S_POLL_REQ;
    c2v_last <= 32'd0;
    c2v_cur  <= 32'd0;
    opcode_r <= 32'd0;
    n_r      <= '0;
    idx      <= '0;
    bad_op   <= 1'b0;
    too_big  <= 1'b0;
    irq      <= 1'b0;
    rd_go    <= 1'b0;
    wr_go    <= 1'b0;
  end
  else begin
    rd_go <= 1'b0;
    wr_go <= 1'b0;
    irq   <= 1'b0;   // 1-cycle pulse

    case (state)
      // Poll C2V_SEQ
      S_POLL_REQ:  begin do_read(OFF_C2V_SEQ); state <= S_POLL_WAIT; end
      S_POLL_WAIT: if (rd_done) begin
                     if (axi_rdata != c2v_last) begin
                       c2v_cur <= axi_rdata;
                       state   <= S_RD_OP;
                     end else state <= S_POLL_REQ;
                   end

      // Read command
      S_RD_OP:   begin do_read(OFF_OPCODE);  state <= S_RD_OP_W; end
      S_RD_OP_W: if (rd_done) begin opcode_r <= axi_rdata; state <= S_RD_N; end
      S_RD_N:    begin do_read(OFF_N_WORDS); state <= S_RD_N_W; end
      S_RD_N_W:  if (rd_done) begin
                   bad_op  <= (opcode_r != OP_INC);
                   too_big <= (axi_rdata > N_DATA);
                   n_r     <= (axi_rdata > N_DATA) ? CNT_W'(N_DATA) : axi_rdata[CNT_W-1:0];
                   idx     <= '0;
                   if ((opcode_r != OP_INC) || (axi_rdata > N_DATA) || (axi_rdata == 32'd0))
                     state <= S_WR_OUT;         // nothing to process
                   else
                     state <= S_RD_DATA;
                 end

      // Read-modify-write each data word (+1)
      S_RD_DATA:   begin do_read(OFF_DATA + (64'(idx) << 2)); state <= S_RD_DATA_W; end
      S_RD_DATA_W: if (rd_done) begin state <= S_WR_DATA; end
      S_WR_DATA:   begin do_write(OFF_DATA + (64'(idx) << 2), axi_rdata + 32'd1); state <= S_WR_DATA_W; end
      S_WR_DATA_W: if (wr_done) begin
                     if (idx == (n_r - 1)) state <= S_WR_OUT;
                     else begin idx <= idx + 1'b1; state <= S_RD_DATA; end
                   end

      // Status
      S_WR_OUT:   begin do_write(OFF_OUT_WORDS,
                                 (bad_op || too_big) ? 32'd0 : {{(32-CNT_W){1'b0}}, n_r});
                        state <= S_WR_OUT_W; end
      S_WR_OUT_W: if (wr_done) state <= S_WR_RC;
      S_WR_RC:    begin do_write(OFF_RCODE,
                                 bad_op ? RC_BAD_OPCODE : (too_big ? RC_TOO_BIG : RC_OK));
                        state <= S_WR_RC_W; end
      S_WR_RC_W:  if (wr_done) state <= S_WR_V2C;

      // Completion + doorbell
      S_WR_V2C:   begin do_write(OFF_V2C_SEQ, c2v_cur); state <= S_WR_V2C_W; end
      S_WR_V2C_W: if (wr_done) begin c2v_last <= c2v_cur; state <= S_IRQ; end
      S_IRQ:      begin irq <= 1'b1; state <= S_POLL_REQ; end

      default: state <= S_POLL_REQ;
    endcase
  end
end

endmodule
