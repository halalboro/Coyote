/*
 * Generic one-to-two AXI4-Lite address splitter for shell-resident control.
 *
 * The implementation deliberately permits only one outstanding read and one
 * outstanding write, but accepts AW and W independently as required by AXI4-Lite.
 */

`timescale 1ns / 1ps

import lynxTypes::*;

module axil_address_splitter #(
    parameter logic [AXI_ADDR_BITS-1:0] SHELL_BYTES = 4096,
    parameter logic [AXI_ADDR_BITS-1:0] SERVICE_BASE = 4096,
    parameter logic [AXI_ADDR_BITS-1:0] SERVICE_BYTES = 4096
) (
    input logic aclk,
    input logic aresetn,

    AXI4L.s s_axi,
    AXI4L.m m_axi_shell,
    AXI4L.m m_axi_service
);

    localparam logic [1:0] SELECT_SHELL   = 2'd0;
    localparam logic [1:0] SELECT_SERVICE = 2'd1;
    localparam logic [1:0] SELECT_INVALID = 2'd2;

    typedef enum logic [1:0] {
        WRITE_COLLECT,
        WRITE_SEND,
        WRITE_RESPONSE
    } write_state_t;

    typedef enum logic [1:0] {
        READ_COLLECT,
        READ_SEND,
        READ_RESPONSE
    } read_state_t;

    write_state_t write_state;
    read_state_t read_state;

    logic aw_held;
    logic w_held;
    logic aw_sent;
    logic w_sent;
    logic [1:0] write_select;
    logic [AXI_ADDR_BITS-1:0] write_addr;
    logic [2:0] write_prot;
    logic [AXIL_DATA_BITS-1:0] write_data;
    logic [AXIL_DATA_BITS/8-1:0] write_strb;

    logic [1:0] read_select;
    logic [AXI_ADDR_BITS-1:0] read_addr;
    logic [2:0] read_prot;

    function automatic logic [1:0] decode_address(
        input logic [AXI_ADDR_BITS-1:0] addr
    );
        if (addr < SHELL_BYTES) begin
            decode_address = SELECT_SHELL;
        end else if (addr >= SERVICE_BASE &&
                     addr < (SERVICE_BASE + SERVICE_BYTES)) begin
            decode_address = SELECT_SERVICE;
        end else begin
            decode_address = SELECT_INVALID;
        end
    endfunction

    function automatic logic [AXI_ADDR_BITS-1:0] rebase_address(
        input logic [AXI_ADDR_BITS-1:0] addr,
        input logic [1:0] select
    );
        if (select == SELECT_SERVICE) begin
            rebase_address = addr - SERVICE_BASE;
        end else begin
            rebase_address = addr;
        end
    endfunction

    always_comb begin
        s_axi.awready = 1'b0;
        s_axi.wready = 1'b0;
        s_axi.bresp = 2'b00;
        s_axi.bvalid = 1'b0;
        s_axi.arready = 1'b0;
        s_axi.rdata = '0;
        s_axi.rresp = 2'b00;
        s_axi.rvalid = 1'b0;

        m_axi_shell.awaddr = rebase_address(write_addr, write_select);
        m_axi_shell.awprot = write_prot;
        m_axi_shell.awqos = '0;
        m_axi_shell.awregion = '0;
        m_axi_shell.awvalid = 1'b0;
        m_axi_shell.wdata = write_data;
        m_axi_shell.wstrb = write_strb;
        m_axi_shell.wvalid = 1'b0;
        m_axi_shell.bready = 1'b0;
        m_axi_shell.araddr = rebase_address(read_addr, read_select);
        m_axi_shell.arprot = read_prot;
        m_axi_shell.arqos = '0;
        m_axi_shell.arregion = '0;
        m_axi_shell.arvalid = 1'b0;
        m_axi_shell.rready = 1'b0;

        m_axi_service.awaddr = rebase_address(write_addr, write_select);
        m_axi_service.awprot = write_prot;
        m_axi_service.awqos = '0;
        m_axi_service.awregion = '0;
        m_axi_service.awvalid = 1'b0;
        m_axi_service.wdata = write_data;
        m_axi_service.wstrb = write_strb;
        m_axi_service.wvalid = 1'b0;
        m_axi_service.bready = 1'b0;
        m_axi_service.araddr = rebase_address(read_addr, read_select);
        m_axi_service.arprot = read_prot;
        m_axi_service.arqos = '0;
        m_axi_service.arregion = '0;
        m_axi_service.arvalid = 1'b0;
        m_axi_service.rready = 1'b0;

        if (write_state == WRITE_COLLECT) begin
            s_axi.awready = !aw_held;
            s_axi.wready = !w_held;
        end else if (write_state == WRITE_SEND) begin
            if (write_select == SELECT_SHELL) begin
                m_axi_shell.awvalid = !aw_sent;
                m_axi_shell.wvalid = !w_sent;
            end else if (write_select == SELECT_SERVICE) begin
                m_axi_service.awvalid = !aw_sent;
                m_axi_service.wvalid = !w_sent;
            end
        end else begin
            if (write_select == SELECT_SHELL) begin
                s_axi.bresp = m_axi_shell.bresp;
                s_axi.bvalid = m_axi_shell.bvalid;
                m_axi_shell.bready = s_axi.bready;
            end else if (write_select == SELECT_SERVICE) begin
                s_axi.bresp = m_axi_service.bresp;
                s_axi.bvalid = m_axi_service.bvalid;
                m_axi_service.bready = s_axi.bready;
            end else begin
                s_axi.bresp = 2'b11; // DECERR
                s_axi.bvalid = 1'b1;
            end
        end

        if (read_state == READ_COLLECT) begin
            s_axi.arready = 1'b1;
        end else if (read_state == READ_SEND) begin
            if (read_select == SELECT_SHELL) begin
                m_axi_shell.arvalid = 1'b1;
            end else if (read_select == SELECT_SERVICE) begin
                m_axi_service.arvalid = 1'b1;
            end
        end else begin
            if (read_select == SELECT_SHELL) begin
                s_axi.rdata = m_axi_shell.rdata;
                s_axi.rresp = m_axi_shell.rresp;
                s_axi.rvalid = m_axi_shell.rvalid;
                m_axi_shell.rready = s_axi.rready;
            end else if (read_select == SELECT_SERVICE) begin
                s_axi.rdata = m_axi_service.rdata;
                s_axi.rresp = m_axi_service.rresp;
                s_axi.rvalid = m_axi_service.rvalid;
                m_axi_service.rready = s_axi.rready;
            end else begin
                s_axi.rdata = '0;
                s_axi.rresp = 2'b11; // DECERR
                s_axi.rvalid = 1'b1;
            end
        end
    end

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            write_state <= WRITE_COLLECT;
            read_state <= READ_COLLECT;
            aw_held <= 1'b0;
            w_held <= 1'b0;
            aw_sent <= 1'b0;
            w_sent <= 1'b0;
            write_select <= SELECT_INVALID;
            write_addr <= '0;
            write_prot <= '0;
            write_data <= '0;
            write_strb <= '0;
            read_select <= SELECT_INVALID;
            read_addr <= '0;
            read_prot <= '0;
        end else begin
            case (write_state)
                WRITE_COLLECT: begin
                    if (s_axi.awvalid && s_axi.awready) begin
                        aw_held <= 1'b1;
                        write_select <= decode_address(s_axi.awaddr);
                        write_addr <= s_axi.awaddr;
                        write_prot <= s_axi.awprot;
                    end
                    if (s_axi.wvalid && s_axi.wready) begin
                        w_held <= 1'b1;
                        write_data <= s_axi.wdata;
                        write_strb <= s_axi.wstrb;
                    end
                    if ((aw_held || (s_axi.awvalid && s_axi.awready)) &&
                        (w_held || (s_axi.wvalid && s_axi.wready))) begin
                        write_state <= WRITE_SEND;
                        aw_sent <= 1'b0;
                        w_sent <= 1'b0;
                    end
                end

                WRITE_SEND: begin
                    if (write_select == SELECT_INVALID) begin
                        write_state <= WRITE_RESPONSE;
                    end else begin
                        if (!aw_sent &&
                            ((write_select == SELECT_SHELL && m_axi_shell.awready) ||
                             (write_select == SELECT_SERVICE && m_axi_service.awready))) begin
                            aw_sent <= 1'b1;
                        end
                        if (!w_sent &&
                            ((write_select == SELECT_SHELL && m_axi_shell.wready) ||
                             (write_select == SELECT_SERVICE && m_axi_service.wready))) begin
                            w_sent <= 1'b1;
                        end
                        if ((aw_sent ||
                             (write_select == SELECT_SHELL && m_axi_shell.awready) ||
                             (write_select == SELECT_SERVICE && m_axi_service.awready)) &&
                            (w_sent ||
                             (write_select == SELECT_SHELL && m_axi_shell.wready) ||
                             (write_select == SELECT_SERVICE && m_axi_service.wready))) begin
                            write_state <= WRITE_RESPONSE;
                        end
                    end
                end

                WRITE_RESPONSE: begin
                    if (s_axi.bvalid && s_axi.bready) begin
                        write_state <= WRITE_COLLECT;
                        aw_held <= 1'b0;
                        w_held <= 1'b0;
                    end
                end

                default: write_state <= WRITE_COLLECT;
            endcase

            case (read_state)
                READ_COLLECT: begin
                    if (s_axi.arvalid && s_axi.arready) begin
                        read_select <= decode_address(s_axi.araddr);
                        read_addr <= s_axi.araddr;
                        read_prot <= s_axi.arprot;
                        read_state <= READ_SEND;
                    end
                end

                READ_SEND: begin
                    if (read_select == SELECT_INVALID ||
                        (read_select == SELECT_SHELL && m_axi_shell.arready) ||
                        (read_select == SELECT_SERVICE && m_axi_service.arready)) begin
                        read_state <= READ_RESPONSE;
                    end
                end

                READ_RESPONSE: begin
                    if (s_axi.rvalid && s_axi.rready) begin
                        read_state <= READ_COLLECT;
                    end
                end

                default: read_state <= READ_COLLECT;
            endcase
        end
    end

endmodule
