/**
 * Coyote Example 15 — vFPGA co-processor slave.
 *
 * The R5 (master) drives this block through the co-processor provider:
 *   - AXIS: R5 sends a single-beat request on axis_recv; this block computes
 *     PING/INC/ADD/SUM and returns a single-beat response on axis_send.
 *   - MMIO: the R5 reads/writes the verdict register file on axis_mmio
 *     (cyt_provider_app_read64/write64). The host mirrors those registers,
 *     read-only, over the vFPGA control interface axi_ctrl (BAR).
 *
 * See coprocessor_abi.svh for the packet + register layout.
 */

`timescale 1ns / 1ps

import lynxTypes::*;

`include "coprocessor_abi.svh"

module coprocessor_slave (
    input  logic aclk,
    input  logic aresetn,

    AXI4SR.s     axis_recv,   // request  (R5 -> vFPGA)
    AXI4SR.m     axis_send,    // response (vFPGA -> R5)
    AXI4L.s      axis_mmio,    // co-processor MMIO aperture (R5-mastered)
    AXI4L.s      axi_ctrl      // vFPGA host control (host reads the verdict)
);

    localparam logic [1:0] RESP_OKAY = 2'b00;
    localparam int         REG_LSB   = 3;                 // 64-bit words
    localparam int         REG_MSB   = $clog2(COP_MMIO_N_REGS);

    // ------------------------------------------------------------------ //
    //  Verdict register file: written by the R5 (axis_mmio), read by both //
    //  the R5 and the host. Single writer => single procedural driver.    //
    // ------------------------------------------------------------------ //
    logic [63:0] csr [COP_MMIO_N_REGS];

    // R5 MMIO write request (produced by the axis_mmio slave FSM below)
    logic                     mmio_wr_en;
    logic [REG_MSB-1:0]       mmio_wr_idx;
    logic [63:0]              mmio_wr_data;
    logic [7:0]               mmio_wr_strb;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            for (int i = 0; i < COP_MMIO_N_REGS; i++) csr[i] <= '0;
        end else if (mmio_wr_en && mmio_wr_idx != COP_MMIO_MAGIC[REG_MSB-1:0]) begin
            for (int b = 0; b < 8; b++)
                if (mmio_wr_strb[b]) csr[mmio_wr_idx][b*8 +: 8] <= mmio_wr_data[b*8 +: 8];
        end
    end

    function automatic logic [63:0] read_csr(input logic [REG_MSB-1:0] idx);
        if (idx == COP_MMIO_MAGIC[REG_MSB-1:0])
            return {32'd0, COP_MMIO_MAGIC_VALUE};
        else
            return csr[idx];
    endfunction

    // ------------------------------------------------------------------ //
    //  AXIS request/response compute (single beat, one request in flight) //
    // ------------------------------------------------------------------ //
    typedef enum logic [0:0] { ST_RECV, ST_SEND } cop_state_t;
    cop_state_t state;

    logic [63:0] acc;                 // SUM accumulator (reset by PING)
    // AXI4S_DATA_BITS / AXI4S_ID_BITS are PARAMETERS OF THE AXI4SR INTERFACE
    // (hw/hdl/pkg/axi_intf.sv:531-532), visible only inside it -- not package
    // constants, so they do not resolve in a module body. Use the lynxTypes
    // constants the ports are actually instantiated with in user_wrapper:
    //   AXI4SR #(.AXI4S_DATA_BITS(COPROCESSOR_STREAM_DATA_BITS),
    //            .AXI4S_ID_BITS(COPROCESSOR_STREAM_ID_BITS)) axis_coprocessor_*
    // AXI_DATA_BITS/PID_BITS happen to hold the same values (512/6) today, but
    // would silently desync if the coprocessor port width is ever reconfigured.
    logic [COPROCESSOR_STREAM_DATA_BITS-1:0] resp_tdata;
    logic [COPROCESSOR_STREAM_ID_BITS-1:0]   resp_tid;

    function automatic logic [63:0] compute(
        input logic [31:0] opcode,
        input logic [31:0] a,
        input logic [31:0] b,
        input logic [63:0] acc_in,
        output logic [31:0] status
    );
        status = COP_ST_OK;
        case (opcode)
            COP_OP_PING: return {32'd0, a};
            COP_OP_INC:  return {32'd0, a + 32'd1};
            COP_OP_ADD:  return {32'd0, a + b};
            COP_OP_SUM:  return acc_in + {32'd0, a};
            default: begin status = COP_ST_BAD_OPCODE; return 64'd0; end
        endcase
    endfunction

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            state      <= ST_RECV;
            acc        <= '0;
            resp_tdata <= '0;
            resp_tid   <= '0;
        end else begin
            case (state)
                ST_RECV: begin
                    if (axis_recv.tvalid) begin
                        automatic logic [31:0] opcode = axis_recv.tdata[31:0];
                        automatic logic [31:0] a      = axis_recv.tdata[63:32];
                        automatic logic [31:0] b      = axis_recv.tdata[95:64];
                        automatic logic [31:0] seq    = axis_recv.tdata[127:96];
                        automatic logic [31:0] status;
                        automatic logic [63:0] result;
                        automatic logic [63:0] next_acc;

                        next_acc = (opcode == COP_OP_PING) ? 64'd0 :
                                   (opcode == COP_OP_SUM)  ? acc + {32'd0, a} : acc;
                        result   = compute(opcode, a, b, acc, status);
                        acc      <= next_acc;

                        resp_tdata <= '0;
                        resp_tdata[31:0]   <= status;       // lane0 status
                        resp_tdata[63:32]  <= result[31:0]; // lane1 result
                        resp_tdata[95:64]  <= opcode;       // lane2 opcode echo
                        resp_tdata[127:96] <= seq;          // lane3 seq echo
                        resp_tid           <= axis_recv.tid;
                        state               <= ST_SEND;
                    end
                end
                ST_SEND: begin
                    if (axis_send.tready) state <= ST_RECV;
                end
            endcase
        end
    end

    // axis_recv accepts only in ST_RECV (single beat, tlast assumed)
    assign axis_recv.tready = (state == ST_RECV);

    // axis_send drives the response beat in ST_SEND
    assign axis_send.tdata  = resp_tdata;
    assign axis_send.tkeep  = '1;
    assign axis_send.tid    = resp_tid;
    assign axis_send.tlast  = 1'b1;
    assign axis_send.tvalid = (state == ST_SEND);

    // ------------------------------------------------------------------ //
    //  AXI4-Lite slave: co-processor MMIO aperture (R5 read/write)        //
    // ------------------------------------------------------------------ //
    // Write channel
    logic mmio_aw_ok, mmio_w_ok;
    assign mmio_aw_ok = axis_mmio.awvalid && !axis_mmio.awready;
    assign mmio_w_ok  = axis_mmio.wvalid  && !axis_mmio.wready;

    logic [REG_MSB-1:0] mmio_awidx;
    assign mmio_awidx = axis_mmio.awaddr[REG_LSB +: REG_MSB];

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            axis_mmio.awready <= 1'b0;
            axis_mmio.wready  <= 1'b0;
            axis_mmio.bvalid  <= 1'b0;
            axis_mmio.bresp   <= RESP_OKAY;
            mmio_wr_en        <= 1'b0;
        end else begin
            mmio_wr_en <= 1'b0;
            axis_mmio.awready <= (!axis_mmio.awready && axis_mmio.awvalid && axis_mmio.wvalid &&
                                  (!axis_mmio.bvalid || axis_mmio.bready));
            axis_mmio.wready  <= (!axis_mmio.wready  && axis_mmio.awvalid && axis_mmio.wvalid &&
                                  (!axis_mmio.bvalid || axis_mmio.bready));
            if (axis_mmio.awready && axis_mmio.wready) begin
                mmio_wr_en   <= 1'b1;
                mmio_wr_idx  <= mmio_awidx;
                mmio_wr_data <= axis_mmio.wdata;
                mmio_wr_strb <= axis_mmio.wstrb;
                axis_mmio.bvalid <= 1'b1;
                axis_mmio.bresp  <= RESP_OKAY;
            end else if (axis_mmio.bvalid && axis_mmio.bready) begin
                axis_mmio.bvalid <= 1'b0;
            end
        end
    end

    // Read channel
    logic [REG_MSB-1:0] mmio_aridx;
    assign mmio_aridx = axis_mmio.araddr[REG_LSB +: REG_MSB];
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            axis_mmio.arready <= 1'b0;
            axis_mmio.rvalid  <= 1'b0;
            axis_mmio.rresp   <= RESP_OKAY;
            axis_mmio.rdata   <= '0;
        end else begin
            axis_mmio.arready <= (!axis_mmio.arready && axis_mmio.arvalid &&
                                  (!axis_mmio.rvalid || axis_mmio.rready));
            if (axis_mmio.arready && axis_mmio.arvalid) begin
                axis_mmio.rdata  <= read_csr(mmio_aridx);
                axis_mmio.rvalid <= 1'b1;
                axis_mmio.rresp  <= RESP_OKAY;
            end else if (axis_mmio.rvalid && axis_mmio.rready) begin
                axis_mmio.rvalid <= 1'b0;
            end
        end
    end

    // ------------------------------------------------------------------ //
    //  AXI4-Lite slave: host control (axi_ctrl) — READ-ONLY verdict mirror //
    //  Writes are accepted and dropped so the host bus never hangs.        //
    // ------------------------------------------------------------------ //
    logic [REG_MSB-1:0] ctrl_aridx;
    assign ctrl_aridx = axi_ctrl.araddr[REG_LSB +: REG_MSB];

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            axi_ctrl.awready <= 1'b0; axi_ctrl.wready <= 1'b0;
            axi_ctrl.bvalid  <= 1'b0; axi_ctrl.bresp  <= RESP_OKAY;
            axi_ctrl.arready <= 1'b0; axi_ctrl.rvalid <= 1'b0;
            axi_ctrl.rresp   <= RESP_OKAY; axi_ctrl.rdata <= '0;
        end else begin
            // write: accept and drop
            axi_ctrl.awready <= (!axi_ctrl.awready && axi_ctrl.awvalid && axi_ctrl.wvalid &&
                                 (!axi_ctrl.bvalid || axi_ctrl.bready));
            axi_ctrl.wready  <= (!axi_ctrl.wready  && axi_ctrl.awvalid && axi_ctrl.wvalid &&
                                 (!axi_ctrl.bvalid || axi_ctrl.bready));
            if (axi_ctrl.awready && axi_ctrl.wready) axi_ctrl.bvalid <= 1'b1;
            else if (axi_ctrl.bvalid && axi_ctrl.bready) axi_ctrl.bvalid <= 1'b0;
            // read: verdict mirror
            axi_ctrl.arready <= (!axi_ctrl.arready && axi_ctrl.arvalid &&
                                 (!axi_ctrl.rvalid || axi_ctrl.rready));
            if (axi_ctrl.arready && axi_ctrl.arvalid) begin
                axi_ctrl.rdata  <= read_csr(ctrl_aridx);
                axi_ctrl.rvalid <= 1'b1;
                axi_ctrl.rresp  <= RESP_OKAY;
            end else if (axi_ctrl.rvalid && axi_ctrl.rready) begin
                axi_ctrl.rvalid <= 1'b0;
            end
        end
    end

endmodule
