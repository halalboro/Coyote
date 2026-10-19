/**
 * QLINK vFPGA-side PHY shim
 *
 * Adapts qlink_link's 32-bit word ports to the 256-bit AXI4-Stream that the
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
 * Phase A: HDR and CKS carry full 32-bit application-defined values (§3 QLink
 * header and CRC-32). The 2-bit TYPE sideband is gone -- TYPE sits in HDR
 * byte 0 now, so there is no separate type wire to route across the partition
 * boundary. The RX err flag bit stays where it is (bit 32) for the shell wire,
 * but phy_rx_err is tied low by qlink_framer_raw in raw mode.
 */

module qlink_phy_shim (
    // ---- qlink_link side: 32-bit words ----
    input  logic [31:0]   phy_tx_data,
    input  logic          phy_tx_valid,
    input  logic          phy_tx_last,
    output logic          phy_tx_ready,
    input  logic [31:0]   phy_tx_hdr,
    input  logic [31:0]   phy_tx_cks,
    output logic [31:0]   phy_rx_data,
    output logic          phy_rx_valid,
    output logic          phy_rx_eof,
    output logic          phy_rx_err,
    output logic [31:0]   phy_rx_hdr,
    output logic          phy_rx_sof,
    output logic [31:0]   phy_rx_cks,

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
    //   [31:0] data   [63:32] hdr   [95:64] cks
    assign shl_tx_tdata  = {160'b0, phy_tx_cks, phy_tx_hdr, phy_tx_data};
    assign shl_tx_tvalid = phy_tx_valid;
    assign shl_tx_tlast  = phy_tx_last;
    assign phy_tx_ready  = shl_tx_tready;

    // Always ready: backpressuring a real-time syndrome stream cannot un-miss a
    // deadline, and dropped frames are caught by the CRC and round counter.
    assign shl_rx_tready = 1'b1;
    assign phy_rx_data   = shl_rx_tdata[31:0];
    assign phy_rx_valid  = shl_rx_tvalid;
    assign phy_rx_eof    = shl_rx_tlast;   // strobe, independent of tvalid
    // RX carries an err bit that TX does not, so the offsets differ from the
    // transmit layout above by one. Do not "tidy" these into shared constants.
    //   [32] err  [64:33] hdr  [96:65] cks  [97] sof
    assign phy_rx_err    = shl_rx_tdata[32];
    assign phy_rx_hdr    = shl_rx_tdata[64:33];
    assign phy_rx_cks    = shl_rx_tdata[96:65];
    assign phy_rx_sof    = shl_rx_tdata[97];

endmodule
