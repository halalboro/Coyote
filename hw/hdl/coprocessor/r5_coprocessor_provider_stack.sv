`timescale 1ns / 1ps

module r5_coprocessor_provider_stack (
    input logic aclk,
    input logic aresetn,
    input logic application_decoupled,

    input logic [31:0] cpu_awaddr,
    input logic [2:0] cpu_awprot,
    input logic cpu_awvalid,
    output logic cpu_awready,
    input logic [31:0] cpu_wdata,
    input logic [3:0] cpu_wstrb,
    input logic cpu_wvalid,
    output logic cpu_wready,
    output logic [1:0] cpu_bresp,
    output logic cpu_bvalid,
    input logic cpu_bready,
    input logic [31:0] cpu_araddr,
    input logic [2:0] cpu_arprot,
    input logic cpu_arvalid,
    output logic cpu_arready,
    output logic [31:0] cpu_rdata,
    output logic [1:0] cpu_rresp,
    output logic cpu_rvalid,
    input logic cpu_rready,

    input logic [11:0] control_awaddr,
    input logic [2:0] control_awprot,
    input logic control_awvalid,
    output logic control_awready,
    input logic [63:0] control_wdata,
    input logic [7:0] control_wstrb,
    input logic control_wvalid,
    output logic control_wready,
    output logic [1:0] control_bresp,
    output logic control_bvalid,
    input logic control_bready,
    input logic [11:0] control_araddr,
    input logic [2:0] control_arprot,
    input logic control_arvalid,
    output logic control_arready,
    output logic [63:0] control_rdata,
    output logic [1:0] control_rresp,
    output logic control_rvalid,
    input logic control_rready,

    input logic [511:0] application_send_tdata,
    input logic [63:0] application_send_tkeep,
    input logic [5:0] application_send_tid,
    input logic application_send_tlast,
    input logic application_send_tvalid,
    output logic application_send_tready,
    output logic [511:0] application_recv_tdata,
    output logic [63:0] application_recv_tkeep,
    output logic [5:0] application_recv_tid,
    output logic application_recv_tlast,
    output logic application_recv_tvalid,
    input logic application_recv_tready,

    output logic [11:0] application_mmio_awaddr,
    output logic [2:0] application_mmio_awprot,
    output logic application_mmio_awvalid,
    input logic application_mmio_awready,
    output logic [63:0] application_mmio_wdata,
    output logic [7:0] application_mmio_wstrb,
    output logic application_mmio_wvalid,
    input logic application_mmio_wready,
    input logic [1:0] application_mmio_bresp,
    input logic application_mmio_bvalid,
    output logic application_mmio_bready,
    output logic [11:0] application_mmio_araddr,
    output logic [2:0] application_mmio_arprot,
    output logic application_mmio_arvalid,
    input logic application_mmio_arready,
    input logic [63:0] application_mmio_rdata,
    input logic [1:0] application_mmio_rresp,
    input logic application_mmio_rvalid,
    output logic application_mmio_rready,

    output logic status_bound,
    output logic status_ready,
    output logic status_fault,
    output logic status_quiesced,
    output logic status_idle,
    output logic [2:0] status_state,
    output logic [15:0] status_endpoint,
    output logic [31:0] status_generation
);
    logic provider_available;
    logic provider_healthy;
    logic provider_idle;
    logic provider_fault;
    logic [31:0] endpoint_generation;
    logic [15:0] firmware_runtime_abi;
    logic [15:0] firmware_abi_id;
    logic [255:0] firmware_image_identity;
    logic provider_selected;
    logic provider_quiesce;
    logic provider_abort;
    logic [31:0] provider_active_generation;

    logic [511:0] provider_send_tdata;
    logic [63:0] provider_send_tkeep;
    logic [5:0] provider_send_tid;
    logic provider_send_tlast;
    logic provider_send_tvalid;
    logic provider_send_tready;
    logic [31:0] provider_send_generation;
    logic [511:0] provider_recv_tdata;
    logic [63:0] provider_recv_tkeep;
    logic [5:0] provider_recv_tid;
    logic provider_recv_tlast;
    logic provider_recv_tvalid;
    logic provider_recv_tready;
    logic [31:0] provider_recv_generation;

    logic [31:0] provider_mmio_generation;
    logic [11:0] provider_mmio_awaddr;
    logic [2:0] provider_mmio_awprot;
    logic provider_mmio_awvalid;
    logic provider_mmio_awready;
    logic [63:0] provider_mmio_wdata;
    logic [7:0] provider_mmio_wstrb;
    logic provider_mmio_wvalid;
    logic provider_mmio_wready;
    logic [1:0] provider_mmio_bresp;
    logic provider_mmio_bvalid;
    logic provider_mmio_bready;
    logic [11:0] provider_mmio_araddr;
    logic [2:0] provider_mmio_arprot;
    logic provider_mmio_arvalid;
    logic provider_mmio_arready;
    logic [63:0] provider_mmio_rdata;
    logic [1:0] provider_mmio_rresp;
    logic provider_mmio_rvalid;
    logic provider_mmio_rready;

    logic command_valid;
    logic command_ready;
    logic [2:0] command_opcode;
    logic [15:0] command_endpoint;
    logic [31:0] command_binding_generation;
    logic [31:0] command_endpoint_generation;
    logic response_valid;
    logic response_ready;
    logic [3:0] response_result;
    logic management_recover;
    logic streams_idle;
    logic mmio_idle;
    logic stale_response_fault;

    r5_packet_queue_provider inst_backend (
        .aclk(aclk), .aresetn(aresetn),
        .provider_selected(provider_selected), .provider_quiesce(provider_quiesce),
        .provider_abort(provider_abort), .management_recover(management_recover),
        .active_generation(provider_active_generation),
        .provider_available(provider_available), .provider_healthy(provider_healthy),
        .provider_idle(provider_idle), .provider_fault(provider_fault),
        .endpoint_generation(endpoint_generation),
        .firmware_runtime_abi(firmware_runtime_abi), .firmware_abi_id(firmware_abi_id),
        .firmware_image_identity(firmware_image_identity),
        .s_axi_awaddr(cpu_awaddr[15:0]), .s_axi_awprot(cpu_awprot),
        .s_axi_awvalid(cpu_awvalid), .s_axi_awready(cpu_awready),
        .s_axi_wdata(cpu_wdata), .s_axi_wstrb(cpu_wstrb),
        .s_axi_wvalid(cpu_wvalid), .s_axi_wready(cpu_wready),
        .s_axi_bresp(cpu_bresp), .s_axi_bvalid(cpu_bvalid), .s_axi_bready(cpu_bready),
        .s_axi_araddr(cpu_araddr[15:0]), .s_axi_arprot(cpu_arprot),
        .s_axi_arvalid(cpu_arvalid), .s_axi_arready(cpu_arready),
        .s_axi_rdata(cpu_rdata), .s_axi_rresp(cpu_rresp),
        .s_axi_rvalid(cpu_rvalid), .s_axi_rready(cpu_rready),
        .s_axis_request_tdata(provider_send_tdata),
        .s_axis_request_tkeep(provider_send_tkeep), .s_axis_request_tid(provider_send_tid),
        .s_axis_request_tlast(provider_send_tlast), .s_axis_request_tvalid(provider_send_tvalid),
        .s_axis_request_tready(provider_send_tready),
        .s_axis_request_generation(provider_send_generation),
        .m_axis_response_tdata(provider_recv_tdata),
        .m_axis_response_tkeep(provider_recv_tkeep), .m_axis_response_tid(provider_recv_tid),
        .m_axis_response_tlast(provider_recv_tlast), .m_axis_response_tvalid(provider_recv_tvalid),
        .m_axis_response_tready(provider_recv_tready),
        .m_axis_response_generation(provider_recv_generation),
        .provider_mmio_generation(provider_mmio_generation),
        .provider_mmio_awaddr(provider_mmio_awaddr), .provider_mmio_awprot(provider_mmio_awprot),
        .provider_mmio_awvalid(provider_mmio_awvalid), .provider_mmio_awready(provider_mmio_awready),
        .provider_mmio_wdata(provider_mmio_wdata), .provider_mmio_wstrb(provider_mmio_wstrb),
        .provider_mmio_wvalid(provider_mmio_wvalid), .provider_mmio_wready(provider_mmio_wready),
        .provider_mmio_bresp(provider_mmio_bresp), .provider_mmio_bvalid(provider_mmio_bvalid),
        .provider_mmio_bready(provider_mmio_bready),
        .provider_mmio_araddr(provider_mmio_araddr), .provider_mmio_arprot(provider_mmio_arprot),
        .provider_mmio_arvalid(provider_mmio_arvalid), .provider_mmio_arready(provider_mmio_arready),
        .provider_mmio_rdata(provider_mmio_rdata), .provider_mmio_rresp(provider_mmio_rresp),
        .provider_mmio_rvalid(provider_mmio_rvalid), .provider_mmio_rready(provider_mmio_rready)
    );

    coprocessor_port_gateway #(.N_PROVIDERS(1)) inst_gateway (
        .aclk(aclk), .aresetn(aresetn), .application_decoupled(application_decoupled),
        .command_valid(command_valid), .command_ready(command_ready),
        .command_opcode(command_opcode), .command_endpoint(command_endpoint),
        .command_binding_generation(command_binding_generation),
        .command_endpoint_generation(command_endpoint_generation),
        .response_valid(response_valid), .response_ready(response_ready),
        .response_result(response_result),
        .provider_endpoint(16'(16'd1)), .provider_stream_abi(16'(16'd1)),
        .provider_mmio_abi(16'(16'd1)), .provider_generation(endpoint_generation),
        .provider_available(provider_available), .provider_healthy(provider_healthy),
        .provider_owned(1'b0), .provider_idle(provider_idle), .provider_fault(provider_fault),
        .provider_selected(provider_selected), .provider_quiesce(provider_quiesce),
        .provider_abort(provider_abort), .provider_active_generation(provider_active_generation),
        .application_send_tdata(application_send_tdata),
        .application_send_tkeep(application_send_tkeep), .application_send_tid(application_send_tid),
        .application_send_tlast(application_send_tlast), .application_send_tvalid(application_send_tvalid),
        .application_send_tready(application_send_tready),
        .application_recv_tdata(application_recv_tdata),
        .application_recv_tkeep(application_recv_tkeep), .application_recv_tid(application_recv_tid),
        .application_recv_tlast(application_recv_tlast), .application_recv_tvalid(application_recv_tvalid),
        .application_recv_tready(application_recv_tready),
        .provider_send_tdata(provider_send_tdata), .provider_send_tkeep(provider_send_tkeep),
        .provider_send_tid(provider_send_tid), .provider_send_tlast(provider_send_tlast),
        .provider_send_tvalid(provider_send_tvalid), .provider_send_tready(provider_send_tready),
        .provider_send_generation(provider_send_generation),
        .provider_recv_tdata(provider_recv_tdata), .provider_recv_tkeep(provider_recv_tkeep),
        .provider_recv_tid(provider_recv_tid), .provider_recv_tlast(provider_recv_tlast),
        .provider_recv_tvalid(provider_recv_tvalid), .provider_recv_tready(provider_recv_tready),
        .provider_recv_generation(provider_recv_generation),
        .provider_mmio_generation(provider_mmio_generation),
        .provider_mmio_awaddr(provider_mmio_awaddr), .provider_mmio_awprot(provider_mmio_awprot),
        .provider_mmio_awvalid(provider_mmio_awvalid), .provider_mmio_awready(provider_mmio_awready),
        .provider_mmio_wdata(provider_mmio_wdata), .provider_mmio_wstrb(provider_mmio_wstrb),
        .provider_mmio_wvalid(provider_mmio_wvalid), .provider_mmio_wready(provider_mmio_wready),
        .provider_mmio_bresp(provider_mmio_bresp), .provider_mmio_bvalid(provider_mmio_bvalid),
        .provider_mmio_bready(provider_mmio_bready),
        .provider_mmio_araddr(provider_mmio_araddr), .provider_mmio_arprot(provider_mmio_arprot),
        .provider_mmio_arvalid(provider_mmio_arvalid), .provider_mmio_arready(provider_mmio_arready),
        .provider_mmio_rdata(provider_mmio_rdata), .provider_mmio_rresp(provider_mmio_rresp),
        .provider_mmio_rvalid(provider_mmio_rvalid), .provider_mmio_rready(provider_mmio_rready),
        .application_mmio_awaddr(application_mmio_awaddr),
        .application_mmio_awprot(application_mmio_awprot),
        .application_mmio_awvalid(application_mmio_awvalid),
        .application_mmio_awready(application_mmio_awready),
        .application_mmio_wdata(application_mmio_wdata),
        .application_mmio_wstrb(application_mmio_wstrb),
        .application_mmio_wvalid(application_mmio_wvalid),
        .application_mmio_wready(application_mmio_wready),
        .application_mmio_bresp(application_mmio_bresp),
        .application_mmio_bvalid(application_mmio_bvalid),
        .application_mmio_bready(application_mmio_bready),
        .application_mmio_araddr(application_mmio_araddr),
        .application_mmio_arprot(application_mmio_arprot),
        .application_mmio_arvalid(application_mmio_arvalid),
        .application_mmio_arready(application_mmio_arready),
        .application_mmio_rdata(application_mmio_rdata),
        .application_mmio_rresp(application_mmio_rresp),
        .application_mmio_rvalid(application_mmio_rvalid),
        .application_mmio_rready(application_mmio_rready),
        .binding_state(status_state), .binding_endpoint(status_endpoint),
        .binding_generation(status_generation), .streams_idle(streams_idle),
        .mmio_idle(mmio_idle), .stale_response_fault(stale_response_fault)
    );

    coprocessor_control_target inst_control (
        .aclk(aclk), .aresetn(aresetn),
        .provider_available(provider_available), .provider_healthy(provider_healthy),
        .provider_idle(provider_idle), .provider_fault(provider_fault),
        .provider_generation(endpoint_generation),
        .firmware_runtime_abi(firmware_runtime_abi), .firmware_abi_id(firmware_abi_id),
        .firmware_image_identity(firmware_image_identity), .binding_state(status_state),
        .binding_endpoint(status_endpoint), .binding_generation(status_generation),
        .streams_idle(streams_idle), .mmio_idle(mmio_idle),
        .stale_response_fault(stale_response_fault),
        .command_valid(command_valid), .command_ready(command_ready),
        .command_opcode(command_opcode), .command_endpoint(command_endpoint),
        .command_binding_generation(command_binding_generation),
        .command_endpoint_generation(command_endpoint_generation),
        .response_valid(response_valid), .response_ready(response_ready),
        .response_result(response_result), .management_recover(management_recover),
        .s_axi_awaddr(control_awaddr), .s_axi_awprot(control_awprot),
        .s_axi_awvalid(control_awvalid), .s_axi_awready(control_awready),
        .s_axi_wdata(control_wdata), .s_axi_wstrb(control_wstrb),
        .s_axi_wvalid(control_wvalid), .s_axi_wready(control_wready),
        .s_axi_bresp(control_bresp), .s_axi_bvalid(control_bvalid),
        .s_axi_bready(control_bready), .s_axi_araddr(control_araddr),
        .s_axi_arprot(control_arprot), .s_axi_arvalid(control_arvalid),
        .s_axi_arready(control_arready), .s_axi_rdata(control_rdata),
        .s_axi_rresp(control_rresp), .s_axi_rvalid(control_rvalid),
        .s_axi_rready(control_rready)
    );

    always_comb begin
        status_bound = status_state != 3'd0;
        status_ready = status_state == 3'd1 && provider_healthy;
        status_fault = status_state == 3'd4 || provider_fault || stale_response_fault;
        status_quiesced = status_state == 3'd3;
        status_idle = streams_idle && mmio_idle && provider_idle;
    end
endmodule
