`timescale 1ns / 1ps

module coprocessor_control_target #(
    parameter integer AXIL_ADDR_BITS = 12,
    parameter logic [15:0] ENDPOINT_ID = 16'd1,
    parameter logic [15:0] STREAM_ABI = 16'd1,
    parameter logic [15:0] MMIO_ABI = 16'd1
) (
    input logic aclk,
    input logic aresetn,
    input logic provider_available,
    input logic provider_healthy,
    input logic provider_idle,
    input logic provider_fault,
    input logic [31:0] provider_generation,
    input logic [15:0] firmware_runtime_abi,
    input logic [15:0] firmware_abi_id,
    input logic [255:0] firmware_image_identity,
    input logic [2:0] binding_state,
    input logic [15:0] binding_endpoint,
    input logic [31:0] binding_generation,
    input logic streams_idle,
    input logic mmio_idle,
    input logic stale_response_fault,

    output logic command_valid,
    input logic command_ready,
    output logic [2:0] command_opcode,
    output logic [15:0] command_endpoint,
    output logic [31:0] command_binding_generation,
    output logic [31:0] command_endpoint_generation,
    input logic response_valid,
    output logic response_ready,
    input logic [3:0] response_result,
    output logic management_recover,

    input logic [AXIL_ADDR_BITS-1:0] s_axi_awaddr,
    input logic [2:0] s_axi_awprot,
    input logic s_axi_awvalid,
    output logic s_axi_awready,
    input logic [63:0] s_axi_wdata,
    input logic [7:0] s_axi_wstrb,
    input logic s_axi_wvalid,
    output logic s_axi_wready,
    output logic [1:0] s_axi_bresp,
    output logic s_axi_bvalid,
    input logic s_axi_bready,
    input logic [AXIL_ADDR_BITS-1:0] s_axi_araddr,
    input logic [2:0] s_axi_arprot,
    input logic s_axi_arvalid,
    output logic s_axi_arready,
    output logic [63:0] s_axi_rdata,
    output logic [1:0] s_axi_rresp,
    output logic s_axi_rvalid,
    input logic s_axi_rready
);
    localparam logic [31:0] MAGIC = 32'h54435043;
    localparam logic [1:0] OKAY = 2'b00;
    localparam logic [1:0] SLVERR = 2'b10;
    localparam logic [1:0] DECERR = 2'b11;

    logic aw_held;
    logic [AXIL_ADDR_BITS-1:0] held_awaddr;
    logic w_held;
    logic [63:0] held_wdata;
    logic [7:0] held_wstrb;
    logic command_inflight;
    logic response_done;
    logic [31:0] command_token;
    logic [31:0] completion_token;
    logic [3:0] completion_result;

    always_comb begin
        s_axi_awready = !aw_held && !s_axi_bvalid;
        s_axi_wready = !w_held && !s_axi_bvalid;
        s_axi_arready = !s_axi_rvalid;
        response_ready = command_inflight && !command_valid && !response_done;
    end

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            aw_held <= 1'b0;
            held_awaddr <= '0;
            w_held <= 1'b0;
            held_wdata <= '0;
            held_wstrb <= '0;
            s_axi_bresp <= OKAY;
            s_axi_bvalid <= 1'b0;
            s_axi_rdata <= '0;
            s_axi_rresp <= OKAY;
            s_axi_rvalid <= 1'b0;
            command_valid <= 1'b0;
            command_opcode <= '0;
            command_endpoint <= '0;
            command_binding_generation <= '0;
            command_endpoint_generation <= '0;
            command_inflight <= 1'b0;
            response_done <= 1'b0;
            command_token <= 32'd1;
            completion_token <= '0;
            completion_result <= '0;
            management_recover <= 1'b0;
        end else begin
            management_recover <= 1'b0;
            if (s_axi_bvalid && s_axi_bready) s_axi_bvalid <= 1'b0;
            if (s_axi_rvalid && s_axi_rready) s_axi_rvalid <= 1'b0;
            if (command_valid && command_ready) command_valid <= 1'b0;

            if (s_axi_awvalid && s_axi_awready) begin
                aw_held <= 1'b1;
                held_awaddr <= s_axi_awaddr;
            end
            if (s_axi_wvalid && s_axi_wready) begin
                w_held <= 1'b1;
                held_wdata <= s_axi_wdata;
                held_wstrb <= s_axi_wstrb;
            end
            if (aw_held && w_held && !s_axi_bvalid) begin
                aw_held <= 1'b0;
                w_held <= 1'b0;
                s_axi_bvalid <= 1'b1;
                s_axi_bresp <= OKAY;
                if (held_wstrb != 8'hff) begin
                    s_axi_bresp <= SLVERR;
                end else begin
                    case (held_awaddr)
                        12'h028: begin
                            if (!command_inflight && !response_done) begin
                                command_opcode <= held_wdata[2:0];
                                command_endpoint <= held_wdata[31:16];
                            end else s_axi_bresp <= SLVERR;
                        end
                        12'h030: begin
                            if (!command_inflight && !response_done)
                                command_binding_generation <= held_wdata[31:0];
                            else s_axi_bresp <= SLVERR;
                        end
                        12'h038: begin
                            if (!command_inflight && !response_done)
                                command_endpoint_generation <= held_wdata[31:0];
                            else s_axi_bresp <= SLVERR;
                        end
                        12'h040: begin
                            if (held_wdata[31:0] != command_token || command_inflight || response_done) begin
                                s_axi_bresp <= SLVERR;
                            end else begin
                                command_valid <= 1'b1;
                                command_inflight <= 1'b1;
                            end
                        end
                        12'h050: begin
                            if (!response_done || held_wdata[31:0] != completion_token) begin
                                s_axi_bresp <= SLVERR;
                            end else begin
                                response_done <= 1'b0;
                                if (&command_token) begin
                                    s_axi_bresp <= SLVERR;
                                end else begin
                                    command_token <= command_token + 1'b1;
                                end
                            end
                        end
                        default: s_axi_bresp <= DECERR;
                    endcase
                end
            end

            if (response_valid && response_ready) begin
                command_inflight <= 1'b0;
                response_done <= 1'b1;
                completion_token <= command_token;
                completion_result <= response_result;
                if (command_opcode == 3'd4 && response_result == 4'd0)
                    management_recover <= 1'b1;
            end

            if (s_axi_arvalid && s_axi_arready) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rresp <= OKAY;
                s_axi_rdata <= '0;
                case (s_axi_araddr)
                    12'h000: s_axi_rdata <= {32'h0001_0000, MAGIC};
                    12'h008: s_axi_rdata <= {ENDPOINT_ID, STREAM_ABI, MMIO_ABI,
                                              12'd0, provider_fault, provider_idle,
                                              provider_healthy, provider_available};
                    12'h010: s_axi_rdata <= provider_generation;
                    12'h018: s_axi_rdata <= {32'd0, binding_endpoint, 13'd0, binding_state};
                    12'h020: s_axi_rdata <= binding_generation;
                    12'h040: s_axi_rdata <= command_token;
                    12'h048: s_axi_rdata <= {completion_token, 22'd0, stale_response_fault,
                                              mmio_idle, streams_idle, command_valid,
                                              response_done, command_inflight,
                                              completion_result};
                    12'h058: s_axi_rdata <= {32'd0, firmware_runtime_abi, firmware_abi_id};
                    12'h060: s_axi_rdata <= firmware_image_identity[63:0];
                    12'h068: s_axi_rdata <= firmware_image_identity[127:64];
                    12'h070: s_axi_rdata <= firmware_image_identity[191:128];
                    12'h078: s_axi_rdata <= firmware_image_identity[255:192];
                    default: begin s_axi_rresp <= DECERR; s_axi_rdata <= '0; end
                endcase
            end
        end
    end

`ifndef SYNTHESIS
    property stable_command;
        @(posedge aclk) disable iff (!aresetn)
        command_valid && !command_ready |=> command_valid &&
            $stable({command_opcode, command_endpoint, command_binding_generation,
                     command_endpoint_generation});
    endproperty
    assert property(stable_command);
`endif
endmodule
