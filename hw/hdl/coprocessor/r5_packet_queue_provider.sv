`timescale 1ns / 1ps

module r5_packet_queue_provider #(
    parameter integer AXIL_ADDR_BITS = 16,
    parameter integer STREAM_DATA_BITS = 512,
    parameter integer STREAM_ID_BITS = 6,
    parameter integer GENERATION_BITS = 32,
    parameter integer QUEUE_DEPTH = 4,
    parameter integer MAX_PACKET_BEATS = 64,
    parameter integer MMIO_ADDR_BITS = 12,
    parameter integer MMIO_DATA_BITS = 64,
    parameter integer MMIO_TIMEOUT_CYCLES = 1024,
    parameter logic [15:0] EXPECTED_FIRMWARE_ABI = 16'd1
) (
    input  logic aclk,
    input  logic aresetn,

    input  logic provider_selected,
    input  logic provider_quiesce,
    input  logic provider_abort,
    input  logic management_recover,
    input  logic [GENERATION_BITS-1:0] active_generation,
    output logic provider_available,
    output logic provider_healthy,
    output logic provider_idle,
    output logic provider_fault,
    output logic [GENERATION_BITS-1:0] endpoint_generation,
    output logic [15:0] firmware_runtime_abi,
    output logic [15:0] firmware_abi_id,
    output logic [255:0] firmware_image_identity,

    input  logic [AXIL_ADDR_BITS-1:0] s_axi_awaddr,
    input  logic [2:0]                s_axi_awprot,
    input  logic                      s_axi_awvalid,
    output logic                      s_axi_awready,
    input  logic [31:0]               s_axi_wdata,
    input  logic [3:0]                s_axi_wstrb,
    input  logic                      s_axi_wvalid,
    output logic                      s_axi_wready,
    output logic [1:0]                s_axi_bresp,
    output logic                      s_axi_bvalid,
    input  logic                      s_axi_bready,
    input  logic [AXIL_ADDR_BITS-1:0] s_axi_araddr,
    input  logic [2:0]                s_axi_arprot,
    input  logic                      s_axi_arvalid,
    output logic                      s_axi_arready,
    output logic [31:0]               s_axi_rdata,
    output logic [1:0]                s_axi_rresp,
    output logic                      s_axi_rvalid,
    input  logic                      s_axi_rready,

    input  logic [STREAM_DATA_BITS-1:0]   s_axis_request_tdata,
    input  logic [STREAM_DATA_BITS/8-1:0] s_axis_request_tkeep,
    input  logic [STREAM_ID_BITS-1:0]     s_axis_request_tid,
    input  logic                          s_axis_request_tlast,
    input  logic                          s_axis_request_tvalid,
    output logic                          s_axis_request_tready,
    input  logic [GENERATION_BITS-1:0]    s_axis_request_generation,

    output logic [STREAM_DATA_BITS-1:0]   m_axis_response_tdata,
    output logic [STREAM_DATA_BITS/8-1:0] m_axis_response_tkeep,
    output logic [STREAM_ID_BITS-1:0]     m_axis_response_tid,
    output logic                          m_axis_response_tlast,
    output logic                          m_axis_response_tvalid,
    input  logic                          m_axis_response_tready,
    output logic [GENERATION_BITS-1:0]    m_axis_response_generation,

    output logic [GENERATION_BITS-1:0] provider_mmio_generation,
    output logic [MMIO_ADDR_BITS-1:0]  provider_mmio_awaddr,
    output logic [2:0]                 provider_mmio_awprot,
    output logic                       provider_mmio_awvalid,
    input  logic                       provider_mmio_awready,
    output logic [MMIO_DATA_BITS-1:0]  provider_mmio_wdata,
    output logic [MMIO_DATA_BITS/8-1:0] provider_mmio_wstrb,
    output logic                       provider_mmio_wvalid,
    input  logic                       provider_mmio_wready,
    input  logic [1:0]                 provider_mmio_bresp,
    input  logic                       provider_mmio_bvalid,
    output logic                       provider_mmio_bready,
    output logic [MMIO_ADDR_BITS-1:0]  provider_mmio_araddr,
    output logic [2:0]                 provider_mmio_arprot,
    output logic                       provider_mmio_arvalid,
    input  logic                       provider_mmio_arready,
    input  logic [MMIO_DATA_BITS-1:0]  provider_mmio_rdata,
    input  logic [1:0]                 provider_mmio_rresp,
    input  logic                       provider_mmio_rvalid,
    output logic                       provider_mmio_rready
);

    localparam integer KEEP_BITS = STREAM_DATA_BITS / 8;
    localparam integer DATA_WORDS = STREAM_DATA_BITS / 32;
    localparam integer KEEP_WORDS = (KEEP_BITS + 31) / 32;
    localparam integer SLOT_BITS = QUEUE_DEPTH <= 1 ? 1 : $clog2(QUEUE_DEPTH);
    localparam integer BEAT_BITS = MAX_PACKET_BEATS <= 1 ? 1 : $clog2(MAX_PACKET_BEATS);
    localparam integer COUNT_BITS = $clog2(QUEUE_DEPTH + 1);
    localparam integer PACKET_BEAT_COUNT_BITS = $clog2(MAX_PACKET_BEATS + 1);
    localparam integer MMIO_TIMEOUT_BITS = MMIO_TIMEOUT_CYCLES <= 1 ? 1 : $clog2(MMIO_TIMEOUT_CYCLES + 1);

    localparam logic [31:0] PROTOCOL_MAGIC = 32'h31514c50;
    localparam logic [31:0] PROTOCOL_VERSION = 32'h0001_0000;
    localparam logic [31:0] IDENTITY_COMMIT_MAGIC = 32'h4944454e;

    localparam logic [1:0] AXI_OKAY = 2'b00;
    localparam logic [1:0] AXI_SLVERR = 2'b10;
    localparam logic [1:0] AXI_DECERR = 2'b11;

    localparam logic [7:0] CMD_NONE = 8'd0;
    localparam logic [7:0] CMD_GENERATION = 8'd1;
    localparam logic [7:0] CMD_IDENTITY = 8'd2;
    localparam logic [7:0] CMD_RX_POP = 8'd3;
    localparam logic [7:0] CMD_TX_COMMIT = 8'd4;
    localparam logic [7:0] CMD_TX_CANCEL = 8'd5;
    localparam logic [7:0] CMD_QUIESCE_ACK = 8'd6;
    localparam logic [7:0] CMD_FAULT = 8'd7;
    localparam logic [7:0] CMD_MMIO_SUBMIT = 8'd8;
    localparam logic [7:0] CMD_MMIO_ACK = 8'd9;
    localparam logic [7:0] CMD_TX_STAGE = 8'd10;

    localparam logic [7:0] RESULT_OK = 8'd0;
    localparam logic [7:0] RESULT_EMPTY = 8'd1;
    localparam logic [7:0] RESULT_FULL = 8'd2;
    localparam logic [7:0] RESULT_BAD_TOKEN = 8'd3;
    localparam logic [7:0] RESULT_STALE_GENERATION = 8'd4;
    localparam logic [7:0] RESULT_BAD_LENGTH = 8'd5;
    localparam logic [7:0] RESULT_BAD_KEEP = 8'd6;
    localparam logic [7:0] RESULT_BAD_LAST = 8'd7;
    localparam logic [7:0] RESULT_INCOMPLETE = 8'd8;
    localparam logic [7:0] RESULT_QUIESCING = 8'd9;
    localparam logic [7:0] RESULT_NOT_READY = 8'd10;
    localparam logic [7:0] RESULT_BUSY = 8'd11;
    localparam logic [7:0] RESULT_ABORTED = 8'd12;
    localparam logic [7:0] RESULT_TIMEOUT = 8'd13;
    localparam logic [7:0] RESULT_AXI_SLVERR = 8'd14;
    localparam logic [7:0] RESULT_AXI_DECERR = 8'd15;
    localparam logic [7:0] RESULT_BAD_ACCESS = 8'd16;
    localparam logic [7:0] RESULT_FIRMWARE_ID = 8'd17;
    localparam logic [7:0] RESULT_FAULTED = 8'd18;

    localparam logic [15:0] REG_MAGIC = 16'h0000;
    localparam logic [15:0] REG_VERSION = 16'h0004;
    localparam logic [15:0] REG_STREAM_SHAPE = 16'h0008;
    localparam logic [15:0] REG_QUEUE_SHAPE = 16'h000c;
    localparam logic [15:0] REG_STATUS = 16'h0010;
    localparam logic [15:0] REG_ACTIVE_GENERATION = 16'h0014;
    localparam logic [15:0] REG_ENDPOINT_GENERATION = 16'h0018;
    localparam logic [15:0] REG_COMMAND_GENERATION = 16'h001c;
    localparam logic [15:0] REG_LAST_COMMAND = 16'h0020;
    localparam logic [15:0] REG_LAST_TOKEN = 16'h0024;
    localparam logic [15:0] REG_FAULT = 16'h0028;
    localparam logic [15:0] REG_FAULT_DETAIL = 16'h002c;
    localparam logic [15:0] REG_QUIESCE_ACK = 16'h0030;
    localparam logic [15:0] REG_FIRMWARE_STATE = 16'h0034;
    localparam logic [15:0] REG_PROTOCOL_ERRORS = 16'h003c;
    localparam logic [15:0] REG_RUNTIME_ABI = 16'h0040;
    localparam logic [15:0] REG_FIRMWARE_ABI = 16'h0044;
    localparam logic [15:0] REG_IDENTITY_BASE = 16'h0048;
    localparam logic [15:0] REG_IDENTITY_COMMIT = 16'h0068;
    localparam logic [15:0] REG_IDENTITY_STATE = 16'h006c;

    localparam logic [15:0] REG_RX_STATUS = 16'h0100;
    localparam logic [15:0] REG_RX_TOKEN = 16'h0104;
    localparam logic [15:0] REG_RX_GENERATION = 16'h0108;
    localparam logic [15:0] REG_RX_BEATS = 16'h010c;
    localparam logic [15:0] REG_RX_BYTES = 16'h0110;
    localparam logic [15:0] REG_RX_POP = 16'h0114;
    localparam logic [15:0] REG_RX_DROPPED = 16'h0118;
    localparam logic [15:0] REG_RX_MALFORMED = 16'h011c;

    localparam logic [15:0] REG_TX_STATUS = 16'h0140;
    localparam logic [15:0] REG_TX_TOKEN = 16'h0144;
    localparam logic [15:0] REG_TX_BEATS = 16'h0148;
    localparam logic [15:0] REG_TX_COMMIT = 16'h014c;
    localparam logic [15:0] REG_TX_CANCEL = 16'h0150;
    localparam logic [15:0] REG_TX_REJECTED = 16'h0154;

    localparam logic [15:0] REG_MMIO_STATUS = 16'h0180;
    localparam logic [15:0] REG_MMIO_TOKEN = 16'h0184;
    localparam logic [15:0] REG_MMIO_ADDRESS = 16'h0188;
    localparam logic [15:0] REG_MMIO_WRITE_LO = 16'h018c;
    localparam logic [15:0] REG_MMIO_WRITE_HI = 16'h0190;
    localparam logic [15:0] REG_MMIO_OPERATION = 16'h0194;
    localparam logic [15:0] REG_MMIO_SUBMIT = 16'h0198;
    localparam logic [15:0] REG_MMIO_COMPLETION = 16'h019c;
    localparam logic [15:0] REG_MMIO_READ_LO = 16'h01a0;
    localparam logic [15:0] REG_MMIO_READ_HI = 16'h01a4;
    localparam logic [15:0] REG_MMIO_RESULT = 16'h01a8;
    localparam logic [15:0] REG_MMIO_ACK = 16'h01ac;

    localparam logic [15:0] RX_DATA_BASE = 16'h1000;
    localparam logic [15:0] RX_KEEP_BASE = 16'h2000;
    localparam logic [15:0] RX_ATTR_BASE = 16'h2200;
    localparam logic [15:0] TX_DATA_BASE = 16'h3000;
    localparam logic [15:0] TX_KEEP_BASE = 16'h4000;
    localparam logic [15:0] TX_ATTR_BASE = 16'h4200;

    logic [STREAM_DATA_BITS-1:0] rx_data [0:QUEUE_DEPTH-1][0:MAX_PACKET_BEATS-1];
    logic [KEEP_BITS-1:0] rx_keep [0:QUEUE_DEPTH-1][0:MAX_PACKET_BEATS-1];
    logic [STREAM_ID_BITS-1:0] rx_id [0:QUEUE_DEPTH-1][0:MAX_PACKET_BEATS-1];
    logic rx_last [0:QUEUE_DEPTH-1][0:MAX_PACKET_BEATS-1];
    logic [GENERATION_BITS-1:0] rx_generation [0:QUEUE_DEPTH-1];
    logic [31:0] rx_token [0:QUEUE_DEPTH-1];
    logic [PACKET_BEAT_COUNT_BITS-1:0] rx_beats [0:QUEUE_DEPTH-1];
    logic [12:0] rx_bytes [0:QUEUE_DEPTH-1];

    logic [STREAM_DATA_BITS-1:0] tx_data [0:QUEUE_DEPTH-1][0:MAX_PACKET_BEATS-1];
    logic [KEEP_BITS-1:0] tx_keep [0:QUEUE_DEPTH-1][0:MAX_PACKET_BEATS-1];
    logic [STREAM_ID_BITS-1:0] tx_id [0:QUEUE_DEPTH-1][0:MAX_PACKET_BEATS-1];
    logic tx_last [0:QUEUE_DEPTH-1][0:MAX_PACKET_BEATS-1];
    logic [GENERATION_BITS-1:0] tx_generation [0:QUEUE_DEPTH-1];

    logic [DATA_WORDS-1:0] tx_data_written [0:MAX_PACKET_BEATS-1];
    logic [KEEP_WORDS-1:0] tx_keep_written [0:MAX_PACKET_BEATS-1];
    logic tx_attr_written [0:MAX_PACKET_BEATS-1];

    logic [SLOT_BITS-1:0] rx_head;
    logic [SLOT_BITS-1:0] rx_tail;
    logic [COUNT_BITS-1:0] rx_count;
    logic [SLOT_BITS-1:0] tx_head;
    logic [SLOT_BITS-1:0] tx_tail;
    logic [COUNT_BITS-1:0] tx_count;
    logic [BEAT_BITS-1:0] tx_output_beat;
    logic tx_output_valid;
    logic [STREAM_DATA_BITS-1:0] tx_output_data;
    logic [KEEP_BITS-1:0] tx_output_keep;
    logic [STREAM_ID_BITS-1:0] tx_output_id;
    logic tx_output_last;
    logic [GENERATION_BITS-1:0] tx_output_generation;
    logic [PACKET_BEAT_COUNT_BITS-1:0] tx_stage_beats;
    logic tx_stage_dirty;

    logic rx_packet_open;
    logic [BEAT_BITS-1:0] rx_input_beat;
    logic [31:0] next_rx_token;
    logic [31:0] tx_stage_token;

    logic identity_valid;
    logic [15:0] runtime_abi;
    logic [15:0] firmware_abi;
    logic [31:0] firmware_identity [0:7];
    logic firmware_identity_nonzero;
    logic firmware_idle;
    logic quiesce_acknowledged;
    logic abort_seen;
    logic [31:0] command_generation;
    logic [31:0] fault_code;
    logic [31:0] fault_detail;
    logic [31:0] protocol_errors;
    logic [31:0] rx_dropped;
    logic [31:0] rx_malformed;
    logic [31:0] tx_rejected;
    logic [15:0] command_serial;
    logic [7:0] last_command_opcode;
    logic [7:0] last_command_result;
    logic [31:0] last_command_token;
    logic [31:0] transport_epoch;
    logic provider_selected_d;
    logic [GENERATION_BITS-1:0] active_generation_d;
    logic abort_latched;

    logic aw_held;
    logic [AXIL_ADDR_BITS-1:0] held_awaddr;
    logic [2:0] held_awprot;
    logic [31:0] held_aw_epoch;
    logic w_held;
    logic [31:0] held_wdata;
    logic [3:0] held_wstrb;
    logic [31:0] held_w_epoch;
    logic read_pending;
    logic [AXIL_ADDR_BITS-1:0] held_araddr;
    logic [2:0] held_arprot;
    logic [31:0] held_ar_epoch;

    logic [MMIO_ADDR_BITS-1:0] mmio_address;
    logic [MMIO_DATA_BITS-1:0] mmio_write_data;
    logic [7:0] mmio_write_strobe;
    logic mmio_operation_write;
    logic [31:0] mmio_token;
    logic [31:0] mmio_completion_token;
    logic [MMIO_DATA_BITS-1:0] mmio_read_data_reg;
    logic [7:0] mmio_result;
    logic mmio_busy;
    logic mmio_done;
    logic mmio_aw_sent;
    logic mmio_w_sent;
    logic mmio_ar_sent;
    logic [MMIO_TIMEOUT_BITS-1:0] mmio_timeout_count;

    logic write_execute;
    logic write_epoch_valid;
    logic [15:0] write_address;
    logic [7:0] write_opcode;
    logic [7:0] write_result;
    logic [1:0] write_bus_response;
    logic write_known;
    logic rx_pop_success;
    logic tx_commit_success;
    logic tx_cancel_success;
    logic identity_publish_success;
    logic generation_ack_success;
    logic quiesce_ack_success;
    logic mmio_submit_success;
    logic mmio_ack_success;

    logic rx_handshake;
    logic rx_keep_valid;
    logic rx_generation_valid;
    logic rx_malformed_event;
    logic rx_push_event;
    logic tx_pop_event;
    logic mmio_timeout_event;

    function automatic logic final_keep_valid(input logic [KEEP_BITS-1:0] keep);
        logic [KEEP_BITS-1:0] incremented;
        begin
            incremented = keep + 1'b1;
            final_keep_valid = keep != '0 && (keep & incremented) == '0;
        end
    endfunction

    function automatic [12:0] keep_byte_count(input logic [KEEP_BITS-1:0] keep);
        integer index;
        begin
            keep_byte_count = '0;
            for (index = 0; index < KEEP_BITS; index = index + 1) begin
                keep_byte_count = keep_byte_count + keep[index];
            end
        end
    endfunction

    function automatic [SLOT_BITS-1:0] next_slot(input logic [SLOT_BITS-1:0] slot);
        begin
            if (slot == QUEUE_DEPTH - 1) begin
                next_slot = '0;
            end else begin
                next_slot = slot + 1'b1;
            end
        end
    endfunction

    function automatic logic tx_stage_packet_valid;
        integer beat_index;
        begin
            tx_stage_packet_valid = tx_stage_beats > 0 && tx_stage_beats <= MAX_PACKET_BEATS;
            for (beat_index = 0; beat_index < MAX_PACKET_BEATS; beat_index = beat_index + 1) begin
                if (beat_index < tx_stage_beats) begin
                    tx_stage_packet_valid = tx_stage_packet_valid && (&tx_data_written[beat_index]) &&
                                            (&tx_keep_written[beat_index]) && tx_attr_written[beat_index];
                    if (beat_index + 1 < tx_stage_beats) begin
                        tx_stage_packet_valid = tx_stage_packet_valid &&
                                                (tx_keep[tx_tail][beat_index] == {KEEP_BITS{1'b1}}) &&
                                                !tx_last[tx_tail][beat_index];
                    end else begin
                        tx_stage_packet_valid = tx_stage_packet_valid &&
                                                final_keep_valid(tx_keep[tx_tail][beat_index]) &&
                                                tx_last[tx_tail][beat_index];
                    end
                end
            end
        end
    endfunction

    function automatic logic generation_ready;
        begin
            generation_ready = provider_selected && identity_valid && fault_code == 0 &&
                               !provider_abort && !abort_seen && active_generation != '0 &&
                               command_generation == active_generation;
        end
    endfunction

    function automatic [31:0] saturating_increment(input logic [31:0] value);
        begin
            saturating_increment = (&value) ? value : value + 1'b1;
        end
    endfunction

    always_comb begin
        s_axi_awready = !aw_held && !s_axi_bvalid;
        s_axi_wready = !w_held && !s_axi_bvalid;
        s_axi_arready = !read_pending && !s_axi_rvalid;
        write_execute = aw_held && w_held && !s_axi_bvalid;
        write_epoch_valid = held_aw_epoch == held_w_epoch && held_aw_epoch == transport_epoch;
        write_address = held_awaddr[15:0];

        write_opcode = CMD_NONE;
        write_result = RESULT_OK;
        write_bus_response = AXI_OKAY;
        write_known = 1'b1;
        rx_pop_success = 1'b0;
        tx_commit_success = 1'b0;
        tx_cancel_success = 1'b0;
        identity_publish_success = 1'b0;
        generation_ack_success = 1'b0;
        quiesce_ack_success = 1'b0;
        mmio_submit_success = 1'b0;
        mmio_ack_success = 1'b0;

        if (!write_epoch_valid) begin
            write_bus_response = AXI_SLVERR;
            write_result = RESULT_ABORTED;
        end else if (held_wstrb != 4'hf) begin
            write_bus_response = AXI_SLVERR;
            write_result = RESULT_BAD_ACCESS;
        end else if (write_address >= TX_DATA_BASE && write_address < TX_DATA_BASE + 16'h1000) begin
            write_opcode = CMD_TX_STAGE;
            if (!generation_ready() || quiesce_acknowledged) begin
                write_result = provider_fault ? RESULT_FAULTED :
                               (quiesce_acknowledged ? RESULT_QUIESCING : RESULT_STALE_GENERATION);
            end else if (tx_count == QUEUE_DEPTH) begin
                write_result = RESULT_FULL;
            end
        end else if (write_address >= TX_KEEP_BASE && write_address < TX_KEEP_BASE + 16'h0200) begin
            write_opcode = CMD_TX_STAGE;
            if (!generation_ready() || quiesce_acknowledged) begin
                write_result = provider_fault ? RESULT_FAULTED :
                               (quiesce_acknowledged ? RESULT_QUIESCING : RESULT_STALE_GENERATION);
            end else if (tx_count == QUEUE_DEPTH) begin
                write_result = RESULT_FULL;
            end
        end else if (write_address >= TX_ATTR_BASE && write_address < TX_ATTR_BASE + 16'h0100) begin
            write_opcode = CMD_TX_STAGE;
            if (!generation_ready() || quiesce_acknowledged) begin
                write_result = provider_fault ? RESULT_FAULTED :
                               (quiesce_acknowledged ? RESULT_QUIESCING : RESULT_STALE_GENERATION);
            end else if (tx_count == QUEUE_DEPTH) begin
                write_result = RESULT_FULL;
            end
        end else begin
            case (write_address)
                REG_COMMAND_GENERATION: begin
                    write_opcode = CMD_GENERATION;
                    if (!provider_selected || !provider_available || provider_fault ||
                        provider_abort || held_wdata == 0 || held_wdata != active_generation) begin
                        write_result = RESULT_STALE_GENERATION;
                    end else begin
                        generation_ack_success = 1'b1;
                    end
                end
                REG_RUNTIME_ABI, REG_FIRMWARE_ABI,
                REG_IDENTITY_BASE, REG_IDENTITY_BASE + 4, REG_IDENTITY_BASE + 8,
                REG_IDENTITY_BASE + 12, REG_IDENTITY_BASE + 16, REG_IDENTITY_BASE + 20,
                REG_IDENTITY_BASE + 24, REG_IDENTITY_BASE + 28: begin
                    if (identity_valid || provider_selected) begin
                        write_result = RESULT_NOT_READY;
                    end
                end
                REG_IDENTITY_COMMIT: begin
                    write_opcode = CMD_IDENTITY;
                    if (held_wdata != IDENTITY_COMMIT_MAGIC || identity_valid || provider_selected ||
                        rx_count != 0 || tx_count != 0 || tx_stage_dirty || mmio_busy ||
                        runtime_abi == 0 || firmware_abi != EXPECTED_FIRMWARE_ABI ||
                        !firmware_identity_nonzero || (&endpoint_generation)) begin
                        write_result = RESULT_FIRMWARE_ID;
                    end else begin
                        identity_publish_success = 1'b1;
                    end
                end
                REG_RX_POP: begin
                    write_opcode = CMD_RX_POP;
                    if (!generation_ready()) begin
                        write_result = RESULT_STALE_GENERATION;
                    end else if (rx_count == 0) begin
                        write_result = RESULT_EMPTY;
                    end else if (held_wdata != rx_token[rx_head]) begin
                        write_result = RESULT_BAD_TOKEN;
                    end else begin
                        rx_pop_success = 1'b1;
                    end
                end
                REG_TX_BEATS: begin
                    write_opcode = CMD_TX_STAGE;
                    if (!generation_ready() || quiesce_acknowledged) begin
                        write_result = quiesce_acknowledged ? RESULT_QUIESCING : RESULT_STALE_GENERATION;
                    end else if (tx_count == QUEUE_DEPTH) begin
                        write_result = RESULT_FULL;
                    end else if (held_wdata == 0 || held_wdata > MAX_PACKET_BEATS) begin
                        write_result = RESULT_BAD_LENGTH;
                    end
                end
                REG_TX_COMMIT: begin
                    write_opcode = CMD_TX_COMMIT;
                    if (!generation_ready()) begin
                        write_result = RESULT_STALE_GENERATION;
                    end else if (quiesce_acknowledged) begin
                        write_result = RESULT_QUIESCING;
                    end else if (held_wdata != tx_stage_token) begin
                        write_result = RESULT_BAD_TOKEN;
                    end else if (tx_count == QUEUE_DEPTH) begin
                        write_result = RESULT_FULL;
                    end else if (!tx_stage_packet_valid()) begin
                        write_result = RESULT_INCOMPLETE;
                    end else begin
                        tx_commit_success = 1'b1;
                    end
                end
                REG_TX_CANCEL: begin
                    write_opcode = CMD_TX_CANCEL;
                    if (held_wdata != tx_stage_token) begin
                        write_result = RESULT_BAD_TOKEN;
                    end else begin
                        tx_cancel_success = 1'b1;
                    end
                end
                REG_QUIESCE_ACK: begin
                    write_opcode = CMD_QUIESCE_ACK;
                    if (!generation_ready()) begin
                        write_result = RESULT_STALE_GENERATION;
                    end else if (!provider_quiesce || held_wdata != active_generation ||
                                 !firmware_idle || rx_count != 0 || tx_count != 0 ||
                                 tx_stage_dirty || rx_packet_open || mmio_busy || mmio_done) begin
                        write_result = RESULT_BUSY;
                    end else begin
                        quiesce_ack_success = 1'b1;
                    end
                end
                REG_FIRMWARE_STATE: begin
                    write_opcode = held_wdata[1] ? CMD_FAULT : CMD_NONE;
                end
                REG_MMIO_ADDRESS, REG_MMIO_WRITE_LO, REG_MMIO_WRITE_HI,
                REG_MMIO_OPERATION: begin
                    if (!generation_ready() || quiesce_acknowledged || mmio_busy) begin
                        write_result = mmio_busy ? RESULT_BUSY :
                                       (quiesce_acknowledged ? RESULT_QUIESCING : RESULT_STALE_GENERATION);
                    end
                end
                REG_MMIO_SUBMIT: begin
                    write_opcode = CMD_MMIO_SUBMIT;
                    if (!generation_ready()) begin
                        write_result = RESULT_STALE_GENERATION;
                    end else if (quiesce_acknowledged) begin
                        write_result = RESULT_QUIESCING;
                    end else if (mmio_busy || mmio_done) begin
                        write_result = RESULT_BUSY;
                    end else if (held_wdata != mmio_token) begin
                        write_result = RESULT_BAD_TOKEN;
                    end else if (mmio_address[2:0] != 0) begin
                        write_result = RESULT_BAD_ACCESS;
                    end else begin
                        mmio_submit_success = 1'b1;
                    end
                end
                REG_MMIO_ACK: begin
                    write_opcode = CMD_MMIO_ACK;
                    if (!mmio_done || held_wdata != mmio_completion_token) begin
                        write_result = RESULT_BAD_TOKEN;
                    end else begin
                        mmio_ack_success = 1'b1;
                    end
                end
                default: begin
                    write_known = 1'b0;
                    write_bus_response = AXI_DECERR;
                    write_result = RESULT_BAD_ACCESS;
                end
            endcase
        end
    end

    always_comb begin
        s_axis_request_tready = provider_selected && identity_valid && fault_code == 0 &&
                                !provider_abort &&
                                (rx_packet_open || (!provider_quiesce && rx_count < QUEUE_DEPTH));

        m_axis_response_tvalid = tx_output_valid && provider_selected && identity_valid &&
                                 fault_code == 0 && !provider_abort;
        m_axis_response_tdata = tx_output_data;
        m_axis_response_tkeep = tx_output_keep;
        m_axis_response_tid = tx_output_id;
        m_axis_response_tlast = tx_output_last;
        m_axis_response_generation = tx_output_generation;

        provider_mmio_generation = active_generation;
        provider_mmio_awaddr = mmio_address;
        provider_mmio_awprot = 3'b000;
        provider_mmio_awvalid = mmio_busy && mmio_operation_write && !mmio_aw_sent;
        provider_mmio_wdata = mmio_write_data;
        provider_mmio_wstrb = mmio_write_strobe;
        provider_mmio_wvalid = mmio_busy && mmio_operation_write && !mmio_w_sent;
        provider_mmio_bready = mmio_busy && mmio_operation_write && mmio_aw_sent && mmio_w_sent;
        provider_mmio_araddr = mmio_address;
        provider_mmio_arprot = 3'b000;
        provider_mmio_arvalid = mmio_busy && !mmio_operation_write && !mmio_ar_sent;
        provider_mmio_rready = mmio_busy && !mmio_operation_write && mmio_ar_sent;
    end

    always_comb begin
        rx_handshake = s_axis_request_tvalid && s_axis_request_tready;
        rx_keep_valid = s_axis_request_tlast ? final_keep_valid(s_axis_request_tkeep) :
                                              (s_axis_request_tkeep == {KEEP_BITS{1'b1}});
        rx_generation_valid = s_axis_request_generation != '0 &&
                              s_axis_request_generation == active_generation;
        rx_malformed_event = rx_handshake && (!rx_keep_valid || !rx_generation_valid ||
                             (!s_axis_request_tlast && rx_input_beat == MAX_PACKET_BEATS - 1));
        rx_push_event = rx_handshake && s_axis_request_tlast && rx_keep_valid && rx_generation_valid;
        tx_pop_event = m_axis_response_tvalid && m_axis_response_tready && m_axis_response_tlast;
        mmio_timeout_event = mmio_busy && mmio_timeout_count == MMIO_TIMEOUT_CYCLES - 1;
    end

    always_comb begin
        firmware_identity_nonzero = |{firmware_identity[0], firmware_identity[1],
                                      firmware_identity[2], firmware_identity[3],
                                      firmware_identity[4], firmware_identity[5],
                                      firmware_identity[6], firmware_identity[7]};
        provider_fault = fault_code != 0;
        provider_available = identity_valid;
        firmware_runtime_abi = runtime_abi;
        firmware_abi_id = firmware_abi;
        firmware_image_identity = {firmware_identity[7], firmware_identity[6],
                                   firmware_identity[5], firmware_identity[4],
                                   firmware_identity[3], firmware_identity[2],
                                   firmware_identity[1], firmware_identity[0]};
        provider_healthy = identity_valid && fault_code == 0;
        provider_idle = firmware_idle && rx_count == 0 && tx_count == 0 &&
                        !rx_packet_open && !tx_stage_dirty && !mmio_busy && !mmio_done &&
                        (!provider_quiesce || quiesce_acknowledged);
    end

    function automatic [31:0] read_register(input logic [15:0] address, output logic known);
        integer word_index;
        integer beat_index;
        integer lane_index;
        logic [31:0] value;
        begin
            known = 1'b1;
            value = 32'd0;
            if (address >= RX_DATA_BASE && address < RX_DATA_BASE + 16'h1000) begin
                word_index = (address - RX_DATA_BASE) >> 2;
                beat_index = word_index / DATA_WORDS;
                lane_index = word_index % DATA_WORDS;
                if (rx_count != 0 && beat_index < rx_beats[rx_head]) begin
                    value = rx_data[rx_head][beat_index][lane_index*32 +: 32];
                end
            end else if (address >= RX_KEEP_BASE && address < RX_KEEP_BASE + 16'h0200) begin
                word_index = (address - RX_KEEP_BASE) >> 2;
                beat_index = word_index / KEEP_WORDS;
                lane_index = word_index % KEEP_WORDS;
                if (rx_count != 0 && beat_index < rx_beats[rx_head]) begin
                    value = rx_keep[rx_head][beat_index][lane_index*32 +: 32];
                end
            end else if (address >= RX_ATTR_BASE && address < RX_ATTR_BASE + 16'h0100) begin
                beat_index = (address - RX_ATTR_BASE) >> 2;
                if (rx_count != 0 && beat_index < rx_beats[rx_head]) begin
                    value[STREAM_ID_BITS-1:0] = rx_id[rx_head][beat_index];
                    value[6] = rx_last[rx_head][beat_index];
                end
            end else begin
                case (address)
                    REG_MAGIC: value = PROTOCOL_MAGIC;
                    REG_VERSION: value = PROTOCOL_VERSION;
                    REG_STREAM_SHAPE: value = {8'(STREAM_ID_BITS), 8'(MAX_PACKET_BEATS), 8'(DATA_WORDS), 8'(KEEP_BITS)};
                    REG_QUEUE_SHAPE: value = {8'(AXIL_ADDR_BITS), 8'(QUEUE_DEPTH), 8'(QUEUE_DEPTH), 8'(MAX_PACKET_BEATS)};
                    REG_STATUS: begin
                        value[0] = identity_valid;
                        value[1] = provider_available;
                        value[2] = provider_healthy;
                        value[3] = provider_selected;
                        value[4] = command_generation == active_generation && active_generation != 0;
                        value[5] = provider_quiesce;
                        value[6] = quiesce_acknowledged;
                        value[7] = provider_idle;
                        value[8] = rx_count == 0;
                        value[9] = rx_count == QUEUE_DEPTH;
                        value[10] = tx_count == 0;
                        value[11] = tx_count == QUEUE_DEPTH;
                        value[12] = mmio_busy;
                        value[13] = provider_fault;
                        value[14] = abort_seen;
                        value[15] = &endpoint_generation;
                    end
                    REG_ACTIVE_GENERATION: value = active_generation;
                    REG_ENDPOINT_GENERATION: value = endpoint_generation;
                    REG_COMMAND_GENERATION: value = command_generation;
                    REG_LAST_COMMAND: value = {command_serial, last_command_opcode, last_command_result};
                    REG_LAST_TOKEN: value = last_command_token;
                    REG_FAULT: value = fault_code;
                    REG_FAULT_DETAIL: value = fault_detail;
                    REG_FIRMWARE_STATE: value = {30'd0, provider_fault, firmware_idle};
                    REG_PROTOCOL_ERRORS: value = protocol_errors;
                    REG_RUNTIME_ABI: value = {16'd0, runtime_abi};
                    REG_FIRMWARE_ABI: value = {16'd0, firmware_abi};
                    REG_IDENTITY_BASE, REG_IDENTITY_BASE + 4, REG_IDENTITY_BASE + 8,
                    REG_IDENTITY_BASE + 12, REG_IDENTITY_BASE + 16, REG_IDENTITY_BASE + 20,
                    REG_IDENTITY_BASE + 24, REG_IDENTITY_BASE + 28:
                        value = firmware_identity[(address - REG_IDENTITY_BASE) >> 2];
                    REG_IDENTITY_STATE: value = {endpoint_generation[15:0], 15'd0, identity_valid};
                    REG_RX_STATUS: value = {16'd0, 7'(rx_count), rx_packet_open, 7'(QUEUE_DEPTH-rx_count), rx_count == 0};
                    REG_RX_TOKEN: value = rx_count == 0 ? 0 : rx_token[rx_head];
                    REG_RX_GENERATION: value = rx_count == 0 ? 0 : rx_generation[rx_head];
                    REG_RX_BEATS: value = rx_count == 0 ? 0 : rx_beats[rx_head];
                    REG_RX_BYTES: value = rx_count == 0 ? 0 : rx_bytes[rx_head];
                    REG_RX_DROPPED: value = rx_dropped;
                    REG_RX_MALFORMED: value = rx_malformed;
                    REG_TX_STATUS: value = {16'd0, 7'(tx_count), tx_stage_dirty, 7'(QUEUE_DEPTH-tx_count), tx_count == QUEUE_DEPTH};
                    REG_TX_TOKEN: value = tx_stage_token;
                    REG_TX_BEATS: value = tx_stage_beats;
                    REG_TX_REJECTED: value = tx_rejected;
                    REG_MMIO_STATUS: value = {24'd0, mmio_result[3:0], mmio_operation_write, mmio_done, mmio_busy};
                    REG_MMIO_TOKEN: value = mmio_token;
                    REG_MMIO_ADDRESS: value = mmio_address;
                    REG_MMIO_WRITE_LO: value = mmio_write_data[31:0];
                    REG_MMIO_WRITE_HI: value = mmio_write_data[63:32];
                    REG_MMIO_OPERATION: value = {23'd0, mmio_write_strobe, mmio_operation_write};
                    REG_MMIO_COMPLETION: value = mmio_completion_token;
                    REG_MMIO_READ_LO: value = mmio_read_data_reg[31:0];
                    REG_MMIO_READ_HI: value = mmio_read_data_reg[63:32];
                    REG_MMIO_RESULT: value = mmio_result;
                    default: known = 1'b0;
                endcase
            end
            read_register = value;
        end
    endfunction

    integer reset_index;
    integer reset_beat;
    integer identity_index;
    integer write_word_index;
    integer write_beat_index;
    integer write_lane_index;
    logic read_known;
    logic [31:0] read_value;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            identity_valid <= 1'b0;
            runtime_abi <= '0;
            firmware_abi <= '0;
            endpoint_generation <= '0;
            firmware_idle <= 1'b0;
            quiesce_acknowledged <= 1'b0;
            abort_seen <= 1'b0;
            command_generation <= '0;
            fault_code <= '0;
            fault_detail <= '0;
            protocol_errors <= '0;
            rx_dropped <= '0;
            rx_malformed <= '0;
            tx_rejected <= '0;
            command_serial <= '0;
            last_command_opcode <= CMD_NONE;
            last_command_result <= RESULT_OK;
            last_command_token <= '0;
            transport_epoch <= 32'd1;
            provider_selected_d <= 1'b0;
            active_generation_d <= '0;
            abort_latched <= 1'b0;
            rx_head <= '0;
            rx_tail <= '0;
            rx_count <= '0;
            tx_head <= '0;
            tx_tail <= '0;
            tx_count <= '0;
            tx_output_beat <= '0;
            tx_output_valid <= 1'b0;
            tx_output_data <= '0;
            tx_output_keep <= '0;
            tx_output_id <= '0;
            tx_output_last <= 1'b0;
            tx_output_generation <= '0;
            tx_stage_beats <= '0;
            tx_stage_dirty <= 1'b0;
            rx_packet_open <= 1'b0;
            rx_input_beat <= '0;
            next_rx_token <= 32'd1;
            tx_stage_token <= 32'd1;
            aw_held <= 1'b0;
            w_held <= 1'b0;
            read_pending <= 1'b0;
            s_axi_bvalid <= 1'b0;
            s_axi_bresp <= AXI_OKAY;
            s_axi_rvalid <= 1'b0;
            s_axi_rresp <= AXI_OKAY;
            s_axi_rdata <= '0;
            mmio_address <= '0;
            mmio_write_data <= '0;
            mmio_write_strobe <= '0;
            mmio_operation_write <= 1'b0;
            mmio_token <= 32'd1;
            mmio_completion_token <= '0;
            mmio_read_data_reg <= '0;
            mmio_result <= RESULT_OK;
            mmio_busy <= 1'b0;
            mmio_done <= 1'b0;
            mmio_aw_sent <= 1'b0;
            mmio_w_sent <= 1'b0;
            mmio_ar_sent <= 1'b0;
            mmio_timeout_count <= '0;
            for (identity_index = 0; identity_index < 8; identity_index = identity_index + 1) begin
                firmware_identity[identity_index] <= '0;
            end
            for (reset_beat = 0; reset_beat < MAX_PACKET_BEATS; reset_beat = reset_beat + 1) begin
                tx_data_written[reset_beat] <= '0;
                tx_keep_written[reset_beat] <= '0;
                tx_attr_written[reset_beat] <= 1'b0;
            end
        end else begin
            provider_selected_d <= provider_selected;
            active_generation_d <= active_generation;

            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
            if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end

            if (s_axi_awvalid && s_axi_awready) begin
                aw_held <= 1'b1;
                held_awaddr <= s_axi_awaddr;
                held_awprot <= s_axi_awprot;
                held_aw_epoch <= transport_epoch;
            end
            if (s_axi_wvalid && s_axi_wready) begin
                w_held <= 1'b1;
                held_wdata <= s_axi_wdata;
                held_wstrb <= s_axi_wstrb;
                held_w_epoch <= transport_epoch;
            end
            if (s_axi_arvalid && s_axi_arready) begin
                read_pending <= 1'b1;
                held_araddr <= s_axi_araddr;
                held_arprot <= s_axi_arprot;
                held_ar_epoch <= transport_epoch;
            end
            if (read_pending && !s_axi_rvalid) begin
                read_pending <= 1'b0;
                read_value = read_register(held_araddr[15:0], read_known);
                s_axi_rdata <= read_value;
                s_axi_rresp <= (held_ar_epoch != transport_epoch) ? AXI_SLVERR :
                               (read_known ? AXI_OKAY : AXI_DECERR);
                s_axi_rvalid <= 1'b1;
            end

            if (write_execute) begin
                aw_held <= 1'b0;
                w_held <= 1'b0;
                s_axi_bresp <= write_bus_response;
                s_axi_bvalid <= 1'b1;

                if (write_known && write_bus_response == AXI_OKAY && write_opcode != CMD_NONE) begin
                    command_serial <= command_serial + 1'b1;
                    last_command_opcode <= write_opcode;
                    last_command_result <= write_result;
                    last_command_token <= held_wdata;
                end
                if (write_bus_response == AXI_SLVERR || write_bus_response == AXI_DECERR) begin
                    protocol_errors <= saturating_increment(protocol_errors);
                end

                if (write_bus_response == AXI_OKAY && write_result == RESULT_OK) begin
                    if (write_address >= TX_DATA_BASE && write_address < TX_DATA_BASE + 16'h1000) begin
                        write_word_index = (write_address - TX_DATA_BASE) >> 2;
                        write_beat_index = write_word_index / DATA_WORDS;
                        write_lane_index = write_word_index % DATA_WORDS;
                        tx_data[tx_tail][write_beat_index][write_lane_index*32 +: 32] <= held_wdata;
                        tx_data_written[write_beat_index][write_lane_index] <= 1'b1;
                        tx_stage_dirty <= 1'b1;
                    end else if (write_address >= TX_KEEP_BASE && write_address < TX_KEEP_BASE + 16'h0200) begin
                        write_word_index = (write_address - TX_KEEP_BASE) >> 2;
                        write_beat_index = write_word_index / KEEP_WORDS;
                        write_lane_index = write_word_index % KEEP_WORDS;
                        tx_keep[tx_tail][write_beat_index][write_lane_index*32 +: 32] <= held_wdata;
                        tx_keep_written[write_beat_index][write_lane_index] <= 1'b1;
                        tx_stage_dirty <= 1'b1;
                    end else if (write_address >= TX_ATTR_BASE && write_address < TX_ATTR_BASE + 16'h0100) begin
                        write_beat_index = (write_address - TX_ATTR_BASE) >> 2;
                        tx_id[tx_tail][write_beat_index] <= held_wdata[STREAM_ID_BITS-1:0];
                        tx_last[tx_tail][write_beat_index] <= held_wdata[6];
                        tx_attr_written[write_beat_index] <= 1'b1;
                        tx_stage_dirty <= 1'b1;
                    end else begin
                        case (write_address)
                            REG_COMMAND_GENERATION: if (generation_ack_success) command_generation <= held_wdata;
                            REG_RUNTIME_ABI: runtime_abi <= held_wdata[15:0];
                            REG_FIRMWARE_ABI: firmware_abi <= held_wdata[15:0];
                            REG_IDENTITY_BASE, REG_IDENTITY_BASE + 4, REG_IDENTITY_BASE + 8,
                            REG_IDENTITY_BASE + 12, REG_IDENTITY_BASE + 16, REG_IDENTITY_BASE + 20,
                            REG_IDENTITY_BASE + 24, REG_IDENTITY_BASE + 28:
                                firmware_identity[(write_address - REG_IDENTITY_BASE) >> 2] <= held_wdata;
                            REG_IDENTITY_COMMIT: if (identity_publish_success) begin
                                identity_valid <= 1'b1;
                                endpoint_generation <= endpoint_generation + 1'b1;
                            end
                            REG_TX_BEATS: tx_stage_beats <= held_wdata[PACKET_BEAT_COUNT_BITS-1:0];
                            REG_FIRMWARE_STATE: begin
                                firmware_idle <= held_wdata[0];
                                if (held_wdata[1]) begin
                                    fault_code <= held_wdata[31:16] == 0 ? 32'h0001_0001 : {16'd0, held_wdata[31:16]};
                                    fault_detail <= held_wdata;
                                end
                            end
                            REG_QUIESCE_ACK: if (quiesce_ack_success) quiesce_acknowledged <= 1'b1;
                            REG_MMIO_ADDRESS: mmio_address <= held_wdata[MMIO_ADDR_BITS-1:0];
                            REG_MMIO_WRITE_LO: mmio_write_data[31:0] <= held_wdata;
                            REG_MMIO_WRITE_HI: mmio_write_data[63:32] <= held_wdata;
                            REG_MMIO_OPERATION: begin
                                mmio_operation_write <= held_wdata[0];
                                mmio_write_strobe <= held_wdata[8:1];
                            end
                            default: ;
                        endcase
                    end
                end

                if (write_opcode == CMD_TX_COMMIT && !tx_commit_success) begin
                    tx_rejected <= saturating_increment(tx_rejected);
                end
            end

            if (rx_handshake && !rx_malformed_event) begin
                rx_data[rx_tail][rx_input_beat] <= s_axis_request_tdata;
                rx_keep[rx_tail][rx_input_beat] <= s_axis_request_tkeep;
                rx_id[rx_tail][rx_input_beat] <= s_axis_request_tid;
                rx_last[rx_tail][rx_input_beat] <= s_axis_request_tlast;
                if (!rx_packet_open) begin
                    rx_packet_open <= 1'b1;
                    rx_input_beat <= '0;
                end
                if (s_axis_request_tlast) begin
                    rx_packet_open <= 1'b0;
                    rx_input_beat <= '0;
                    rx_generation[rx_tail] <= active_generation;
                    rx_token[rx_tail] <= next_rx_token;
                    rx_beats[rx_tail] <= rx_input_beat + 1'b1;
                    rx_bytes[rx_tail] <= rx_input_beat * KEEP_BITS + keep_byte_count(s_axis_request_tkeep);
                    rx_tail <= next_slot(rx_tail);
                    if (&next_rx_token) begin
                        fault_code <= 32'h0002_0001;
                        fault_detail <= next_rx_token;
                    end else begin
                        next_rx_token <= next_rx_token + 1'b1;
                    end
                end else begin
                    rx_input_beat <= rx_input_beat + 1'b1;
                end
            end
            if (rx_malformed_event) begin
                rx_packet_open <= 1'b0;
                rx_input_beat <= '0;
                rx_malformed <= saturating_increment(rx_malformed);
                fault_code <= 32'h0002_0002;
                fault_detail <= {24'd0, s_axis_request_tlast, s_axis_request_tid};
            end

            if (tx_commit_success) begin
                tx_generation[tx_tail] <= active_generation;
                tx_tail <= next_slot(tx_tail);
                tx_stage_dirty <= 1'b0;
                tx_stage_beats <= '0;
                if (&tx_stage_token) begin
                    fault_code <= 32'h0003_0001;
                    fault_detail <= tx_stage_token;
                end else begin
                    tx_stage_token <= tx_stage_token + 1'b1;
                end
                for (reset_beat = 0; reset_beat < MAX_PACKET_BEATS; reset_beat = reset_beat + 1) begin
                    tx_data_written[reset_beat] <= '0;
                    tx_keep_written[reset_beat] <= '0;
                    tx_attr_written[reset_beat] <= 1'b0;
                end
            end else if (tx_cancel_success) begin
                tx_stage_dirty <= 1'b0;
                tx_stage_beats <= '0;
                if (&tx_stage_token) begin
                    fault_code <= 32'h0003_0001;
                    fault_detail <= tx_stage_token;
                end else begin
                    tx_stage_token <= tx_stage_token + 1'b1;
                end
                for (reset_beat = 0; reset_beat < MAX_PACKET_BEATS; reset_beat = reset_beat + 1) begin
                    tx_data_written[reset_beat] <= '0;
                    tx_keep_written[reset_beat] <= '0;
                    tx_attr_written[reset_beat] <= 1'b0;
                end
            end

            if (!tx_output_valid && tx_count != 0 && !provider_abort) begin
                tx_output_valid <= 1'b1;
                tx_output_data <= tx_data[tx_head][tx_output_beat];
                tx_output_keep <= tx_keep[tx_head][tx_output_beat];
                tx_output_id <= tx_id[tx_head][tx_output_beat];
                tx_output_last <= tx_last[tx_head][tx_output_beat];
                tx_output_generation <= tx_generation[tx_head];
            end
            if (m_axis_response_tvalid && m_axis_response_tready) begin
                if (m_axis_response_tlast) begin
                    tx_output_valid <= 1'b0;
                    tx_head <= next_slot(tx_head);
                    tx_output_beat <= '0;
                end else begin
                    tx_output_beat <= tx_output_beat + 1'b1;
                    tx_output_data <= tx_data[tx_head][tx_output_beat + 1'b1];
                    tx_output_keep <= tx_keep[tx_head][tx_output_beat + 1'b1];
                    tx_output_id <= tx_id[tx_head][tx_output_beat + 1'b1];
                    tx_output_last <= tx_last[tx_head][tx_output_beat + 1'b1];
                    tx_output_generation <= tx_generation[tx_head];
                end
            end

            case ({rx_push_event, rx_pop_success})
                2'b10: rx_count <= rx_count + 1'b1;
                2'b01: begin
                    rx_count <= rx_count - 1'b1;
                    rx_head <= next_slot(rx_head);
                end
                2'b11: rx_head <= next_slot(rx_head);
                default: ;
            endcase
            case ({tx_commit_success, tx_pop_event})
                2'b10: tx_count <= tx_count + 1'b1;
                2'b01: tx_count <= tx_count - 1'b1;
                default: ;
            endcase

            if (mmio_submit_success) begin
                mmio_busy <= 1'b1;
                mmio_done <= 1'b0;
                mmio_result <= RESULT_OK;
                mmio_completion_token <= mmio_token;
                mmio_aw_sent <= 1'b0;
                mmio_w_sent <= 1'b0;
                mmio_ar_sent <= 1'b0;
                mmio_timeout_count <= '0;
            end
            if (mmio_busy) begin
                if (provider_mmio_awvalid && provider_mmio_awready) mmio_aw_sent <= 1'b1;
                if (provider_mmio_wvalid && provider_mmio_wready) mmio_w_sent <= 1'b1;
                if (provider_mmio_arvalid && provider_mmio_arready) mmio_ar_sent <= 1'b1;
                if (provider_mmio_bvalid && provider_mmio_bready) begin
                    mmio_busy <= 1'b0;
                    mmio_done <= 1'b1;
                    mmio_result <= provider_mmio_bresp == AXI_OKAY ? RESULT_OK :
                                   (provider_mmio_bresp == AXI_SLVERR ? RESULT_AXI_SLVERR : RESULT_AXI_DECERR);
                end else if (provider_mmio_rvalid && provider_mmio_rready) begin
                    mmio_busy <= 1'b0;
                    mmio_done <= 1'b1;
                    mmio_read_data_reg <= provider_mmio_rdata;
                    mmio_result <= provider_mmio_rresp == AXI_OKAY ? RESULT_OK :
                                   (provider_mmio_rresp == AXI_SLVERR ? RESULT_AXI_SLVERR : RESULT_AXI_DECERR);
                end else if (mmio_timeout_event) begin
                    mmio_busy <= 1'b0;
                    mmio_done <= 1'b1;
                    mmio_result <= RESULT_TIMEOUT;
                    fault_code <= 32'h0004_0001;
                    fault_detail <= mmio_completion_token;
                end else begin
                    mmio_timeout_count <= mmio_timeout_count + 1'b1;
                end
            end
            if (mmio_ack_success) begin
                mmio_done <= 1'b0;
                if (&mmio_token) begin
                    fault_code <= 32'h0004_0002;
                    fault_detail <= mmio_token;
                end else begin
                    mmio_token <= mmio_token + 1'b1;
                end
            end

            if (identity_publish_success) begin
                firmware_idle <= 1'b1;
            end
            if (generation_ack_success) begin
                abort_seen <= 1'b0;
                quiesce_acknowledged <= 1'b0;
            end

            if ((!provider_selected_d && provider_selected) ||
                (provider_selected && active_generation_d != active_generation)) begin
                transport_epoch <= transport_epoch + 1'b1;
                command_generation <= '0;
                quiesce_acknowledged <= 1'b0;
                rx_packet_open <= 1'b0;
                rx_input_beat <= '0;
                rx_head <= '0;
                rx_tail <= '0;
                rx_count <= '0;
                tx_head <= '0;
                tx_tail <= '0;
                tx_count <= '0;
                tx_output_beat <= '0;
                tx_output_valid <= 1'b0;
                tx_stage_dirty <= 1'b0;
                tx_stage_beats <= '0;
                if (!(&tx_stage_token)) tx_stage_token <= tx_stage_token + 1'b1;
                for (reset_beat = 0; reset_beat < MAX_PACKET_BEATS; reset_beat = reset_beat + 1) begin
                    tx_data_written[reset_beat] <= '0;
                    tx_keep_written[reset_beat] <= '0;
                    tx_attr_written[reset_beat] <= 1'b0;
                end
                mmio_busy <= 1'b0;
                mmio_done <= 1'b0;
            end
            if (provider_selected_d && !provider_selected) begin
                transport_epoch <= transport_epoch + 1'b1;
                command_generation <= '0;
                quiesce_acknowledged <= 1'b0;
            end

            if (provider_abort && !abort_latched) begin
                abort_latched <= 1'b1;
                abort_seen <= 1'b1;
                transport_epoch <= transport_epoch + 1'b1;
                command_generation <= '0;
                quiesce_acknowledged <= 1'b0;
                rx_packet_open <= 1'b0;
                rx_input_beat <= '0;
                rx_head <= '0;
                rx_tail <= '0;
                rx_count <= '0;
                tx_head <= '0;
                tx_tail <= '0;
                tx_count <= '0;
                tx_output_beat <= '0;
                tx_output_valid <= 1'b0;
                tx_stage_dirty <= 1'b0;
                tx_stage_beats <= '0;
                if (!(&tx_stage_token)) tx_stage_token <= tx_stage_token + 1'b1;
                for (reset_beat = 0; reset_beat < MAX_PACKET_BEATS; reset_beat = reset_beat + 1) begin
                    tx_data_written[reset_beat] <= '0;
                    tx_keep_written[reset_beat] <= '0;
                    tx_attr_written[reset_beat] <= 1'b0;
                end
                mmio_busy <= 1'b0;
                mmio_done <= 1'b1;
                mmio_result <= RESULT_ABORTED;
                mmio_completion_token <= mmio_token;
                protocol_errors <= saturating_increment(protocol_errors);
            end else if (!provider_abort) begin
                abort_latched <= 1'b0;
            end

            if (management_recover) begin
                identity_valid <= 1'b0;
                runtime_abi <= '0;
                firmware_abi <= '0;
                firmware_idle <= 1'b0;
                command_generation <= '0;
                quiesce_acknowledged <= 1'b0;
                abort_seen <= 1'b0;
                fault_code <= '0;
                fault_detail <= '0;
                transport_epoch <= transport_epoch + 1'b1;
                rx_head <= '0;
                rx_tail <= '0;
                rx_count <= '0;
                tx_head <= '0;
                tx_tail <= '0;
                tx_count <= '0;
                tx_output_beat <= '0;
                tx_output_valid <= 1'b0;
                tx_stage_dirty <= 1'b0;
                tx_stage_beats <= '0;
                if (!(&tx_stage_token)) tx_stage_token <= tx_stage_token + 1'b1;
                for (reset_beat = 0; reset_beat < MAX_PACKET_BEATS; reset_beat = reset_beat + 1) begin
                    tx_data_written[reset_beat] <= '0;
                    tx_keep_written[reset_beat] <= '0;
                    tx_attr_written[reset_beat] <= 1'b0;
                end
                rx_packet_open <= 1'b0;
                mmio_busy <= 1'b0;
                mmio_done <= 1'b0;
            end
        end
    end

`ifndef SYNTHESIS
    initial begin
        assert(STREAM_DATA_BITS == 512);
        assert(KEEP_BITS == 64);
        assert(STREAM_ID_BITS == 6);
        assert(GENERATION_BITS == 32);
        assert(MMIO_DATA_BITS == 64);
        assert(MAX_PACKET_BEATS == 64);
        assert(QUEUE_DEPTH > 0);
        assert((QUEUE_DEPTH & (QUEUE_DEPTH - 1)) == 0);
        assert(MMIO_TIMEOUT_CYCLES > 1);
    end

    property stable_response_stream;
        @(posedge aclk) disable iff (!aresetn || provider_abort)
        m_axis_response_tvalid && !m_axis_response_tready |=>
            m_axis_response_tvalid && $stable({m_axis_response_tdata, m_axis_response_tkeep,
                                               m_axis_response_tid, m_axis_response_tlast,
                                               m_axis_response_generation});
    endproperty
    assert property(stable_response_stream);

    property stable_write_response;
        @(posedge aclk) disable iff (!aresetn)
        s_axi_bvalid && !s_axi_bready |=> s_axi_bvalid && $stable(s_axi_bresp);
    endproperty
    assert property(stable_write_response);

    property stable_read_response;
        @(posedge aclk) disable iff (!aresetn)
        s_axi_rvalid && !s_axi_rready |=> s_axi_rvalid && $stable({s_axi_rdata, s_axi_rresp});
    endproperty
    assert property(stable_read_response);
`endif

endmodule
