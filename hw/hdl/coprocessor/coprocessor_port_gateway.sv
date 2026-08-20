`timescale 1ns / 1ps

module coprocessor_port_gateway #(
    parameter integer N_PROVIDERS = 2,
    parameter integer ENDPOINT_BITS = 16,
    parameter integer STREAM_DATA_BITS = 512,
    parameter integer STREAM_ID_BITS = 6,
    parameter integer MMIO_ADDR_BITS = 12,
    parameter integer MMIO_DATA_BITS = 64,
    parameter integer GENERATION_BITS = 32,
    parameter integer ABI_BITS = 16,
    parameter integer MAX_PACKET_BEATS = 64,
    parameter logic [ABI_BITS-1:0] REQUIRED_STREAM_ABI = 1,
    parameter logic [ABI_BITS-1:0] REQUIRED_MMIO_ABI = 1
) (
    input  logic aclk,
    input  logic aresetn,
    input  logic application_decoupled,

    input  logic                         command_valid,
    output logic                         command_ready,
    input  logic [2:0]                   command_opcode,
    input  logic [ENDPOINT_BITS-1:0]     command_endpoint,
    input  logic [GENERATION_BITS-1:0]   command_binding_generation,
    input  logic [GENERATION_BITS-1:0]   command_endpoint_generation,
    output logic                         response_valid,
    input  logic                         response_ready,
    output logic [3:0]                   response_result,

    input  logic [N_PROVIDERS-1:0][ENDPOINT_BITS-1:0]   provider_endpoint,
    input  logic [N_PROVIDERS-1:0][ABI_BITS-1:0]        provider_stream_abi,
    input  logic [N_PROVIDERS-1:0][ABI_BITS-1:0]        provider_mmio_abi,
    input  logic [N_PROVIDERS-1:0][GENERATION_BITS-1:0] provider_generation,
    input  logic [N_PROVIDERS-1:0]                      provider_available,
    input  logic [N_PROVIDERS-1:0]                      provider_healthy,
    input  logic [N_PROVIDERS-1:0]                      provider_owned,
    input  logic [N_PROVIDERS-1:0]                      provider_idle,
    input  logic [N_PROVIDERS-1:0]                      provider_fault,
    output logic [N_PROVIDERS-1:0]                      provider_selected,
    output logic [N_PROVIDERS-1:0]                      provider_quiesce,
    output logic [N_PROVIDERS-1:0]                      provider_abort,
    output logic [N_PROVIDERS-1:0][GENERATION_BITS-1:0] provider_active_generation,

    input  logic [STREAM_DATA_BITS-1:0]   application_send_tdata,
    input  logic [STREAM_DATA_BITS/8-1:0] application_send_tkeep,
    input  logic [STREAM_ID_BITS-1:0]     application_send_tid,
    input  logic                          application_send_tlast,
    input  logic                          application_send_tvalid,
    output logic                          application_send_tready,

    output logic [STREAM_DATA_BITS-1:0]   application_recv_tdata,
    output logic [STREAM_DATA_BITS/8-1:0] application_recv_tkeep,
    output logic [STREAM_ID_BITS-1:0]     application_recv_tid,
    output logic                          application_recv_tlast,
    output logic                          application_recv_tvalid,
    input  logic                          application_recv_tready,

    output logic [N_PROVIDERS-1:0][STREAM_DATA_BITS-1:0]   provider_send_tdata,
    output logic [N_PROVIDERS-1:0][STREAM_DATA_BITS/8-1:0] provider_send_tkeep,
    output logic [N_PROVIDERS-1:0][STREAM_ID_BITS-1:0]     provider_send_tid,
    output logic [N_PROVIDERS-1:0]                         provider_send_tlast,
    output logic [N_PROVIDERS-1:0]                         provider_send_tvalid,
    input  logic [N_PROVIDERS-1:0]                         provider_send_tready,
    output logic [N_PROVIDERS-1:0][GENERATION_BITS-1:0]    provider_send_generation,

    input  logic [N_PROVIDERS-1:0][STREAM_DATA_BITS-1:0]   provider_recv_tdata,
    input  logic [N_PROVIDERS-1:0][STREAM_DATA_BITS/8-1:0] provider_recv_tkeep,
    input  logic [N_PROVIDERS-1:0][STREAM_ID_BITS-1:0]     provider_recv_tid,
    input  logic [N_PROVIDERS-1:0]                         provider_recv_tlast,
    input  logic [N_PROVIDERS-1:0]                         provider_recv_tvalid,
    output logic [N_PROVIDERS-1:0]                         provider_recv_tready,
    input  logic [N_PROVIDERS-1:0][GENERATION_BITS-1:0]    provider_recv_generation,

    input  logic [N_PROVIDERS-1:0][GENERATION_BITS-1:0]    provider_mmio_generation,
    input  logic [N_PROVIDERS-1:0][MMIO_ADDR_BITS-1:0]     provider_mmio_awaddr,
    input  logic [N_PROVIDERS-1:0][2:0]                    provider_mmio_awprot,
    input  logic [N_PROVIDERS-1:0]                         provider_mmio_awvalid,
    output logic [N_PROVIDERS-1:0]                         provider_mmio_awready,
    input  logic [N_PROVIDERS-1:0][MMIO_DATA_BITS-1:0]     provider_mmio_wdata,
    input  logic [N_PROVIDERS-1:0][MMIO_DATA_BITS/8-1:0]   provider_mmio_wstrb,
    input  logic [N_PROVIDERS-1:0]                         provider_mmio_wvalid,
    output logic [N_PROVIDERS-1:0]                         provider_mmio_wready,
    output logic [N_PROVIDERS-1:0][1:0]                    provider_mmio_bresp,
    output logic [N_PROVIDERS-1:0]                         provider_mmio_bvalid,
    input  logic [N_PROVIDERS-1:0]                         provider_mmio_bready,
    input  logic [N_PROVIDERS-1:0][MMIO_ADDR_BITS-1:0]     provider_mmio_araddr,
    input  logic [N_PROVIDERS-1:0][2:0]                    provider_mmio_arprot,
    input  logic [N_PROVIDERS-1:0]                         provider_mmio_arvalid,
    output logic [N_PROVIDERS-1:0]                         provider_mmio_arready,
    output logic [N_PROVIDERS-1:0][MMIO_DATA_BITS-1:0]     provider_mmio_rdata,
    output logic [N_PROVIDERS-1:0][1:0]                    provider_mmio_rresp,
    output logic [N_PROVIDERS-1:0]                         provider_mmio_rvalid,
    input  logic [N_PROVIDERS-1:0]                         provider_mmio_rready,

    output logic [MMIO_ADDR_BITS-1:0]     application_mmio_awaddr,
    output logic [2:0]                    application_mmio_awprot,
    output logic                          application_mmio_awvalid,
    input  logic                          application_mmio_awready,
    output logic [MMIO_DATA_BITS-1:0]     application_mmio_wdata,
    output logic [MMIO_DATA_BITS/8-1:0]   application_mmio_wstrb,
    output logic                          application_mmio_wvalid,
    input  logic                          application_mmio_wready,
    input  logic [1:0]                    application_mmio_bresp,
    input  logic                          application_mmio_bvalid,
    output logic                          application_mmio_bready,
    output logic [MMIO_ADDR_BITS-1:0]     application_mmio_araddr,
    output logic [2:0]                    application_mmio_arprot,
    output logic                          application_mmio_arvalid,
    input  logic                          application_mmio_arready,
    input  logic [MMIO_DATA_BITS-1:0]     application_mmio_rdata,
    input  logic [1:0]                    application_mmio_rresp,
    input  logic                          application_mmio_rvalid,
    output logic                          application_mmio_rready,

    output logic [2:0]                    binding_state,
    output logic [ENDPOINT_BITS-1:0]      binding_endpoint,
    output logic [GENERATION_BITS-1:0]    binding_generation,
    output logic                          streams_idle,
    output logic                          mmio_idle,
    output logic                          stale_response_fault
);

    localparam logic [2:0] STATE_UNBOUND    = 3'd0;
    localparam logic [2:0] STATE_READY      = 3'd1;
    localparam logic [2:0] STATE_QUIESCING  = 3'd2;
    localparam logic [2:0] STATE_QUIESCED   = 3'd3;
    localparam logic [2:0] STATE_FAULTED    = 3'd4;

    localparam logic [2:0] OP_BIND     = 3'd1;
    localparam logic [2:0] OP_QUIESCE  = 3'd2;
    localparam logic [2:0] OP_UNBIND   = 3'd3;
    localparam logic [2:0] OP_RECOVER  = 3'd4;

    localparam logic [3:0] RESULT_OK                    = 4'd0;
    localparam logic [3:0] RESULT_ENDPOINT_NOT_FOUND    = 4'd1;
    localparam logic [3:0] RESULT_ABI_MISMATCH          = 4'd2;
    localparam logic [3:0] RESULT_UNHEALTHY             = 4'd3;
    localparam logic [3:0] RESULT_NOT_IDLE              = 4'd4;
    localparam logic [3:0] RESULT_STALE_GENERATION      = 4'd5;
    localparam logic [3:0] RESULT_DECOUPLED             = 4'd6;
    localparam logic [3:0] RESULT_GENERATION_EXHAUSTED  = 4'd7;
    localparam logic [3:0] RESULT_FAULTED               = 4'd8;
    localparam logic [3:0] RESULT_BAD_STATE             = 4'd9;
    localparam logic [3:0] RESULT_OCCUPIED              = 4'd11;

    localparam integer PROVIDER_INDEX_BITS = N_PROVIDERS <= 1 ? 1 : $clog2(N_PROVIDERS);
    localparam integer PACKET_COUNT_BITS = MAX_PACKET_BEATS <= 1 ? 1 : $clog2(MAX_PACKET_BEATS + 1);

    logic [PROVIDER_INDEX_BITS-1:0] selected_index;
    logic selected_valid;
    logic [GENERATION_BITS-1:0] bound_provider_generation;
    logic application_send_open;
    logic provider_recv_open;
    logic [PACKET_COUNT_BITS-1:0] application_send_beats;
    logic [PACKET_COUNT_BITS-1:0] provider_recv_beats;
    logic [GENERATION_BITS-1:0] provider_packet_generation;
    logic send_buffer_valid;
    logic [PROVIDER_INDEX_BITS-1:0] send_buffer_index;
    logic [STREAM_DATA_BITS-1:0] send_buffer_data;
    logic [STREAM_DATA_BITS/8-1:0] send_buffer_keep;
    logic [STREAM_ID_BITS-1:0] send_buffer_id;
    logic send_buffer_last;
    logic [GENERATION_BITS-1:0] send_buffer_generation;
    logic recv_buffer_valid;
    logic [STREAM_DATA_BITS-1:0] recv_buffer_data;
    logic [STREAM_DATA_BITS/8-1:0] recv_buffer_keep;
    logic [STREAM_ID_BITS-1:0] recv_buffer_id;
    logic recv_buffer_last;
    logic [GENERATION_BITS-1:0] recv_buffer_generation;

    logic mmio_write_active;
    logic mmio_read_active;
    logic mmio_aw_sent;
    logic mmio_w_sent;
    logic mmio_ar_sent;
    logic drain_write_response;
    logic drain_read_response;
    logic [MMIO_ADDR_BITS-1:0] mmio_write_addr;
    logic [2:0] mmio_write_prot;
    logic [MMIO_DATA_BITS-1:0] mmio_write_data;
    logic [MMIO_DATA_BITS/8-1:0] mmio_write_strb;
    logic [MMIO_ADDR_BITS-1:0] mmio_read_addr;
    logic [2:0] mmio_read_prot;
    logic [N_PROVIDERS-1:0] error_bvalid;
    logic [N_PROVIDERS-1:0][1:0] error_bresp;
    logic [N_PROVIDERS-1:0] error_rvalid;
    logic [N_PROVIDERS-1:0][1:0] error_rresp;
    logic [N_PROVIDERS-1:0][MMIO_DATA_BITS-1:0] error_rdata;
    logic [N_PROVIDERS-1:0] aw_held;
    logic [N_PROVIDERS-1:0] w_held;
    logic [N_PROVIDERS-1:0][MMIO_ADDR_BITS-1:0] held_awaddr;
    logic [N_PROVIDERS-1:0][2:0] held_awprot;
    logic [N_PROVIDERS-1:0][GENERATION_BITS-1:0] held_aw_generation;
    logic [N_PROVIDERS-1:0][MMIO_DATA_BITS-1:0] held_wdata;
    logic [N_PROVIDERS-1:0][MMIO_DATA_BITS/8-1:0] held_wstrb;
    logic [N_PROVIDERS-1:0][GENERATION_BITS-1:0] held_w_generation;

    function automatic logic valid_keep(
        input logic [STREAM_DATA_BITS/8-1:0] keep,
        input logic last
    );
        logic [STREAM_DATA_BITS/8-1:0] incremented;
        begin
            incremented = keep + 1'b1;
            valid_keep = last ? ((keep != '0) && ((keep & incremented) == '0)) : (&keep);
        end
    endfunction

    logic read_candidate_valid;
    logic [PROVIDER_INDEX_BITS-1:0] read_candidate_index;
    always_comb begin
        read_candidate_valid = 1'b0;
        read_candidate_index = '0;
        if (selected_valid && provider_mmio_arvalid[selected_index]) begin
            read_candidate_valid = 1'b1;
            read_candidate_index = selected_index;
        end
        for (int read_index = 0; read_index < N_PROVIDERS; read_index = read_index + 1) begin
            if (!read_candidate_valid && provider_mmio_arvalid[read_index]) begin
                read_candidate_valid = 1'b1;
                read_candidate_index = read_index[PROVIDER_INDEX_BITS-1:0];
            end
        end
    end

    logic selected_provider_idle;
    logic selected_mmio_idle;
    logic new_work_present;
    logic datapath_idle;
    logic selected_provider_fault;
    logic binding_fault_event;
    logic packet_fault;

    always_comb begin
        selected_provider_idle = 1'b1;
        selected_provider_fault = 1'b0;
        if (selected_valid) begin
            selected_provider_idle = provider_idle[selected_index];
            selected_provider_fault = provider_fault[selected_index] ||
                                      !provider_available[selected_index] ||
                                      !provider_healthy[selected_index] ||
                                      provider_generation[selected_index] != bound_provider_generation;
        end
        streams_idle = !application_send_open && !provider_recv_open &&
                       !send_buffer_valid && !recv_buffer_valid;
        selected_mmio_idle = !mmio_write_active && !mmio_read_active &&
                             !drain_write_response && !drain_read_response;
        if (selected_valid) begin
            selected_mmio_idle = selected_mmio_idle && !aw_held[selected_index] &&
                                 !w_held[selected_index];
            if (binding_state != STATE_FAULTED) begin
                selected_mmio_idle = selected_mmio_idle && !error_bvalid[selected_index] &&
                                     !error_rvalid[selected_index];
            end
        end
        mmio_idle = selected_mmio_idle;
        new_work_present = application_send_tvalid || (selected_valid && provider_recv_tvalid[selected_index]);
        if (selected_valid) begin
            new_work_present = new_work_present || provider_mmio_awvalid[selected_index] ||
                               provider_mmio_wvalid[selected_index] || provider_mmio_arvalid[selected_index];
        end
        datapath_idle = streams_idle && mmio_idle && selected_provider_idle;
        binding_fault_event =
            (binding_state == STATE_READY || binding_state == STATE_QUIESCING ||
             binding_state == STATE_QUIESCED) &&
            (application_decoupled || selected_provider_fault || packet_fault);
    end

    always_comb begin
        command_ready = !response_valid && !binding_fault_event;
        provider_selected = '0;
        provider_quiesce = '0;
        provider_abort = '0;
        provider_active_generation = '0;
        if (selected_valid) begin
            provider_selected[selected_index] = binding_state != STATE_UNBOUND;
            provider_quiesce[selected_index] = binding_state == STATE_QUIESCING ||
                                                binding_state == STATE_QUIESCED;
            provider_abort[selected_index] = binding_state == STATE_FAULTED || binding_fault_event;
            provider_active_generation[selected_index] = binding_generation;
        end
    end

    logic found_endpoint;
    logic [PROVIDER_INDEX_BITS-1:0] found_index;
    always_comb begin
        found_endpoint = 1'b0;
        found_index = '0;
        for (int lookup_index = 0; lookup_index < N_PROVIDERS; lookup_index = lookup_index + 1) begin
            if (provider_endpoint[lookup_index] == command_endpoint) begin
                found_endpoint = 1'b1;
                found_index = lookup_index[PROVIDER_INDEX_BITS-1:0];
            end
        end
    end

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            binding_state <= STATE_UNBOUND;
            binding_endpoint <= '0;
            binding_generation <= '0;
            selected_index <= '0;
            selected_valid <= 1'b0;
            bound_provider_generation <= '0;
            response_valid <= 1'b0;
            response_result <= RESULT_OK;
        end else begin
            if (response_valid && response_ready) begin
                response_valid <= 1'b0;
            end

            if (binding_fault_event) begin
                binding_state <= STATE_FAULTED;
            end else if (binding_state == STATE_QUIESCING && datapath_idle) begin
                binding_state <= STATE_QUIESCED;
            end

            if (command_valid && command_ready && !binding_fault_event) begin
                response_valid <= 1'b1;
                response_result <= RESULT_OK;
                case (command_opcode)
                    OP_BIND: begin
                        if (binding_state == STATE_FAULTED) begin
                            response_result <= RESULT_FAULTED;
                        end else if (binding_state != STATE_UNBOUND) begin
                            response_result <= RESULT_BAD_STATE;
                        end else if (application_decoupled) begin
                            response_result <= RESULT_DECOUPLED;
                        end else if (!found_endpoint) begin
                            response_result <= RESULT_ENDPOINT_NOT_FOUND;
                        end else if (command_endpoint_generation == '0 ||
                                     provider_generation[found_index] == '0 ||
                                     provider_generation[found_index] != command_endpoint_generation) begin
                            response_result <= RESULT_STALE_GENERATION;
                        end else if (!provider_available[found_index] || !provider_healthy[found_index] ||
                                     provider_fault[found_index]) begin
                            response_result <= RESULT_UNHEALTHY;
                        end else if (!provider_idle[found_index] || !streams_idle ||
                                     mmio_write_active || mmio_read_active ||
                                     aw_held[found_index] || w_held[found_index] ||
                                     error_bvalid[found_index] || error_rvalid[found_index]) begin
                            response_result <= RESULT_NOT_IDLE;
                        end else if (provider_owned[found_index]) begin
                            response_result <= RESULT_OCCUPIED;
                        end else if (provider_stream_abi[found_index] != REQUIRED_STREAM_ABI ||
                                     provider_mmio_abi[found_index] != REQUIRED_MMIO_ABI) begin
                            response_result <= RESULT_ABI_MISMATCH;
                        end else if (&binding_generation) begin
                            response_result <= RESULT_GENERATION_EXHAUSTED;
                        end else begin
                            selected_index <= found_index;
                            selected_valid <= 1'b1;
                            binding_endpoint <= command_endpoint;
                            bound_provider_generation <= command_endpoint_generation;
                            binding_generation <= binding_generation + 1'b1;
                            binding_state <= STATE_READY;
                        end
                    end
                    OP_QUIESCE: begin
                        if (command_binding_generation != binding_generation) begin
                            response_result <= RESULT_STALE_GENERATION;
                        end else if (binding_state == STATE_FAULTED) begin
                            response_result <= RESULT_FAULTED;
                        end else if (binding_state != STATE_READY &&
                                     binding_state != STATE_QUIESCING &&
                                     binding_state != STATE_QUIESCED) begin
                            response_result <= RESULT_BAD_STATE;
                        end else if (datapath_idle && !new_work_present) begin
                            binding_state <= STATE_QUIESCED;
                        end else begin
                            binding_state <= STATE_QUIESCING;
                        end
                    end
                    OP_UNBIND: begin
                        if (command_binding_generation != binding_generation) begin
                            response_result <= RESULT_STALE_GENERATION;
                        end else if (binding_state == STATE_FAULTED) begin
                            response_result <= RESULT_FAULTED;
                        end else if (binding_state != STATE_QUIESCED || !datapath_idle) begin
                            response_result <= RESULT_NOT_IDLE;
                        end else begin
                            binding_state <= STATE_UNBOUND;
                            binding_endpoint <= '0;
                            bound_provider_generation <= '0;
                            selected_valid <= 1'b0;
                        end
                    end
                    OP_RECOVER: begin
                        if (command_binding_generation != binding_generation) begin
                            response_result <= RESULT_STALE_GENERATION;
                        end else if (binding_state != STATE_FAULTED) begin
                            response_result <= RESULT_BAD_STATE;
                        end else if (application_decoupled || !datapath_idle) begin
                            response_result <= RESULT_NOT_IDLE;
                        end else begin
                            binding_state <= STATE_UNBOUND;
                            binding_endpoint <= '0;
                            bound_provider_generation <= '0;
                            selected_valid <= 1'b0;
                        end
                    end
                    default: response_result <= RESULT_BAD_STATE;
                endcase
            end
        end
    end

    always_comb begin
        application_send_tready = 1'b0;
        application_recv_tdata = recv_buffer_data;
        application_recv_tkeep = recv_buffer_keep;
        application_recv_tid = recv_buffer_id;
        application_recv_tlast = recv_buffer_last;
        application_recv_tvalid = recv_buffer_valid;
        provider_send_tdata = '0;
        provider_send_tkeep = '0;
        provider_send_tid = '0;
        provider_send_tlast = '0;
        provider_send_tvalid = '0;
        provider_send_generation = '0;
        provider_recv_tready = '0;

        // Once a beat is accepted, hold it and its routing provenance stable
        // until the destination handshakes. Fault and decouple stop admission;
        // they do not retract a beat that was already visible downstream.
        if (send_buffer_valid) begin
            provider_send_tdata[send_buffer_index] = send_buffer_data;
            provider_send_tkeep[send_buffer_index] = send_buffer_keep;
            provider_send_tid[send_buffer_index] = send_buffer_id;
            provider_send_tlast[send_buffer_index] = send_buffer_last;
            provider_send_tvalid[send_buffer_index] = 1'b1;
            provider_send_generation[send_buffer_index] = send_buffer_generation;
        end

        if (selected_valid && !binding_fault_event && !application_decoupled &&
            (binding_state == STATE_READY ||
             (binding_state == STATE_QUIESCING && application_send_open)) &&
            !send_buffer_valid) begin
            application_send_tready = valid_keep(application_send_tkeep, application_send_tlast) ?
                                      1'b1 : application_send_tvalid;
        end

        // A provider may have several complete responses committed before the
        // quiesce fence. Let those packets start and drain while quiescing;
        // provider_idle remains low until the backend has fenced new commits
        // and emptied its pre-fence queue.
        if (selected_valid && !binding_fault_event && !application_decoupled &&
            (binding_state == STATE_READY || binding_state == STATE_QUIESCING) &&
            !recv_buffer_valid &&
            provider_recv_generation[selected_index] ==
                (provider_recv_open ? provider_packet_generation : binding_generation)) begin
            provider_recv_tready[selected_index] = 1'b1;
        end

        // Responses from unselected endpoints and stale generations are
        // consumed but never presented to the application.
        for (int stream_index = 0; stream_index < N_PROVIDERS; stream_index = stream_index + 1) begin
            if ((!selected_valid || stream_index[PROVIDER_INDEX_BITS-1:0] != selected_index ||
                 provider_recv_generation[stream_index] !=
                    (provider_recv_open ? provider_packet_generation : binding_generation)) &&
                provider_recv_tvalid[stream_index]) begin
                provider_recv_tready[stream_index] = 1'b1;
            end
        end
    end

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            application_send_open <= 1'b0;
            provider_recv_open <= 1'b0;
            application_send_beats <= '0;
            provider_recv_beats <= '0;
            provider_packet_generation <= '0;
            send_buffer_valid <= 1'b0;
            send_buffer_index <= '0;
            send_buffer_data <= '0;
            send_buffer_keep <= '0;
            send_buffer_id <= '0;
            send_buffer_last <= 1'b0;
            send_buffer_generation <= '0;
            recv_buffer_valid <= 1'b0;
            recv_buffer_data <= '0;
            recv_buffer_keep <= '0;
            recv_buffer_id <= '0;
            recv_buffer_last <= 1'b0;
            recv_buffer_generation <= '0;
            stale_response_fault <= 1'b0;
            packet_fault <= 1'b0;
        end else begin
            packet_fault <= 1'b0;
            if (send_buffer_valid && provider_send_tready[send_buffer_index]) begin
                send_buffer_valid <= 1'b0;
            end
            if (recv_buffer_valid && application_recv_tready) begin
                recv_buffer_valid <= 1'b0;
            end
            if (application_send_tvalid && application_send_tready &&
                valid_keep(application_send_tkeep, application_send_tlast)) begin
                send_buffer_valid <= 1'b1;
                send_buffer_index <= selected_index;
                send_buffer_data <= application_send_tdata;
                send_buffer_keep <= application_send_tkeep;
                send_buffer_id <= application_send_tid;
                send_buffer_last <= application_send_tlast;
                send_buffer_generation <= binding_generation;
            end
            if (selected_valid && provider_recv_tvalid[selected_index] &&
                provider_recv_tready[selected_index] &&
                valid_keep(provider_recv_tkeep[selected_index], provider_recv_tlast[selected_index]) &&
                provider_recv_generation[selected_index] ==
                    (provider_recv_open ? provider_packet_generation : binding_generation)) begin
                recv_buffer_valid <= 1'b1;
                recv_buffer_data <= provider_recv_tdata[selected_index];
                recv_buffer_keep <= provider_recv_tkeep[selected_index];
                recv_buffer_id <= provider_recv_tid[selected_index];
                recv_buffer_last <= provider_recv_tlast[selected_index];
                recv_buffer_generation <= provider_recv_generation[selected_index];
            end
            if (application_send_tvalid && application_send_tready &&
                !valid_keep(application_send_tkeep, application_send_tlast)) begin
                packet_fault <= 1'b1;
            end
            if (selected_valid && provider_recv_tvalid[selected_index] &&
                provider_recv_tready[selected_index] &&
                !valid_keep(provider_recv_tkeep[selected_index], provider_recv_tlast[selected_index])) begin
                packet_fault <= 1'b1;
            end
            if (application_send_tvalid && application_send_tready &&
                valid_keep(application_send_tkeep, application_send_tlast)) begin
                if (!application_send_open) begin
                    application_send_open <= !application_send_tlast;
                    application_send_beats <= 1;
                end else if (application_send_tlast) begin
                    application_send_open <= 1'b0;
                    application_send_beats <= '0;
                end else if (application_send_beats == PACKET_COUNT_BITS'(MAX_PACKET_BEATS-1)) begin
                    packet_fault <= 1'b1;
                    application_send_open <= 1'b0;
                end else begin
                    application_send_beats <= application_send_beats + 1'b1;
                end
            end
            if (application_recv_tvalid && application_recv_tready) begin
                if (!provider_recv_open) begin
                    provider_recv_open <= !application_recv_tlast;
                    provider_recv_beats <= 1;
                    provider_packet_generation <= recv_buffer_generation;
                end else if (application_recv_tlast) begin
                    provider_recv_open <= 1'b0;
                    provider_recv_beats <= '0;
                end else if (provider_recv_beats == PACKET_COUNT_BITS'(MAX_PACKET_BEATS-1)) begin
                    packet_fault <= 1'b1;
                    provider_recv_open <= 1'b0;
                end else begin
                    provider_recv_beats <= provider_recv_beats + 1'b1;
                end
            end
            if (selected_valid && provider_recv_open && provider_recv_tvalid[selected_index] &&
                provider_recv_generation[selected_index] != provider_packet_generation) begin
                packet_fault <= 1'b1;
            end
            if (binding_fault_event || binding_state == STATE_FAULTED) begin
                application_send_open <= 1'b0;
                provider_recv_open <= 1'b0;
            end
            if (binding_fault_event) begin
                // provider_abort/application_decoupled define an epoch abort
                // for the qualified stream interfaces. Buffered old-epoch
                // beats are discarded rather than crossing recovery.
                send_buffer_valid <= 1'b0;
                recv_buffer_valid <= 1'b0;
            end
            for (int stale_index = 0; stale_index < N_PROVIDERS; stale_index = stale_index + 1) begin
                if (provider_recv_tvalid[stale_index] && provider_recv_tready[stale_index] &&
                    (!selected_valid || stale_index[PROVIDER_INDEX_BITS-1:0] != selected_index ||
                     provider_recv_generation[stale_index] != binding_generation)) begin
                    stale_response_fault <= 1'b1;
                end
            end
        end
    end

    always_comb begin
        provider_mmio_awready = '0;
        provider_mmio_wready = '0;
        provider_mmio_bresp = '0;
        provider_mmio_bvalid = error_bvalid;
        provider_mmio_arready = '0;
        provider_mmio_rdata = '0;
        provider_mmio_rresp = '0;
        provider_mmio_rvalid = error_rvalid;

        application_mmio_awaddr = mmio_write_addr;
        application_mmio_awprot = mmio_write_prot;
        application_mmio_awvalid = mmio_write_active && !mmio_aw_sent;
        application_mmio_wdata = mmio_write_data;
        application_mmio_wstrb = mmio_write_strb;
        application_mmio_wvalid = mmio_write_active && !mmio_w_sent;
        application_mmio_bready = drain_write_response ||
                                  (mmio_write_active && mmio_aw_sent && mmio_w_sent &&
                                   provider_mmio_bready[selected_index]);
        application_mmio_araddr = mmio_read_addr;
        application_mmio_arprot = mmio_read_prot;
        application_mmio_arvalid = mmio_read_active && !mmio_ar_sent;
        application_mmio_rready = drain_read_response ||
                                  (mmio_read_active && mmio_ar_sent &&
                                   provider_mmio_rready[selected_index]);

        for (int mmio_index = 0; mmio_index < N_PROVIDERS; mmio_index = mmio_index + 1) begin
            provider_mmio_awready[mmio_index] = !binding_fault_event &&
                                                !(selected_valid &&
                                                  mmio_index[PROVIDER_INDEX_BITS-1:0] == selected_index &&
                                                  binding_state == STATE_FAULTED) &&
                                                !aw_held[mmio_index] &&
                                                !error_bvalid[mmio_index] && !mmio_read_active &&
                                                !(mmio_write_active && mmio_index[PROVIDER_INDEX_BITS-1:0] == selected_index);
            provider_mmio_wready[mmio_index] = !binding_fault_event &&
                                               !(selected_valid &&
                                                 mmio_index[PROVIDER_INDEX_BITS-1:0] == selected_index &&
                                                 binding_state == STATE_FAULTED) &&
                                               !w_held[mmio_index] &&
                                               !error_bvalid[mmio_index] && !mmio_read_active &&
                                               !(mmio_write_active && mmio_index[PROVIDER_INDEX_BITS-1:0] == selected_index);
            provider_mmio_arready[mmio_index] = !binding_fault_event && read_candidate_valid &&
                                                !(selected_valid &&
                                                  mmio_index[PROVIDER_INDEX_BITS-1:0] == selected_index &&
                                                  binding_state == STATE_FAULTED) &&
                                                mmio_index[PROVIDER_INDEX_BITS-1:0] == read_candidate_index &&
                                                !error_rvalid[mmio_index] &&
                                                !mmio_read_active && !mmio_write_active &&
                                                (!selected_valid || read_candidate_index != selected_index ||
                                                 (!aw_held[selected_index] && !w_held[selected_index]));
            if (error_bvalid[mmio_index]) begin
                provider_mmio_bresp[mmio_index] = error_bresp[mmio_index];
            end
            if (error_rvalid[mmio_index]) begin
                provider_mmio_rresp[mmio_index] = error_rresp[mmio_index];
                provider_mmio_rdata[mmio_index] = error_rdata[mmio_index];
            end
        end

        if (mmio_write_active && selected_valid && !drain_write_response) begin
            provider_mmio_bvalid[selected_index] = application_mmio_bvalid && mmio_aw_sent && mmio_w_sent;
            provider_mmio_bresp[selected_index] = application_mmio_bresp;
        end
        if (mmio_read_active && selected_valid && !drain_read_response) begin
            provider_mmio_rvalid[selected_index] = application_mmio_rvalid && mmio_ar_sent;
            provider_mmio_rresp[selected_index] = application_mmio_rresp;
            provider_mmio_rdata[selected_index] = application_mmio_rdata;
        end
    end

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            mmio_write_active <= 1'b0;
            mmio_read_active <= 1'b0;
            mmio_aw_sent <= 1'b0;
            mmio_w_sent <= 1'b0;
            mmio_ar_sent <= 1'b0;
            drain_write_response <= 1'b0;
            drain_read_response <= 1'b0;
            mmio_write_addr <= '0;
            mmio_write_prot <= '0;
            mmio_write_data <= '0;
            mmio_write_strb <= '0;
            mmio_read_addr <= '0;
            mmio_read_prot <= '0;
            error_bvalid <= '0;
            error_bresp <= '0;
            error_rvalid <= '0;
            error_rresp <= '0;
            error_rdata <= '0;
            aw_held <= '0;
            w_held <= '0;
            held_awaddr <= '0;
            held_awprot <= '0;
            held_aw_generation <= '0;
            held_wdata <= '0;
            held_wstrb <= '0;
            held_w_generation <= '0;
        end else begin
            for (int request_index = 0; request_index < N_PROVIDERS; request_index = request_index + 1) begin
                if (provider_mmio_awvalid[request_index] && provider_mmio_awready[request_index]) begin
                    aw_held[request_index] <= 1'b1;
                    held_awaddr[request_index] <= provider_mmio_awaddr[request_index];
                    held_awprot[request_index] <= provider_mmio_awprot[request_index];
                    held_aw_generation[request_index] <= provider_mmio_generation[request_index];
                end
                if (provider_mmio_wvalid[request_index] && provider_mmio_wready[request_index]) begin
                    w_held[request_index] <= 1'b1;
                    held_wdata[request_index] <= provider_mmio_wdata[request_index];
                    held_wstrb[request_index] <= provider_mmio_wstrb[request_index];
                    held_w_generation[request_index] <= provider_mmio_generation[request_index];
                end
                if (error_bvalid[request_index] && provider_mmio_bready[request_index]) begin
                    error_bvalid[request_index] <= 1'b0;
                end
                if (error_rvalid[request_index] && provider_mmio_rready[request_index]) begin
                    error_rvalid[request_index] <= 1'b0;
                end
                if (provider_mmio_arvalid[request_index] && provider_mmio_arready[request_index]) begin
                    if (selected_valid && request_index[PROVIDER_INDEX_BITS-1:0] == selected_index &&
                        provider_mmio_generation[request_index] == binding_generation &&
                        binding_state == STATE_READY && !application_decoupled &&
                        !binding_fault_event && !mmio_read_active && !mmio_write_active) begin
                        mmio_read_active <= 1'b1;
                        mmio_ar_sent <= 1'b0;
                        mmio_read_addr <= provider_mmio_araddr[request_index];
                        mmio_read_prot <= provider_mmio_arprot[request_index];
                    end else begin
                        error_rvalid[request_index] <= 1'b1;
                        error_rresp[request_index] <= 2'b11;
                        error_rdata[request_index] <= '0;
                    end
                end
                if ((aw_held[request_index] ||
                     (provider_mmio_awvalid[request_index] && provider_mmio_awready[request_index])) &&
                    (w_held[request_index] ||
                     (provider_mmio_wvalid[request_index] && provider_mmio_wready[request_index])) &&
                    !error_bvalid[request_index] &&
                    !(mmio_write_active && request_index[PROVIDER_INDEX_BITS-1:0] == selected_index)) begin
                    if (selected_valid && request_index[PROVIDER_INDEX_BITS-1:0] == selected_index &&
                        (aw_held[request_index] ? held_aw_generation[request_index]
                                                : provider_mmio_generation[request_index]) == binding_generation &&
                        (w_held[request_index] ? held_w_generation[request_index]
                                               : provider_mmio_generation[request_index]) == binding_generation &&
                        binding_state == STATE_READY && !application_decoupled &&
                        !binding_fault_event && !mmio_write_active && !mmio_read_active) begin
                        mmio_write_active <= 1'b1;
                        mmio_aw_sent <= 1'b0;
                        mmio_w_sent <= 1'b0;
                        mmio_write_addr <= aw_held[request_index] ? held_awaddr[request_index]
                                                                  : provider_mmio_awaddr[request_index];
                        mmio_write_prot <= aw_held[request_index] ? held_awprot[request_index]
                                                                  : provider_mmio_awprot[request_index];
                        mmio_write_data <= w_held[request_index] ? held_wdata[request_index]
                                                                 : provider_mmio_wdata[request_index];
                        mmio_write_strb <= w_held[request_index] ? held_wstrb[request_index]
                                                                 : provider_mmio_wstrb[request_index];
                    end else begin
                        error_bvalid[request_index] <= 1'b1;
                        error_bresp[request_index] <= 2'b11;
                        aw_held[request_index] <= 1'b0;
                        w_held[request_index] <= 1'b0;
                    end
                end
            end

            if (mmio_write_active) begin
                if (application_mmio_awvalid && application_mmio_awready) begin
                    mmio_aw_sent <= 1'b1;
                end
                if (application_mmio_wvalid && application_mmio_wready) begin
                    mmio_w_sent <= 1'b1;
                end
                if (application_mmio_bvalid && application_mmio_bready && mmio_aw_sent && mmio_w_sent) begin
                    mmio_write_active <= 1'b0;
                    aw_held[selected_index] <= 1'b0;
                    w_held[selected_index] <= 1'b0;
                end
            end
            if (mmio_read_active && application_mmio_arvalid && application_mmio_arready) begin
                mmio_ar_sent <= 1'b1;
            end
            if (mmio_read_active && mmio_ar_sent && application_mmio_rvalid && application_mmio_rready) begin
                mmio_read_active <= 1'b0;
                mmio_ar_sent <= 1'b0;
            end
            if (drain_write_response && application_mmio_bvalid && application_mmio_bready) begin
                drain_write_response <= 1'b0;
            end
            if (drain_read_response && application_mmio_rvalid && application_mmio_rready) begin
                drain_read_response <= 1'b0;
            end

            // Decouple is an application-epoch reset: the application-side
            // isolator discards any partial AXI-Lite slave state. Never send a
            // captured partner channel into a replacement application. Other
            // provider faults leave the application epoch intact, so a split
            // write is completed from captured data and its response drained.
            if ((binding_fault_event ||
                 (application_decoupled && binding_state == STATE_FAULTED)) && selected_valid) begin
                if (application_decoupled) begin
                    if (mmio_write_active &&
                        !(mmio_aw_sent && mmio_w_sent &&
                          application_mmio_bvalid && provider_mmio_bready[selected_index])) begin
                        error_bvalid[selected_index] <= 1'b1;
                        error_bresp[selected_index] <= 2'b10;
                    end
                    if (mmio_read_active &&
                        !(mmio_ar_sent && application_mmio_rvalid &&
                          provider_mmio_rready[selected_index])) begin
                        error_rvalid[selected_index] <= 1'b1;
                        error_rresp[selected_index] <= 2'b10;
                        error_rdata[selected_index] <= '0;
                    end
                    mmio_write_active <= 1'b0;
                    mmio_read_active <= 1'b0;
                    mmio_aw_sent <= 1'b0;
                    mmio_w_sent <= 1'b0;
                    mmio_ar_sent <= 1'b0;
                    drain_write_response <= 1'b0;
                    drain_read_response <= 1'b0;
                    aw_held[selected_index] <= 1'b0;
                    w_held[selected_index] <= 1'b0;
                end else begin
                    // A provider-side transaction is complete only after both
                    // AW and W were accepted into mmio_write_active. A lone
                    // held half is discarded under provider_abort without
                    // fabricating an AXI B response.
                    if (mmio_write_active) begin
                        if (!(mmio_aw_sent && mmio_w_sent &&
                              application_mmio_bvalid && provider_mmio_bready[selected_index])) begin
                            error_bvalid[selected_index] <= 1'b1;
                            error_bresp[selected_index] <=
                                (mmio_aw_sent && mmio_w_sent && application_mmio_bvalid) ?
                                    application_mmio_bresp : 2'b10;
                            if (mmio_aw_sent || mmio_w_sent ||
                                (application_mmio_awvalid && application_mmio_awready) ||
                                (application_mmio_wvalid && application_mmio_wready)) begin
                                mmio_aw_sent <= mmio_aw_sent ||
                                                (application_mmio_awvalid && application_mmio_awready);
                                mmio_w_sent <= mmio_w_sent ||
                                               (application_mmio_wvalid && application_mmio_wready);
                                drain_write_response <= 1'b1;
                            end else begin
                                mmio_write_active <= 1'b0;
                                mmio_aw_sent <= 1'b0;
                                mmio_w_sent <= 1'b0;
                            end
                        end
                    end
                    aw_held[selected_index] <= 1'b0;
                    w_held[selected_index] <= 1'b0;
                    if (mmio_read_active) begin
                        if (!(mmio_ar_sent && application_mmio_rvalid &&
                              provider_mmio_rready[selected_index])) begin
                            error_rvalid[selected_index] <= 1'b1;
                            error_rresp[selected_index] <=
                                (mmio_ar_sent && application_mmio_rvalid) ?
                                    application_mmio_rresp : 2'b10;
                            error_rdata[selected_index] <=
                                (mmio_ar_sent && application_mmio_rvalid) ?
                                    application_mmio_rdata : '0;
                            if (mmio_ar_sent ||
                                (application_mmio_arvalid && application_mmio_arready)) begin
                                drain_read_response <= 1'b1;
                            end
                        end
                        mmio_read_active <= 1'b0;
                        mmio_ar_sent <= 1'b0;
                    end
                end
            end

            // Fault recovery discards an unconsumed synthetic response only
            // after all downstream responses have drained.
            if (command_valid && command_ready && command_opcode == OP_RECOVER &&
                binding_state == STATE_FAULTED &&
                command_binding_generation == binding_generation &&
                !application_decoupled && datapath_idle && selected_valid) begin
                error_bvalid[selected_index] <= 1'b0;
                error_rvalid[selected_index] <= 1'b0;
            end
        end
    end

`ifndef SYNTHESIS
    property stable_binding_during_application_packet;
        @(posedge aclk) disable iff (!aresetn)
        application_send_open |=> $stable(binding_endpoint) && $stable(binding_generation);
    endproperty
    assert property(stable_binding_during_application_packet);

    property no_new_application_stream_when_unavailable;
        @(posedge aclk) disable iff (!aresetn)
        (binding_state == STATE_UNBOUND || binding_state == STATE_FAULTED || application_decoupled)
        |-> !application_send_tready;
    endproperty
    assert property(no_new_application_stream_when_unavailable);

    property stable_provider_stream_under_backpressure;
        @(posedge aclk) disable iff (!aresetn || binding_fault_event || binding_state == STATE_FAULTED)
        send_buffer_valid && !provider_send_tready[send_buffer_index]
        |=> provider_send_tready[send_buffer_index] ||
            (send_buffer_valid && $stable(send_buffer_index) &&
             $stable(send_buffer_data) && $stable(send_buffer_keep) &&
             $stable(send_buffer_id) && $stable(send_buffer_last) &&
             $stable(send_buffer_generation));
    endproperty
    assert property(stable_provider_stream_under_backpressure);

    property stable_application_stream_under_backpressure;
        @(posedge aclk) disable iff (!aresetn || binding_fault_event || binding_state == STATE_FAULTED)
        application_recv_tvalid && !application_recv_tready
        |=> application_recv_tready ||
            (application_recv_tvalid && $stable(application_recv_tdata) &&
             $stable(application_recv_tkeep) && $stable(application_recv_tid) &&
             $stable(application_recv_tlast));
    endproperty
    assert property(stable_application_stream_under_backpressure);
`endif

endmodule
