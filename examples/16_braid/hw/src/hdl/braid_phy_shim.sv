/**
 * BRAID vFPGA-side PHY shim
 *
 * Adapts braid_link's 32-bit word ports to the 256-bit AXI4-Stream that the
 * Coyote shell routes into the vFPGA. One protocol word per 256-bit beat:
 * wasteful of width, trivially correct, and width is not a resource under
 * pressure here.
 *
 * TWO CLOCK DOMAINS, NO CROSSING. Since Task 2b the shell's streams arrive on
 * the GT's own clocks -- shl_tx_* in tx_clk, shl_rx_* in rx_clk -- and this
 * module is pure combinational rewiring, so it inherits both and mixes neither.
 * It takes no clock at all, which is the honest description: there is nothing
 * here to clock.
 *
 * The TX register stage that used to live here is GONE. It existed to keep a
 * long combinational path out of the shell's CDC FIFO; with that FIFO deleted it
 * was a second register behind braid_link_tx's own output register, worth 3.9 ns
 * of pure latency. braid_link_tx already drives phy_tx_* from flops, so the path
 * across the partition boundary is still register-to-register.
 *
 * Bit 32 of the RX stream carries the PHY's error flag (8B/10B disparity or
 * not-in-table), packed there by braid_gty_wrapper. braid_link_rx folds it into
 * frame validity alongside its own checksum.
 */

module braid_phy_shim (
    // ---- braid_link side: 32-bit words ----
    input  logic [31:0]   phy_tx_data,
    input  logic          phy_tx_valid,
    input  logic          phy_tx_last,
    output logic          phy_tx_ready,
    input  logic [23:0]   phy_tx_hdr,
    input  logic [23:0]   phy_tx_cks,
    input  logic [1:0]    phy_tx_type,
    output logic [31:0]   phy_rx_data,
    output logic          phy_rx_valid,
    output logic          phy_rx_eof,
    output logic          phy_rx_err,
    output logic [23:0]   phy_rx_hdr,
    output logic          phy_rx_sof,
    output logic [1:0]    phy_rx_type,
    output logic [23:0]   phy_rx_cks,

    // ---- shell side: 256-bit AXI4-Stream, GT clock domains ----
    output logic [255:0]  shl_tx_tdata,     // tx_clk
    output logic          shl_tx_tvalid,
    output logic          shl_tx_tlast,
    input  logic          shl_tx_tready,
    input  logic [255:0]  shl_rx_tdata,     // rx_clk
    input  logic          shl_rx_tvalid,
    input  logic          shl_rx_tlast,
    output logic          shl_rx_tready
);

    // The shell stream is 256 bits and a protocol word is 32, so the sidebands
    // ride in bits that were being wired to zero. No template change, no extra
    // partition pins.
    //   [31:0] data   [55:32] hdr   [79:56] cks   [81:80] type
    assign shl_tx_tdata  = {174'b0, phy_tx_type, phy_tx_cks, phy_tx_hdr, phy_tx_data};
    assign shl_tx_tvalid = phy_tx_valid;
    assign shl_tx_tlast  = phy_tx_last;
    assign phy_tx_ready  = shl_tx_tready;

    // Always ready: backpressuring a real-time syndrome stream cannot un-miss a
    // deadline, and dropped frames are caught by the checksum and round counter.
    assign shl_rx_tready = 1'b1;
    assign phy_rx_data   = shl_rx_tdata[31:0];
    assign phy_rx_valid  = shl_rx_tvalid;
    assign phy_rx_eof    = shl_rx_tlast;   // strobe, independent of tvalid
    assign phy_rx_err    = shl_rx_tdata[32];
    // RX carries an err bit that TX does not, so the offsets differ from the
    // transmit layout above by one. Do not "tidy" these into shared constants.
    //   [32] err  [56:33] hdr  [80:57] cks  [82:81] type  [83] sof
    assign phy_rx_hdr    = shl_rx_tdata[56:33];
    assign phy_rx_cks    = shl_rx_tdata[80:57];
    assign phy_rx_type   = shl_rx_tdata[82:81];
    assign phy_rx_sof    = shl_rx_tdata[83];

endmodule
