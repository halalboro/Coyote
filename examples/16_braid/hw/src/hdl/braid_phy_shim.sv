/**
 * BRAID vFPGA-side PHY shim
 *
 * Adapts braid_link's 32-bit word port to the 256-bit AXI4-Stream that the
 * Coyote shell routes into the vFPGA. Deliberately agnostic to which PHY sits
 * on the far side of that stream in the shell -- braid_gty_wrapper today, and
 * this file would not change if it were something else tomorrow.
 *
 * One protocol word per 256-bit beat. Wasteful of width, trivially correct, and
 * width is not a resource under pressure here.
 *
 * Bit 32 of the RX stream carries the PHY's error flag (8B/10B disparity or
 * not-in-table), packed there by braid_gty_wrapper. braid_link folds it into
 * frame validity alongside its own checksum.
 */

module braid_phy_shim (
    input  logic          clk,
    input  logic          rstn,

    // ---- braid_link side: 32-bit words ----
    input  logic [31:0]   phy_tx_data,
    input  logic          phy_tx_valid,
    input  logic          phy_tx_last,
    output logic          phy_tx_ready,
    output logic [31:0]   phy_rx_data,
    output logic          phy_rx_valid,
    output logic          phy_rx_last,
    output logic          phy_rx_err,

    // ---- shell side: 256-bit AXI4-Stream, aclk domain ----
    output logic [255:0]  shl_tx_tdata,
    output logic          shl_tx_tvalid,
    output logic          shl_tx_tlast,
    input  logic          shl_tx_tready,
    input  logic [255:0]  shl_rx_tdata,
    input  logic          shl_rx_tvalid,
    input  logic          shl_rx_tlast,
    output logic          shl_rx_tready
);

    // TX registered so no long combinational path runs from the protocol core
    // into the shell's CDC FIFO.
    always_ff @(posedge clk) begin
        if (!rstn) begin
            shl_tx_tdata  <= '0;
            shl_tx_tvalid <= 1'b0;
            shl_tx_tlast  <= 1'b0;
        end else if (!shl_tx_tvalid || shl_tx_tready) begin
            shl_tx_tdata  <= {224'b0, phy_tx_data};
            shl_tx_tvalid <= phy_tx_valid;
            shl_tx_tlast  <= phy_tx_last;
        end
    end

    assign phy_tx_ready = !shl_tx_tvalid || shl_tx_tready;

    // Always ready: backpressuring a real-time syndrome stream cannot un-miss a
    // deadline, and dropped frames are caught by the checksum and round counter.
    assign shl_rx_tready = 1'b1;
    assign phy_rx_data   = shl_rx_tdata[31:0];
    assign phy_rx_valid  = shl_rx_tvalid;
    assign phy_rx_last   = shl_rx_tlast;
    assign phy_rx_err    = shl_rx_tdata[32];

endmodule
