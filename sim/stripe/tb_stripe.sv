`timescale 1ns / 1ps

import lynxTypes::*;

// Testbench for axi_stripe_rd / axi_stripe_wr: two memory channels with random latencies, responses returned out of
// order across channels and interleaved per beat, random back-pressure everywhere. Checks data, IDs, rlast and B counts.
module tb_stripe;

localparam integer NCH = N_STRIPE_CHAN;
localparam integer BEAT = AXI_DATA_BITS/8;
localparam integer SPACE = 256 * 1024;          // striped test space (bytes)
localparam integer ROUNDS = 6;
localparam integer NBURSTS = 300;

logic aclk = 0, aresetn = 0;
always #2 aclk = ~aclk;

// ---------------- DUT signals
logic [AXI_ADDR_BITS-1:0] s_araddr, m_araddr, s_awaddr, m_awaddr;
logic [1:0] s_arburst, m_arburst, s_awburst, m_awburst;
logic [3:0] s_arcache, m_arcache, s_awcache, m_awcache;
logic [AXI_ID_BITS-1:0] s_arid, m_arid, s_awid, m_awid, s_rid, m_rid, s_bid, m_bid;
logic [7:0] s_arlen, m_arlen, s_awlen, m_awlen;
logic [0:0] s_arlock, m_arlock, s_awlock, m_awlock;
logic [2:0] s_arprot, m_arprot, s_awprot, m_awprot, s_arsize, m_arsize, s_awsize, m_awsize;
logic [3:0] s_arqos, m_arqos, s_awqos, m_awqos, s_arregion, m_arregion, s_awregion, m_awregion;
logic s_arready, s_arvalid, m_arready, m_arvalid, s_awready, s_awvalid, m_awready, m_awvalid;
logic [AXI_DATA_BITS-1:0] s_rdata, m_rdata, s_wdata, m_wdata;
logic s_rlast, m_rlast, s_rready, s_rvalid, m_rready, m_rvalid;
logic [1:0] s_rresp, m_rresp, s_bresp, m_bresp;
logic [AXI_DATA_BITS/8-1:0] s_wstrb, m_wstrb;
logic s_wlast, m_wlast, s_wready, s_wvalid, m_wready, m_wvalid;
logic s_bready, s_bvalid, m_bready, m_bvalid;

axi_stripe_rd dut_rd (
    .aclk(aclk), .aresetn(aresetn),
    .s_axi_araddr(s_araddr), .s_axi_arburst(s_arburst), .s_axi_arcache(s_arcache), .s_axi_arid(s_arid), .s_axi_arlen(s_arlen),
    .s_axi_arlock(s_arlock), .s_axi_arprot(s_arprot), .s_axi_arqos(s_arqos), .s_axi_arregion(s_arregion), .s_axi_arsize(s_arsize),
    .s_axi_arready(s_arready), .s_axi_arvalid(s_arvalid),
    .m_axi_araddr(m_araddr), .m_axi_arburst(m_arburst), .m_axi_arcache(m_arcache), .m_axi_arid(m_arid), .m_axi_arlen(m_arlen),
    .m_axi_arlock(m_arlock), .m_axi_arprot(m_arprot), .m_axi_arqos(m_arqos), .m_axi_arregion(m_arregion), .m_axi_arsize(m_arsize),
    .m_axi_arready(m_arready), .m_axi_arvalid(m_arvalid),
    .s_axi_rdata(s_rdata), .s_axi_rid(s_rid), .s_axi_rlast(s_rlast), .s_axi_rresp(s_rresp), .s_axi_rready(s_rready), .s_axi_rvalid(s_rvalid),
    .m_axi_rdata(m_rdata), .m_axi_rid(m_rid), .m_axi_rlast(m_rlast), .m_axi_rresp(m_rresp), .m_axi_rready(m_rready), .m_axi_rvalid(m_rvalid)
);

axi_stripe_wr dut_wr (
    .aclk(aclk), .aresetn(aresetn),
    .s_axi_awaddr(s_awaddr), .s_axi_awburst(s_awburst), .s_axi_awcache(s_awcache), .s_axi_awid(s_awid), .s_axi_awlen(s_awlen),
    .s_axi_awlock(s_awlock), .s_axi_awprot(s_awprot), .s_axi_awqos(s_awqos), .s_axi_awregion(s_awregion), .s_axi_awsize(s_awsize),
    .s_axi_awready(s_awready), .s_axi_awvalid(s_awvalid),
    .m_axi_awaddr(m_awaddr), .m_axi_awburst(m_awburst), .m_axi_awcache(m_awcache), .m_axi_awid(m_awid), .m_axi_awlen(m_awlen),
    .m_axi_awlock(m_awlock), .m_axi_awprot(m_awprot), .m_axi_awqos(m_awqos), .m_axi_awregion(m_awregion), .m_axi_awsize(m_awsize),
    .m_axi_awready(m_awready), .m_axi_awvalid(m_awvalid),
    .s_axi_bid(s_bid), .s_axi_bresp(s_bresp), .s_axi_bready(s_bready), .s_axi_bvalid(s_bvalid),
    .m_axi_bid(m_bid), .m_axi_bresp(m_bresp), .m_axi_bready(m_bready), .m_axi_bvalid(m_bvalid),
    .s_axi_wdata(s_wdata), .s_axi_wlast(s_wlast), .s_axi_wstrb(s_wstrb), .s_axi_wready(s_wready), .s_axi_wvalid(s_wvalid),
    .m_axi_wdata(m_wdata), .m_axi_wlast(m_wlast), .m_axi_wstrb(m_wstrb), .m_axi_wready(m_wready), .m_axi_wvalid(m_wvalid)
);

assign s_arburst = 2'b01; assign s_arcache = 0; assign s_arlock = 0; assign s_arprot = 0; assign s_arqos = 0; assign s_arregion = 0;
assign s_arsize = 3'b110;
assign s_awburst = 2'b01; assign s_awcache = 0; assign s_awlock = 0; assign s_awprot = 0; assign s_awqos = 0; assign s_awregion = 0;
assign s_awsize = 3'b110; assign s_wstrb = '1;

int errors = 0;
task automatic err(string msg);
    errors++;
    if (errors < 20) $display("[%0t] ERROR: %s", $time, msg);
endtask

// ---------------- reference (striped space, one word per beat)
logic [AXI_DATA_BITS-1:0] ref_mem [longint];
// ---------------- channel memories (physical, per channel)
logic [AXI_DATA_BITS-1:0] ch_mem [NCH][longint];

function automatic logic [AXI_DATA_BITS-1:0] rnd_word();
    logic [AXI_DATA_BITS-1:0] w;
    for (int i = 0; i < AXI_DATA_BITS/32; i++) w[i*32+:32] = $urandom;
    return w;
endfunction

// ================= channel models
typedef struct { longint addr; int len; int id; longint ready_t; } req_t;
req_t rq [NCH][$];          // reads in flight, per channel (in order)
req_t wq [$];               // writes in global AW order (W follows it)
req_t bq [NCH][$];          // pending B per channel

int r_beat [NCH];
int r_cur;                  // channel currently driving R
longint cyc = 0;
always @(posedge aclk) cyc <= cyc + 1;

// AR / AW acceptance with random back-pressure
always @(posedge aclk) begin
    m_arready <= ($urandom % 4) != 0;
    m_awready <= ($urandom % 4) != 0;
    m_wready  <= ($urandom % 5) != 0;
end

int max_rq [NCH];
always @(posedge aclk) if (aresetn) begin
    if (m_arvalid && m_arready) begin
        int c; req_t r;
        c = m_araddr >> MC_SIZE;
        if (m_arid != c) err($sformatf("arid %0d for channel %0d", m_arid, c));
        r.addr = m_araddr & ((64'd1 << MC_SIZE) - 1); r.len = m_arlen; r.id = m_arid;
        r.ready_t = cyc + 20 + (c == 0 ? $urandom % 80 : $urandom % 10);    // channel 0 slower
        rq[c].push_back(r);
        if (rq[c].size() > max_rq[c]) max_rq[c] = rq[c].size();
    end
    if (m_awvalid && m_awready) begin
        int c; req_t r;
        c = m_awaddr >> MC_SIZE;
        if (m_awid != c) err($sformatf("awid %0d for channel %0d", m_awid, c));
        r.addr = m_awaddr & ((64'd1 << MC_SIZE) - 1); r.len = m_awlen; r.id = c;
        wq.push_back(r);
    end
end

// R: pick a channel with ready data at random, interleave per beat
always @(posedge aclk) begin
    if (!aresetn) begin
        m_rvalid <= 0;
        for (int c = 0; c < NCH; c++) r_beat[c] = 0;
    end else begin
        if (m_rvalid && m_rready) begin
            r_beat[r_cur]++;
            if (m_rlast) begin rq[r_cur].pop_front(); r_beat[r_cur] = 0; end
        end
        m_rvalid <= 0;
        if ($urandom % 3 != 0) begin
            int c0;
            c0 = $urandom % NCH;
            for (int k = 0; k < NCH; k++) begin
                int c;
                c = (c0 + k) % NCH;
                if (rq[c].size() > 0 && rq[c][0].ready_t <= cyc) begin
                    longint a;
                    a = rq[c][0].addr + r_beat[c] * BEAT;
                    r_cur = c;
                    m_rvalid <= 1;
                    m_rid <= rq[c][0].id;
                    m_rdata <= ch_mem[c].exists(a) ? ch_mem[c][a] : '0;
                    m_rresp <= 0;
                    m_rlast <= (r_beat[c] == rq[c][0].len);
                    break;
                end
            end
        end
    end
end

// W: follows AW order; check wlast against the part length
int w_beat = 0;
always @(posedge aclk) if (aresetn) begin
    if (m_wvalid && m_wready) begin
        if (wq.size() == 0) err("W beat before its AW");
        else begin
            int c; req_t r;
            r = wq[0];
            c = r.id;
            ch_mem[c][r.addr + w_beat * BEAT] = m_wdata;
            if (m_wlast != (w_beat == r.len)) err($sformatf("wlast %0d at beat %0d of %0d", m_wlast, w_beat, r.len));
            if (w_beat == r.len) begin
                r.ready_t = cyc + 10 + (c == 0 ? $urandom % 60 : $urandom % 8);
                bq[c].push_back(r);
                wq.pop_front();
                w_beat = 0;
            end else w_beat++;
        end
    end
end

// B: per channel in order, random channel
int b_cur;
longint ch_b_done [NCH];
longint ch_b_need [NCH];
always @(posedge aclk) begin
    if (!aresetn) m_bvalid <= 0;
    else begin
        if (m_bvalid && m_bready) begin bq[b_cur].pop_front(); ch_b_done[b_cur]++; end
        m_bvalid <= 0;
        if ($urandom % 2) begin
            int c0;
            c0 = $urandom % NCH;
            for (int k = 0; k < NCH; k++) begin
                int c;
                c = (c0 + k) % NCH;
                if (bq[c].size() > 0 && bq[c][0].ready_t <= cyc && !(m_bvalid && m_bready && b_cur == c && bq[c].size() == 1)) begin
                    b_cur = c; m_bvalid <= 1; m_bid <= c; m_bresp <= 0;
                    break;
                end
            end
        end
    end
end

// ================= shell side
typedef struct { longint addr; int len; int id; int parts [NCH]; } sreq_t;
sreq_t aw_list [$], ar_list [$], ar_exp [$], b_exp [$];
logic [AXI_DATA_BITS-1:0] w_list [$];

function automatic sreq_t rnd_burst();
    sreq_t r;
    longint a; int len, room;
    a = ($urandom % (SPACE / BEAT)) * BEAT;
    room = (4096 - (a % 4096)) / BEAT;                       // AXI: no 4 KB crossing
    case ($urandom % 4)
        0: len = 1;
        1: len = 1 + $urandom % 4;
        default: len = 1 + $urandom % 64;
    endcase
    if (len > room) len = room;
    r.addr = a; r.len = len - 1; r.id = $urandom % 4;
    return r;
endfunction

always @(posedge aclk) begin
    s_rready <= ($urandom % 4) != 0;
    s_bready <= ($urandom % 3) != 0;
end

// AW driver
initial begin
    s_awvalid = 0;
    forever begin
        @(posedge aclk);
        if (s_awvalid && s_awready) begin aw_list.pop_front(); s_awvalid = 0; end
        if (!s_awvalid && aw_list.size() > 0 && ($urandom % 3 != 0)) begin
            s_awvalid = 1; s_awaddr = aw_list[0].addr; s_awlen = aw_list[0].len; s_awid = aw_list[0].id;
        end
        #0.1;
    end
end
// W driver (independent of AW)
initial begin
    s_wvalid = 0;
    forever begin
        @(posedge aclk);
        if (s_wvalid && s_wready) begin w_list.pop_front(); s_wvalid = 0; end
        if (!s_wvalid && w_list.size() > 0 && ($urandom % 4 != 0)) begin
            s_wvalid = 1; s_wdata = w_list[0];
        end
        #0.1;
    end
end
// AR driver
initial begin
    s_arvalid = 0;
    forever begin
        @(posedge aclk);
        if (s_arvalid && s_arready) begin ar_list.pop_front(); s_arvalid = 0; end
        if (!s_arvalid && ar_list.size() > 0 && ($urandom % 3 != 0)) begin
            s_arvalid = 1; s_araddr = ar_list[0].addr; s_arlen = ar_list[0].len; s_arid = ar_list[0].id;
        end
        #0.1;
    end
end

// R checker (stripe returns in request order)
int rb = 0; int n_rbursts = 0;
always @(posedge aclk) if (aresetn && s_rvalid && s_rready) begin
    if (ar_exp.size() == 0) err("R beat with no read outstanding");
    else begin
        sreq_t e; longint a;
        e = ar_exp[0];
        a = e.addr + rb * BEAT;
        if (s_rdata !== ref_mem[a]) err($sformatf("read data mismatch at 0x%0h (burst 0x%0h len %0d beat %0d)", a, e.addr, e.len, rb));
        if (s_rid != e.id) err($sformatf("rid %0d, expected %0d", s_rid, e.id));
        if (s_rlast != (rb == e.len)) err($sformatf("rlast %0d at beat %0d of %0d", s_rlast, rb, e.len));
        if (rb == e.len) begin ar_exp.pop_front(); rb = 0; n_rbursts++; end
        else rb++;
    end
end

// B checker
int n_b = 0;
always @(posedge aclk) if (aresetn && s_bvalid && s_bready) begin
    if (b_exp.size() == 0) err("B with no write outstanding");
    else begin
        if (s_bid != b_exp[0].id) err($sformatf("bid %0d, expected %0d", s_bid, b_exp[0].id));
        if (s_bresp != 0) err("bresp not OKAY");
        for (int c = 0; c < NCH; c++) begin
            ch_b_need[c] += b_exp[0].parts[c];
            if (ch_b_done[c] < ch_b_need[c]) err($sformatf("B sent before channel %0d answered (%0d of %0d)", c, ch_b_done[c], ch_b_need[c]));
        end
        b_exp.pop_front(); n_b++;
    end
end

// Map a striped address to (channel, physical address), as the DUT should
function automatic void stripe_map(longint a, output int c, output longint p);
    longint lsb, msb;
    lsb = a & (STRIPE_FRAG_SIZE - 1);
    c = (a / STRIPE_FRAG_SIZE) % NCH;
    msb = (a / (STRIPE_FRAG_SIZE * NCH)) * STRIPE_FRAG_SIZE;
    p = msb | lsb;
endfunction

longint t0, wr_beats, rd_beats;
initial begin
    repeat (20) @(posedge aclk);
    aresetn = 1;
    repeat (100) @(posedge aclk);       // xpm reset busy

    for (int rnd = 0; rnd < ROUNDS; rnd++) begin
        // write phase
        wr_beats = 0;
        for (int i = 0; i < NBURSTS; i++) begin
            sreq_t r;
            r = rnd_burst();
            for (int c = 0; c < NCH; c++) r.parts[c] = 0;
            for (longint f = r.addr / STRIPE_FRAG_SIZE; f <= (r.addr + r.len * BEAT) / STRIPE_FRAG_SIZE; f++) r.parts[f % NCH]++;
            aw_list.push_back(r); b_exp.push_back(r);
            for (int b = 0; b <= r.len; b++) begin
                logic [AXI_DATA_BITS-1:0] w;
                w = rnd_word();
                w_list.push_back(w);
                ref_mem[r.addr + b * BEAT] = w;
            end
            wr_beats += r.len + 1;
        end
        t0 = cyc;
        fork
            begin wait (b_exp.size() == 0); end
            begin repeat (200000) @(posedge aclk); err("timeout in write phase"); end
        join_any
        disable fork;
        $display("round %0d: %0d write beats in %0d cycles", rnd, wr_beats, cyc - t0);

        // check physical placement of a few words
        for (int k = 0; k < 50; k++) begin
            longint a, p; int c;
            a = ($urandom % (SPACE / BEAT)) * BEAT;
            if (ref_mem.exists(a)) begin
                stripe_map(a, c, p);
                if (!ch_mem[c].exists(p) || ch_mem[c][p] !== ref_mem[a]) err($sformatf("placement of 0x%0h (ch %0d phys 0x%0h)", a, c, p));
            end
        end

        // read phase (only addresses written before)
        rd_beats = 0;
        for (int i = 0; i < NBURSTS; i++) begin
            sreq_t r; bit ok;
            ok = 0;
            while (!ok) begin
                r = rnd_burst(); ok = 1;
                for (int b = 0; b <= r.len; b++) if (!ref_mem.exists(r.addr + b * BEAT)) ok = 0;
            end
            ar_list.push_back(r); ar_exp.push_back(r);
            rd_beats += r.len + 1;
        end
        t0 = cyc;
        fork
            begin wait (ar_exp.size() == 0); end
            begin repeat (200000) @(posedge aclk); err("timeout in read phase"); end
        join_any
        disable fork;
        $display("round %0d: %0d read beats in %0d cycles", rnd, rd_beats, cyc - t0);
    end

    $display("max reads in flight per channel: %0d / %0d", max_rq[0], max_rq[1]);
    $display("bursts read %0d, writes acked %0d", n_rbursts, n_b);
    if (errors == 0) $display("PASS"); else $display("FAIL: %0d errors", errors);
    $finish;
end

endmodule
