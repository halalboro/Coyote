// Generator : SpinalHDL v1.9.3    git head : 029104c77a54c53f1edda327a3bea333f7d65fd9
// Component : MicroBlossomBus

`timescale 1ns/1ps

module MicroBlossomBus (
  input               s0_awvalid,
  output              s0_awready,
  input      [22:0]   s0_awaddr,
  input      [2:0]    s0_awprot,
  input               s0_wvalid,
  output              s0_wready,
  input      [63:0]   s0_wdata,
  input      [7:0]    s0_wstrb,
  output              s0_bvalid,
  input               s0_bready,
  output     [1:0]    s0_bresp,
  input               s0_arvalid,
  output reg          s0_arready,
  input      [22:0]   s0_araddr,
  input      [2:0]    s0_arprot,
  output              s0_rvalid,
  input               s0_rready,
  output     [63:0]   s0_rdata,
  output     [1:0]    s0_rresp,
  input               slow_clk,
  input               clk,
  input               reset
);
  localparam fsm_enumDef_BOOT = 15'd1;
  localparam fsm_enumDef_stateIdle = 15'd2;
  localparam fsm_enumDef_stateUpdateMaximumGrowth = 15'd4;
  localparam fsm_enumDef_stateReadParityReports = 15'd8;
  localparam fsm_enumDef_stateReadMaximumGrowth = 15'd16;
  localparam fsm_enumDef_stateReadObstacle = 15'd32;
  localparam fsm_enumDef_stateReadIssueFindObstacleWaitPending = 15'd64;
  localparam fsm_enumDef_stateReadIssueFindObstacle = 15'd128;
  localparam fsm_enumDef_stateReadIssueFindObstaclePause = 15'd256;
  localparam fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush = 15'd512;
  localparam fsm_enumDef_stateReadLoadTime = 15'd1024;
  localparam fsm_enumDef_stateReadFinishTime = 15'd2048;
  localparam fsm_enumDef_stateRead = 15'd4096;
  localparam fsm_enumDef_stateWriteInstruction = 15'd8192;
  localparam fsm_enumDef_stateWriteWaitFiFoPush = 15'd16384;
  localparam rsp_enumDef_BOOT = 2'd1;
  localparam rsp_enumDef_stateIdle = 2'd2;

  reg                 streamFifo_1_io_push_valid;
  reg        [11:0]   streamFifo_1_io_push_payload_instruction;
  reg        [15:0]   streamFifo_1_io_push_payload_maximumGrowth;
  reg        [3:0]    streamFifo_1_io_push_payload_tag_instructionId;
  reg                 streamFifo_1_io_push_payload_tag_isFindObstacle;
  reg        [15:0]   streamFifo_1_io_push_payload_tag_accumulatedGrown;
  reg                 slow_microBlossom_io_pop_ready;
  wire                streamFifo_1_io_push_ready;
  wire                streamFifo_1_io_pop_valid;
  wire       [11:0]   streamFifo_1_io_pop_payload_instruction;
  wire       [15:0]   streamFifo_1_io_pop_payload_maximumGrowth;
  wire       [3:0]    streamFifo_1_io_pop_payload_tag_instructionId;
  wire                streamFifo_1_io_pop_payload_tag_isFindObstacle;
  wire       [15:0]   streamFifo_1_io_pop_payload_tag_accumulatedGrown;
  wire       [2:0]    streamFifo_1_io_occupancy;
  wire       [2:0]    streamFifo_1_io_availability;
  wire                slow_microBlossom_io_push_ready;
  wire                slow_microBlossom_io_pop_valid;
  wire       [1:0]    slow_microBlossom_io_pop_payload_maxGrowable_length;
  wire       [4:0]    slow_microBlossom_io_pop_payload_conflict_node1;
  wire       [4:0]    slow_microBlossom_io_pop_payload_conflict_node2;
  wire       [4:0]    slow_microBlossom_io_pop_payload_conflict_touch1;
  wire       [4:0]    slow_microBlossom_io_pop_payload_conflict_touch2;
  wire       [4:0]    slow_microBlossom_io_pop_payload_conflict_vertex1;
  wire       [4:0]    slow_microBlossom_io_pop_payload_conflict_vertex2;
  wire                slow_microBlossom_io_pop_payload_conflict_valid;
  wire       [15:0]   slow_microBlossom_io_pop_payload_grown;
  wire       [3:0]    slow_microBlossom_io_pop_payload_tag_instructionId;
  wire                slow_microBlossom_io_pop_payload_tag_isFindObstacle;
  wire       [15:0]   slow_microBlossom_io_pop_payload_tag_accumulatedGrown;
  wire                slow_microBlossom_io_dataLoss;
  wire       [9:0]    _zz_readout_contextIdRaw;
  wire       [16:0]   _zz_readout_contextIdRaw_1;
  wire       [22:0]   _zz_readout_contextIdRaw_2;
  wire       [22:0]   _zz_readout_subAddress;
  wire       [16:0]   _zz_readout_writeContextIdRaw;
  wire       [22:0]   _zz_readout_writeContextIdRaw_1;
  wire       [22:0]   _zz_readout_writeSubAddress;
  wire       [14:0]   _zz_resizedInstruction;
  wire       [14:0]   _zz_resizedInstruction_1;
  wire       [14:0]   _zz_resizedInstruction_2;
  wire       [14:0]   _zz_resizedInstruction_3;
  wire       [14:0]   _zz_resizedInstruction_4;
  wire       [25:0]   _zz_resizedInstruction_5;
  wire       [14:0]   _zz_resizedInstruction_6;
  wire       [10:0]   _zz_resizedInstruction_7;
  wire       [14:0]   _zz_resizedInstruction_8;
  wire       [14:0]   _zz_resizedInstruction_9;
  wire       [31:0]   _zz_hardwareInfo_instructionCounter;
  wire       [31:0]   _zz_hardwareInfo_instructionCounter_1;
  wire       [31:0]   _zz_hardwareInfo_readoutCounter;
  wire       [31:0]   _zz_hardwareInfo_readoutCounter_1;
  wire       [31:0]   _zz_hardwareInfo_transactionCounter;
  wire       [31:0]   _zz_hardwareInfo_transactionCounter_1;
  wire       [31:0]   _zz_hardwareInfo_errorCounter;
  wire       [31:0]   _zz_hardwareInfo_errorCounter_1;
  wire       [63:0]   _zz_rawFactory_readRsp_data;
  wire       [63:0]   _zz_rawFactory_readRsp_data_1;
  wire       [55:0]   _zz_rawFactory_readRsp_data_2;
  wire       [31:0]   _zz_rawFactory_readRsp_data_3;
  wire       [31:0]   _zz_rawFactory_readRsp_data_4;
  wire       [31:0]   _zz_rawFactory_readRsp_data_5;
  wire       [31:0]   _zz_rawFactory_readRsp_data_6;
  wire       [22:0]   _zz_when_MicroBlossomBus_l423;
  wire       [22:0]   _zz_when_MicroBlossomBus_l449;
  wire       [22:0]   _zz_when_MicroBlossomBus_l452;
  wire       [7:0]    _zz_readout_value;
  wire       [0:0]    _zz_readout_value_1;
  wire                rawFactory_readErrorFlag;
  wire                rawFactory_writeErrorFlag;
  reg                 rawFactory_readHaltRequest;
  reg                 rawFactory_writeHaltRequest;
  wire                rawFactory_writeJoinEvent_valid;
  wire                rawFactory_writeJoinEvent_ready;
  wire                rawFactory_writeOccur;
  reg        [1:0]    rawFactory_writeRsp_resp;
  wire                rawFactory_writeJoinEvent_translated_valid;
  wire                rawFactory_writeJoinEvent_translated_ready;
  wire       [1:0]    rawFactory_writeJoinEvent_translated_payload_resp;
  wire                _zz_rawFactory_writeJoinEvent_translated_ready;
  reg                 _zz_rawFactory_writeJoinEvent_translated_ready_1;
  wire                _zz_s0_bvalid;
  reg                 _zz_s0_bvalid_1;
  reg        [1:0]    _zz_s0_bresp;
  wire                when_Stream_l369;
  wire                rawFactory_readDataStage_valid;
  wire                rawFactory_readDataStage_ready;
  wire       [22:0]   rawFactory_readDataStage_payload_addr;
  wire       [2:0]    rawFactory_readDataStage_payload_prot;
  reg                 io_s0_ar_rValid;
  reg        [22:0]   io_s0_ar_rData_addr;
  reg        [2:0]    io_s0_ar_rData_prot;
  wire                when_Stream_l369_1;
  reg        [63:0]   rawFactory_readRsp_data;
  reg        [1:0]    rawFactory_readRsp_resp;
  wire                _zz_s0_rvalid;
  wire       [22:0]   rawFactory_readAddressMasked;
  wire       [22:0]   rawFactory_writeAddressMasked;
  wire                rawFactory_readOccur;
  wire                factory_readErrorFlag;
  wire                factory_writeErrorFlag;
  reg        [63:0]   counter_value;
  wire       [63:0]   counter_valueNext;
  reg        [15:0]   configurationBits;
  reg        [31:0]   hardwareInfo_instructionCounter;
  reg        [31:0]   hardwareInfo_readoutCounter;
  reg        [31:0]   hardwareInfo_transactionCounter;
  reg        [31:0]   hardwareInfo_errorCounter;
  reg                 hasError;
  wire                toplevel_slow_microBlossom_io_pop_m2sPipe_valid;
  reg                 toplevel_slow_microBlossom_io_pop_m2sPipe_ready;
  wire       [1:0]    toplevel_slow_microBlossom_io_pop_m2sPipe_payload_maxGrowable_length;
  wire       [4:0]    toplevel_slow_microBlossom_io_pop_m2sPipe_payload_conflict_node1;
  wire       [4:0]    toplevel_slow_microBlossom_io_pop_m2sPipe_payload_conflict_node2;
  wire       [4:0]    toplevel_slow_microBlossom_io_pop_m2sPipe_payload_conflict_touch1;
  wire       [4:0]    toplevel_slow_microBlossom_io_pop_m2sPipe_payload_conflict_touch2;
  wire       [4:0]    toplevel_slow_microBlossom_io_pop_m2sPipe_payload_conflict_vertex1;
  wire       [4:0]    toplevel_slow_microBlossom_io_pop_m2sPipe_payload_conflict_vertex2;
  wire                toplevel_slow_microBlossom_io_pop_m2sPipe_payload_conflict_valid;
  wire       [15:0]   toplevel_slow_microBlossom_io_pop_m2sPipe_payload_grown;
  wire       [3:0]    toplevel_slow_microBlossom_io_pop_m2sPipe_payload_tag_instructionId;
  wire                toplevel_slow_microBlossom_io_pop_m2sPipe_payload_tag_isFindObstacle;
  wire       [15:0]   toplevel_slow_microBlossom_io_pop_m2sPipe_payload_tag_accumulatedGrown;
  reg                 toplevel_slow_microBlossom_io_pop_rValid;
  reg        [1:0]    toplevel_slow_microBlossom_io_pop_rData_maxGrowable_length;
  reg        [4:0]    toplevel_slow_microBlossom_io_pop_rData_conflict_node1;
  reg        [4:0]    toplevel_slow_microBlossom_io_pop_rData_conflict_node2;
  reg        [4:0]    toplevel_slow_microBlossom_io_pop_rData_conflict_touch1;
  reg        [4:0]    toplevel_slow_microBlossom_io_pop_rData_conflict_touch2;
  reg        [4:0]    toplevel_slow_microBlossom_io_pop_rData_conflict_vertex1;
  reg        [4:0]    toplevel_slow_microBlossom_io_pop_rData_conflict_vertex2;
  reg                 toplevel_slow_microBlossom_io_pop_rData_conflict_valid;
  reg        [15:0]   toplevel_slow_microBlossom_io_pop_rData_grown;
  reg        [3:0]    toplevel_slow_microBlossom_io_pop_rData_tag_instructionId;
  reg                 toplevel_slow_microBlossom_io_pop_rData_tag_isFindObstacle;
  reg        [15:0]   toplevel_slow_microBlossom_io_pop_rData_tag_accumulatedGrown;
  wire                when_Stream_l369_2;
  reg        [15:0]   maximumGrowth_register;
  reg        [15:0]   accumulatedGrown_register;
  reg        [1:0]    maxGrowable_register_length;
  reg        [4:0]    conflict_register_node1;
  reg        [4:0]    conflict_register_node2;
  reg        [4:0]    conflict_register_touch1;
  reg        [4:0]    conflict_register_touch2;
  reg        [4:0]    conflict_register_vertex1;
  reg        [4:0]    conflict_register_vertex2;
  reg                 conflict_register_valid;
  reg        [3:0]    pushId_register;
  reg        [3:0]    popId_register;
  reg        [31:0]   timeLoad_lower_register;
  reg        [31:0]   timeLoad_upper_register;
  reg        [31:0]   timeFinish_lower_register;
  reg        [31:0]   timeFinish_upper_register;
  reg                 isLastFindObstacle_register;
  reg                 hasPendingFindObstacle_register;
  wire       [31:0]   instruction_value;
  reg        [63:0]   readout_value;
  wire       [63:0]   readout_writeValue;
  wire       [9:0]    readout_contextIdRaw;
  wire       [6:0]    readout_subAddress;
  wire       [3:0]    readout_obstacleAddress;
  wire       [9:0]    readout_writeContextIdRaw;
  wire       [6:0]    readout_writeSubAddress;
  reg                 isWriteHalt;
  reg                 isWriteAsk;
  reg                 isWriteDo;
  reg                 isReadHalt;
  reg                 isReadAsk;
  reg                 isReadDo;
  reg        [11:0]   resizedInstruction;
  reg                 resizeInstructionHasError;
  wire       [1:0]    switch_Instruction_l19;
  wire                when_Instruction_l23;
  wire                when_Instruction_l30;
  wire                when_Instruction_l35;
  wire                when_Instruction_l39;
  wire                when_Instruction_l45;
  wire                when_Instruction_l47;
  wire                when_Instruction_l53;
  wire                when_Instruction_l62;
  reg        [15:0]   fsmAccumulatedGrown_writeData;
  reg                 fsmAccumulatedGrown_enable;
  reg                 fsmAccumulatedGrown_write;
  wire       [15:0]   fsmAccumulatedGrown_data;
  wire                when_OneMem_l105;
  reg        [15:0]   accumulatedGrown_register_regNextWhen;
  reg                 fsmMaxGrowable_enable;
  wire       [1:0]    fsmMaxGrowable_data_length;
  reg        [1:0]    maxGrowable_register_regNextWhen_length;
  reg                 fsmConflict_enable;
  wire       [4:0]    fsmConflict_data_node1;
  wire       [4:0]    fsmConflict_data_node2;
  wire       [4:0]    fsmConflict_data_touch1;
  wire       [4:0]    fsmConflict_data_touch2;
  wire       [4:0]    fsmConflict_data_vertex1;
  wire       [4:0]    fsmConflict_data_vertex2;
  wire                fsmConflict_data_valid;
  reg        [4:0]    conflict_register_regNextWhen_node1;
  reg        [4:0]    conflict_register_regNextWhen_node2;
  reg        [4:0]    conflict_register_regNextWhen_touch1;
  reg        [4:0]    conflict_register_regNextWhen_touch2;
  reg        [4:0]    conflict_register_regNextWhen_vertex1;
  reg        [4:0]    conflict_register_regNextWhen_vertex2;
  reg                 conflict_register_regNextWhen_valid;
  reg                 fsmParityReports_enable;
  reg        [3:0]    fsmPushId_writeData;
  reg                 fsmPushId_enable;
  reg                 fsmPushId_write;
  wire       [3:0]    fsmPushId_data;
  wire                when_OneMem_l105_1;
  reg        [3:0]    pushId_register_regNextWhen;
  reg                 fsmPopId_enable;
  wire       [3:0]    fsmPopId_data;
  reg        [3:0]    popId_register_regNextWhen;
  reg        [15:0]   fsmMaximumGrowth_writeData;
  reg                 fsmMaximumGrowth_enable;
  reg                 fsmMaximumGrowth_write;
  wire       [15:0]   fsmMaximumGrowth_data;
  wire                when_OneMem_l105_2;
  reg        [15:0]   maximumGrowth_register_regNextWhen;
  reg        [31:0]   fsmTimeLoad_lower_writeData;
  reg                 fsmTimeLoad_lower_enable;
  reg                 fsmTimeLoad_lower_write;
  wire       [31:0]   fsmTimeLoad_lower_data;
  wire                when_OneMem_l105_3;
  reg        [31:0]   timeLoad_lower_register_regNextWhen;
  reg        [31:0]   fsmTimeLoad_upper_writeData;
  reg                 fsmTimeLoad_upper_enable;
  reg                 fsmTimeLoad_upper_write;
  wire       [31:0]   fsmTimeLoad_upper_data;
  wire                when_OneMem_l105_4;
  reg        [31:0]   timeLoad_upper_register_regNextWhen;
  reg        [31:0]   fsmTimeFinish_lower_writeData;
  reg                 fsmTimeFinish_lower_enable;
  reg                 fsmTimeFinish_lower_write;
  wire       [31:0]   fsmTimeFinish_lower_data;
  wire                when_OneMem_l105_5;
  reg        [31:0]   timeFinish_lower_register_regNextWhen;
  reg        [31:0]   fsmTimeFinish_upper_writeData;
  reg                 fsmTimeFinish_upper_enable;
  reg                 fsmTimeFinish_upper_write;
  wire       [31:0]   fsmTimeFinish_upper_data;
  wire                when_OneMem_l105_6;
  reg        [31:0]   timeFinish_upper_register_regNextWhen;
  reg                 fsmIsLastFindObstacle_writeData;
  reg                 fsmIsLastFindObstacle_enable;
  reg                 fsmIsLastFindObstacle_write;
  wire                fsmIsLastFindObstacle_data;
  wire                when_OneMem_l105_7;
  reg                 isLastFindObstacle_register_regNextWhen;
  reg                 fsmHasPendingFindObstacle_writeData;
  reg                 fsmHasPendingFindObstacle_enable;
  reg                 fsmHasPendingFindObstacle_write;
  wire                fsmHasPendingFindObstacle_data;
  wire                when_OneMem_l105_8;
  reg                 hasPendingFindObstacle_register_regNextWhen;
  reg        [15:0]   fsmConflictB16_node1;
  reg        [15:0]   fsmConflictB16_node2;
  reg        [15:0]   fsmConflictB16_touch1;
  reg        [15:0]   fsmConflictB16_touch2;
  wire       [15:0]   fsmConflictB16_vertex1;
  wire       [15:0]   fsmConflictB16_vertex2;
  wire                fsmConflictB16_valid;
  wire                when_ConvergecastMessage_l45;
  wire                when_ConvergecastMessage_l45_1;
  wire                when_ConvergecastMessage_l45_2;
  wire                when_ConvergecastMessage_l45_3;
  reg        [7:0]    fsmMaxGrowableU8_length;
  wire                when_ConvergecastMessage_l22;
  wire                when_ConvergecastMessage_l20;
  reg        [15:0]   fsmMaxGrowableU16_length;
  wire                when_ConvergecastMessage_l22_1;
  wire                when_ConvergecastMessage_l20_1;
  reg        [11:0]   dataWaitFiFoPushLooperInput_instruction;
  reg        [15:0]   dataWaitFiFoPushLooperInput_maximumGrowth;
  reg        [3:0]    dataWaitFiFoPushLooperInput_tag_instructionId;
  reg                 dataWaitFiFoPushLooperInput_tag_isFindObstacle;
  reg        [15:0]   dataWaitFiFoPushLooperInput_tag_accumulatedGrown;
  reg                 fsmWriteStallPendingFindObstacle;
  wire                fsmWriteStallLoadStall;
  wire                fsm_wantExit;
  reg                 fsm_wantStart;
  wire                fsm_wantKill;
  reg        [3:0]    rspPopId_writeData;
  reg                 rspPopId_enable;
  reg                 rspPopId_write;
  wire       [3:0]    rspPopId_data;
  wire                when_OneMem_l105_9;
  reg        [3:0]    popId_register_regNextWhen_1;
  reg        [1:0]    rspMaxGrowable_writeData_length;
  reg                 rspMaxGrowable_enable;
  reg                 rspMaxGrowable_write;
  wire       [1:0]    rspMaxGrowable_data_length;
  wire                when_OneMem_l105_10;
  reg        [1:0]    maxGrowable_register_regNextWhen_length_1;
  reg        [4:0]    rspConflict_writeData_node1;
  reg        [4:0]    rspConflict_writeData_node2;
  reg        [4:0]    rspConflict_writeData_touch1;
  reg        [4:0]    rspConflict_writeData_touch2;
  reg        [4:0]    rspConflict_writeData_vertex1;
  reg        [4:0]    rspConflict_writeData_vertex2;
  reg                 rspConflict_writeData_valid;
  reg                 rspConflict_enable;
  reg                 rspConflict_write;
  wire       [4:0]    rspConflict_data_node1;
  wire       [4:0]    rspConflict_data_node2;
  wire       [4:0]    rspConflict_data_touch1;
  wire       [4:0]    rspConflict_data_touch2;
  wire       [4:0]    rspConflict_data_vertex1;
  wire       [4:0]    rspConflict_data_vertex2;
  wire                rspConflict_data_valid;
  wire                when_OneMem_l105_11;
  reg        [4:0]    conflict_register_regNextWhen_node1_1;
  reg        [4:0]    conflict_register_regNextWhen_node2_1;
  reg        [4:0]    conflict_register_regNextWhen_touch1_1;
  reg        [4:0]    conflict_register_regNextWhen_touch2_1;
  reg        [4:0]    conflict_register_regNextWhen_vertex1_1;
  reg        [4:0]    conflict_register_regNextWhen_vertex2_1;
  reg                 conflict_register_regNextWhen_valid_1;
  reg                 rspParityReports_enable;
  reg                 rspParityReports_write;
  reg        [15:0]   rspAccumulatedGrown_writeData;
  reg                 rspAccumulatedGrown_enable;
  reg                 rspAccumulatedGrown_write;
  wire       [15:0]   rspAccumulatedGrown_data;
  wire                when_OneMem_l105_12;
  reg        [15:0]   accumulatedGrown_register_regNextWhen_1;
  reg        [31:0]   rspTimeFinish_upper_writeData;
  reg                 rspTimeFinish_upper_enable;
  reg                 rspTimeFinish_upper_write;
  wire       [31:0]   rspTimeFinish_upper_data;
  wire                when_OneMem_l105_13;
  reg        [31:0]   timeFinish_upper_register_regNextWhen_1;
  reg        [31:0]   rspTimeFinish_lower_writeData;
  reg                 rspTimeFinish_lower_enable;
  reg                 rspTimeFinish_lower_write;
  wire       [31:0]   rspTimeFinish_lower_data;
  wire                when_OneMem_l105_14;
  reg        [31:0]   timeFinish_lower_register_regNextWhen_1;
  reg                 rspHasPendingFindObstacle_writeData;
  reg                 rspHasPendingFindObstacle_enable;
  reg                 rspHasPendingFindObstacle_write;
  wire                rspHasPendingFindObstacle_data;
  wire                when_OneMem_l105_15;
  reg                 hasPendingFindObstacle_register_regNextWhen_1;
  wire                rsp_wantExit;
  reg                 rsp_wantStart;
  wire                rsp_wantKill;
  wire                when_AxiLite4SlaveFactory_l68;
  wire                when_AxiLite4SlaveFactory_l68_1;
  wire                when_AxiLite4SlaveFactory_l68_2;
  wire                when_AxiLite4SlaveFactory_l68_3;
  wire                when_AxiLite4SlaveFactory_l68_4;
  wire                when_AxiLite4SlaveFactory_l68_5;
  wire                when_AxiLite4SlaveFactory_l86;
  wire                when_AxiLite4SlaveFactory_l86_1;
  wire                when_AxiLite4SlaveFactory_l86_2;
  wire                when_AxiLite4SlaveFactory_l86_3;
  wire                when_AxiLite4SlaveFactory_l86_4;
  wire                when_AxiLite4SlaveFactory_l86_5;
  wire                when_AxiLite4SlaveFactory_l86_6;
  wire                when_AxiLite4SlaveFactory_l86_7;
  reg        [14:0]   fsm_stateReg;
  reg        [14:0]   fsm_stateNext;
  wire                when_MicroBlossomBus_l423;
  wire                when_Utils_l1410;
  wire                when_Utils_l1413;
  wire                when_Utils_l1413_1;
  wire                when_Utils_l1413_2;
  wire                when_Utils_l1413_3;
  wire                when_MicroBlossomBus_l449;
  wire                when_Utils_l1410_1;
  wire                when_Utils_l1413_4;
  wire                when_MicroBlossomBus_l452;
  wire       [15:0]   _zz_fsmMaximumGrowth_writeData;
  wire                when_MicroBlossomBus_l504;
  wire                when_MicroBlossomBus_l557;
  wire                when_MicroBlossomBus_l565;
  wire                when_MicroBlossomBus_l568;
  wire                when_MicroBlossomBus_l600;
  wire       [3:0]    _zz_fsmPushId_writeData;
  reg        [11:0]   _zz_dataWaitFiFoPushLooperInput_instruction;
  wire       [15:0]   _zz_dataWaitFiFoPushLooperInput_maximumGrowth;
  wire       [3:0]    _zz_dataWaitFiFoPushLooperInput_tag_instructionId;
  wire       [15:0]   _zz_dataWaitFiFoPushLooperInput_tag_accumulatedGrown;
  wire                when_MicroBlossomBus_l665;
  wire                when_MicroBlossomBus_l792;
  wire                when_MicroBlossomBus_l809;
  wire                when_MicroBlossomBus_l783;
  wire       [3:0]    _zz_fsmPushId_writeData_1;
  wire       [11:0]   _zz_dataWaitFiFoPushLooperInput_instruction_1;
  reg        [15:0]   _zz_dataWaitFiFoPushLooperInput_maximumGrowth_1;
  wire       [3:0]    _zz_dataWaitFiFoPushLooperInput_tag_instructionId_1;
  wire                _zz_dataWaitFiFoPushLooperInput_tag_isFindObstacle;
  wire       [15:0]   _zz_dataWaitFiFoPushLooperInput_tag_accumulatedGrown_1;
  wire                when_MicroBlossomBus_l497;
  wire                when_MicroBlossomBus_l498;
  wire                when_MicroBlossomBus_l516;
  wire                when_MicroBlossomBus_l530;
  wire                when_MicroBlossomBus_l759;
  reg        [1:0]    rsp_stateReg;
  reg        [1:0]    rsp_stateNext;
  wire                when_MicroBlossomBus_l864;
  `ifndef SYNTHESIS
  reg [303:0] fsm_stateReg_string;
  reg [303:0] fsm_stateNext_string;
  reg [71:0] rsp_stateReg_string;
  reg [71:0] rsp_stateNext_string;
  `endif

  function [15:0] zz_configurationBits(input dummy);
    begin
      zz_configurationBits = 16'h0000;
      zz_configurationBits[0] = 1'b1;
      zz_configurationBits[1] = 1'b0;
      zz_configurationBits[2] = 1'b0;
      zz_configurationBits[3] = 1'b1;
      zz_configurationBits[4] = 1'b0;
      zz_configurationBits[5] = 1'b1;
      zz_configurationBits[6] = 1'b0;
    end
  endfunction
  wire [15:0] _zz_1;
  function [11:0] zz__zz_dataWaitFiFoPushLooperInput_instruction(input dummy);
    begin
      zz__zz_dataWaitFiFoPushLooperInput_instruction[11 : 2] = 10'h000;
      zz__zz_dataWaitFiFoPushLooperInput_instruction[1 : 0] = 2'b00;
      zz__zz_dataWaitFiFoPushLooperInput_instruction[2 : 2] = 1'b1;
      zz__zz_dataWaitFiFoPushLooperInput_instruction[5 : 3] = 3'b000;
    end
  endfunction
  wire [11:0] _zz_2;

  assign _zz_readout_contextIdRaw = (_zz_readout_contextIdRaw_1 >>> 3'd7);
  assign _zz_readout_contextIdRaw_2 = (rawFactory_readAddressMasked - 23'h000000);
  assign _zz_readout_contextIdRaw_1 = _zz_readout_contextIdRaw_2[16:0];
  assign _zz_readout_subAddress = (rawFactory_readAddressMasked - 23'h000000);
  assign _zz_readout_writeContextIdRaw_1 = (rawFactory_writeAddressMasked - 23'h000000);
  assign _zz_readout_writeContextIdRaw = _zz_readout_writeContextIdRaw_1[16:0];
  assign _zz_readout_writeSubAddress = (rawFactory_writeAddressMasked - 23'h000000);
  assign _zz_resizedInstruction = instruction_value[31 : 17];
  assign _zz_resizedInstruction_1 = instruction_value[16 : 2];
  assign _zz_resizedInstruction_2 = instruction_value[31 : 17];
  assign _zz_resizedInstruction_3 = instruction_value[16 : 2];
  assign _zz_resizedInstruction_4 = instruction_value[31 : 17];
  assign _zz_resizedInstruction_5 = instruction_value[31 : 6];
  assign _zz_resizedInstruction_6 = instruction_value[31 : 17];
  assign _zz_resizedInstruction_7 = instruction_value[16 : 6];
  assign _zz_resizedInstruction_8 = instruction_value[31 : 17];
  assign _zz_resizedInstruction_9 = instruction_value[16 : 2];
  assign _zz_hardwareInfo_instructionCounter_1 = s0_wdata[31 : 0];
  assign _zz_hardwareInfo_instructionCounter = _zz_hardwareInfo_instructionCounter_1;
  assign _zz_hardwareInfo_readoutCounter_1 = s0_wdata[31 : 0];
  assign _zz_hardwareInfo_readoutCounter = _zz_hardwareInfo_readoutCounter_1;
  assign _zz_hardwareInfo_transactionCounter_1 = s0_wdata[31 : 0];
  assign _zz_hardwareInfo_transactionCounter = _zz_hardwareInfo_transactionCounter_1;
  assign _zz_hardwareInfo_errorCounter_1 = s0_wdata[31 : 0];
  assign _zz_hardwareInfo_errorCounter = _zz_hardwareInfo_errorCounter_1;
  assign _zz_rawFactory_readRsp_data = counter_value;
  assign _zz_rawFactory_readRsp_data_1 = {32'h00000001,32'h240123c0};
  assign _zz_rawFactory_readRsp_data_2 = {{{{{8'h01,configurationBits},8'h04},8'h02},8'h05},8'h01};
  assign _zz_rawFactory_readRsp_data_3 = hardwareInfo_instructionCounter;
  assign _zz_rawFactory_readRsp_data_4 = hardwareInfo_readoutCounter;
  assign _zz_rawFactory_readRsp_data_5 = hardwareInfo_transactionCounter;
  assign _zz_rawFactory_readRsp_data_6 = hardwareInfo_errorCounter;
  assign _zz_when_MicroBlossomBus_l423 = (rawFactory_readAddressMasked - 23'h000000);
  assign _zz_when_MicroBlossomBus_l449 = (rawFactory_writeAddressMasked - 23'h000000);
  assign _zz_when_MicroBlossomBus_l452 = (rawFactory_writeAddressMasked - 23'h000000);
  assign _zz_readout_value_1 = fsmConflictB16_valid;
  assign _zz_readout_value = {7'd0, _zz_readout_value_1};
  StreamFifo streamFifo_1 (
    .io_push_valid                        (streamFifo_1_io_push_valid                             ), //i
    .io_push_ready                        (streamFifo_1_io_push_ready                             ), //o
    .io_push_payload_instruction          (streamFifo_1_io_push_payload_instruction[11:0]         ), //i
    .io_push_payload_maximumGrowth        (streamFifo_1_io_push_payload_maximumGrowth[15:0]       ), //i
    .io_push_payload_tag_instructionId    (streamFifo_1_io_push_payload_tag_instructionId[3:0]    ), //i
    .io_push_payload_tag_isFindObstacle   (streamFifo_1_io_push_payload_tag_isFindObstacle        ), //i
    .io_push_payload_tag_accumulatedGrown (streamFifo_1_io_push_payload_tag_accumulatedGrown[15:0]), //i
    .io_pop_valid                         (streamFifo_1_io_pop_valid                              ), //o
    .io_pop_ready                         (slow_microBlossom_io_push_ready                        ), //i
    .io_pop_payload_instruction           (streamFifo_1_io_pop_payload_instruction[11:0]          ), //o
    .io_pop_payload_maximumGrowth         (streamFifo_1_io_pop_payload_maximumGrowth[15:0]        ), //o
    .io_pop_payload_tag_instructionId     (streamFifo_1_io_pop_payload_tag_instructionId[3:0]     ), //o
    .io_pop_payload_tag_isFindObstacle    (streamFifo_1_io_pop_payload_tag_isFindObstacle         ), //o
    .io_pop_payload_tag_accumulatedGrown  (streamFifo_1_io_pop_payload_tag_accumulatedGrown[15:0] ), //o
    .io_flush                             (1'b0                                                   ), //i
    .io_occupancy                         (streamFifo_1_io_occupancy[2:0]                         ), //o
    .io_availability                      (streamFifo_1_io_availability[2:0]                      ), //o
    .clk                                  (clk                                                    ), //i
    .reset                                (reset                                                  )  //i
  );
  MicroBlossomLooper slow_microBlossom (
    .io_push_valid                        (streamFifo_1_io_pop_valid                                  ), //i
    .io_push_ready                        (slow_microBlossom_io_push_ready                            ), //o
    .io_push_payload_instruction          (streamFifo_1_io_pop_payload_instruction[11:0]              ), //i
    .io_push_payload_maximumGrowth        (streamFifo_1_io_pop_payload_maximumGrowth[15:0]            ), //i
    .io_push_payload_tag_instructionId    (streamFifo_1_io_pop_payload_tag_instructionId[3:0]         ), //i
    .io_push_payload_tag_isFindObstacle   (streamFifo_1_io_pop_payload_tag_isFindObstacle             ), //i
    .io_push_payload_tag_accumulatedGrown (streamFifo_1_io_pop_payload_tag_accumulatedGrown[15:0]     ), //i
    .io_pop_valid                         (slow_microBlossom_io_pop_valid                             ), //o
    .io_pop_ready                         (slow_microBlossom_io_pop_ready                             ), //i
    .io_pop_payload_maxGrowable_length    (slow_microBlossom_io_pop_payload_maxGrowable_length[1:0]   ), //o
    .io_pop_payload_conflict_node1        (slow_microBlossom_io_pop_payload_conflict_node1[4:0]       ), //o
    .io_pop_payload_conflict_node2        (slow_microBlossom_io_pop_payload_conflict_node2[4:0]       ), //o
    .io_pop_payload_conflict_touch1       (slow_microBlossom_io_pop_payload_conflict_touch1[4:0]      ), //o
    .io_pop_payload_conflict_touch2       (slow_microBlossom_io_pop_payload_conflict_touch2[4:0]      ), //o
    .io_pop_payload_conflict_vertex1      (slow_microBlossom_io_pop_payload_conflict_vertex1[4:0]     ), //o
    .io_pop_payload_conflict_vertex2      (slow_microBlossom_io_pop_payload_conflict_vertex2[4:0]     ), //o
    .io_pop_payload_conflict_valid        (slow_microBlossom_io_pop_payload_conflict_valid            ), //o
    .io_pop_payload_grown                 (slow_microBlossom_io_pop_payload_grown[15:0]               ), //o
    .io_pop_payload_tag_instructionId     (slow_microBlossom_io_pop_payload_tag_instructionId[3:0]    ), //o
    .io_pop_payload_tag_isFindObstacle    (slow_microBlossom_io_pop_payload_tag_isFindObstacle        ), //o
    .io_pop_payload_tag_accumulatedGrown  (slow_microBlossom_io_pop_payload_tag_accumulatedGrown[15:0]), //o
    .io_dataLoss                          (slow_microBlossom_io_dataLoss                              ), //o
    .clk                                  (clk                                                        ), //i
    .reset                                (reset                                                      )  //i
  );
  `ifndef SYNTHESIS
  always @(*) begin
    case(fsm_stateReg)
      fsm_enumDef_BOOT : fsm_stateReg_string = "BOOT                                  ";
      fsm_enumDef_stateIdle : fsm_stateReg_string = "stateIdle                             ";
      fsm_enumDef_stateUpdateMaximumGrowth : fsm_stateReg_string = "stateUpdateMaximumGrowth              ";
      fsm_enumDef_stateReadParityReports : fsm_stateReg_string = "stateReadParityReports                ";
      fsm_enumDef_stateReadMaximumGrowth : fsm_stateReg_string = "stateReadMaximumGrowth                ";
      fsm_enumDef_stateReadObstacle : fsm_stateReg_string = "stateReadObstacle                     ";
      fsm_enumDef_stateReadIssueFindObstacleWaitPending : fsm_stateReg_string = "stateReadIssueFindObstacleWaitPending ";
      fsm_enumDef_stateReadIssueFindObstacle : fsm_stateReg_string = "stateReadIssueFindObstacle            ";
      fsm_enumDef_stateReadIssueFindObstaclePause : fsm_stateReg_string = "stateReadIssueFindObstaclePause       ";
      fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush : fsm_stateReg_string = "stateReadIssueFindObstacleWaitFiFoPush";
      fsm_enumDef_stateReadLoadTime : fsm_stateReg_string = "stateReadLoadTime                     ";
      fsm_enumDef_stateReadFinishTime : fsm_stateReg_string = "stateReadFinishTime                   ";
      fsm_enumDef_stateRead : fsm_stateReg_string = "stateRead                             ";
      fsm_enumDef_stateWriteInstruction : fsm_stateReg_string = "stateWriteInstruction                 ";
      fsm_enumDef_stateWriteWaitFiFoPush : fsm_stateReg_string = "stateWriteWaitFiFoPush                ";
      default : fsm_stateReg_string = "??????????????????????????????????????";
    endcase
  end
  always @(*) begin
    case(fsm_stateNext)
      fsm_enumDef_BOOT : fsm_stateNext_string = "BOOT                                  ";
      fsm_enumDef_stateIdle : fsm_stateNext_string = "stateIdle                             ";
      fsm_enumDef_stateUpdateMaximumGrowth : fsm_stateNext_string = "stateUpdateMaximumGrowth              ";
      fsm_enumDef_stateReadParityReports : fsm_stateNext_string = "stateReadParityReports                ";
      fsm_enumDef_stateReadMaximumGrowth : fsm_stateNext_string = "stateReadMaximumGrowth                ";
      fsm_enumDef_stateReadObstacle : fsm_stateNext_string = "stateReadObstacle                     ";
      fsm_enumDef_stateReadIssueFindObstacleWaitPending : fsm_stateNext_string = "stateReadIssueFindObstacleWaitPending ";
      fsm_enumDef_stateReadIssueFindObstacle : fsm_stateNext_string = "stateReadIssueFindObstacle            ";
      fsm_enumDef_stateReadIssueFindObstaclePause : fsm_stateNext_string = "stateReadIssueFindObstaclePause       ";
      fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush : fsm_stateNext_string = "stateReadIssueFindObstacleWaitFiFoPush";
      fsm_enumDef_stateReadLoadTime : fsm_stateNext_string = "stateReadLoadTime                     ";
      fsm_enumDef_stateReadFinishTime : fsm_stateNext_string = "stateReadFinishTime                   ";
      fsm_enumDef_stateRead : fsm_stateNext_string = "stateRead                             ";
      fsm_enumDef_stateWriteInstruction : fsm_stateNext_string = "stateWriteInstruction                 ";
      fsm_enumDef_stateWriteWaitFiFoPush : fsm_stateNext_string = "stateWriteWaitFiFoPush                ";
      default : fsm_stateNext_string = "??????????????????????????????????????";
    endcase
  end
  always @(*) begin
    case(rsp_stateReg)
      rsp_enumDef_BOOT : rsp_stateReg_string = "BOOT     ";
      rsp_enumDef_stateIdle : rsp_stateReg_string = "stateIdle";
      default : rsp_stateReg_string = "?????????";
    endcase
  end
  always @(*) begin
    case(rsp_stateNext)
      rsp_enumDef_BOOT : rsp_stateNext_string = "BOOT     ";
      rsp_enumDef_stateIdle : rsp_stateNext_string = "stateIdle";
      default : rsp_stateNext_string = "?????????";
    endcase
  end
  `endif

  assign rawFactory_readErrorFlag = 1'b0;
  assign rawFactory_writeErrorFlag = 1'b0;
  always @(*) begin
    rawFactory_readHaltRequest = 1'b0;
    if(when_AxiLite4SlaveFactory_l86_7) begin
      if(rawFactory_readDataStage_valid) begin
        if(isReadHalt) begin
          rawFactory_readHaltRequest = 1'b1;
        end
      end
    end
  end

  always @(*) begin
    rawFactory_writeHaltRequest = 1'b0;
    if(when_AxiLite4SlaveFactory_l68_4) begin
      if(rawFactory_writeJoinEvent_valid) begin
        if(isWriteHalt) begin
          rawFactory_writeHaltRequest = 1'b1;
        end
      end
    end
    if(when_AxiLite4SlaveFactory_l68_5) begin
      if(rawFactory_writeJoinEvent_valid) begin
        if(isWriteHalt) begin
          rawFactory_writeHaltRequest = 1'b1;
        end
      end
    end
  end

  assign rawFactory_writeOccur = (rawFactory_writeJoinEvent_valid && rawFactory_writeJoinEvent_ready);
  assign rawFactory_writeJoinEvent_valid = (s0_awvalid && s0_wvalid);
  assign s0_awready = rawFactory_writeOccur;
  assign s0_wready = rawFactory_writeOccur;
  assign rawFactory_writeJoinEvent_translated_valid = rawFactory_writeJoinEvent_valid;
  assign rawFactory_writeJoinEvent_ready = rawFactory_writeJoinEvent_translated_ready;
  assign rawFactory_writeJoinEvent_translated_payload_resp = rawFactory_writeRsp_resp;
  assign _zz_rawFactory_writeJoinEvent_translated_ready = (! rawFactory_writeHaltRequest);
  assign rawFactory_writeJoinEvent_translated_ready = (_zz_rawFactory_writeJoinEvent_translated_ready_1 && _zz_rawFactory_writeJoinEvent_translated_ready);
  always @(*) begin
    _zz_rawFactory_writeJoinEvent_translated_ready_1 = s0_bready;
    if(when_Stream_l369) begin
      _zz_rawFactory_writeJoinEvent_translated_ready_1 = 1'b1;
    end
  end

  assign when_Stream_l369 = (! _zz_s0_bvalid);
  assign _zz_s0_bvalid = _zz_s0_bvalid_1;
  assign s0_bvalid = _zz_s0_bvalid;
  assign s0_bresp = _zz_s0_bresp;
  always @(*) begin
    s0_arready = rawFactory_readDataStage_ready;
    if(when_Stream_l369_1) begin
      s0_arready = 1'b1;
    end
  end

  assign when_Stream_l369_1 = (! rawFactory_readDataStage_valid);
  assign rawFactory_readDataStage_valid = io_s0_ar_rValid;
  assign rawFactory_readDataStage_payload_addr = io_s0_ar_rData_addr;
  assign rawFactory_readDataStage_payload_prot = io_s0_ar_rData_prot;
  assign _zz_s0_rvalid = (! rawFactory_readHaltRequest);
  assign rawFactory_readDataStage_ready = (s0_rready && _zz_s0_rvalid);
  assign s0_rvalid = (rawFactory_readDataStage_valid && _zz_s0_rvalid);
  assign s0_rdata = rawFactory_readRsp_data;
  assign s0_rresp = rawFactory_readRsp_resp;
  always @(*) begin
    if(rawFactory_writeErrorFlag) begin
      rawFactory_writeRsp_resp = 2'b10;
    end else begin
      rawFactory_writeRsp_resp = 2'b00;
    end
  end

  always @(*) begin
    if(rawFactory_readErrorFlag) begin
      rawFactory_readRsp_resp = 2'b10;
    end else begin
      rawFactory_readRsp_resp = 2'b00;
    end
  end

  always @(*) begin
    rawFactory_readRsp_data = 64'h0000000000000000;
    if(when_AxiLite4SlaveFactory_l86) begin
      rawFactory_readRsp_data[63 : 0] = _zz_rawFactory_readRsp_data[63 : 0];
    end
    if(when_AxiLite4SlaveFactory_l86_1) begin
      rawFactory_readRsp_data[63 : 0] = _zz_rawFactory_readRsp_data_1[63 : 0];
    end
    if(when_AxiLite4SlaveFactory_l86_2) begin
      rawFactory_readRsp_data[55 : 0] = _zz_rawFactory_readRsp_data_2[55 : 0];
    end
    if(when_AxiLite4SlaveFactory_l86_3) begin
      rawFactory_readRsp_data[31 : 0] = _zz_rawFactory_readRsp_data_3[31 : 0];
    end
    if(when_AxiLite4SlaveFactory_l86_4) begin
      rawFactory_readRsp_data[31 : 0] = _zz_rawFactory_readRsp_data_4[31 : 0];
    end
    if(when_AxiLite4SlaveFactory_l86_5) begin
      rawFactory_readRsp_data[31 : 0] = _zz_rawFactory_readRsp_data_5[31 : 0];
    end
    if(when_AxiLite4SlaveFactory_l86_6) begin
      rawFactory_readRsp_data[31 : 0] = _zz_rawFactory_readRsp_data_6[31 : 0];
    end
    if(when_AxiLite4SlaveFactory_l86_7) begin
      rawFactory_readRsp_data[63 : 0] = readout_value;
    end
  end

  assign rawFactory_readAddressMasked = (rawFactory_readDataStage_payload_addr & (~ 23'h000007));
  assign rawFactory_writeAddressMasked = (s0_awaddr & (~ 23'h000007));
  assign rawFactory_readOccur = (s0_rvalid && s0_rready);
  assign factory_readErrorFlag = 1'b0;
  assign factory_writeErrorFlag = 1'b0;
  assign counter_valueNext = (counter_value + 64'h0000000000000001);
  assign _zz_1 = zz_configurationBits(1'b0);
  always @(*) configurationBits = _zz_1;
  always @(*) begin
    hasError = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateReg) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
        if(isReadAsk) begin
          if(when_MicroBlossomBus_l423) begin
            if(!when_Utils_l1410) begin
              if(!when_Utils_l1413) begin
                if(!when_Utils_l1413_1) begin
                  if(!when_Utils_l1413_2) begin
                    if(!when_Utils_l1413_3) begin
                      hasError = 1'b1;
                    end
                  end
                end
              end
            end
          end else begin
            hasError = 1'b1;
          end
        end else begin
          if(isWriteAsk) begin
            if(!when_MicroBlossomBus_l449) begin
              if(when_MicroBlossomBus_l452) begin
                if(!when_Utils_l1410_1) begin
                  if(!when_Utils_l1413_4) begin
                    hasError = 1'b1;
                  end
                end
              end else begin
                hasError = 1'b1;
              end
            end
          end
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
        if(fsmIsLastFindObstacle_data) begin
          if(when_MicroBlossomBus_l557) begin
            if(!when_MicroBlossomBus_l565) begin
              if(!when_MicroBlossomBus_l568) begin
                hasError = 1'b1;
              end
            end
          end
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l783) begin
          if(resizeInstructionHasError) begin
            hasError = 1'b1;
          end
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateNext) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
        if(when_MicroBlossomBus_l497) begin
          hasError = 1'b1;
        end
        if(when_MicroBlossomBus_l498) begin
          hasError = 1'b1;
        end
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
        if(when_MicroBlossomBus_l516) begin
          hasError = 1'b1;
        end
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
        if(when_MicroBlossomBus_l530) begin
          hasError = 1'b1;
        end
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    slow_microBlossom_io_pop_ready = toplevel_slow_microBlossom_io_pop_m2sPipe_ready;
    if(when_Stream_l369_2) begin
      slow_microBlossom_io_pop_ready = 1'b1;
    end
  end

  assign when_Stream_l369_2 = (! toplevel_slow_microBlossom_io_pop_m2sPipe_valid);
  assign toplevel_slow_microBlossom_io_pop_m2sPipe_valid = toplevel_slow_microBlossom_io_pop_rValid;
  assign toplevel_slow_microBlossom_io_pop_m2sPipe_payload_maxGrowable_length = toplevel_slow_microBlossom_io_pop_rData_maxGrowable_length;
  assign toplevel_slow_microBlossom_io_pop_m2sPipe_payload_conflict_node1 = toplevel_slow_microBlossom_io_pop_rData_conflict_node1;
  assign toplevel_slow_microBlossom_io_pop_m2sPipe_payload_conflict_node2 = toplevel_slow_microBlossom_io_pop_rData_conflict_node2;
  assign toplevel_slow_microBlossom_io_pop_m2sPipe_payload_conflict_touch1 = toplevel_slow_microBlossom_io_pop_rData_conflict_touch1;
  assign toplevel_slow_microBlossom_io_pop_m2sPipe_payload_conflict_touch2 = toplevel_slow_microBlossom_io_pop_rData_conflict_touch2;
  assign toplevel_slow_microBlossom_io_pop_m2sPipe_payload_conflict_vertex1 = toplevel_slow_microBlossom_io_pop_rData_conflict_vertex1;
  assign toplevel_slow_microBlossom_io_pop_m2sPipe_payload_conflict_vertex2 = toplevel_slow_microBlossom_io_pop_rData_conflict_vertex2;
  assign toplevel_slow_microBlossom_io_pop_m2sPipe_payload_conflict_valid = toplevel_slow_microBlossom_io_pop_rData_conflict_valid;
  assign toplevel_slow_microBlossom_io_pop_m2sPipe_payload_grown = toplevel_slow_microBlossom_io_pop_rData_grown;
  assign toplevel_slow_microBlossom_io_pop_m2sPipe_payload_tag_instructionId = toplevel_slow_microBlossom_io_pop_rData_tag_instructionId;
  assign toplevel_slow_microBlossom_io_pop_m2sPipe_payload_tag_isFindObstacle = toplevel_slow_microBlossom_io_pop_rData_tag_isFindObstacle;
  assign toplevel_slow_microBlossom_io_pop_m2sPipe_payload_tag_accumulatedGrown = toplevel_slow_microBlossom_io_pop_rData_tag_accumulatedGrown;
  always @(*) begin
    streamFifo_1_io_push_valid = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateReg) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
        streamFifo_1_io_push_valid = 1'b1;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
        streamFifo_1_io_push_valid = 1'b1;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l783) begin
          streamFifo_1_io_push_valid = 1'b1;
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
        streamFifo_1_io_push_valid = 1'b1;
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    streamFifo_1_io_push_payload_instruction = 12'bxxxxxxxxxxxx;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateReg) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
        streamFifo_1_io_push_payload_instruction = _zz_dataWaitFiFoPushLooperInput_instruction;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
        streamFifo_1_io_push_payload_instruction = dataWaitFiFoPushLooperInput_instruction;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l783) begin
          streamFifo_1_io_push_payload_instruction = _zz_dataWaitFiFoPushLooperInput_instruction_1;
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
        streamFifo_1_io_push_payload_instruction = dataWaitFiFoPushLooperInput_instruction;
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    streamFifo_1_io_push_payload_maximumGrowth = 16'bxxxxxxxxxxxxxxxx;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateReg) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
        streamFifo_1_io_push_payload_maximumGrowth = _zz_dataWaitFiFoPushLooperInput_maximumGrowth;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
        streamFifo_1_io_push_payload_maximumGrowth = dataWaitFiFoPushLooperInput_maximumGrowth;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l783) begin
          streamFifo_1_io_push_payload_maximumGrowth = _zz_dataWaitFiFoPushLooperInput_maximumGrowth_1;
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
        streamFifo_1_io_push_payload_maximumGrowth = dataWaitFiFoPushLooperInput_maximumGrowth;
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    streamFifo_1_io_push_payload_tag_instructionId = 4'bxxxx;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateReg) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
        streamFifo_1_io_push_payload_tag_instructionId = _zz_dataWaitFiFoPushLooperInput_tag_instructionId;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
        streamFifo_1_io_push_payload_tag_instructionId = dataWaitFiFoPushLooperInput_tag_instructionId;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l783) begin
          streamFifo_1_io_push_payload_tag_instructionId = _zz_dataWaitFiFoPushLooperInput_tag_instructionId_1;
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
        streamFifo_1_io_push_payload_tag_instructionId = dataWaitFiFoPushLooperInput_tag_instructionId;
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    streamFifo_1_io_push_payload_tag_isFindObstacle = 1'bx;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateReg) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
        streamFifo_1_io_push_payload_tag_isFindObstacle = 1'b1;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
        streamFifo_1_io_push_payload_tag_isFindObstacle = dataWaitFiFoPushLooperInput_tag_isFindObstacle;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l783) begin
          streamFifo_1_io_push_payload_tag_isFindObstacle = _zz_dataWaitFiFoPushLooperInput_tag_isFindObstacle;
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
        streamFifo_1_io_push_payload_tag_isFindObstacle = dataWaitFiFoPushLooperInput_tag_isFindObstacle;
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    streamFifo_1_io_push_payload_tag_accumulatedGrown = 16'bxxxxxxxxxxxxxxxx;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateReg) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
        streamFifo_1_io_push_payload_tag_accumulatedGrown = _zz_dataWaitFiFoPushLooperInput_tag_accumulatedGrown;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
        streamFifo_1_io_push_payload_tag_accumulatedGrown = dataWaitFiFoPushLooperInput_tag_accumulatedGrown;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l783) begin
          streamFifo_1_io_push_payload_tag_accumulatedGrown = _zz_dataWaitFiFoPushLooperInput_tag_accumulatedGrown_1;
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
        streamFifo_1_io_push_payload_tag_accumulatedGrown = dataWaitFiFoPushLooperInput_tag_accumulatedGrown;
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    toplevel_slow_microBlossom_io_pop_m2sPipe_ready = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((rsp_stateReg) & rsp_enumDef_stateIdle) == rsp_enumDef_stateIdle) : begin
        toplevel_slow_microBlossom_io_pop_m2sPipe_ready = 1'b1;
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    readout_value = 64'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateReg) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
        if(isReadAsk) begin
          if(when_MicroBlossomBus_l423) begin
            if(!when_Utils_l1410) begin
              if(!when_Utils_l1413) begin
                if(!when_Utils_l1413_1) begin
                  if(!when_Utils_l1413_2) begin
                    if(!when_Utils_l1413_3) begin
                      readout_value = 64'hffffffffffffffff;
                    end
                  end
                end
              end
            end
          end else begin
            readout_value = 64'hffffffffffffffff;
          end
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
        readout_value = 64'h0000000000000000;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
        readout_value = {32'h00000000,{fsmMaxGrowableU16_length,fsmMaximumGrowth_data}};
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
        if(fsmIsLastFindObstacle_data) begin
          if(when_MicroBlossomBus_l557) begin
            if(when_MicroBlossomBus_l565) begin
              readout_value = {{fsmConflictB16_touch2,fsmConflictB16_touch1},{fsmConflictB16_node2,fsmConflictB16_node1}};
            end else begin
              if(when_MicroBlossomBus_l568) begin
                readout_value = {{{fsmAccumulatedGrown_data,fsmMaxGrowableU8_length},_zz_readout_value},{fsmConflictB16_vertex2,fsmConflictB16_vertex1}};
              end else begin
                readout_value = 64'hffffffffffffffff;
              end
            end
          end
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
        if(when_MicroBlossomBus_l665) begin
          readout_value = {fsmTimeLoad_upper_data,fsmTimeLoad_lower_data};
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
        readout_value = {fsmTimeFinish_upper_data,fsmTimeFinish_lower_data};
      end
      (((fsm_stateReg) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
        readout_value = 64'h0000000000000000;
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  assign readout_contextIdRaw = _zz_readout_contextIdRaw;
  assign readout_subAddress = _zz_readout_subAddress[6:0];
  assign readout_obstacleAddress = readout_subAddress[3:0];
  assign readout_writeContextIdRaw = (_zz_readout_writeContextIdRaw >>> 3'd7);
  assign readout_writeSubAddress = _zz_readout_writeSubAddress[6:0];
  always @(*) begin
    isWriteHalt = 1'b1;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateReg) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
        if(!isReadAsk) begin
          if(isWriteAsk) begin
            if(!when_MicroBlossomBus_l449) begin
              if(when_MicroBlossomBus_l452) begin
                if(!when_Utils_l1410_1) begin
                  if(when_Utils_l1413_4) begin
                    isWriteHalt = 1'b0;
                  end else begin
                    isWriteHalt = 1'b0;
                  end
                end
              end else begin
                isWriteHalt = 1'b0;
              end
            end
          end
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
        isWriteHalt = 1'b0;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l783) begin
          if(streamFifo_1_io_push_ready) begin
            isWriteHalt = 1'b0;
          end
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
        if(streamFifo_1_io_push_ready) begin
          isWriteHalt = 1'b0;
        end
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    isWriteAsk = 1'b0;
    if(when_AxiLite4SlaveFactory_l68_4) begin
      if(rawFactory_writeJoinEvent_valid) begin
        isWriteAsk = 1'b1;
      end
    end
    if(when_AxiLite4SlaveFactory_l68_5) begin
      if(rawFactory_writeJoinEvent_valid) begin
        isWriteAsk = 1'b1;
      end
    end
  end

  always @(*) begin
    isWriteDo = 1'b0;
    if(when_AxiLite4SlaveFactory_l68_4) begin
      if(rawFactory_writeOccur) begin
        isWriteDo = 1'b1;
      end
    end
    if(when_AxiLite4SlaveFactory_l68_5) begin
      if(rawFactory_writeOccur) begin
        isWriteDo = 1'b1;
      end
    end
  end

  always @(*) begin
    isReadHalt = 1'b1;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateReg) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
        if(isReadAsk) begin
          if(when_MicroBlossomBus_l423) begin
            if(!when_Utils_l1410) begin
              if(!when_Utils_l1413) begin
                if(!when_Utils_l1413_1) begin
                  if(!when_Utils_l1413_2) begin
                    if(!when_Utils_l1413_3) begin
                      isReadHalt = 1'b0;
                    end
                  end
                end
              end
            end
          end else begin
            isReadHalt = 1'b0;
          end
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
        isReadHalt = 1'b0;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
        isReadHalt = 1'b0;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
        if(fsmIsLastFindObstacle_data) begin
          if(when_MicroBlossomBus_l557) begin
            isReadHalt = 1'b0;
            if(!when_MicroBlossomBus_l565) begin
              if(!when_MicroBlossomBus_l568) begin
                isReadHalt = 1'b0;
              end
            end
          end
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
        if(when_MicroBlossomBus_l665) begin
          isReadHalt = 1'b0;
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
        isReadHalt = 1'b0;
      end
      (((fsm_stateReg) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
        isReadHalt = 1'b0;
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    isReadAsk = 1'b0;
    if(when_AxiLite4SlaveFactory_l86_7) begin
      if(rawFactory_readDataStage_valid) begin
        isReadAsk = 1'b1;
      end
    end
  end

  always @(*) begin
    isReadDo = 1'b0;
    if(when_AxiLite4SlaveFactory_l86_7) begin
      if(rawFactory_readOccur) begin
        isReadDo = 1'b1;
      end
    end
  end

  always @(*) begin
    resizeInstructionHasError = 1'b0;
    case(switch_Instruction_l19)
      2'b01 : begin
        if(when_Instruction_l23) begin
          resizeInstructionHasError = 1'b1;
        end
      end
      2'b11 : begin
        if(when_Instruction_l30) begin
          resizeInstructionHasError = 1'b1;
        end
      end
      2'b00 : begin
        if(when_Instruction_l35) begin
          if(when_Instruction_l39) begin
            resizeInstructionHasError = 1'b1;
          end
        end else begin
          if(when_Instruction_l45) begin
            if(when_Instruction_l47) begin
              resizeInstructionHasError = 1'b1;
            end
          end else begin
            if(when_Instruction_l53) begin
              resizeInstructionHasError = 1'b1;
            end
          end
        end
      end
      default : begin
        if(when_Instruction_l62) begin
          resizeInstructionHasError = 1'b1;
        end
      end
    endcase
  end

  always @(*) begin
    resizedInstruction[1 : 0] = instruction_value[1 : 0];
    case(switch_Instruction_l19)
      2'b01 : begin
        resizedInstruction[11 : 7] = _zz_resizedInstruction[4:0];
        resizedInstruction[6 : 2] = _zz_resizedInstruction_1[4:0];
      end
      2'b11 : begin
        resizedInstruction[11 : 7] = _zz_resizedInstruction_2[4:0];
        resizedInstruction[6 : 2] = _zz_resizedInstruction_3[4:0];
      end
      2'b00 : begin
        if(when_Instruction_l35) begin
          resizedInstruction[11 : 7] = _zz_resizedInstruction_4[4:0];
          resizedInstruction[6 : 5] = instruction_value[16 : 15];
          resizedInstruction[4 : 2] = 3'b000;
        end else begin
          resizedInstruction[5 : 3] = instruction_value[5 : 3];
          resizedInstruction[2 : 2] = instruction_value[2 : 2];
          if(when_Instruction_l45) begin
            resizedInstruction[11 : 6] = _zz_resizedInstruction_5[5:0];
          end else begin
            resizedInstruction[11 : 7] = _zz_resizedInstruction_6[4:0];
            resizedInstruction[6 : 6] = _zz_resizedInstruction_7[0:0];
          end
        end
      end
      default : begin
        resizedInstruction[11 : 7] = _zz_resizedInstruction_8[4:0];
        resizedInstruction[6 : 2] = _zz_resizedInstruction_9[4:0];
      end
    endcase
  end

  assign switch_Instruction_l19 = instruction_value[1 : 0];
  assign when_Instruction_l23 = ((15'h001f < instruction_value[31 : 17]) || (15'h001f < instruction_value[16 : 2]));
  assign when_Instruction_l30 = ((15'h001f < instruction_value[31 : 17]) || (15'h001f < instruction_value[16 : 2]));
  assign when_Instruction_l35 = (instruction_value[2 : 2] == 1'b0);
  assign when_Instruction_l39 = (15'h001f < instruction_value[31 : 17]);
  assign when_Instruction_l45 = (instruction_value[5 : 3] == 3'b110);
  assign when_Instruction_l47 = (26'h000003f < instruction_value[31 : 6]);
  assign when_Instruction_l53 = (15'h001f < instruction_value[31 : 17]);
  assign when_Instruction_l62 = ((15'h001f < instruction_value[31 : 17]) || (15'h001f < instruction_value[16 : 2]));
  always @(*) begin
    fsmAccumulatedGrown_enable = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateReg) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
        if(!isReadAsk) begin
          if(isWriteAsk) begin
            if(!when_MicroBlossomBus_l449) begin
              if(when_MicroBlossomBus_l452) begin
                if(!when_Utils_l1410_1) begin
                  if(when_Utils_l1413_4) begin
                    fsmAccumulatedGrown_enable = 1'b1;
                  end
                end
              end
            end
          end
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l783) begin
          if(when_MicroBlossomBus_l809) begin
            fsmAccumulatedGrown_enable = 1'b1;
          end
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateNext) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
        fsmAccumulatedGrown_enable = 1'b1;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
        fsmAccumulatedGrown_enable = 1'b1;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        fsmAccumulatedGrown_enable = 1'b1;
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    fsmAccumulatedGrown_write = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateReg) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
        if(!isReadAsk) begin
          if(isWriteAsk) begin
            if(!when_MicroBlossomBus_l449) begin
              if(when_MicroBlossomBus_l452) begin
                if(!when_Utils_l1410_1) begin
                  if(when_Utils_l1413_4) begin
                    fsmAccumulatedGrown_write = 1'b1;
                  end
                end
              end
            end
          end
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l783) begin
          if(when_MicroBlossomBus_l809) begin
            fsmAccumulatedGrown_write = 1'b1;
          end
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateNext) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
        fsmAccumulatedGrown_write = 1'b0;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
        fsmAccumulatedGrown_write = 1'b0;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        fsmAccumulatedGrown_write = 1'b0;
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    fsmAccumulatedGrown_writeData = 16'bxxxxxxxxxxxxxxxx;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateReg) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
        if(!isReadAsk) begin
          if(isWriteAsk) begin
            if(!when_MicroBlossomBus_l449) begin
              if(when_MicroBlossomBus_l452) begin
                if(!when_Utils_l1410_1) begin
                  if(when_Utils_l1413_4) begin
                    fsmAccumulatedGrown_writeData = 16'h0000;
                  end
                end
              end
            end
          end
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l783) begin
          if(when_MicroBlossomBus_l809) begin
            fsmAccumulatedGrown_writeData = 16'h0000;
          end
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  assign when_OneMem_l105 = (fsmAccumulatedGrown_enable && fsmAccumulatedGrown_write);
  assign fsmAccumulatedGrown_data = accumulatedGrown_register_regNextWhen;
  always @(*) begin
    fsmMaxGrowable_enable = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateNext) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
        fsmMaxGrowable_enable = 1'b1;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
        fsmMaxGrowable_enable = 1'b1;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  assign fsmMaxGrowable_data_length = maxGrowable_register_regNextWhen_length;
  always @(*) begin
    fsmConflict_enable = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateNext) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
        fsmConflict_enable = 1'b1;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  assign fsmConflict_data_node1 = conflict_register_regNextWhen_node1;
  assign fsmConflict_data_node2 = conflict_register_regNextWhen_node2;
  assign fsmConflict_data_touch1 = conflict_register_regNextWhen_touch1;
  assign fsmConflict_data_touch2 = conflict_register_regNextWhen_touch2;
  assign fsmConflict_data_vertex1 = conflict_register_regNextWhen_vertex1;
  assign fsmConflict_data_vertex2 = conflict_register_regNextWhen_vertex2;
  assign fsmConflict_data_valid = conflict_register_regNextWhen_valid;
  always @(*) begin
    fsmParityReports_enable = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateNext) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
        fsmParityReports_enable = 1'b1;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    fsmPushId_enable = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateReg) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
        fsmPushId_enable = 1'b1;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l783) begin
          fsmPushId_enable = 1'b1;
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateNext) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
        fsmPushId_enable = 1'b1;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
        fsmPushId_enable = 1'b1;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
        fsmPushId_enable = 1'b1;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    fsmPushId_write = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateReg) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
        fsmPushId_write = 1'b1;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l783) begin
          fsmPushId_write = 1'b1;
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateNext) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
        fsmPushId_write = 1'b0;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
        fsmPushId_write = 1'b0;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
        fsmPushId_write = 1'b0;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    fsmPushId_writeData = 4'bxxxx;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateReg) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
        fsmPushId_writeData = _zz_fsmPushId_writeData;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l783) begin
          fsmPushId_writeData = _zz_fsmPushId_writeData_1;
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  assign when_OneMem_l105_1 = (fsmPushId_enable && fsmPushId_write);
  assign fsmPushId_data = pushId_register_regNextWhen;
  always @(*) begin
    fsmPopId_enable = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateNext) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
        fsmPopId_enable = 1'b1;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
        fsmPopId_enable = 1'b1;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  assign fsmPopId_data = popId_register_regNextWhen;
  always @(*) begin
    fsmMaximumGrowth_enable = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateReg) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
        fsmMaximumGrowth_enable = 1'b1;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l783) begin
          if(when_MicroBlossomBus_l809) begin
            fsmMaximumGrowth_enable = 1'b1;
          end
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateNext) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
        fsmMaximumGrowth_enable = 1'b1;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
        fsmMaximumGrowth_enable = 1'b1;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
        fsmMaximumGrowth_enable = 1'b1;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
        fsmMaximumGrowth_enable = 1'b1;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        fsmMaximumGrowth_enable = 1'b1;
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    fsmMaximumGrowth_write = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateReg) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
        fsmMaximumGrowth_write = 1'b1;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l783) begin
          if(when_MicroBlossomBus_l809) begin
            fsmMaximumGrowth_write = 1'b1;
          end
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateNext) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
        fsmMaximumGrowth_write = 1'b0;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
        fsmMaximumGrowth_write = 1'b0;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
        fsmMaximumGrowth_write = 1'b0;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
        fsmMaximumGrowth_write = 1'b0;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        fsmMaximumGrowth_write = 1'b0;
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    fsmMaximumGrowth_writeData = 16'bxxxxxxxxxxxxxxxx;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateReg) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
        fsmMaximumGrowth_writeData = _zz_fsmMaximumGrowth_writeData;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l783) begin
          if(when_MicroBlossomBus_l809) begin
            fsmMaximumGrowth_writeData = 16'h0000;
          end
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  assign when_OneMem_l105_2 = (fsmMaximumGrowth_enable && fsmMaximumGrowth_write);
  assign fsmMaximumGrowth_data = maximumGrowth_register_regNextWhen;
  always @(*) begin
    fsmTimeLoad_lower_enable = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateNext) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
        fsmTimeLoad_lower_enable = 1'b1;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l759) begin
          fsmTimeLoad_lower_enable = 1'b1;
        end
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    fsmTimeLoad_lower_write = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateNext) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
        fsmTimeLoad_lower_write = 1'b0;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l759) begin
          fsmTimeLoad_lower_write = 1'b1;
        end
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    fsmTimeLoad_lower_writeData = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateNext) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l759) begin
          fsmTimeLoad_lower_writeData = counter_valueNext[31 : 0];
        end
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  assign when_OneMem_l105_3 = (fsmTimeLoad_lower_enable && fsmTimeLoad_lower_write);
  assign fsmTimeLoad_lower_data = timeLoad_lower_register_regNextWhen;
  always @(*) begin
    fsmTimeLoad_upper_enable = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateNext) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
        fsmTimeLoad_upper_enable = 1'b1;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l759) begin
          fsmTimeLoad_upper_enable = 1'b1;
        end
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    fsmTimeLoad_upper_write = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateNext) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
        fsmTimeLoad_upper_write = 1'b0;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l759) begin
          fsmTimeLoad_upper_write = 1'b1;
        end
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    fsmTimeLoad_upper_writeData = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateNext) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l759) begin
          fsmTimeLoad_upper_writeData = counter_valueNext[63 : 32];
        end
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  assign when_OneMem_l105_4 = (fsmTimeLoad_upper_enable && fsmTimeLoad_upper_write);
  assign fsmTimeLoad_upper_data = timeLoad_upper_register_regNextWhen;
  always @(*) begin
    fsmTimeFinish_lower_enable = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateNext) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
        fsmTimeFinish_lower_enable = 1'b1;
      end
      (((fsm_stateNext) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l759) begin
          fsmTimeFinish_lower_enable = 1'b1;
        end
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    fsmTimeFinish_lower_write = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateNext) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
        fsmTimeFinish_lower_write = 1'b0;
      end
      (((fsm_stateNext) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l759) begin
          fsmTimeFinish_lower_write = 1'b1;
        end
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    fsmTimeFinish_lower_writeData = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateNext) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l759) begin
          fsmTimeFinish_lower_writeData = (~ 32'h00000000);
        end
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  assign when_OneMem_l105_5 = (fsmTimeFinish_lower_enable && fsmTimeFinish_lower_write);
  assign fsmTimeFinish_lower_data = timeFinish_lower_register_regNextWhen;
  always @(*) begin
    fsmTimeFinish_upper_enable = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateNext) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
        fsmTimeFinish_upper_enable = 1'b1;
      end
      (((fsm_stateNext) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l759) begin
          fsmTimeFinish_upper_enable = 1'b1;
        end
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    fsmTimeFinish_upper_write = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateNext) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
        fsmTimeFinish_upper_write = 1'b0;
      end
      (((fsm_stateNext) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l759) begin
          fsmTimeFinish_upper_write = 1'b1;
        end
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    fsmTimeFinish_upper_writeData = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateNext) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l759) begin
          fsmTimeFinish_upper_writeData = (~ 32'h00000000);
        end
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  assign when_OneMem_l105_6 = (fsmTimeFinish_upper_enable && fsmTimeFinish_upper_write);
  assign fsmTimeFinish_upper_data = timeFinish_upper_register_regNextWhen;
  always @(*) begin
    fsmIsLastFindObstacle_enable = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateReg) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
        if(when_MicroBlossomBus_l504) begin
          fsmIsLastFindObstacle_enable = 1'b1;
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
        fsmIsLastFindObstacle_enable = 1'b1;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l783) begin
          fsmIsLastFindObstacle_enable = 1'b1;
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateNext) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
        fsmIsLastFindObstacle_enable = 1'b1;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    fsmIsLastFindObstacle_write = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateReg) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
        if(when_MicroBlossomBus_l504) begin
          fsmIsLastFindObstacle_write = 1'b1;
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
        fsmIsLastFindObstacle_write = 1'b1;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l783) begin
          fsmIsLastFindObstacle_write = 1'b1;
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateNext) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
        fsmIsLastFindObstacle_write = 1'b0;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    fsmIsLastFindObstacle_writeData = 1'bx;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateReg) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
        if(when_MicroBlossomBus_l504) begin
          fsmIsLastFindObstacle_writeData = 1'b0;
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
        fsmIsLastFindObstacle_writeData = 1'b1;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l783) begin
          fsmIsLastFindObstacle_writeData = when_MicroBlossomBus_l792;
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  assign when_OneMem_l105_7 = (fsmIsLastFindObstacle_enable && fsmIsLastFindObstacle_write);
  assign fsmIsLastFindObstacle_data = isLastFindObstacle_register_regNextWhen;
  always @(*) begin
    fsmHasPendingFindObstacle_enable = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateReg) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
        fsmHasPendingFindObstacle_enable = 1'b1;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l783) begin
          if(when_MicroBlossomBus_l792) begin
            fsmHasPendingFindObstacle_enable = 1'b1;
          end
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateNext) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
        fsmHasPendingFindObstacle_enable = 1'b1;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        fsmHasPendingFindObstacle_enable = 1'b1;
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    fsmHasPendingFindObstacle_write = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateReg) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
        fsmHasPendingFindObstacle_write = 1'b1;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l783) begin
          if(when_MicroBlossomBus_l792) begin
            fsmHasPendingFindObstacle_write = 1'b1;
          end
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateNext) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
        fsmHasPendingFindObstacle_write = 1'b0;
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        fsmHasPendingFindObstacle_write = 1'b0;
      end
      (((fsm_stateNext) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    fsmHasPendingFindObstacle_writeData = 1'bx;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateReg) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
        fsmHasPendingFindObstacle_writeData = 1'b1;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l783) begin
          if(when_MicroBlossomBus_l792) begin
            fsmHasPendingFindObstacle_writeData = 1'b1;
          end
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  assign when_OneMem_l105_8 = (fsmHasPendingFindObstacle_enable && fsmHasPendingFindObstacle_write);
  assign fsmHasPendingFindObstacle_data = hasPendingFindObstacle_register_regNextWhen;
  assign fsmConflictB16_valid = fsmConflict_data_valid;
  always @(*) begin
    fsmConflictB16_node1 = {11'd0, fsmConflict_data_node1};
    if(when_ConvergecastMessage_l45) begin
      fsmConflictB16_node1[15 : 5] = 11'h7ff;
    end
  end

  assign when_ConvergecastMessage_l45 = (fsmConflict_data_node1 == 5'h1f);
  always @(*) begin
    fsmConflictB16_node2 = {11'd0, fsmConflict_data_node2};
    if(when_ConvergecastMessage_l45_1) begin
      fsmConflictB16_node2[15 : 5] = 11'h7ff;
    end
  end

  assign when_ConvergecastMessage_l45_1 = (fsmConflict_data_node2 == 5'h1f);
  always @(*) begin
    fsmConflictB16_touch1 = {11'd0, fsmConflict_data_touch1};
    if(when_ConvergecastMessage_l45_2) begin
      fsmConflictB16_touch1[15 : 5] = 11'h7ff;
    end
  end

  assign when_ConvergecastMessage_l45_2 = (fsmConflict_data_touch1 == 5'h1f);
  always @(*) begin
    fsmConflictB16_touch2 = {11'd0, fsmConflict_data_touch2};
    if(when_ConvergecastMessage_l45_3) begin
      fsmConflictB16_touch2[15 : 5] = 11'h7ff;
    end
  end

  assign when_ConvergecastMessage_l45_3 = (fsmConflict_data_touch2 == 5'h1f);
  assign fsmConflictB16_vertex1 = {11'd0, fsmConflict_data_vertex1};
  assign fsmConflictB16_vertex2 = {11'd0, fsmConflict_data_vertex2};
  assign when_ConvergecastMessage_l22 = 1'b0;
  assign when_ConvergecastMessage_l20 = (fsmMaxGrowable_data_length == 2'b11);
  always @(*) begin
    if(when_ConvergecastMessage_l20) begin
      fsmMaxGrowableU8_length = 8'hff;
    end else begin
      if(when_ConvergecastMessage_l22) begin
        fsmMaxGrowableU8_length = 8'hfe;
      end else begin
        fsmMaxGrowableU8_length = {6'd0, fsmMaxGrowable_data_length};
      end
    end
  end

  assign when_ConvergecastMessage_l22_1 = 1'b0;
  assign when_ConvergecastMessage_l20_1 = (fsmMaxGrowable_data_length == 2'b11);
  always @(*) begin
    if(when_ConvergecastMessage_l20_1) begin
      fsmMaxGrowableU16_length = 16'hffff;
    end else begin
      if(when_ConvergecastMessage_l22_1) begin
        fsmMaxGrowableU16_length = 16'hfffe;
      end else begin
        fsmMaxGrowableU16_length = {14'd0, fsmMaxGrowable_data_length};
      end
    end
  end

  always @(*) begin
    fsmWriteStallPendingFindObstacle = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateReg) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        fsmWriteStallPendingFindObstacle = ((when_MicroBlossomBus_l792 || when_MicroBlossomBus_l809) && fsmHasPendingFindObstacle_data);
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end

  assign fsmWriteStallLoadStall = 1'b0;
  assign fsm_wantExit = 1'b0;
  always @(*) begin
    fsm_wantStart = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateReg) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
        fsm_wantStart = 1'b1;
      end
    endcase
  end

  assign fsm_wantKill = 1'b0;
  always @(*) begin
    rspPopId_enable = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((rsp_stateReg) & rsp_enumDef_stateIdle) == rsp_enumDef_stateIdle) : begin
        if(toplevel_slow_microBlossom_io_pop_m2sPipe_valid) begin
          rspPopId_enable = 1'b1;
        end
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    rspPopId_write = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((rsp_stateReg) & rsp_enumDef_stateIdle) == rsp_enumDef_stateIdle) : begin
        if(toplevel_slow_microBlossom_io_pop_m2sPipe_valid) begin
          rspPopId_write = 1'b1;
        end
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    rspPopId_writeData = 4'bxxxx;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((rsp_stateReg) & rsp_enumDef_stateIdle) == rsp_enumDef_stateIdle) : begin
        if(toplevel_slow_microBlossom_io_pop_m2sPipe_valid) begin
          rspPopId_writeData = toplevel_slow_microBlossom_io_pop_m2sPipe_payload_tag_instructionId;
        end
      end
      default : begin
      end
    endcase
  end

  assign when_OneMem_l105_9 = (rspPopId_enable && rspPopId_write);
  assign rspPopId_data = popId_register_regNextWhen_1;
  always @(*) begin
    rspMaxGrowable_enable = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((rsp_stateReg) & rsp_enumDef_stateIdle) == rsp_enumDef_stateIdle) : begin
        if(toplevel_slow_microBlossom_io_pop_m2sPipe_valid) begin
          rspMaxGrowable_enable = 1'b1;
        end
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    rspMaxGrowable_write = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((rsp_stateReg) & rsp_enumDef_stateIdle) == rsp_enumDef_stateIdle) : begin
        if(toplevel_slow_microBlossom_io_pop_m2sPipe_valid) begin
          rspMaxGrowable_write = 1'b1;
        end
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    rspMaxGrowable_writeData_length = 2'bxx;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((rsp_stateReg) & rsp_enumDef_stateIdle) == rsp_enumDef_stateIdle) : begin
        if(toplevel_slow_microBlossom_io_pop_m2sPipe_valid) begin
          rspMaxGrowable_writeData_length = toplevel_slow_microBlossom_io_pop_m2sPipe_payload_maxGrowable_length;
        end
      end
      default : begin
      end
    endcase
  end

  assign when_OneMem_l105_10 = (rspMaxGrowable_enable && rspMaxGrowable_write);
  assign rspMaxGrowable_data_length = maxGrowable_register_regNextWhen_length_1;
  always @(*) begin
    rspConflict_enable = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((rsp_stateReg) & rsp_enumDef_stateIdle) == rsp_enumDef_stateIdle) : begin
        if(toplevel_slow_microBlossom_io_pop_m2sPipe_valid) begin
          rspConflict_enable = 1'b1;
        end
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    rspConflict_write = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((rsp_stateReg) & rsp_enumDef_stateIdle) == rsp_enumDef_stateIdle) : begin
        if(toplevel_slow_microBlossom_io_pop_m2sPipe_valid) begin
          rspConflict_write = 1'b1;
        end
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    rspConflict_writeData_node1 = 5'bxxxxx;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((rsp_stateReg) & rsp_enumDef_stateIdle) == rsp_enumDef_stateIdle) : begin
        if(toplevel_slow_microBlossom_io_pop_m2sPipe_valid) begin
          rspConflict_writeData_node1 = toplevel_slow_microBlossom_io_pop_m2sPipe_payload_conflict_node1;
        end
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    rspConflict_writeData_node2 = 5'bxxxxx;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((rsp_stateReg) & rsp_enumDef_stateIdle) == rsp_enumDef_stateIdle) : begin
        if(toplevel_slow_microBlossom_io_pop_m2sPipe_valid) begin
          rspConflict_writeData_node2 = toplevel_slow_microBlossom_io_pop_m2sPipe_payload_conflict_node2;
        end
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    rspConflict_writeData_touch1 = 5'bxxxxx;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((rsp_stateReg) & rsp_enumDef_stateIdle) == rsp_enumDef_stateIdle) : begin
        if(toplevel_slow_microBlossom_io_pop_m2sPipe_valid) begin
          rspConflict_writeData_touch1 = toplevel_slow_microBlossom_io_pop_m2sPipe_payload_conflict_touch1;
        end
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    rspConflict_writeData_touch2 = 5'bxxxxx;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((rsp_stateReg) & rsp_enumDef_stateIdle) == rsp_enumDef_stateIdle) : begin
        if(toplevel_slow_microBlossom_io_pop_m2sPipe_valid) begin
          rspConflict_writeData_touch2 = toplevel_slow_microBlossom_io_pop_m2sPipe_payload_conflict_touch2;
        end
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    rspConflict_writeData_vertex1 = 5'bxxxxx;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((rsp_stateReg) & rsp_enumDef_stateIdle) == rsp_enumDef_stateIdle) : begin
        if(toplevel_slow_microBlossom_io_pop_m2sPipe_valid) begin
          rspConflict_writeData_vertex1 = toplevel_slow_microBlossom_io_pop_m2sPipe_payload_conflict_vertex1;
        end
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    rspConflict_writeData_vertex2 = 5'bxxxxx;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((rsp_stateReg) & rsp_enumDef_stateIdle) == rsp_enumDef_stateIdle) : begin
        if(toplevel_slow_microBlossom_io_pop_m2sPipe_valid) begin
          rspConflict_writeData_vertex2 = toplevel_slow_microBlossom_io_pop_m2sPipe_payload_conflict_vertex2;
        end
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    rspConflict_writeData_valid = 1'bx;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((rsp_stateReg) & rsp_enumDef_stateIdle) == rsp_enumDef_stateIdle) : begin
        if(toplevel_slow_microBlossom_io_pop_m2sPipe_valid) begin
          rspConflict_writeData_valid = toplevel_slow_microBlossom_io_pop_m2sPipe_payload_conflict_valid;
        end
      end
      default : begin
      end
    endcase
  end

  assign when_OneMem_l105_11 = (rspConflict_enable && rspConflict_write);
  assign rspConflict_data_node1 = conflict_register_regNextWhen_node1_1;
  assign rspConflict_data_node2 = conflict_register_regNextWhen_node2_1;
  assign rspConflict_data_touch1 = conflict_register_regNextWhen_touch1_1;
  assign rspConflict_data_touch2 = conflict_register_regNextWhen_touch2_1;
  assign rspConflict_data_vertex1 = conflict_register_regNextWhen_vertex1_1;
  assign rspConflict_data_vertex2 = conflict_register_regNextWhen_vertex2_1;
  assign rspConflict_data_valid = conflict_register_regNextWhen_valid_1;
  always @(*) begin
    rspParityReports_enable = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((rsp_stateReg) & rsp_enumDef_stateIdle) == rsp_enumDef_stateIdle) : begin
        if(toplevel_slow_microBlossom_io_pop_m2sPipe_valid) begin
          rspParityReports_enable = 1'b1;
        end
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    rspParityReports_write = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((rsp_stateReg) & rsp_enumDef_stateIdle) == rsp_enumDef_stateIdle) : begin
        if(toplevel_slow_microBlossom_io_pop_m2sPipe_valid) begin
          rspParityReports_write = 1'b1;
        end
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    rspAccumulatedGrown_enable = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((rsp_stateReg) & rsp_enumDef_stateIdle) == rsp_enumDef_stateIdle) : begin
        if(toplevel_slow_microBlossom_io_pop_m2sPipe_valid) begin
          rspAccumulatedGrown_enable = 1'b1;
        end
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    rspAccumulatedGrown_write = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((rsp_stateReg) & rsp_enumDef_stateIdle) == rsp_enumDef_stateIdle) : begin
        if(toplevel_slow_microBlossom_io_pop_m2sPipe_valid) begin
          rspAccumulatedGrown_write = 1'b1;
        end
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    rspAccumulatedGrown_writeData = 16'bxxxxxxxxxxxxxxxx;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((rsp_stateReg) & rsp_enumDef_stateIdle) == rsp_enumDef_stateIdle) : begin
        if(toplevel_slow_microBlossom_io_pop_m2sPipe_valid) begin
          rspAccumulatedGrown_writeData = (toplevel_slow_microBlossom_io_pop_m2sPipe_payload_grown + toplevel_slow_microBlossom_io_pop_m2sPipe_payload_tag_accumulatedGrown);
        end
      end
      default : begin
      end
    endcase
  end

  assign when_OneMem_l105_12 = (rspAccumulatedGrown_enable && rspAccumulatedGrown_write);
  assign rspAccumulatedGrown_data = accumulatedGrown_register_regNextWhen_1;
  always @(*) begin
    rspTimeFinish_upper_enable = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((rsp_stateReg) & rsp_enumDef_stateIdle) == rsp_enumDef_stateIdle) : begin
        if(toplevel_slow_microBlossom_io_pop_m2sPipe_valid) begin
          if(when_MicroBlossomBus_l864) begin
            rspTimeFinish_upper_enable = 1'b1;
          end
        end
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    rspTimeFinish_upper_write = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((rsp_stateReg) & rsp_enumDef_stateIdle) == rsp_enumDef_stateIdle) : begin
        if(toplevel_slow_microBlossom_io_pop_m2sPipe_valid) begin
          if(when_MicroBlossomBus_l864) begin
            rspTimeFinish_upper_write = 1'b1;
          end
        end
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    rspTimeFinish_upper_writeData = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((rsp_stateReg) & rsp_enumDef_stateIdle) == rsp_enumDef_stateIdle) : begin
        if(toplevel_slow_microBlossom_io_pop_m2sPipe_valid) begin
          if(when_MicroBlossomBus_l864) begin
            rspTimeFinish_upper_writeData = counter_value[63 : 32];
          end
        end
      end
      default : begin
      end
    endcase
  end

  assign when_OneMem_l105_13 = (rspTimeFinish_upper_enable && rspTimeFinish_upper_write);
  assign rspTimeFinish_upper_data = timeFinish_upper_register_regNextWhen_1;
  always @(*) begin
    rspTimeFinish_lower_enable = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((rsp_stateReg) & rsp_enumDef_stateIdle) == rsp_enumDef_stateIdle) : begin
        if(toplevel_slow_microBlossom_io_pop_m2sPipe_valid) begin
          if(when_MicroBlossomBus_l864) begin
            rspTimeFinish_lower_enable = 1'b1;
          end
        end
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    rspTimeFinish_lower_write = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((rsp_stateReg) & rsp_enumDef_stateIdle) == rsp_enumDef_stateIdle) : begin
        if(toplevel_slow_microBlossom_io_pop_m2sPipe_valid) begin
          if(when_MicroBlossomBus_l864) begin
            rspTimeFinish_lower_write = 1'b1;
          end
        end
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    rspTimeFinish_lower_writeData = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((rsp_stateReg) & rsp_enumDef_stateIdle) == rsp_enumDef_stateIdle) : begin
        if(toplevel_slow_microBlossom_io_pop_m2sPipe_valid) begin
          if(when_MicroBlossomBus_l864) begin
            rspTimeFinish_lower_writeData = counter_value[31 : 0];
          end
        end
      end
      default : begin
      end
    endcase
  end

  assign when_OneMem_l105_14 = (rspTimeFinish_lower_enable && rspTimeFinish_lower_write);
  assign rspTimeFinish_lower_data = timeFinish_lower_register_regNextWhen_1;
  always @(*) begin
    rspHasPendingFindObstacle_enable = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((rsp_stateReg) & rsp_enumDef_stateIdle) == rsp_enumDef_stateIdle) : begin
        if(toplevel_slow_microBlossom_io_pop_m2sPipe_valid) begin
          if(toplevel_slow_microBlossom_io_pop_m2sPipe_payload_tag_isFindObstacle) begin
            rspHasPendingFindObstacle_enable = 1'b1;
          end
        end
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    rspHasPendingFindObstacle_write = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((rsp_stateReg) & rsp_enumDef_stateIdle) == rsp_enumDef_stateIdle) : begin
        if(toplevel_slow_microBlossom_io_pop_m2sPipe_valid) begin
          if(toplevel_slow_microBlossom_io_pop_m2sPipe_payload_tag_isFindObstacle) begin
            rspHasPendingFindObstacle_write = 1'b1;
          end
        end
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    rspHasPendingFindObstacle_writeData = 1'bx;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((rsp_stateReg) & rsp_enumDef_stateIdle) == rsp_enumDef_stateIdle) : begin
        if(toplevel_slow_microBlossom_io_pop_m2sPipe_valid) begin
          if(toplevel_slow_microBlossom_io_pop_m2sPipe_payload_tag_isFindObstacle) begin
            rspHasPendingFindObstacle_writeData = 1'b0;
          end
        end
      end
      default : begin
      end
    endcase
  end

  assign when_OneMem_l105_15 = (rspHasPendingFindObstacle_enable && rspHasPendingFindObstacle_write);
  assign rspHasPendingFindObstacle_data = hasPendingFindObstacle_register_regNextWhen_1;
  assign rsp_wantExit = 1'b0;
  always @(*) begin
    rsp_wantStart = 1'b0;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((rsp_stateReg) & rsp_enumDef_stateIdle) == rsp_enumDef_stateIdle) : begin
      end
      default : begin
        rsp_wantStart = 1'b1;
      end
    endcase
  end

  assign rsp_wantKill = 1'b0;
  assign instruction_value = s0_wdata[31 : 0];
  assign readout_writeValue = s0_wdata[63 : 0];
  assign when_AxiLite4SlaveFactory_l68 = ((rawFactory_writeAddressMasked & (~ 23'h000007)) == 23'h000018);
  assign when_AxiLite4SlaveFactory_l68_1 = ((rawFactory_writeAddressMasked & (~ 23'h000007)) == 23'h000020);
  assign when_AxiLite4SlaveFactory_l68_2 = ((rawFactory_writeAddressMasked & (~ 23'h000007)) == 23'h000028);
  assign when_AxiLite4SlaveFactory_l68_3 = ((rawFactory_writeAddressMasked & (~ 23'h000007)) == 23'h000030);
  assign when_AxiLite4SlaveFactory_l68_4 = ((rawFactory_writeAddressMasked & (~ 23'h01ffff)) == 23'h020000);
  assign when_AxiLite4SlaveFactory_l68_5 = ((rawFactory_writeAddressMasked & (~ 23'h000fff)) == 23'h001000);
  assign when_AxiLite4SlaveFactory_l86 = ((rawFactory_readAddressMasked & (~ 23'h000007)) == 23'h000000);
  assign when_AxiLite4SlaveFactory_l86_1 = ((rawFactory_readAddressMasked & (~ 23'h000007)) == 23'h000008);
  assign when_AxiLite4SlaveFactory_l86_2 = ((rawFactory_readAddressMasked & (~ 23'h000007)) == 23'h000010);
  assign when_AxiLite4SlaveFactory_l86_3 = ((rawFactory_readAddressMasked & (~ 23'h000007)) == 23'h000018);
  assign when_AxiLite4SlaveFactory_l86_4 = ((rawFactory_readAddressMasked & (~ 23'h000007)) == 23'h000020);
  assign when_AxiLite4SlaveFactory_l86_5 = ((rawFactory_readAddressMasked & (~ 23'h000007)) == 23'h000028);
  assign when_AxiLite4SlaveFactory_l86_6 = ((rawFactory_readAddressMasked & (~ 23'h000007)) == 23'h000030);
  assign when_AxiLite4SlaveFactory_l86_7 = ((rawFactory_readAddressMasked & (~ 23'h01ffff)) == 23'h020000);
  always @(*) begin
    fsm_stateNext = fsm_stateReg;
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateReg) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
        if(isReadAsk) begin
          if(when_MicroBlossomBus_l423) begin
            if(when_Utils_l1410) begin
              fsm_stateNext = fsm_enumDef_stateReadLoadTime;
            end else begin
              if(when_Utils_l1413) begin
                fsm_stateNext = fsm_enumDef_stateReadFinishTime;
              end else begin
                if(when_Utils_l1413_1) begin
                  fsm_stateNext = fsm_enumDef_stateReadMaximumGrowth;
                end else begin
                  if(when_Utils_l1413_2) begin
                    fsm_stateNext = fsm_enumDef_stateReadParityReports;
                  end else begin
                    if(when_Utils_l1413_3) begin
                      fsm_stateNext = fsm_enumDef_stateReadObstacle;
                    end else begin
                      fsm_stateNext = fsm_enumDef_stateIdle;
                    end
                  end
                end
              end
            end
          end else begin
            fsm_stateNext = fsm_enumDef_stateIdle;
          end
        end else begin
          if(isWriteAsk) begin
            if(when_MicroBlossomBus_l449) begin
              fsm_stateNext = fsm_enumDef_stateWriteInstruction;
            end else begin
              if(when_MicroBlossomBus_l452) begin
                if(when_Utils_l1410_1) begin
                  fsm_stateNext = fsm_enumDef_stateUpdateMaximumGrowth;
                end
              end
            end
          end
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
        fsm_stateNext = fsm_enumDef_stateIdle;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
        fsm_stateNext = fsm_enumDef_stateIdle;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
        fsm_stateNext = fsm_enumDef_stateIdle;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
        if(fsmIsLastFindObstacle_data) begin
          if(when_MicroBlossomBus_l557) begin
            fsm_stateNext = fsm_enumDef_stateIdle;
            if(!when_MicroBlossomBus_l565) begin
              if(!when_MicroBlossomBus_l568) begin
                fsm_stateNext = fsm_enumDef_stateIdle;
              end
            end
          end
        end else begin
          fsm_stateNext = fsm_enumDef_stateReadIssueFindObstacleWaitPending;
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
        if(when_MicroBlossomBus_l600) begin
          fsm_stateNext = fsm_enumDef_stateReadIssueFindObstacle;
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
        if(streamFifo_1_io_push_ready) begin
          fsm_stateNext = fsm_enumDef_stateReadIssueFindObstaclePause;
        end else begin
          fsm_stateNext = fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush;
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
        fsm_stateNext = fsm_enumDef_stateReadObstacle;
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
        if(streamFifo_1_io_push_ready) begin
          fsm_stateNext = fsm_enumDef_stateReadObstacle;
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
        if(when_MicroBlossomBus_l665) begin
          fsm_stateNext = fsm_enumDef_stateIdle;
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
        fsm_stateNext = fsm_enumDef_stateIdle;
      end
      (((fsm_stateReg) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
        fsm_stateNext = fsm_enumDef_stateIdle;
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l783) begin
          if(streamFifo_1_io_push_ready) begin
            fsm_stateNext = fsm_enumDef_stateIdle;
          end else begin
            fsm_stateNext = fsm_enumDef_stateWriteWaitFiFoPush;
          end
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
        if(streamFifo_1_io_push_ready) begin
          fsm_stateNext = fsm_enumDef_stateIdle;
        end
      end
      default : begin
      end
    endcase
    if(fsm_wantStart) begin
      fsm_stateNext = fsm_enumDef_stateIdle;
    end
    if(fsm_wantKill) begin
      fsm_stateNext = fsm_enumDef_BOOT;
    end
  end

  assign when_MicroBlossomBus_l423 = ((_zz_when_MicroBlossomBus_l423 & (~ 23'h01ffff)) == 23'h020000);
  assign when_Utils_l1410 = (readout_subAddress == 7'h00);
  assign when_Utils_l1413 = (readout_subAddress == 7'h08);
  assign when_Utils_l1413_1 = (readout_subAddress == 7'h10);
  assign when_Utils_l1413_2 = (readout_subAddress == 7'h18);
  assign when_Utils_l1413_3 = ((7'h20 <= readout_subAddress) && (readout_subAddress < 7'h30));
  assign when_MicroBlossomBus_l449 = ((_zz_when_MicroBlossomBus_l449 & (~ 23'h000fff)) == 23'h001000);
  assign when_Utils_l1410_1 = (readout_writeSubAddress == 7'h10);
  assign when_Utils_l1413_4 = (readout_writeSubAddress == 7'h00);
  assign when_MicroBlossomBus_l452 = ((_zz_when_MicroBlossomBus_l452 & (~ 23'h01ffff)) == 23'h020000);
  assign _zz_fsmMaximumGrowth_writeData = readout_writeValue[15:0];
  assign when_MicroBlossomBus_l504 = (fsmMaximumGrowth_data != _zz_fsmMaximumGrowth_writeData);
  assign when_MicroBlossomBus_l557 = (fsmPushId_data == fsmPopId_data);
  assign when_MicroBlossomBus_l565 = (readout_obstacleAddress == 4'b0000);
  assign when_MicroBlossomBus_l568 = (readout_obstacleAddress == 4'b1000);
  assign when_MicroBlossomBus_l600 = (! fsmHasPendingFindObstacle_data);
  assign _zz_fsmPushId_writeData = (fsmPushId_data + 4'b0001);
  assign _zz_2 = zz__zz_dataWaitFiFoPushLooperInput_instruction(1'b0);
  always @(*) _zz_dataWaitFiFoPushLooperInput_instruction = _zz_2;
  assign _zz_dataWaitFiFoPushLooperInput_tag_instructionId = _zz_fsmPushId_writeData;
  assign _zz_dataWaitFiFoPushLooperInput_tag_accumulatedGrown = fsmAccumulatedGrown_data;
  assign _zz_dataWaitFiFoPushLooperInput_maximumGrowth = (fsmMaximumGrowth_data - fsmAccumulatedGrown_data);
  assign when_MicroBlossomBus_l665 = (fsmPushId_data == fsmPopId_data);
  assign when_MicroBlossomBus_l792 = (((instruction_value[1 : 0] == 2'b00) && (instruction_value[2] == 1'b1)) && (instruction_value[5 : 3] == 3'b000));
  assign when_MicroBlossomBus_l809 = (((instruction_value[1 : 0] == 2'b00) && (instruction_value[2] == 1'b1)) && (instruction_value[5 : 3] == 3'b100));
  assign when_MicroBlossomBus_l783 = ((! fsmWriteStallPendingFindObstacle) && (! fsmWriteStallLoadStall));
  assign _zz_fsmPushId_writeData_1 = (fsmPushId_data + 4'b0001);
  assign _zz_dataWaitFiFoPushLooperInput_instruction_1 = resizedInstruction;
  assign _zz_dataWaitFiFoPushLooperInput_tag_instructionId_1 = _zz_fsmPushId_writeData_1;
  assign _zz_dataWaitFiFoPushLooperInput_tag_isFindObstacle = when_MicroBlossomBus_l792;
  assign _zz_dataWaitFiFoPushLooperInput_tag_accumulatedGrown_1 = fsmAccumulatedGrown_data;
  always @(*) begin
    if(when_MicroBlossomBus_l792) begin
      _zz_dataWaitFiFoPushLooperInput_maximumGrowth_1 = (fsmMaximumGrowth_data - fsmAccumulatedGrown_data);
    end else begin
      _zz_dataWaitFiFoPushLooperInput_maximumGrowth_1 = 16'h0000;
    end
  end

  assign when_MicroBlossomBus_l497 = (64'h000000000000ffff < readout_writeValue);
  assign when_MicroBlossomBus_l498 = (10'h000 < readout_writeContextIdRaw);
  assign when_MicroBlossomBus_l516 = (10'h000 < readout_contextIdRaw);
  assign when_MicroBlossomBus_l530 = (10'h000 < readout_contextIdRaw);
  assign when_MicroBlossomBus_l759 = (((instruction_value[1 : 0] == 2'b10) || (((instruction_value[1 : 0] == 2'b00) && (instruction_value[2] == 1'b1)) && (instruction_value[5 : 3] == 3'b100))) || (((instruction_value[1 : 0] == 2'b00) && (instruction_value[2] == 1'b1)) && (instruction_value[5 : 3] == 3'b101)));
  always @(*) begin
    rsp_stateNext = rsp_stateReg;
    if(rsp_wantStart) begin
      rsp_stateNext = rsp_enumDef_stateIdle;
    end
    if(rsp_wantKill) begin
      rsp_stateNext = rsp_enumDef_BOOT;
    end
  end

  assign when_MicroBlossomBus_l864 = (toplevel_slow_microBlossom_io_pop_m2sPipe_payload_tag_isFindObstacle && (toplevel_slow_microBlossom_io_pop_m2sPipe_payload_maxGrowable_length == 2'b11));
  always @(posedge clk or posedge reset) begin
    if(reset) begin
      _zz_s0_bvalid_1 <= 1'b0;
      io_s0_ar_rValid <= 1'b0;
      counter_value <= 64'h0000000000000000;
      hardwareInfo_instructionCounter <= 32'h00000000;
      hardwareInfo_readoutCounter <= 32'h00000000;
      hardwareInfo_transactionCounter <= 32'h00000000;
      hardwareInfo_errorCounter <= 32'h00000000;
      toplevel_slow_microBlossom_io_pop_rValid <= 1'b0;
      maximumGrowth_register <= 16'h0000;
      accumulatedGrown_register <= 16'h0000;
      pushId_register <= 4'b0000;
      popId_register <= 4'b0000;
      timeLoad_lower_register <= 32'h00000000;
      timeLoad_upper_register <= 32'h00000000;
      timeFinish_lower_register <= 32'h00000000;
      timeFinish_upper_register <= 32'h00000000;
      isLastFindObstacle_register <= 1'b0;
      hasPendingFindObstacle_register <= 1'b0;
      fsm_stateReg <= fsm_enumDef_BOOT;
      rsp_stateReg <= rsp_enumDef_BOOT;
    end else begin
      if(_zz_rawFactory_writeJoinEvent_translated_ready_1) begin
        _zz_s0_bvalid_1 <= (rawFactory_writeJoinEvent_translated_valid && _zz_rawFactory_writeJoinEvent_translated_ready);
      end
      if(s0_arready) begin
        io_s0_ar_rValid <= s0_arvalid;
      end
      counter_value <= counter_valueNext;
      if(hasError) begin
        hardwareInfo_errorCounter <= (hardwareInfo_errorCounter + 32'h00000001);
      end
      if(slow_microBlossom_io_pop_ready) begin
        toplevel_slow_microBlossom_io_pop_rValid <= slow_microBlossom_io_pop_valid;
      end
      if(when_OneMem_l105) begin
        accumulatedGrown_register <= fsmAccumulatedGrown_writeData;
      end
      if(when_OneMem_l105_1) begin
        pushId_register <= fsmPushId_writeData;
      end
      if(when_OneMem_l105_2) begin
        maximumGrowth_register <= fsmMaximumGrowth_writeData;
      end
      if(when_OneMem_l105_3) begin
        timeLoad_lower_register <= fsmTimeLoad_lower_writeData;
      end
      if(when_OneMem_l105_4) begin
        timeLoad_upper_register <= fsmTimeLoad_upper_writeData;
      end
      if(when_OneMem_l105_5) begin
        timeFinish_lower_register <= fsmTimeFinish_lower_writeData;
      end
      if(when_OneMem_l105_6) begin
        timeFinish_upper_register <= fsmTimeFinish_upper_writeData;
      end
      if(when_OneMem_l105_7) begin
        isLastFindObstacle_register <= fsmIsLastFindObstacle_writeData;
      end
      if(when_OneMem_l105_8) begin
        hasPendingFindObstacle_register <= fsmHasPendingFindObstacle_writeData;
      end
      if(when_OneMem_l105_9) begin
        popId_register <= rspPopId_writeData;
      end
      if(when_OneMem_l105_12) begin
        accumulatedGrown_register <= rspAccumulatedGrown_writeData;
      end
      if(when_OneMem_l105_13) begin
        timeFinish_upper_register <= rspTimeFinish_upper_writeData;
      end
      if(when_OneMem_l105_14) begin
        timeFinish_lower_register <= rspTimeFinish_lower_writeData;
      end
      if(when_OneMem_l105_15) begin
        hasPendingFindObstacle_register <= rspHasPendingFindObstacle_writeData;
      end
      if(when_AxiLite4SlaveFactory_l68) begin
        if(rawFactory_writeOccur) begin
          hardwareInfo_instructionCounter[31 : 0] <= _zz_hardwareInfo_instructionCounter;
        end
      end
      if(when_AxiLite4SlaveFactory_l68_1) begin
        if(rawFactory_writeOccur) begin
          hardwareInfo_readoutCounter[31 : 0] <= _zz_hardwareInfo_readoutCounter;
        end
      end
      if(when_AxiLite4SlaveFactory_l68_2) begin
        if(rawFactory_writeOccur) begin
          hardwareInfo_transactionCounter[31 : 0] <= _zz_hardwareInfo_transactionCounter;
        end
      end
      if(when_AxiLite4SlaveFactory_l68_3) begin
        if(rawFactory_writeOccur) begin
          hardwareInfo_errorCounter[31 : 0] <= _zz_hardwareInfo_errorCounter;
        end
      end
      if(when_AxiLite4SlaveFactory_l68_4) begin
        if(rawFactory_writeOccur) begin
          hardwareInfo_transactionCounter <= (hardwareInfo_transactionCounter + 32'h00000001);
        end
      end
      if(when_AxiLite4SlaveFactory_l68_5) begin
        if(rawFactory_writeOccur) begin
          hardwareInfo_transactionCounter <= (hardwareInfo_transactionCounter + 32'h00000001);
        end
      end
      if(when_AxiLite4SlaveFactory_l86_7) begin
        if(rawFactory_readOccur) begin
          hardwareInfo_transactionCounter <= (hardwareInfo_transactionCounter + 32'h00000001);
        end
      end
      fsm_stateReg <= fsm_stateNext;
      (* parallel_case *)
      case(1) // synthesis parallel_case
        (((fsm_stateReg) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
          if(isReadAsk) begin
            if(when_MicroBlossomBus_l423) begin
              if(!when_Utils_l1410) begin
                if(!when_Utils_l1413) begin
                  if(!when_Utils_l1413_1) begin
                    if(!when_Utils_l1413_2) begin
                      if(when_Utils_l1413_3) begin
                        hardwareInfo_readoutCounter <= (hardwareInfo_readoutCounter + 32'h00000001);
                      end
                    end
                  end
                end
              end
            end
          end else begin
            if(isWriteAsk) begin
              if(when_MicroBlossomBus_l449) begin
                hardwareInfo_instructionCounter <= (hardwareInfo_instructionCounter + 32'h00000001);
              end
            end
          end
        end
        (((fsm_stateReg) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
        end
        (((fsm_stateReg) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
        end
        (((fsm_stateReg) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
        end
        (((fsm_stateReg) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
        end
        (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
        end
        (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
        end
        (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
        end
        (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
        end
        (((fsm_stateReg) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
        end
        (((fsm_stateReg) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
        end
        (((fsm_stateReg) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
        end
        (((fsm_stateReg) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        end
        (((fsm_stateReg) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
        end
        default : begin
        end
      endcase
      rsp_stateReg <= rsp_stateNext;
    end
  end

  always @(posedge clk) begin
    if(_zz_rawFactory_writeJoinEvent_translated_ready_1) begin
      _zz_s0_bresp <= rawFactory_writeJoinEvent_translated_payload_resp;
    end
    if(s0_arready) begin
      io_s0_ar_rData_addr <= s0_araddr;
      io_s0_ar_rData_prot <= s0_arprot;
    end
    if(slow_microBlossom_io_pop_ready) begin
      toplevel_slow_microBlossom_io_pop_rData_maxGrowable_length <= slow_microBlossom_io_pop_payload_maxGrowable_length;
      toplevel_slow_microBlossom_io_pop_rData_conflict_node1 <= slow_microBlossom_io_pop_payload_conflict_node1;
      toplevel_slow_microBlossom_io_pop_rData_conflict_node2 <= slow_microBlossom_io_pop_payload_conflict_node2;
      toplevel_slow_microBlossom_io_pop_rData_conflict_touch1 <= slow_microBlossom_io_pop_payload_conflict_touch1;
      toplevel_slow_microBlossom_io_pop_rData_conflict_touch2 <= slow_microBlossom_io_pop_payload_conflict_touch2;
      toplevel_slow_microBlossom_io_pop_rData_conflict_vertex1 <= slow_microBlossom_io_pop_payload_conflict_vertex1;
      toplevel_slow_microBlossom_io_pop_rData_conflict_vertex2 <= slow_microBlossom_io_pop_payload_conflict_vertex2;
      toplevel_slow_microBlossom_io_pop_rData_conflict_valid <= slow_microBlossom_io_pop_payload_conflict_valid;
      toplevel_slow_microBlossom_io_pop_rData_grown <= slow_microBlossom_io_pop_payload_grown;
      toplevel_slow_microBlossom_io_pop_rData_tag_instructionId <= slow_microBlossom_io_pop_payload_tag_instructionId;
      toplevel_slow_microBlossom_io_pop_rData_tag_isFindObstacle <= slow_microBlossom_io_pop_payload_tag_isFindObstacle;
      toplevel_slow_microBlossom_io_pop_rData_tag_accumulatedGrown <= slow_microBlossom_io_pop_payload_tag_accumulatedGrown;
    end
    if(fsmAccumulatedGrown_enable) begin
      accumulatedGrown_register_regNextWhen <= accumulatedGrown_register;
    end
    if(fsmMaxGrowable_enable) begin
      maxGrowable_register_regNextWhen_length <= maxGrowable_register_length;
    end
    if(fsmConflict_enable) begin
      conflict_register_regNextWhen_node1 <= conflict_register_node1;
      conflict_register_regNextWhen_node2 <= conflict_register_node2;
      conflict_register_regNextWhen_touch1 <= conflict_register_touch1;
      conflict_register_regNextWhen_touch2 <= conflict_register_touch2;
      conflict_register_regNextWhen_vertex1 <= conflict_register_vertex1;
      conflict_register_regNextWhen_vertex2 <= conflict_register_vertex2;
      conflict_register_regNextWhen_valid <= conflict_register_valid;
    end
    if(fsmPushId_enable) begin
      pushId_register_regNextWhen <= pushId_register;
    end
    if(fsmPopId_enable) begin
      popId_register_regNextWhen <= popId_register;
    end
    if(fsmMaximumGrowth_enable) begin
      maximumGrowth_register_regNextWhen <= maximumGrowth_register;
    end
    if(fsmTimeLoad_lower_enable) begin
      timeLoad_lower_register_regNextWhen <= timeLoad_lower_register;
    end
    if(fsmTimeLoad_upper_enable) begin
      timeLoad_upper_register_regNextWhen <= timeLoad_upper_register;
    end
    if(fsmTimeFinish_lower_enable) begin
      timeFinish_lower_register_regNextWhen <= timeFinish_lower_register;
    end
    if(fsmTimeFinish_upper_enable) begin
      timeFinish_upper_register_regNextWhen <= timeFinish_upper_register;
    end
    if(fsmIsLastFindObstacle_enable) begin
      isLastFindObstacle_register_regNextWhen <= isLastFindObstacle_register;
    end
    if(fsmHasPendingFindObstacle_enable) begin
      hasPendingFindObstacle_register_regNextWhen <= hasPendingFindObstacle_register;
    end
    if(rspPopId_enable) begin
      popId_register_regNextWhen_1 <= popId_register;
    end
    if(when_OneMem_l105_10) begin
      maxGrowable_register_length <= rspMaxGrowable_writeData_length;
    end
    if(rspMaxGrowable_enable) begin
      maxGrowable_register_regNextWhen_length_1 <= maxGrowable_register_length;
    end
    if(when_OneMem_l105_11) begin
      conflict_register_node1 <= rspConflict_writeData_node1;
      conflict_register_node2 <= rspConflict_writeData_node2;
      conflict_register_touch1 <= rspConflict_writeData_touch1;
      conflict_register_touch2 <= rspConflict_writeData_touch2;
      conflict_register_vertex1 <= rspConflict_writeData_vertex1;
      conflict_register_vertex2 <= rspConflict_writeData_vertex2;
      conflict_register_valid <= rspConflict_writeData_valid;
    end
    if(rspConflict_enable) begin
      conflict_register_regNextWhen_node1_1 <= conflict_register_node1;
      conflict_register_regNextWhen_node2_1 <= conflict_register_node2;
      conflict_register_regNextWhen_touch1_1 <= conflict_register_touch1;
      conflict_register_regNextWhen_touch2_1 <= conflict_register_touch2;
      conflict_register_regNextWhen_vertex1_1 <= conflict_register_vertex1;
      conflict_register_regNextWhen_vertex2_1 <= conflict_register_vertex2;
      conflict_register_regNextWhen_valid_1 <= conflict_register_valid;
    end
    if(rspAccumulatedGrown_enable) begin
      accumulatedGrown_register_regNextWhen_1 <= accumulatedGrown_register;
    end
    if(rspTimeFinish_upper_enable) begin
      timeFinish_upper_register_regNextWhen_1 <= timeFinish_upper_register;
    end
    if(rspTimeFinish_lower_enable) begin
      timeFinish_lower_register_regNextWhen_1 <= timeFinish_lower_register;
    end
    if(rspHasPendingFindObstacle_enable) begin
      hasPendingFindObstacle_register_regNextWhen_1 <= hasPendingFindObstacle_register;
    end
    (* parallel_case *)
    case(1) // synthesis parallel_case
      (((fsm_stateReg) & fsm_enumDef_stateIdle) == fsm_enumDef_stateIdle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateUpdateMaximumGrowth) == fsm_enumDef_stateUpdateMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadParityReports) == fsm_enumDef_stateReadParityReports) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadMaximumGrowth) == fsm_enumDef_stateReadMaximumGrowth) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadObstacle) == fsm_enumDef_stateReadObstacle) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitPending) == fsm_enumDef_stateReadIssueFindObstacleWaitPending) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacle) == fsm_enumDef_stateReadIssueFindObstacle) : begin
        if(!streamFifo_1_io_push_ready) begin
          dataWaitFiFoPushLooperInput_instruction <= _zz_dataWaitFiFoPushLooperInput_instruction;
          dataWaitFiFoPushLooperInput_maximumGrowth <= _zz_dataWaitFiFoPushLooperInput_maximumGrowth;
          dataWaitFiFoPushLooperInput_tag_instructionId <= _zz_dataWaitFiFoPushLooperInput_tag_instructionId;
          dataWaitFiFoPushLooperInput_tag_isFindObstacle <= 1'b1;
          dataWaitFiFoPushLooperInput_tag_accumulatedGrown <= _zz_dataWaitFiFoPushLooperInput_tag_accumulatedGrown;
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstaclePause) == fsm_enumDef_stateReadIssueFindObstaclePause) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) == fsm_enumDef_stateReadIssueFindObstacleWaitFiFoPush) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadLoadTime) == fsm_enumDef_stateReadLoadTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateReadFinishTime) == fsm_enumDef_stateReadFinishTime) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateRead) == fsm_enumDef_stateRead) : begin
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteInstruction) == fsm_enumDef_stateWriteInstruction) : begin
        if(when_MicroBlossomBus_l783) begin
          if(!streamFifo_1_io_push_ready) begin
            dataWaitFiFoPushLooperInput_instruction <= _zz_dataWaitFiFoPushLooperInput_instruction_1;
            dataWaitFiFoPushLooperInput_maximumGrowth <= _zz_dataWaitFiFoPushLooperInput_maximumGrowth_1;
            dataWaitFiFoPushLooperInput_tag_instructionId <= _zz_dataWaitFiFoPushLooperInput_tag_instructionId_1;
            dataWaitFiFoPushLooperInput_tag_isFindObstacle <= _zz_dataWaitFiFoPushLooperInput_tag_isFindObstacle;
            dataWaitFiFoPushLooperInput_tag_accumulatedGrown <= _zz_dataWaitFiFoPushLooperInput_tag_accumulatedGrown_1;
          end
        end
      end
      (((fsm_stateReg) & fsm_enumDef_stateWriteWaitFiFoPush) == fsm_enumDef_stateWriteWaitFiFoPush) : begin
      end
      default : begin
      end
    endcase
  end


endmodule

module MicroBlossomLooper (
  input               io_push_valid,
  output              io_push_ready,
  input      [11:0]   io_push_payload_instruction,
  input      [15:0]   io_push_payload_maximumGrowth,
  input      [3:0]    io_push_payload_tag_instructionId,
  input               io_push_payload_tag_isFindObstacle,
  input      [15:0]   io_push_payload_tag_accumulatedGrown,
  output reg          io_pop_valid,
  input               io_pop_ready,
  output reg [1:0]    io_pop_payload_maxGrowable_length,
  output reg [4:0]    io_pop_payload_conflict_node1,
  output reg [4:0]    io_pop_payload_conflict_node2,
  output reg [4:0]    io_pop_payload_conflict_touch1,
  output reg [4:0]    io_pop_payload_conflict_touch2,
  output reg [4:0]    io_pop_payload_conflict_vertex1,
  output reg [4:0]    io_pop_payload_conflict_vertex2,
  output reg          io_pop_payload_conflict_valid,
  output reg [15:0]   io_pop_payload_grown,
  output reg [3:0]    io_pop_payload_tag_instructionId,
  output reg          io_pop_payload_tag_isFindObstacle,
  output reg [15:0]   io_pop_payload_tag_accumulatedGrown,
  output              io_dataLoss,
  input               clk,
  input               reset
);

  wire       [1:0]    microBlossom_io_maxGrowable_length;
  wire       [4:0]    microBlossom_io_conflict_node1;
  wire       [4:0]    microBlossom_io_conflict_node2;
  wire       [4:0]    microBlossom_io_conflict_touch1;
  wire       [4:0]    microBlossom_io_conflict_touch2;
  wire       [4:0]    microBlossom_io_conflict_vertex1;
  wire       [4:0]    microBlossom_io_conflict_vertex2;
  wire                microBlossom_io_conflict_valid;
  wire       [15:0]   _zz_growLength;
  wire       [15:0]   _zz_growLength_1;
  wire       [15:0]   _zz_growLength_2;
  wire       [15:0]   _zz_growLength_3;
  wire       [15:0]   _zz_inputInstruction;
  wire                immediateLoopback;
  wire                isDataRace;
  reg        [11:0]   inputInstruction;
  reg                 inputEntry_valid;
  reg        [15:0]   inputEntry_maximumGrowth;
  reg        [15:0]   inputEntry_grown;
  reg                 inputEntry_isLoopBackGrow;
  reg        [3:0]    inputEntry_tag_instructionId;
  reg                 inputEntry_tag_isFindObstacle;
  reg        [15:0]   inputEntry_tag_accumulatedGrown;
  reg                 pipelineEntries_0_valid;
  reg        [15:0]   pipelineEntries_0_maximumGrowth;
  reg        [15:0]   pipelineEntries_0_grown;
  reg                 pipelineEntries_0_isLoopBackGrow;
  reg        [3:0]    pipelineEntries_0_tag_instructionId;
  reg                 pipelineEntries_0_tag_isFindObstacle;
  reg        [15:0]   pipelineEntries_0_tag_accumulatedGrown;
  reg                 dataLoss;
  wire       [15:0]   growLength;
  wire                dataRaces_0;
  wire                when_MicroBlossomLooper_l118;
  wire                when_MicroBlossomLooper_l119;
  wire                when_ConvergecastMessage_l62;

  assign _zz_growLength = (pipelineEntries_0_grown + _zz_growLength_1);
  assign _zz_growLength_1 = {14'd0, microBlossom_io_maxGrowable_length};
  assign _zz_growLength_2 = (pipelineEntries_0_maximumGrowth - pipelineEntries_0_grown);
  assign _zz_growLength_3 = {14'd0, microBlossom_io_maxGrowable_length};
  assign _zz_inputInstruction = growLength;
  DistributedDual microBlossom (
    .io_message_valid       (inputEntry_valid                       ), //i
    .io_message_instruction (inputInstruction[11:0]                 ), //i
    .io_maxGrowable_length  (microBlossom_io_maxGrowable_length[1:0]), //o
    .io_conflict_node1      (microBlossom_io_conflict_node1[4:0]    ), //o
    .io_conflict_node2      (microBlossom_io_conflict_node2[4:0]    ), //o
    .io_conflict_touch1     (microBlossom_io_conflict_touch1[4:0]   ), //o
    .io_conflict_touch2     (microBlossom_io_conflict_touch2[4:0]   ), //o
    .io_conflict_vertex1    (microBlossom_io_conflict_vertex1[4:0]  ), //o
    .io_conflict_vertex2    (microBlossom_io_conflict_vertex2[4:0]  ), //o
    .io_conflict_valid      (microBlossom_io_conflict_valid         ), //o
    .clk                    (clk                                    ), //i
    .reset                  (reset                                  )  //i
  );
  assign io_dataLoss = dataLoss;
  assign immediateLoopback = (pipelineEntries_0_valid && (pipelineEntries_0_isLoopBackGrow || (((! microBlossom_io_conflict_valid) && (microBlossom_io_maxGrowable_length != 2'b11)) && (pipelineEntries_0_grown < pipelineEntries_0_maximumGrowth))));
  assign growLength = ((pipelineEntries_0_maximumGrowth < _zz_growLength) ? _zz_growLength_2 : _zz_growLength_3);
  always @(*) begin
    if(immediateLoopback) begin
      inputEntry_valid = 1'b1;
    end else begin
      inputEntry_valid = (io_push_valid && (! isDataRace));
    end
  end

  always @(*) begin
    if(immediateLoopback) begin
      inputEntry_tag_instructionId = pipelineEntries_0_tag_instructionId;
    end else begin
      inputEntry_tag_instructionId = io_push_payload_tag_instructionId;
    end
  end

  always @(*) begin
    if(immediateLoopback) begin
      inputEntry_tag_isFindObstacle = pipelineEntries_0_tag_isFindObstacle;
    end else begin
      inputEntry_tag_isFindObstacle = io_push_payload_tag_isFindObstacle;
    end
  end

  always @(*) begin
    if(immediateLoopback) begin
      inputEntry_tag_accumulatedGrown = pipelineEntries_0_tag_accumulatedGrown;
    end else begin
      inputEntry_tag_accumulatedGrown = io_push_payload_tag_accumulatedGrown;
    end
  end

  always @(*) begin
    if(immediateLoopback) begin
      inputEntry_maximumGrowth = pipelineEntries_0_maximumGrowth;
    end else begin
      inputEntry_maximumGrowth = io_push_payload_maximumGrowth;
    end
  end

  always @(*) begin
    if(immediateLoopback) begin
      if(pipelineEntries_0_isLoopBackGrow) begin
        inputEntry_grown = pipelineEntries_0_grown;
      end else begin
        inputEntry_grown = (pipelineEntries_0_grown + growLength);
      end
    end else begin
      inputEntry_grown = 16'h0000;
    end
  end

  always @(*) begin
    if(immediateLoopback) begin
      if(pipelineEntries_0_isLoopBackGrow) begin
        inputEntry_isLoopBackGrow = 1'b0;
      end else begin
        inputEntry_isLoopBackGrow = 1'b1;
      end
    end else begin
      inputEntry_isLoopBackGrow = 1'b0;
    end
  end

  always @(*) begin
    if(immediateLoopback) begin
      if(pipelineEntries_0_isLoopBackGrow) begin
        inputInstruction[11 : 2] = 10'h000;
        inputInstruction[1 : 0] = 2'b00;
        inputInstruction[2 : 2] = 1'b1;
        inputInstruction[5 : 3] = 3'b000;
      end else begin
        inputInstruction[11 : 2] = 10'h000;
        inputInstruction[1 : 0] = 2'b00;
        inputInstruction[2 : 2] = 1'b1;
        inputInstruction[5 : 3] = 3'b110;
        inputInstruction[7 : 6] = _zz_inputInstruction[1:0];
      end
    end else begin
      inputInstruction = io_push_payload_instruction;
    end
  end

  assign dataRaces_0 = pipelineEntries_0_valid;
  assign isDataRace = dataRaces_0;
  assign when_MicroBlossomLooper_l118 = (pipelineEntries_0_valid && (! immediateLoopback));
  assign when_MicroBlossomLooper_l119 = (! io_pop_ready);
  always @(*) begin
    if(when_MicroBlossomLooper_l118) begin
      io_pop_valid = 1'b1;
    end else begin
      io_pop_valid = 1'b0;
    end
  end

  always @(*) begin
    if(when_MicroBlossomLooper_l118) begin
      io_pop_payload_tag_instructionId = pipelineEntries_0_tag_instructionId;
    end else begin
      io_pop_payload_tag_instructionId = 4'bxxxx;
    end
  end

  always @(*) begin
    if(when_MicroBlossomLooper_l118) begin
      io_pop_payload_tag_isFindObstacle = pipelineEntries_0_tag_isFindObstacle;
    end else begin
      io_pop_payload_tag_isFindObstacle = 1'bx;
    end
  end

  always @(*) begin
    if(when_MicroBlossomLooper_l118) begin
      io_pop_payload_tag_accumulatedGrown = pipelineEntries_0_tag_accumulatedGrown;
    end else begin
      io_pop_payload_tag_accumulatedGrown = 16'bxxxxxxxxxxxxxxxx;
    end
  end

  always @(*) begin
    if(when_MicroBlossomLooper_l118) begin
      io_pop_payload_maxGrowable_length = microBlossom_io_maxGrowable_length;
    end else begin
      io_pop_payload_maxGrowable_length = 2'bxx;
    end
  end

  always @(*) begin
    if(when_MicroBlossomLooper_l118) begin
      io_pop_payload_conflict_valid = microBlossom_io_conflict_valid;
    end else begin
      io_pop_payload_conflict_valid = 1'bx;
    end
  end

  assign when_ConvergecastMessage_l62 = (microBlossom_io_conflict_node1 == 5'h1f);
  always @(*) begin
    if(when_MicroBlossomLooper_l118) begin
      if(when_ConvergecastMessage_l62) begin
        io_pop_payload_conflict_node1 = microBlossom_io_conflict_node2;
      end else begin
        io_pop_payload_conflict_node1 = microBlossom_io_conflict_node1;
      end
    end else begin
      io_pop_payload_conflict_node1 = 5'bxxxxx;
    end
  end

  always @(*) begin
    if(when_MicroBlossomLooper_l118) begin
      if(when_ConvergecastMessage_l62) begin
        io_pop_payload_conflict_node2 = microBlossom_io_conflict_node1;
      end else begin
        io_pop_payload_conflict_node2 = microBlossom_io_conflict_node2;
      end
    end else begin
      io_pop_payload_conflict_node2 = 5'bxxxxx;
    end
  end

  always @(*) begin
    if(when_MicroBlossomLooper_l118) begin
      if(when_ConvergecastMessage_l62) begin
        io_pop_payload_conflict_touch1 = microBlossom_io_conflict_touch2;
      end else begin
        io_pop_payload_conflict_touch1 = microBlossom_io_conflict_touch1;
      end
    end else begin
      io_pop_payload_conflict_touch1 = 5'bxxxxx;
    end
  end

  always @(*) begin
    if(when_MicroBlossomLooper_l118) begin
      if(when_ConvergecastMessage_l62) begin
        io_pop_payload_conflict_touch2 = microBlossom_io_conflict_touch1;
      end else begin
        io_pop_payload_conflict_touch2 = microBlossom_io_conflict_touch2;
      end
    end else begin
      io_pop_payload_conflict_touch2 = 5'bxxxxx;
    end
  end

  always @(*) begin
    if(when_MicroBlossomLooper_l118) begin
      if(when_ConvergecastMessage_l62) begin
        io_pop_payload_conflict_vertex1 = microBlossom_io_conflict_vertex2;
      end else begin
        io_pop_payload_conflict_vertex1 = microBlossom_io_conflict_vertex1;
      end
    end else begin
      io_pop_payload_conflict_vertex1 = 5'bxxxxx;
    end
  end

  always @(*) begin
    if(when_MicroBlossomLooper_l118) begin
      if(when_ConvergecastMessage_l62) begin
        io_pop_payload_conflict_vertex2 = microBlossom_io_conflict_vertex1;
      end else begin
        io_pop_payload_conflict_vertex2 = microBlossom_io_conflict_vertex2;
      end
    end else begin
      io_pop_payload_conflict_vertex2 = 5'bxxxxx;
    end
  end

  always @(*) begin
    if(when_MicroBlossomLooper_l118) begin
      io_pop_payload_grown = pipelineEntries_0_grown;
    end else begin
      io_pop_payload_grown = 16'bxxxxxxxxxxxxxxxx;
    end
  end

  assign io_push_ready = ((io_push_valid && (! isDataRace)) && (! immediateLoopback));
  always @(posedge clk or posedge reset) begin
    if(reset) begin
      pipelineEntries_0_valid <= 1'b0;
      pipelineEntries_0_maximumGrowth <= 16'bxxxxxxxxxxxxxxxx;
      pipelineEntries_0_grown <= 16'bxxxxxxxxxxxxxxxx;
      pipelineEntries_0_isLoopBackGrow <= 1'bx;
      pipelineEntries_0_tag_instructionId <= 4'bxxxx;
      pipelineEntries_0_tag_isFindObstacle <= 1'bx;
      pipelineEntries_0_tag_accumulatedGrown <= 16'bxxxxxxxxxxxxxxxx;
      dataLoss <= 1'b0;
    end else begin
      pipelineEntries_0_valid <= inputEntry_valid;
      pipelineEntries_0_maximumGrowth <= inputEntry_maximumGrowth;
      pipelineEntries_0_grown <= inputEntry_grown;
      pipelineEntries_0_isLoopBackGrow <= inputEntry_isLoopBackGrow;
      pipelineEntries_0_tag_instructionId <= inputEntry_tag_instructionId;
      pipelineEntries_0_tag_isFindObstacle <= inputEntry_tag_isFindObstacle;
      pipelineEntries_0_tag_accumulatedGrown <= inputEntry_tag_accumulatedGrown;
      if(when_MicroBlossomLooper_l118) begin
        if(when_MicroBlossomLooper_l119) begin
          dataLoss <= 1'b1;
        end
      end
    end
  end


endmodule

module StreamFifo (
  input               io_push_valid,
  output              io_push_ready,
  input      [11:0]   io_push_payload_instruction,
  input      [15:0]   io_push_payload_maximumGrowth,
  input      [3:0]    io_push_payload_tag_instructionId,
  input               io_push_payload_tag_isFindObstacle,
  input      [15:0]   io_push_payload_tag_accumulatedGrown,
  output              io_pop_valid,
  input               io_pop_ready,
  output     [11:0]   io_pop_payload_instruction,
  output     [15:0]   io_pop_payload_maximumGrowth,
  output     [3:0]    io_pop_payload_tag_instructionId,
  output              io_pop_payload_tag_isFindObstacle,
  output     [15:0]   io_pop_payload_tag_accumulatedGrown,
  input               io_flush,
  output     [2:0]    io_occupancy,
  output     [2:0]    io_availability,
  input               clk,
  input               reset
);

  wire       [48:0]   _zz_logic_ram_port1;
  wire       [48:0]   _zz_logic_ram_port;
  reg                 _zz_1;
  wire                logic_ptr_doPush;
  wire                logic_ptr_doPop;
  wire                logic_ptr_full;
  wire                logic_ptr_empty;
  reg        [2:0]    logic_ptr_push;
  reg        [2:0]    logic_ptr_pop;
  wire       [2:0]    logic_ptr_occupancy;
  wire       [2:0]    logic_ptr_popOnIo;
  wire                when_Stream_l1183;
  reg                 logic_ptr_wentUp;
  wire                io_push_fire;
  wire                logic_push_onRam_write_valid;
  wire       [1:0]    logic_push_onRam_write_payload_address;
  wire       [11:0]   logic_push_onRam_write_payload_data_instruction;
  wire       [15:0]   logic_push_onRam_write_payload_data_maximumGrowth;
  wire       [3:0]    logic_push_onRam_write_payload_data_tag_instructionId;
  wire                logic_push_onRam_write_payload_data_tag_isFindObstacle;
  wire       [15:0]   logic_push_onRam_write_payload_data_tag_accumulatedGrown;
  wire                logic_pop_addressGen_valid;
  wire                logic_pop_addressGen_ready;
  wire       [1:0]    logic_pop_addressGen_payload;
  wire                logic_pop_addressGen_fire;
  wire       [11:0]   logic_pop_async_readed_instruction;
  wire       [15:0]   logic_pop_async_readed_maximumGrowth;
  wire       [3:0]    logic_pop_async_readed_tag_instructionId;
  wire                logic_pop_async_readed_tag_isFindObstacle;
  wire       [15:0]   logic_pop_async_readed_tag_accumulatedGrown;
  wire       [48:0]   _zz_logic_pop_async_readed_instruction;
  wire       [20:0]   _zz_logic_pop_async_readed_tag_instructionId;
  wire                logic_pop_addressGen_translated_valid;
  wire                logic_pop_addressGen_translated_ready;
  wire       [11:0]   logic_pop_addressGen_translated_payload_instruction;
  wire       [15:0]   logic_pop_addressGen_translated_payload_maximumGrowth;
  wire       [3:0]    logic_pop_addressGen_translated_payload_tag_instructionId;
  wire                logic_pop_addressGen_translated_payload_tag_isFindObstacle;
  wire       [15:0]   logic_pop_addressGen_translated_payload_tag_accumulatedGrown;
  (* ram_style = "distributed" *) reg [48:0] logic_ram [0:3];

  assign _zz_logic_ram_port = {{logic_push_onRam_write_payload_data_tag_accumulatedGrown,{logic_push_onRam_write_payload_data_tag_isFindObstacle,logic_push_onRam_write_payload_data_tag_instructionId}},{logic_push_onRam_write_payload_data_maximumGrowth,logic_push_onRam_write_payload_data_instruction}};
  always @(posedge clk) begin
    if(_zz_1) begin
      logic_ram[logic_push_onRam_write_payload_address] <= _zz_logic_ram_port;
    end
  end

  assign _zz_logic_ram_port1 = logic_ram[logic_pop_addressGen_payload];
  always @(*) begin
    _zz_1 = 1'b0;
    if(logic_push_onRam_write_valid) begin
      _zz_1 = 1'b1;
    end
  end

  assign when_Stream_l1183 = (logic_ptr_doPush != logic_ptr_doPop);
  assign logic_ptr_full = (((logic_ptr_push ^ logic_ptr_popOnIo) ^ 3'b100) == 3'b000);
  assign logic_ptr_empty = (logic_ptr_push == logic_ptr_pop);
  assign logic_ptr_occupancy = (logic_ptr_push - logic_ptr_popOnIo);
  assign io_push_ready = (! logic_ptr_full);
  assign io_push_fire = (io_push_valid && io_push_ready);
  assign logic_ptr_doPush = io_push_fire;
  assign logic_push_onRam_write_valid = io_push_fire;
  assign logic_push_onRam_write_payload_address = logic_ptr_push[1:0];
  assign logic_push_onRam_write_payload_data_instruction = io_push_payload_instruction;
  assign logic_push_onRam_write_payload_data_maximumGrowth = io_push_payload_maximumGrowth;
  assign logic_push_onRam_write_payload_data_tag_instructionId = io_push_payload_tag_instructionId;
  assign logic_push_onRam_write_payload_data_tag_isFindObstacle = io_push_payload_tag_isFindObstacle;
  assign logic_push_onRam_write_payload_data_tag_accumulatedGrown = io_push_payload_tag_accumulatedGrown;
  assign logic_pop_addressGen_valid = (! logic_ptr_empty);
  assign logic_pop_addressGen_payload = logic_ptr_pop[1:0];
  assign logic_pop_addressGen_fire = (logic_pop_addressGen_valid && logic_pop_addressGen_ready);
  assign logic_ptr_doPop = logic_pop_addressGen_fire;
  assign _zz_logic_pop_async_readed_instruction = _zz_logic_ram_port1;
  assign logic_pop_async_readed_instruction = _zz_logic_pop_async_readed_instruction[11 : 0];
  assign logic_pop_async_readed_maximumGrowth = _zz_logic_pop_async_readed_instruction[27 : 12];
  assign _zz_logic_pop_async_readed_tag_instructionId = _zz_logic_pop_async_readed_instruction[48 : 28];
  assign logic_pop_async_readed_tag_instructionId = _zz_logic_pop_async_readed_tag_instructionId[3 : 0];
  assign logic_pop_async_readed_tag_isFindObstacle = _zz_logic_pop_async_readed_tag_instructionId[4];
  assign logic_pop_async_readed_tag_accumulatedGrown = _zz_logic_pop_async_readed_tag_instructionId[20 : 5];
  assign logic_pop_addressGen_translated_valid = logic_pop_addressGen_valid;
  assign logic_pop_addressGen_ready = logic_pop_addressGen_translated_ready;
  assign logic_pop_addressGen_translated_payload_instruction = logic_pop_async_readed_instruction;
  assign logic_pop_addressGen_translated_payload_maximumGrowth = logic_pop_async_readed_maximumGrowth;
  assign logic_pop_addressGen_translated_payload_tag_instructionId = logic_pop_async_readed_tag_instructionId;
  assign logic_pop_addressGen_translated_payload_tag_isFindObstacle = logic_pop_async_readed_tag_isFindObstacle;
  assign logic_pop_addressGen_translated_payload_tag_accumulatedGrown = logic_pop_async_readed_tag_accumulatedGrown;
  assign io_pop_valid = logic_pop_addressGen_translated_valid;
  assign logic_pop_addressGen_translated_ready = io_pop_ready;
  assign io_pop_payload_instruction = logic_pop_addressGen_translated_payload_instruction;
  assign io_pop_payload_maximumGrowth = logic_pop_addressGen_translated_payload_maximumGrowth;
  assign io_pop_payload_tag_instructionId = logic_pop_addressGen_translated_payload_tag_instructionId;
  assign io_pop_payload_tag_isFindObstacle = logic_pop_addressGen_translated_payload_tag_isFindObstacle;
  assign io_pop_payload_tag_accumulatedGrown = logic_pop_addressGen_translated_payload_tag_accumulatedGrown;
  assign logic_ptr_popOnIo = logic_ptr_pop;
  assign io_occupancy = logic_ptr_occupancy;
  assign io_availability = (3'b100 - logic_ptr_occupancy);
  always @(posedge clk or posedge reset) begin
    if(reset) begin
      logic_ptr_push <= 3'b000;
      logic_ptr_pop <= 3'b000;
      logic_ptr_wentUp <= 1'b0;
    end else begin
      if(when_Stream_l1183) begin
        logic_ptr_wentUp <= logic_ptr_doPush;
      end
      if(io_flush) begin
        logic_ptr_wentUp <= 1'b0;
      end
      if(logic_ptr_doPush) begin
        logic_ptr_push <= (logic_ptr_push + 3'b001);
      end
      if(logic_ptr_doPop) begin
        logic_ptr_pop <= (logic_ptr_pop + 3'b001);
      end
      if(io_flush) begin
        logic_ptr_push <= 3'b000;
        logic_ptr_pop <= 3'b000;
      end
    end
  end


endmodule

module DistributedDual (
  input               io_message_valid,
  input      [11:0]   io_message_instruction,
  output     [1:0]    io_maxGrowable_length,
  output     [4:0]    io_conflict_node1,
  output     [4:0]    io_conflict_node2,
  output     [4:0]    io_conflict_touch1,
  output     [4:0]    io_conflict_touch2,
  output     [4:0]    io_conflict_vertex1,
  output     [4:0]    io_conflict_vertex2,
  output              io_conflict_valid,
  input               clk,
  input               reset
);

  wire       [1:0]    vertices_0_io_stageOutputs_offloadGet_state_speed;
  wire       [4:0]    vertices_0_io_stageOutputs_offloadGet_state_node;
  wire       [4:0]    vertices_0_io_stageOutputs_offloadGet_state_root;
  wire                vertices_0_io_stageOutputs_offloadGet_state_isVirtual;
  wire                vertices_0_io_stageOutputs_offloadGet_state_isDefect;
  wire       [1:0]    vertices_0_io_stageOutputs_offloadGet_state_grown;
  wire                vertices_0_io_stageOutputs_offloadGet_message_valid;
  wire       [11:0]   vertices_0_io_stageOutputs_offloadGet_message_instruction;
  wire                vertices_0_io_stageOutputs_offloadGet_message_isReset;
  wire       [1:0]    vertices_0_io_stageOutputs_offloadGet2_state_speed;
  wire       [4:0]    vertices_0_io_stageOutputs_offloadGet2_state_node;
  wire       [4:0]    vertices_0_io_stageOutputs_offloadGet2_state_root;
  wire                vertices_0_io_stageOutputs_offloadGet2_state_isVirtual;
  wire                vertices_0_io_stageOutputs_offloadGet2_state_isDefect;
  wire       [1:0]    vertices_0_io_stageOutputs_offloadGet2_state_grown;
  wire                vertices_0_io_stageOutputs_offloadGet2_message_valid;
  wire       [11:0]   vertices_0_io_stageOutputs_offloadGet2_message_instruction;
  wire                vertices_0_io_stageOutputs_offloadGet2_message_isReset;
  wire       [1:0]    vertices_0_io_stageOutputs_offloadGet3_state_speed;
  wire       [4:0]    vertices_0_io_stageOutputs_offloadGet3_state_node;
  wire       [4:0]    vertices_0_io_stageOutputs_offloadGet3_state_root;
  wire                vertices_0_io_stageOutputs_offloadGet3_state_isVirtual;
  wire                vertices_0_io_stageOutputs_offloadGet3_state_isDefect;
  wire       [1:0]    vertices_0_io_stageOutputs_offloadGet3_state_grown;
  wire                vertices_0_io_stageOutputs_offloadGet3_message_valid;
  wire       [11:0]   vertices_0_io_stageOutputs_offloadGet3_message_instruction;
  wire                vertices_0_io_stageOutputs_offloadGet3_message_isReset;
  wire                vertices_0_io_stageOutputs_offloadGet3_isUniqueTight;
  wire                vertices_0_io_stageOutputs_offloadGet3_isIsolated;
  wire       [1:0]    vertices_0_io_stageOutputs_offloadGet4_state_speed;
  wire       [4:0]    vertices_0_io_stageOutputs_offloadGet4_state_node;
  wire       [4:0]    vertices_0_io_stageOutputs_offloadGet4_state_root;
  wire                vertices_0_io_stageOutputs_offloadGet4_state_isVirtual;
  wire                vertices_0_io_stageOutputs_offloadGet4_state_isDefect;
  wire       [1:0]    vertices_0_io_stageOutputs_offloadGet4_state_grown;
  wire                vertices_0_io_stageOutputs_offloadGet4_message_valid;
  wire       [11:0]   vertices_0_io_stageOutputs_offloadGet4_message_instruction;
  wire                vertices_0_io_stageOutputs_offloadGet4_message_isReset;
  wire       [1:0]    vertices_0_io_stageOutputs_executeGet_state_speed;
  wire       [4:0]    vertices_0_io_stageOutputs_executeGet_state_node;
  wire       [4:0]    vertices_0_io_stageOutputs_executeGet_state_root;
  wire                vertices_0_io_stageOutputs_executeGet_state_isVirtual;
  wire                vertices_0_io_stageOutputs_executeGet_state_isDefect;
  wire       [1:0]    vertices_0_io_stageOutputs_executeGet_state_grown;
  wire                vertices_0_io_stageOutputs_executeGet_message_valid;
  wire       [11:0]   vertices_0_io_stageOutputs_executeGet_message_instruction;
  wire                vertices_0_io_stageOutputs_executeGet_message_isReset;
  wire                vertices_0_io_stageOutputs_executeGet_isStalled;
  wire       [1:0]    vertices_0_io_stageOutputs_executeGet2_state_speed;
  wire       [4:0]    vertices_0_io_stageOutputs_executeGet2_state_node;
  wire       [4:0]    vertices_0_io_stageOutputs_executeGet2_state_root;
  wire                vertices_0_io_stageOutputs_executeGet2_state_isVirtual;
  wire                vertices_0_io_stageOutputs_executeGet2_state_isDefect;
  wire       [1:0]    vertices_0_io_stageOutputs_executeGet2_state_grown;
  wire                vertices_0_io_stageOutputs_executeGet2_isStalled;
  wire                vertices_0_io_stageOutputs_executeGet2_compact_valid;
  wire                vertices_0_io_stageOutputs_executeGet2_compact_isReset;
  wire       [1:0]    vertices_0_io_stageOutputs_executeGet3_state_speed;
  wire       [4:0]    vertices_0_io_stageOutputs_executeGet3_state_node;
  wire       [4:0]    vertices_0_io_stageOutputs_executeGet3_state_root;
  wire                vertices_0_io_stageOutputs_executeGet3_state_isVirtual;
  wire                vertices_0_io_stageOutputs_executeGet3_state_isDefect;
  wire       [1:0]    vertices_0_io_stageOutputs_executeGet3_state_grown;
  wire                vertices_0_io_stageOutputs_executeGet3_isStalled;
  wire                vertices_0_io_stageOutputs_executeGet3_compact_valid;
  wire                vertices_0_io_stageOutputs_executeGet3_compact_isReset;
  wire       [1:0]    vertices_0_io_stageOutputs_updateGet_state_speed;
  wire       [4:0]    vertices_0_io_stageOutputs_updateGet_state_node;
  wire       [4:0]    vertices_0_io_stageOutputs_updateGet_state_root;
  wire                vertices_0_io_stageOutputs_updateGet_state_isVirtual;
  wire                vertices_0_io_stageOutputs_updateGet_state_isDefect;
  wire       [1:0]    vertices_0_io_stageOutputs_updateGet_state_grown;
  wire                vertices_0_io_stageOutputs_updateGet_isStalled;
  wire                vertices_0_io_stageOutputs_updateGet_compact_valid;
  wire                vertices_0_io_stageOutputs_updateGet_compact_isReset;
  wire                vertices_0_io_stageOutputs_updateGet_propagatingPeer_valid;
  wire       [4:0]    vertices_0_io_stageOutputs_updateGet_propagatingPeer_node;
  wire       [4:0]    vertices_0_io_stageOutputs_updateGet_propagatingPeer_root;
  wire       [1:0]    vertices_0_io_stageOutputs_updateGet2_state_speed;
  wire       [4:0]    vertices_0_io_stageOutputs_updateGet2_state_node;
  wire       [4:0]    vertices_0_io_stageOutputs_updateGet2_state_root;
  wire                vertices_0_io_stageOutputs_updateGet2_state_isVirtual;
  wire                vertices_0_io_stageOutputs_updateGet2_state_isDefect;
  wire       [1:0]    vertices_0_io_stageOutputs_updateGet2_state_grown;
  wire                vertices_0_io_stageOutputs_updateGet2_isStalled;
  wire                vertices_0_io_stageOutputs_updateGet2_compact_valid;
  wire                vertices_0_io_stageOutputs_updateGet2_compact_isReset;
  wire                vertices_0_io_stageOutputs_updateGet2_propagatingPeer_valid;
  wire       [4:0]    vertices_0_io_stageOutputs_updateGet2_propagatingPeer_node;
  wire       [4:0]    vertices_0_io_stageOutputs_updateGet2_propagatingPeer_root;
  wire       [1:0]    vertices_0_io_stageOutputs_updateGet3_state_speed;
  wire       [4:0]    vertices_0_io_stageOutputs_updateGet3_state_node;
  wire       [4:0]    vertices_0_io_stageOutputs_updateGet3_state_root;
  wire                vertices_0_io_stageOutputs_updateGet3_state_isVirtual;
  wire                vertices_0_io_stageOutputs_updateGet3_state_isDefect;
  wire       [1:0]    vertices_0_io_stageOutputs_updateGet3_state_grown;
  wire       [1:0]    vertices_0_io_stageOutputs_updateGet3_shadow_speed;
  wire       [4:0]    vertices_0_io_stageOutputs_updateGet3_shadow_node;
  wire       [4:0]    vertices_0_io_stageOutputs_updateGet3_shadow_root;
  wire                vertices_0_io_stageOutputs_updateGet3_compact_valid;
  wire                vertices_0_io_stageOutputs_updateGet3_compact_isReset;
  wire       [1:0]    vertices_0_io_maxGrowable_length;
  wire       [1:0]    vertices_1_io_stageOutputs_offloadGet_state_speed;
  wire       [4:0]    vertices_1_io_stageOutputs_offloadGet_state_node;
  wire       [4:0]    vertices_1_io_stageOutputs_offloadGet_state_root;
  wire                vertices_1_io_stageOutputs_offloadGet_state_isVirtual;
  wire                vertices_1_io_stageOutputs_offloadGet_state_isDefect;
  wire       [1:0]    vertices_1_io_stageOutputs_offloadGet_state_grown;
  wire                vertices_1_io_stageOutputs_offloadGet_message_valid;
  wire       [11:0]   vertices_1_io_stageOutputs_offloadGet_message_instruction;
  wire                vertices_1_io_stageOutputs_offloadGet_message_isReset;
  wire       [1:0]    vertices_1_io_stageOutputs_offloadGet2_state_speed;
  wire       [4:0]    vertices_1_io_stageOutputs_offloadGet2_state_node;
  wire       [4:0]    vertices_1_io_stageOutputs_offloadGet2_state_root;
  wire                vertices_1_io_stageOutputs_offloadGet2_state_isVirtual;
  wire                vertices_1_io_stageOutputs_offloadGet2_state_isDefect;
  wire       [1:0]    vertices_1_io_stageOutputs_offloadGet2_state_grown;
  wire                vertices_1_io_stageOutputs_offloadGet2_message_valid;
  wire       [11:0]   vertices_1_io_stageOutputs_offloadGet2_message_instruction;
  wire                vertices_1_io_stageOutputs_offloadGet2_message_isReset;
  wire       [1:0]    vertices_1_io_stageOutputs_offloadGet3_state_speed;
  wire       [4:0]    vertices_1_io_stageOutputs_offloadGet3_state_node;
  wire       [4:0]    vertices_1_io_stageOutputs_offloadGet3_state_root;
  wire                vertices_1_io_stageOutputs_offloadGet3_state_isVirtual;
  wire                vertices_1_io_stageOutputs_offloadGet3_state_isDefect;
  wire       [1:0]    vertices_1_io_stageOutputs_offloadGet3_state_grown;
  wire                vertices_1_io_stageOutputs_offloadGet3_message_valid;
  wire       [11:0]   vertices_1_io_stageOutputs_offloadGet3_message_instruction;
  wire                vertices_1_io_stageOutputs_offloadGet3_message_isReset;
  wire                vertices_1_io_stageOutputs_offloadGet3_isUniqueTight;
  wire                vertices_1_io_stageOutputs_offloadGet3_isIsolated;
  wire       [1:0]    vertices_1_io_stageOutputs_offloadGet4_state_speed;
  wire       [4:0]    vertices_1_io_stageOutputs_offloadGet4_state_node;
  wire       [4:0]    vertices_1_io_stageOutputs_offloadGet4_state_root;
  wire                vertices_1_io_stageOutputs_offloadGet4_state_isVirtual;
  wire                vertices_1_io_stageOutputs_offloadGet4_state_isDefect;
  wire       [1:0]    vertices_1_io_stageOutputs_offloadGet4_state_grown;
  wire                vertices_1_io_stageOutputs_offloadGet4_message_valid;
  wire       [11:0]   vertices_1_io_stageOutputs_offloadGet4_message_instruction;
  wire                vertices_1_io_stageOutputs_offloadGet4_message_isReset;
  wire       [1:0]    vertices_1_io_stageOutputs_executeGet_state_speed;
  wire       [4:0]    vertices_1_io_stageOutputs_executeGet_state_node;
  wire       [4:0]    vertices_1_io_stageOutputs_executeGet_state_root;
  wire                vertices_1_io_stageOutputs_executeGet_state_isVirtual;
  wire                vertices_1_io_stageOutputs_executeGet_state_isDefect;
  wire       [1:0]    vertices_1_io_stageOutputs_executeGet_state_grown;
  wire                vertices_1_io_stageOutputs_executeGet_message_valid;
  wire       [11:0]   vertices_1_io_stageOutputs_executeGet_message_instruction;
  wire                vertices_1_io_stageOutputs_executeGet_message_isReset;
  wire                vertices_1_io_stageOutputs_executeGet_isStalled;
  wire       [1:0]    vertices_1_io_stageOutputs_executeGet2_state_speed;
  wire       [4:0]    vertices_1_io_stageOutputs_executeGet2_state_node;
  wire       [4:0]    vertices_1_io_stageOutputs_executeGet2_state_root;
  wire                vertices_1_io_stageOutputs_executeGet2_state_isVirtual;
  wire                vertices_1_io_stageOutputs_executeGet2_state_isDefect;
  wire       [1:0]    vertices_1_io_stageOutputs_executeGet2_state_grown;
  wire                vertices_1_io_stageOutputs_executeGet2_isStalled;
  wire                vertices_1_io_stageOutputs_executeGet2_compact_valid;
  wire                vertices_1_io_stageOutputs_executeGet2_compact_isReset;
  wire       [1:0]    vertices_1_io_stageOutputs_executeGet3_state_speed;
  wire       [4:0]    vertices_1_io_stageOutputs_executeGet3_state_node;
  wire       [4:0]    vertices_1_io_stageOutputs_executeGet3_state_root;
  wire                vertices_1_io_stageOutputs_executeGet3_state_isVirtual;
  wire                vertices_1_io_stageOutputs_executeGet3_state_isDefect;
  wire       [1:0]    vertices_1_io_stageOutputs_executeGet3_state_grown;
  wire                vertices_1_io_stageOutputs_executeGet3_isStalled;
  wire                vertices_1_io_stageOutputs_executeGet3_compact_valid;
  wire                vertices_1_io_stageOutputs_executeGet3_compact_isReset;
  wire       [1:0]    vertices_1_io_stageOutputs_updateGet_state_speed;
  wire       [4:0]    vertices_1_io_stageOutputs_updateGet_state_node;
  wire       [4:0]    vertices_1_io_stageOutputs_updateGet_state_root;
  wire                vertices_1_io_stageOutputs_updateGet_state_isVirtual;
  wire                vertices_1_io_stageOutputs_updateGet_state_isDefect;
  wire       [1:0]    vertices_1_io_stageOutputs_updateGet_state_grown;
  wire                vertices_1_io_stageOutputs_updateGet_isStalled;
  wire                vertices_1_io_stageOutputs_updateGet_compact_valid;
  wire                vertices_1_io_stageOutputs_updateGet_compact_isReset;
  wire                vertices_1_io_stageOutputs_updateGet_propagatingPeer_valid;
  wire       [4:0]    vertices_1_io_stageOutputs_updateGet_propagatingPeer_node;
  wire       [4:0]    vertices_1_io_stageOutputs_updateGet_propagatingPeer_root;
  wire       [1:0]    vertices_1_io_stageOutputs_updateGet2_state_speed;
  wire       [4:0]    vertices_1_io_stageOutputs_updateGet2_state_node;
  wire       [4:0]    vertices_1_io_stageOutputs_updateGet2_state_root;
  wire                vertices_1_io_stageOutputs_updateGet2_state_isVirtual;
  wire                vertices_1_io_stageOutputs_updateGet2_state_isDefect;
  wire       [1:0]    vertices_1_io_stageOutputs_updateGet2_state_grown;
  wire                vertices_1_io_stageOutputs_updateGet2_isStalled;
  wire                vertices_1_io_stageOutputs_updateGet2_compact_valid;
  wire                vertices_1_io_stageOutputs_updateGet2_compact_isReset;
  wire                vertices_1_io_stageOutputs_updateGet2_propagatingPeer_valid;
  wire       [4:0]    vertices_1_io_stageOutputs_updateGet2_propagatingPeer_node;
  wire       [4:0]    vertices_1_io_stageOutputs_updateGet2_propagatingPeer_root;
  wire       [1:0]    vertices_1_io_stageOutputs_updateGet3_state_speed;
  wire       [4:0]    vertices_1_io_stageOutputs_updateGet3_state_node;
  wire       [4:0]    vertices_1_io_stageOutputs_updateGet3_state_root;
  wire                vertices_1_io_stageOutputs_updateGet3_state_isVirtual;
  wire                vertices_1_io_stageOutputs_updateGet3_state_isDefect;
  wire       [1:0]    vertices_1_io_stageOutputs_updateGet3_state_grown;
  wire       [1:0]    vertices_1_io_stageOutputs_updateGet3_shadow_speed;
  wire       [4:0]    vertices_1_io_stageOutputs_updateGet3_shadow_node;
  wire       [4:0]    vertices_1_io_stageOutputs_updateGet3_shadow_root;
  wire                vertices_1_io_stageOutputs_updateGet3_compact_valid;
  wire                vertices_1_io_stageOutputs_updateGet3_compact_isReset;
  wire       [1:0]    vertices_1_io_maxGrowable_length;
  wire       [1:0]    vertices_2_io_stageOutputs_offloadGet_state_speed;
  wire       [4:0]    vertices_2_io_stageOutputs_offloadGet_state_node;
  wire       [4:0]    vertices_2_io_stageOutputs_offloadGet_state_root;
  wire                vertices_2_io_stageOutputs_offloadGet_state_isVirtual;
  wire                vertices_2_io_stageOutputs_offloadGet_state_isDefect;
  wire       [1:0]    vertices_2_io_stageOutputs_offloadGet_state_grown;
  wire                vertices_2_io_stageOutputs_offloadGet_message_valid;
  wire       [11:0]   vertices_2_io_stageOutputs_offloadGet_message_instruction;
  wire                vertices_2_io_stageOutputs_offloadGet_message_isReset;
  wire       [1:0]    vertices_2_io_stageOutputs_offloadGet2_state_speed;
  wire       [4:0]    vertices_2_io_stageOutputs_offloadGet2_state_node;
  wire       [4:0]    vertices_2_io_stageOutputs_offloadGet2_state_root;
  wire                vertices_2_io_stageOutputs_offloadGet2_state_isVirtual;
  wire                vertices_2_io_stageOutputs_offloadGet2_state_isDefect;
  wire       [1:0]    vertices_2_io_stageOutputs_offloadGet2_state_grown;
  wire                vertices_2_io_stageOutputs_offloadGet2_message_valid;
  wire       [11:0]   vertices_2_io_stageOutputs_offloadGet2_message_instruction;
  wire                vertices_2_io_stageOutputs_offloadGet2_message_isReset;
  wire       [1:0]    vertices_2_io_stageOutputs_offloadGet3_state_speed;
  wire       [4:0]    vertices_2_io_stageOutputs_offloadGet3_state_node;
  wire       [4:0]    vertices_2_io_stageOutputs_offloadGet3_state_root;
  wire                vertices_2_io_stageOutputs_offloadGet3_state_isVirtual;
  wire                vertices_2_io_stageOutputs_offloadGet3_state_isDefect;
  wire       [1:0]    vertices_2_io_stageOutputs_offloadGet3_state_grown;
  wire                vertices_2_io_stageOutputs_offloadGet3_message_valid;
  wire       [11:0]   vertices_2_io_stageOutputs_offloadGet3_message_instruction;
  wire                vertices_2_io_stageOutputs_offloadGet3_message_isReset;
  wire                vertices_2_io_stageOutputs_offloadGet3_isUniqueTight;
  wire                vertices_2_io_stageOutputs_offloadGet3_isIsolated;
  wire       [1:0]    vertices_2_io_stageOutputs_offloadGet4_state_speed;
  wire       [4:0]    vertices_2_io_stageOutputs_offloadGet4_state_node;
  wire       [4:0]    vertices_2_io_stageOutputs_offloadGet4_state_root;
  wire                vertices_2_io_stageOutputs_offloadGet4_state_isVirtual;
  wire                vertices_2_io_stageOutputs_offloadGet4_state_isDefect;
  wire       [1:0]    vertices_2_io_stageOutputs_offloadGet4_state_grown;
  wire                vertices_2_io_stageOutputs_offloadGet4_message_valid;
  wire       [11:0]   vertices_2_io_stageOutputs_offloadGet4_message_instruction;
  wire                vertices_2_io_stageOutputs_offloadGet4_message_isReset;
  wire       [1:0]    vertices_2_io_stageOutputs_executeGet_state_speed;
  wire       [4:0]    vertices_2_io_stageOutputs_executeGet_state_node;
  wire       [4:0]    vertices_2_io_stageOutputs_executeGet_state_root;
  wire                vertices_2_io_stageOutputs_executeGet_state_isVirtual;
  wire                vertices_2_io_stageOutputs_executeGet_state_isDefect;
  wire       [1:0]    vertices_2_io_stageOutputs_executeGet_state_grown;
  wire                vertices_2_io_stageOutputs_executeGet_message_valid;
  wire       [11:0]   vertices_2_io_stageOutputs_executeGet_message_instruction;
  wire                vertices_2_io_stageOutputs_executeGet_message_isReset;
  wire                vertices_2_io_stageOutputs_executeGet_isStalled;
  wire       [1:0]    vertices_2_io_stageOutputs_executeGet2_state_speed;
  wire       [4:0]    vertices_2_io_stageOutputs_executeGet2_state_node;
  wire       [4:0]    vertices_2_io_stageOutputs_executeGet2_state_root;
  wire                vertices_2_io_stageOutputs_executeGet2_state_isVirtual;
  wire                vertices_2_io_stageOutputs_executeGet2_state_isDefect;
  wire       [1:0]    vertices_2_io_stageOutputs_executeGet2_state_grown;
  wire                vertices_2_io_stageOutputs_executeGet2_isStalled;
  wire                vertices_2_io_stageOutputs_executeGet2_compact_valid;
  wire                vertices_2_io_stageOutputs_executeGet2_compact_isReset;
  wire       [1:0]    vertices_2_io_stageOutputs_executeGet3_state_speed;
  wire       [4:0]    vertices_2_io_stageOutputs_executeGet3_state_node;
  wire       [4:0]    vertices_2_io_stageOutputs_executeGet3_state_root;
  wire                vertices_2_io_stageOutputs_executeGet3_state_isVirtual;
  wire                vertices_2_io_stageOutputs_executeGet3_state_isDefect;
  wire       [1:0]    vertices_2_io_stageOutputs_executeGet3_state_grown;
  wire                vertices_2_io_stageOutputs_executeGet3_isStalled;
  wire                vertices_2_io_stageOutputs_executeGet3_compact_valid;
  wire                vertices_2_io_stageOutputs_executeGet3_compact_isReset;
  wire       [1:0]    vertices_2_io_stageOutputs_updateGet_state_speed;
  wire       [4:0]    vertices_2_io_stageOutputs_updateGet_state_node;
  wire       [4:0]    vertices_2_io_stageOutputs_updateGet_state_root;
  wire                vertices_2_io_stageOutputs_updateGet_state_isVirtual;
  wire                vertices_2_io_stageOutputs_updateGet_state_isDefect;
  wire       [1:0]    vertices_2_io_stageOutputs_updateGet_state_grown;
  wire                vertices_2_io_stageOutputs_updateGet_isStalled;
  wire                vertices_2_io_stageOutputs_updateGet_compact_valid;
  wire                vertices_2_io_stageOutputs_updateGet_compact_isReset;
  wire                vertices_2_io_stageOutputs_updateGet_propagatingPeer_valid;
  wire       [4:0]    vertices_2_io_stageOutputs_updateGet_propagatingPeer_node;
  wire       [4:0]    vertices_2_io_stageOutputs_updateGet_propagatingPeer_root;
  wire       [1:0]    vertices_2_io_stageOutputs_updateGet2_state_speed;
  wire       [4:0]    vertices_2_io_stageOutputs_updateGet2_state_node;
  wire       [4:0]    vertices_2_io_stageOutputs_updateGet2_state_root;
  wire                vertices_2_io_stageOutputs_updateGet2_state_isVirtual;
  wire                vertices_2_io_stageOutputs_updateGet2_state_isDefect;
  wire       [1:0]    vertices_2_io_stageOutputs_updateGet2_state_grown;
  wire                vertices_2_io_stageOutputs_updateGet2_isStalled;
  wire                vertices_2_io_stageOutputs_updateGet2_compact_valid;
  wire                vertices_2_io_stageOutputs_updateGet2_compact_isReset;
  wire                vertices_2_io_stageOutputs_updateGet2_propagatingPeer_valid;
  wire       [4:0]    vertices_2_io_stageOutputs_updateGet2_propagatingPeer_node;
  wire       [4:0]    vertices_2_io_stageOutputs_updateGet2_propagatingPeer_root;
  wire       [1:0]    vertices_2_io_stageOutputs_updateGet3_state_speed;
  wire       [4:0]    vertices_2_io_stageOutputs_updateGet3_state_node;
  wire       [4:0]    vertices_2_io_stageOutputs_updateGet3_state_root;
  wire                vertices_2_io_stageOutputs_updateGet3_state_isVirtual;
  wire                vertices_2_io_stageOutputs_updateGet3_state_isDefect;
  wire       [1:0]    vertices_2_io_stageOutputs_updateGet3_state_grown;
  wire       [1:0]    vertices_2_io_stageOutputs_updateGet3_shadow_speed;
  wire       [4:0]    vertices_2_io_stageOutputs_updateGet3_shadow_node;
  wire       [4:0]    vertices_2_io_stageOutputs_updateGet3_shadow_root;
  wire                vertices_2_io_stageOutputs_updateGet3_compact_valid;
  wire                vertices_2_io_stageOutputs_updateGet3_compact_isReset;
  wire       [1:0]    vertices_2_io_maxGrowable_length;
  wire       [1:0]    vertices_3_io_stageOutputs_offloadGet_state_speed;
  wire       [4:0]    vertices_3_io_stageOutputs_offloadGet_state_node;
  wire       [4:0]    vertices_3_io_stageOutputs_offloadGet_state_root;
  wire                vertices_3_io_stageOutputs_offloadGet_state_isVirtual;
  wire                vertices_3_io_stageOutputs_offloadGet_state_isDefect;
  wire       [1:0]    vertices_3_io_stageOutputs_offloadGet_state_grown;
  wire                vertices_3_io_stageOutputs_offloadGet_message_valid;
  wire       [11:0]   vertices_3_io_stageOutputs_offloadGet_message_instruction;
  wire                vertices_3_io_stageOutputs_offloadGet_message_isReset;
  wire       [1:0]    vertices_3_io_stageOutputs_offloadGet2_state_speed;
  wire       [4:0]    vertices_3_io_stageOutputs_offloadGet2_state_node;
  wire       [4:0]    vertices_3_io_stageOutputs_offloadGet2_state_root;
  wire                vertices_3_io_stageOutputs_offloadGet2_state_isVirtual;
  wire                vertices_3_io_stageOutputs_offloadGet2_state_isDefect;
  wire       [1:0]    vertices_3_io_stageOutputs_offloadGet2_state_grown;
  wire                vertices_3_io_stageOutputs_offloadGet2_message_valid;
  wire       [11:0]   vertices_3_io_stageOutputs_offloadGet2_message_instruction;
  wire                vertices_3_io_stageOutputs_offloadGet2_message_isReset;
  wire       [1:0]    vertices_3_io_stageOutputs_offloadGet3_state_speed;
  wire       [4:0]    vertices_3_io_stageOutputs_offloadGet3_state_node;
  wire       [4:0]    vertices_3_io_stageOutputs_offloadGet3_state_root;
  wire                vertices_3_io_stageOutputs_offloadGet3_state_isVirtual;
  wire                vertices_3_io_stageOutputs_offloadGet3_state_isDefect;
  wire       [1:0]    vertices_3_io_stageOutputs_offloadGet3_state_grown;
  wire                vertices_3_io_stageOutputs_offloadGet3_message_valid;
  wire       [11:0]   vertices_3_io_stageOutputs_offloadGet3_message_instruction;
  wire                vertices_3_io_stageOutputs_offloadGet3_message_isReset;
  wire                vertices_3_io_stageOutputs_offloadGet3_isUniqueTight;
  wire                vertices_3_io_stageOutputs_offloadGet3_isIsolated;
  wire       [1:0]    vertices_3_io_stageOutputs_offloadGet4_state_speed;
  wire       [4:0]    vertices_3_io_stageOutputs_offloadGet4_state_node;
  wire       [4:0]    vertices_3_io_stageOutputs_offloadGet4_state_root;
  wire                vertices_3_io_stageOutputs_offloadGet4_state_isVirtual;
  wire                vertices_3_io_stageOutputs_offloadGet4_state_isDefect;
  wire       [1:0]    vertices_3_io_stageOutputs_offloadGet4_state_grown;
  wire                vertices_3_io_stageOutputs_offloadGet4_message_valid;
  wire       [11:0]   vertices_3_io_stageOutputs_offloadGet4_message_instruction;
  wire                vertices_3_io_stageOutputs_offloadGet4_message_isReset;
  wire       [1:0]    vertices_3_io_stageOutputs_executeGet_state_speed;
  wire       [4:0]    vertices_3_io_stageOutputs_executeGet_state_node;
  wire       [4:0]    vertices_3_io_stageOutputs_executeGet_state_root;
  wire                vertices_3_io_stageOutputs_executeGet_state_isVirtual;
  wire                vertices_3_io_stageOutputs_executeGet_state_isDefect;
  wire       [1:0]    vertices_3_io_stageOutputs_executeGet_state_grown;
  wire                vertices_3_io_stageOutputs_executeGet_message_valid;
  wire       [11:0]   vertices_3_io_stageOutputs_executeGet_message_instruction;
  wire                vertices_3_io_stageOutputs_executeGet_message_isReset;
  wire                vertices_3_io_stageOutputs_executeGet_isStalled;
  wire       [1:0]    vertices_3_io_stageOutputs_executeGet2_state_speed;
  wire       [4:0]    vertices_3_io_stageOutputs_executeGet2_state_node;
  wire       [4:0]    vertices_3_io_stageOutputs_executeGet2_state_root;
  wire                vertices_3_io_stageOutputs_executeGet2_state_isVirtual;
  wire                vertices_3_io_stageOutputs_executeGet2_state_isDefect;
  wire       [1:0]    vertices_3_io_stageOutputs_executeGet2_state_grown;
  wire                vertices_3_io_stageOutputs_executeGet2_isStalled;
  wire                vertices_3_io_stageOutputs_executeGet2_compact_valid;
  wire                vertices_3_io_stageOutputs_executeGet2_compact_isReset;
  wire       [1:0]    vertices_3_io_stageOutputs_executeGet3_state_speed;
  wire       [4:0]    vertices_3_io_stageOutputs_executeGet3_state_node;
  wire       [4:0]    vertices_3_io_stageOutputs_executeGet3_state_root;
  wire                vertices_3_io_stageOutputs_executeGet3_state_isVirtual;
  wire                vertices_3_io_stageOutputs_executeGet3_state_isDefect;
  wire       [1:0]    vertices_3_io_stageOutputs_executeGet3_state_grown;
  wire                vertices_3_io_stageOutputs_executeGet3_isStalled;
  wire                vertices_3_io_stageOutputs_executeGet3_compact_valid;
  wire                vertices_3_io_stageOutputs_executeGet3_compact_isReset;
  wire       [1:0]    vertices_3_io_stageOutputs_updateGet_state_speed;
  wire       [4:0]    vertices_3_io_stageOutputs_updateGet_state_node;
  wire       [4:0]    vertices_3_io_stageOutputs_updateGet_state_root;
  wire                vertices_3_io_stageOutputs_updateGet_state_isVirtual;
  wire                vertices_3_io_stageOutputs_updateGet_state_isDefect;
  wire       [1:0]    vertices_3_io_stageOutputs_updateGet_state_grown;
  wire                vertices_3_io_stageOutputs_updateGet_isStalled;
  wire                vertices_3_io_stageOutputs_updateGet_compact_valid;
  wire                vertices_3_io_stageOutputs_updateGet_compact_isReset;
  wire                vertices_3_io_stageOutputs_updateGet_propagatingPeer_valid;
  wire       [4:0]    vertices_3_io_stageOutputs_updateGet_propagatingPeer_node;
  wire       [4:0]    vertices_3_io_stageOutputs_updateGet_propagatingPeer_root;
  wire       [1:0]    vertices_3_io_stageOutputs_updateGet2_state_speed;
  wire       [4:0]    vertices_3_io_stageOutputs_updateGet2_state_node;
  wire       [4:0]    vertices_3_io_stageOutputs_updateGet2_state_root;
  wire                vertices_3_io_stageOutputs_updateGet2_state_isVirtual;
  wire                vertices_3_io_stageOutputs_updateGet2_state_isDefect;
  wire       [1:0]    vertices_3_io_stageOutputs_updateGet2_state_grown;
  wire                vertices_3_io_stageOutputs_updateGet2_isStalled;
  wire                vertices_3_io_stageOutputs_updateGet2_compact_valid;
  wire                vertices_3_io_stageOutputs_updateGet2_compact_isReset;
  wire                vertices_3_io_stageOutputs_updateGet2_propagatingPeer_valid;
  wire       [4:0]    vertices_3_io_stageOutputs_updateGet2_propagatingPeer_node;
  wire       [4:0]    vertices_3_io_stageOutputs_updateGet2_propagatingPeer_root;
  wire       [1:0]    vertices_3_io_stageOutputs_updateGet3_state_speed;
  wire       [4:0]    vertices_3_io_stageOutputs_updateGet3_state_node;
  wire       [4:0]    vertices_3_io_stageOutputs_updateGet3_state_root;
  wire                vertices_3_io_stageOutputs_updateGet3_state_isVirtual;
  wire                vertices_3_io_stageOutputs_updateGet3_state_isDefect;
  wire       [1:0]    vertices_3_io_stageOutputs_updateGet3_state_grown;
  wire       [1:0]    vertices_3_io_stageOutputs_updateGet3_shadow_speed;
  wire       [4:0]    vertices_3_io_stageOutputs_updateGet3_shadow_node;
  wire       [4:0]    vertices_3_io_stageOutputs_updateGet3_shadow_root;
  wire                vertices_3_io_stageOutputs_updateGet3_compact_valid;
  wire                vertices_3_io_stageOutputs_updateGet3_compact_isReset;
  wire       [1:0]    vertices_3_io_maxGrowable_length;
  wire       [1:0]    edges_0_io_stageOutputs_offloadGet_state_weight;
  wire                edges_0_io_stageOutputs_offloadGet_compact_valid;
  wire                edges_0_io_stageOutputs_offloadGet_compact_isReset;
  wire       [1:0]    edges_0_io_stageOutputs_offloadGet2_state_weight;
  wire                edges_0_io_stageOutputs_offloadGet2_isTight;
  wire                edges_0_io_stageOutputs_offloadGet2_isTightExFusion;
  wire                edges_0_io_stageOutputs_offloadGet2_compact_valid;
  wire                edges_0_io_stageOutputs_offloadGet2_compact_isReset;
  wire       [1:0]    edges_0_io_stageOutputs_offloadGet3_state_weight;
  wire                edges_0_io_stageOutputs_offloadGet3_isTight;
  wire                edges_0_io_stageOutputs_offloadGet3_compact_valid;
  wire                edges_0_io_stageOutputs_offloadGet3_compact_isReset;
  wire       [1:0]    edges_0_io_stageOutputs_offloadGet4_state_weight;
  wire                edges_0_io_stageOutputs_offloadGet4_compact_valid;
  wire                edges_0_io_stageOutputs_offloadGet4_compact_isReset;
  wire       [1:0]    edges_0_io_stageOutputs_executeGet_state_weight;
  wire                edges_0_io_stageOutputs_executeGet_compact_valid;
  wire                edges_0_io_stageOutputs_executeGet_compact_isReset;
  wire       [1:0]    edges_0_io_stageOutputs_executeGet2_state_weight;
  wire                edges_0_io_stageOutputs_executeGet2_compact_valid;
  wire                edges_0_io_stageOutputs_executeGet2_compact_isReset;
  wire       [1:0]    edges_0_io_stageOutputs_executeGet3_state_weight;
  wire                edges_0_io_stageOutputs_executeGet3_isTight;
  wire                edges_0_io_stageOutputs_executeGet3_compact_valid;
  wire                edges_0_io_stageOutputs_executeGet3_compact_isReset;
  wire       [1:0]    edges_0_io_stageOutputs_updateGet_state_weight;
  wire       [1:0]    edges_0_io_stageOutputs_updateGet_remaining;
  wire                edges_0_io_stageOutputs_updateGet_compact_valid;
  wire                edges_0_io_stageOutputs_updateGet_compact_isReset;
  wire       [1:0]    edges_0_io_stageOutputs_updateGet2_state_weight;
  wire       [1:0]    edges_0_io_stageOutputs_updateGet2_remaining;
  wire                edges_0_io_stageOutputs_updateGet2_compact_valid;
  wire                edges_0_io_stageOutputs_updateGet2_compact_isReset;
  wire       [1:0]    edges_0_io_stageOutputs_updateGet3_state_weight;
  wire       [1:0]    edges_0_io_stageOutputs_updateGet3_remaining;
  wire                edges_0_io_stageOutputs_updateGet3_compact_valid;
  wire                edges_0_io_stageOutputs_updateGet3_compact_isReset;
  wire       [1:0]    edges_0_io_maxGrowable_length;
  wire       [4:0]    edges_0_io_conflict_node1;
  wire       [4:0]    edges_0_io_conflict_node2;
  wire       [4:0]    edges_0_io_conflict_touch1;
  wire       [4:0]    edges_0_io_conflict_touch2;
  wire       [4:0]    edges_0_io_conflict_vertex1;
  wire       [4:0]    edges_0_io_conflict_vertex2;
  wire                edges_0_io_conflict_valid;
  wire       [1:0]    edges_1_io_stageOutputs_offloadGet_state_weight;
  wire                edges_1_io_stageOutputs_offloadGet_compact_valid;
  wire                edges_1_io_stageOutputs_offloadGet_compact_isReset;
  wire       [1:0]    edges_1_io_stageOutputs_offloadGet2_state_weight;
  wire                edges_1_io_stageOutputs_offloadGet2_isTight;
  wire                edges_1_io_stageOutputs_offloadGet2_isTightExFusion;
  wire                edges_1_io_stageOutputs_offloadGet2_compact_valid;
  wire                edges_1_io_stageOutputs_offloadGet2_compact_isReset;
  wire       [1:0]    edges_1_io_stageOutputs_offloadGet3_state_weight;
  wire                edges_1_io_stageOutputs_offloadGet3_isTight;
  wire                edges_1_io_stageOutputs_offloadGet3_compact_valid;
  wire                edges_1_io_stageOutputs_offloadGet3_compact_isReset;
  wire       [1:0]    edges_1_io_stageOutputs_offloadGet4_state_weight;
  wire                edges_1_io_stageOutputs_offloadGet4_compact_valid;
  wire                edges_1_io_stageOutputs_offloadGet4_compact_isReset;
  wire       [1:0]    edges_1_io_stageOutputs_executeGet_state_weight;
  wire                edges_1_io_stageOutputs_executeGet_compact_valid;
  wire                edges_1_io_stageOutputs_executeGet_compact_isReset;
  wire       [1:0]    edges_1_io_stageOutputs_executeGet2_state_weight;
  wire                edges_1_io_stageOutputs_executeGet2_compact_valid;
  wire                edges_1_io_stageOutputs_executeGet2_compact_isReset;
  wire       [1:0]    edges_1_io_stageOutputs_executeGet3_state_weight;
  wire                edges_1_io_stageOutputs_executeGet3_isTight;
  wire                edges_1_io_stageOutputs_executeGet3_compact_valid;
  wire                edges_1_io_stageOutputs_executeGet3_compact_isReset;
  wire       [1:0]    edges_1_io_stageOutputs_updateGet_state_weight;
  wire       [1:0]    edges_1_io_stageOutputs_updateGet_remaining;
  wire                edges_1_io_stageOutputs_updateGet_compact_valid;
  wire                edges_1_io_stageOutputs_updateGet_compact_isReset;
  wire       [1:0]    edges_1_io_stageOutputs_updateGet2_state_weight;
  wire       [1:0]    edges_1_io_stageOutputs_updateGet2_remaining;
  wire                edges_1_io_stageOutputs_updateGet2_compact_valid;
  wire                edges_1_io_stageOutputs_updateGet2_compact_isReset;
  wire       [1:0]    edges_1_io_stageOutputs_updateGet3_state_weight;
  wire       [1:0]    edges_1_io_stageOutputs_updateGet3_remaining;
  wire                edges_1_io_stageOutputs_updateGet3_compact_valid;
  wire                edges_1_io_stageOutputs_updateGet3_compact_isReset;
  wire       [1:0]    edges_1_io_maxGrowable_length;
  wire       [4:0]    edges_1_io_conflict_node1;
  wire       [4:0]    edges_1_io_conflict_node2;
  wire       [4:0]    edges_1_io_conflict_touch1;
  wire       [4:0]    edges_1_io_conflict_touch2;
  wire       [4:0]    edges_1_io_conflict_vertex1;
  wire       [4:0]    edges_1_io_conflict_vertex2;
  wire                edges_1_io_conflict_valid;
  wire       [1:0]    edges_2_io_stageOutputs_offloadGet_state_weight;
  wire                edges_2_io_stageOutputs_offloadGet_compact_valid;
  wire                edges_2_io_stageOutputs_offloadGet_compact_isReset;
  wire       [1:0]    edges_2_io_stageOutputs_offloadGet2_state_weight;
  wire                edges_2_io_stageOutputs_offloadGet2_isTight;
  wire                edges_2_io_stageOutputs_offloadGet2_isTightExFusion;
  wire                edges_2_io_stageOutputs_offloadGet2_compact_valid;
  wire                edges_2_io_stageOutputs_offloadGet2_compact_isReset;
  wire       [1:0]    edges_2_io_stageOutputs_offloadGet3_state_weight;
  wire                edges_2_io_stageOutputs_offloadGet3_isTight;
  wire                edges_2_io_stageOutputs_offloadGet3_compact_valid;
  wire                edges_2_io_stageOutputs_offloadGet3_compact_isReset;
  wire       [1:0]    edges_2_io_stageOutputs_offloadGet4_state_weight;
  wire                edges_2_io_stageOutputs_offloadGet4_compact_valid;
  wire                edges_2_io_stageOutputs_offloadGet4_compact_isReset;
  wire       [1:0]    edges_2_io_stageOutputs_executeGet_state_weight;
  wire                edges_2_io_stageOutputs_executeGet_compact_valid;
  wire                edges_2_io_stageOutputs_executeGet_compact_isReset;
  wire       [1:0]    edges_2_io_stageOutputs_executeGet2_state_weight;
  wire                edges_2_io_stageOutputs_executeGet2_compact_valid;
  wire                edges_2_io_stageOutputs_executeGet2_compact_isReset;
  wire       [1:0]    edges_2_io_stageOutputs_executeGet3_state_weight;
  wire                edges_2_io_stageOutputs_executeGet3_isTight;
  wire                edges_2_io_stageOutputs_executeGet3_compact_valid;
  wire                edges_2_io_stageOutputs_executeGet3_compact_isReset;
  wire       [1:0]    edges_2_io_stageOutputs_updateGet_state_weight;
  wire       [1:0]    edges_2_io_stageOutputs_updateGet_remaining;
  wire                edges_2_io_stageOutputs_updateGet_compact_valid;
  wire                edges_2_io_stageOutputs_updateGet_compact_isReset;
  wire       [1:0]    edges_2_io_stageOutputs_updateGet2_state_weight;
  wire       [1:0]    edges_2_io_stageOutputs_updateGet2_remaining;
  wire                edges_2_io_stageOutputs_updateGet2_compact_valid;
  wire                edges_2_io_stageOutputs_updateGet2_compact_isReset;
  wire       [1:0]    edges_2_io_stageOutputs_updateGet3_state_weight;
  wire       [1:0]    edges_2_io_stageOutputs_updateGet3_remaining;
  wire                edges_2_io_stageOutputs_updateGet3_compact_valid;
  wire                edges_2_io_stageOutputs_updateGet3_compact_isReset;
  wire       [1:0]    edges_2_io_maxGrowable_length;
  wire       [4:0]    edges_2_io_conflict_node1;
  wire       [4:0]    edges_2_io_conflict_node2;
  wire       [4:0]    edges_2_io_conflict_touch1;
  wire       [4:0]    edges_2_io_conflict_touch2;
  wire       [4:0]    edges_2_io_conflict_vertex1;
  wire       [4:0]    edges_2_io_conflict_vertex2;
  wire                edges_2_io_conflict_valid;
  (* clock_buffer_type = "BUFG" *) wire                broadcastMessage_valid;
  (* clock_buffer_type = "BUFG" *) wire       [11:0]   broadcastMessage_instruction;
  (* clock_buffer_type = "BUFG" *) wire                broadcastMessage_isReset;
  wire       [1:0]    maxGrowableConvergcastTree_0_length;
  wire       [1:0]    maxGrowableConvergcastTree_1_length;
  wire       [1:0]    maxGrowableConvergcastTree_2_length;
  wire       [1:0]    maxGrowableConvergcastTree_3_length;
  wire       [1:0]    maxGrowableConvergcastTree_4_length;
  wire       [1:0]    maxGrowableConvergcastTree_5_length;
  wire       [1:0]    maxGrowableConvergcastTree_6_length;
  reg        [1:0]    maxGrowableConvergcastTree_7_length;
  reg        [1:0]    maxGrowableConvergcastTree_8_length;
  reg        [1:0]    maxGrowableConvergcastTree_9_length;
  reg        [1:0]    maxGrowableConvergcastTree_10_length;
  reg        [1:0]    maxGrowableConvergcastTree_11_length;
  reg        [1:0]    maxGrowableConvergcastTree_12_length;
  wire                when_DistributedDual_l103;
  wire                when_DistributedDual_l103_1;
  wire                when_DistributedDual_l103_2;
  wire                when_DistributedDual_l103_3;
  wire                when_DistributedDual_l103_4;
  wire                when_DistributedDual_l103_5;
  reg        [1:0]    selectedMaxGrowable_length;
  wire       [4:0]    conflictConvergecastTree_0_node1;
  wire       [4:0]    conflictConvergecastTree_0_node2;
  wire       [4:0]    conflictConvergecastTree_0_touch1;
  wire       [4:0]    conflictConvergecastTree_0_touch2;
  wire       [4:0]    conflictConvergecastTree_0_vertex1;
  wire       [4:0]    conflictConvergecastTree_0_vertex2;
  wire                conflictConvergecastTree_0_valid;
  wire       [4:0]    conflictConvergecastTree_1_node1;
  wire       [4:0]    conflictConvergecastTree_1_node2;
  wire       [4:0]    conflictConvergecastTree_1_touch1;
  wire       [4:0]    conflictConvergecastTree_1_touch2;
  wire       [4:0]    conflictConvergecastTree_1_vertex1;
  wire       [4:0]    conflictConvergecastTree_1_vertex2;
  wire                conflictConvergecastTree_1_valid;
  wire       [4:0]    conflictConvergecastTree_2_node1;
  wire       [4:0]    conflictConvergecastTree_2_node2;
  wire       [4:0]    conflictConvergecastTree_2_touch1;
  wire       [4:0]    conflictConvergecastTree_2_touch2;
  wire       [4:0]    conflictConvergecastTree_2_vertex1;
  wire       [4:0]    conflictConvergecastTree_2_vertex2;
  wire                conflictConvergecastTree_2_valid;
  reg        [4:0]    conflictConvergecastTree_3_node1;
  reg        [4:0]    conflictConvergecastTree_3_node2;
  reg        [4:0]    conflictConvergecastTree_3_touch1;
  reg        [4:0]    conflictConvergecastTree_3_touch2;
  reg        [4:0]    conflictConvergecastTree_3_vertex1;
  reg        [4:0]    conflictConvergecastTree_3_vertex2;
  reg                 conflictConvergecastTree_3_valid;
  reg        [4:0]    conflictConvergecastTree_4_node1;
  reg        [4:0]    conflictConvergecastTree_4_node2;
  reg        [4:0]    conflictConvergecastTree_4_touch1;
  reg        [4:0]    conflictConvergecastTree_4_touch2;
  reg        [4:0]    conflictConvergecastTree_4_vertex1;
  reg        [4:0]    conflictConvergecastTree_4_vertex2;
  reg                 conflictConvergecastTree_4_valid;
  reg        [4:0]    convergecastedConflict_node1;
  reg        [4:0]    convergecastedConflict_node2;
  reg        [4:0]    convergecastedConflict_touch1;
  reg        [4:0]    convergecastedConflict_touch2;
  reg        [4:0]    convergecastedConflict_vertex1;
  reg        [4:0]    convergecastedConflict_vertex2;
  reg                 convergecastedConflict_valid;

  Vertex vertices_0 (
    .io_message_valid                                 (broadcastMessage_valid                                          ), //i
    .io_message_instruction                           (broadcastMessage_instruction[11:0]                              ), //i
    .io_message_isReset                               (broadcastMessage_isReset                                        ), //i
    .io_stageOutputs_offloadGet_state_speed           (vertices_0_io_stageOutputs_offloadGet_state_speed[1:0]          ), //o
    .io_stageOutputs_offloadGet_state_node            (vertices_0_io_stageOutputs_offloadGet_state_node[4:0]           ), //o
    .io_stageOutputs_offloadGet_state_root            (vertices_0_io_stageOutputs_offloadGet_state_root[4:0]           ), //o
    .io_stageOutputs_offloadGet_state_isVirtual       (vertices_0_io_stageOutputs_offloadGet_state_isVirtual           ), //o
    .io_stageOutputs_offloadGet_state_isDefect        (vertices_0_io_stageOutputs_offloadGet_state_isDefect            ), //o
    .io_stageOutputs_offloadGet_state_grown           (vertices_0_io_stageOutputs_offloadGet_state_grown[1:0]          ), //o
    .io_stageOutputs_offloadGet_message_valid         (vertices_0_io_stageOutputs_offloadGet_message_valid             ), //o
    .io_stageOutputs_offloadGet_message_instruction   (vertices_0_io_stageOutputs_offloadGet_message_instruction[11:0] ), //o
    .io_stageOutputs_offloadGet_message_isReset       (vertices_0_io_stageOutputs_offloadGet_message_isReset           ), //o
    .io_stageOutputs_offloadGet2_state_speed          (vertices_0_io_stageOutputs_offloadGet2_state_speed[1:0]         ), //o
    .io_stageOutputs_offloadGet2_state_node           (vertices_0_io_stageOutputs_offloadGet2_state_node[4:0]          ), //o
    .io_stageOutputs_offloadGet2_state_root           (vertices_0_io_stageOutputs_offloadGet2_state_root[4:0]          ), //o
    .io_stageOutputs_offloadGet2_state_isVirtual      (vertices_0_io_stageOutputs_offloadGet2_state_isVirtual          ), //o
    .io_stageOutputs_offloadGet2_state_isDefect       (vertices_0_io_stageOutputs_offloadGet2_state_isDefect           ), //o
    .io_stageOutputs_offloadGet2_state_grown          (vertices_0_io_stageOutputs_offloadGet2_state_grown[1:0]         ), //o
    .io_stageOutputs_offloadGet2_message_valid        (vertices_0_io_stageOutputs_offloadGet2_message_valid            ), //o
    .io_stageOutputs_offloadGet2_message_instruction  (vertices_0_io_stageOutputs_offloadGet2_message_instruction[11:0]), //o
    .io_stageOutputs_offloadGet2_message_isReset      (vertices_0_io_stageOutputs_offloadGet2_message_isReset          ), //o
    .io_stageOutputs_offloadGet3_state_speed          (vertices_0_io_stageOutputs_offloadGet3_state_speed[1:0]         ), //o
    .io_stageOutputs_offloadGet3_state_node           (vertices_0_io_stageOutputs_offloadGet3_state_node[4:0]          ), //o
    .io_stageOutputs_offloadGet3_state_root           (vertices_0_io_stageOutputs_offloadGet3_state_root[4:0]          ), //o
    .io_stageOutputs_offloadGet3_state_isVirtual      (vertices_0_io_stageOutputs_offloadGet3_state_isVirtual          ), //o
    .io_stageOutputs_offloadGet3_state_isDefect       (vertices_0_io_stageOutputs_offloadGet3_state_isDefect           ), //o
    .io_stageOutputs_offloadGet3_state_grown          (vertices_0_io_stageOutputs_offloadGet3_state_grown[1:0]         ), //o
    .io_stageOutputs_offloadGet3_message_valid        (vertices_0_io_stageOutputs_offloadGet3_message_valid            ), //o
    .io_stageOutputs_offloadGet3_message_instruction  (vertices_0_io_stageOutputs_offloadGet3_message_instruction[11:0]), //o
    .io_stageOutputs_offloadGet3_message_isReset      (vertices_0_io_stageOutputs_offloadGet3_message_isReset          ), //o
    .io_stageOutputs_offloadGet3_isUniqueTight        (vertices_0_io_stageOutputs_offloadGet3_isUniqueTight            ), //o
    .io_stageOutputs_offloadGet3_isIsolated           (vertices_0_io_stageOutputs_offloadGet3_isIsolated               ), //o
    .io_stageOutputs_offloadGet4_state_speed          (vertices_0_io_stageOutputs_offloadGet4_state_speed[1:0]         ), //o
    .io_stageOutputs_offloadGet4_state_node           (vertices_0_io_stageOutputs_offloadGet4_state_node[4:0]          ), //o
    .io_stageOutputs_offloadGet4_state_root           (vertices_0_io_stageOutputs_offloadGet4_state_root[4:0]          ), //o
    .io_stageOutputs_offloadGet4_state_isVirtual      (vertices_0_io_stageOutputs_offloadGet4_state_isVirtual          ), //o
    .io_stageOutputs_offloadGet4_state_isDefect       (vertices_0_io_stageOutputs_offloadGet4_state_isDefect           ), //o
    .io_stageOutputs_offloadGet4_state_grown          (vertices_0_io_stageOutputs_offloadGet4_state_grown[1:0]         ), //o
    .io_stageOutputs_offloadGet4_message_valid        (vertices_0_io_stageOutputs_offloadGet4_message_valid            ), //o
    .io_stageOutputs_offloadGet4_message_instruction  (vertices_0_io_stageOutputs_offloadGet4_message_instruction[11:0]), //o
    .io_stageOutputs_offloadGet4_message_isReset      (vertices_0_io_stageOutputs_offloadGet4_message_isReset          ), //o
    .io_stageOutputs_executeGet_state_speed           (vertices_0_io_stageOutputs_executeGet_state_speed[1:0]          ), //o
    .io_stageOutputs_executeGet_state_node            (vertices_0_io_stageOutputs_executeGet_state_node[4:0]           ), //o
    .io_stageOutputs_executeGet_state_root            (vertices_0_io_stageOutputs_executeGet_state_root[4:0]           ), //o
    .io_stageOutputs_executeGet_state_isVirtual       (vertices_0_io_stageOutputs_executeGet_state_isVirtual           ), //o
    .io_stageOutputs_executeGet_state_isDefect        (vertices_0_io_stageOutputs_executeGet_state_isDefect            ), //o
    .io_stageOutputs_executeGet_state_grown           (vertices_0_io_stageOutputs_executeGet_state_grown[1:0]          ), //o
    .io_stageOutputs_executeGet_message_valid         (vertices_0_io_stageOutputs_executeGet_message_valid             ), //o
    .io_stageOutputs_executeGet_message_instruction   (vertices_0_io_stageOutputs_executeGet_message_instruction[11:0] ), //o
    .io_stageOutputs_executeGet_message_isReset       (vertices_0_io_stageOutputs_executeGet_message_isReset           ), //o
    .io_stageOutputs_executeGet_isStalled             (vertices_0_io_stageOutputs_executeGet_isStalled                 ), //o
    .io_stageOutputs_executeGet2_state_speed          (vertices_0_io_stageOutputs_executeGet2_state_speed[1:0]         ), //o
    .io_stageOutputs_executeGet2_state_node           (vertices_0_io_stageOutputs_executeGet2_state_node[4:0]          ), //o
    .io_stageOutputs_executeGet2_state_root           (vertices_0_io_stageOutputs_executeGet2_state_root[4:0]          ), //o
    .io_stageOutputs_executeGet2_state_isVirtual      (vertices_0_io_stageOutputs_executeGet2_state_isVirtual          ), //o
    .io_stageOutputs_executeGet2_state_isDefect       (vertices_0_io_stageOutputs_executeGet2_state_isDefect           ), //o
    .io_stageOutputs_executeGet2_state_grown          (vertices_0_io_stageOutputs_executeGet2_state_grown[1:0]         ), //o
    .io_stageOutputs_executeGet2_isStalled            (vertices_0_io_stageOutputs_executeGet2_isStalled                ), //o
    .io_stageOutputs_executeGet2_compact_valid        (vertices_0_io_stageOutputs_executeGet2_compact_valid            ), //o
    .io_stageOutputs_executeGet2_compact_isReset      (vertices_0_io_stageOutputs_executeGet2_compact_isReset          ), //o
    .io_stageOutputs_executeGet3_state_speed          (vertices_0_io_stageOutputs_executeGet3_state_speed[1:0]         ), //o
    .io_stageOutputs_executeGet3_state_node           (vertices_0_io_stageOutputs_executeGet3_state_node[4:0]          ), //o
    .io_stageOutputs_executeGet3_state_root           (vertices_0_io_stageOutputs_executeGet3_state_root[4:0]          ), //o
    .io_stageOutputs_executeGet3_state_isVirtual      (vertices_0_io_stageOutputs_executeGet3_state_isVirtual          ), //o
    .io_stageOutputs_executeGet3_state_isDefect       (vertices_0_io_stageOutputs_executeGet3_state_isDefect           ), //o
    .io_stageOutputs_executeGet3_state_grown          (vertices_0_io_stageOutputs_executeGet3_state_grown[1:0]         ), //o
    .io_stageOutputs_executeGet3_isStalled            (vertices_0_io_stageOutputs_executeGet3_isStalled                ), //o
    .io_stageOutputs_executeGet3_compact_valid        (vertices_0_io_stageOutputs_executeGet3_compact_valid            ), //o
    .io_stageOutputs_executeGet3_compact_isReset      (vertices_0_io_stageOutputs_executeGet3_compact_isReset          ), //o
    .io_stageOutputs_updateGet_state_speed            (vertices_0_io_stageOutputs_updateGet_state_speed[1:0]           ), //o
    .io_stageOutputs_updateGet_state_node             (vertices_0_io_stageOutputs_updateGet_state_node[4:0]            ), //o
    .io_stageOutputs_updateGet_state_root             (vertices_0_io_stageOutputs_updateGet_state_root[4:0]            ), //o
    .io_stageOutputs_updateGet_state_isVirtual        (vertices_0_io_stageOutputs_updateGet_state_isVirtual            ), //o
    .io_stageOutputs_updateGet_state_isDefect         (vertices_0_io_stageOutputs_updateGet_state_isDefect             ), //o
    .io_stageOutputs_updateGet_state_grown            (vertices_0_io_stageOutputs_updateGet_state_grown[1:0]           ), //o
    .io_stageOutputs_updateGet_isStalled              (vertices_0_io_stageOutputs_updateGet_isStalled                  ), //o
    .io_stageOutputs_updateGet_compact_valid          (vertices_0_io_stageOutputs_updateGet_compact_valid              ), //o
    .io_stageOutputs_updateGet_compact_isReset        (vertices_0_io_stageOutputs_updateGet_compact_isReset            ), //o
    .io_stageOutputs_updateGet_propagatingPeer_valid  (vertices_0_io_stageOutputs_updateGet_propagatingPeer_valid      ), //o
    .io_stageOutputs_updateGet_propagatingPeer_node   (vertices_0_io_stageOutputs_updateGet_propagatingPeer_node[4:0]  ), //o
    .io_stageOutputs_updateGet_propagatingPeer_root   (vertices_0_io_stageOutputs_updateGet_propagatingPeer_root[4:0]  ), //o
    .io_stageOutputs_updateGet2_state_speed           (vertices_0_io_stageOutputs_updateGet2_state_speed[1:0]          ), //o
    .io_stageOutputs_updateGet2_state_node            (vertices_0_io_stageOutputs_updateGet2_state_node[4:0]           ), //o
    .io_stageOutputs_updateGet2_state_root            (vertices_0_io_stageOutputs_updateGet2_state_root[4:0]           ), //o
    .io_stageOutputs_updateGet2_state_isVirtual       (vertices_0_io_stageOutputs_updateGet2_state_isVirtual           ), //o
    .io_stageOutputs_updateGet2_state_isDefect        (vertices_0_io_stageOutputs_updateGet2_state_isDefect            ), //o
    .io_stageOutputs_updateGet2_state_grown           (vertices_0_io_stageOutputs_updateGet2_state_grown[1:0]          ), //o
    .io_stageOutputs_updateGet2_isStalled             (vertices_0_io_stageOutputs_updateGet2_isStalled                 ), //o
    .io_stageOutputs_updateGet2_compact_valid         (vertices_0_io_stageOutputs_updateGet2_compact_valid             ), //o
    .io_stageOutputs_updateGet2_compact_isReset       (vertices_0_io_stageOutputs_updateGet2_compact_isReset           ), //o
    .io_stageOutputs_updateGet2_propagatingPeer_valid (vertices_0_io_stageOutputs_updateGet2_propagatingPeer_valid     ), //o
    .io_stageOutputs_updateGet2_propagatingPeer_node  (vertices_0_io_stageOutputs_updateGet2_propagatingPeer_node[4:0] ), //o
    .io_stageOutputs_updateGet2_propagatingPeer_root  (vertices_0_io_stageOutputs_updateGet2_propagatingPeer_root[4:0] ), //o
    .io_stageOutputs_updateGet3_state_speed           (vertices_0_io_stageOutputs_updateGet3_state_speed[1:0]          ), //o
    .io_stageOutputs_updateGet3_state_node            (vertices_0_io_stageOutputs_updateGet3_state_node[4:0]           ), //o
    .io_stageOutputs_updateGet3_state_root            (vertices_0_io_stageOutputs_updateGet3_state_root[4:0]           ), //o
    .io_stageOutputs_updateGet3_state_isVirtual       (vertices_0_io_stageOutputs_updateGet3_state_isVirtual           ), //o
    .io_stageOutputs_updateGet3_state_isDefect        (vertices_0_io_stageOutputs_updateGet3_state_isDefect            ), //o
    .io_stageOutputs_updateGet3_state_grown           (vertices_0_io_stageOutputs_updateGet3_state_grown[1:0]          ), //o
    .io_stageOutputs_updateGet3_shadow_speed          (vertices_0_io_stageOutputs_updateGet3_shadow_speed[1:0]         ), //o
    .io_stageOutputs_updateGet3_shadow_node           (vertices_0_io_stageOutputs_updateGet3_shadow_node[4:0]          ), //o
    .io_stageOutputs_updateGet3_shadow_root           (vertices_0_io_stageOutputs_updateGet3_shadow_root[4:0]          ), //o
    .io_stageOutputs_updateGet3_compact_valid         (vertices_0_io_stageOutputs_updateGet3_compact_valid             ), //o
    .io_stageOutputs_updateGet3_compact_isReset       (vertices_0_io_stageOutputs_updateGet3_compact_isReset           ), //o
    .io_edgeInputs_0_offloadGet_state_weight          (edges_0_io_stageOutputs_offloadGet_state_weight[1:0]            ), //i
    .io_edgeInputs_0_offloadGet_compact_valid         (edges_0_io_stageOutputs_offloadGet_compact_valid                ), //i
    .io_edgeInputs_0_offloadGet_compact_isReset       (edges_0_io_stageOutputs_offloadGet_compact_isReset              ), //i
    .io_edgeInputs_0_offloadGet2_state_weight         (edges_0_io_stageOutputs_offloadGet2_state_weight[1:0]           ), //i
    .io_edgeInputs_0_offloadGet2_isTight              (edges_0_io_stageOutputs_offloadGet2_isTight                     ), //i
    .io_edgeInputs_0_offloadGet2_isTightExFusion      (edges_0_io_stageOutputs_offloadGet2_isTightExFusion             ), //i
    .io_edgeInputs_0_offloadGet2_compact_valid        (edges_0_io_stageOutputs_offloadGet2_compact_valid               ), //i
    .io_edgeInputs_0_offloadGet2_compact_isReset      (edges_0_io_stageOutputs_offloadGet2_compact_isReset             ), //i
    .io_edgeInputs_0_offloadGet3_state_weight         (edges_0_io_stageOutputs_offloadGet3_state_weight[1:0]           ), //i
    .io_edgeInputs_0_offloadGet3_isTight              (edges_0_io_stageOutputs_offloadGet3_isTight                     ), //i
    .io_edgeInputs_0_offloadGet3_compact_valid        (edges_0_io_stageOutputs_offloadGet3_compact_valid               ), //i
    .io_edgeInputs_0_offloadGet3_compact_isReset      (edges_0_io_stageOutputs_offloadGet3_compact_isReset             ), //i
    .io_edgeInputs_0_offloadGet4_state_weight         (edges_0_io_stageOutputs_offloadGet4_state_weight[1:0]           ), //i
    .io_edgeInputs_0_offloadGet4_compact_valid        (edges_0_io_stageOutputs_offloadGet4_compact_valid               ), //i
    .io_edgeInputs_0_offloadGet4_compact_isReset      (edges_0_io_stageOutputs_offloadGet4_compact_isReset             ), //i
    .io_edgeInputs_0_executeGet_state_weight          (edges_0_io_stageOutputs_executeGet_state_weight[1:0]            ), //i
    .io_edgeInputs_0_executeGet_compact_valid         (edges_0_io_stageOutputs_executeGet_compact_valid                ), //i
    .io_edgeInputs_0_executeGet_compact_isReset       (edges_0_io_stageOutputs_executeGet_compact_isReset              ), //i
    .io_edgeInputs_0_executeGet2_state_weight         (edges_0_io_stageOutputs_executeGet2_state_weight[1:0]           ), //i
    .io_edgeInputs_0_executeGet2_compact_valid        (edges_0_io_stageOutputs_executeGet2_compact_valid               ), //i
    .io_edgeInputs_0_executeGet2_compact_isReset      (edges_0_io_stageOutputs_executeGet2_compact_isReset             ), //i
    .io_edgeInputs_0_executeGet3_state_weight         (edges_0_io_stageOutputs_executeGet3_state_weight[1:0]           ), //i
    .io_edgeInputs_0_executeGet3_isTight              (edges_0_io_stageOutputs_executeGet3_isTight                     ), //i
    .io_edgeInputs_0_executeGet3_compact_valid        (edges_0_io_stageOutputs_executeGet3_compact_valid               ), //i
    .io_edgeInputs_0_executeGet3_compact_isReset      (edges_0_io_stageOutputs_executeGet3_compact_isReset             ), //i
    .io_edgeInputs_0_updateGet_state_weight           (edges_0_io_stageOutputs_updateGet_state_weight[1:0]             ), //i
    .io_edgeInputs_0_updateGet_remaining              (edges_0_io_stageOutputs_updateGet_remaining[1:0]                ), //i
    .io_edgeInputs_0_updateGet_compact_valid          (edges_0_io_stageOutputs_updateGet_compact_valid                 ), //i
    .io_edgeInputs_0_updateGet_compact_isReset        (edges_0_io_stageOutputs_updateGet_compact_isReset               ), //i
    .io_edgeInputs_0_updateGet2_state_weight          (edges_0_io_stageOutputs_updateGet2_state_weight[1:0]            ), //i
    .io_edgeInputs_0_updateGet2_remaining             (edges_0_io_stageOutputs_updateGet2_remaining[1:0]               ), //i
    .io_edgeInputs_0_updateGet2_compact_valid         (edges_0_io_stageOutputs_updateGet2_compact_valid                ), //i
    .io_edgeInputs_0_updateGet2_compact_isReset       (edges_0_io_stageOutputs_updateGet2_compact_isReset              ), //i
    .io_edgeInputs_0_updateGet3_state_weight          (edges_0_io_stageOutputs_updateGet3_state_weight[1:0]            ), //i
    .io_edgeInputs_0_updateGet3_remaining             (edges_0_io_stageOutputs_updateGet3_remaining[1:0]               ), //i
    .io_edgeInputs_0_updateGet3_compact_valid         (edges_0_io_stageOutputs_updateGet3_compact_valid                ), //i
    .io_edgeInputs_0_updateGet3_compact_isReset       (edges_0_io_stageOutputs_updateGet3_compact_isReset              ), //i
    .io_edgeInputs_1_offloadGet_state_weight          (edges_2_io_stageOutputs_offloadGet_state_weight[1:0]            ), //i
    .io_edgeInputs_1_offloadGet_compact_valid         (edges_2_io_stageOutputs_offloadGet_compact_valid                ), //i
    .io_edgeInputs_1_offloadGet_compact_isReset       (edges_2_io_stageOutputs_offloadGet_compact_isReset              ), //i
    .io_edgeInputs_1_offloadGet2_state_weight         (edges_2_io_stageOutputs_offloadGet2_state_weight[1:0]           ), //i
    .io_edgeInputs_1_offloadGet2_isTight              (edges_2_io_stageOutputs_offloadGet2_isTight                     ), //i
    .io_edgeInputs_1_offloadGet2_isTightExFusion      (edges_2_io_stageOutputs_offloadGet2_isTightExFusion             ), //i
    .io_edgeInputs_1_offloadGet2_compact_valid        (edges_2_io_stageOutputs_offloadGet2_compact_valid               ), //i
    .io_edgeInputs_1_offloadGet2_compact_isReset      (edges_2_io_stageOutputs_offloadGet2_compact_isReset             ), //i
    .io_edgeInputs_1_offloadGet3_state_weight         (edges_2_io_stageOutputs_offloadGet3_state_weight[1:0]           ), //i
    .io_edgeInputs_1_offloadGet3_isTight              (edges_2_io_stageOutputs_offloadGet3_isTight                     ), //i
    .io_edgeInputs_1_offloadGet3_compact_valid        (edges_2_io_stageOutputs_offloadGet3_compact_valid               ), //i
    .io_edgeInputs_1_offloadGet3_compact_isReset      (edges_2_io_stageOutputs_offloadGet3_compact_isReset             ), //i
    .io_edgeInputs_1_offloadGet4_state_weight         (edges_2_io_stageOutputs_offloadGet4_state_weight[1:0]           ), //i
    .io_edgeInputs_1_offloadGet4_compact_valid        (edges_2_io_stageOutputs_offloadGet4_compact_valid               ), //i
    .io_edgeInputs_1_offloadGet4_compact_isReset      (edges_2_io_stageOutputs_offloadGet4_compact_isReset             ), //i
    .io_edgeInputs_1_executeGet_state_weight          (edges_2_io_stageOutputs_executeGet_state_weight[1:0]            ), //i
    .io_edgeInputs_1_executeGet_compact_valid         (edges_2_io_stageOutputs_executeGet_compact_valid                ), //i
    .io_edgeInputs_1_executeGet_compact_isReset       (edges_2_io_stageOutputs_executeGet_compact_isReset              ), //i
    .io_edgeInputs_1_executeGet2_state_weight         (edges_2_io_stageOutputs_executeGet2_state_weight[1:0]           ), //i
    .io_edgeInputs_1_executeGet2_compact_valid        (edges_2_io_stageOutputs_executeGet2_compact_valid               ), //i
    .io_edgeInputs_1_executeGet2_compact_isReset      (edges_2_io_stageOutputs_executeGet2_compact_isReset             ), //i
    .io_edgeInputs_1_executeGet3_state_weight         (edges_2_io_stageOutputs_executeGet3_state_weight[1:0]           ), //i
    .io_edgeInputs_1_executeGet3_isTight              (edges_2_io_stageOutputs_executeGet3_isTight                     ), //i
    .io_edgeInputs_1_executeGet3_compact_valid        (edges_2_io_stageOutputs_executeGet3_compact_valid               ), //i
    .io_edgeInputs_1_executeGet3_compact_isReset      (edges_2_io_stageOutputs_executeGet3_compact_isReset             ), //i
    .io_edgeInputs_1_updateGet_state_weight           (edges_2_io_stageOutputs_updateGet_state_weight[1:0]             ), //i
    .io_edgeInputs_1_updateGet_remaining              (edges_2_io_stageOutputs_updateGet_remaining[1:0]                ), //i
    .io_edgeInputs_1_updateGet_compact_valid          (edges_2_io_stageOutputs_updateGet_compact_valid                 ), //i
    .io_edgeInputs_1_updateGet_compact_isReset        (edges_2_io_stageOutputs_updateGet_compact_isReset               ), //i
    .io_edgeInputs_1_updateGet2_state_weight          (edges_2_io_stageOutputs_updateGet2_state_weight[1:0]            ), //i
    .io_edgeInputs_1_updateGet2_remaining             (edges_2_io_stageOutputs_updateGet2_remaining[1:0]               ), //i
    .io_edgeInputs_1_updateGet2_compact_valid         (edges_2_io_stageOutputs_updateGet2_compact_valid                ), //i
    .io_edgeInputs_1_updateGet2_compact_isReset       (edges_2_io_stageOutputs_updateGet2_compact_isReset              ), //i
    .io_edgeInputs_1_updateGet3_state_weight          (edges_2_io_stageOutputs_updateGet3_state_weight[1:0]            ), //i
    .io_edgeInputs_1_updateGet3_remaining             (edges_2_io_stageOutputs_updateGet3_remaining[1:0]               ), //i
    .io_edgeInputs_1_updateGet3_compact_valid         (edges_2_io_stageOutputs_updateGet3_compact_valid                ), //i
    .io_edgeInputs_1_updateGet3_compact_isReset       (edges_2_io_stageOutputs_updateGet3_compact_isReset              ), //i
    ._zz_io_peerSpeed_0                               (vertices_1_io_stageOutputs_executeGet3_state_speed[1:0]         ), //i
    ._zz_io_peerNode_0                                (vertices_1_io_stageOutputs_executeGet3_state_node[4:0]          ), //i
    ._zz_io_peerRoot_0                                (vertices_1_io_stageOutputs_executeGet3_state_root[4:0]          ), //i
    ._zz_io_peerSpeed_1                               (vertices_3_io_stageOutputs_executeGet3_state_speed[1:0]         ), //i
    ._zz_io_peerNode_1                                (vertices_3_io_stageOutputs_executeGet3_state_node[4:0]          ), //i
    ._zz_io_peerRoot_1                                (vertices_3_io_stageOutputs_executeGet3_state_root[4:0]          ), //i
    .io_maxGrowable_length                            (vertices_0_io_maxGrowable_length[1:0]                           ), //o
    .clk                                              (clk                                                             ), //i
    .reset                                            (reset                                                           )  //i
  );
  Vertex_1 vertices_1 (
    .io_message_valid                                 (broadcastMessage_valid                                          ), //i
    .io_message_instruction                           (broadcastMessage_instruction[11:0]                              ), //i
    .io_message_isReset                               (broadcastMessage_isReset                                        ), //i
    .io_stageOutputs_offloadGet_state_speed           (vertices_1_io_stageOutputs_offloadGet_state_speed[1:0]          ), //o
    .io_stageOutputs_offloadGet_state_node            (vertices_1_io_stageOutputs_offloadGet_state_node[4:0]           ), //o
    .io_stageOutputs_offloadGet_state_root            (vertices_1_io_stageOutputs_offloadGet_state_root[4:0]           ), //o
    .io_stageOutputs_offloadGet_state_isVirtual       (vertices_1_io_stageOutputs_offloadGet_state_isVirtual           ), //o
    .io_stageOutputs_offloadGet_state_isDefect        (vertices_1_io_stageOutputs_offloadGet_state_isDefect            ), //o
    .io_stageOutputs_offloadGet_state_grown           (vertices_1_io_stageOutputs_offloadGet_state_grown[1:0]          ), //o
    .io_stageOutputs_offloadGet_message_valid         (vertices_1_io_stageOutputs_offloadGet_message_valid             ), //o
    .io_stageOutputs_offloadGet_message_instruction   (vertices_1_io_stageOutputs_offloadGet_message_instruction[11:0] ), //o
    .io_stageOutputs_offloadGet_message_isReset       (vertices_1_io_stageOutputs_offloadGet_message_isReset           ), //o
    .io_stageOutputs_offloadGet2_state_speed          (vertices_1_io_stageOutputs_offloadGet2_state_speed[1:0]         ), //o
    .io_stageOutputs_offloadGet2_state_node           (vertices_1_io_stageOutputs_offloadGet2_state_node[4:0]          ), //o
    .io_stageOutputs_offloadGet2_state_root           (vertices_1_io_stageOutputs_offloadGet2_state_root[4:0]          ), //o
    .io_stageOutputs_offloadGet2_state_isVirtual      (vertices_1_io_stageOutputs_offloadGet2_state_isVirtual          ), //o
    .io_stageOutputs_offloadGet2_state_isDefect       (vertices_1_io_stageOutputs_offloadGet2_state_isDefect           ), //o
    .io_stageOutputs_offloadGet2_state_grown          (vertices_1_io_stageOutputs_offloadGet2_state_grown[1:0]         ), //o
    .io_stageOutputs_offloadGet2_message_valid        (vertices_1_io_stageOutputs_offloadGet2_message_valid            ), //o
    .io_stageOutputs_offloadGet2_message_instruction  (vertices_1_io_stageOutputs_offloadGet2_message_instruction[11:0]), //o
    .io_stageOutputs_offloadGet2_message_isReset      (vertices_1_io_stageOutputs_offloadGet2_message_isReset          ), //o
    .io_stageOutputs_offloadGet3_state_speed          (vertices_1_io_stageOutputs_offloadGet3_state_speed[1:0]         ), //o
    .io_stageOutputs_offloadGet3_state_node           (vertices_1_io_stageOutputs_offloadGet3_state_node[4:0]          ), //o
    .io_stageOutputs_offloadGet3_state_root           (vertices_1_io_stageOutputs_offloadGet3_state_root[4:0]          ), //o
    .io_stageOutputs_offloadGet3_state_isVirtual      (vertices_1_io_stageOutputs_offloadGet3_state_isVirtual          ), //o
    .io_stageOutputs_offloadGet3_state_isDefect       (vertices_1_io_stageOutputs_offloadGet3_state_isDefect           ), //o
    .io_stageOutputs_offloadGet3_state_grown          (vertices_1_io_stageOutputs_offloadGet3_state_grown[1:0]         ), //o
    .io_stageOutputs_offloadGet3_message_valid        (vertices_1_io_stageOutputs_offloadGet3_message_valid            ), //o
    .io_stageOutputs_offloadGet3_message_instruction  (vertices_1_io_stageOutputs_offloadGet3_message_instruction[11:0]), //o
    .io_stageOutputs_offloadGet3_message_isReset      (vertices_1_io_stageOutputs_offloadGet3_message_isReset          ), //o
    .io_stageOutputs_offloadGet3_isUniqueTight        (vertices_1_io_stageOutputs_offloadGet3_isUniqueTight            ), //o
    .io_stageOutputs_offloadGet3_isIsolated           (vertices_1_io_stageOutputs_offloadGet3_isIsolated               ), //o
    .io_stageOutputs_offloadGet4_state_speed          (vertices_1_io_stageOutputs_offloadGet4_state_speed[1:0]         ), //o
    .io_stageOutputs_offloadGet4_state_node           (vertices_1_io_stageOutputs_offloadGet4_state_node[4:0]          ), //o
    .io_stageOutputs_offloadGet4_state_root           (vertices_1_io_stageOutputs_offloadGet4_state_root[4:0]          ), //o
    .io_stageOutputs_offloadGet4_state_isVirtual      (vertices_1_io_stageOutputs_offloadGet4_state_isVirtual          ), //o
    .io_stageOutputs_offloadGet4_state_isDefect       (vertices_1_io_stageOutputs_offloadGet4_state_isDefect           ), //o
    .io_stageOutputs_offloadGet4_state_grown          (vertices_1_io_stageOutputs_offloadGet4_state_grown[1:0]         ), //o
    .io_stageOutputs_offloadGet4_message_valid        (vertices_1_io_stageOutputs_offloadGet4_message_valid            ), //o
    .io_stageOutputs_offloadGet4_message_instruction  (vertices_1_io_stageOutputs_offloadGet4_message_instruction[11:0]), //o
    .io_stageOutputs_offloadGet4_message_isReset      (vertices_1_io_stageOutputs_offloadGet4_message_isReset          ), //o
    .io_stageOutputs_executeGet_state_speed           (vertices_1_io_stageOutputs_executeGet_state_speed[1:0]          ), //o
    .io_stageOutputs_executeGet_state_node            (vertices_1_io_stageOutputs_executeGet_state_node[4:0]           ), //o
    .io_stageOutputs_executeGet_state_root            (vertices_1_io_stageOutputs_executeGet_state_root[4:0]           ), //o
    .io_stageOutputs_executeGet_state_isVirtual       (vertices_1_io_stageOutputs_executeGet_state_isVirtual           ), //o
    .io_stageOutputs_executeGet_state_isDefect        (vertices_1_io_stageOutputs_executeGet_state_isDefect            ), //o
    .io_stageOutputs_executeGet_state_grown           (vertices_1_io_stageOutputs_executeGet_state_grown[1:0]          ), //o
    .io_stageOutputs_executeGet_message_valid         (vertices_1_io_stageOutputs_executeGet_message_valid             ), //o
    .io_stageOutputs_executeGet_message_instruction   (vertices_1_io_stageOutputs_executeGet_message_instruction[11:0] ), //o
    .io_stageOutputs_executeGet_message_isReset       (vertices_1_io_stageOutputs_executeGet_message_isReset           ), //o
    .io_stageOutputs_executeGet_isStalled             (vertices_1_io_stageOutputs_executeGet_isStalled                 ), //o
    .io_stageOutputs_executeGet2_state_speed          (vertices_1_io_stageOutputs_executeGet2_state_speed[1:0]         ), //o
    .io_stageOutputs_executeGet2_state_node           (vertices_1_io_stageOutputs_executeGet2_state_node[4:0]          ), //o
    .io_stageOutputs_executeGet2_state_root           (vertices_1_io_stageOutputs_executeGet2_state_root[4:0]          ), //o
    .io_stageOutputs_executeGet2_state_isVirtual      (vertices_1_io_stageOutputs_executeGet2_state_isVirtual          ), //o
    .io_stageOutputs_executeGet2_state_isDefect       (vertices_1_io_stageOutputs_executeGet2_state_isDefect           ), //o
    .io_stageOutputs_executeGet2_state_grown          (vertices_1_io_stageOutputs_executeGet2_state_grown[1:0]         ), //o
    .io_stageOutputs_executeGet2_isStalled            (vertices_1_io_stageOutputs_executeGet2_isStalled                ), //o
    .io_stageOutputs_executeGet2_compact_valid        (vertices_1_io_stageOutputs_executeGet2_compact_valid            ), //o
    .io_stageOutputs_executeGet2_compact_isReset      (vertices_1_io_stageOutputs_executeGet2_compact_isReset          ), //o
    .io_stageOutputs_executeGet3_state_speed          (vertices_1_io_stageOutputs_executeGet3_state_speed[1:0]         ), //o
    .io_stageOutputs_executeGet3_state_node           (vertices_1_io_stageOutputs_executeGet3_state_node[4:0]          ), //o
    .io_stageOutputs_executeGet3_state_root           (vertices_1_io_stageOutputs_executeGet3_state_root[4:0]          ), //o
    .io_stageOutputs_executeGet3_state_isVirtual      (vertices_1_io_stageOutputs_executeGet3_state_isVirtual          ), //o
    .io_stageOutputs_executeGet3_state_isDefect       (vertices_1_io_stageOutputs_executeGet3_state_isDefect           ), //o
    .io_stageOutputs_executeGet3_state_grown          (vertices_1_io_stageOutputs_executeGet3_state_grown[1:0]         ), //o
    .io_stageOutputs_executeGet3_isStalled            (vertices_1_io_stageOutputs_executeGet3_isStalled                ), //o
    .io_stageOutputs_executeGet3_compact_valid        (vertices_1_io_stageOutputs_executeGet3_compact_valid            ), //o
    .io_stageOutputs_executeGet3_compact_isReset      (vertices_1_io_stageOutputs_executeGet3_compact_isReset          ), //o
    .io_stageOutputs_updateGet_state_speed            (vertices_1_io_stageOutputs_updateGet_state_speed[1:0]           ), //o
    .io_stageOutputs_updateGet_state_node             (vertices_1_io_stageOutputs_updateGet_state_node[4:0]            ), //o
    .io_stageOutputs_updateGet_state_root             (vertices_1_io_stageOutputs_updateGet_state_root[4:0]            ), //o
    .io_stageOutputs_updateGet_state_isVirtual        (vertices_1_io_stageOutputs_updateGet_state_isVirtual            ), //o
    .io_stageOutputs_updateGet_state_isDefect         (vertices_1_io_stageOutputs_updateGet_state_isDefect             ), //o
    .io_stageOutputs_updateGet_state_grown            (vertices_1_io_stageOutputs_updateGet_state_grown[1:0]           ), //o
    .io_stageOutputs_updateGet_isStalled              (vertices_1_io_stageOutputs_updateGet_isStalled                  ), //o
    .io_stageOutputs_updateGet_compact_valid          (vertices_1_io_stageOutputs_updateGet_compact_valid              ), //o
    .io_stageOutputs_updateGet_compact_isReset        (vertices_1_io_stageOutputs_updateGet_compact_isReset            ), //o
    .io_stageOutputs_updateGet_propagatingPeer_valid  (vertices_1_io_stageOutputs_updateGet_propagatingPeer_valid      ), //o
    .io_stageOutputs_updateGet_propagatingPeer_node   (vertices_1_io_stageOutputs_updateGet_propagatingPeer_node[4:0]  ), //o
    .io_stageOutputs_updateGet_propagatingPeer_root   (vertices_1_io_stageOutputs_updateGet_propagatingPeer_root[4:0]  ), //o
    .io_stageOutputs_updateGet2_state_speed           (vertices_1_io_stageOutputs_updateGet2_state_speed[1:0]          ), //o
    .io_stageOutputs_updateGet2_state_node            (vertices_1_io_stageOutputs_updateGet2_state_node[4:0]           ), //o
    .io_stageOutputs_updateGet2_state_root            (vertices_1_io_stageOutputs_updateGet2_state_root[4:0]           ), //o
    .io_stageOutputs_updateGet2_state_isVirtual       (vertices_1_io_stageOutputs_updateGet2_state_isVirtual           ), //o
    .io_stageOutputs_updateGet2_state_isDefect        (vertices_1_io_stageOutputs_updateGet2_state_isDefect            ), //o
    .io_stageOutputs_updateGet2_state_grown           (vertices_1_io_stageOutputs_updateGet2_state_grown[1:0]          ), //o
    .io_stageOutputs_updateGet2_isStalled             (vertices_1_io_stageOutputs_updateGet2_isStalled                 ), //o
    .io_stageOutputs_updateGet2_compact_valid         (vertices_1_io_stageOutputs_updateGet2_compact_valid             ), //o
    .io_stageOutputs_updateGet2_compact_isReset       (vertices_1_io_stageOutputs_updateGet2_compact_isReset           ), //o
    .io_stageOutputs_updateGet2_propagatingPeer_valid (vertices_1_io_stageOutputs_updateGet2_propagatingPeer_valid     ), //o
    .io_stageOutputs_updateGet2_propagatingPeer_node  (vertices_1_io_stageOutputs_updateGet2_propagatingPeer_node[4:0] ), //o
    .io_stageOutputs_updateGet2_propagatingPeer_root  (vertices_1_io_stageOutputs_updateGet2_propagatingPeer_root[4:0] ), //o
    .io_stageOutputs_updateGet3_state_speed           (vertices_1_io_stageOutputs_updateGet3_state_speed[1:0]          ), //o
    .io_stageOutputs_updateGet3_state_node            (vertices_1_io_stageOutputs_updateGet3_state_node[4:0]           ), //o
    .io_stageOutputs_updateGet3_state_root            (vertices_1_io_stageOutputs_updateGet3_state_root[4:0]           ), //o
    .io_stageOutputs_updateGet3_state_isVirtual       (vertices_1_io_stageOutputs_updateGet3_state_isVirtual           ), //o
    .io_stageOutputs_updateGet3_state_isDefect        (vertices_1_io_stageOutputs_updateGet3_state_isDefect            ), //o
    .io_stageOutputs_updateGet3_state_grown           (vertices_1_io_stageOutputs_updateGet3_state_grown[1:0]          ), //o
    .io_stageOutputs_updateGet3_shadow_speed          (vertices_1_io_stageOutputs_updateGet3_shadow_speed[1:0]         ), //o
    .io_stageOutputs_updateGet3_shadow_node           (vertices_1_io_stageOutputs_updateGet3_shadow_node[4:0]          ), //o
    .io_stageOutputs_updateGet3_shadow_root           (vertices_1_io_stageOutputs_updateGet3_shadow_root[4:0]          ), //o
    .io_stageOutputs_updateGet3_compact_valid         (vertices_1_io_stageOutputs_updateGet3_compact_valid             ), //o
    .io_stageOutputs_updateGet3_compact_isReset       (vertices_1_io_stageOutputs_updateGet3_compact_isReset           ), //o
    .io_edgeInputs_0_offloadGet_state_weight          (edges_0_io_stageOutputs_offloadGet_state_weight[1:0]            ), //i
    .io_edgeInputs_0_offloadGet_compact_valid         (edges_0_io_stageOutputs_offloadGet_compact_valid                ), //i
    .io_edgeInputs_0_offloadGet_compact_isReset       (edges_0_io_stageOutputs_offloadGet_compact_isReset              ), //i
    .io_edgeInputs_0_offloadGet2_state_weight         (edges_0_io_stageOutputs_offloadGet2_state_weight[1:0]           ), //i
    .io_edgeInputs_0_offloadGet2_isTight              (edges_0_io_stageOutputs_offloadGet2_isTight                     ), //i
    .io_edgeInputs_0_offloadGet2_isTightExFusion      (edges_0_io_stageOutputs_offloadGet2_isTightExFusion             ), //i
    .io_edgeInputs_0_offloadGet2_compact_valid        (edges_0_io_stageOutputs_offloadGet2_compact_valid               ), //i
    .io_edgeInputs_0_offloadGet2_compact_isReset      (edges_0_io_stageOutputs_offloadGet2_compact_isReset             ), //i
    .io_edgeInputs_0_offloadGet3_state_weight         (edges_0_io_stageOutputs_offloadGet3_state_weight[1:0]           ), //i
    .io_edgeInputs_0_offloadGet3_isTight              (edges_0_io_stageOutputs_offloadGet3_isTight                     ), //i
    .io_edgeInputs_0_offloadGet3_compact_valid        (edges_0_io_stageOutputs_offloadGet3_compact_valid               ), //i
    .io_edgeInputs_0_offloadGet3_compact_isReset      (edges_0_io_stageOutputs_offloadGet3_compact_isReset             ), //i
    .io_edgeInputs_0_offloadGet4_state_weight         (edges_0_io_stageOutputs_offloadGet4_state_weight[1:0]           ), //i
    .io_edgeInputs_0_offloadGet4_compact_valid        (edges_0_io_stageOutputs_offloadGet4_compact_valid               ), //i
    .io_edgeInputs_0_offloadGet4_compact_isReset      (edges_0_io_stageOutputs_offloadGet4_compact_isReset             ), //i
    .io_edgeInputs_0_executeGet_state_weight          (edges_0_io_stageOutputs_executeGet_state_weight[1:0]            ), //i
    .io_edgeInputs_0_executeGet_compact_valid         (edges_0_io_stageOutputs_executeGet_compact_valid                ), //i
    .io_edgeInputs_0_executeGet_compact_isReset       (edges_0_io_stageOutputs_executeGet_compact_isReset              ), //i
    .io_edgeInputs_0_executeGet2_state_weight         (edges_0_io_stageOutputs_executeGet2_state_weight[1:0]           ), //i
    .io_edgeInputs_0_executeGet2_compact_valid        (edges_0_io_stageOutputs_executeGet2_compact_valid               ), //i
    .io_edgeInputs_0_executeGet2_compact_isReset      (edges_0_io_stageOutputs_executeGet2_compact_isReset             ), //i
    .io_edgeInputs_0_executeGet3_state_weight         (edges_0_io_stageOutputs_executeGet3_state_weight[1:0]           ), //i
    .io_edgeInputs_0_executeGet3_isTight              (edges_0_io_stageOutputs_executeGet3_isTight                     ), //i
    .io_edgeInputs_0_executeGet3_compact_valid        (edges_0_io_stageOutputs_executeGet3_compact_valid               ), //i
    .io_edgeInputs_0_executeGet3_compact_isReset      (edges_0_io_stageOutputs_executeGet3_compact_isReset             ), //i
    .io_edgeInputs_0_updateGet_state_weight           (edges_0_io_stageOutputs_updateGet_state_weight[1:0]             ), //i
    .io_edgeInputs_0_updateGet_remaining              (edges_0_io_stageOutputs_updateGet_remaining[1:0]                ), //i
    .io_edgeInputs_0_updateGet_compact_valid          (edges_0_io_stageOutputs_updateGet_compact_valid                 ), //i
    .io_edgeInputs_0_updateGet_compact_isReset        (edges_0_io_stageOutputs_updateGet_compact_isReset               ), //i
    .io_edgeInputs_0_updateGet2_state_weight          (edges_0_io_stageOutputs_updateGet2_state_weight[1:0]            ), //i
    .io_edgeInputs_0_updateGet2_remaining             (edges_0_io_stageOutputs_updateGet2_remaining[1:0]               ), //i
    .io_edgeInputs_0_updateGet2_compact_valid         (edges_0_io_stageOutputs_updateGet2_compact_valid                ), //i
    .io_edgeInputs_0_updateGet2_compact_isReset       (edges_0_io_stageOutputs_updateGet2_compact_isReset              ), //i
    .io_edgeInputs_0_updateGet3_state_weight          (edges_0_io_stageOutputs_updateGet3_state_weight[1:0]            ), //i
    .io_edgeInputs_0_updateGet3_remaining             (edges_0_io_stageOutputs_updateGet3_remaining[1:0]               ), //i
    .io_edgeInputs_0_updateGet3_compact_valid         (edges_0_io_stageOutputs_updateGet3_compact_valid                ), //i
    .io_edgeInputs_0_updateGet3_compact_isReset       (edges_0_io_stageOutputs_updateGet3_compact_isReset              ), //i
    .io_edgeInputs_1_offloadGet_state_weight          (edges_1_io_stageOutputs_offloadGet_state_weight[1:0]            ), //i
    .io_edgeInputs_1_offloadGet_compact_valid         (edges_1_io_stageOutputs_offloadGet_compact_valid                ), //i
    .io_edgeInputs_1_offloadGet_compact_isReset       (edges_1_io_stageOutputs_offloadGet_compact_isReset              ), //i
    .io_edgeInputs_1_offloadGet2_state_weight         (edges_1_io_stageOutputs_offloadGet2_state_weight[1:0]           ), //i
    .io_edgeInputs_1_offloadGet2_isTight              (edges_1_io_stageOutputs_offloadGet2_isTight                     ), //i
    .io_edgeInputs_1_offloadGet2_isTightExFusion      (edges_1_io_stageOutputs_offloadGet2_isTightExFusion             ), //i
    .io_edgeInputs_1_offloadGet2_compact_valid        (edges_1_io_stageOutputs_offloadGet2_compact_valid               ), //i
    .io_edgeInputs_1_offloadGet2_compact_isReset      (edges_1_io_stageOutputs_offloadGet2_compact_isReset             ), //i
    .io_edgeInputs_1_offloadGet3_state_weight         (edges_1_io_stageOutputs_offloadGet3_state_weight[1:0]           ), //i
    .io_edgeInputs_1_offloadGet3_isTight              (edges_1_io_stageOutputs_offloadGet3_isTight                     ), //i
    .io_edgeInputs_1_offloadGet3_compact_valid        (edges_1_io_stageOutputs_offloadGet3_compact_valid               ), //i
    .io_edgeInputs_1_offloadGet3_compact_isReset      (edges_1_io_stageOutputs_offloadGet3_compact_isReset             ), //i
    .io_edgeInputs_1_offloadGet4_state_weight         (edges_1_io_stageOutputs_offloadGet4_state_weight[1:0]           ), //i
    .io_edgeInputs_1_offloadGet4_compact_valid        (edges_1_io_stageOutputs_offloadGet4_compact_valid               ), //i
    .io_edgeInputs_1_offloadGet4_compact_isReset      (edges_1_io_stageOutputs_offloadGet4_compact_isReset             ), //i
    .io_edgeInputs_1_executeGet_state_weight          (edges_1_io_stageOutputs_executeGet_state_weight[1:0]            ), //i
    .io_edgeInputs_1_executeGet_compact_valid         (edges_1_io_stageOutputs_executeGet_compact_valid                ), //i
    .io_edgeInputs_1_executeGet_compact_isReset       (edges_1_io_stageOutputs_executeGet_compact_isReset              ), //i
    .io_edgeInputs_1_executeGet2_state_weight         (edges_1_io_stageOutputs_executeGet2_state_weight[1:0]           ), //i
    .io_edgeInputs_1_executeGet2_compact_valid        (edges_1_io_stageOutputs_executeGet2_compact_valid               ), //i
    .io_edgeInputs_1_executeGet2_compact_isReset      (edges_1_io_stageOutputs_executeGet2_compact_isReset             ), //i
    .io_edgeInputs_1_executeGet3_state_weight         (edges_1_io_stageOutputs_executeGet3_state_weight[1:0]           ), //i
    .io_edgeInputs_1_executeGet3_isTight              (edges_1_io_stageOutputs_executeGet3_isTight                     ), //i
    .io_edgeInputs_1_executeGet3_compact_valid        (edges_1_io_stageOutputs_executeGet3_compact_valid               ), //i
    .io_edgeInputs_1_executeGet3_compact_isReset      (edges_1_io_stageOutputs_executeGet3_compact_isReset             ), //i
    .io_edgeInputs_1_updateGet_state_weight           (edges_1_io_stageOutputs_updateGet_state_weight[1:0]             ), //i
    .io_edgeInputs_1_updateGet_remaining              (edges_1_io_stageOutputs_updateGet_remaining[1:0]                ), //i
    .io_edgeInputs_1_updateGet_compact_valid          (edges_1_io_stageOutputs_updateGet_compact_valid                 ), //i
    .io_edgeInputs_1_updateGet_compact_isReset        (edges_1_io_stageOutputs_updateGet_compact_isReset               ), //i
    .io_edgeInputs_1_updateGet2_state_weight          (edges_1_io_stageOutputs_updateGet2_state_weight[1:0]            ), //i
    .io_edgeInputs_1_updateGet2_remaining             (edges_1_io_stageOutputs_updateGet2_remaining[1:0]               ), //i
    .io_edgeInputs_1_updateGet2_compact_valid         (edges_1_io_stageOutputs_updateGet2_compact_valid                ), //i
    .io_edgeInputs_1_updateGet2_compact_isReset       (edges_1_io_stageOutputs_updateGet2_compact_isReset              ), //i
    .io_edgeInputs_1_updateGet3_state_weight          (edges_1_io_stageOutputs_updateGet3_state_weight[1:0]            ), //i
    .io_edgeInputs_1_updateGet3_remaining             (edges_1_io_stageOutputs_updateGet3_remaining[1:0]               ), //i
    .io_edgeInputs_1_updateGet3_compact_valid         (edges_1_io_stageOutputs_updateGet3_compact_valid                ), //i
    .io_edgeInputs_1_updateGet3_compact_isReset       (edges_1_io_stageOutputs_updateGet3_compact_isReset              ), //i
    ._zz_io_peerSpeed_0                               (vertices_0_io_stageOutputs_executeGet3_state_speed[1:0]         ), //i
    ._zz_io_peerNode_0                                (vertices_0_io_stageOutputs_executeGet3_state_node[4:0]          ), //i
    ._zz_io_peerRoot_0                                (vertices_0_io_stageOutputs_executeGet3_state_root[4:0]          ), //i
    ._zz_io_peerSpeed_1                               (vertices_2_io_stageOutputs_executeGet3_state_speed[1:0]         ), //i
    ._zz_io_peerNode_1                                (vertices_2_io_stageOutputs_executeGet3_state_node[4:0]          ), //i
    ._zz_io_peerRoot_1                                (vertices_2_io_stageOutputs_executeGet3_state_root[4:0]          ), //i
    .io_maxGrowable_length                            (vertices_1_io_maxGrowable_length[1:0]                           ), //o
    .clk                                              (clk                                                             ), //i
    .reset                                            (reset                                                           )  //i
  );
  Vertex_2 vertices_2 (
    .io_message_valid                                 (broadcastMessage_valid                                          ), //i
    .io_message_instruction                           (broadcastMessage_instruction[11:0]                              ), //i
    .io_message_isReset                               (broadcastMessage_isReset                                        ), //i
    .io_stageOutputs_offloadGet_state_speed           (vertices_2_io_stageOutputs_offloadGet_state_speed[1:0]          ), //o
    .io_stageOutputs_offloadGet_state_node            (vertices_2_io_stageOutputs_offloadGet_state_node[4:0]           ), //o
    .io_stageOutputs_offloadGet_state_root            (vertices_2_io_stageOutputs_offloadGet_state_root[4:0]           ), //o
    .io_stageOutputs_offloadGet_state_isVirtual       (vertices_2_io_stageOutputs_offloadGet_state_isVirtual           ), //o
    .io_stageOutputs_offloadGet_state_isDefect        (vertices_2_io_stageOutputs_offloadGet_state_isDefect            ), //o
    .io_stageOutputs_offloadGet_state_grown           (vertices_2_io_stageOutputs_offloadGet_state_grown[1:0]          ), //o
    .io_stageOutputs_offloadGet_message_valid         (vertices_2_io_stageOutputs_offloadGet_message_valid             ), //o
    .io_stageOutputs_offloadGet_message_instruction   (vertices_2_io_stageOutputs_offloadGet_message_instruction[11:0] ), //o
    .io_stageOutputs_offloadGet_message_isReset       (vertices_2_io_stageOutputs_offloadGet_message_isReset           ), //o
    .io_stageOutputs_offloadGet2_state_speed          (vertices_2_io_stageOutputs_offloadGet2_state_speed[1:0]         ), //o
    .io_stageOutputs_offloadGet2_state_node           (vertices_2_io_stageOutputs_offloadGet2_state_node[4:0]          ), //o
    .io_stageOutputs_offloadGet2_state_root           (vertices_2_io_stageOutputs_offloadGet2_state_root[4:0]          ), //o
    .io_stageOutputs_offloadGet2_state_isVirtual      (vertices_2_io_stageOutputs_offloadGet2_state_isVirtual          ), //o
    .io_stageOutputs_offloadGet2_state_isDefect       (vertices_2_io_stageOutputs_offloadGet2_state_isDefect           ), //o
    .io_stageOutputs_offloadGet2_state_grown          (vertices_2_io_stageOutputs_offloadGet2_state_grown[1:0]         ), //o
    .io_stageOutputs_offloadGet2_message_valid        (vertices_2_io_stageOutputs_offloadGet2_message_valid            ), //o
    .io_stageOutputs_offloadGet2_message_instruction  (vertices_2_io_stageOutputs_offloadGet2_message_instruction[11:0]), //o
    .io_stageOutputs_offloadGet2_message_isReset      (vertices_2_io_stageOutputs_offloadGet2_message_isReset          ), //o
    .io_stageOutputs_offloadGet3_state_speed          (vertices_2_io_stageOutputs_offloadGet3_state_speed[1:0]         ), //o
    .io_stageOutputs_offloadGet3_state_node           (vertices_2_io_stageOutputs_offloadGet3_state_node[4:0]          ), //o
    .io_stageOutputs_offloadGet3_state_root           (vertices_2_io_stageOutputs_offloadGet3_state_root[4:0]          ), //o
    .io_stageOutputs_offloadGet3_state_isVirtual      (vertices_2_io_stageOutputs_offloadGet3_state_isVirtual          ), //o
    .io_stageOutputs_offloadGet3_state_isDefect       (vertices_2_io_stageOutputs_offloadGet3_state_isDefect           ), //o
    .io_stageOutputs_offloadGet3_state_grown          (vertices_2_io_stageOutputs_offloadGet3_state_grown[1:0]         ), //o
    .io_stageOutputs_offloadGet3_message_valid        (vertices_2_io_stageOutputs_offloadGet3_message_valid            ), //o
    .io_stageOutputs_offloadGet3_message_instruction  (vertices_2_io_stageOutputs_offloadGet3_message_instruction[11:0]), //o
    .io_stageOutputs_offloadGet3_message_isReset      (vertices_2_io_stageOutputs_offloadGet3_message_isReset          ), //o
    .io_stageOutputs_offloadGet3_isUniqueTight        (vertices_2_io_stageOutputs_offloadGet3_isUniqueTight            ), //o
    .io_stageOutputs_offloadGet3_isIsolated           (vertices_2_io_stageOutputs_offloadGet3_isIsolated               ), //o
    .io_stageOutputs_offloadGet4_state_speed          (vertices_2_io_stageOutputs_offloadGet4_state_speed[1:0]         ), //o
    .io_stageOutputs_offloadGet4_state_node           (vertices_2_io_stageOutputs_offloadGet4_state_node[4:0]          ), //o
    .io_stageOutputs_offloadGet4_state_root           (vertices_2_io_stageOutputs_offloadGet4_state_root[4:0]          ), //o
    .io_stageOutputs_offloadGet4_state_isVirtual      (vertices_2_io_stageOutputs_offloadGet4_state_isVirtual          ), //o
    .io_stageOutputs_offloadGet4_state_isDefect       (vertices_2_io_stageOutputs_offloadGet4_state_isDefect           ), //o
    .io_stageOutputs_offloadGet4_state_grown          (vertices_2_io_stageOutputs_offloadGet4_state_grown[1:0]         ), //o
    .io_stageOutputs_offloadGet4_message_valid        (vertices_2_io_stageOutputs_offloadGet4_message_valid            ), //o
    .io_stageOutputs_offloadGet4_message_instruction  (vertices_2_io_stageOutputs_offloadGet4_message_instruction[11:0]), //o
    .io_stageOutputs_offloadGet4_message_isReset      (vertices_2_io_stageOutputs_offloadGet4_message_isReset          ), //o
    .io_stageOutputs_executeGet_state_speed           (vertices_2_io_stageOutputs_executeGet_state_speed[1:0]          ), //o
    .io_stageOutputs_executeGet_state_node            (vertices_2_io_stageOutputs_executeGet_state_node[4:0]           ), //o
    .io_stageOutputs_executeGet_state_root            (vertices_2_io_stageOutputs_executeGet_state_root[4:0]           ), //o
    .io_stageOutputs_executeGet_state_isVirtual       (vertices_2_io_stageOutputs_executeGet_state_isVirtual           ), //o
    .io_stageOutputs_executeGet_state_isDefect        (vertices_2_io_stageOutputs_executeGet_state_isDefect            ), //o
    .io_stageOutputs_executeGet_state_grown           (vertices_2_io_stageOutputs_executeGet_state_grown[1:0]          ), //o
    .io_stageOutputs_executeGet_message_valid         (vertices_2_io_stageOutputs_executeGet_message_valid             ), //o
    .io_stageOutputs_executeGet_message_instruction   (vertices_2_io_stageOutputs_executeGet_message_instruction[11:0] ), //o
    .io_stageOutputs_executeGet_message_isReset       (vertices_2_io_stageOutputs_executeGet_message_isReset           ), //o
    .io_stageOutputs_executeGet_isStalled             (vertices_2_io_stageOutputs_executeGet_isStalled                 ), //o
    .io_stageOutputs_executeGet2_state_speed          (vertices_2_io_stageOutputs_executeGet2_state_speed[1:0]         ), //o
    .io_stageOutputs_executeGet2_state_node           (vertices_2_io_stageOutputs_executeGet2_state_node[4:0]          ), //o
    .io_stageOutputs_executeGet2_state_root           (vertices_2_io_stageOutputs_executeGet2_state_root[4:0]          ), //o
    .io_stageOutputs_executeGet2_state_isVirtual      (vertices_2_io_stageOutputs_executeGet2_state_isVirtual          ), //o
    .io_stageOutputs_executeGet2_state_isDefect       (vertices_2_io_stageOutputs_executeGet2_state_isDefect           ), //o
    .io_stageOutputs_executeGet2_state_grown          (vertices_2_io_stageOutputs_executeGet2_state_grown[1:0]         ), //o
    .io_stageOutputs_executeGet2_isStalled            (vertices_2_io_stageOutputs_executeGet2_isStalled                ), //o
    .io_stageOutputs_executeGet2_compact_valid        (vertices_2_io_stageOutputs_executeGet2_compact_valid            ), //o
    .io_stageOutputs_executeGet2_compact_isReset      (vertices_2_io_stageOutputs_executeGet2_compact_isReset          ), //o
    .io_stageOutputs_executeGet3_state_speed          (vertices_2_io_stageOutputs_executeGet3_state_speed[1:0]         ), //o
    .io_stageOutputs_executeGet3_state_node           (vertices_2_io_stageOutputs_executeGet3_state_node[4:0]          ), //o
    .io_stageOutputs_executeGet3_state_root           (vertices_2_io_stageOutputs_executeGet3_state_root[4:0]          ), //o
    .io_stageOutputs_executeGet3_state_isVirtual      (vertices_2_io_stageOutputs_executeGet3_state_isVirtual          ), //o
    .io_stageOutputs_executeGet3_state_isDefect       (vertices_2_io_stageOutputs_executeGet3_state_isDefect           ), //o
    .io_stageOutputs_executeGet3_state_grown          (vertices_2_io_stageOutputs_executeGet3_state_grown[1:0]         ), //o
    .io_stageOutputs_executeGet3_isStalled            (vertices_2_io_stageOutputs_executeGet3_isStalled                ), //o
    .io_stageOutputs_executeGet3_compact_valid        (vertices_2_io_stageOutputs_executeGet3_compact_valid            ), //o
    .io_stageOutputs_executeGet3_compact_isReset      (vertices_2_io_stageOutputs_executeGet3_compact_isReset          ), //o
    .io_stageOutputs_updateGet_state_speed            (vertices_2_io_stageOutputs_updateGet_state_speed[1:0]           ), //o
    .io_stageOutputs_updateGet_state_node             (vertices_2_io_stageOutputs_updateGet_state_node[4:0]            ), //o
    .io_stageOutputs_updateGet_state_root             (vertices_2_io_stageOutputs_updateGet_state_root[4:0]            ), //o
    .io_stageOutputs_updateGet_state_isVirtual        (vertices_2_io_stageOutputs_updateGet_state_isVirtual            ), //o
    .io_stageOutputs_updateGet_state_isDefect         (vertices_2_io_stageOutputs_updateGet_state_isDefect             ), //o
    .io_stageOutputs_updateGet_state_grown            (vertices_2_io_stageOutputs_updateGet_state_grown[1:0]           ), //o
    .io_stageOutputs_updateGet_isStalled              (vertices_2_io_stageOutputs_updateGet_isStalled                  ), //o
    .io_stageOutputs_updateGet_compact_valid          (vertices_2_io_stageOutputs_updateGet_compact_valid              ), //o
    .io_stageOutputs_updateGet_compact_isReset        (vertices_2_io_stageOutputs_updateGet_compact_isReset            ), //o
    .io_stageOutputs_updateGet_propagatingPeer_valid  (vertices_2_io_stageOutputs_updateGet_propagatingPeer_valid      ), //o
    .io_stageOutputs_updateGet_propagatingPeer_node   (vertices_2_io_stageOutputs_updateGet_propagatingPeer_node[4:0]  ), //o
    .io_stageOutputs_updateGet_propagatingPeer_root   (vertices_2_io_stageOutputs_updateGet_propagatingPeer_root[4:0]  ), //o
    .io_stageOutputs_updateGet2_state_speed           (vertices_2_io_stageOutputs_updateGet2_state_speed[1:0]          ), //o
    .io_stageOutputs_updateGet2_state_node            (vertices_2_io_stageOutputs_updateGet2_state_node[4:0]           ), //o
    .io_stageOutputs_updateGet2_state_root            (vertices_2_io_stageOutputs_updateGet2_state_root[4:0]           ), //o
    .io_stageOutputs_updateGet2_state_isVirtual       (vertices_2_io_stageOutputs_updateGet2_state_isVirtual           ), //o
    .io_stageOutputs_updateGet2_state_isDefect        (vertices_2_io_stageOutputs_updateGet2_state_isDefect            ), //o
    .io_stageOutputs_updateGet2_state_grown           (vertices_2_io_stageOutputs_updateGet2_state_grown[1:0]          ), //o
    .io_stageOutputs_updateGet2_isStalled             (vertices_2_io_stageOutputs_updateGet2_isStalled                 ), //o
    .io_stageOutputs_updateGet2_compact_valid         (vertices_2_io_stageOutputs_updateGet2_compact_valid             ), //o
    .io_stageOutputs_updateGet2_compact_isReset       (vertices_2_io_stageOutputs_updateGet2_compact_isReset           ), //o
    .io_stageOutputs_updateGet2_propagatingPeer_valid (vertices_2_io_stageOutputs_updateGet2_propagatingPeer_valid     ), //o
    .io_stageOutputs_updateGet2_propagatingPeer_node  (vertices_2_io_stageOutputs_updateGet2_propagatingPeer_node[4:0] ), //o
    .io_stageOutputs_updateGet2_propagatingPeer_root  (vertices_2_io_stageOutputs_updateGet2_propagatingPeer_root[4:0] ), //o
    .io_stageOutputs_updateGet3_state_speed           (vertices_2_io_stageOutputs_updateGet3_state_speed[1:0]          ), //o
    .io_stageOutputs_updateGet3_state_node            (vertices_2_io_stageOutputs_updateGet3_state_node[4:0]           ), //o
    .io_stageOutputs_updateGet3_state_root            (vertices_2_io_stageOutputs_updateGet3_state_root[4:0]           ), //o
    .io_stageOutputs_updateGet3_state_isVirtual       (vertices_2_io_stageOutputs_updateGet3_state_isVirtual           ), //o
    .io_stageOutputs_updateGet3_state_isDefect        (vertices_2_io_stageOutputs_updateGet3_state_isDefect            ), //o
    .io_stageOutputs_updateGet3_state_grown           (vertices_2_io_stageOutputs_updateGet3_state_grown[1:0]          ), //o
    .io_stageOutputs_updateGet3_shadow_speed          (vertices_2_io_stageOutputs_updateGet3_shadow_speed[1:0]         ), //o
    .io_stageOutputs_updateGet3_shadow_node           (vertices_2_io_stageOutputs_updateGet3_shadow_node[4:0]          ), //o
    .io_stageOutputs_updateGet3_shadow_root           (vertices_2_io_stageOutputs_updateGet3_shadow_root[4:0]          ), //o
    .io_stageOutputs_updateGet3_compact_valid         (vertices_2_io_stageOutputs_updateGet3_compact_valid             ), //o
    .io_stageOutputs_updateGet3_compact_isReset       (vertices_2_io_stageOutputs_updateGet3_compact_isReset           ), //o
    .io_edgeInputs_0_offloadGet_state_weight          (edges_1_io_stageOutputs_offloadGet_state_weight[1:0]            ), //i
    .io_edgeInputs_0_offloadGet_compact_valid         (edges_1_io_stageOutputs_offloadGet_compact_valid                ), //i
    .io_edgeInputs_0_offloadGet_compact_isReset       (edges_1_io_stageOutputs_offloadGet_compact_isReset              ), //i
    .io_edgeInputs_0_offloadGet2_state_weight         (edges_1_io_stageOutputs_offloadGet2_state_weight[1:0]           ), //i
    .io_edgeInputs_0_offloadGet2_isTight              (edges_1_io_stageOutputs_offloadGet2_isTight                     ), //i
    .io_edgeInputs_0_offloadGet2_isTightExFusion      (edges_1_io_stageOutputs_offloadGet2_isTightExFusion             ), //i
    .io_edgeInputs_0_offloadGet2_compact_valid        (edges_1_io_stageOutputs_offloadGet2_compact_valid               ), //i
    .io_edgeInputs_0_offloadGet2_compact_isReset      (edges_1_io_stageOutputs_offloadGet2_compact_isReset             ), //i
    .io_edgeInputs_0_offloadGet3_state_weight         (edges_1_io_stageOutputs_offloadGet3_state_weight[1:0]           ), //i
    .io_edgeInputs_0_offloadGet3_isTight              (edges_1_io_stageOutputs_offloadGet3_isTight                     ), //i
    .io_edgeInputs_0_offloadGet3_compact_valid        (edges_1_io_stageOutputs_offloadGet3_compact_valid               ), //i
    .io_edgeInputs_0_offloadGet3_compact_isReset      (edges_1_io_stageOutputs_offloadGet3_compact_isReset             ), //i
    .io_edgeInputs_0_offloadGet4_state_weight         (edges_1_io_stageOutputs_offloadGet4_state_weight[1:0]           ), //i
    .io_edgeInputs_0_offloadGet4_compact_valid        (edges_1_io_stageOutputs_offloadGet4_compact_valid               ), //i
    .io_edgeInputs_0_offloadGet4_compact_isReset      (edges_1_io_stageOutputs_offloadGet4_compact_isReset             ), //i
    .io_edgeInputs_0_executeGet_state_weight          (edges_1_io_stageOutputs_executeGet_state_weight[1:0]            ), //i
    .io_edgeInputs_0_executeGet_compact_valid         (edges_1_io_stageOutputs_executeGet_compact_valid                ), //i
    .io_edgeInputs_0_executeGet_compact_isReset       (edges_1_io_stageOutputs_executeGet_compact_isReset              ), //i
    .io_edgeInputs_0_executeGet2_state_weight         (edges_1_io_stageOutputs_executeGet2_state_weight[1:0]           ), //i
    .io_edgeInputs_0_executeGet2_compact_valid        (edges_1_io_stageOutputs_executeGet2_compact_valid               ), //i
    .io_edgeInputs_0_executeGet2_compact_isReset      (edges_1_io_stageOutputs_executeGet2_compact_isReset             ), //i
    .io_edgeInputs_0_executeGet3_state_weight         (edges_1_io_stageOutputs_executeGet3_state_weight[1:0]           ), //i
    .io_edgeInputs_0_executeGet3_isTight              (edges_1_io_stageOutputs_executeGet3_isTight                     ), //i
    .io_edgeInputs_0_executeGet3_compact_valid        (edges_1_io_stageOutputs_executeGet3_compact_valid               ), //i
    .io_edgeInputs_0_executeGet3_compact_isReset      (edges_1_io_stageOutputs_executeGet3_compact_isReset             ), //i
    .io_edgeInputs_0_updateGet_state_weight           (edges_1_io_stageOutputs_updateGet_state_weight[1:0]             ), //i
    .io_edgeInputs_0_updateGet_remaining              (edges_1_io_stageOutputs_updateGet_remaining[1:0]                ), //i
    .io_edgeInputs_0_updateGet_compact_valid          (edges_1_io_stageOutputs_updateGet_compact_valid                 ), //i
    .io_edgeInputs_0_updateGet_compact_isReset        (edges_1_io_stageOutputs_updateGet_compact_isReset               ), //i
    .io_edgeInputs_0_updateGet2_state_weight          (edges_1_io_stageOutputs_updateGet2_state_weight[1:0]            ), //i
    .io_edgeInputs_0_updateGet2_remaining             (edges_1_io_stageOutputs_updateGet2_remaining[1:0]               ), //i
    .io_edgeInputs_0_updateGet2_compact_valid         (edges_1_io_stageOutputs_updateGet2_compact_valid                ), //i
    .io_edgeInputs_0_updateGet2_compact_isReset       (edges_1_io_stageOutputs_updateGet2_compact_isReset              ), //i
    .io_edgeInputs_0_updateGet3_state_weight          (edges_1_io_stageOutputs_updateGet3_state_weight[1:0]            ), //i
    .io_edgeInputs_0_updateGet3_remaining             (edges_1_io_stageOutputs_updateGet3_remaining[1:0]               ), //i
    .io_edgeInputs_0_updateGet3_compact_valid         (edges_1_io_stageOutputs_updateGet3_compact_valid                ), //i
    .io_edgeInputs_0_updateGet3_compact_isReset       (edges_1_io_stageOutputs_updateGet3_compact_isReset              ), //i
    ._zz_io_peerSpeed_0                               (vertices_1_io_stageOutputs_executeGet3_state_speed[1:0]         ), //i
    ._zz_io_peerNode_0                                (vertices_1_io_stageOutputs_executeGet3_state_node[4:0]          ), //i
    ._zz_io_peerRoot_0                                (vertices_1_io_stageOutputs_executeGet3_state_root[4:0]          ), //i
    .io_maxGrowable_length                            (vertices_2_io_maxGrowable_length[1:0]                           ), //o
    .clk                                              (clk                                                             ), //i
    .reset                                            (reset                                                           )  //i
  );
  Vertex_3 vertices_3 (
    .io_message_valid                                 (broadcastMessage_valid                                          ), //i
    .io_message_instruction                           (broadcastMessage_instruction[11:0]                              ), //i
    .io_message_isReset                               (broadcastMessage_isReset                                        ), //i
    .io_stageOutputs_offloadGet_state_speed           (vertices_3_io_stageOutputs_offloadGet_state_speed[1:0]          ), //o
    .io_stageOutputs_offloadGet_state_node            (vertices_3_io_stageOutputs_offloadGet_state_node[4:0]           ), //o
    .io_stageOutputs_offloadGet_state_root            (vertices_3_io_stageOutputs_offloadGet_state_root[4:0]           ), //o
    .io_stageOutputs_offloadGet_state_isVirtual       (vertices_3_io_stageOutputs_offloadGet_state_isVirtual           ), //o
    .io_stageOutputs_offloadGet_state_isDefect        (vertices_3_io_stageOutputs_offloadGet_state_isDefect            ), //o
    .io_stageOutputs_offloadGet_state_grown           (vertices_3_io_stageOutputs_offloadGet_state_grown[1:0]          ), //o
    .io_stageOutputs_offloadGet_message_valid         (vertices_3_io_stageOutputs_offloadGet_message_valid             ), //o
    .io_stageOutputs_offloadGet_message_instruction   (vertices_3_io_stageOutputs_offloadGet_message_instruction[11:0] ), //o
    .io_stageOutputs_offloadGet_message_isReset       (vertices_3_io_stageOutputs_offloadGet_message_isReset           ), //o
    .io_stageOutputs_offloadGet2_state_speed          (vertices_3_io_stageOutputs_offloadGet2_state_speed[1:0]         ), //o
    .io_stageOutputs_offloadGet2_state_node           (vertices_3_io_stageOutputs_offloadGet2_state_node[4:0]          ), //o
    .io_stageOutputs_offloadGet2_state_root           (vertices_3_io_stageOutputs_offloadGet2_state_root[4:0]          ), //o
    .io_stageOutputs_offloadGet2_state_isVirtual      (vertices_3_io_stageOutputs_offloadGet2_state_isVirtual          ), //o
    .io_stageOutputs_offloadGet2_state_isDefect       (vertices_3_io_stageOutputs_offloadGet2_state_isDefect           ), //o
    .io_stageOutputs_offloadGet2_state_grown          (vertices_3_io_stageOutputs_offloadGet2_state_grown[1:0]         ), //o
    .io_stageOutputs_offloadGet2_message_valid        (vertices_3_io_stageOutputs_offloadGet2_message_valid            ), //o
    .io_stageOutputs_offloadGet2_message_instruction  (vertices_3_io_stageOutputs_offloadGet2_message_instruction[11:0]), //o
    .io_stageOutputs_offloadGet2_message_isReset      (vertices_3_io_stageOutputs_offloadGet2_message_isReset          ), //o
    .io_stageOutputs_offloadGet3_state_speed          (vertices_3_io_stageOutputs_offloadGet3_state_speed[1:0]         ), //o
    .io_stageOutputs_offloadGet3_state_node           (vertices_3_io_stageOutputs_offloadGet3_state_node[4:0]          ), //o
    .io_stageOutputs_offloadGet3_state_root           (vertices_3_io_stageOutputs_offloadGet3_state_root[4:0]          ), //o
    .io_stageOutputs_offloadGet3_state_isVirtual      (vertices_3_io_stageOutputs_offloadGet3_state_isVirtual          ), //o
    .io_stageOutputs_offloadGet3_state_isDefect       (vertices_3_io_stageOutputs_offloadGet3_state_isDefect           ), //o
    .io_stageOutputs_offloadGet3_state_grown          (vertices_3_io_stageOutputs_offloadGet3_state_grown[1:0]         ), //o
    .io_stageOutputs_offloadGet3_message_valid        (vertices_3_io_stageOutputs_offloadGet3_message_valid            ), //o
    .io_stageOutputs_offloadGet3_message_instruction  (vertices_3_io_stageOutputs_offloadGet3_message_instruction[11:0]), //o
    .io_stageOutputs_offloadGet3_message_isReset      (vertices_3_io_stageOutputs_offloadGet3_message_isReset          ), //o
    .io_stageOutputs_offloadGet3_isUniqueTight        (vertices_3_io_stageOutputs_offloadGet3_isUniqueTight            ), //o
    .io_stageOutputs_offloadGet3_isIsolated           (vertices_3_io_stageOutputs_offloadGet3_isIsolated               ), //o
    .io_stageOutputs_offloadGet4_state_speed          (vertices_3_io_stageOutputs_offloadGet4_state_speed[1:0]         ), //o
    .io_stageOutputs_offloadGet4_state_node           (vertices_3_io_stageOutputs_offloadGet4_state_node[4:0]          ), //o
    .io_stageOutputs_offloadGet4_state_root           (vertices_3_io_stageOutputs_offloadGet4_state_root[4:0]          ), //o
    .io_stageOutputs_offloadGet4_state_isVirtual      (vertices_3_io_stageOutputs_offloadGet4_state_isVirtual          ), //o
    .io_stageOutputs_offloadGet4_state_isDefect       (vertices_3_io_stageOutputs_offloadGet4_state_isDefect           ), //o
    .io_stageOutputs_offloadGet4_state_grown          (vertices_3_io_stageOutputs_offloadGet4_state_grown[1:0]         ), //o
    .io_stageOutputs_offloadGet4_message_valid        (vertices_3_io_stageOutputs_offloadGet4_message_valid            ), //o
    .io_stageOutputs_offloadGet4_message_instruction  (vertices_3_io_stageOutputs_offloadGet4_message_instruction[11:0]), //o
    .io_stageOutputs_offloadGet4_message_isReset      (vertices_3_io_stageOutputs_offloadGet4_message_isReset          ), //o
    .io_stageOutputs_executeGet_state_speed           (vertices_3_io_stageOutputs_executeGet_state_speed[1:0]          ), //o
    .io_stageOutputs_executeGet_state_node            (vertices_3_io_stageOutputs_executeGet_state_node[4:0]           ), //o
    .io_stageOutputs_executeGet_state_root            (vertices_3_io_stageOutputs_executeGet_state_root[4:0]           ), //o
    .io_stageOutputs_executeGet_state_isVirtual       (vertices_3_io_stageOutputs_executeGet_state_isVirtual           ), //o
    .io_stageOutputs_executeGet_state_isDefect        (vertices_3_io_stageOutputs_executeGet_state_isDefect            ), //o
    .io_stageOutputs_executeGet_state_grown           (vertices_3_io_stageOutputs_executeGet_state_grown[1:0]          ), //o
    .io_stageOutputs_executeGet_message_valid         (vertices_3_io_stageOutputs_executeGet_message_valid             ), //o
    .io_stageOutputs_executeGet_message_instruction   (vertices_3_io_stageOutputs_executeGet_message_instruction[11:0] ), //o
    .io_stageOutputs_executeGet_message_isReset       (vertices_3_io_stageOutputs_executeGet_message_isReset           ), //o
    .io_stageOutputs_executeGet_isStalled             (vertices_3_io_stageOutputs_executeGet_isStalled                 ), //o
    .io_stageOutputs_executeGet2_state_speed          (vertices_3_io_stageOutputs_executeGet2_state_speed[1:0]         ), //o
    .io_stageOutputs_executeGet2_state_node           (vertices_3_io_stageOutputs_executeGet2_state_node[4:0]          ), //o
    .io_stageOutputs_executeGet2_state_root           (vertices_3_io_stageOutputs_executeGet2_state_root[4:0]          ), //o
    .io_stageOutputs_executeGet2_state_isVirtual      (vertices_3_io_stageOutputs_executeGet2_state_isVirtual          ), //o
    .io_stageOutputs_executeGet2_state_isDefect       (vertices_3_io_stageOutputs_executeGet2_state_isDefect           ), //o
    .io_stageOutputs_executeGet2_state_grown          (vertices_3_io_stageOutputs_executeGet2_state_grown[1:0]         ), //o
    .io_stageOutputs_executeGet2_isStalled            (vertices_3_io_stageOutputs_executeGet2_isStalled                ), //o
    .io_stageOutputs_executeGet2_compact_valid        (vertices_3_io_stageOutputs_executeGet2_compact_valid            ), //o
    .io_stageOutputs_executeGet2_compact_isReset      (vertices_3_io_stageOutputs_executeGet2_compact_isReset          ), //o
    .io_stageOutputs_executeGet3_state_speed          (vertices_3_io_stageOutputs_executeGet3_state_speed[1:0]         ), //o
    .io_stageOutputs_executeGet3_state_node           (vertices_3_io_stageOutputs_executeGet3_state_node[4:0]          ), //o
    .io_stageOutputs_executeGet3_state_root           (vertices_3_io_stageOutputs_executeGet3_state_root[4:0]          ), //o
    .io_stageOutputs_executeGet3_state_isVirtual      (vertices_3_io_stageOutputs_executeGet3_state_isVirtual          ), //o
    .io_stageOutputs_executeGet3_state_isDefect       (vertices_3_io_stageOutputs_executeGet3_state_isDefect           ), //o
    .io_stageOutputs_executeGet3_state_grown          (vertices_3_io_stageOutputs_executeGet3_state_grown[1:0]         ), //o
    .io_stageOutputs_executeGet3_isStalled            (vertices_3_io_stageOutputs_executeGet3_isStalled                ), //o
    .io_stageOutputs_executeGet3_compact_valid        (vertices_3_io_stageOutputs_executeGet3_compact_valid            ), //o
    .io_stageOutputs_executeGet3_compact_isReset      (vertices_3_io_stageOutputs_executeGet3_compact_isReset          ), //o
    .io_stageOutputs_updateGet_state_speed            (vertices_3_io_stageOutputs_updateGet_state_speed[1:0]           ), //o
    .io_stageOutputs_updateGet_state_node             (vertices_3_io_stageOutputs_updateGet_state_node[4:0]            ), //o
    .io_stageOutputs_updateGet_state_root             (vertices_3_io_stageOutputs_updateGet_state_root[4:0]            ), //o
    .io_stageOutputs_updateGet_state_isVirtual        (vertices_3_io_stageOutputs_updateGet_state_isVirtual            ), //o
    .io_stageOutputs_updateGet_state_isDefect         (vertices_3_io_stageOutputs_updateGet_state_isDefect             ), //o
    .io_stageOutputs_updateGet_state_grown            (vertices_3_io_stageOutputs_updateGet_state_grown[1:0]           ), //o
    .io_stageOutputs_updateGet_isStalled              (vertices_3_io_stageOutputs_updateGet_isStalled                  ), //o
    .io_stageOutputs_updateGet_compact_valid          (vertices_3_io_stageOutputs_updateGet_compact_valid              ), //o
    .io_stageOutputs_updateGet_compact_isReset        (vertices_3_io_stageOutputs_updateGet_compact_isReset            ), //o
    .io_stageOutputs_updateGet_propagatingPeer_valid  (vertices_3_io_stageOutputs_updateGet_propagatingPeer_valid      ), //o
    .io_stageOutputs_updateGet_propagatingPeer_node   (vertices_3_io_stageOutputs_updateGet_propagatingPeer_node[4:0]  ), //o
    .io_stageOutputs_updateGet_propagatingPeer_root   (vertices_3_io_stageOutputs_updateGet_propagatingPeer_root[4:0]  ), //o
    .io_stageOutputs_updateGet2_state_speed           (vertices_3_io_stageOutputs_updateGet2_state_speed[1:0]          ), //o
    .io_stageOutputs_updateGet2_state_node            (vertices_3_io_stageOutputs_updateGet2_state_node[4:0]           ), //o
    .io_stageOutputs_updateGet2_state_root            (vertices_3_io_stageOutputs_updateGet2_state_root[4:0]           ), //o
    .io_stageOutputs_updateGet2_state_isVirtual       (vertices_3_io_stageOutputs_updateGet2_state_isVirtual           ), //o
    .io_stageOutputs_updateGet2_state_isDefect        (vertices_3_io_stageOutputs_updateGet2_state_isDefect            ), //o
    .io_stageOutputs_updateGet2_state_grown           (vertices_3_io_stageOutputs_updateGet2_state_grown[1:0]          ), //o
    .io_stageOutputs_updateGet2_isStalled             (vertices_3_io_stageOutputs_updateGet2_isStalled                 ), //o
    .io_stageOutputs_updateGet2_compact_valid         (vertices_3_io_stageOutputs_updateGet2_compact_valid             ), //o
    .io_stageOutputs_updateGet2_compact_isReset       (vertices_3_io_stageOutputs_updateGet2_compact_isReset           ), //o
    .io_stageOutputs_updateGet2_propagatingPeer_valid (vertices_3_io_stageOutputs_updateGet2_propagatingPeer_valid     ), //o
    .io_stageOutputs_updateGet2_propagatingPeer_node  (vertices_3_io_stageOutputs_updateGet2_propagatingPeer_node[4:0] ), //o
    .io_stageOutputs_updateGet2_propagatingPeer_root  (vertices_3_io_stageOutputs_updateGet2_propagatingPeer_root[4:0] ), //o
    .io_stageOutputs_updateGet3_state_speed           (vertices_3_io_stageOutputs_updateGet3_state_speed[1:0]          ), //o
    .io_stageOutputs_updateGet3_state_node            (vertices_3_io_stageOutputs_updateGet3_state_node[4:0]           ), //o
    .io_stageOutputs_updateGet3_state_root            (vertices_3_io_stageOutputs_updateGet3_state_root[4:0]           ), //o
    .io_stageOutputs_updateGet3_state_isVirtual       (vertices_3_io_stageOutputs_updateGet3_state_isVirtual           ), //o
    .io_stageOutputs_updateGet3_state_isDefect        (vertices_3_io_stageOutputs_updateGet3_state_isDefect            ), //o
    .io_stageOutputs_updateGet3_state_grown           (vertices_3_io_stageOutputs_updateGet3_state_grown[1:0]          ), //o
    .io_stageOutputs_updateGet3_shadow_speed          (vertices_3_io_stageOutputs_updateGet3_shadow_speed[1:0]         ), //o
    .io_stageOutputs_updateGet3_shadow_node           (vertices_3_io_stageOutputs_updateGet3_shadow_node[4:0]          ), //o
    .io_stageOutputs_updateGet3_shadow_root           (vertices_3_io_stageOutputs_updateGet3_shadow_root[4:0]          ), //o
    .io_stageOutputs_updateGet3_compact_valid         (vertices_3_io_stageOutputs_updateGet3_compact_valid             ), //o
    .io_stageOutputs_updateGet3_compact_isReset       (vertices_3_io_stageOutputs_updateGet3_compact_isReset           ), //o
    .io_edgeInputs_0_offloadGet_state_weight          (edges_2_io_stageOutputs_offloadGet_state_weight[1:0]            ), //i
    .io_edgeInputs_0_offloadGet_compact_valid         (edges_2_io_stageOutputs_offloadGet_compact_valid                ), //i
    .io_edgeInputs_0_offloadGet_compact_isReset       (edges_2_io_stageOutputs_offloadGet_compact_isReset              ), //i
    .io_edgeInputs_0_offloadGet2_state_weight         (edges_2_io_stageOutputs_offloadGet2_state_weight[1:0]           ), //i
    .io_edgeInputs_0_offloadGet2_isTight              (edges_2_io_stageOutputs_offloadGet2_isTight                     ), //i
    .io_edgeInputs_0_offloadGet2_isTightExFusion      (edges_2_io_stageOutputs_offloadGet2_isTightExFusion             ), //i
    .io_edgeInputs_0_offloadGet2_compact_valid        (edges_2_io_stageOutputs_offloadGet2_compact_valid               ), //i
    .io_edgeInputs_0_offloadGet2_compact_isReset      (edges_2_io_stageOutputs_offloadGet2_compact_isReset             ), //i
    .io_edgeInputs_0_offloadGet3_state_weight         (edges_2_io_stageOutputs_offloadGet3_state_weight[1:0]           ), //i
    .io_edgeInputs_0_offloadGet3_isTight              (edges_2_io_stageOutputs_offloadGet3_isTight                     ), //i
    .io_edgeInputs_0_offloadGet3_compact_valid        (edges_2_io_stageOutputs_offloadGet3_compact_valid               ), //i
    .io_edgeInputs_0_offloadGet3_compact_isReset      (edges_2_io_stageOutputs_offloadGet3_compact_isReset             ), //i
    .io_edgeInputs_0_offloadGet4_state_weight         (edges_2_io_stageOutputs_offloadGet4_state_weight[1:0]           ), //i
    .io_edgeInputs_0_offloadGet4_compact_valid        (edges_2_io_stageOutputs_offloadGet4_compact_valid               ), //i
    .io_edgeInputs_0_offloadGet4_compact_isReset      (edges_2_io_stageOutputs_offloadGet4_compact_isReset             ), //i
    .io_edgeInputs_0_executeGet_state_weight          (edges_2_io_stageOutputs_executeGet_state_weight[1:0]            ), //i
    .io_edgeInputs_0_executeGet_compact_valid         (edges_2_io_stageOutputs_executeGet_compact_valid                ), //i
    .io_edgeInputs_0_executeGet_compact_isReset       (edges_2_io_stageOutputs_executeGet_compact_isReset              ), //i
    .io_edgeInputs_0_executeGet2_state_weight         (edges_2_io_stageOutputs_executeGet2_state_weight[1:0]           ), //i
    .io_edgeInputs_0_executeGet2_compact_valid        (edges_2_io_stageOutputs_executeGet2_compact_valid               ), //i
    .io_edgeInputs_0_executeGet2_compact_isReset      (edges_2_io_stageOutputs_executeGet2_compact_isReset             ), //i
    .io_edgeInputs_0_executeGet3_state_weight         (edges_2_io_stageOutputs_executeGet3_state_weight[1:0]           ), //i
    .io_edgeInputs_0_executeGet3_isTight              (edges_2_io_stageOutputs_executeGet3_isTight                     ), //i
    .io_edgeInputs_0_executeGet3_compact_valid        (edges_2_io_stageOutputs_executeGet3_compact_valid               ), //i
    .io_edgeInputs_0_executeGet3_compact_isReset      (edges_2_io_stageOutputs_executeGet3_compact_isReset             ), //i
    .io_edgeInputs_0_updateGet_state_weight           (edges_2_io_stageOutputs_updateGet_state_weight[1:0]             ), //i
    .io_edgeInputs_0_updateGet_remaining              (edges_2_io_stageOutputs_updateGet_remaining[1:0]                ), //i
    .io_edgeInputs_0_updateGet_compact_valid          (edges_2_io_stageOutputs_updateGet_compact_valid                 ), //i
    .io_edgeInputs_0_updateGet_compact_isReset        (edges_2_io_stageOutputs_updateGet_compact_isReset               ), //i
    .io_edgeInputs_0_updateGet2_state_weight          (edges_2_io_stageOutputs_updateGet2_state_weight[1:0]            ), //i
    .io_edgeInputs_0_updateGet2_remaining             (edges_2_io_stageOutputs_updateGet2_remaining[1:0]               ), //i
    .io_edgeInputs_0_updateGet2_compact_valid         (edges_2_io_stageOutputs_updateGet2_compact_valid                ), //i
    .io_edgeInputs_0_updateGet2_compact_isReset       (edges_2_io_stageOutputs_updateGet2_compact_isReset              ), //i
    .io_edgeInputs_0_updateGet3_state_weight          (edges_2_io_stageOutputs_updateGet3_state_weight[1:0]            ), //i
    .io_edgeInputs_0_updateGet3_remaining             (edges_2_io_stageOutputs_updateGet3_remaining[1:0]               ), //i
    .io_edgeInputs_0_updateGet3_compact_valid         (edges_2_io_stageOutputs_updateGet3_compact_valid                ), //i
    .io_edgeInputs_0_updateGet3_compact_isReset       (edges_2_io_stageOutputs_updateGet3_compact_isReset              ), //i
    ._zz_io_peerSpeed_0                               (vertices_0_io_stageOutputs_executeGet3_state_speed[1:0]         ), //i
    ._zz_io_peerNode_0                                (vertices_0_io_stageOutputs_executeGet3_state_node[4:0]          ), //i
    ._zz_io_peerRoot_0                                (vertices_0_io_stageOutputs_executeGet3_state_root[4:0]          ), //i
    .io_maxGrowable_length                            (vertices_3_io_maxGrowable_length[1:0]                           ), //o
    .clk                                              (clk                                                             ), //i
    .reset                                            (reset                                                           )  //i
  );
  Edge_1 edges_0 (
    .io_message_valid                                     (broadcastMessage_valid                                          ), //i
    .io_message_instruction                               (broadcastMessage_instruction[11:0]                              ), //i
    .io_message_isReset                                   (broadcastMessage_isReset                                        ), //i
    .io_stageOutputs_offloadGet_state_weight              (edges_0_io_stageOutputs_offloadGet_state_weight[1:0]            ), //o
    .io_stageOutputs_offloadGet_compact_valid             (edges_0_io_stageOutputs_offloadGet_compact_valid                ), //o
    .io_stageOutputs_offloadGet_compact_isReset           (edges_0_io_stageOutputs_offloadGet_compact_isReset              ), //o
    .io_stageOutputs_offloadGet2_state_weight             (edges_0_io_stageOutputs_offloadGet2_state_weight[1:0]           ), //o
    .io_stageOutputs_offloadGet2_isTight                  (edges_0_io_stageOutputs_offloadGet2_isTight                     ), //o
    .io_stageOutputs_offloadGet2_isTightExFusion          (edges_0_io_stageOutputs_offloadGet2_isTightExFusion             ), //o
    .io_stageOutputs_offloadGet2_compact_valid            (edges_0_io_stageOutputs_offloadGet2_compact_valid               ), //o
    .io_stageOutputs_offloadGet2_compact_isReset          (edges_0_io_stageOutputs_offloadGet2_compact_isReset             ), //o
    .io_stageOutputs_offloadGet3_state_weight             (edges_0_io_stageOutputs_offloadGet3_state_weight[1:0]           ), //o
    .io_stageOutputs_offloadGet3_isTight                  (edges_0_io_stageOutputs_offloadGet3_isTight                     ), //o
    .io_stageOutputs_offloadGet3_compact_valid            (edges_0_io_stageOutputs_offloadGet3_compact_valid               ), //o
    .io_stageOutputs_offloadGet3_compact_isReset          (edges_0_io_stageOutputs_offloadGet3_compact_isReset             ), //o
    .io_stageOutputs_offloadGet4_state_weight             (edges_0_io_stageOutputs_offloadGet4_state_weight[1:0]           ), //o
    .io_stageOutputs_offloadGet4_compact_valid            (edges_0_io_stageOutputs_offloadGet4_compact_valid               ), //o
    .io_stageOutputs_offloadGet4_compact_isReset          (edges_0_io_stageOutputs_offloadGet4_compact_isReset             ), //o
    .io_stageOutputs_executeGet_state_weight              (edges_0_io_stageOutputs_executeGet_state_weight[1:0]            ), //o
    .io_stageOutputs_executeGet_compact_valid             (edges_0_io_stageOutputs_executeGet_compact_valid                ), //o
    .io_stageOutputs_executeGet_compact_isReset           (edges_0_io_stageOutputs_executeGet_compact_isReset              ), //o
    .io_stageOutputs_executeGet2_state_weight             (edges_0_io_stageOutputs_executeGet2_state_weight[1:0]           ), //o
    .io_stageOutputs_executeGet2_compact_valid            (edges_0_io_stageOutputs_executeGet2_compact_valid               ), //o
    .io_stageOutputs_executeGet2_compact_isReset          (edges_0_io_stageOutputs_executeGet2_compact_isReset             ), //o
    .io_stageOutputs_executeGet3_state_weight             (edges_0_io_stageOutputs_executeGet3_state_weight[1:0]           ), //o
    .io_stageOutputs_executeGet3_isTight                  (edges_0_io_stageOutputs_executeGet3_isTight                     ), //o
    .io_stageOutputs_executeGet3_compact_valid            (edges_0_io_stageOutputs_executeGet3_compact_valid               ), //o
    .io_stageOutputs_executeGet3_compact_isReset          (edges_0_io_stageOutputs_executeGet3_compact_isReset             ), //o
    .io_stageOutputs_updateGet_state_weight               (edges_0_io_stageOutputs_updateGet_state_weight[1:0]             ), //o
    .io_stageOutputs_updateGet_remaining                  (edges_0_io_stageOutputs_updateGet_remaining[1:0]                ), //o
    .io_stageOutputs_updateGet_compact_valid              (edges_0_io_stageOutputs_updateGet_compact_valid                 ), //o
    .io_stageOutputs_updateGet_compact_isReset            (edges_0_io_stageOutputs_updateGet_compact_isReset               ), //o
    .io_stageOutputs_updateGet2_state_weight              (edges_0_io_stageOutputs_updateGet2_state_weight[1:0]            ), //o
    .io_stageOutputs_updateGet2_remaining                 (edges_0_io_stageOutputs_updateGet2_remaining[1:0]               ), //o
    .io_stageOutputs_updateGet2_compact_valid             (edges_0_io_stageOutputs_updateGet2_compact_valid                ), //o
    .io_stageOutputs_updateGet2_compact_isReset           (edges_0_io_stageOutputs_updateGet2_compact_isReset              ), //o
    .io_stageOutputs_updateGet3_state_weight              (edges_0_io_stageOutputs_updateGet3_state_weight[1:0]            ), //o
    .io_stageOutputs_updateGet3_remaining                 (edges_0_io_stageOutputs_updateGet3_remaining[1:0]               ), //o
    .io_stageOutputs_updateGet3_compact_valid             (edges_0_io_stageOutputs_updateGet3_compact_valid                ), //o
    .io_stageOutputs_updateGet3_compact_isReset           (edges_0_io_stageOutputs_updateGet3_compact_isReset              ), //o
    .io_leftVertexInput_offloadGet_state_speed            (vertices_0_io_stageOutputs_offloadGet_state_speed[1:0]          ), //i
    .io_leftVertexInput_offloadGet_state_node             (vertices_0_io_stageOutputs_offloadGet_state_node[4:0]           ), //i
    .io_leftVertexInput_offloadGet_state_root             (vertices_0_io_stageOutputs_offloadGet_state_root[4:0]           ), //i
    .io_leftVertexInput_offloadGet_state_isVirtual        (vertices_0_io_stageOutputs_offloadGet_state_isVirtual           ), //i
    .io_leftVertexInput_offloadGet_state_isDefect         (vertices_0_io_stageOutputs_offloadGet_state_isDefect            ), //i
    .io_leftVertexInput_offloadGet_state_grown            (vertices_0_io_stageOutputs_offloadGet_state_grown[1:0]          ), //i
    .io_leftVertexInput_offloadGet_message_valid          (vertices_0_io_stageOutputs_offloadGet_message_valid             ), //i
    .io_leftVertexInput_offloadGet_message_instruction    (vertices_0_io_stageOutputs_offloadGet_message_instruction[11:0] ), //i
    .io_leftVertexInput_offloadGet_message_isReset        (vertices_0_io_stageOutputs_offloadGet_message_isReset           ), //i
    .io_leftVertexInput_offloadGet2_state_speed           (vertices_0_io_stageOutputs_offloadGet2_state_speed[1:0]         ), //i
    .io_leftVertexInput_offloadGet2_state_node            (vertices_0_io_stageOutputs_offloadGet2_state_node[4:0]          ), //i
    .io_leftVertexInput_offloadGet2_state_root            (vertices_0_io_stageOutputs_offloadGet2_state_root[4:0]          ), //i
    .io_leftVertexInput_offloadGet2_state_isVirtual       (vertices_0_io_stageOutputs_offloadGet2_state_isVirtual          ), //i
    .io_leftVertexInput_offloadGet2_state_isDefect        (vertices_0_io_stageOutputs_offloadGet2_state_isDefect           ), //i
    .io_leftVertexInput_offloadGet2_state_grown           (vertices_0_io_stageOutputs_offloadGet2_state_grown[1:0]         ), //i
    .io_leftVertexInput_offloadGet2_message_valid         (vertices_0_io_stageOutputs_offloadGet2_message_valid            ), //i
    .io_leftVertexInput_offloadGet2_message_instruction   (vertices_0_io_stageOutputs_offloadGet2_message_instruction[11:0]), //i
    .io_leftVertexInput_offloadGet2_message_isReset       (vertices_0_io_stageOutputs_offloadGet2_message_isReset          ), //i
    .io_leftVertexInput_offloadGet3_state_speed           (vertices_0_io_stageOutputs_offloadGet3_state_speed[1:0]         ), //i
    .io_leftVertexInput_offloadGet3_state_node            (vertices_0_io_stageOutputs_offloadGet3_state_node[4:0]          ), //i
    .io_leftVertexInput_offloadGet3_state_root            (vertices_0_io_stageOutputs_offloadGet3_state_root[4:0]          ), //i
    .io_leftVertexInput_offloadGet3_state_isVirtual       (vertices_0_io_stageOutputs_offloadGet3_state_isVirtual          ), //i
    .io_leftVertexInput_offloadGet3_state_isDefect        (vertices_0_io_stageOutputs_offloadGet3_state_isDefect           ), //i
    .io_leftVertexInput_offloadGet3_state_grown           (vertices_0_io_stageOutputs_offloadGet3_state_grown[1:0]         ), //i
    .io_leftVertexInput_offloadGet3_message_valid         (vertices_0_io_stageOutputs_offloadGet3_message_valid            ), //i
    .io_leftVertexInput_offloadGet3_message_instruction   (vertices_0_io_stageOutputs_offloadGet3_message_instruction[11:0]), //i
    .io_leftVertexInput_offloadGet3_message_isReset       (vertices_0_io_stageOutputs_offloadGet3_message_isReset          ), //i
    .io_leftVertexInput_offloadGet3_isUniqueTight         (vertices_0_io_stageOutputs_offloadGet3_isUniqueTight            ), //i
    .io_leftVertexInput_offloadGet3_isIsolated            (vertices_0_io_stageOutputs_offloadGet3_isIsolated               ), //i
    .io_leftVertexInput_offloadGet4_state_speed           (vertices_0_io_stageOutputs_offloadGet4_state_speed[1:0]         ), //i
    .io_leftVertexInput_offloadGet4_state_node            (vertices_0_io_stageOutputs_offloadGet4_state_node[4:0]          ), //i
    .io_leftVertexInput_offloadGet4_state_root            (vertices_0_io_stageOutputs_offloadGet4_state_root[4:0]          ), //i
    .io_leftVertexInput_offloadGet4_state_isVirtual       (vertices_0_io_stageOutputs_offloadGet4_state_isVirtual          ), //i
    .io_leftVertexInput_offloadGet4_state_isDefect        (vertices_0_io_stageOutputs_offloadGet4_state_isDefect           ), //i
    .io_leftVertexInput_offloadGet4_state_grown           (vertices_0_io_stageOutputs_offloadGet4_state_grown[1:0]         ), //i
    .io_leftVertexInput_offloadGet4_message_valid         (vertices_0_io_stageOutputs_offloadGet4_message_valid            ), //i
    .io_leftVertexInput_offloadGet4_message_instruction   (vertices_0_io_stageOutputs_offloadGet4_message_instruction[11:0]), //i
    .io_leftVertexInput_offloadGet4_message_isReset       (vertices_0_io_stageOutputs_offloadGet4_message_isReset          ), //i
    .io_leftVertexInput_executeGet_state_speed            (vertices_0_io_stageOutputs_executeGet_state_speed[1:0]          ), //i
    .io_leftVertexInput_executeGet_state_node             (vertices_0_io_stageOutputs_executeGet_state_node[4:0]           ), //i
    .io_leftVertexInput_executeGet_state_root             (vertices_0_io_stageOutputs_executeGet_state_root[4:0]           ), //i
    .io_leftVertexInput_executeGet_state_isVirtual        (vertices_0_io_stageOutputs_executeGet_state_isVirtual           ), //i
    .io_leftVertexInput_executeGet_state_isDefect         (vertices_0_io_stageOutputs_executeGet_state_isDefect            ), //i
    .io_leftVertexInput_executeGet_state_grown            (vertices_0_io_stageOutputs_executeGet_state_grown[1:0]          ), //i
    .io_leftVertexInput_executeGet_message_valid          (vertices_0_io_stageOutputs_executeGet_message_valid             ), //i
    .io_leftVertexInput_executeGet_message_instruction    (vertices_0_io_stageOutputs_executeGet_message_instruction[11:0] ), //i
    .io_leftVertexInput_executeGet_message_isReset        (vertices_0_io_stageOutputs_executeGet_message_isReset           ), //i
    .io_leftVertexInput_executeGet_isStalled              (vertices_0_io_stageOutputs_executeGet_isStalled                 ), //i
    .io_leftVertexInput_executeGet2_state_speed           (vertices_0_io_stageOutputs_executeGet2_state_speed[1:0]         ), //i
    .io_leftVertexInput_executeGet2_state_node            (vertices_0_io_stageOutputs_executeGet2_state_node[4:0]          ), //i
    .io_leftVertexInput_executeGet2_state_root            (vertices_0_io_stageOutputs_executeGet2_state_root[4:0]          ), //i
    .io_leftVertexInput_executeGet2_state_isVirtual       (vertices_0_io_stageOutputs_executeGet2_state_isVirtual          ), //i
    .io_leftVertexInput_executeGet2_state_isDefect        (vertices_0_io_stageOutputs_executeGet2_state_isDefect           ), //i
    .io_leftVertexInput_executeGet2_state_grown           (vertices_0_io_stageOutputs_executeGet2_state_grown[1:0]         ), //i
    .io_leftVertexInput_executeGet2_isStalled             (vertices_0_io_stageOutputs_executeGet2_isStalled                ), //i
    .io_leftVertexInput_executeGet2_compact_valid         (vertices_0_io_stageOutputs_executeGet2_compact_valid            ), //i
    .io_leftVertexInput_executeGet2_compact_isReset       (vertices_0_io_stageOutputs_executeGet2_compact_isReset          ), //i
    .io_leftVertexInput_executeGet3_state_speed           (vertices_0_io_stageOutputs_executeGet3_state_speed[1:0]         ), //i
    .io_leftVertexInput_executeGet3_state_node            (vertices_0_io_stageOutputs_executeGet3_state_node[4:0]          ), //i
    .io_leftVertexInput_executeGet3_state_root            (vertices_0_io_stageOutputs_executeGet3_state_root[4:0]          ), //i
    .io_leftVertexInput_executeGet3_state_isVirtual       (vertices_0_io_stageOutputs_executeGet3_state_isVirtual          ), //i
    .io_leftVertexInput_executeGet3_state_isDefect        (vertices_0_io_stageOutputs_executeGet3_state_isDefect           ), //i
    .io_leftVertexInput_executeGet3_state_grown           (vertices_0_io_stageOutputs_executeGet3_state_grown[1:0]         ), //i
    .io_leftVertexInput_executeGet3_isStalled             (vertices_0_io_stageOutputs_executeGet3_isStalled                ), //i
    .io_leftVertexInput_executeGet3_compact_valid         (vertices_0_io_stageOutputs_executeGet3_compact_valid            ), //i
    .io_leftVertexInput_executeGet3_compact_isReset       (vertices_0_io_stageOutputs_executeGet3_compact_isReset          ), //i
    .io_leftVertexInput_updateGet_state_speed             (vertices_0_io_stageOutputs_updateGet_state_speed[1:0]           ), //i
    .io_leftVertexInput_updateGet_state_node              (vertices_0_io_stageOutputs_updateGet_state_node[4:0]            ), //i
    .io_leftVertexInput_updateGet_state_root              (vertices_0_io_stageOutputs_updateGet_state_root[4:0]            ), //i
    .io_leftVertexInput_updateGet_state_isVirtual         (vertices_0_io_stageOutputs_updateGet_state_isVirtual            ), //i
    .io_leftVertexInput_updateGet_state_isDefect          (vertices_0_io_stageOutputs_updateGet_state_isDefect             ), //i
    .io_leftVertexInput_updateGet_state_grown             (vertices_0_io_stageOutputs_updateGet_state_grown[1:0]           ), //i
    .io_leftVertexInput_updateGet_isStalled               (vertices_0_io_stageOutputs_updateGet_isStalled                  ), //i
    .io_leftVertexInput_updateGet_compact_valid           (vertices_0_io_stageOutputs_updateGet_compact_valid              ), //i
    .io_leftVertexInput_updateGet_compact_isReset         (vertices_0_io_stageOutputs_updateGet_compact_isReset            ), //i
    .io_leftVertexInput_updateGet_propagatingPeer_valid   (vertices_0_io_stageOutputs_updateGet_propagatingPeer_valid      ), //i
    .io_leftVertexInput_updateGet_propagatingPeer_node    (vertices_0_io_stageOutputs_updateGet_propagatingPeer_node[4:0]  ), //i
    .io_leftVertexInput_updateGet_propagatingPeer_root    (vertices_0_io_stageOutputs_updateGet_propagatingPeer_root[4:0]  ), //i
    .io_leftVertexInput_updateGet2_state_speed            (vertices_0_io_stageOutputs_updateGet2_state_speed[1:0]          ), //i
    .io_leftVertexInput_updateGet2_state_node             (vertices_0_io_stageOutputs_updateGet2_state_node[4:0]           ), //i
    .io_leftVertexInput_updateGet2_state_root             (vertices_0_io_stageOutputs_updateGet2_state_root[4:0]           ), //i
    .io_leftVertexInput_updateGet2_state_isVirtual        (vertices_0_io_stageOutputs_updateGet2_state_isVirtual           ), //i
    .io_leftVertexInput_updateGet2_state_isDefect         (vertices_0_io_stageOutputs_updateGet2_state_isDefect            ), //i
    .io_leftVertexInput_updateGet2_state_grown            (vertices_0_io_stageOutputs_updateGet2_state_grown[1:0]          ), //i
    .io_leftVertexInput_updateGet2_isStalled              (vertices_0_io_stageOutputs_updateGet2_isStalled                 ), //i
    .io_leftVertexInput_updateGet2_compact_valid          (vertices_0_io_stageOutputs_updateGet2_compact_valid             ), //i
    .io_leftVertexInput_updateGet2_compact_isReset        (vertices_0_io_stageOutputs_updateGet2_compact_isReset           ), //i
    .io_leftVertexInput_updateGet2_propagatingPeer_valid  (vertices_0_io_stageOutputs_updateGet2_propagatingPeer_valid     ), //i
    .io_leftVertexInput_updateGet2_propagatingPeer_node   (vertices_0_io_stageOutputs_updateGet2_propagatingPeer_node[4:0] ), //i
    .io_leftVertexInput_updateGet2_propagatingPeer_root   (vertices_0_io_stageOutputs_updateGet2_propagatingPeer_root[4:0] ), //i
    .io_leftVertexInput_updateGet3_state_speed            (vertices_0_io_stageOutputs_updateGet3_state_speed[1:0]          ), //i
    .io_leftVertexInput_updateGet3_state_node             (vertices_0_io_stageOutputs_updateGet3_state_node[4:0]           ), //i
    .io_leftVertexInput_updateGet3_state_root             (vertices_0_io_stageOutputs_updateGet3_state_root[4:0]           ), //i
    .io_leftVertexInput_updateGet3_state_isVirtual        (vertices_0_io_stageOutputs_updateGet3_state_isVirtual           ), //i
    .io_leftVertexInput_updateGet3_state_isDefect         (vertices_0_io_stageOutputs_updateGet3_state_isDefect            ), //i
    .io_leftVertexInput_updateGet3_state_grown            (vertices_0_io_stageOutputs_updateGet3_state_grown[1:0]          ), //i
    .io_leftVertexInput_updateGet3_shadow_speed           (vertices_0_io_stageOutputs_updateGet3_shadow_speed[1:0]         ), //i
    .io_leftVertexInput_updateGet3_shadow_node            (vertices_0_io_stageOutputs_updateGet3_shadow_node[4:0]          ), //i
    .io_leftVertexInput_updateGet3_shadow_root            (vertices_0_io_stageOutputs_updateGet3_shadow_root[4:0]          ), //i
    .io_leftVertexInput_updateGet3_compact_valid          (vertices_0_io_stageOutputs_updateGet3_compact_valid             ), //i
    .io_leftVertexInput_updateGet3_compact_isReset        (vertices_0_io_stageOutputs_updateGet3_compact_isReset           ), //i
    .io_rightVertexInput_offloadGet_state_speed           (vertices_1_io_stageOutputs_offloadGet_state_speed[1:0]          ), //i
    .io_rightVertexInput_offloadGet_state_node            (vertices_1_io_stageOutputs_offloadGet_state_node[4:0]           ), //i
    .io_rightVertexInput_offloadGet_state_root            (vertices_1_io_stageOutputs_offloadGet_state_root[4:0]           ), //i
    .io_rightVertexInput_offloadGet_state_isVirtual       (vertices_1_io_stageOutputs_offloadGet_state_isVirtual           ), //i
    .io_rightVertexInput_offloadGet_state_isDefect        (vertices_1_io_stageOutputs_offloadGet_state_isDefect            ), //i
    .io_rightVertexInput_offloadGet_state_grown           (vertices_1_io_stageOutputs_offloadGet_state_grown[1:0]          ), //i
    .io_rightVertexInput_offloadGet_message_valid         (vertices_1_io_stageOutputs_offloadGet_message_valid             ), //i
    .io_rightVertexInput_offloadGet_message_instruction   (vertices_1_io_stageOutputs_offloadGet_message_instruction[11:0] ), //i
    .io_rightVertexInput_offloadGet_message_isReset       (vertices_1_io_stageOutputs_offloadGet_message_isReset           ), //i
    .io_rightVertexInput_offloadGet2_state_speed          (vertices_1_io_stageOutputs_offloadGet2_state_speed[1:0]         ), //i
    .io_rightVertexInput_offloadGet2_state_node           (vertices_1_io_stageOutputs_offloadGet2_state_node[4:0]          ), //i
    .io_rightVertexInput_offloadGet2_state_root           (vertices_1_io_stageOutputs_offloadGet2_state_root[4:0]          ), //i
    .io_rightVertexInput_offloadGet2_state_isVirtual      (vertices_1_io_stageOutputs_offloadGet2_state_isVirtual          ), //i
    .io_rightVertexInput_offloadGet2_state_isDefect       (vertices_1_io_stageOutputs_offloadGet2_state_isDefect           ), //i
    .io_rightVertexInput_offloadGet2_state_grown          (vertices_1_io_stageOutputs_offloadGet2_state_grown[1:0]         ), //i
    .io_rightVertexInput_offloadGet2_message_valid        (vertices_1_io_stageOutputs_offloadGet2_message_valid            ), //i
    .io_rightVertexInput_offloadGet2_message_instruction  (vertices_1_io_stageOutputs_offloadGet2_message_instruction[11:0]), //i
    .io_rightVertexInput_offloadGet2_message_isReset      (vertices_1_io_stageOutputs_offloadGet2_message_isReset          ), //i
    .io_rightVertexInput_offloadGet3_state_speed          (vertices_1_io_stageOutputs_offloadGet3_state_speed[1:0]         ), //i
    .io_rightVertexInput_offloadGet3_state_node           (vertices_1_io_stageOutputs_offloadGet3_state_node[4:0]          ), //i
    .io_rightVertexInput_offloadGet3_state_root           (vertices_1_io_stageOutputs_offloadGet3_state_root[4:0]          ), //i
    .io_rightVertexInput_offloadGet3_state_isVirtual      (vertices_1_io_stageOutputs_offloadGet3_state_isVirtual          ), //i
    .io_rightVertexInput_offloadGet3_state_isDefect       (vertices_1_io_stageOutputs_offloadGet3_state_isDefect           ), //i
    .io_rightVertexInput_offloadGet3_state_grown          (vertices_1_io_stageOutputs_offloadGet3_state_grown[1:0]         ), //i
    .io_rightVertexInput_offloadGet3_message_valid        (vertices_1_io_stageOutputs_offloadGet3_message_valid            ), //i
    .io_rightVertexInput_offloadGet3_message_instruction  (vertices_1_io_stageOutputs_offloadGet3_message_instruction[11:0]), //i
    .io_rightVertexInput_offloadGet3_message_isReset      (vertices_1_io_stageOutputs_offloadGet3_message_isReset          ), //i
    .io_rightVertexInput_offloadGet3_isUniqueTight        (vertices_1_io_stageOutputs_offloadGet3_isUniqueTight            ), //i
    .io_rightVertexInput_offloadGet3_isIsolated           (vertices_1_io_stageOutputs_offloadGet3_isIsolated               ), //i
    .io_rightVertexInput_offloadGet4_state_speed          (vertices_1_io_stageOutputs_offloadGet4_state_speed[1:0]         ), //i
    .io_rightVertexInput_offloadGet4_state_node           (vertices_1_io_stageOutputs_offloadGet4_state_node[4:0]          ), //i
    .io_rightVertexInput_offloadGet4_state_root           (vertices_1_io_stageOutputs_offloadGet4_state_root[4:0]          ), //i
    .io_rightVertexInput_offloadGet4_state_isVirtual      (vertices_1_io_stageOutputs_offloadGet4_state_isVirtual          ), //i
    .io_rightVertexInput_offloadGet4_state_isDefect       (vertices_1_io_stageOutputs_offloadGet4_state_isDefect           ), //i
    .io_rightVertexInput_offloadGet4_state_grown          (vertices_1_io_stageOutputs_offloadGet4_state_grown[1:0]         ), //i
    .io_rightVertexInput_offloadGet4_message_valid        (vertices_1_io_stageOutputs_offloadGet4_message_valid            ), //i
    .io_rightVertexInput_offloadGet4_message_instruction  (vertices_1_io_stageOutputs_offloadGet4_message_instruction[11:0]), //i
    .io_rightVertexInput_offloadGet4_message_isReset      (vertices_1_io_stageOutputs_offloadGet4_message_isReset          ), //i
    .io_rightVertexInput_executeGet_state_speed           (vertices_1_io_stageOutputs_executeGet_state_speed[1:0]          ), //i
    .io_rightVertexInput_executeGet_state_node            (vertices_1_io_stageOutputs_executeGet_state_node[4:0]           ), //i
    .io_rightVertexInput_executeGet_state_root            (vertices_1_io_stageOutputs_executeGet_state_root[4:0]           ), //i
    .io_rightVertexInput_executeGet_state_isVirtual       (vertices_1_io_stageOutputs_executeGet_state_isVirtual           ), //i
    .io_rightVertexInput_executeGet_state_isDefect        (vertices_1_io_stageOutputs_executeGet_state_isDefect            ), //i
    .io_rightVertexInput_executeGet_state_grown           (vertices_1_io_stageOutputs_executeGet_state_grown[1:0]          ), //i
    .io_rightVertexInput_executeGet_message_valid         (vertices_1_io_stageOutputs_executeGet_message_valid             ), //i
    .io_rightVertexInput_executeGet_message_instruction   (vertices_1_io_stageOutputs_executeGet_message_instruction[11:0] ), //i
    .io_rightVertexInput_executeGet_message_isReset       (vertices_1_io_stageOutputs_executeGet_message_isReset           ), //i
    .io_rightVertexInput_executeGet_isStalled             (vertices_1_io_stageOutputs_executeGet_isStalled                 ), //i
    .io_rightVertexInput_executeGet2_state_speed          (vertices_1_io_stageOutputs_executeGet2_state_speed[1:0]         ), //i
    .io_rightVertexInput_executeGet2_state_node           (vertices_1_io_stageOutputs_executeGet2_state_node[4:0]          ), //i
    .io_rightVertexInput_executeGet2_state_root           (vertices_1_io_stageOutputs_executeGet2_state_root[4:0]          ), //i
    .io_rightVertexInput_executeGet2_state_isVirtual      (vertices_1_io_stageOutputs_executeGet2_state_isVirtual          ), //i
    .io_rightVertexInput_executeGet2_state_isDefect       (vertices_1_io_stageOutputs_executeGet2_state_isDefect           ), //i
    .io_rightVertexInput_executeGet2_state_grown          (vertices_1_io_stageOutputs_executeGet2_state_grown[1:0]         ), //i
    .io_rightVertexInput_executeGet2_isStalled            (vertices_1_io_stageOutputs_executeGet2_isStalled                ), //i
    .io_rightVertexInput_executeGet2_compact_valid        (vertices_1_io_stageOutputs_executeGet2_compact_valid            ), //i
    .io_rightVertexInput_executeGet2_compact_isReset      (vertices_1_io_stageOutputs_executeGet2_compact_isReset          ), //i
    .io_rightVertexInput_executeGet3_state_speed          (vertices_1_io_stageOutputs_executeGet3_state_speed[1:0]         ), //i
    .io_rightVertexInput_executeGet3_state_node           (vertices_1_io_stageOutputs_executeGet3_state_node[4:0]          ), //i
    .io_rightVertexInput_executeGet3_state_root           (vertices_1_io_stageOutputs_executeGet3_state_root[4:0]          ), //i
    .io_rightVertexInput_executeGet3_state_isVirtual      (vertices_1_io_stageOutputs_executeGet3_state_isVirtual          ), //i
    .io_rightVertexInput_executeGet3_state_isDefect       (vertices_1_io_stageOutputs_executeGet3_state_isDefect           ), //i
    .io_rightVertexInput_executeGet3_state_grown          (vertices_1_io_stageOutputs_executeGet3_state_grown[1:0]         ), //i
    .io_rightVertexInput_executeGet3_isStalled            (vertices_1_io_stageOutputs_executeGet3_isStalled                ), //i
    .io_rightVertexInput_executeGet3_compact_valid        (vertices_1_io_stageOutputs_executeGet3_compact_valid            ), //i
    .io_rightVertexInput_executeGet3_compact_isReset      (vertices_1_io_stageOutputs_executeGet3_compact_isReset          ), //i
    .io_rightVertexInput_updateGet_state_speed            (vertices_1_io_stageOutputs_updateGet_state_speed[1:0]           ), //i
    .io_rightVertexInput_updateGet_state_node             (vertices_1_io_stageOutputs_updateGet_state_node[4:0]            ), //i
    .io_rightVertexInput_updateGet_state_root             (vertices_1_io_stageOutputs_updateGet_state_root[4:0]            ), //i
    .io_rightVertexInput_updateGet_state_isVirtual        (vertices_1_io_stageOutputs_updateGet_state_isVirtual            ), //i
    .io_rightVertexInput_updateGet_state_isDefect         (vertices_1_io_stageOutputs_updateGet_state_isDefect             ), //i
    .io_rightVertexInput_updateGet_state_grown            (vertices_1_io_stageOutputs_updateGet_state_grown[1:0]           ), //i
    .io_rightVertexInput_updateGet_isStalled              (vertices_1_io_stageOutputs_updateGet_isStalled                  ), //i
    .io_rightVertexInput_updateGet_compact_valid          (vertices_1_io_stageOutputs_updateGet_compact_valid              ), //i
    .io_rightVertexInput_updateGet_compact_isReset        (vertices_1_io_stageOutputs_updateGet_compact_isReset            ), //i
    .io_rightVertexInput_updateGet_propagatingPeer_valid  (vertices_1_io_stageOutputs_updateGet_propagatingPeer_valid      ), //i
    .io_rightVertexInput_updateGet_propagatingPeer_node   (vertices_1_io_stageOutputs_updateGet_propagatingPeer_node[4:0]  ), //i
    .io_rightVertexInput_updateGet_propagatingPeer_root   (vertices_1_io_stageOutputs_updateGet_propagatingPeer_root[4:0]  ), //i
    .io_rightVertexInput_updateGet2_state_speed           (vertices_1_io_stageOutputs_updateGet2_state_speed[1:0]          ), //i
    .io_rightVertexInput_updateGet2_state_node            (vertices_1_io_stageOutputs_updateGet2_state_node[4:0]           ), //i
    .io_rightVertexInput_updateGet2_state_root            (vertices_1_io_stageOutputs_updateGet2_state_root[4:0]           ), //i
    .io_rightVertexInput_updateGet2_state_isVirtual       (vertices_1_io_stageOutputs_updateGet2_state_isVirtual           ), //i
    .io_rightVertexInput_updateGet2_state_isDefect        (vertices_1_io_stageOutputs_updateGet2_state_isDefect            ), //i
    .io_rightVertexInput_updateGet2_state_grown           (vertices_1_io_stageOutputs_updateGet2_state_grown[1:0]          ), //i
    .io_rightVertexInput_updateGet2_isStalled             (vertices_1_io_stageOutputs_updateGet2_isStalled                 ), //i
    .io_rightVertexInput_updateGet2_compact_valid         (vertices_1_io_stageOutputs_updateGet2_compact_valid             ), //i
    .io_rightVertexInput_updateGet2_compact_isReset       (vertices_1_io_stageOutputs_updateGet2_compact_isReset           ), //i
    .io_rightVertexInput_updateGet2_propagatingPeer_valid (vertices_1_io_stageOutputs_updateGet2_propagatingPeer_valid     ), //i
    .io_rightVertexInput_updateGet2_propagatingPeer_node  (vertices_1_io_stageOutputs_updateGet2_propagatingPeer_node[4:0] ), //i
    .io_rightVertexInput_updateGet2_propagatingPeer_root  (vertices_1_io_stageOutputs_updateGet2_propagatingPeer_root[4:0] ), //i
    .io_rightVertexInput_updateGet3_state_speed           (vertices_1_io_stageOutputs_updateGet3_state_speed[1:0]          ), //i
    .io_rightVertexInput_updateGet3_state_node            (vertices_1_io_stageOutputs_updateGet3_state_node[4:0]           ), //i
    .io_rightVertexInput_updateGet3_state_root            (vertices_1_io_stageOutputs_updateGet3_state_root[4:0]           ), //i
    .io_rightVertexInput_updateGet3_state_isVirtual       (vertices_1_io_stageOutputs_updateGet3_state_isVirtual           ), //i
    .io_rightVertexInput_updateGet3_state_isDefect        (vertices_1_io_stageOutputs_updateGet3_state_isDefect            ), //i
    .io_rightVertexInput_updateGet3_state_grown           (vertices_1_io_stageOutputs_updateGet3_state_grown[1:0]          ), //i
    .io_rightVertexInput_updateGet3_shadow_speed          (vertices_1_io_stageOutputs_updateGet3_shadow_speed[1:0]         ), //i
    .io_rightVertexInput_updateGet3_shadow_node           (vertices_1_io_stageOutputs_updateGet3_shadow_node[4:0]          ), //i
    .io_rightVertexInput_updateGet3_shadow_root           (vertices_1_io_stageOutputs_updateGet3_shadow_root[4:0]          ), //i
    .io_rightVertexInput_updateGet3_compact_valid         (vertices_1_io_stageOutputs_updateGet3_compact_valid             ), //i
    .io_rightVertexInput_updateGet3_compact_isReset       (vertices_1_io_stageOutputs_updateGet3_compact_isReset           ), //i
    .io_maxGrowable_length                                (edges_0_io_maxGrowable_length[1:0]                              ), //o
    .io_conflict_node1                                    (edges_0_io_conflict_node1[4:0]                                  ), //o
    .io_conflict_node2                                    (edges_0_io_conflict_node2[4:0]                                  ), //o
    .io_conflict_touch1                                   (edges_0_io_conflict_touch1[4:0]                                 ), //o
    .io_conflict_touch2                                   (edges_0_io_conflict_touch2[4:0]                                 ), //o
    .io_conflict_vertex1                                  (edges_0_io_conflict_vertex1[4:0]                                ), //o
    .io_conflict_vertex2                                  (edges_0_io_conflict_vertex2[4:0]                                ), //o
    .io_conflict_valid                                    (edges_0_io_conflict_valid                                       )  //o
  );
  Edge_2 edges_1 (
    .io_message_valid                                     (broadcastMessage_valid                                          ), //i
    .io_message_instruction                               (broadcastMessage_instruction[11:0]                              ), //i
    .io_message_isReset                                   (broadcastMessage_isReset                                        ), //i
    .io_stageOutputs_offloadGet_state_weight              (edges_1_io_stageOutputs_offloadGet_state_weight[1:0]            ), //o
    .io_stageOutputs_offloadGet_compact_valid             (edges_1_io_stageOutputs_offloadGet_compact_valid                ), //o
    .io_stageOutputs_offloadGet_compact_isReset           (edges_1_io_stageOutputs_offloadGet_compact_isReset              ), //o
    .io_stageOutputs_offloadGet2_state_weight             (edges_1_io_stageOutputs_offloadGet2_state_weight[1:0]           ), //o
    .io_stageOutputs_offloadGet2_isTight                  (edges_1_io_stageOutputs_offloadGet2_isTight                     ), //o
    .io_stageOutputs_offloadGet2_isTightExFusion          (edges_1_io_stageOutputs_offloadGet2_isTightExFusion             ), //o
    .io_stageOutputs_offloadGet2_compact_valid            (edges_1_io_stageOutputs_offloadGet2_compact_valid               ), //o
    .io_stageOutputs_offloadGet2_compact_isReset          (edges_1_io_stageOutputs_offloadGet2_compact_isReset             ), //o
    .io_stageOutputs_offloadGet3_state_weight             (edges_1_io_stageOutputs_offloadGet3_state_weight[1:0]           ), //o
    .io_stageOutputs_offloadGet3_isTight                  (edges_1_io_stageOutputs_offloadGet3_isTight                     ), //o
    .io_stageOutputs_offloadGet3_compact_valid            (edges_1_io_stageOutputs_offloadGet3_compact_valid               ), //o
    .io_stageOutputs_offloadGet3_compact_isReset          (edges_1_io_stageOutputs_offloadGet3_compact_isReset             ), //o
    .io_stageOutputs_offloadGet4_state_weight             (edges_1_io_stageOutputs_offloadGet4_state_weight[1:0]           ), //o
    .io_stageOutputs_offloadGet4_compact_valid            (edges_1_io_stageOutputs_offloadGet4_compact_valid               ), //o
    .io_stageOutputs_offloadGet4_compact_isReset          (edges_1_io_stageOutputs_offloadGet4_compact_isReset             ), //o
    .io_stageOutputs_executeGet_state_weight              (edges_1_io_stageOutputs_executeGet_state_weight[1:0]            ), //o
    .io_stageOutputs_executeGet_compact_valid             (edges_1_io_stageOutputs_executeGet_compact_valid                ), //o
    .io_stageOutputs_executeGet_compact_isReset           (edges_1_io_stageOutputs_executeGet_compact_isReset              ), //o
    .io_stageOutputs_executeGet2_state_weight             (edges_1_io_stageOutputs_executeGet2_state_weight[1:0]           ), //o
    .io_stageOutputs_executeGet2_compact_valid            (edges_1_io_stageOutputs_executeGet2_compact_valid               ), //o
    .io_stageOutputs_executeGet2_compact_isReset          (edges_1_io_stageOutputs_executeGet2_compact_isReset             ), //o
    .io_stageOutputs_executeGet3_state_weight             (edges_1_io_stageOutputs_executeGet3_state_weight[1:0]           ), //o
    .io_stageOutputs_executeGet3_isTight                  (edges_1_io_stageOutputs_executeGet3_isTight                     ), //o
    .io_stageOutputs_executeGet3_compact_valid            (edges_1_io_stageOutputs_executeGet3_compact_valid               ), //o
    .io_stageOutputs_executeGet3_compact_isReset          (edges_1_io_stageOutputs_executeGet3_compact_isReset             ), //o
    .io_stageOutputs_updateGet_state_weight               (edges_1_io_stageOutputs_updateGet_state_weight[1:0]             ), //o
    .io_stageOutputs_updateGet_remaining                  (edges_1_io_stageOutputs_updateGet_remaining[1:0]                ), //o
    .io_stageOutputs_updateGet_compact_valid              (edges_1_io_stageOutputs_updateGet_compact_valid                 ), //o
    .io_stageOutputs_updateGet_compact_isReset            (edges_1_io_stageOutputs_updateGet_compact_isReset               ), //o
    .io_stageOutputs_updateGet2_state_weight              (edges_1_io_stageOutputs_updateGet2_state_weight[1:0]            ), //o
    .io_stageOutputs_updateGet2_remaining                 (edges_1_io_stageOutputs_updateGet2_remaining[1:0]               ), //o
    .io_stageOutputs_updateGet2_compact_valid             (edges_1_io_stageOutputs_updateGet2_compact_valid                ), //o
    .io_stageOutputs_updateGet2_compact_isReset           (edges_1_io_stageOutputs_updateGet2_compact_isReset              ), //o
    .io_stageOutputs_updateGet3_state_weight              (edges_1_io_stageOutputs_updateGet3_state_weight[1:0]            ), //o
    .io_stageOutputs_updateGet3_remaining                 (edges_1_io_stageOutputs_updateGet3_remaining[1:0]               ), //o
    .io_stageOutputs_updateGet3_compact_valid             (edges_1_io_stageOutputs_updateGet3_compact_valid                ), //o
    .io_stageOutputs_updateGet3_compact_isReset           (edges_1_io_stageOutputs_updateGet3_compact_isReset              ), //o
    .io_leftVertexInput_offloadGet_state_speed            (vertices_1_io_stageOutputs_offloadGet_state_speed[1:0]          ), //i
    .io_leftVertexInput_offloadGet_state_node             (vertices_1_io_stageOutputs_offloadGet_state_node[4:0]           ), //i
    .io_leftVertexInput_offloadGet_state_root             (vertices_1_io_stageOutputs_offloadGet_state_root[4:0]           ), //i
    .io_leftVertexInput_offloadGet_state_isVirtual        (vertices_1_io_stageOutputs_offloadGet_state_isVirtual           ), //i
    .io_leftVertexInput_offloadGet_state_isDefect         (vertices_1_io_stageOutputs_offloadGet_state_isDefect            ), //i
    .io_leftVertexInput_offloadGet_state_grown            (vertices_1_io_stageOutputs_offloadGet_state_grown[1:0]          ), //i
    .io_leftVertexInput_offloadGet_message_valid          (vertices_1_io_stageOutputs_offloadGet_message_valid             ), //i
    .io_leftVertexInput_offloadGet_message_instruction    (vertices_1_io_stageOutputs_offloadGet_message_instruction[11:0] ), //i
    .io_leftVertexInput_offloadGet_message_isReset        (vertices_1_io_stageOutputs_offloadGet_message_isReset           ), //i
    .io_leftVertexInput_offloadGet2_state_speed           (vertices_1_io_stageOutputs_offloadGet2_state_speed[1:0]         ), //i
    .io_leftVertexInput_offloadGet2_state_node            (vertices_1_io_stageOutputs_offloadGet2_state_node[4:0]          ), //i
    .io_leftVertexInput_offloadGet2_state_root            (vertices_1_io_stageOutputs_offloadGet2_state_root[4:0]          ), //i
    .io_leftVertexInput_offloadGet2_state_isVirtual       (vertices_1_io_stageOutputs_offloadGet2_state_isVirtual          ), //i
    .io_leftVertexInput_offloadGet2_state_isDefect        (vertices_1_io_stageOutputs_offloadGet2_state_isDefect           ), //i
    .io_leftVertexInput_offloadGet2_state_grown           (vertices_1_io_stageOutputs_offloadGet2_state_grown[1:0]         ), //i
    .io_leftVertexInput_offloadGet2_message_valid         (vertices_1_io_stageOutputs_offloadGet2_message_valid            ), //i
    .io_leftVertexInput_offloadGet2_message_instruction   (vertices_1_io_stageOutputs_offloadGet2_message_instruction[11:0]), //i
    .io_leftVertexInput_offloadGet2_message_isReset       (vertices_1_io_stageOutputs_offloadGet2_message_isReset          ), //i
    .io_leftVertexInput_offloadGet3_state_speed           (vertices_1_io_stageOutputs_offloadGet3_state_speed[1:0]         ), //i
    .io_leftVertexInput_offloadGet3_state_node            (vertices_1_io_stageOutputs_offloadGet3_state_node[4:0]          ), //i
    .io_leftVertexInput_offloadGet3_state_root            (vertices_1_io_stageOutputs_offloadGet3_state_root[4:0]          ), //i
    .io_leftVertexInput_offloadGet3_state_isVirtual       (vertices_1_io_stageOutputs_offloadGet3_state_isVirtual          ), //i
    .io_leftVertexInput_offloadGet3_state_isDefect        (vertices_1_io_stageOutputs_offloadGet3_state_isDefect           ), //i
    .io_leftVertexInput_offloadGet3_state_grown           (vertices_1_io_stageOutputs_offloadGet3_state_grown[1:0]         ), //i
    .io_leftVertexInput_offloadGet3_message_valid         (vertices_1_io_stageOutputs_offloadGet3_message_valid            ), //i
    .io_leftVertexInput_offloadGet3_message_instruction   (vertices_1_io_stageOutputs_offloadGet3_message_instruction[11:0]), //i
    .io_leftVertexInput_offloadGet3_message_isReset       (vertices_1_io_stageOutputs_offloadGet3_message_isReset          ), //i
    .io_leftVertexInput_offloadGet3_isUniqueTight         (vertices_1_io_stageOutputs_offloadGet3_isUniqueTight            ), //i
    .io_leftVertexInput_offloadGet3_isIsolated            (vertices_1_io_stageOutputs_offloadGet3_isIsolated               ), //i
    .io_leftVertexInput_offloadGet4_state_speed           (vertices_1_io_stageOutputs_offloadGet4_state_speed[1:0]         ), //i
    .io_leftVertexInput_offloadGet4_state_node            (vertices_1_io_stageOutputs_offloadGet4_state_node[4:0]          ), //i
    .io_leftVertexInput_offloadGet4_state_root            (vertices_1_io_stageOutputs_offloadGet4_state_root[4:0]          ), //i
    .io_leftVertexInput_offloadGet4_state_isVirtual       (vertices_1_io_stageOutputs_offloadGet4_state_isVirtual          ), //i
    .io_leftVertexInput_offloadGet4_state_isDefect        (vertices_1_io_stageOutputs_offloadGet4_state_isDefect           ), //i
    .io_leftVertexInput_offloadGet4_state_grown           (vertices_1_io_stageOutputs_offloadGet4_state_grown[1:0]         ), //i
    .io_leftVertexInput_offloadGet4_message_valid         (vertices_1_io_stageOutputs_offloadGet4_message_valid            ), //i
    .io_leftVertexInput_offloadGet4_message_instruction   (vertices_1_io_stageOutputs_offloadGet4_message_instruction[11:0]), //i
    .io_leftVertexInput_offloadGet4_message_isReset       (vertices_1_io_stageOutputs_offloadGet4_message_isReset          ), //i
    .io_leftVertexInput_executeGet_state_speed            (vertices_1_io_stageOutputs_executeGet_state_speed[1:0]          ), //i
    .io_leftVertexInput_executeGet_state_node             (vertices_1_io_stageOutputs_executeGet_state_node[4:0]           ), //i
    .io_leftVertexInput_executeGet_state_root             (vertices_1_io_stageOutputs_executeGet_state_root[4:0]           ), //i
    .io_leftVertexInput_executeGet_state_isVirtual        (vertices_1_io_stageOutputs_executeGet_state_isVirtual           ), //i
    .io_leftVertexInput_executeGet_state_isDefect         (vertices_1_io_stageOutputs_executeGet_state_isDefect            ), //i
    .io_leftVertexInput_executeGet_state_grown            (vertices_1_io_stageOutputs_executeGet_state_grown[1:0]          ), //i
    .io_leftVertexInput_executeGet_message_valid          (vertices_1_io_stageOutputs_executeGet_message_valid             ), //i
    .io_leftVertexInput_executeGet_message_instruction    (vertices_1_io_stageOutputs_executeGet_message_instruction[11:0] ), //i
    .io_leftVertexInput_executeGet_message_isReset        (vertices_1_io_stageOutputs_executeGet_message_isReset           ), //i
    .io_leftVertexInput_executeGet_isStalled              (vertices_1_io_stageOutputs_executeGet_isStalled                 ), //i
    .io_leftVertexInput_executeGet2_state_speed           (vertices_1_io_stageOutputs_executeGet2_state_speed[1:0]         ), //i
    .io_leftVertexInput_executeGet2_state_node            (vertices_1_io_stageOutputs_executeGet2_state_node[4:0]          ), //i
    .io_leftVertexInput_executeGet2_state_root            (vertices_1_io_stageOutputs_executeGet2_state_root[4:0]          ), //i
    .io_leftVertexInput_executeGet2_state_isVirtual       (vertices_1_io_stageOutputs_executeGet2_state_isVirtual          ), //i
    .io_leftVertexInput_executeGet2_state_isDefect        (vertices_1_io_stageOutputs_executeGet2_state_isDefect           ), //i
    .io_leftVertexInput_executeGet2_state_grown           (vertices_1_io_stageOutputs_executeGet2_state_grown[1:0]         ), //i
    .io_leftVertexInput_executeGet2_isStalled             (vertices_1_io_stageOutputs_executeGet2_isStalled                ), //i
    .io_leftVertexInput_executeGet2_compact_valid         (vertices_1_io_stageOutputs_executeGet2_compact_valid            ), //i
    .io_leftVertexInput_executeGet2_compact_isReset       (vertices_1_io_stageOutputs_executeGet2_compact_isReset          ), //i
    .io_leftVertexInput_executeGet3_state_speed           (vertices_1_io_stageOutputs_executeGet3_state_speed[1:0]         ), //i
    .io_leftVertexInput_executeGet3_state_node            (vertices_1_io_stageOutputs_executeGet3_state_node[4:0]          ), //i
    .io_leftVertexInput_executeGet3_state_root            (vertices_1_io_stageOutputs_executeGet3_state_root[4:0]          ), //i
    .io_leftVertexInput_executeGet3_state_isVirtual       (vertices_1_io_stageOutputs_executeGet3_state_isVirtual          ), //i
    .io_leftVertexInput_executeGet3_state_isDefect        (vertices_1_io_stageOutputs_executeGet3_state_isDefect           ), //i
    .io_leftVertexInput_executeGet3_state_grown           (vertices_1_io_stageOutputs_executeGet3_state_grown[1:0]         ), //i
    .io_leftVertexInput_executeGet3_isStalled             (vertices_1_io_stageOutputs_executeGet3_isStalled                ), //i
    .io_leftVertexInput_executeGet3_compact_valid         (vertices_1_io_stageOutputs_executeGet3_compact_valid            ), //i
    .io_leftVertexInput_executeGet3_compact_isReset       (vertices_1_io_stageOutputs_executeGet3_compact_isReset          ), //i
    .io_leftVertexInput_updateGet_state_speed             (vertices_1_io_stageOutputs_updateGet_state_speed[1:0]           ), //i
    .io_leftVertexInput_updateGet_state_node              (vertices_1_io_stageOutputs_updateGet_state_node[4:0]            ), //i
    .io_leftVertexInput_updateGet_state_root              (vertices_1_io_stageOutputs_updateGet_state_root[4:0]            ), //i
    .io_leftVertexInput_updateGet_state_isVirtual         (vertices_1_io_stageOutputs_updateGet_state_isVirtual            ), //i
    .io_leftVertexInput_updateGet_state_isDefect          (vertices_1_io_stageOutputs_updateGet_state_isDefect             ), //i
    .io_leftVertexInput_updateGet_state_grown             (vertices_1_io_stageOutputs_updateGet_state_grown[1:0]           ), //i
    .io_leftVertexInput_updateGet_isStalled               (vertices_1_io_stageOutputs_updateGet_isStalled                  ), //i
    .io_leftVertexInput_updateGet_compact_valid           (vertices_1_io_stageOutputs_updateGet_compact_valid              ), //i
    .io_leftVertexInput_updateGet_compact_isReset         (vertices_1_io_stageOutputs_updateGet_compact_isReset            ), //i
    .io_leftVertexInput_updateGet_propagatingPeer_valid   (vertices_1_io_stageOutputs_updateGet_propagatingPeer_valid      ), //i
    .io_leftVertexInput_updateGet_propagatingPeer_node    (vertices_1_io_stageOutputs_updateGet_propagatingPeer_node[4:0]  ), //i
    .io_leftVertexInput_updateGet_propagatingPeer_root    (vertices_1_io_stageOutputs_updateGet_propagatingPeer_root[4:0]  ), //i
    .io_leftVertexInput_updateGet2_state_speed            (vertices_1_io_stageOutputs_updateGet2_state_speed[1:0]          ), //i
    .io_leftVertexInput_updateGet2_state_node             (vertices_1_io_stageOutputs_updateGet2_state_node[4:0]           ), //i
    .io_leftVertexInput_updateGet2_state_root             (vertices_1_io_stageOutputs_updateGet2_state_root[4:0]           ), //i
    .io_leftVertexInput_updateGet2_state_isVirtual        (vertices_1_io_stageOutputs_updateGet2_state_isVirtual           ), //i
    .io_leftVertexInput_updateGet2_state_isDefect         (vertices_1_io_stageOutputs_updateGet2_state_isDefect            ), //i
    .io_leftVertexInput_updateGet2_state_grown            (vertices_1_io_stageOutputs_updateGet2_state_grown[1:0]          ), //i
    .io_leftVertexInput_updateGet2_isStalled              (vertices_1_io_stageOutputs_updateGet2_isStalled                 ), //i
    .io_leftVertexInput_updateGet2_compact_valid          (vertices_1_io_stageOutputs_updateGet2_compact_valid             ), //i
    .io_leftVertexInput_updateGet2_compact_isReset        (vertices_1_io_stageOutputs_updateGet2_compact_isReset           ), //i
    .io_leftVertexInput_updateGet2_propagatingPeer_valid  (vertices_1_io_stageOutputs_updateGet2_propagatingPeer_valid     ), //i
    .io_leftVertexInput_updateGet2_propagatingPeer_node   (vertices_1_io_stageOutputs_updateGet2_propagatingPeer_node[4:0] ), //i
    .io_leftVertexInput_updateGet2_propagatingPeer_root   (vertices_1_io_stageOutputs_updateGet2_propagatingPeer_root[4:0] ), //i
    .io_leftVertexInput_updateGet3_state_speed            (vertices_1_io_stageOutputs_updateGet3_state_speed[1:0]          ), //i
    .io_leftVertexInput_updateGet3_state_node             (vertices_1_io_stageOutputs_updateGet3_state_node[4:0]           ), //i
    .io_leftVertexInput_updateGet3_state_root             (vertices_1_io_stageOutputs_updateGet3_state_root[4:0]           ), //i
    .io_leftVertexInput_updateGet3_state_isVirtual        (vertices_1_io_stageOutputs_updateGet3_state_isVirtual           ), //i
    .io_leftVertexInput_updateGet3_state_isDefect         (vertices_1_io_stageOutputs_updateGet3_state_isDefect            ), //i
    .io_leftVertexInput_updateGet3_state_grown            (vertices_1_io_stageOutputs_updateGet3_state_grown[1:0]          ), //i
    .io_leftVertexInput_updateGet3_shadow_speed           (vertices_1_io_stageOutputs_updateGet3_shadow_speed[1:0]         ), //i
    .io_leftVertexInput_updateGet3_shadow_node            (vertices_1_io_stageOutputs_updateGet3_shadow_node[4:0]          ), //i
    .io_leftVertexInput_updateGet3_shadow_root            (vertices_1_io_stageOutputs_updateGet3_shadow_root[4:0]          ), //i
    .io_leftVertexInput_updateGet3_compact_valid          (vertices_1_io_stageOutputs_updateGet3_compact_valid             ), //i
    .io_leftVertexInput_updateGet3_compact_isReset        (vertices_1_io_stageOutputs_updateGet3_compact_isReset           ), //i
    .io_rightVertexInput_offloadGet_state_speed           (vertices_2_io_stageOutputs_offloadGet_state_speed[1:0]          ), //i
    .io_rightVertexInput_offloadGet_state_node            (vertices_2_io_stageOutputs_offloadGet_state_node[4:0]           ), //i
    .io_rightVertexInput_offloadGet_state_root            (vertices_2_io_stageOutputs_offloadGet_state_root[4:0]           ), //i
    .io_rightVertexInput_offloadGet_state_isVirtual       (vertices_2_io_stageOutputs_offloadGet_state_isVirtual           ), //i
    .io_rightVertexInput_offloadGet_state_isDefect        (vertices_2_io_stageOutputs_offloadGet_state_isDefect            ), //i
    .io_rightVertexInput_offloadGet_state_grown           (vertices_2_io_stageOutputs_offloadGet_state_grown[1:0]          ), //i
    .io_rightVertexInput_offloadGet_message_valid         (vertices_2_io_stageOutputs_offloadGet_message_valid             ), //i
    .io_rightVertexInput_offloadGet_message_instruction   (vertices_2_io_stageOutputs_offloadGet_message_instruction[11:0] ), //i
    .io_rightVertexInput_offloadGet_message_isReset       (vertices_2_io_stageOutputs_offloadGet_message_isReset           ), //i
    .io_rightVertexInput_offloadGet2_state_speed          (vertices_2_io_stageOutputs_offloadGet2_state_speed[1:0]         ), //i
    .io_rightVertexInput_offloadGet2_state_node           (vertices_2_io_stageOutputs_offloadGet2_state_node[4:0]          ), //i
    .io_rightVertexInput_offloadGet2_state_root           (vertices_2_io_stageOutputs_offloadGet2_state_root[4:0]          ), //i
    .io_rightVertexInput_offloadGet2_state_isVirtual      (vertices_2_io_stageOutputs_offloadGet2_state_isVirtual          ), //i
    .io_rightVertexInput_offloadGet2_state_isDefect       (vertices_2_io_stageOutputs_offloadGet2_state_isDefect           ), //i
    .io_rightVertexInput_offloadGet2_state_grown          (vertices_2_io_stageOutputs_offloadGet2_state_grown[1:0]         ), //i
    .io_rightVertexInput_offloadGet2_message_valid        (vertices_2_io_stageOutputs_offloadGet2_message_valid            ), //i
    .io_rightVertexInput_offloadGet2_message_instruction  (vertices_2_io_stageOutputs_offloadGet2_message_instruction[11:0]), //i
    .io_rightVertexInput_offloadGet2_message_isReset      (vertices_2_io_stageOutputs_offloadGet2_message_isReset          ), //i
    .io_rightVertexInput_offloadGet3_state_speed          (vertices_2_io_stageOutputs_offloadGet3_state_speed[1:0]         ), //i
    .io_rightVertexInput_offloadGet3_state_node           (vertices_2_io_stageOutputs_offloadGet3_state_node[4:0]          ), //i
    .io_rightVertexInput_offloadGet3_state_root           (vertices_2_io_stageOutputs_offloadGet3_state_root[4:0]          ), //i
    .io_rightVertexInput_offloadGet3_state_isVirtual      (vertices_2_io_stageOutputs_offloadGet3_state_isVirtual          ), //i
    .io_rightVertexInput_offloadGet3_state_isDefect       (vertices_2_io_stageOutputs_offloadGet3_state_isDefect           ), //i
    .io_rightVertexInput_offloadGet3_state_grown          (vertices_2_io_stageOutputs_offloadGet3_state_grown[1:0]         ), //i
    .io_rightVertexInput_offloadGet3_message_valid        (vertices_2_io_stageOutputs_offloadGet3_message_valid            ), //i
    .io_rightVertexInput_offloadGet3_message_instruction  (vertices_2_io_stageOutputs_offloadGet3_message_instruction[11:0]), //i
    .io_rightVertexInput_offloadGet3_message_isReset      (vertices_2_io_stageOutputs_offloadGet3_message_isReset          ), //i
    .io_rightVertexInput_offloadGet3_isUniqueTight        (vertices_2_io_stageOutputs_offloadGet3_isUniqueTight            ), //i
    .io_rightVertexInput_offloadGet3_isIsolated           (vertices_2_io_stageOutputs_offloadGet3_isIsolated               ), //i
    .io_rightVertexInput_offloadGet4_state_speed          (vertices_2_io_stageOutputs_offloadGet4_state_speed[1:0]         ), //i
    .io_rightVertexInput_offloadGet4_state_node           (vertices_2_io_stageOutputs_offloadGet4_state_node[4:0]          ), //i
    .io_rightVertexInput_offloadGet4_state_root           (vertices_2_io_stageOutputs_offloadGet4_state_root[4:0]          ), //i
    .io_rightVertexInput_offloadGet4_state_isVirtual      (vertices_2_io_stageOutputs_offloadGet4_state_isVirtual          ), //i
    .io_rightVertexInput_offloadGet4_state_isDefect       (vertices_2_io_stageOutputs_offloadGet4_state_isDefect           ), //i
    .io_rightVertexInput_offloadGet4_state_grown          (vertices_2_io_stageOutputs_offloadGet4_state_grown[1:0]         ), //i
    .io_rightVertexInput_offloadGet4_message_valid        (vertices_2_io_stageOutputs_offloadGet4_message_valid            ), //i
    .io_rightVertexInput_offloadGet4_message_instruction  (vertices_2_io_stageOutputs_offloadGet4_message_instruction[11:0]), //i
    .io_rightVertexInput_offloadGet4_message_isReset      (vertices_2_io_stageOutputs_offloadGet4_message_isReset          ), //i
    .io_rightVertexInput_executeGet_state_speed           (vertices_2_io_stageOutputs_executeGet_state_speed[1:0]          ), //i
    .io_rightVertexInput_executeGet_state_node            (vertices_2_io_stageOutputs_executeGet_state_node[4:0]           ), //i
    .io_rightVertexInput_executeGet_state_root            (vertices_2_io_stageOutputs_executeGet_state_root[4:0]           ), //i
    .io_rightVertexInput_executeGet_state_isVirtual       (vertices_2_io_stageOutputs_executeGet_state_isVirtual           ), //i
    .io_rightVertexInput_executeGet_state_isDefect        (vertices_2_io_stageOutputs_executeGet_state_isDefect            ), //i
    .io_rightVertexInput_executeGet_state_grown           (vertices_2_io_stageOutputs_executeGet_state_grown[1:0]          ), //i
    .io_rightVertexInput_executeGet_message_valid         (vertices_2_io_stageOutputs_executeGet_message_valid             ), //i
    .io_rightVertexInput_executeGet_message_instruction   (vertices_2_io_stageOutputs_executeGet_message_instruction[11:0] ), //i
    .io_rightVertexInput_executeGet_message_isReset       (vertices_2_io_stageOutputs_executeGet_message_isReset           ), //i
    .io_rightVertexInput_executeGet_isStalled             (vertices_2_io_stageOutputs_executeGet_isStalled                 ), //i
    .io_rightVertexInput_executeGet2_state_speed          (vertices_2_io_stageOutputs_executeGet2_state_speed[1:0]         ), //i
    .io_rightVertexInput_executeGet2_state_node           (vertices_2_io_stageOutputs_executeGet2_state_node[4:0]          ), //i
    .io_rightVertexInput_executeGet2_state_root           (vertices_2_io_stageOutputs_executeGet2_state_root[4:0]          ), //i
    .io_rightVertexInput_executeGet2_state_isVirtual      (vertices_2_io_stageOutputs_executeGet2_state_isVirtual          ), //i
    .io_rightVertexInput_executeGet2_state_isDefect       (vertices_2_io_stageOutputs_executeGet2_state_isDefect           ), //i
    .io_rightVertexInput_executeGet2_state_grown          (vertices_2_io_stageOutputs_executeGet2_state_grown[1:0]         ), //i
    .io_rightVertexInput_executeGet2_isStalled            (vertices_2_io_stageOutputs_executeGet2_isStalled                ), //i
    .io_rightVertexInput_executeGet2_compact_valid        (vertices_2_io_stageOutputs_executeGet2_compact_valid            ), //i
    .io_rightVertexInput_executeGet2_compact_isReset      (vertices_2_io_stageOutputs_executeGet2_compact_isReset          ), //i
    .io_rightVertexInput_executeGet3_state_speed          (vertices_2_io_stageOutputs_executeGet3_state_speed[1:0]         ), //i
    .io_rightVertexInput_executeGet3_state_node           (vertices_2_io_stageOutputs_executeGet3_state_node[4:0]          ), //i
    .io_rightVertexInput_executeGet3_state_root           (vertices_2_io_stageOutputs_executeGet3_state_root[4:0]          ), //i
    .io_rightVertexInput_executeGet3_state_isVirtual      (vertices_2_io_stageOutputs_executeGet3_state_isVirtual          ), //i
    .io_rightVertexInput_executeGet3_state_isDefect       (vertices_2_io_stageOutputs_executeGet3_state_isDefect           ), //i
    .io_rightVertexInput_executeGet3_state_grown          (vertices_2_io_stageOutputs_executeGet3_state_grown[1:0]         ), //i
    .io_rightVertexInput_executeGet3_isStalled            (vertices_2_io_stageOutputs_executeGet3_isStalled                ), //i
    .io_rightVertexInput_executeGet3_compact_valid        (vertices_2_io_stageOutputs_executeGet3_compact_valid            ), //i
    .io_rightVertexInput_executeGet3_compact_isReset      (vertices_2_io_stageOutputs_executeGet3_compact_isReset          ), //i
    .io_rightVertexInput_updateGet_state_speed            (vertices_2_io_stageOutputs_updateGet_state_speed[1:0]           ), //i
    .io_rightVertexInput_updateGet_state_node             (vertices_2_io_stageOutputs_updateGet_state_node[4:0]            ), //i
    .io_rightVertexInput_updateGet_state_root             (vertices_2_io_stageOutputs_updateGet_state_root[4:0]            ), //i
    .io_rightVertexInput_updateGet_state_isVirtual        (vertices_2_io_stageOutputs_updateGet_state_isVirtual            ), //i
    .io_rightVertexInput_updateGet_state_isDefect         (vertices_2_io_stageOutputs_updateGet_state_isDefect             ), //i
    .io_rightVertexInput_updateGet_state_grown            (vertices_2_io_stageOutputs_updateGet_state_grown[1:0]           ), //i
    .io_rightVertexInput_updateGet_isStalled              (vertices_2_io_stageOutputs_updateGet_isStalled                  ), //i
    .io_rightVertexInput_updateGet_compact_valid          (vertices_2_io_stageOutputs_updateGet_compact_valid              ), //i
    .io_rightVertexInput_updateGet_compact_isReset        (vertices_2_io_stageOutputs_updateGet_compact_isReset            ), //i
    .io_rightVertexInput_updateGet_propagatingPeer_valid  (vertices_2_io_stageOutputs_updateGet_propagatingPeer_valid      ), //i
    .io_rightVertexInput_updateGet_propagatingPeer_node   (vertices_2_io_stageOutputs_updateGet_propagatingPeer_node[4:0]  ), //i
    .io_rightVertexInput_updateGet_propagatingPeer_root   (vertices_2_io_stageOutputs_updateGet_propagatingPeer_root[4:0]  ), //i
    .io_rightVertexInput_updateGet2_state_speed           (vertices_2_io_stageOutputs_updateGet2_state_speed[1:0]          ), //i
    .io_rightVertexInput_updateGet2_state_node            (vertices_2_io_stageOutputs_updateGet2_state_node[4:0]           ), //i
    .io_rightVertexInput_updateGet2_state_root            (vertices_2_io_stageOutputs_updateGet2_state_root[4:0]           ), //i
    .io_rightVertexInput_updateGet2_state_isVirtual       (vertices_2_io_stageOutputs_updateGet2_state_isVirtual           ), //i
    .io_rightVertexInput_updateGet2_state_isDefect        (vertices_2_io_stageOutputs_updateGet2_state_isDefect            ), //i
    .io_rightVertexInput_updateGet2_state_grown           (vertices_2_io_stageOutputs_updateGet2_state_grown[1:0]          ), //i
    .io_rightVertexInput_updateGet2_isStalled             (vertices_2_io_stageOutputs_updateGet2_isStalled                 ), //i
    .io_rightVertexInput_updateGet2_compact_valid         (vertices_2_io_stageOutputs_updateGet2_compact_valid             ), //i
    .io_rightVertexInput_updateGet2_compact_isReset       (vertices_2_io_stageOutputs_updateGet2_compact_isReset           ), //i
    .io_rightVertexInput_updateGet2_propagatingPeer_valid (vertices_2_io_stageOutputs_updateGet2_propagatingPeer_valid     ), //i
    .io_rightVertexInput_updateGet2_propagatingPeer_node  (vertices_2_io_stageOutputs_updateGet2_propagatingPeer_node[4:0] ), //i
    .io_rightVertexInput_updateGet2_propagatingPeer_root  (vertices_2_io_stageOutputs_updateGet2_propagatingPeer_root[4:0] ), //i
    .io_rightVertexInput_updateGet3_state_speed           (vertices_2_io_stageOutputs_updateGet3_state_speed[1:0]          ), //i
    .io_rightVertexInput_updateGet3_state_node            (vertices_2_io_stageOutputs_updateGet3_state_node[4:0]           ), //i
    .io_rightVertexInput_updateGet3_state_root            (vertices_2_io_stageOutputs_updateGet3_state_root[4:0]           ), //i
    .io_rightVertexInput_updateGet3_state_isVirtual       (vertices_2_io_stageOutputs_updateGet3_state_isVirtual           ), //i
    .io_rightVertexInput_updateGet3_state_isDefect        (vertices_2_io_stageOutputs_updateGet3_state_isDefect            ), //i
    .io_rightVertexInput_updateGet3_state_grown           (vertices_2_io_stageOutputs_updateGet3_state_grown[1:0]          ), //i
    .io_rightVertexInput_updateGet3_shadow_speed          (vertices_2_io_stageOutputs_updateGet3_shadow_speed[1:0]         ), //i
    .io_rightVertexInput_updateGet3_shadow_node           (vertices_2_io_stageOutputs_updateGet3_shadow_node[4:0]          ), //i
    .io_rightVertexInput_updateGet3_shadow_root           (vertices_2_io_stageOutputs_updateGet3_shadow_root[4:0]          ), //i
    .io_rightVertexInput_updateGet3_compact_valid         (vertices_2_io_stageOutputs_updateGet3_compact_valid             ), //i
    .io_rightVertexInput_updateGet3_compact_isReset       (vertices_2_io_stageOutputs_updateGet3_compact_isReset           ), //i
    .io_maxGrowable_length                                (edges_1_io_maxGrowable_length[1:0]                              ), //o
    .io_conflict_node1                                    (edges_1_io_conflict_node1[4:0]                                  ), //o
    .io_conflict_node2                                    (edges_1_io_conflict_node2[4:0]                                  ), //o
    .io_conflict_touch1                                   (edges_1_io_conflict_touch1[4:0]                                 ), //o
    .io_conflict_touch2                                   (edges_1_io_conflict_touch2[4:0]                                 ), //o
    .io_conflict_vertex1                                  (edges_1_io_conflict_vertex1[4:0]                                ), //o
    .io_conflict_vertex2                                  (edges_1_io_conflict_vertex2[4:0]                                ), //o
    .io_conflict_valid                                    (edges_1_io_conflict_valid                                       )  //o
  );
  Edge_3 edges_2 (
    .io_message_valid                                     (broadcastMessage_valid                                          ), //i
    .io_message_instruction                               (broadcastMessage_instruction[11:0]                              ), //i
    .io_message_isReset                                   (broadcastMessage_isReset                                        ), //i
    .io_stageOutputs_offloadGet_state_weight              (edges_2_io_stageOutputs_offloadGet_state_weight[1:0]            ), //o
    .io_stageOutputs_offloadGet_compact_valid             (edges_2_io_stageOutputs_offloadGet_compact_valid                ), //o
    .io_stageOutputs_offloadGet_compact_isReset           (edges_2_io_stageOutputs_offloadGet_compact_isReset              ), //o
    .io_stageOutputs_offloadGet2_state_weight             (edges_2_io_stageOutputs_offloadGet2_state_weight[1:0]           ), //o
    .io_stageOutputs_offloadGet2_isTight                  (edges_2_io_stageOutputs_offloadGet2_isTight                     ), //o
    .io_stageOutputs_offloadGet2_isTightExFusion          (edges_2_io_stageOutputs_offloadGet2_isTightExFusion             ), //o
    .io_stageOutputs_offloadGet2_compact_valid            (edges_2_io_stageOutputs_offloadGet2_compact_valid               ), //o
    .io_stageOutputs_offloadGet2_compact_isReset          (edges_2_io_stageOutputs_offloadGet2_compact_isReset             ), //o
    .io_stageOutputs_offloadGet3_state_weight             (edges_2_io_stageOutputs_offloadGet3_state_weight[1:0]           ), //o
    .io_stageOutputs_offloadGet3_isTight                  (edges_2_io_stageOutputs_offloadGet3_isTight                     ), //o
    .io_stageOutputs_offloadGet3_compact_valid            (edges_2_io_stageOutputs_offloadGet3_compact_valid               ), //o
    .io_stageOutputs_offloadGet3_compact_isReset          (edges_2_io_stageOutputs_offloadGet3_compact_isReset             ), //o
    .io_stageOutputs_offloadGet4_state_weight             (edges_2_io_stageOutputs_offloadGet4_state_weight[1:0]           ), //o
    .io_stageOutputs_offloadGet4_compact_valid            (edges_2_io_stageOutputs_offloadGet4_compact_valid               ), //o
    .io_stageOutputs_offloadGet4_compact_isReset          (edges_2_io_stageOutputs_offloadGet4_compact_isReset             ), //o
    .io_stageOutputs_executeGet_state_weight              (edges_2_io_stageOutputs_executeGet_state_weight[1:0]            ), //o
    .io_stageOutputs_executeGet_compact_valid             (edges_2_io_stageOutputs_executeGet_compact_valid                ), //o
    .io_stageOutputs_executeGet_compact_isReset           (edges_2_io_stageOutputs_executeGet_compact_isReset              ), //o
    .io_stageOutputs_executeGet2_state_weight             (edges_2_io_stageOutputs_executeGet2_state_weight[1:0]           ), //o
    .io_stageOutputs_executeGet2_compact_valid            (edges_2_io_stageOutputs_executeGet2_compact_valid               ), //o
    .io_stageOutputs_executeGet2_compact_isReset          (edges_2_io_stageOutputs_executeGet2_compact_isReset             ), //o
    .io_stageOutputs_executeGet3_state_weight             (edges_2_io_stageOutputs_executeGet3_state_weight[1:0]           ), //o
    .io_stageOutputs_executeGet3_isTight                  (edges_2_io_stageOutputs_executeGet3_isTight                     ), //o
    .io_stageOutputs_executeGet3_compact_valid            (edges_2_io_stageOutputs_executeGet3_compact_valid               ), //o
    .io_stageOutputs_executeGet3_compact_isReset          (edges_2_io_stageOutputs_executeGet3_compact_isReset             ), //o
    .io_stageOutputs_updateGet_state_weight               (edges_2_io_stageOutputs_updateGet_state_weight[1:0]             ), //o
    .io_stageOutputs_updateGet_remaining                  (edges_2_io_stageOutputs_updateGet_remaining[1:0]                ), //o
    .io_stageOutputs_updateGet_compact_valid              (edges_2_io_stageOutputs_updateGet_compact_valid                 ), //o
    .io_stageOutputs_updateGet_compact_isReset            (edges_2_io_stageOutputs_updateGet_compact_isReset               ), //o
    .io_stageOutputs_updateGet2_state_weight              (edges_2_io_stageOutputs_updateGet2_state_weight[1:0]            ), //o
    .io_stageOutputs_updateGet2_remaining                 (edges_2_io_stageOutputs_updateGet2_remaining[1:0]               ), //o
    .io_stageOutputs_updateGet2_compact_valid             (edges_2_io_stageOutputs_updateGet2_compact_valid                ), //o
    .io_stageOutputs_updateGet2_compact_isReset           (edges_2_io_stageOutputs_updateGet2_compact_isReset              ), //o
    .io_stageOutputs_updateGet3_state_weight              (edges_2_io_stageOutputs_updateGet3_state_weight[1:0]            ), //o
    .io_stageOutputs_updateGet3_remaining                 (edges_2_io_stageOutputs_updateGet3_remaining[1:0]               ), //o
    .io_stageOutputs_updateGet3_compact_valid             (edges_2_io_stageOutputs_updateGet3_compact_valid                ), //o
    .io_stageOutputs_updateGet3_compact_isReset           (edges_2_io_stageOutputs_updateGet3_compact_isReset              ), //o
    .io_leftVertexInput_offloadGet_state_speed            (vertices_0_io_stageOutputs_offloadGet_state_speed[1:0]          ), //i
    .io_leftVertexInput_offloadGet_state_node             (vertices_0_io_stageOutputs_offloadGet_state_node[4:0]           ), //i
    .io_leftVertexInput_offloadGet_state_root             (vertices_0_io_stageOutputs_offloadGet_state_root[4:0]           ), //i
    .io_leftVertexInput_offloadGet_state_isVirtual        (vertices_0_io_stageOutputs_offloadGet_state_isVirtual           ), //i
    .io_leftVertexInput_offloadGet_state_isDefect         (vertices_0_io_stageOutputs_offloadGet_state_isDefect            ), //i
    .io_leftVertexInput_offloadGet_state_grown            (vertices_0_io_stageOutputs_offloadGet_state_grown[1:0]          ), //i
    .io_leftVertexInput_offloadGet_message_valid          (vertices_0_io_stageOutputs_offloadGet_message_valid             ), //i
    .io_leftVertexInput_offloadGet_message_instruction    (vertices_0_io_stageOutputs_offloadGet_message_instruction[11:0] ), //i
    .io_leftVertexInput_offloadGet_message_isReset        (vertices_0_io_stageOutputs_offloadGet_message_isReset           ), //i
    .io_leftVertexInput_offloadGet2_state_speed           (vertices_0_io_stageOutputs_offloadGet2_state_speed[1:0]         ), //i
    .io_leftVertexInput_offloadGet2_state_node            (vertices_0_io_stageOutputs_offloadGet2_state_node[4:0]          ), //i
    .io_leftVertexInput_offloadGet2_state_root            (vertices_0_io_stageOutputs_offloadGet2_state_root[4:0]          ), //i
    .io_leftVertexInput_offloadGet2_state_isVirtual       (vertices_0_io_stageOutputs_offloadGet2_state_isVirtual          ), //i
    .io_leftVertexInput_offloadGet2_state_isDefect        (vertices_0_io_stageOutputs_offloadGet2_state_isDefect           ), //i
    .io_leftVertexInput_offloadGet2_state_grown           (vertices_0_io_stageOutputs_offloadGet2_state_grown[1:0]         ), //i
    .io_leftVertexInput_offloadGet2_message_valid         (vertices_0_io_stageOutputs_offloadGet2_message_valid            ), //i
    .io_leftVertexInput_offloadGet2_message_instruction   (vertices_0_io_stageOutputs_offloadGet2_message_instruction[11:0]), //i
    .io_leftVertexInput_offloadGet2_message_isReset       (vertices_0_io_stageOutputs_offloadGet2_message_isReset          ), //i
    .io_leftVertexInput_offloadGet3_state_speed           (vertices_0_io_stageOutputs_offloadGet3_state_speed[1:0]         ), //i
    .io_leftVertexInput_offloadGet3_state_node            (vertices_0_io_stageOutputs_offloadGet3_state_node[4:0]          ), //i
    .io_leftVertexInput_offloadGet3_state_root            (vertices_0_io_stageOutputs_offloadGet3_state_root[4:0]          ), //i
    .io_leftVertexInput_offloadGet3_state_isVirtual       (vertices_0_io_stageOutputs_offloadGet3_state_isVirtual          ), //i
    .io_leftVertexInput_offloadGet3_state_isDefect        (vertices_0_io_stageOutputs_offloadGet3_state_isDefect           ), //i
    .io_leftVertexInput_offloadGet3_state_grown           (vertices_0_io_stageOutputs_offloadGet3_state_grown[1:0]         ), //i
    .io_leftVertexInput_offloadGet3_message_valid         (vertices_0_io_stageOutputs_offloadGet3_message_valid            ), //i
    .io_leftVertexInput_offloadGet3_message_instruction   (vertices_0_io_stageOutputs_offloadGet3_message_instruction[11:0]), //i
    .io_leftVertexInput_offloadGet3_message_isReset       (vertices_0_io_stageOutputs_offloadGet3_message_isReset          ), //i
    .io_leftVertexInput_offloadGet3_isUniqueTight         (vertices_0_io_stageOutputs_offloadGet3_isUniqueTight            ), //i
    .io_leftVertexInput_offloadGet3_isIsolated            (vertices_0_io_stageOutputs_offloadGet3_isIsolated               ), //i
    .io_leftVertexInput_offloadGet4_state_speed           (vertices_0_io_stageOutputs_offloadGet4_state_speed[1:0]         ), //i
    .io_leftVertexInput_offloadGet4_state_node            (vertices_0_io_stageOutputs_offloadGet4_state_node[4:0]          ), //i
    .io_leftVertexInput_offloadGet4_state_root            (vertices_0_io_stageOutputs_offloadGet4_state_root[4:0]          ), //i
    .io_leftVertexInput_offloadGet4_state_isVirtual       (vertices_0_io_stageOutputs_offloadGet4_state_isVirtual          ), //i
    .io_leftVertexInput_offloadGet4_state_isDefect        (vertices_0_io_stageOutputs_offloadGet4_state_isDefect           ), //i
    .io_leftVertexInput_offloadGet4_state_grown           (vertices_0_io_stageOutputs_offloadGet4_state_grown[1:0]         ), //i
    .io_leftVertexInput_offloadGet4_message_valid         (vertices_0_io_stageOutputs_offloadGet4_message_valid            ), //i
    .io_leftVertexInput_offloadGet4_message_instruction   (vertices_0_io_stageOutputs_offloadGet4_message_instruction[11:0]), //i
    .io_leftVertexInput_offloadGet4_message_isReset       (vertices_0_io_stageOutputs_offloadGet4_message_isReset          ), //i
    .io_leftVertexInput_executeGet_state_speed            (vertices_0_io_stageOutputs_executeGet_state_speed[1:0]          ), //i
    .io_leftVertexInput_executeGet_state_node             (vertices_0_io_stageOutputs_executeGet_state_node[4:0]           ), //i
    .io_leftVertexInput_executeGet_state_root             (vertices_0_io_stageOutputs_executeGet_state_root[4:0]           ), //i
    .io_leftVertexInput_executeGet_state_isVirtual        (vertices_0_io_stageOutputs_executeGet_state_isVirtual           ), //i
    .io_leftVertexInput_executeGet_state_isDefect         (vertices_0_io_stageOutputs_executeGet_state_isDefect            ), //i
    .io_leftVertexInput_executeGet_state_grown            (vertices_0_io_stageOutputs_executeGet_state_grown[1:0]          ), //i
    .io_leftVertexInput_executeGet_message_valid          (vertices_0_io_stageOutputs_executeGet_message_valid             ), //i
    .io_leftVertexInput_executeGet_message_instruction    (vertices_0_io_stageOutputs_executeGet_message_instruction[11:0] ), //i
    .io_leftVertexInput_executeGet_message_isReset        (vertices_0_io_stageOutputs_executeGet_message_isReset           ), //i
    .io_leftVertexInput_executeGet_isStalled              (vertices_0_io_stageOutputs_executeGet_isStalled                 ), //i
    .io_leftVertexInput_executeGet2_state_speed           (vertices_0_io_stageOutputs_executeGet2_state_speed[1:0]         ), //i
    .io_leftVertexInput_executeGet2_state_node            (vertices_0_io_stageOutputs_executeGet2_state_node[4:0]          ), //i
    .io_leftVertexInput_executeGet2_state_root            (vertices_0_io_stageOutputs_executeGet2_state_root[4:0]          ), //i
    .io_leftVertexInput_executeGet2_state_isVirtual       (vertices_0_io_stageOutputs_executeGet2_state_isVirtual          ), //i
    .io_leftVertexInput_executeGet2_state_isDefect        (vertices_0_io_stageOutputs_executeGet2_state_isDefect           ), //i
    .io_leftVertexInput_executeGet2_state_grown           (vertices_0_io_stageOutputs_executeGet2_state_grown[1:0]         ), //i
    .io_leftVertexInput_executeGet2_isStalled             (vertices_0_io_stageOutputs_executeGet2_isStalled                ), //i
    .io_leftVertexInput_executeGet2_compact_valid         (vertices_0_io_stageOutputs_executeGet2_compact_valid            ), //i
    .io_leftVertexInput_executeGet2_compact_isReset       (vertices_0_io_stageOutputs_executeGet2_compact_isReset          ), //i
    .io_leftVertexInput_executeGet3_state_speed           (vertices_0_io_stageOutputs_executeGet3_state_speed[1:0]         ), //i
    .io_leftVertexInput_executeGet3_state_node            (vertices_0_io_stageOutputs_executeGet3_state_node[4:0]          ), //i
    .io_leftVertexInput_executeGet3_state_root            (vertices_0_io_stageOutputs_executeGet3_state_root[4:0]          ), //i
    .io_leftVertexInput_executeGet3_state_isVirtual       (vertices_0_io_stageOutputs_executeGet3_state_isVirtual          ), //i
    .io_leftVertexInput_executeGet3_state_isDefect        (vertices_0_io_stageOutputs_executeGet3_state_isDefect           ), //i
    .io_leftVertexInput_executeGet3_state_grown           (vertices_0_io_stageOutputs_executeGet3_state_grown[1:0]         ), //i
    .io_leftVertexInput_executeGet3_isStalled             (vertices_0_io_stageOutputs_executeGet3_isStalled                ), //i
    .io_leftVertexInput_executeGet3_compact_valid         (vertices_0_io_stageOutputs_executeGet3_compact_valid            ), //i
    .io_leftVertexInput_executeGet3_compact_isReset       (vertices_0_io_stageOutputs_executeGet3_compact_isReset          ), //i
    .io_leftVertexInput_updateGet_state_speed             (vertices_0_io_stageOutputs_updateGet_state_speed[1:0]           ), //i
    .io_leftVertexInput_updateGet_state_node              (vertices_0_io_stageOutputs_updateGet_state_node[4:0]            ), //i
    .io_leftVertexInput_updateGet_state_root              (vertices_0_io_stageOutputs_updateGet_state_root[4:0]            ), //i
    .io_leftVertexInput_updateGet_state_isVirtual         (vertices_0_io_stageOutputs_updateGet_state_isVirtual            ), //i
    .io_leftVertexInput_updateGet_state_isDefect          (vertices_0_io_stageOutputs_updateGet_state_isDefect             ), //i
    .io_leftVertexInput_updateGet_state_grown             (vertices_0_io_stageOutputs_updateGet_state_grown[1:0]           ), //i
    .io_leftVertexInput_updateGet_isStalled               (vertices_0_io_stageOutputs_updateGet_isStalled                  ), //i
    .io_leftVertexInput_updateGet_compact_valid           (vertices_0_io_stageOutputs_updateGet_compact_valid              ), //i
    .io_leftVertexInput_updateGet_compact_isReset         (vertices_0_io_stageOutputs_updateGet_compact_isReset            ), //i
    .io_leftVertexInput_updateGet_propagatingPeer_valid   (vertices_0_io_stageOutputs_updateGet_propagatingPeer_valid      ), //i
    .io_leftVertexInput_updateGet_propagatingPeer_node    (vertices_0_io_stageOutputs_updateGet_propagatingPeer_node[4:0]  ), //i
    .io_leftVertexInput_updateGet_propagatingPeer_root    (vertices_0_io_stageOutputs_updateGet_propagatingPeer_root[4:0]  ), //i
    .io_leftVertexInput_updateGet2_state_speed            (vertices_0_io_stageOutputs_updateGet2_state_speed[1:0]          ), //i
    .io_leftVertexInput_updateGet2_state_node             (vertices_0_io_stageOutputs_updateGet2_state_node[4:0]           ), //i
    .io_leftVertexInput_updateGet2_state_root             (vertices_0_io_stageOutputs_updateGet2_state_root[4:0]           ), //i
    .io_leftVertexInput_updateGet2_state_isVirtual        (vertices_0_io_stageOutputs_updateGet2_state_isVirtual           ), //i
    .io_leftVertexInput_updateGet2_state_isDefect         (vertices_0_io_stageOutputs_updateGet2_state_isDefect            ), //i
    .io_leftVertexInput_updateGet2_state_grown            (vertices_0_io_stageOutputs_updateGet2_state_grown[1:0]          ), //i
    .io_leftVertexInput_updateGet2_isStalled              (vertices_0_io_stageOutputs_updateGet2_isStalled                 ), //i
    .io_leftVertexInput_updateGet2_compact_valid          (vertices_0_io_stageOutputs_updateGet2_compact_valid             ), //i
    .io_leftVertexInput_updateGet2_compact_isReset        (vertices_0_io_stageOutputs_updateGet2_compact_isReset           ), //i
    .io_leftVertexInput_updateGet2_propagatingPeer_valid  (vertices_0_io_stageOutputs_updateGet2_propagatingPeer_valid     ), //i
    .io_leftVertexInput_updateGet2_propagatingPeer_node   (vertices_0_io_stageOutputs_updateGet2_propagatingPeer_node[4:0] ), //i
    .io_leftVertexInput_updateGet2_propagatingPeer_root   (vertices_0_io_stageOutputs_updateGet2_propagatingPeer_root[4:0] ), //i
    .io_leftVertexInput_updateGet3_state_speed            (vertices_0_io_stageOutputs_updateGet3_state_speed[1:0]          ), //i
    .io_leftVertexInput_updateGet3_state_node             (vertices_0_io_stageOutputs_updateGet3_state_node[4:0]           ), //i
    .io_leftVertexInput_updateGet3_state_root             (vertices_0_io_stageOutputs_updateGet3_state_root[4:0]           ), //i
    .io_leftVertexInput_updateGet3_state_isVirtual        (vertices_0_io_stageOutputs_updateGet3_state_isVirtual           ), //i
    .io_leftVertexInput_updateGet3_state_isDefect         (vertices_0_io_stageOutputs_updateGet3_state_isDefect            ), //i
    .io_leftVertexInput_updateGet3_state_grown            (vertices_0_io_stageOutputs_updateGet3_state_grown[1:0]          ), //i
    .io_leftVertexInput_updateGet3_shadow_speed           (vertices_0_io_stageOutputs_updateGet3_shadow_speed[1:0]         ), //i
    .io_leftVertexInput_updateGet3_shadow_node            (vertices_0_io_stageOutputs_updateGet3_shadow_node[4:0]          ), //i
    .io_leftVertexInput_updateGet3_shadow_root            (vertices_0_io_stageOutputs_updateGet3_shadow_root[4:0]          ), //i
    .io_leftVertexInput_updateGet3_compact_valid          (vertices_0_io_stageOutputs_updateGet3_compact_valid             ), //i
    .io_leftVertexInput_updateGet3_compact_isReset        (vertices_0_io_stageOutputs_updateGet3_compact_isReset           ), //i
    .io_rightVertexInput_offloadGet_state_speed           (vertices_3_io_stageOutputs_offloadGet_state_speed[1:0]          ), //i
    .io_rightVertexInput_offloadGet_state_node            (vertices_3_io_stageOutputs_offloadGet_state_node[4:0]           ), //i
    .io_rightVertexInput_offloadGet_state_root            (vertices_3_io_stageOutputs_offloadGet_state_root[4:0]           ), //i
    .io_rightVertexInput_offloadGet_state_isVirtual       (vertices_3_io_stageOutputs_offloadGet_state_isVirtual           ), //i
    .io_rightVertexInput_offloadGet_state_isDefect        (vertices_3_io_stageOutputs_offloadGet_state_isDefect            ), //i
    .io_rightVertexInput_offloadGet_state_grown           (vertices_3_io_stageOutputs_offloadGet_state_grown[1:0]          ), //i
    .io_rightVertexInput_offloadGet_message_valid         (vertices_3_io_stageOutputs_offloadGet_message_valid             ), //i
    .io_rightVertexInput_offloadGet_message_instruction   (vertices_3_io_stageOutputs_offloadGet_message_instruction[11:0] ), //i
    .io_rightVertexInput_offloadGet_message_isReset       (vertices_3_io_stageOutputs_offloadGet_message_isReset           ), //i
    .io_rightVertexInput_offloadGet2_state_speed          (vertices_3_io_stageOutputs_offloadGet2_state_speed[1:0]         ), //i
    .io_rightVertexInput_offloadGet2_state_node           (vertices_3_io_stageOutputs_offloadGet2_state_node[4:0]          ), //i
    .io_rightVertexInput_offloadGet2_state_root           (vertices_3_io_stageOutputs_offloadGet2_state_root[4:0]          ), //i
    .io_rightVertexInput_offloadGet2_state_isVirtual      (vertices_3_io_stageOutputs_offloadGet2_state_isVirtual          ), //i
    .io_rightVertexInput_offloadGet2_state_isDefect       (vertices_3_io_stageOutputs_offloadGet2_state_isDefect           ), //i
    .io_rightVertexInput_offloadGet2_state_grown          (vertices_3_io_stageOutputs_offloadGet2_state_grown[1:0]         ), //i
    .io_rightVertexInput_offloadGet2_message_valid        (vertices_3_io_stageOutputs_offloadGet2_message_valid            ), //i
    .io_rightVertexInput_offloadGet2_message_instruction  (vertices_3_io_stageOutputs_offloadGet2_message_instruction[11:0]), //i
    .io_rightVertexInput_offloadGet2_message_isReset      (vertices_3_io_stageOutputs_offloadGet2_message_isReset          ), //i
    .io_rightVertexInput_offloadGet3_state_speed          (vertices_3_io_stageOutputs_offloadGet3_state_speed[1:0]         ), //i
    .io_rightVertexInput_offloadGet3_state_node           (vertices_3_io_stageOutputs_offloadGet3_state_node[4:0]          ), //i
    .io_rightVertexInput_offloadGet3_state_root           (vertices_3_io_stageOutputs_offloadGet3_state_root[4:0]          ), //i
    .io_rightVertexInput_offloadGet3_state_isVirtual      (vertices_3_io_stageOutputs_offloadGet3_state_isVirtual          ), //i
    .io_rightVertexInput_offloadGet3_state_isDefect       (vertices_3_io_stageOutputs_offloadGet3_state_isDefect           ), //i
    .io_rightVertexInput_offloadGet3_state_grown          (vertices_3_io_stageOutputs_offloadGet3_state_grown[1:0]         ), //i
    .io_rightVertexInput_offloadGet3_message_valid        (vertices_3_io_stageOutputs_offloadGet3_message_valid            ), //i
    .io_rightVertexInput_offloadGet3_message_instruction  (vertices_3_io_stageOutputs_offloadGet3_message_instruction[11:0]), //i
    .io_rightVertexInput_offloadGet3_message_isReset      (vertices_3_io_stageOutputs_offloadGet3_message_isReset          ), //i
    .io_rightVertexInput_offloadGet3_isUniqueTight        (vertices_3_io_stageOutputs_offloadGet3_isUniqueTight            ), //i
    .io_rightVertexInput_offloadGet3_isIsolated           (vertices_3_io_stageOutputs_offloadGet3_isIsolated               ), //i
    .io_rightVertexInput_offloadGet4_state_speed          (vertices_3_io_stageOutputs_offloadGet4_state_speed[1:0]         ), //i
    .io_rightVertexInput_offloadGet4_state_node           (vertices_3_io_stageOutputs_offloadGet4_state_node[4:0]          ), //i
    .io_rightVertexInput_offloadGet4_state_root           (vertices_3_io_stageOutputs_offloadGet4_state_root[4:0]          ), //i
    .io_rightVertexInput_offloadGet4_state_isVirtual      (vertices_3_io_stageOutputs_offloadGet4_state_isVirtual          ), //i
    .io_rightVertexInput_offloadGet4_state_isDefect       (vertices_3_io_stageOutputs_offloadGet4_state_isDefect           ), //i
    .io_rightVertexInput_offloadGet4_state_grown          (vertices_3_io_stageOutputs_offloadGet4_state_grown[1:0]         ), //i
    .io_rightVertexInput_offloadGet4_message_valid        (vertices_3_io_stageOutputs_offloadGet4_message_valid            ), //i
    .io_rightVertexInput_offloadGet4_message_instruction  (vertices_3_io_stageOutputs_offloadGet4_message_instruction[11:0]), //i
    .io_rightVertexInput_offloadGet4_message_isReset      (vertices_3_io_stageOutputs_offloadGet4_message_isReset          ), //i
    .io_rightVertexInput_executeGet_state_speed           (vertices_3_io_stageOutputs_executeGet_state_speed[1:0]          ), //i
    .io_rightVertexInput_executeGet_state_node            (vertices_3_io_stageOutputs_executeGet_state_node[4:0]           ), //i
    .io_rightVertexInput_executeGet_state_root            (vertices_3_io_stageOutputs_executeGet_state_root[4:0]           ), //i
    .io_rightVertexInput_executeGet_state_isVirtual       (vertices_3_io_stageOutputs_executeGet_state_isVirtual           ), //i
    .io_rightVertexInput_executeGet_state_isDefect        (vertices_3_io_stageOutputs_executeGet_state_isDefect            ), //i
    .io_rightVertexInput_executeGet_state_grown           (vertices_3_io_stageOutputs_executeGet_state_grown[1:0]          ), //i
    .io_rightVertexInput_executeGet_message_valid         (vertices_3_io_stageOutputs_executeGet_message_valid             ), //i
    .io_rightVertexInput_executeGet_message_instruction   (vertices_3_io_stageOutputs_executeGet_message_instruction[11:0] ), //i
    .io_rightVertexInput_executeGet_message_isReset       (vertices_3_io_stageOutputs_executeGet_message_isReset           ), //i
    .io_rightVertexInput_executeGet_isStalled             (vertices_3_io_stageOutputs_executeGet_isStalled                 ), //i
    .io_rightVertexInput_executeGet2_state_speed          (vertices_3_io_stageOutputs_executeGet2_state_speed[1:0]         ), //i
    .io_rightVertexInput_executeGet2_state_node           (vertices_3_io_stageOutputs_executeGet2_state_node[4:0]          ), //i
    .io_rightVertexInput_executeGet2_state_root           (vertices_3_io_stageOutputs_executeGet2_state_root[4:0]          ), //i
    .io_rightVertexInput_executeGet2_state_isVirtual      (vertices_3_io_stageOutputs_executeGet2_state_isVirtual          ), //i
    .io_rightVertexInput_executeGet2_state_isDefect       (vertices_3_io_stageOutputs_executeGet2_state_isDefect           ), //i
    .io_rightVertexInput_executeGet2_state_grown          (vertices_3_io_stageOutputs_executeGet2_state_grown[1:0]         ), //i
    .io_rightVertexInput_executeGet2_isStalled            (vertices_3_io_stageOutputs_executeGet2_isStalled                ), //i
    .io_rightVertexInput_executeGet2_compact_valid        (vertices_3_io_stageOutputs_executeGet2_compact_valid            ), //i
    .io_rightVertexInput_executeGet2_compact_isReset      (vertices_3_io_stageOutputs_executeGet2_compact_isReset          ), //i
    .io_rightVertexInput_executeGet3_state_speed          (vertices_3_io_stageOutputs_executeGet3_state_speed[1:0]         ), //i
    .io_rightVertexInput_executeGet3_state_node           (vertices_3_io_stageOutputs_executeGet3_state_node[4:0]          ), //i
    .io_rightVertexInput_executeGet3_state_root           (vertices_3_io_stageOutputs_executeGet3_state_root[4:0]          ), //i
    .io_rightVertexInput_executeGet3_state_isVirtual      (vertices_3_io_stageOutputs_executeGet3_state_isVirtual          ), //i
    .io_rightVertexInput_executeGet3_state_isDefect       (vertices_3_io_stageOutputs_executeGet3_state_isDefect           ), //i
    .io_rightVertexInput_executeGet3_state_grown          (vertices_3_io_stageOutputs_executeGet3_state_grown[1:0]         ), //i
    .io_rightVertexInput_executeGet3_isStalled            (vertices_3_io_stageOutputs_executeGet3_isStalled                ), //i
    .io_rightVertexInput_executeGet3_compact_valid        (vertices_3_io_stageOutputs_executeGet3_compact_valid            ), //i
    .io_rightVertexInput_executeGet3_compact_isReset      (vertices_3_io_stageOutputs_executeGet3_compact_isReset          ), //i
    .io_rightVertexInput_updateGet_state_speed            (vertices_3_io_stageOutputs_updateGet_state_speed[1:0]           ), //i
    .io_rightVertexInput_updateGet_state_node             (vertices_3_io_stageOutputs_updateGet_state_node[4:0]            ), //i
    .io_rightVertexInput_updateGet_state_root             (vertices_3_io_stageOutputs_updateGet_state_root[4:0]            ), //i
    .io_rightVertexInput_updateGet_state_isVirtual        (vertices_3_io_stageOutputs_updateGet_state_isVirtual            ), //i
    .io_rightVertexInput_updateGet_state_isDefect         (vertices_3_io_stageOutputs_updateGet_state_isDefect             ), //i
    .io_rightVertexInput_updateGet_state_grown            (vertices_3_io_stageOutputs_updateGet_state_grown[1:0]           ), //i
    .io_rightVertexInput_updateGet_isStalled              (vertices_3_io_stageOutputs_updateGet_isStalled                  ), //i
    .io_rightVertexInput_updateGet_compact_valid          (vertices_3_io_stageOutputs_updateGet_compact_valid              ), //i
    .io_rightVertexInput_updateGet_compact_isReset        (vertices_3_io_stageOutputs_updateGet_compact_isReset            ), //i
    .io_rightVertexInput_updateGet_propagatingPeer_valid  (vertices_3_io_stageOutputs_updateGet_propagatingPeer_valid      ), //i
    .io_rightVertexInput_updateGet_propagatingPeer_node   (vertices_3_io_stageOutputs_updateGet_propagatingPeer_node[4:0]  ), //i
    .io_rightVertexInput_updateGet_propagatingPeer_root   (vertices_3_io_stageOutputs_updateGet_propagatingPeer_root[4:0]  ), //i
    .io_rightVertexInput_updateGet2_state_speed           (vertices_3_io_stageOutputs_updateGet2_state_speed[1:0]          ), //i
    .io_rightVertexInput_updateGet2_state_node            (vertices_3_io_stageOutputs_updateGet2_state_node[4:0]           ), //i
    .io_rightVertexInput_updateGet2_state_root            (vertices_3_io_stageOutputs_updateGet2_state_root[4:0]           ), //i
    .io_rightVertexInput_updateGet2_state_isVirtual       (vertices_3_io_stageOutputs_updateGet2_state_isVirtual           ), //i
    .io_rightVertexInput_updateGet2_state_isDefect        (vertices_3_io_stageOutputs_updateGet2_state_isDefect            ), //i
    .io_rightVertexInput_updateGet2_state_grown           (vertices_3_io_stageOutputs_updateGet2_state_grown[1:0]          ), //i
    .io_rightVertexInput_updateGet2_isStalled             (vertices_3_io_stageOutputs_updateGet2_isStalled                 ), //i
    .io_rightVertexInput_updateGet2_compact_valid         (vertices_3_io_stageOutputs_updateGet2_compact_valid             ), //i
    .io_rightVertexInput_updateGet2_compact_isReset       (vertices_3_io_stageOutputs_updateGet2_compact_isReset           ), //i
    .io_rightVertexInput_updateGet2_propagatingPeer_valid (vertices_3_io_stageOutputs_updateGet2_propagatingPeer_valid     ), //i
    .io_rightVertexInput_updateGet2_propagatingPeer_node  (vertices_3_io_stageOutputs_updateGet2_propagatingPeer_node[4:0] ), //i
    .io_rightVertexInput_updateGet2_propagatingPeer_root  (vertices_3_io_stageOutputs_updateGet2_propagatingPeer_root[4:0] ), //i
    .io_rightVertexInput_updateGet3_state_speed           (vertices_3_io_stageOutputs_updateGet3_state_speed[1:0]          ), //i
    .io_rightVertexInput_updateGet3_state_node            (vertices_3_io_stageOutputs_updateGet3_state_node[4:0]           ), //i
    .io_rightVertexInput_updateGet3_state_root            (vertices_3_io_stageOutputs_updateGet3_state_root[4:0]           ), //i
    .io_rightVertexInput_updateGet3_state_isVirtual       (vertices_3_io_stageOutputs_updateGet3_state_isVirtual           ), //i
    .io_rightVertexInput_updateGet3_state_isDefect        (vertices_3_io_stageOutputs_updateGet3_state_isDefect            ), //i
    .io_rightVertexInput_updateGet3_state_grown           (vertices_3_io_stageOutputs_updateGet3_state_grown[1:0]          ), //i
    .io_rightVertexInput_updateGet3_shadow_speed          (vertices_3_io_stageOutputs_updateGet3_shadow_speed[1:0]         ), //i
    .io_rightVertexInput_updateGet3_shadow_node           (vertices_3_io_stageOutputs_updateGet3_shadow_node[4:0]          ), //i
    .io_rightVertexInput_updateGet3_shadow_root           (vertices_3_io_stageOutputs_updateGet3_shadow_root[4:0]          ), //i
    .io_rightVertexInput_updateGet3_compact_valid         (vertices_3_io_stageOutputs_updateGet3_compact_valid             ), //i
    .io_rightVertexInput_updateGet3_compact_isReset       (vertices_3_io_stageOutputs_updateGet3_compact_isReset           ), //i
    .io_maxGrowable_length                                (edges_2_io_maxGrowable_length[1:0]                              ), //o
    .io_conflict_node1                                    (edges_2_io_conflict_node1[4:0]                                  ), //o
    .io_conflict_node2                                    (edges_2_io_conflict_node2[4:0]                                  ), //o
    .io_conflict_touch1                                   (edges_2_io_conflict_touch1[4:0]                                 ), //o
    .io_conflict_touch2                                   (edges_2_io_conflict_touch2[4:0]                                 ), //o
    .io_conflict_vertex1                                  (edges_2_io_conflict_vertex1[4:0]                                ), //o
    .io_conflict_vertex2                                  (edges_2_io_conflict_vertex2[4:0]                                ), //o
    .io_conflict_valid                                    (edges_2_io_conflict_valid                                       )  //o
  );
  assign broadcastMessage_instruction = io_message_instruction;
  assign broadcastMessage_valid = io_message_valid;
  assign broadcastMessage_isReset = (((io_message_instruction[1 : 0] == 2'b00) && (io_message_instruction[2] == 1'b1)) && (io_message_instruction[5 : 3] == 3'b100));
  assign maxGrowableConvergcastTree_0_length = vertices_0_io_maxGrowable_length;
  assign maxGrowableConvergcastTree_1_length = vertices_1_io_maxGrowable_length;
  assign maxGrowableConvergcastTree_2_length = vertices_2_io_maxGrowable_length;
  assign maxGrowableConvergcastTree_3_length = vertices_3_io_maxGrowable_length;
  assign maxGrowableConvergcastTree_4_length = edges_0_io_maxGrowable_length;
  assign maxGrowableConvergcastTree_5_length = edges_1_io_maxGrowable_length;
  assign maxGrowableConvergcastTree_6_length = edges_2_io_maxGrowable_length;
  assign when_DistributedDual_l103 = (maxGrowableConvergcastTree_3_length < maxGrowableConvergcastTree_6_length);
  always @(*) begin
    if(when_DistributedDual_l103) begin
      maxGrowableConvergcastTree_7_length = maxGrowableConvergcastTree_3_length;
    end else begin
      maxGrowableConvergcastTree_7_length = maxGrowableConvergcastTree_6_length;
    end
  end

  assign when_DistributedDual_l103_1 = (maxGrowableConvergcastTree_0_length < maxGrowableConvergcastTree_4_length);
  always @(*) begin
    if(when_DistributedDual_l103_1) begin
      maxGrowableConvergcastTree_8_length = maxGrowableConvergcastTree_0_length;
    end else begin
      maxGrowableConvergcastTree_8_length = maxGrowableConvergcastTree_4_length;
    end
  end

  assign when_DistributedDual_l103_2 = (maxGrowableConvergcastTree_1_length < maxGrowableConvergcastTree_5_length);
  always @(*) begin
    if(when_DistributedDual_l103_2) begin
      maxGrowableConvergcastTree_9_length = maxGrowableConvergcastTree_1_length;
    end else begin
      maxGrowableConvergcastTree_9_length = maxGrowableConvergcastTree_5_length;
    end
  end

  assign when_DistributedDual_l103_3 = (maxGrowableConvergcastTree_7_length < maxGrowableConvergcastTree_8_length);
  always @(*) begin
    if(when_DistributedDual_l103_3) begin
      maxGrowableConvergcastTree_10_length = maxGrowableConvergcastTree_7_length;
    end else begin
      maxGrowableConvergcastTree_10_length = maxGrowableConvergcastTree_8_length;
    end
  end

  assign when_DistributedDual_l103_4 = (maxGrowableConvergcastTree_9_length < maxGrowableConvergcastTree_2_length);
  always @(*) begin
    if(when_DistributedDual_l103_4) begin
      maxGrowableConvergcastTree_11_length = maxGrowableConvergcastTree_9_length;
    end else begin
      maxGrowableConvergcastTree_11_length = maxGrowableConvergcastTree_2_length;
    end
  end

  assign when_DistributedDual_l103_5 = (maxGrowableConvergcastTree_10_length < maxGrowableConvergcastTree_11_length);
  always @(*) begin
    if(when_DistributedDual_l103_5) begin
      maxGrowableConvergcastTree_12_length = maxGrowableConvergcastTree_10_length;
    end else begin
      maxGrowableConvergcastTree_12_length = maxGrowableConvergcastTree_11_length;
    end
  end

  assign io_maxGrowable_length = selectedMaxGrowable_length;
  assign conflictConvergecastTree_0_node1 = edges_0_io_conflict_node1;
  assign conflictConvergecastTree_0_node2 = edges_0_io_conflict_node2;
  assign conflictConvergecastTree_0_touch1 = edges_0_io_conflict_touch1;
  assign conflictConvergecastTree_0_touch2 = edges_0_io_conflict_touch2;
  assign conflictConvergecastTree_0_vertex1 = edges_0_io_conflict_vertex1;
  assign conflictConvergecastTree_0_vertex2 = edges_0_io_conflict_vertex2;
  assign conflictConvergecastTree_0_valid = edges_0_io_conflict_valid;
  assign conflictConvergecastTree_1_node1 = edges_1_io_conflict_node1;
  assign conflictConvergecastTree_1_node2 = edges_1_io_conflict_node2;
  assign conflictConvergecastTree_1_touch1 = edges_1_io_conflict_touch1;
  assign conflictConvergecastTree_1_touch2 = edges_1_io_conflict_touch2;
  assign conflictConvergecastTree_1_vertex1 = edges_1_io_conflict_vertex1;
  assign conflictConvergecastTree_1_vertex2 = edges_1_io_conflict_vertex2;
  assign conflictConvergecastTree_1_valid = edges_1_io_conflict_valid;
  assign conflictConvergecastTree_2_node1 = edges_2_io_conflict_node1;
  assign conflictConvergecastTree_2_node2 = edges_2_io_conflict_node2;
  assign conflictConvergecastTree_2_touch1 = edges_2_io_conflict_touch1;
  assign conflictConvergecastTree_2_touch2 = edges_2_io_conflict_touch2;
  assign conflictConvergecastTree_2_vertex1 = edges_2_io_conflict_vertex1;
  assign conflictConvergecastTree_2_vertex2 = edges_2_io_conflict_vertex2;
  assign conflictConvergecastTree_2_valid = edges_2_io_conflict_valid;
  always @(*) begin
    if(conflictConvergecastTree_0_valid) begin
      conflictConvergecastTree_3_node1 = conflictConvergecastTree_0_node1;
    end else begin
      conflictConvergecastTree_3_node1 = conflictConvergecastTree_1_node1;
    end
  end

  always @(*) begin
    if(conflictConvergecastTree_0_valid) begin
      conflictConvergecastTree_3_node2 = conflictConvergecastTree_0_node2;
    end else begin
      conflictConvergecastTree_3_node2 = conflictConvergecastTree_1_node2;
    end
  end

  always @(*) begin
    if(conflictConvergecastTree_0_valid) begin
      conflictConvergecastTree_3_touch1 = conflictConvergecastTree_0_touch1;
    end else begin
      conflictConvergecastTree_3_touch1 = conflictConvergecastTree_1_touch1;
    end
  end

  always @(*) begin
    if(conflictConvergecastTree_0_valid) begin
      conflictConvergecastTree_3_touch2 = conflictConvergecastTree_0_touch2;
    end else begin
      conflictConvergecastTree_3_touch2 = conflictConvergecastTree_1_touch2;
    end
  end

  always @(*) begin
    if(conflictConvergecastTree_0_valid) begin
      conflictConvergecastTree_3_vertex1 = conflictConvergecastTree_0_vertex1;
    end else begin
      conflictConvergecastTree_3_vertex1 = conflictConvergecastTree_1_vertex1;
    end
  end

  always @(*) begin
    if(conflictConvergecastTree_0_valid) begin
      conflictConvergecastTree_3_vertex2 = conflictConvergecastTree_0_vertex2;
    end else begin
      conflictConvergecastTree_3_vertex2 = conflictConvergecastTree_1_vertex2;
    end
  end

  always @(*) begin
    if(conflictConvergecastTree_0_valid) begin
      conflictConvergecastTree_3_valid = conflictConvergecastTree_0_valid;
    end else begin
      conflictConvergecastTree_3_valid = conflictConvergecastTree_1_valid;
    end
  end

  always @(*) begin
    if(conflictConvergecastTree_3_valid) begin
      conflictConvergecastTree_4_node1 = conflictConvergecastTree_3_node1;
    end else begin
      conflictConvergecastTree_4_node1 = conflictConvergecastTree_2_node1;
    end
  end

  always @(*) begin
    if(conflictConvergecastTree_3_valid) begin
      conflictConvergecastTree_4_node2 = conflictConvergecastTree_3_node2;
    end else begin
      conflictConvergecastTree_4_node2 = conflictConvergecastTree_2_node2;
    end
  end

  always @(*) begin
    if(conflictConvergecastTree_3_valid) begin
      conflictConvergecastTree_4_touch1 = conflictConvergecastTree_3_touch1;
    end else begin
      conflictConvergecastTree_4_touch1 = conflictConvergecastTree_2_touch1;
    end
  end

  always @(*) begin
    if(conflictConvergecastTree_3_valid) begin
      conflictConvergecastTree_4_touch2 = conflictConvergecastTree_3_touch2;
    end else begin
      conflictConvergecastTree_4_touch2 = conflictConvergecastTree_2_touch2;
    end
  end

  always @(*) begin
    if(conflictConvergecastTree_3_valid) begin
      conflictConvergecastTree_4_vertex1 = conflictConvergecastTree_3_vertex1;
    end else begin
      conflictConvergecastTree_4_vertex1 = conflictConvergecastTree_2_vertex1;
    end
  end

  always @(*) begin
    if(conflictConvergecastTree_3_valid) begin
      conflictConvergecastTree_4_vertex2 = conflictConvergecastTree_3_vertex2;
    end else begin
      conflictConvergecastTree_4_vertex2 = conflictConvergecastTree_2_vertex2;
    end
  end

  always @(*) begin
    if(conflictConvergecastTree_3_valid) begin
      conflictConvergecastTree_4_valid = conflictConvergecastTree_3_valid;
    end else begin
      conflictConvergecastTree_4_valid = conflictConvergecastTree_2_valid;
    end
  end

  assign io_conflict_valid = convergecastedConflict_valid;
  assign io_conflict_node1 = convergecastedConflict_node1;
  assign io_conflict_node2 = convergecastedConflict_node2;
  assign io_conflict_touch1 = convergecastedConflict_touch1;
  assign io_conflict_touch2 = convergecastedConflict_touch2;
  assign io_conflict_vertex1 = convergecastedConflict_vertex1;
  assign io_conflict_vertex2 = convergecastedConflict_vertex2;
  always @(posedge clk) begin
    selectedMaxGrowable_length <= maxGrowableConvergcastTree_12_length;
    convergecastedConflict_node1 <= conflictConvergecastTree_4_node1;
    convergecastedConflict_node2 <= conflictConvergecastTree_4_node2;
    convergecastedConflict_touch1 <= conflictConvergecastTree_4_touch1;
    convergecastedConflict_touch2 <= conflictConvergecastTree_4_touch2;
    convergecastedConflict_vertex1 <= conflictConvergecastTree_4_vertex1;
    convergecastedConflict_vertex2 <= conflictConvergecastTree_4_vertex2;
    convergecastedConflict_valid <= conflictConvergecastTree_4_valid;
  end


endmodule

module Edge_3 (
  input               io_message_valid,
  input      [11:0]   io_message_instruction,
  input               io_message_isReset,
  output     [1:0]    io_stageOutputs_offloadGet_state_weight,
  output              io_stageOutputs_offloadGet_compact_valid,
  output              io_stageOutputs_offloadGet_compact_isReset,
  output     [1:0]    io_stageOutputs_offloadGet2_state_weight,
  output              io_stageOutputs_offloadGet2_isTight,
  output              io_stageOutputs_offloadGet2_isTightExFusion,
  output              io_stageOutputs_offloadGet2_compact_valid,
  output              io_stageOutputs_offloadGet2_compact_isReset,
  output     [1:0]    io_stageOutputs_offloadGet3_state_weight,
  output              io_stageOutputs_offloadGet3_isTight,
  output              io_stageOutputs_offloadGet3_compact_valid,
  output              io_stageOutputs_offloadGet3_compact_isReset,
  output     [1:0]    io_stageOutputs_offloadGet4_state_weight,
  output              io_stageOutputs_offloadGet4_compact_valid,
  output              io_stageOutputs_offloadGet4_compact_isReset,
  output     [1:0]    io_stageOutputs_executeGet_state_weight,
  output              io_stageOutputs_executeGet_compact_valid,
  output              io_stageOutputs_executeGet_compact_isReset,
  output     [1:0]    io_stageOutputs_executeGet2_state_weight,
  output              io_stageOutputs_executeGet2_compact_valid,
  output              io_stageOutputs_executeGet2_compact_isReset,
  output     [1:0]    io_stageOutputs_executeGet3_state_weight,
  output              io_stageOutputs_executeGet3_isTight,
  output              io_stageOutputs_executeGet3_compact_valid,
  output              io_stageOutputs_executeGet3_compact_isReset,
  output     [1:0]    io_stageOutputs_updateGet_state_weight,
  output     [1:0]    io_stageOutputs_updateGet_remaining,
  output              io_stageOutputs_updateGet_compact_valid,
  output              io_stageOutputs_updateGet_compact_isReset,
  output     [1:0]    io_stageOutputs_updateGet2_state_weight,
  output     [1:0]    io_stageOutputs_updateGet2_remaining,
  output              io_stageOutputs_updateGet2_compact_valid,
  output              io_stageOutputs_updateGet2_compact_isReset,
  output     [1:0]    io_stageOutputs_updateGet3_state_weight,
  output     [1:0]    io_stageOutputs_updateGet3_remaining,
  output              io_stageOutputs_updateGet3_compact_valid,
  output              io_stageOutputs_updateGet3_compact_isReset,
  input      [1:0]    io_leftVertexInput_offloadGet_state_speed,
  input      [4:0]    io_leftVertexInput_offloadGet_state_node,
  input      [4:0]    io_leftVertexInput_offloadGet_state_root,
  input               io_leftVertexInput_offloadGet_state_isVirtual,
  input               io_leftVertexInput_offloadGet_state_isDefect,
  input      [1:0]    io_leftVertexInput_offloadGet_state_grown,
  input               io_leftVertexInput_offloadGet_message_valid,
  input      [11:0]   io_leftVertexInput_offloadGet_message_instruction,
  input               io_leftVertexInput_offloadGet_message_isReset,
  input      [1:0]    io_leftVertexInput_offloadGet2_state_speed,
  input      [4:0]    io_leftVertexInput_offloadGet2_state_node,
  input      [4:0]    io_leftVertexInput_offloadGet2_state_root,
  input               io_leftVertexInput_offloadGet2_state_isVirtual,
  input               io_leftVertexInput_offloadGet2_state_isDefect,
  input      [1:0]    io_leftVertexInput_offloadGet2_state_grown,
  input               io_leftVertexInput_offloadGet2_message_valid,
  input      [11:0]   io_leftVertexInput_offloadGet2_message_instruction,
  input               io_leftVertexInput_offloadGet2_message_isReset,
  input      [1:0]    io_leftVertexInput_offloadGet3_state_speed,
  input      [4:0]    io_leftVertexInput_offloadGet3_state_node,
  input      [4:0]    io_leftVertexInput_offloadGet3_state_root,
  input               io_leftVertexInput_offloadGet3_state_isVirtual,
  input               io_leftVertexInput_offloadGet3_state_isDefect,
  input      [1:0]    io_leftVertexInput_offloadGet3_state_grown,
  input               io_leftVertexInput_offloadGet3_message_valid,
  input      [11:0]   io_leftVertexInput_offloadGet3_message_instruction,
  input               io_leftVertexInput_offloadGet3_message_isReset,
  input               io_leftVertexInput_offloadGet3_isUniqueTight,
  input               io_leftVertexInput_offloadGet3_isIsolated,
  input      [1:0]    io_leftVertexInput_offloadGet4_state_speed,
  input      [4:0]    io_leftVertexInput_offloadGet4_state_node,
  input      [4:0]    io_leftVertexInput_offloadGet4_state_root,
  input               io_leftVertexInput_offloadGet4_state_isVirtual,
  input               io_leftVertexInput_offloadGet4_state_isDefect,
  input      [1:0]    io_leftVertexInput_offloadGet4_state_grown,
  input               io_leftVertexInput_offloadGet4_message_valid,
  input      [11:0]   io_leftVertexInput_offloadGet4_message_instruction,
  input               io_leftVertexInput_offloadGet4_message_isReset,
  input      [1:0]    io_leftVertexInput_executeGet_state_speed,
  input      [4:0]    io_leftVertexInput_executeGet_state_node,
  input      [4:0]    io_leftVertexInput_executeGet_state_root,
  input               io_leftVertexInput_executeGet_state_isVirtual,
  input               io_leftVertexInput_executeGet_state_isDefect,
  input      [1:0]    io_leftVertexInput_executeGet_state_grown,
  input               io_leftVertexInput_executeGet_message_valid,
  input      [11:0]   io_leftVertexInput_executeGet_message_instruction,
  input               io_leftVertexInput_executeGet_message_isReset,
  input               io_leftVertexInput_executeGet_isStalled,
  input      [1:0]    io_leftVertexInput_executeGet2_state_speed,
  input      [4:0]    io_leftVertexInput_executeGet2_state_node,
  input      [4:0]    io_leftVertexInput_executeGet2_state_root,
  input               io_leftVertexInput_executeGet2_state_isVirtual,
  input               io_leftVertexInput_executeGet2_state_isDefect,
  input      [1:0]    io_leftVertexInput_executeGet2_state_grown,
  input               io_leftVertexInput_executeGet2_isStalled,
  input               io_leftVertexInput_executeGet2_compact_valid,
  input               io_leftVertexInput_executeGet2_compact_isReset,
  input      [1:0]    io_leftVertexInput_executeGet3_state_speed,
  input      [4:0]    io_leftVertexInput_executeGet3_state_node,
  input      [4:0]    io_leftVertexInput_executeGet3_state_root,
  input               io_leftVertexInput_executeGet3_state_isVirtual,
  input               io_leftVertexInput_executeGet3_state_isDefect,
  input      [1:0]    io_leftVertexInput_executeGet3_state_grown,
  input               io_leftVertexInput_executeGet3_isStalled,
  input               io_leftVertexInput_executeGet3_compact_valid,
  input               io_leftVertexInput_executeGet3_compact_isReset,
  input      [1:0]    io_leftVertexInput_updateGet_state_speed,
  input      [4:0]    io_leftVertexInput_updateGet_state_node,
  input      [4:0]    io_leftVertexInput_updateGet_state_root,
  input               io_leftVertexInput_updateGet_state_isVirtual,
  input               io_leftVertexInput_updateGet_state_isDefect,
  input      [1:0]    io_leftVertexInput_updateGet_state_grown,
  input               io_leftVertexInput_updateGet_isStalled,
  input               io_leftVertexInput_updateGet_compact_valid,
  input               io_leftVertexInput_updateGet_compact_isReset,
  input               io_leftVertexInput_updateGet_propagatingPeer_valid,
  input      [4:0]    io_leftVertexInput_updateGet_propagatingPeer_node,
  input      [4:0]    io_leftVertexInput_updateGet_propagatingPeer_root,
  input      [1:0]    io_leftVertexInput_updateGet2_state_speed,
  input      [4:0]    io_leftVertexInput_updateGet2_state_node,
  input      [4:0]    io_leftVertexInput_updateGet2_state_root,
  input               io_leftVertexInput_updateGet2_state_isVirtual,
  input               io_leftVertexInput_updateGet2_state_isDefect,
  input      [1:0]    io_leftVertexInput_updateGet2_state_grown,
  input               io_leftVertexInput_updateGet2_isStalled,
  input               io_leftVertexInput_updateGet2_compact_valid,
  input               io_leftVertexInput_updateGet2_compact_isReset,
  input               io_leftVertexInput_updateGet2_propagatingPeer_valid,
  input      [4:0]    io_leftVertexInput_updateGet2_propagatingPeer_node,
  input      [4:0]    io_leftVertexInput_updateGet2_propagatingPeer_root,
  input      [1:0]    io_leftVertexInput_updateGet3_state_speed,
  input      [4:0]    io_leftVertexInput_updateGet3_state_node,
  input      [4:0]    io_leftVertexInput_updateGet3_state_root,
  input               io_leftVertexInput_updateGet3_state_isVirtual,
  input               io_leftVertexInput_updateGet3_state_isDefect,
  input      [1:0]    io_leftVertexInput_updateGet3_state_grown,
  input      [1:0]    io_leftVertexInput_updateGet3_shadow_speed,
  input      [4:0]    io_leftVertexInput_updateGet3_shadow_node,
  input      [4:0]    io_leftVertexInput_updateGet3_shadow_root,
  input               io_leftVertexInput_updateGet3_compact_valid,
  input               io_leftVertexInput_updateGet3_compact_isReset,
  input      [1:0]    io_rightVertexInput_offloadGet_state_speed,
  input      [4:0]    io_rightVertexInput_offloadGet_state_node,
  input      [4:0]    io_rightVertexInput_offloadGet_state_root,
  input               io_rightVertexInput_offloadGet_state_isVirtual,
  input               io_rightVertexInput_offloadGet_state_isDefect,
  input      [1:0]    io_rightVertexInput_offloadGet_state_grown,
  input               io_rightVertexInput_offloadGet_message_valid,
  input      [11:0]   io_rightVertexInput_offloadGet_message_instruction,
  input               io_rightVertexInput_offloadGet_message_isReset,
  input      [1:0]    io_rightVertexInput_offloadGet2_state_speed,
  input      [4:0]    io_rightVertexInput_offloadGet2_state_node,
  input      [4:0]    io_rightVertexInput_offloadGet2_state_root,
  input               io_rightVertexInput_offloadGet2_state_isVirtual,
  input               io_rightVertexInput_offloadGet2_state_isDefect,
  input      [1:0]    io_rightVertexInput_offloadGet2_state_grown,
  input               io_rightVertexInput_offloadGet2_message_valid,
  input      [11:0]   io_rightVertexInput_offloadGet2_message_instruction,
  input               io_rightVertexInput_offloadGet2_message_isReset,
  input      [1:0]    io_rightVertexInput_offloadGet3_state_speed,
  input      [4:0]    io_rightVertexInput_offloadGet3_state_node,
  input      [4:0]    io_rightVertexInput_offloadGet3_state_root,
  input               io_rightVertexInput_offloadGet3_state_isVirtual,
  input               io_rightVertexInput_offloadGet3_state_isDefect,
  input      [1:0]    io_rightVertexInput_offloadGet3_state_grown,
  input               io_rightVertexInput_offloadGet3_message_valid,
  input      [11:0]   io_rightVertexInput_offloadGet3_message_instruction,
  input               io_rightVertexInput_offloadGet3_message_isReset,
  input               io_rightVertexInput_offloadGet3_isUniqueTight,
  input               io_rightVertexInput_offloadGet3_isIsolated,
  input      [1:0]    io_rightVertexInput_offloadGet4_state_speed,
  input      [4:0]    io_rightVertexInput_offloadGet4_state_node,
  input      [4:0]    io_rightVertexInput_offloadGet4_state_root,
  input               io_rightVertexInput_offloadGet4_state_isVirtual,
  input               io_rightVertexInput_offloadGet4_state_isDefect,
  input      [1:0]    io_rightVertexInput_offloadGet4_state_grown,
  input               io_rightVertexInput_offloadGet4_message_valid,
  input      [11:0]   io_rightVertexInput_offloadGet4_message_instruction,
  input               io_rightVertexInput_offloadGet4_message_isReset,
  input      [1:0]    io_rightVertexInput_executeGet_state_speed,
  input      [4:0]    io_rightVertexInput_executeGet_state_node,
  input      [4:0]    io_rightVertexInput_executeGet_state_root,
  input               io_rightVertexInput_executeGet_state_isVirtual,
  input               io_rightVertexInput_executeGet_state_isDefect,
  input      [1:0]    io_rightVertexInput_executeGet_state_grown,
  input               io_rightVertexInput_executeGet_message_valid,
  input      [11:0]   io_rightVertexInput_executeGet_message_instruction,
  input               io_rightVertexInput_executeGet_message_isReset,
  input               io_rightVertexInput_executeGet_isStalled,
  input      [1:0]    io_rightVertexInput_executeGet2_state_speed,
  input      [4:0]    io_rightVertexInput_executeGet2_state_node,
  input      [4:0]    io_rightVertexInput_executeGet2_state_root,
  input               io_rightVertexInput_executeGet2_state_isVirtual,
  input               io_rightVertexInput_executeGet2_state_isDefect,
  input      [1:0]    io_rightVertexInput_executeGet2_state_grown,
  input               io_rightVertexInput_executeGet2_isStalled,
  input               io_rightVertexInput_executeGet2_compact_valid,
  input               io_rightVertexInput_executeGet2_compact_isReset,
  input      [1:0]    io_rightVertexInput_executeGet3_state_speed,
  input      [4:0]    io_rightVertexInput_executeGet3_state_node,
  input      [4:0]    io_rightVertexInput_executeGet3_state_root,
  input               io_rightVertexInput_executeGet3_state_isVirtual,
  input               io_rightVertexInput_executeGet3_state_isDefect,
  input      [1:0]    io_rightVertexInput_executeGet3_state_grown,
  input               io_rightVertexInput_executeGet3_isStalled,
  input               io_rightVertexInput_executeGet3_compact_valid,
  input               io_rightVertexInput_executeGet3_compact_isReset,
  input      [1:0]    io_rightVertexInput_updateGet_state_speed,
  input      [4:0]    io_rightVertexInput_updateGet_state_node,
  input      [4:0]    io_rightVertexInput_updateGet_state_root,
  input               io_rightVertexInput_updateGet_state_isVirtual,
  input               io_rightVertexInput_updateGet_state_isDefect,
  input      [1:0]    io_rightVertexInput_updateGet_state_grown,
  input               io_rightVertexInput_updateGet_isStalled,
  input               io_rightVertexInput_updateGet_compact_valid,
  input               io_rightVertexInput_updateGet_compact_isReset,
  input               io_rightVertexInput_updateGet_propagatingPeer_valid,
  input      [4:0]    io_rightVertexInput_updateGet_propagatingPeer_node,
  input      [4:0]    io_rightVertexInput_updateGet_propagatingPeer_root,
  input      [1:0]    io_rightVertexInput_updateGet2_state_speed,
  input      [4:0]    io_rightVertexInput_updateGet2_state_node,
  input      [4:0]    io_rightVertexInput_updateGet2_state_root,
  input               io_rightVertexInput_updateGet2_state_isVirtual,
  input               io_rightVertexInput_updateGet2_state_isDefect,
  input      [1:0]    io_rightVertexInput_updateGet2_state_grown,
  input               io_rightVertexInput_updateGet2_isStalled,
  input               io_rightVertexInput_updateGet2_compact_valid,
  input               io_rightVertexInput_updateGet2_compact_isReset,
  input               io_rightVertexInput_updateGet2_propagatingPeer_valid,
  input      [4:0]    io_rightVertexInput_updateGet2_propagatingPeer_node,
  input      [4:0]    io_rightVertexInput_updateGet2_propagatingPeer_root,
  input      [1:0]    io_rightVertexInput_updateGet3_state_speed,
  input      [4:0]    io_rightVertexInput_updateGet3_state_node,
  input      [4:0]    io_rightVertexInput_updateGet3_state_root,
  input               io_rightVertexInput_updateGet3_state_isVirtual,
  input               io_rightVertexInput_updateGet3_state_isDefect,
  input      [1:0]    io_rightVertexInput_updateGet3_state_grown,
  input      [1:0]    io_rightVertexInput_updateGet3_shadow_speed,
  input      [4:0]    io_rightVertexInput_updateGet3_shadow_node,
  input      [4:0]    io_rightVertexInput_updateGet3_shadow_root,
  input               io_rightVertexInput_updateGet3_compact_valid,
  input               io_rightVertexInput_updateGet3_compact_isReset,
  output     [1:0]    io_maxGrowable_length,
  output     [4:0]    io_conflict_node1,
  output     [4:0]    io_conflict_node2,
  output     [4:0]    io_conflict_touch1,
  output     [4:0]    io_conflict_touch2,
  output     [4:0]    io_conflict_vertex1,
  output     [4:0]    io_conflict_vertex2,
  output              io_conflict_valid
);

  wire                offload2Area_edgeIsTight_io_isTight;
  wire                execute3Area_edgeIsTight_io_isTight;
  wire       [1:0]    updateArea_edgeRemaining_io_remaining;
  wire       [1:0]    edgeResponse_3_io_maxGrowable_length;
  wire       [4:0]    edgeResponse_3_io_conflict_node1;
  wire       [4:0]    edgeResponse_3_io_conflict_node2;
  wire       [4:0]    edgeResponse_3_io_conflict_touch1;
  wire       [4:0]    edgeResponse_3_io_conflict_touch2;
  wire       [4:0]    edgeResponse_3_io_conflict_vertex1;
  wire       [4:0]    edgeResponse_3_io_conflict_vertex2;
  wire                edgeResponse_3_io_conflict_valid;
  wire       [1:0]    stages_offloadSet_state_weight;
  wire                stages_offloadSet_compact_valid;
  wire                stages_offloadSet_compact_isReset;
  wire       [1:0]    stages_offloadGet_state_weight;
  wire                stages_offloadGet_compact_valid;
  wire                stages_offloadGet_compact_isReset;
  wire       [1:0]    stages_offloadSet2_state_weight;
  wire                stages_offloadSet2_isTight;
  wire                stages_offloadSet2_isTightExFusion;
  wire                stages_offloadSet2_compact_valid;
  wire                stages_offloadSet2_compact_isReset;
  wire       [1:0]    stages_offloadGet2_state_weight;
  wire                stages_offloadGet2_isTight;
  wire                stages_offloadGet2_isTightExFusion;
  wire                stages_offloadGet2_compact_valid;
  wire                stages_offloadGet2_compact_isReset;
  wire       [1:0]    stages_offloadSet3_state_weight;
  wire                stages_offloadSet3_isTight;
  wire                stages_offloadSet3_compact_valid;
  wire                stages_offloadSet3_compact_isReset;
  wire       [1:0]    stages_offloadGet3_state_weight;
  wire                stages_offloadGet3_isTight;
  wire                stages_offloadGet3_compact_valid;
  wire                stages_offloadGet3_compact_isReset;
  wire       [1:0]    stages_offloadSet4_state_weight;
  wire                stages_offloadSet4_compact_valid;
  wire                stages_offloadSet4_compact_isReset;
  wire       [1:0]    stages_offloadGet4_state_weight;
  wire                stages_offloadGet4_compact_valid;
  wire                stages_offloadGet4_compact_isReset;
  wire       [1:0]    stages_executeSet_state_weight;
  wire                stages_executeSet_compact_valid;
  wire                stages_executeSet_compact_isReset;
  wire       [1:0]    stages_executeGet_state_weight;
  wire                stages_executeGet_compact_valid;
  wire                stages_executeGet_compact_isReset;
  wire       [1:0]    stages_executeSet2_state_weight;
  wire                stages_executeSet2_compact_valid;
  wire                stages_executeSet2_compact_isReset;
  wire       [1:0]    stages_executeGet2_state_weight;
  wire                stages_executeGet2_compact_valid;
  wire                stages_executeGet2_compact_isReset;
  wire       [1:0]    stages_executeSet3_state_weight;
  wire                stages_executeSet3_isTight;
  wire                stages_executeSet3_compact_valid;
  wire                stages_executeSet3_compact_isReset;
  wire       [1:0]    stages_executeGet3_state_weight;
  wire                stages_executeGet3_isTight;
  wire                stages_executeGet3_compact_valid;
  wire                stages_executeGet3_compact_isReset;
  wire       [1:0]    stages_updateSet_state_weight;
  wire       [1:0]    stages_updateSet_remaining;
  wire                stages_updateSet_compact_valid;
  wire                stages_updateSet_compact_isReset;
  wire       [1:0]    stages_updateGet_state_weight;
  wire       [1:0]    stages_updateGet_remaining;
  wire                stages_updateGet_compact_valid;
  wire                stages_updateGet_compact_isReset;
  wire       [1:0]    stages_updateSet2_state_weight;
  wire       [1:0]    stages_updateSet2_remaining;
  wire                stages_updateSet2_compact_valid;
  wire                stages_updateSet2_compact_isReset;
  wire       [1:0]    stages_updateGet2_state_weight;
  wire       [1:0]    stages_updateGet2_remaining;
  wire                stages_updateGet2_compact_valid;
  wire                stages_updateGet2_compact_isReset;
  wire       [1:0]    stages_updateSet3_state_weight;
  wire       [1:0]    stages_updateSet3_remaining;
  wire                stages_updateSet3_compact_valid;
  wire                stages_updateSet3_compact_isReset;
  wire       [1:0]    stages_updateGet3_state_weight;
  wire       [1:0]    stages_updateGet3_remaining;
  wire                stages_updateGet3_compact_valid;
  wire                stages_updateGet3_compact_isReset;
  wire       [1:0]    fetchState_weight;
  wire                message_valid;
  wire       [11:0]   message_instruction;
  wire                message_isReset;
  wire                conditionedVertexIsVirtual;
  wire       [1:0]    offload2Weight;

  EdgeIsTight_4 offload2Area_edgeIsTight (
    .io_leftGrown  (io_leftVertexInput_offloadGet_state_grown[1:0] ), //i
    .io_rightGrown (io_rightVertexInput_offloadGet_state_grown[1:0]), //i
    .io_weight     (offload2Weight[1:0]                            ), //i
    .io_isTight    (offload2Area_edgeIsTight_io_isTight            )  //o
  );
  EdgeIsTight_4 execute3Area_edgeIsTight (
    .io_leftGrown  (io_leftVertexInput_executeGet2_state_grown[1:0] ), //i
    .io_rightGrown (io_rightVertexInput_executeGet2_state_grown[1:0]), //i
    .io_weight     (stages_executeGet2_state_weight[1:0]            ), //i
    .io_isTight    (execute3Area_edgeIsTight_io_isTight             )  //o
  );
  EdgeRemaining_2 updateArea_edgeRemaining (
    .io_leftGrown  (io_leftVertexInput_executeGet3_state_grown[1:0] ), //i
    .io_rightGrown (io_rightVertexInput_executeGet3_state_grown[1:0]), //i
    .io_weight     (stages_executeGet3_state_weight[1:0]            ), //i
    .io_remaining  (updateArea_edgeRemaining_io_remaining[1:0]      )  //o
  );
  EdgeResponse_2 edgeResponse_3 (
    .io_leftShadow_speed   (io_leftVertexInput_updateGet3_shadow_speed[1:0] ), //i
    .io_leftShadow_node    (io_leftVertexInput_updateGet3_shadow_node[4:0]  ), //i
    .io_leftShadow_root    (io_leftVertexInput_updateGet3_shadow_root[4:0]  ), //i
    .io_rightShadow_speed  (io_rightVertexInput_updateGet3_shadow_speed[1:0]), //i
    .io_rightShadow_node   (io_rightVertexInput_updateGet3_shadow_node[4:0] ), //i
    .io_rightShadow_root   (io_rightVertexInput_updateGet3_shadow_root[4:0] ), //i
    .io_leftIsVirtual      (io_leftVertexInput_updateGet3_state_isVirtual   ), //i
    .io_rightIsVirtual     (io_rightVertexInput_updateGet3_state_isVirtual  ), //i
    .io_leftVertex         (5'h00                                           ), //i
    .io_rightVertex        (5'h03                                           ), //i
    .io_remaining          (stages_updateGet3_remaining[1:0]                ), //i
    .io_maxGrowable_length (edgeResponse_3_io_maxGrowable_length[1:0]       ), //o
    .io_conflict_node1     (edgeResponse_3_io_conflict_node1[4:0]           ), //o
    .io_conflict_node2     (edgeResponse_3_io_conflict_node2[4:0]           ), //o
    .io_conflict_touch1    (edgeResponse_3_io_conflict_touch1[4:0]          ), //o
    .io_conflict_touch2    (edgeResponse_3_io_conflict_touch2[4:0]          ), //o
    .io_conflict_vertex1   (edgeResponse_3_io_conflict_vertex1[4:0]         ), //o
    .io_conflict_vertex2   (edgeResponse_3_io_conflict_vertex2[4:0]         ), //o
    .io_conflict_valid     (edgeResponse_3_io_conflict_valid                )  //o
  );
  assign io_stageOutputs_offloadGet_state_weight = stages_offloadGet_state_weight;
  assign io_stageOutputs_offloadGet_compact_valid = stages_offloadGet_compact_valid;
  assign io_stageOutputs_offloadGet_compact_isReset = stages_offloadGet_compact_isReset;
  assign io_stageOutputs_offloadGet2_state_weight = stages_offloadGet2_state_weight;
  assign io_stageOutputs_offloadGet2_isTight = stages_offloadGet2_isTight;
  assign io_stageOutputs_offloadGet2_isTightExFusion = stages_offloadGet2_isTightExFusion;
  assign io_stageOutputs_offloadGet2_compact_valid = stages_offloadGet2_compact_valid;
  assign io_stageOutputs_offloadGet2_compact_isReset = stages_offloadGet2_compact_isReset;
  assign io_stageOutputs_offloadGet3_state_weight = stages_offloadGet3_state_weight;
  assign io_stageOutputs_offloadGet3_isTight = stages_offloadGet3_isTight;
  assign io_stageOutputs_offloadGet3_compact_valid = stages_offloadGet3_compact_valid;
  assign io_stageOutputs_offloadGet3_compact_isReset = stages_offloadGet3_compact_isReset;
  assign io_stageOutputs_offloadGet4_state_weight = stages_offloadGet4_state_weight;
  assign io_stageOutputs_offloadGet4_compact_valid = stages_offloadGet4_compact_valid;
  assign io_stageOutputs_offloadGet4_compact_isReset = stages_offloadGet4_compact_isReset;
  assign io_stageOutputs_executeGet_state_weight = stages_executeGet_state_weight;
  assign io_stageOutputs_executeGet_compact_valid = stages_executeGet_compact_valid;
  assign io_stageOutputs_executeGet_compact_isReset = stages_executeGet_compact_isReset;
  assign io_stageOutputs_executeGet2_state_weight = stages_executeGet2_state_weight;
  assign io_stageOutputs_executeGet2_compact_valid = stages_executeGet2_compact_valid;
  assign io_stageOutputs_executeGet2_compact_isReset = stages_executeGet2_compact_isReset;
  assign io_stageOutputs_executeGet3_state_weight = stages_executeGet3_state_weight;
  assign io_stageOutputs_executeGet3_isTight = stages_executeGet3_isTight;
  assign io_stageOutputs_executeGet3_compact_valid = stages_executeGet3_compact_valid;
  assign io_stageOutputs_executeGet3_compact_isReset = stages_executeGet3_compact_isReset;
  assign io_stageOutputs_updateGet_state_weight = stages_updateGet_state_weight;
  assign io_stageOutputs_updateGet_remaining = stages_updateGet_remaining;
  assign io_stageOutputs_updateGet_compact_valid = stages_updateGet_compact_valid;
  assign io_stageOutputs_updateGet_compact_isReset = stages_updateGet_compact_isReset;
  assign io_stageOutputs_updateGet2_state_weight = stages_updateGet2_state_weight;
  assign io_stageOutputs_updateGet2_remaining = stages_updateGet2_remaining;
  assign io_stageOutputs_updateGet2_compact_valid = stages_updateGet2_compact_valid;
  assign io_stageOutputs_updateGet2_compact_isReset = stages_updateGet2_compact_isReset;
  assign io_stageOutputs_updateGet3_state_weight = stages_updateGet3_state_weight;
  assign io_stageOutputs_updateGet3_remaining = stages_updateGet3_remaining;
  assign io_stageOutputs_updateGet3_compact_valid = stages_updateGet3_compact_valid;
  assign io_stageOutputs_updateGet3_compact_isReset = stages_updateGet3_compact_isReset;
  assign fetchState_weight = 2'b10;
  assign message_valid = io_message_valid;
  assign message_instruction = io_message_instruction;
  assign message_isReset = io_message_isReset;
  assign stages_offloadSet_state_weight = fetchState_weight;
  assign stages_offloadSet_compact_valid = message_valid;
  assign stages_offloadSet_compact_isReset = message_isReset;
  assign stages_offloadSet2_state_weight = stages_offloadGet_state_weight;
  assign stages_offloadSet2_compact_valid = stages_offloadGet_compact_valid;
  assign stages_offloadSet2_compact_isReset = stages_offloadGet_compact_isReset;
  assign conditionedVertexIsVirtual = 1'b0;
  assign offload2Weight = stages_offloadGet_state_weight;
  assign stages_offloadSet2_isTight = offload2Area_edgeIsTight_io_isTight;
  assign stages_offloadSet2_isTightExFusion = offload2Area_edgeIsTight_io_isTight;
  assign stages_offloadSet3_state_weight = stages_offloadGet2_state_weight;
  assign stages_offloadSet3_isTight = stages_offloadGet2_isTight;
  assign stages_offloadSet3_compact_valid = stages_offloadGet2_compact_valid;
  assign stages_offloadSet3_compact_isReset = stages_offloadGet2_compact_isReset;
  assign stages_offloadSet4_state_weight = stages_offloadGet3_state_weight;
  assign stages_offloadSet4_compact_valid = stages_offloadGet3_compact_valid;
  assign stages_offloadSet4_compact_isReset = stages_offloadGet3_compact_isReset;
  assign stages_executeSet_state_weight = stages_offloadGet4_state_weight;
  assign stages_executeSet_compact_valid = stages_offloadGet4_compact_valid;
  assign stages_executeSet_compact_isReset = stages_offloadGet4_compact_isReset;
  assign stages_executeSet2_state_weight = stages_executeGet_state_weight;
  assign stages_executeSet2_compact_valid = stages_executeGet_compact_valid;
  assign stages_executeSet2_compact_isReset = stages_executeGet_compact_isReset;
  assign stages_executeSet3_state_weight = stages_executeGet2_state_weight;
  assign stages_executeSet3_compact_valid = stages_executeGet2_compact_valid;
  assign stages_executeSet3_compact_isReset = stages_executeGet2_compact_isReset;
  assign stages_executeSet3_isTight = execute3Area_edgeIsTight_io_isTight;
  assign stages_updateSet_state_weight = stages_executeGet3_state_weight;
  assign stages_updateSet_compact_valid = stages_executeGet3_compact_valid;
  assign stages_updateSet_compact_isReset = stages_executeGet3_compact_isReset;
  assign stages_updateSet_remaining = updateArea_edgeRemaining_io_remaining;
  assign stages_updateSet2_state_weight = stages_updateGet_state_weight;
  assign stages_updateSet2_remaining = stages_updateGet_remaining;
  assign stages_updateSet2_compact_valid = stages_updateGet_compact_valid;
  assign stages_updateSet2_compact_isReset = stages_updateGet_compact_isReset;
  assign stages_updateSet3_state_weight = stages_updateGet2_state_weight;
  assign stages_updateSet3_remaining = stages_updateGet2_remaining;
  assign stages_updateSet3_compact_valid = stages_updateGet2_compact_valid;
  assign stages_updateSet3_compact_isReset = stages_updateGet2_compact_isReset;
  assign io_maxGrowable_length = edgeResponse_3_io_maxGrowable_length;
  assign io_conflict_node1 = edgeResponse_3_io_conflict_node1;
  assign io_conflict_node2 = edgeResponse_3_io_conflict_node2;
  assign io_conflict_touch1 = edgeResponse_3_io_conflict_touch1;
  assign io_conflict_touch2 = edgeResponse_3_io_conflict_touch2;
  assign io_conflict_vertex1 = edgeResponse_3_io_conflict_vertex1;
  assign io_conflict_vertex2 = edgeResponse_3_io_conflict_vertex2;
  assign io_conflict_valid = edgeResponse_3_io_conflict_valid;
  assign stages_executeGet3_state_weight = stages_executeSet3_state_weight;
  assign stages_executeGet3_isTight = stages_executeSet3_isTight;
  assign stages_executeGet3_compact_valid = stages_executeSet3_compact_valid;
  assign stages_executeGet3_compact_isReset = stages_executeSet3_compact_isReset;
  assign stages_updateGet_state_weight = stages_updateSet_state_weight;
  assign stages_updateGet_remaining = stages_updateSet_remaining;
  assign stages_updateGet_compact_valid = stages_updateSet_compact_valid;
  assign stages_updateGet_compact_isReset = stages_updateSet_compact_isReset;
  assign stages_offloadGet_state_weight = stages_offloadSet_state_weight;
  assign stages_offloadGet_compact_valid = stages_offloadSet_compact_valid;
  assign stages_offloadGet_compact_isReset = stages_offloadSet_compact_isReset;
  assign stages_offloadGet4_state_weight = stages_offloadSet4_state_weight;
  assign stages_offloadGet4_compact_valid = stages_offloadSet4_compact_valid;
  assign stages_offloadGet4_compact_isReset = stages_offloadSet4_compact_isReset;
  assign stages_updateGet3_state_weight = stages_updateSet3_state_weight;
  assign stages_updateGet3_remaining = stages_updateSet3_remaining;
  assign stages_updateGet3_compact_valid = stages_updateSet3_compact_valid;
  assign stages_updateGet3_compact_isReset = stages_updateSet3_compact_isReset;
  assign stages_executeGet_state_weight = stages_executeSet_state_weight;
  assign stages_executeGet_compact_valid = stages_executeSet_compact_valid;
  assign stages_executeGet_compact_isReset = stages_executeSet_compact_isReset;
  assign stages_executeGet2_state_weight = stages_executeSet2_state_weight;
  assign stages_executeGet2_compact_valid = stages_executeSet2_compact_valid;
  assign stages_executeGet2_compact_isReset = stages_executeSet2_compact_isReset;
  assign stages_offloadGet3_state_weight = stages_offloadSet3_state_weight;
  assign stages_offloadGet3_isTight = stages_offloadSet3_isTight;
  assign stages_offloadGet3_compact_valid = stages_offloadSet3_compact_valid;
  assign stages_offloadGet3_compact_isReset = stages_offloadSet3_compact_isReset;
  assign stages_updateGet2_state_weight = stages_updateSet2_state_weight;
  assign stages_updateGet2_remaining = stages_updateSet2_remaining;
  assign stages_updateGet2_compact_valid = stages_updateSet2_compact_valid;
  assign stages_updateGet2_compact_isReset = stages_updateSet2_compact_isReset;
  assign stages_offloadGet2_state_weight = stages_offloadSet2_state_weight;
  assign stages_offloadGet2_isTight = stages_offloadSet2_isTight;
  assign stages_offloadGet2_isTightExFusion = stages_offloadSet2_isTightExFusion;
  assign stages_offloadGet2_compact_valid = stages_offloadSet2_compact_valid;
  assign stages_offloadGet2_compact_isReset = stages_offloadSet2_compact_isReset;

endmodule

module Edge_2 (
  input               io_message_valid,
  input      [11:0]   io_message_instruction,
  input               io_message_isReset,
  output     [1:0]    io_stageOutputs_offloadGet_state_weight,
  output              io_stageOutputs_offloadGet_compact_valid,
  output              io_stageOutputs_offloadGet_compact_isReset,
  output     [1:0]    io_stageOutputs_offloadGet2_state_weight,
  output              io_stageOutputs_offloadGet2_isTight,
  output              io_stageOutputs_offloadGet2_isTightExFusion,
  output              io_stageOutputs_offloadGet2_compact_valid,
  output              io_stageOutputs_offloadGet2_compact_isReset,
  output     [1:0]    io_stageOutputs_offloadGet3_state_weight,
  output              io_stageOutputs_offloadGet3_isTight,
  output              io_stageOutputs_offloadGet3_compact_valid,
  output              io_stageOutputs_offloadGet3_compact_isReset,
  output     [1:0]    io_stageOutputs_offloadGet4_state_weight,
  output              io_stageOutputs_offloadGet4_compact_valid,
  output              io_stageOutputs_offloadGet4_compact_isReset,
  output     [1:0]    io_stageOutputs_executeGet_state_weight,
  output              io_stageOutputs_executeGet_compact_valid,
  output              io_stageOutputs_executeGet_compact_isReset,
  output     [1:0]    io_stageOutputs_executeGet2_state_weight,
  output              io_stageOutputs_executeGet2_compact_valid,
  output              io_stageOutputs_executeGet2_compact_isReset,
  output     [1:0]    io_stageOutputs_executeGet3_state_weight,
  output              io_stageOutputs_executeGet3_isTight,
  output              io_stageOutputs_executeGet3_compact_valid,
  output              io_stageOutputs_executeGet3_compact_isReset,
  output     [1:0]    io_stageOutputs_updateGet_state_weight,
  output     [1:0]    io_stageOutputs_updateGet_remaining,
  output              io_stageOutputs_updateGet_compact_valid,
  output              io_stageOutputs_updateGet_compact_isReset,
  output     [1:0]    io_stageOutputs_updateGet2_state_weight,
  output     [1:0]    io_stageOutputs_updateGet2_remaining,
  output              io_stageOutputs_updateGet2_compact_valid,
  output              io_stageOutputs_updateGet2_compact_isReset,
  output     [1:0]    io_stageOutputs_updateGet3_state_weight,
  output     [1:0]    io_stageOutputs_updateGet3_remaining,
  output              io_stageOutputs_updateGet3_compact_valid,
  output              io_stageOutputs_updateGet3_compact_isReset,
  input      [1:0]    io_leftVertexInput_offloadGet_state_speed,
  input      [4:0]    io_leftVertexInput_offloadGet_state_node,
  input      [4:0]    io_leftVertexInput_offloadGet_state_root,
  input               io_leftVertexInput_offloadGet_state_isVirtual,
  input               io_leftVertexInput_offloadGet_state_isDefect,
  input      [1:0]    io_leftVertexInput_offloadGet_state_grown,
  input               io_leftVertexInput_offloadGet_message_valid,
  input      [11:0]   io_leftVertexInput_offloadGet_message_instruction,
  input               io_leftVertexInput_offloadGet_message_isReset,
  input      [1:0]    io_leftVertexInput_offloadGet2_state_speed,
  input      [4:0]    io_leftVertexInput_offloadGet2_state_node,
  input      [4:0]    io_leftVertexInput_offloadGet2_state_root,
  input               io_leftVertexInput_offloadGet2_state_isVirtual,
  input               io_leftVertexInput_offloadGet2_state_isDefect,
  input      [1:0]    io_leftVertexInput_offloadGet2_state_grown,
  input               io_leftVertexInput_offloadGet2_message_valid,
  input      [11:0]   io_leftVertexInput_offloadGet2_message_instruction,
  input               io_leftVertexInput_offloadGet2_message_isReset,
  input      [1:0]    io_leftVertexInput_offloadGet3_state_speed,
  input      [4:0]    io_leftVertexInput_offloadGet3_state_node,
  input      [4:0]    io_leftVertexInput_offloadGet3_state_root,
  input               io_leftVertexInput_offloadGet3_state_isVirtual,
  input               io_leftVertexInput_offloadGet3_state_isDefect,
  input      [1:0]    io_leftVertexInput_offloadGet3_state_grown,
  input               io_leftVertexInput_offloadGet3_message_valid,
  input      [11:0]   io_leftVertexInput_offloadGet3_message_instruction,
  input               io_leftVertexInput_offloadGet3_message_isReset,
  input               io_leftVertexInput_offloadGet3_isUniqueTight,
  input               io_leftVertexInput_offloadGet3_isIsolated,
  input      [1:0]    io_leftVertexInput_offloadGet4_state_speed,
  input      [4:0]    io_leftVertexInput_offloadGet4_state_node,
  input      [4:0]    io_leftVertexInput_offloadGet4_state_root,
  input               io_leftVertexInput_offloadGet4_state_isVirtual,
  input               io_leftVertexInput_offloadGet4_state_isDefect,
  input      [1:0]    io_leftVertexInput_offloadGet4_state_grown,
  input               io_leftVertexInput_offloadGet4_message_valid,
  input      [11:0]   io_leftVertexInput_offloadGet4_message_instruction,
  input               io_leftVertexInput_offloadGet4_message_isReset,
  input      [1:0]    io_leftVertexInput_executeGet_state_speed,
  input      [4:0]    io_leftVertexInput_executeGet_state_node,
  input      [4:0]    io_leftVertexInput_executeGet_state_root,
  input               io_leftVertexInput_executeGet_state_isVirtual,
  input               io_leftVertexInput_executeGet_state_isDefect,
  input      [1:0]    io_leftVertexInput_executeGet_state_grown,
  input               io_leftVertexInput_executeGet_message_valid,
  input      [11:0]   io_leftVertexInput_executeGet_message_instruction,
  input               io_leftVertexInput_executeGet_message_isReset,
  input               io_leftVertexInput_executeGet_isStalled,
  input      [1:0]    io_leftVertexInput_executeGet2_state_speed,
  input      [4:0]    io_leftVertexInput_executeGet2_state_node,
  input      [4:0]    io_leftVertexInput_executeGet2_state_root,
  input               io_leftVertexInput_executeGet2_state_isVirtual,
  input               io_leftVertexInput_executeGet2_state_isDefect,
  input      [1:0]    io_leftVertexInput_executeGet2_state_grown,
  input               io_leftVertexInput_executeGet2_isStalled,
  input               io_leftVertexInput_executeGet2_compact_valid,
  input               io_leftVertexInput_executeGet2_compact_isReset,
  input      [1:0]    io_leftVertexInput_executeGet3_state_speed,
  input      [4:0]    io_leftVertexInput_executeGet3_state_node,
  input      [4:0]    io_leftVertexInput_executeGet3_state_root,
  input               io_leftVertexInput_executeGet3_state_isVirtual,
  input               io_leftVertexInput_executeGet3_state_isDefect,
  input      [1:0]    io_leftVertexInput_executeGet3_state_grown,
  input               io_leftVertexInput_executeGet3_isStalled,
  input               io_leftVertexInput_executeGet3_compact_valid,
  input               io_leftVertexInput_executeGet3_compact_isReset,
  input      [1:0]    io_leftVertexInput_updateGet_state_speed,
  input      [4:0]    io_leftVertexInput_updateGet_state_node,
  input      [4:0]    io_leftVertexInput_updateGet_state_root,
  input               io_leftVertexInput_updateGet_state_isVirtual,
  input               io_leftVertexInput_updateGet_state_isDefect,
  input      [1:0]    io_leftVertexInput_updateGet_state_grown,
  input               io_leftVertexInput_updateGet_isStalled,
  input               io_leftVertexInput_updateGet_compact_valid,
  input               io_leftVertexInput_updateGet_compact_isReset,
  input               io_leftVertexInput_updateGet_propagatingPeer_valid,
  input      [4:0]    io_leftVertexInput_updateGet_propagatingPeer_node,
  input      [4:0]    io_leftVertexInput_updateGet_propagatingPeer_root,
  input      [1:0]    io_leftVertexInput_updateGet2_state_speed,
  input      [4:0]    io_leftVertexInput_updateGet2_state_node,
  input      [4:0]    io_leftVertexInput_updateGet2_state_root,
  input               io_leftVertexInput_updateGet2_state_isVirtual,
  input               io_leftVertexInput_updateGet2_state_isDefect,
  input      [1:0]    io_leftVertexInput_updateGet2_state_grown,
  input               io_leftVertexInput_updateGet2_isStalled,
  input               io_leftVertexInput_updateGet2_compact_valid,
  input               io_leftVertexInput_updateGet2_compact_isReset,
  input               io_leftVertexInput_updateGet2_propagatingPeer_valid,
  input      [4:0]    io_leftVertexInput_updateGet2_propagatingPeer_node,
  input      [4:0]    io_leftVertexInput_updateGet2_propagatingPeer_root,
  input      [1:0]    io_leftVertexInput_updateGet3_state_speed,
  input      [4:0]    io_leftVertexInput_updateGet3_state_node,
  input      [4:0]    io_leftVertexInput_updateGet3_state_root,
  input               io_leftVertexInput_updateGet3_state_isVirtual,
  input               io_leftVertexInput_updateGet3_state_isDefect,
  input      [1:0]    io_leftVertexInput_updateGet3_state_grown,
  input      [1:0]    io_leftVertexInput_updateGet3_shadow_speed,
  input      [4:0]    io_leftVertexInput_updateGet3_shadow_node,
  input      [4:0]    io_leftVertexInput_updateGet3_shadow_root,
  input               io_leftVertexInput_updateGet3_compact_valid,
  input               io_leftVertexInput_updateGet3_compact_isReset,
  input      [1:0]    io_rightVertexInput_offloadGet_state_speed,
  input      [4:0]    io_rightVertexInput_offloadGet_state_node,
  input      [4:0]    io_rightVertexInput_offloadGet_state_root,
  input               io_rightVertexInput_offloadGet_state_isVirtual,
  input               io_rightVertexInput_offloadGet_state_isDefect,
  input      [1:0]    io_rightVertexInput_offloadGet_state_grown,
  input               io_rightVertexInput_offloadGet_message_valid,
  input      [11:0]   io_rightVertexInput_offloadGet_message_instruction,
  input               io_rightVertexInput_offloadGet_message_isReset,
  input      [1:0]    io_rightVertexInput_offloadGet2_state_speed,
  input      [4:0]    io_rightVertexInput_offloadGet2_state_node,
  input      [4:0]    io_rightVertexInput_offloadGet2_state_root,
  input               io_rightVertexInput_offloadGet2_state_isVirtual,
  input               io_rightVertexInput_offloadGet2_state_isDefect,
  input      [1:0]    io_rightVertexInput_offloadGet2_state_grown,
  input               io_rightVertexInput_offloadGet2_message_valid,
  input      [11:0]   io_rightVertexInput_offloadGet2_message_instruction,
  input               io_rightVertexInput_offloadGet2_message_isReset,
  input      [1:0]    io_rightVertexInput_offloadGet3_state_speed,
  input      [4:0]    io_rightVertexInput_offloadGet3_state_node,
  input      [4:0]    io_rightVertexInput_offloadGet3_state_root,
  input               io_rightVertexInput_offloadGet3_state_isVirtual,
  input               io_rightVertexInput_offloadGet3_state_isDefect,
  input      [1:0]    io_rightVertexInput_offloadGet3_state_grown,
  input               io_rightVertexInput_offloadGet3_message_valid,
  input      [11:0]   io_rightVertexInput_offloadGet3_message_instruction,
  input               io_rightVertexInput_offloadGet3_message_isReset,
  input               io_rightVertexInput_offloadGet3_isUniqueTight,
  input               io_rightVertexInput_offloadGet3_isIsolated,
  input      [1:0]    io_rightVertexInput_offloadGet4_state_speed,
  input      [4:0]    io_rightVertexInput_offloadGet4_state_node,
  input      [4:0]    io_rightVertexInput_offloadGet4_state_root,
  input               io_rightVertexInput_offloadGet4_state_isVirtual,
  input               io_rightVertexInput_offloadGet4_state_isDefect,
  input      [1:0]    io_rightVertexInput_offloadGet4_state_grown,
  input               io_rightVertexInput_offloadGet4_message_valid,
  input      [11:0]   io_rightVertexInput_offloadGet4_message_instruction,
  input               io_rightVertexInput_offloadGet4_message_isReset,
  input      [1:0]    io_rightVertexInput_executeGet_state_speed,
  input      [4:0]    io_rightVertexInput_executeGet_state_node,
  input      [4:0]    io_rightVertexInput_executeGet_state_root,
  input               io_rightVertexInput_executeGet_state_isVirtual,
  input               io_rightVertexInput_executeGet_state_isDefect,
  input      [1:0]    io_rightVertexInput_executeGet_state_grown,
  input               io_rightVertexInput_executeGet_message_valid,
  input      [11:0]   io_rightVertexInput_executeGet_message_instruction,
  input               io_rightVertexInput_executeGet_message_isReset,
  input               io_rightVertexInput_executeGet_isStalled,
  input      [1:0]    io_rightVertexInput_executeGet2_state_speed,
  input      [4:0]    io_rightVertexInput_executeGet2_state_node,
  input      [4:0]    io_rightVertexInput_executeGet2_state_root,
  input               io_rightVertexInput_executeGet2_state_isVirtual,
  input               io_rightVertexInput_executeGet2_state_isDefect,
  input      [1:0]    io_rightVertexInput_executeGet2_state_grown,
  input               io_rightVertexInput_executeGet2_isStalled,
  input               io_rightVertexInput_executeGet2_compact_valid,
  input               io_rightVertexInput_executeGet2_compact_isReset,
  input      [1:0]    io_rightVertexInput_executeGet3_state_speed,
  input      [4:0]    io_rightVertexInput_executeGet3_state_node,
  input      [4:0]    io_rightVertexInput_executeGet3_state_root,
  input               io_rightVertexInput_executeGet3_state_isVirtual,
  input               io_rightVertexInput_executeGet3_state_isDefect,
  input      [1:0]    io_rightVertexInput_executeGet3_state_grown,
  input               io_rightVertexInput_executeGet3_isStalled,
  input               io_rightVertexInput_executeGet3_compact_valid,
  input               io_rightVertexInput_executeGet3_compact_isReset,
  input      [1:0]    io_rightVertexInput_updateGet_state_speed,
  input      [4:0]    io_rightVertexInput_updateGet_state_node,
  input      [4:0]    io_rightVertexInput_updateGet_state_root,
  input               io_rightVertexInput_updateGet_state_isVirtual,
  input               io_rightVertexInput_updateGet_state_isDefect,
  input      [1:0]    io_rightVertexInput_updateGet_state_grown,
  input               io_rightVertexInput_updateGet_isStalled,
  input               io_rightVertexInput_updateGet_compact_valid,
  input               io_rightVertexInput_updateGet_compact_isReset,
  input               io_rightVertexInput_updateGet_propagatingPeer_valid,
  input      [4:0]    io_rightVertexInput_updateGet_propagatingPeer_node,
  input      [4:0]    io_rightVertexInput_updateGet_propagatingPeer_root,
  input      [1:0]    io_rightVertexInput_updateGet2_state_speed,
  input      [4:0]    io_rightVertexInput_updateGet2_state_node,
  input      [4:0]    io_rightVertexInput_updateGet2_state_root,
  input               io_rightVertexInput_updateGet2_state_isVirtual,
  input               io_rightVertexInput_updateGet2_state_isDefect,
  input      [1:0]    io_rightVertexInput_updateGet2_state_grown,
  input               io_rightVertexInput_updateGet2_isStalled,
  input               io_rightVertexInput_updateGet2_compact_valid,
  input               io_rightVertexInput_updateGet2_compact_isReset,
  input               io_rightVertexInput_updateGet2_propagatingPeer_valid,
  input      [4:0]    io_rightVertexInput_updateGet2_propagatingPeer_node,
  input      [4:0]    io_rightVertexInput_updateGet2_propagatingPeer_root,
  input      [1:0]    io_rightVertexInput_updateGet3_state_speed,
  input      [4:0]    io_rightVertexInput_updateGet3_state_node,
  input      [4:0]    io_rightVertexInput_updateGet3_state_root,
  input               io_rightVertexInput_updateGet3_state_isVirtual,
  input               io_rightVertexInput_updateGet3_state_isDefect,
  input      [1:0]    io_rightVertexInput_updateGet3_state_grown,
  input      [1:0]    io_rightVertexInput_updateGet3_shadow_speed,
  input      [4:0]    io_rightVertexInput_updateGet3_shadow_node,
  input      [4:0]    io_rightVertexInput_updateGet3_shadow_root,
  input               io_rightVertexInput_updateGet3_compact_valid,
  input               io_rightVertexInput_updateGet3_compact_isReset,
  output     [1:0]    io_maxGrowable_length,
  output     [4:0]    io_conflict_node1,
  output     [4:0]    io_conflict_node2,
  output     [4:0]    io_conflict_touch1,
  output     [4:0]    io_conflict_touch2,
  output     [4:0]    io_conflict_vertex1,
  output     [4:0]    io_conflict_vertex2,
  output              io_conflict_valid
);

  wire                offload2Area_edgeIsTight_io_isTight;
  wire                execute3Area_edgeIsTight_io_isTight;
  wire       [1:0]    updateArea_edgeRemaining_io_remaining;
  wire       [1:0]    edgeResponse_3_io_maxGrowable_length;
  wire       [4:0]    edgeResponse_3_io_conflict_node1;
  wire       [4:0]    edgeResponse_3_io_conflict_node2;
  wire       [4:0]    edgeResponse_3_io_conflict_touch1;
  wire       [4:0]    edgeResponse_3_io_conflict_touch2;
  wire       [4:0]    edgeResponse_3_io_conflict_vertex1;
  wire       [4:0]    edgeResponse_3_io_conflict_vertex2;
  wire                edgeResponse_3_io_conflict_valid;
  wire       [1:0]    stages_offloadSet_state_weight;
  wire                stages_offloadSet_compact_valid;
  wire                stages_offloadSet_compact_isReset;
  wire       [1:0]    stages_offloadGet_state_weight;
  wire                stages_offloadGet_compact_valid;
  wire                stages_offloadGet_compact_isReset;
  wire       [1:0]    stages_offloadSet2_state_weight;
  wire                stages_offloadSet2_isTight;
  wire                stages_offloadSet2_isTightExFusion;
  wire                stages_offloadSet2_compact_valid;
  wire                stages_offloadSet2_compact_isReset;
  wire       [1:0]    stages_offloadGet2_state_weight;
  wire                stages_offloadGet2_isTight;
  wire                stages_offloadGet2_isTightExFusion;
  wire                stages_offloadGet2_compact_valid;
  wire                stages_offloadGet2_compact_isReset;
  wire       [1:0]    stages_offloadSet3_state_weight;
  wire                stages_offloadSet3_isTight;
  wire                stages_offloadSet3_compact_valid;
  wire                stages_offloadSet3_compact_isReset;
  wire       [1:0]    stages_offloadGet3_state_weight;
  wire                stages_offloadGet3_isTight;
  wire                stages_offloadGet3_compact_valid;
  wire                stages_offloadGet3_compact_isReset;
  wire       [1:0]    stages_offloadSet4_state_weight;
  wire                stages_offloadSet4_compact_valid;
  wire                stages_offloadSet4_compact_isReset;
  wire       [1:0]    stages_offloadGet4_state_weight;
  wire                stages_offloadGet4_compact_valid;
  wire                stages_offloadGet4_compact_isReset;
  wire       [1:0]    stages_executeSet_state_weight;
  wire                stages_executeSet_compact_valid;
  wire                stages_executeSet_compact_isReset;
  wire       [1:0]    stages_executeGet_state_weight;
  wire                stages_executeGet_compact_valid;
  wire                stages_executeGet_compact_isReset;
  wire       [1:0]    stages_executeSet2_state_weight;
  wire                stages_executeSet2_compact_valid;
  wire                stages_executeSet2_compact_isReset;
  wire       [1:0]    stages_executeGet2_state_weight;
  wire                stages_executeGet2_compact_valid;
  wire                stages_executeGet2_compact_isReset;
  wire       [1:0]    stages_executeSet3_state_weight;
  wire                stages_executeSet3_isTight;
  wire                stages_executeSet3_compact_valid;
  wire                stages_executeSet3_compact_isReset;
  wire       [1:0]    stages_executeGet3_state_weight;
  wire                stages_executeGet3_isTight;
  wire                stages_executeGet3_compact_valid;
  wire                stages_executeGet3_compact_isReset;
  wire       [1:0]    stages_updateSet_state_weight;
  wire       [1:0]    stages_updateSet_remaining;
  wire                stages_updateSet_compact_valid;
  wire                stages_updateSet_compact_isReset;
  wire       [1:0]    stages_updateGet_state_weight;
  wire       [1:0]    stages_updateGet_remaining;
  wire                stages_updateGet_compact_valid;
  wire                stages_updateGet_compact_isReset;
  wire       [1:0]    stages_updateSet2_state_weight;
  wire       [1:0]    stages_updateSet2_remaining;
  wire                stages_updateSet2_compact_valid;
  wire                stages_updateSet2_compact_isReset;
  wire       [1:0]    stages_updateGet2_state_weight;
  wire       [1:0]    stages_updateGet2_remaining;
  wire                stages_updateGet2_compact_valid;
  wire                stages_updateGet2_compact_isReset;
  wire       [1:0]    stages_updateSet3_state_weight;
  wire       [1:0]    stages_updateSet3_remaining;
  wire                stages_updateSet3_compact_valid;
  wire                stages_updateSet3_compact_isReset;
  wire       [1:0]    stages_updateGet3_state_weight;
  wire       [1:0]    stages_updateGet3_remaining;
  wire                stages_updateGet3_compact_valid;
  wire                stages_updateGet3_compact_isReset;
  wire       [1:0]    fetchState_weight;
  wire                message_valid;
  wire       [11:0]   message_instruction;
  wire                message_isReset;
  wire                conditionedVertexIsVirtual;
  wire       [1:0]    offload2Weight;

  EdgeIsTight_4 offload2Area_edgeIsTight (
    .io_leftGrown  (io_leftVertexInput_offloadGet_state_grown[1:0] ), //i
    .io_rightGrown (io_rightVertexInput_offloadGet_state_grown[1:0]), //i
    .io_weight     (offload2Weight[1:0]                            ), //i
    .io_isTight    (offload2Area_edgeIsTight_io_isTight            )  //o
  );
  EdgeIsTight_4 execute3Area_edgeIsTight (
    .io_leftGrown  (io_leftVertexInput_executeGet2_state_grown[1:0] ), //i
    .io_rightGrown (io_rightVertexInput_executeGet2_state_grown[1:0]), //i
    .io_weight     (stages_executeGet2_state_weight[1:0]            ), //i
    .io_isTight    (execute3Area_edgeIsTight_io_isTight             )  //o
  );
  EdgeRemaining_2 updateArea_edgeRemaining (
    .io_leftGrown  (io_leftVertexInput_executeGet3_state_grown[1:0] ), //i
    .io_rightGrown (io_rightVertexInput_executeGet3_state_grown[1:0]), //i
    .io_weight     (stages_executeGet3_state_weight[1:0]            ), //i
    .io_remaining  (updateArea_edgeRemaining_io_remaining[1:0]      )  //o
  );
  EdgeResponse_2 edgeResponse_3 (
    .io_leftShadow_speed   (io_leftVertexInput_updateGet3_shadow_speed[1:0] ), //i
    .io_leftShadow_node    (io_leftVertexInput_updateGet3_shadow_node[4:0]  ), //i
    .io_leftShadow_root    (io_leftVertexInput_updateGet3_shadow_root[4:0]  ), //i
    .io_rightShadow_speed  (io_rightVertexInput_updateGet3_shadow_speed[1:0]), //i
    .io_rightShadow_node   (io_rightVertexInput_updateGet3_shadow_node[4:0] ), //i
    .io_rightShadow_root   (io_rightVertexInput_updateGet3_shadow_root[4:0] ), //i
    .io_leftIsVirtual      (io_leftVertexInput_updateGet3_state_isVirtual   ), //i
    .io_rightIsVirtual     (io_rightVertexInput_updateGet3_state_isVirtual  ), //i
    .io_leftVertex         (5'h01                                           ), //i
    .io_rightVertex        (5'h02                                           ), //i
    .io_remaining          (stages_updateGet3_remaining[1:0]                ), //i
    .io_maxGrowable_length (edgeResponse_3_io_maxGrowable_length[1:0]       ), //o
    .io_conflict_node1     (edgeResponse_3_io_conflict_node1[4:0]           ), //o
    .io_conflict_node2     (edgeResponse_3_io_conflict_node2[4:0]           ), //o
    .io_conflict_touch1    (edgeResponse_3_io_conflict_touch1[4:0]          ), //o
    .io_conflict_touch2    (edgeResponse_3_io_conflict_touch2[4:0]          ), //o
    .io_conflict_vertex1   (edgeResponse_3_io_conflict_vertex1[4:0]         ), //o
    .io_conflict_vertex2   (edgeResponse_3_io_conflict_vertex2[4:0]         ), //o
    .io_conflict_valid     (edgeResponse_3_io_conflict_valid                )  //o
  );
  assign io_stageOutputs_offloadGet_state_weight = stages_offloadGet_state_weight;
  assign io_stageOutputs_offloadGet_compact_valid = stages_offloadGet_compact_valid;
  assign io_stageOutputs_offloadGet_compact_isReset = stages_offloadGet_compact_isReset;
  assign io_stageOutputs_offloadGet2_state_weight = stages_offloadGet2_state_weight;
  assign io_stageOutputs_offloadGet2_isTight = stages_offloadGet2_isTight;
  assign io_stageOutputs_offloadGet2_isTightExFusion = stages_offloadGet2_isTightExFusion;
  assign io_stageOutputs_offloadGet2_compact_valid = stages_offloadGet2_compact_valid;
  assign io_stageOutputs_offloadGet2_compact_isReset = stages_offloadGet2_compact_isReset;
  assign io_stageOutputs_offloadGet3_state_weight = stages_offloadGet3_state_weight;
  assign io_stageOutputs_offloadGet3_isTight = stages_offloadGet3_isTight;
  assign io_stageOutputs_offloadGet3_compact_valid = stages_offloadGet3_compact_valid;
  assign io_stageOutputs_offloadGet3_compact_isReset = stages_offloadGet3_compact_isReset;
  assign io_stageOutputs_offloadGet4_state_weight = stages_offloadGet4_state_weight;
  assign io_stageOutputs_offloadGet4_compact_valid = stages_offloadGet4_compact_valid;
  assign io_stageOutputs_offloadGet4_compact_isReset = stages_offloadGet4_compact_isReset;
  assign io_stageOutputs_executeGet_state_weight = stages_executeGet_state_weight;
  assign io_stageOutputs_executeGet_compact_valid = stages_executeGet_compact_valid;
  assign io_stageOutputs_executeGet_compact_isReset = stages_executeGet_compact_isReset;
  assign io_stageOutputs_executeGet2_state_weight = stages_executeGet2_state_weight;
  assign io_stageOutputs_executeGet2_compact_valid = stages_executeGet2_compact_valid;
  assign io_stageOutputs_executeGet2_compact_isReset = stages_executeGet2_compact_isReset;
  assign io_stageOutputs_executeGet3_state_weight = stages_executeGet3_state_weight;
  assign io_stageOutputs_executeGet3_isTight = stages_executeGet3_isTight;
  assign io_stageOutputs_executeGet3_compact_valid = stages_executeGet3_compact_valid;
  assign io_stageOutputs_executeGet3_compact_isReset = stages_executeGet3_compact_isReset;
  assign io_stageOutputs_updateGet_state_weight = stages_updateGet_state_weight;
  assign io_stageOutputs_updateGet_remaining = stages_updateGet_remaining;
  assign io_stageOutputs_updateGet_compact_valid = stages_updateGet_compact_valid;
  assign io_stageOutputs_updateGet_compact_isReset = stages_updateGet_compact_isReset;
  assign io_stageOutputs_updateGet2_state_weight = stages_updateGet2_state_weight;
  assign io_stageOutputs_updateGet2_remaining = stages_updateGet2_remaining;
  assign io_stageOutputs_updateGet2_compact_valid = stages_updateGet2_compact_valid;
  assign io_stageOutputs_updateGet2_compact_isReset = stages_updateGet2_compact_isReset;
  assign io_stageOutputs_updateGet3_state_weight = stages_updateGet3_state_weight;
  assign io_stageOutputs_updateGet3_remaining = stages_updateGet3_remaining;
  assign io_stageOutputs_updateGet3_compact_valid = stages_updateGet3_compact_valid;
  assign io_stageOutputs_updateGet3_compact_isReset = stages_updateGet3_compact_isReset;
  assign fetchState_weight = 2'b10;
  assign message_valid = io_message_valid;
  assign message_instruction = io_message_instruction;
  assign message_isReset = io_message_isReset;
  assign stages_offloadSet_state_weight = fetchState_weight;
  assign stages_offloadSet_compact_valid = message_valid;
  assign stages_offloadSet_compact_isReset = message_isReset;
  assign stages_offloadSet2_state_weight = stages_offloadGet_state_weight;
  assign stages_offloadSet2_compact_valid = stages_offloadGet_compact_valid;
  assign stages_offloadSet2_compact_isReset = stages_offloadGet_compact_isReset;
  assign conditionedVertexIsVirtual = 1'b0;
  assign offload2Weight = stages_offloadGet_state_weight;
  assign stages_offloadSet2_isTight = offload2Area_edgeIsTight_io_isTight;
  assign stages_offloadSet2_isTightExFusion = offload2Area_edgeIsTight_io_isTight;
  assign stages_offloadSet3_state_weight = stages_offloadGet2_state_weight;
  assign stages_offloadSet3_isTight = stages_offloadGet2_isTight;
  assign stages_offloadSet3_compact_valid = stages_offloadGet2_compact_valid;
  assign stages_offloadSet3_compact_isReset = stages_offloadGet2_compact_isReset;
  assign stages_offloadSet4_state_weight = stages_offloadGet3_state_weight;
  assign stages_offloadSet4_compact_valid = stages_offloadGet3_compact_valid;
  assign stages_offloadSet4_compact_isReset = stages_offloadGet3_compact_isReset;
  assign stages_executeSet_state_weight = stages_offloadGet4_state_weight;
  assign stages_executeSet_compact_valid = stages_offloadGet4_compact_valid;
  assign stages_executeSet_compact_isReset = stages_offloadGet4_compact_isReset;
  assign stages_executeSet2_state_weight = stages_executeGet_state_weight;
  assign stages_executeSet2_compact_valid = stages_executeGet_compact_valid;
  assign stages_executeSet2_compact_isReset = stages_executeGet_compact_isReset;
  assign stages_executeSet3_state_weight = stages_executeGet2_state_weight;
  assign stages_executeSet3_compact_valid = stages_executeGet2_compact_valid;
  assign stages_executeSet3_compact_isReset = stages_executeGet2_compact_isReset;
  assign stages_executeSet3_isTight = execute3Area_edgeIsTight_io_isTight;
  assign stages_updateSet_state_weight = stages_executeGet3_state_weight;
  assign stages_updateSet_compact_valid = stages_executeGet3_compact_valid;
  assign stages_updateSet_compact_isReset = stages_executeGet3_compact_isReset;
  assign stages_updateSet_remaining = updateArea_edgeRemaining_io_remaining;
  assign stages_updateSet2_state_weight = stages_updateGet_state_weight;
  assign stages_updateSet2_remaining = stages_updateGet_remaining;
  assign stages_updateSet2_compact_valid = stages_updateGet_compact_valid;
  assign stages_updateSet2_compact_isReset = stages_updateGet_compact_isReset;
  assign stages_updateSet3_state_weight = stages_updateGet2_state_weight;
  assign stages_updateSet3_remaining = stages_updateGet2_remaining;
  assign stages_updateSet3_compact_valid = stages_updateGet2_compact_valid;
  assign stages_updateSet3_compact_isReset = stages_updateGet2_compact_isReset;
  assign io_maxGrowable_length = edgeResponse_3_io_maxGrowable_length;
  assign io_conflict_node1 = edgeResponse_3_io_conflict_node1;
  assign io_conflict_node2 = edgeResponse_3_io_conflict_node2;
  assign io_conflict_touch1 = edgeResponse_3_io_conflict_touch1;
  assign io_conflict_touch2 = edgeResponse_3_io_conflict_touch2;
  assign io_conflict_vertex1 = edgeResponse_3_io_conflict_vertex1;
  assign io_conflict_vertex2 = edgeResponse_3_io_conflict_vertex2;
  assign io_conflict_valid = edgeResponse_3_io_conflict_valid;
  assign stages_executeGet3_state_weight = stages_executeSet3_state_weight;
  assign stages_executeGet3_isTight = stages_executeSet3_isTight;
  assign stages_executeGet3_compact_valid = stages_executeSet3_compact_valid;
  assign stages_executeGet3_compact_isReset = stages_executeSet3_compact_isReset;
  assign stages_updateGet_state_weight = stages_updateSet_state_weight;
  assign stages_updateGet_remaining = stages_updateSet_remaining;
  assign stages_updateGet_compact_valid = stages_updateSet_compact_valid;
  assign stages_updateGet_compact_isReset = stages_updateSet_compact_isReset;
  assign stages_offloadGet_state_weight = stages_offloadSet_state_weight;
  assign stages_offloadGet_compact_valid = stages_offloadSet_compact_valid;
  assign stages_offloadGet_compact_isReset = stages_offloadSet_compact_isReset;
  assign stages_offloadGet4_state_weight = stages_offloadSet4_state_weight;
  assign stages_offloadGet4_compact_valid = stages_offloadSet4_compact_valid;
  assign stages_offloadGet4_compact_isReset = stages_offloadSet4_compact_isReset;
  assign stages_updateGet3_state_weight = stages_updateSet3_state_weight;
  assign stages_updateGet3_remaining = stages_updateSet3_remaining;
  assign stages_updateGet3_compact_valid = stages_updateSet3_compact_valid;
  assign stages_updateGet3_compact_isReset = stages_updateSet3_compact_isReset;
  assign stages_executeGet_state_weight = stages_executeSet_state_weight;
  assign stages_executeGet_compact_valid = stages_executeSet_compact_valid;
  assign stages_executeGet_compact_isReset = stages_executeSet_compact_isReset;
  assign stages_executeGet2_state_weight = stages_executeSet2_state_weight;
  assign stages_executeGet2_compact_valid = stages_executeSet2_compact_valid;
  assign stages_executeGet2_compact_isReset = stages_executeSet2_compact_isReset;
  assign stages_offloadGet3_state_weight = stages_offloadSet3_state_weight;
  assign stages_offloadGet3_isTight = stages_offloadSet3_isTight;
  assign stages_offloadGet3_compact_valid = stages_offloadSet3_compact_valid;
  assign stages_offloadGet3_compact_isReset = stages_offloadSet3_compact_isReset;
  assign stages_updateGet2_state_weight = stages_updateSet2_state_weight;
  assign stages_updateGet2_remaining = stages_updateSet2_remaining;
  assign stages_updateGet2_compact_valid = stages_updateSet2_compact_valid;
  assign stages_updateGet2_compact_isReset = stages_updateSet2_compact_isReset;
  assign stages_offloadGet2_state_weight = stages_offloadSet2_state_weight;
  assign stages_offloadGet2_isTight = stages_offloadSet2_isTight;
  assign stages_offloadGet2_isTightExFusion = stages_offloadSet2_isTightExFusion;
  assign stages_offloadGet2_compact_valid = stages_offloadSet2_compact_valid;
  assign stages_offloadGet2_compact_isReset = stages_offloadSet2_compact_isReset;

endmodule

module Edge_1 (
  input               io_message_valid,
  input      [11:0]   io_message_instruction,
  input               io_message_isReset,
  output     [1:0]    io_stageOutputs_offloadGet_state_weight,
  output              io_stageOutputs_offloadGet_compact_valid,
  output              io_stageOutputs_offloadGet_compact_isReset,
  output     [1:0]    io_stageOutputs_offloadGet2_state_weight,
  output              io_stageOutputs_offloadGet2_isTight,
  output              io_stageOutputs_offloadGet2_isTightExFusion,
  output              io_stageOutputs_offloadGet2_compact_valid,
  output              io_stageOutputs_offloadGet2_compact_isReset,
  output     [1:0]    io_stageOutputs_offloadGet3_state_weight,
  output              io_stageOutputs_offloadGet3_isTight,
  output              io_stageOutputs_offloadGet3_compact_valid,
  output              io_stageOutputs_offloadGet3_compact_isReset,
  output     [1:0]    io_stageOutputs_offloadGet4_state_weight,
  output              io_stageOutputs_offloadGet4_compact_valid,
  output              io_stageOutputs_offloadGet4_compact_isReset,
  output     [1:0]    io_stageOutputs_executeGet_state_weight,
  output              io_stageOutputs_executeGet_compact_valid,
  output              io_stageOutputs_executeGet_compact_isReset,
  output     [1:0]    io_stageOutputs_executeGet2_state_weight,
  output              io_stageOutputs_executeGet2_compact_valid,
  output              io_stageOutputs_executeGet2_compact_isReset,
  output     [1:0]    io_stageOutputs_executeGet3_state_weight,
  output              io_stageOutputs_executeGet3_isTight,
  output              io_stageOutputs_executeGet3_compact_valid,
  output              io_stageOutputs_executeGet3_compact_isReset,
  output     [1:0]    io_stageOutputs_updateGet_state_weight,
  output     [1:0]    io_stageOutputs_updateGet_remaining,
  output              io_stageOutputs_updateGet_compact_valid,
  output              io_stageOutputs_updateGet_compact_isReset,
  output     [1:0]    io_stageOutputs_updateGet2_state_weight,
  output     [1:0]    io_stageOutputs_updateGet2_remaining,
  output              io_stageOutputs_updateGet2_compact_valid,
  output              io_stageOutputs_updateGet2_compact_isReset,
  output     [1:0]    io_stageOutputs_updateGet3_state_weight,
  output     [1:0]    io_stageOutputs_updateGet3_remaining,
  output              io_stageOutputs_updateGet3_compact_valid,
  output              io_stageOutputs_updateGet3_compact_isReset,
  input      [1:0]    io_leftVertexInput_offloadGet_state_speed,
  input      [4:0]    io_leftVertexInput_offloadGet_state_node,
  input      [4:0]    io_leftVertexInput_offloadGet_state_root,
  input               io_leftVertexInput_offloadGet_state_isVirtual,
  input               io_leftVertexInput_offloadGet_state_isDefect,
  input      [1:0]    io_leftVertexInput_offloadGet_state_grown,
  input               io_leftVertexInput_offloadGet_message_valid,
  input      [11:0]   io_leftVertexInput_offloadGet_message_instruction,
  input               io_leftVertexInput_offloadGet_message_isReset,
  input      [1:0]    io_leftVertexInput_offloadGet2_state_speed,
  input      [4:0]    io_leftVertexInput_offloadGet2_state_node,
  input      [4:0]    io_leftVertexInput_offloadGet2_state_root,
  input               io_leftVertexInput_offloadGet2_state_isVirtual,
  input               io_leftVertexInput_offloadGet2_state_isDefect,
  input      [1:0]    io_leftVertexInput_offloadGet2_state_grown,
  input               io_leftVertexInput_offloadGet2_message_valid,
  input      [11:0]   io_leftVertexInput_offloadGet2_message_instruction,
  input               io_leftVertexInput_offloadGet2_message_isReset,
  input      [1:0]    io_leftVertexInput_offloadGet3_state_speed,
  input      [4:0]    io_leftVertexInput_offloadGet3_state_node,
  input      [4:0]    io_leftVertexInput_offloadGet3_state_root,
  input               io_leftVertexInput_offloadGet3_state_isVirtual,
  input               io_leftVertexInput_offloadGet3_state_isDefect,
  input      [1:0]    io_leftVertexInput_offloadGet3_state_grown,
  input               io_leftVertexInput_offloadGet3_message_valid,
  input      [11:0]   io_leftVertexInput_offloadGet3_message_instruction,
  input               io_leftVertexInput_offloadGet3_message_isReset,
  input               io_leftVertexInput_offloadGet3_isUniqueTight,
  input               io_leftVertexInput_offloadGet3_isIsolated,
  input      [1:0]    io_leftVertexInput_offloadGet4_state_speed,
  input      [4:0]    io_leftVertexInput_offloadGet4_state_node,
  input      [4:0]    io_leftVertexInput_offloadGet4_state_root,
  input               io_leftVertexInput_offloadGet4_state_isVirtual,
  input               io_leftVertexInput_offloadGet4_state_isDefect,
  input      [1:0]    io_leftVertexInput_offloadGet4_state_grown,
  input               io_leftVertexInput_offloadGet4_message_valid,
  input      [11:0]   io_leftVertexInput_offloadGet4_message_instruction,
  input               io_leftVertexInput_offloadGet4_message_isReset,
  input      [1:0]    io_leftVertexInput_executeGet_state_speed,
  input      [4:0]    io_leftVertexInput_executeGet_state_node,
  input      [4:0]    io_leftVertexInput_executeGet_state_root,
  input               io_leftVertexInput_executeGet_state_isVirtual,
  input               io_leftVertexInput_executeGet_state_isDefect,
  input      [1:0]    io_leftVertexInput_executeGet_state_grown,
  input               io_leftVertexInput_executeGet_message_valid,
  input      [11:0]   io_leftVertexInput_executeGet_message_instruction,
  input               io_leftVertexInput_executeGet_message_isReset,
  input               io_leftVertexInput_executeGet_isStalled,
  input      [1:0]    io_leftVertexInput_executeGet2_state_speed,
  input      [4:0]    io_leftVertexInput_executeGet2_state_node,
  input      [4:0]    io_leftVertexInput_executeGet2_state_root,
  input               io_leftVertexInput_executeGet2_state_isVirtual,
  input               io_leftVertexInput_executeGet2_state_isDefect,
  input      [1:0]    io_leftVertexInput_executeGet2_state_grown,
  input               io_leftVertexInput_executeGet2_isStalled,
  input               io_leftVertexInput_executeGet2_compact_valid,
  input               io_leftVertexInput_executeGet2_compact_isReset,
  input      [1:0]    io_leftVertexInput_executeGet3_state_speed,
  input      [4:0]    io_leftVertexInput_executeGet3_state_node,
  input      [4:0]    io_leftVertexInput_executeGet3_state_root,
  input               io_leftVertexInput_executeGet3_state_isVirtual,
  input               io_leftVertexInput_executeGet3_state_isDefect,
  input      [1:0]    io_leftVertexInput_executeGet3_state_grown,
  input               io_leftVertexInput_executeGet3_isStalled,
  input               io_leftVertexInput_executeGet3_compact_valid,
  input               io_leftVertexInput_executeGet3_compact_isReset,
  input      [1:0]    io_leftVertexInput_updateGet_state_speed,
  input      [4:0]    io_leftVertexInput_updateGet_state_node,
  input      [4:0]    io_leftVertexInput_updateGet_state_root,
  input               io_leftVertexInput_updateGet_state_isVirtual,
  input               io_leftVertexInput_updateGet_state_isDefect,
  input      [1:0]    io_leftVertexInput_updateGet_state_grown,
  input               io_leftVertexInput_updateGet_isStalled,
  input               io_leftVertexInput_updateGet_compact_valid,
  input               io_leftVertexInput_updateGet_compact_isReset,
  input               io_leftVertexInput_updateGet_propagatingPeer_valid,
  input      [4:0]    io_leftVertexInput_updateGet_propagatingPeer_node,
  input      [4:0]    io_leftVertexInput_updateGet_propagatingPeer_root,
  input      [1:0]    io_leftVertexInput_updateGet2_state_speed,
  input      [4:0]    io_leftVertexInput_updateGet2_state_node,
  input      [4:0]    io_leftVertexInput_updateGet2_state_root,
  input               io_leftVertexInput_updateGet2_state_isVirtual,
  input               io_leftVertexInput_updateGet2_state_isDefect,
  input      [1:0]    io_leftVertexInput_updateGet2_state_grown,
  input               io_leftVertexInput_updateGet2_isStalled,
  input               io_leftVertexInput_updateGet2_compact_valid,
  input               io_leftVertexInput_updateGet2_compact_isReset,
  input               io_leftVertexInput_updateGet2_propagatingPeer_valid,
  input      [4:0]    io_leftVertexInput_updateGet2_propagatingPeer_node,
  input      [4:0]    io_leftVertexInput_updateGet2_propagatingPeer_root,
  input      [1:0]    io_leftVertexInput_updateGet3_state_speed,
  input      [4:0]    io_leftVertexInput_updateGet3_state_node,
  input      [4:0]    io_leftVertexInput_updateGet3_state_root,
  input               io_leftVertexInput_updateGet3_state_isVirtual,
  input               io_leftVertexInput_updateGet3_state_isDefect,
  input      [1:0]    io_leftVertexInput_updateGet3_state_grown,
  input      [1:0]    io_leftVertexInput_updateGet3_shadow_speed,
  input      [4:0]    io_leftVertexInput_updateGet3_shadow_node,
  input      [4:0]    io_leftVertexInput_updateGet3_shadow_root,
  input               io_leftVertexInput_updateGet3_compact_valid,
  input               io_leftVertexInput_updateGet3_compact_isReset,
  input      [1:0]    io_rightVertexInput_offloadGet_state_speed,
  input      [4:0]    io_rightVertexInput_offloadGet_state_node,
  input      [4:0]    io_rightVertexInput_offloadGet_state_root,
  input               io_rightVertexInput_offloadGet_state_isVirtual,
  input               io_rightVertexInput_offloadGet_state_isDefect,
  input      [1:0]    io_rightVertexInput_offloadGet_state_grown,
  input               io_rightVertexInput_offloadGet_message_valid,
  input      [11:0]   io_rightVertexInput_offloadGet_message_instruction,
  input               io_rightVertexInput_offloadGet_message_isReset,
  input      [1:0]    io_rightVertexInput_offloadGet2_state_speed,
  input      [4:0]    io_rightVertexInput_offloadGet2_state_node,
  input      [4:0]    io_rightVertexInput_offloadGet2_state_root,
  input               io_rightVertexInput_offloadGet2_state_isVirtual,
  input               io_rightVertexInput_offloadGet2_state_isDefect,
  input      [1:0]    io_rightVertexInput_offloadGet2_state_grown,
  input               io_rightVertexInput_offloadGet2_message_valid,
  input      [11:0]   io_rightVertexInput_offloadGet2_message_instruction,
  input               io_rightVertexInput_offloadGet2_message_isReset,
  input      [1:0]    io_rightVertexInput_offloadGet3_state_speed,
  input      [4:0]    io_rightVertexInput_offloadGet3_state_node,
  input      [4:0]    io_rightVertexInput_offloadGet3_state_root,
  input               io_rightVertexInput_offloadGet3_state_isVirtual,
  input               io_rightVertexInput_offloadGet3_state_isDefect,
  input      [1:0]    io_rightVertexInput_offloadGet3_state_grown,
  input               io_rightVertexInput_offloadGet3_message_valid,
  input      [11:0]   io_rightVertexInput_offloadGet3_message_instruction,
  input               io_rightVertexInput_offloadGet3_message_isReset,
  input               io_rightVertexInput_offloadGet3_isUniqueTight,
  input               io_rightVertexInput_offloadGet3_isIsolated,
  input      [1:0]    io_rightVertexInput_offloadGet4_state_speed,
  input      [4:0]    io_rightVertexInput_offloadGet4_state_node,
  input      [4:0]    io_rightVertexInput_offloadGet4_state_root,
  input               io_rightVertexInput_offloadGet4_state_isVirtual,
  input               io_rightVertexInput_offloadGet4_state_isDefect,
  input      [1:0]    io_rightVertexInput_offloadGet4_state_grown,
  input               io_rightVertexInput_offloadGet4_message_valid,
  input      [11:0]   io_rightVertexInput_offloadGet4_message_instruction,
  input               io_rightVertexInput_offloadGet4_message_isReset,
  input      [1:0]    io_rightVertexInput_executeGet_state_speed,
  input      [4:0]    io_rightVertexInput_executeGet_state_node,
  input      [4:0]    io_rightVertexInput_executeGet_state_root,
  input               io_rightVertexInput_executeGet_state_isVirtual,
  input               io_rightVertexInput_executeGet_state_isDefect,
  input      [1:0]    io_rightVertexInput_executeGet_state_grown,
  input               io_rightVertexInput_executeGet_message_valid,
  input      [11:0]   io_rightVertexInput_executeGet_message_instruction,
  input               io_rightVertexInput_executeGet_message_isReset,
  input               io_rightVertexInput_executeGet_isStalled,
  input      [1:0]    io_rightVertexInput_executeGet2_state_speed,
  input      [4:0]    io_rightVertexInput_executeGet2_state_node,
  input      [4:0]    io_rightVertexInput_executeGet2_state_root,
  input               io_rightVertexInput_executeGet2_state_isVirtual,
  input               io_rightVertexInput_executeGet2_state_isDefect,
  input      [1:0]    io_rightVertexInput_executeGet2_state_grown,
  input               io_rightVertexInput_executeGet2_isStalled,
  input               io_rightVertexInput_executeGet2_compact_valid,
  input               io_rightVertexInput_executeGet2_compact_isReset,
  input      [1:0]    io_rightVertexInput_executeGet3_state_speed,
  input      [4:0]    io_rightVertexInput_executeGet3_state_node,
  input      [4:0]    io_rightVertexInput_executeGet3_state_root,
  input               io_rightVertexInput_executeGet3_state_isVirtual,
  input               io_rightVertexInput_executeGet3_state_isDefect,
  input      [1:0]    io_rightVertexInput_executeGet3_state_grown,
  input               io_rightVertexInput_executeGet3_isStalled,
  input               io_rightVertexInput_executeGet3_compact_valid,
  input               io_rightVertexInput_executeGet3_compact_isReset,
  input      [1:0]    io_rightVertexInput_updateGet_state_speed,
  input      [4:0]    io_rightVertexInput_updateGet_state_node,
  input      [4:0]    io_rightVertexInput_updateGet_state_root,
  input               io_rightVertexInput_updateGet_state_isVirtual,
  input               io_rightVertexInput_updateGet_state_isDefect,
  input      [1:0]    io_rightVertexInput_updateGet_state_grown,
  input               io_rightVertexInput_updateGet_isStalled,
  input               io_rightVertexInput_updateGet_compact_valid,
  input               io_rightVertexInput_updateGet_compact_isReset,
  input               io_rightVertexInput_updateGet_propagatingPeer_valid,
  input      [4:0]    io_rightVertexInput_updateGet_propagatingPeer_node,
  input      [4:0]    io_rightVertexInput_updateGet_propagatingPeer_root,
  input      [1:0]    io_rightVertexInput_updateGet2_state_speed,
  input      [4:0]    io_rightVertexInput_updateGet2_state_node,
  input      [4:0]    io_rightVertexInput_updateGet2_state_root,
  input               io_rightVertexInput_updateGet2_state_isVirtual,
  input               io_rightVertexInput_updateGet2_state_isDefect,
  input      [1:0]    io_rightVertexInput_updateGet2_state_grown,
  input               io_rightVertexInput_updateGet2_isStalled,
  input               io_rightVertexInput_updateGet2_compact_valid,
  input               io_rightVertexInput_updateGet2_compact_isReset,
  input               io_rightVertexInput_updateGet2_propagatingPeer_valid,
  input      [4:0]    io_rightVertexInput_updateGet2_propagatingPeer_node,
  input      [4:0]    io_rightVertexInput_updateGet2_propagatingPeer_root,
  input      [1:0]    io_rightVertexInput_updateGet3_state_speed,
  input      [4:0]    io_rightVertexInput_updateGet3_state_node,
  input      [4:0]    io_rightVertexInput_updateGet3_state_root,
  input               io_rightVertexInput_updateGet3_state_isVirtual,
  input               io_rightVertexInput_updateGet3_state_isDefect,
  input      [1:0]    io_rightVertexInput_updateGet3_state_grown,
  input      [1:0]    io_rightVertexInput_updateGet3_shadow_speed,
  input      [4:0]    io_rightVertexInput_updateGet3_shadow_node,
  input      [4:0]    io_rightVertexInput_updateGet3_shadow_root,
  input               io_rightVertexInput_updateGet3_compact_valid,
  input               io_rightVertexInput_updateGet3_compact_isReset,
  output     [1:0]    io_maxGrowable_length,
  output     [4:0]    io_conflict_node1,
  output     [4:0]    io_conflict_node2,
  output     [4:0]    io_conflict_touch1,
  output     [4:0]    io_conflict_touch2,
  output     [4:0]    io_conflict_vertex1,
  output     [4:0]    io_conflict_vertex2,
  output              io_conflict_valid
);

  wire                offload2Area_edgeIsTight_io_isTight;
  wire                execute3Area_edgeIsTight_io_isTight;
  wire       [1:0]    updateArea_edgeRemaining_io_remaining;
  wire       [1:0]    edgeResponse_3_io_maxGrowable_length;
  wire       [4:0]    edgeResponse_3_io_conflict_node1;
  wire       [4:0]    edgeResponse_3_io_conflict_node2;
  wire       [4:0]    edgeResponse_3_io_conflict_touch1;
  wire       [4:0]    edgeResponse_3_io_conflict_touch2;
  wire       [4:0]    edgeResponse_3_io_conflict_vertex1;
  wire       [4:0]    edgeResponse_3_io_conflict_vertex2;
  wire                edgeResponse_3_io_conflict_valid;
  wire       [1:0]    stages_offloadSet_state_weight;
  wire                stages_offloadSet_compact_valid;
  wire                stages_offloadSet_compact_isReset;
  wire       [1:0]    stages_offloadGet_state_weight;
  wire                stages_offloadGet_compact_valid;
  wire                stages_offloadGet_compact_isReset;
  wire       [1:0]    stages_offloadSet2_state_weight;
  wire                stages_offloadSet2_isTight;
  wire                stages_offloadSet2_isTightExFusion;
  wire                stages_offloadSet2_compact_valid;
  wire                stages_offloadSet2_compact_isReset;
  wire       [1:0]    stages_offloadGet2_state_weight;
  wire                stages_offloadGet2_isTight;
  wire                stages_offloadGet2_isTightExFusion;
  wire                stages_offloadGet2_compact_valid;
  wire                stages_offloadGet2_compact_isReset;
  wire       [1:0]    stages_offloadSet3_state_weight;
  wire                stages_offloadSet3_isTight;
  wire                stages_offloadSet3_compact_valid;
  wire                stages_offloadSet3_compact_isReset;
  wire       [1:0]    stages_offloadGet3_state_weight;
  wire                stages_offloadGet3_isTight;
  wire                stages_offloadGet3_compact_valid;
  wire                stages_offloadGet3_compact_isReset;
  wire       [1:0]    stages_offloadSet4_state_weight;
  wire                stages_offloadSet4_compact_valid;
  wire                stages_offloadSet4_compact_isReset;
  wire       [1:0]    stages_offloadGet4_state_weight;
  wire                stages_offloadGet4_compact_valid;
  wire                stages_offloadGet4_compact_isReset;
  wire       [1:0]    stages_executeSet_state_weight;
  wire                stages_executeSet_compact_valid;
  wire                stages_executeSet_compact_isReset;
  wire       [1:0]    stages_executeGet_state_weight;
  wire                stages_executeGet_compact_valid;
  wire                stages_executeGet_compact_isReset;
  wire       [1:0]    stages_executeSet2_state_weight;
  wire                stages_executeSet2_compact_valid;
  wire                stages_executeSet2_compact_isReset;
  wire       [1:0]    stages_executeGet2_state_weight;
  wire                stages_executeGet2_compact_valid;
  wire                stages_executeGet2_compact_isReset;
  wire       [1:0]    stages_executeSet3_state_weight;
  wire                stages_executeSet3_isTight;
  wire                stages_executeSet3_compact_valid;
  wire                stages_executeSet3_compact_isReset;
  wire       [1:0]    stages_executeGet3_state_weight;
  wire                stages_executeGet3_isTight;
  wire                stages_executeGet3_compact_valid;
  wire                stages_executeGet3_compact_isReset;
  wire       [1:0]    stages_updateSet_state_weight;
  wire       [1:0]    stages_updateSet_remaining;
  wire                stages_updateSet_compact_valid;
  wire                stages_updateSet_compact_isReset;
  wire       [1:0]    stages_updateGet_state_weight;
  wire       [1:0]    stages_updateGet_remaining;
  wire                stages_updateGet_compact_valid;
  wire                stages_updateGet_compact_isReset;
  wire       [1:0]    stages_updateSet2_state_weight;
  wire       [1:0]    stages_updateSet2_remaining;
  wire                stages_updateSet2_compact_valid;
  wire                stages_updateSet2_compact_isReset;
  wire       [1:0]    stages_updateGet2_state_weight;
  wire       [1:0]    stages_updateGet2_remaining;
  wire                stages_updateGet2_compact_valid;
  wire                stages_updateGet2_compact_isReset;
  wire       [1:0]    stages_updateSet3_state_weight;
  wire       [1:0]    stages_updateSet3_remaining;
  wire                stages_updateSet3_compact_valid;
  wire                stages_updateSet3_compact_isReset;
  wire       [1:0]    stages_updateGet3_state_weight;
  wire       [1:0]    stages_updateGet3_remaining;
  wire                stages_updateGet3_compact_valid;
  wire                stages_updateGet3_compact_isReset;
  wire       [1:0]    fetchState_weight;
  wire                message_valid;
  wire       [11:0]   message_instruction;
  wire                message_isReset;
  wire                conditionedVertexIsVirtual;
  wire       [1:0]    offload2Weight;

  EdgeIsTight_4 offload2Area_edgeIsTight (
    .io_leftGrown  (io_leftVertexInput_offloadGet_state_grown[1:0] ), //i
    .io_rightGrown (io_rightVertexInput_offloadGet_state_grown[1:0]), //i
    .io_weight     (offload2Weight[1:0]                            ), //i
    .io_isTight    (offload2Area_edgeIsTight_io_isTight            )  //o
  );
  EdgeIsTight_4 execute3Area_edgeIsTight (
    .io_leftGrown  (io_leftVertexInput_executeGet2_state_grown[1:0] ), //i
    .io_rightGrown (io_rightVertexInput_executeGet2_state_grown[1:0]), //i
    .io_weight     (stages_executeGet2_state_weight[1:0]            ), //i
    .io_isTight    (execute3Area_edgeIsTight_io_isTight             )  //o
  );
  EdgeRemaining_2 updateArea_edgeRemaining (
    .io_leftGrown  (io_leftVertexInput_executeGet3_state_grown[1:0] ), //i
    .io_rightGrown (io_rightVertexInput_executeGet3_state_grown[1:0]), //i
    .io_weight     (stages_executeGet3_state_weight[1:0]            ), //i
    .io_remaining  (updateArea_edgeRemaining_io_remaining[1:0]      )  //o
  );
  EdgeResponse_2 edgeResponse_3 (
    .io_leftShadow_speed   (io_leftVertexInput_updateGet3_shadow_speed[1:0] ), //i
    .io_leftShadow_node    (io_leftVertexInput_updateGet3_shadow_node[4:0]  ), //i
    .io_leftShadow_root    (io_leftVertexInput_updateGet3_shadow_root[4:0]  ), //i
    .io_rightShadow_speed  (io_rightVertexInput_updateGet3_shadow_speed[1:0]), //i
    .io_rightShadow_node   (io_rightVertexInput_updateGet3_shadow_node[4:0] ), //i
    .io_rightShadow_root   (io_rightVertexInput_updateGet3_shadow_root[4:0] ), //i
    .io_leftIsVirtual      (io_leftVertexInput_updateGet3_state_isVirtual   ), //i
    .io_rightIsVirtual     (io_rightVertexInput_updateGet3_state_isVirtual  ), //i
    .io_leftVertex         (5'h00                                           ), //i
    .io_rightVertex        (5'h01                                           ), //i
    .io_remaining          (stages_updateGet3_remaining[1:0]                ), //i
    .io_maxGrowable_length (edgeResponse_3_io_maxGrowable_length[1:0]       ), //o
    .io_conflict_node1     (edgeResponse_3_io_conflict_node1[4:0]           ), //o
    .io_conflict_node2     (edgeResponse_3_io_conflict_node2[4:0]           ), //o
    .io_conflict_touch1    (edgeResponse_3_io_conflict_touch1[4:0]          ), //o
    .io_conflict_touch2    (edgeResponse_3_io_conflict_touch2[4:0]          ), //o
    .io_conflict_vertex1   (edgeResponse_3_io_conflict_vertex1[4:0]         ), //o
    .io_conflict_vertex2   (edgeResponse_3_io_conflict_vertex2[4:0]         ), //o
    .io_conflict_valid     (edgeResponse_3_io_conflict_valid                )  //o
  );
  assign io_stageOutputs_offloadGet_state_weight = stages_offloadGet_state_weight;
  assign io_stageOutputs_offloadGet_compact_valid = stages_offloadGet_compact_valid;
  assign io_stageOutputs_offloadGet_compact_isReset = stages_offloadGet_compact_isReset;
  assign io_stageOutputs_offloadGet2_state_weight = stages_offloadGet2_state_weight;
  assign io_stageOutputs_offloadGet2_isTight = stages_offloadGet2_isTight;
  assign io_stageOutputs_offloadGet2_isTightExFusion = stages_offloadGet2_isTightExFusion;
  assign io_stageOutputs_offloadGet2_compact_valid = stages_offloadGet2_compact_valid;
  assign io_stageOutputs_offloadGet2_compact_isReset = stages_offloadGet2_compact_isReset;
  assign io_stageOutputs_offloadGet3_state_weight = stages_offloadGet3_state_weight;
  assign io_stageOutputs_offloadGet3_isTight = stages_offloadGet3_isTight;
  assign io_stageOutputs_offloadGet3_compact_valid = stages_offloadGet3_compact_valid;
  assign io_stageOutputs_offloadGet3_compact_isReset = stages_offloadGet3_compact_isReset;
  assign io_stageOutputs_offloadGet4_state_weight = stages_offloadGet4_state_weight;
  assign io_stageOutputs_offloadGet4_compact_valid = stages_offloadGet4_compact_valid;
  assign io_stageOutputs_offloadGet4_compact_isReset = stages_offloadGet4_compact_isReset;
  assign io_stageOutputs_executeGet_state_weight = stages_executeGet_state_weight;
  assign io_stageOutputs_executeGet_compact_valid = stages_executeGet_compact_valid;
  assign io_stageOutputs_executeGet_compact_isReset = stages_executeGet_compact_isReset;
  assign io_stageOutputs_executeGet2_state_weight = stages_executeGet2_state_weight;
  assign io_stageOutputs_executeGet2_compact_valid = stages_executeGet2_compact_valid;
  assign io_stageOutputs_executeGet2_compact_isReset = stages_executeGet2_compact_isReset;
  assign io_stageOutputs_executeGet3_state_weight = stages_executeGet3_state_weight;
  assign io_stageOutputs_executeGet3_isTight = stages_executeGet3_isTight;
  assign io_stageOutputs_executeGet3_compact_valid = stages_executeGet3_compact_valid;
  assign io_stageOutputs_executeGet3_compact_isReset = stages_executeGet3_compact_isReset;
  assign io_stageOutputs_updateGet_state_weight = stages_updateGet_state_weight;
  assign io_stageOutputs_updateGet_remaining = stages_updateGet_remaining;
  assign io_stageOutputs_updateGet_compact_valid = stages_updateGet_compact_valid;
  assign io_stageOutputs_updateGet_compact_isReset = stages_updateGet_compact_isReset;
  assign io_stageOutputs_updateGet2_state_weight = stages_updateGet2_state_weight;
  assign io_stageOutputs_updateGet2_remaining = stages_updateGet2_remaining;
  assign io_stageOutputs_updateGet2_compact_valid = stages_updateGet2_compact_valid;
  assign io_stageOutputs_updateGet2_compact_isReset = stages_updateGet2_compact_isReset;
  assign io_stageOutputs_updateGet3_state_weight = stages_updateGet3_state_weight;
  assign io_stageOutputs_updateGet3_remaining = stages_updateGet3_remaining;
  assign io_stageOutputs_updateGet3_compact_valid = stages_updateGet3_compact_valid;
  assign io_stageOutputs_updateGet3_compact_isReset = stages_updateGet3_compact_isReset;
  assign fetchState_weight = 2'b10;
  assign message_valid = io_message_valid;
  assign message_instruction = io_message_instruction;
  assign message_isReset = io_message_isReset;
  assign stages_offloadSet_state_weight = fetchState_weight;
  assign stages_offloadSet_compact_valid = message_valid;
  assign stages_offloadSet_compact_isReset = message_isReset;
  assign stages_offloadSet2_state_weight = stages_offloadGet_state_weight;
  assign stages_offloadSet2_compact_valid = stages_offloadGet_compact_valid;
  assign stages_offloadSet2_compact_isReset = stages_offloadGet_compact_isReset;
  assign conditionedVertexIsVirtual = 1'b0;
  assign offload2Weight = stages_offloadGet_state_weight;
  assign stages_offloadSet2_isTight = offload2Area_edgeIsTight_io_isTight;
  assign stages_offloadSet2_isTightExFusion = offload2Area_edgeIsTight_io_isTight;
  assign stages_offloadSet3_state_weight = stages_offloadGet2_state_weight;
  assign stages_offloadSet3_isTight = stages_offloadGet2_isTight;
  assign stages_offloadSet3_compact_valid = stages_offloadGet2_compact_valid;
  assign stages_offloadSet3_compact_isReset = stages_offloadGet2_compact_isReset;
  assign stages_offloadSet4_state_weight = stages_offloadGet3_state_weight;
  assign stages_offloadSet4_compact_valid = stages_offloadGet3_compact_valid;
  assign stages_offloadSet4_compact_isReset = stages_offloadGet3_compact_isReset;
  assign stages_executeSet_state_weight = stages_offloadGet4_state_weight;
  assign stages_executeSet_compact_valid = stages_offloadGet4_compact_valid;
  assign stages_executeSet_compact_isReset = stages_offloadGet4_compact_isReset;
  assign stages_executeSet2_state_weight = stages_executeGet_state_weight;
  assign stages_executeSet2_compact_valid = stages_executeGet_compact_valid;
  assign stages_executeSet2_compact_isReset = stages_executeGet_compact_isReset;
  assign stages_executeSet3_state_weight = stages_executeGet2_state_weight;
  assign stages_executeSet3_compact_valid = stages_executeGet2_compact_valid;
  assign stages_executeSet3_compact_isReset = stages_executeGet2_compact_isReset;
  assign stages_executeSet3_isTight = execute3Area_edgeIsTight_io_isTight;
  assign stages_updateSet_state_weight = stages_executeGet3_state_weight;
  assign stages_updateSet_compact_valid = stages_executeGet3_compact_valid;
  assign stages_updateSet_compact_isReset = stages_executeGet3_compact_isReset;
  assign stages_updateSet_remaining = updateArea_edgeRemaining_io_remaining;
  assign stages_updateSet2_state_weight = stages_updateGet_state_weight;
  assign stages_updateSet2_remaining = stages_updateGet_remaining;
  assign stages_updateSet2_compact_valid = stages_updateGet_compact_valid;
  assign stages_updateSet2_compact_isReset = stages_updateGet_compact_isReset;
  assign stages_updateSet3_state_weight = stages_updateGet2_state_weight;
  assign stages_updateSet3_remaining = stages_updateGet2_remaining;
  assign stages_updateSet3_compact_valid = stages_updateGet2_compact_valid;
  assign stages_updateSet3_compact_isReset = stages_updateGet2_compact_isReset;
  assign io_maxGrowable_length = edgeResponse_3_io_maxGrowable_length;
  assign io_conflict_node1 = edgeResponse_3_io_conflict_node1;
  assign io_conflict_node2 = edgeResponse_3_io_conflict_node2;
  assign io_conflict_touch1 = edgeResponse_3_io_conflict_touch1;
  assign io_conflict_touch2 = edgeResponse_3_io_conflict_touch2;
  assign io_conflict_vertex1 = edgeResponse_3_io_conflict_vertex1;
  assign io_conflict_vertex2 = edgeResponse_3_io_conflict_vertex2;
  assign io_conflict_valid = edgeResponse_3_io_conflict_valid;
  assign stages_executeGet3_state_weight = stages_executeSet3_state_weight;
  assign stages_executeGet3_isTight = stages_executeSet3_isTight;
  assign stages_executeGet3_compact_valid = stages_executeSet3_compact_valid;
  assign stages_executeGet3_compact_isReset = stages_executeSet3_compact_isReset;
  assign stages_updateGet_state_weight = stages_updateSet_state_weight;
  assign stages_updateGet_remaining = stages_updateSet_remaining;
  assign stages_updateGet_compact_valid = stages_updateSet_compact_valid;
  assign stages_updateGet_compact_isReset = stages_updateSet_compact_isReset;
  assign stages_offloadGet_state_weight = stages_offloadSet_state_weight;
  assign stages_offloadGet_compact_valid = stages_offloadSet_compact_valid;
  assign stages_offloadGet_compact_isReset = stages_offloadSet_compact_isReset;
  assign stages_offloadGet4_state_weight = stages_offloadSet4_state_weight;
  assign stages_offloadGet4_compact_valid = stages_offloadSet4_compact_valid;
  assign stages_offloadGet4_compact_isReset = stages_offloadSet4_compact_isReset;
  assign stages_updateGet3_state_weight = stages_updateSet3_state_weight;
  assign stages_updateGet3_remaining = stages_updateSet3_remaining;
  assign stages_updateGet3_compact_valid = stages_updateSet3_compact_valid;
  assign stages_updateGet3_compact_isReset = stages_updateSet3_compact_isReset;
  assign stages_executeGet_state_weight = stages_executeSet_state_weight;
  assign stages_executeGet_compact_valid = stages_executeSet_compact_valid;
  assign stages_executeGet_compact_isReset = stages_executeSet_compact_isReset;
  assign stages_executeGet2_state_weight = stages_executeSet2_state_weight;
  assign stages_executeGet2_compact_valid = stages_executeSet2_compact_valid;
  assign stages_executeGet2_compact_isReset = stages_executeSet2_compact_isReset;
  assign stages_offloadGet3_state_weight = stages_offloadSet3_state_weight;
  assign stages_offloadGet3_isTight = stages_offloadSet3_isTight;
  assign stages_offloadGet3_compact_valid = stages_offloadSet3_compact_valid;
  assign stages_offloadGet3_compact_isReset = stages_offloadSet3_compact_isReset;
  assign stages_updateGet2_state_weight = stages_updateSet2_state_weight;
  assign stages_updateGet2_remaining = stages_updateSet2_remaining;
  assign stages_updateGet2_compact_valid = stages_updateSet2_compact_valid;
  assign stages_updateGet2_compact_isReset = stages_updateSet2_compact_isReset;
  assign stages_offloadGet2_state_weight = stages_offloadSet2_state_weight;
  assign stages_offloadGet2_isTight = stages_offloadSet2_isTight;
  assign stages_offloadGet2_isTightExFusion = stages_offloadSet2_isTightExFusion;
  assign stages_offloadGet2_compact_valid = stages_offloadSet2_compact_valid;
  assign stages_offloadGet2_compact_isReset = stages_offloadSet2_compact_isReset;

endmodule

module Vertex_3 (
  input               io_message_valid,
  input      [11:0]   io_message_instruction,
  input               io_message_isReset,
  output     [1:0]    io_stageOutputs_offloadGet_state_speed,
  output     [4:0]    io_stageOutputs_offloadGet_state_node,
  output     [4:0]    io_stageOutputs_offloadGet_state_root,
  output              io_stageOutputs_offloadGet_state_isVirtual,
  output              io_stageOutputs_offloadGet_state_isDefect,
  output     [1:0]    io_stageOutputs_offloadGet_state_grown,
  output              io_stageOutputs_offloadGet_message_valid,
  output     [11:0]   io_stageOutputs_offloadGet_message_instruction,
  output              io_stageOutputs_offloadGet_message_isReset,
  output     [1:0]    io_stageOutputs_offloadGet2_state_speed,
  output     [4:0]    io_stageOutputs_offloadGet2_state_node,
  output     [4:0]    io_stageOutputs_offloadGet2_state_root,
  output              io_stageOutputs_offloadGet2_state_isVirtual,
  output              io_stageOutputs_offloadGet2_state_isDefect,
  output     [1:0]    io_stageOutputs_offloadGet2_state_grown,
  output              io_stageOutputs_offloadGet2_message_valid,
  output     [11:0]   io_stageOutputs_offloadGet2_message_instruction,
  output              io_stageOutputs_offloadGet2_message_isReset,
  output     [1:0]    io_stageOutputs_offloadGet3_state_speed,
  output     [4:0]    io_stageOutputs_offloadGet3_state_node,
  output     [4:0]    io_stageOutputs_offloadGet3_state_root,
  output              io_stageOutputs_offloadGet3_state_isVirtual,
  output              io_stageOutputs_offloadGet3_state_isDefect,
  output     [1:0]    io_stageOutputs_offloadGet3_state_grown,
  output              io_stageOutputs_offloadGet3_message_valid,
  output     [11:0]   io_stageOutputs_offloadGet3_message_instruction,
  output              io_stageOutputs_offloadGet3_message_isReset,
  output              io_stageOutputs_offloadGet3_isUniqueTight,
  output              io_stageOutputs_offloadGet3_isIsolated,
  output     [1:0]    io_stageOutputs_offloadGet4_state_speed,
  output     [4:0]    io_stageOutputs_offloadGet4_state_node,
  output     [4:0]    io_stageOutputs_offloadGet4_state_root,
  output              io_stageOutputs_offloadGet4_state_isVirtual,
  output              io_stageOutputs_offloadGet4_state_isDefect,
  output     [1:0]    io_stageOutputs_offloadGet4_state_grown,
  output              io_stageOutputs_offloadGet4_message_valid,
  output     [11:0]   io_stageOutputs_offloadGet4_message_instruction,
  output              io_stageOutputs_offloadGet4_message_isReset,
  output     [1:0]    io_stageOutputs_executeGet_state_speed,
  output     [4:0]    io_stageOutputs_executeGet_state_node,
  output     [4:0]    io_stageOutputs_executeGet_state_root,
  output              io_stageOutputs_executeGet_state_isVirtual,
  output              io_stageOutputs_executeGet_state_isDefect,
  output     [1:0]    io_stageOutputs_executeGet_state_grown,
  output              io_stageOutputs_executeGet_message_valid,
  output     [11:0]   io_stageOutputs_executeGet_message_instruction,
  output              io_stageOutputs_executeGet_message_isReset,
  output              io_stageOutputs_executeGet_isStalled,
  output     [1:0]    io_stageOutputs_executeGet2_state_speed,
  output     [4:0]    io_stageOutputs_executeGet2_state_node,
  output     [4:0]    io_stageOutputs_executeGet2_state_root,
  output              io_stageOutputs_executeGet2_state_isVirtual,
  output              io_stageOutputs_executeGet2_state_isDefect,
  output     [1:0]    io_stageOutputs_executeGet2_state_grown,
  output              io_stageOutputs_executeGet2_isStalled,
  output              io_stageOutputs_executeGet2_compact_valid,
  output              io_stageOutputs_executeGet2_compact_isReset,
  output     [1:0]    io_stageOutputs_executeGet3_state_speed,
  output     [4:0]    io_stageOutputs_executeGet3_state_node,
  output     [4:0]    io_stageOutputs_executeGet3_state_root,
  output              io_stageOutputs_executeGet3_state_isVirtual,
  output              io_stageOutputs_executeGet3_state_isDefect,
  output     [1:0]    io_stageOutputs_executeGet3_state_grown,
  output              io_stageOutputs_executeGet3_isStalled,
  output              io_stageOutputs_executeGet3_compact_valid,
  output              io_stageOutputs_executeGet3_compact_isReset,
  output     [1:0]    io_stageOutputs_updateGet_state_speed,
  output     [4:0]    io_stageOutputs_updateGet_state_node,
  output     [4:0]    io_stageOutputs_updateGet_state_root,
  output              io_stageOutputs_updateGet_state_isVirtual,
  output              io_stageOutputs_updateGet_state_isDefect,
  output     [1:0]    io_stageOutputs_updateGet_state_grown,
  output              io_stageOutputs_updateGet_isStalled,
  output              io_stageOutputs_updateGet_compact_valid,
  output              io_stageOutputs_updateGet_compact_isReset,
  output              io_stageOutputs_updateGet_propagatingPeer_valid,
  output     [4:0]    io_stageOutputs_updateGet_propagatingPeer_node,
  output     [4:0]    io_stageOutputs_updateGet_propagatingPeer_root,
  output     [1:0]    io_stageOutputs_updateGet2_state_speed,
  output     [4:0]    io_stageOutputs_updateGet2_state_node,
  output     [4:0]    io_stageOutputs_updateGet2_state_root,
  output              io_stageOutputs_updateGet2_state_isVirtual,
  output              io_stageOutputs_updateGet2_state_isDefect,
  output     [1:0]    io_stageOutputs_updateGet2_state_grown,
  output              io_stageOutputs_updateGet2_isStalled,
  output              io_stageOutputs_updateGet2_compact_valid,
  output              io_stageOutputs_updateGet2_compact_isReset,
  output              io_stageOutputs_updateGet2_propagatingPeer_valid,
  output     [4:0]    io_stageOutputs_updateGet2_propagatingPeer_node,
  output     [4:0]    io_stageOutputs_updateGet2_propagatingPeer_root,
  output     [1:0]    io_stageOutputs_updateGet3_state_speed,
  output     [4:0]    io_stageOutputs_updateGet3_state_node,
  output     [4:0]    io_stageOutputs_updateGet3_state_root,
  output              io_stageOutputs_updateGet3_state_isVirtual,
  output              io_stageOutputs_updateGet3_state_isDefect,
  output     [1:0]    io_stageOutputs_updateGet3_state_grown,
  output     [1:0]    io_stageOutputs_updateGet3_shadow_speed,
  output     [4:0]    io_stageOutputs_updateGet3_shadow_node,
  output     [4:0]    io_stageOutputs_updateGet3_shadow_root,
  output              io_stageOutputs_updateGet3_compact_valid,
  output              io_stageOutputs_updateGet3_compact_isReset,
  input      [1:0]    io_edgeInputs_0_offloadGet_state_weight,
  input               io_edgeInputs_0_offloadGet_compact_valid,
  input               io_edgeInputs_0_offloadGet_compact_isReset,
  input      [1:0]    io_edgeInputs_0_offloadGet2_state_weight,
  input               io_edgeInputs_0_offloadGet2_isTight,
  input               io_edgeInputs_0_offloadGet2_isTightExFusion,
  input               io_edgeInputs_0_offloadGet2_compact_valid,
  input               io_edgeInputs_0_offloadGet2_compact_isReset,
  input      [1:0]    io_edgeInputs_0_offloadGet3_state_weight,
  input               io_edgeInputs_0_offloadGet3_isTight,
  input               io_edgeInputs_0_offloadGet3_compact_valid,
  input               io_edgeInputs_0_offloadGet3_compact_isReset,
  input      [1:0]    io_edgeInputs_0_offloadGet4_state_weight,
  input               io_edgeInputs_0_offloadGet4_compact_valid,
  input               io_edgeInputs_0_offloadGet4_compact_isReset,
  input      [1:0]    io_edgeInputs_0_executeGet_state_weight,
  input               io_edgeInputs_0_executeGet_compact_valid,
  input               io_edgeInputs_0_executeGet_compact_isReset,
  input      [1:0]    io_edgeInputs_0_executeGet2_state_weight,
  input               io_edgeInputs_0_executeGet2_compact_valid,
  input               io_edgeInputs_0_executeGet2_compact_isReset,
  input      [1:0]    io_edgeInputs_0_executeGet3_state_weight,
  input               io_edgeInputs_0_executeGet3_isTight,
  input               io_edgeInputs_0_executeGet3_compact_valid,
  input               io_edgeInputs_0_executeGet3_compact_isReset,
  input      [1:0]    io_edgeInputs_0_updateGet_state_weight,
  input      [1:0]    io_edgeInputs_0_updateGet_remaining,
  input               io_edgeInputs_0_updateGet_compact_valid,
  input               io_edgeInputs_0_updateGet_compact_isReset,
  input      [1:0]    io_edgeInputs_0_updateGet2_state_weight,
  input      [1:0]    io_edgeInputs_0_updateGet2_remaining,
  input               io_edgeInputs_0_updateGet2_compact_valid,
  input               io_edgeInputs_0_updateGet2_compact_isReset,
  input      [1:0]    io_edgeInputs_0_updateGet3_state_weight,
  input      [1:0]    io_edgeInputs_0_updateGet3_remaining,
  input               io_edgeInputs_0_updateGet3_compact_valid,
  input               io_edgeInputs_0_updateGet3_compact_isReset,
  input      [1:0]    _zz_io_peerSpeed_0,
  input      [4:0]    _zz_io_peerNode_0,
  input      [4:0]    _zz_io_peerRoot_0,
  output     [1:0]    io_maxGrowable_length,
  input               clk,
  input               reset
);

  wire                offload3Area_tightCounter_io_isUnique;
  wire                offload3Area_tightCounter_io_isIsolated;
  wire                executeArea_offloadStalled_io_isStalled;
  wire       [1:0]    execute2Area_vertexPostExecuteState_io_after_speed;
  wire       [4:0]    execute2Area_vertexPostExecuteState_io_after_node;
  wire       [4:0]    execute2Area_vertexPostExecuteState_io_after_root;
  wire                execute2Area_vertexPostExecuteState_io_after_isVirtual;
  wire                execute2Area_vertexPostExecuteState_io_after_isDefect;
  wire       [1:0]    execute2Area_vertexPostExecuteState_io_after_grown;
  wire                updateArea_vertexPropagatingPeer_io_peer_valid;
  wire       [4:0]    updateArea_vertexPropagatingPeer_io_peer_node;
  wire       [4:0]    updateArea_vertexPropagatingPeer_io_peer_root;
  wire       [1:0]    update2Area_vertexPostUpdateState_io_after_speed;
  wire       [4:0]    update2Area_vertexPostUpdateState_io_after_node;
  wire       [4:0]    update2Area_vertexPostUpdateState_io_after_root;
  wire                update2Area_vertexPostUpdateState_io_after_isVirtual;
  wire                update2Area_vertexPostUpdateState_io_after_isDefect;
  wire       [1:0]    update2Area_vertexPostUpdateState_io_after_grown;
  wire       [1:0]    update3Area_vertexShadow_io_shadow_speed;
  wire       [4:0]    update3Area_vertexShadow_io_shadow_node;
  wire       [4:0]    update3Area_vertexShadow_io_shadow_root;
  wire       [1:0]    vertexResponse_4_io_maxGrowable_length;
  wire       [1:0]    stages_offloadSet_state_speed;
  wire       [4:0]    stages_offloadSet_state_node;
  wire       [4:0]    stages_offloadSet_state_root;
  wire                stages_offloadSet_state_isVirtual;
  wire                stages_offloadSet_state_isDefect;
  wire       [1:0]    stages_offloadSet_state_grown;
  wire                stages_offloadSet_message_valid;
  wire       [11:0]   stages_offloadSet_message_instruction;
  wire                stages_offloadSet_message_isReset;
  wire       [1:0]    stages_offloadGet_state_speed;
  wire       [4:0]    stages_offloadGet_state_node;
  wire       [4:0]    stages_offloadGet_state_root;
  wire                stages_offloadGet_state_isVirtual;
  wire                stages_offloadGet_state_isDefect;
  wire       [1:0]    stages_offloadGet_state_grown;
  wire                stages_offloadGet_message_valid;
  wire       [11:0]   stages_offloadGet_message_instruction;
  wire                stages_offloadGet_message_isReset;
  wire       [1:0]    stages_offloadSet2_state_speed;
  wire       [4:0]    stages_offloadSet2_state_node;
  wire       [4:0]    stages_offloadSet2_state_root;
  wire                stages_offloadSet2_state_isVirtual;
  wire                stages_offloadSet2_state_isDefect;
  wire       [1:0]    stages_offloadSet2_state_grown;
  wire                stages_offloadSet2_message_valid;
  wire       [11:0]   stages_offloadSet2_message_instruction;
  wire                stages_offloadSet2_message_isReset;
  wire       [1:0]    stages_offloadGet2_state_speed;
  wire       [4:0]    stages_offloadGet2_state_node;
  wire       [4:0]    stages_offloadGet2_state_root;
  wire                stages_offloadGet2_state_isVirtual;
  wire                stages_offloadGet2_state_isDefect;
  wire       [1:0]    stages_offloadGet2_state_grown;
  wire                stages_offloadGet2_message_valid;
  wire       [11:0]   stages_offloadGet2_message_instruction;
  wire                stages_offloadGet2_message_isReset;
  wire       [1:0]    stages_offloadSet3_state_speed;
  wire       [4:0]    stages_offloadSet3_state_node;
  wire       [4:0]    stages_offloadSet3_state_root;
  wire                stages_offloadSet3_state_isVirtual;
  wire                stages_offloadSet3_state_isDefect;
  wire       [1:0]    stages_offloadSet3_state_grown;
  wire                stages_offloadSet3_message_valid;
  wire       [11:0]   stages_offloadSet3_message_instruction;
  wire                stages_offloadSet3_message_isReset;
  wire                stages_offloadSet3_isUniqueTight;
  wire                stages_offloadSet3_isIsolated;
  wire       [1:0]    stages_offloadGet3_state_speed;
  wire       [4:0]    stages_offloadGet3_state_node;
  wire       [4:0]    stages_offloadGet3_state_root;
  wire                stages_offloadGet3_state_isVirtual;
  wire                stages_offloadGet3_state_isDefect;
  wire       [1:0]    stages_offloadGet3_state_grown;
  wire                stages_offloadGet3_message_valid;
  wire       [11:0]   stages_offloadGet3_message_instruction;
  wire                stages_offloadGet3_message_isReset;
  wire                stages_offloadGet3_isUniqueTight;
  wire                stages_offloadGet3_isIsolated;
  wire       [1:0]    stages_offloadSet4_state_speed;
  wire       [4:0]    stages_offloadSet4_state_node;
  wire       [4:0]    stages_offloadSet4_state_root;
  wire                stages_offloadSet4_state_isVirtual;
  wire                stages_offloadSet4_state_isDefect;
  wire       [1:0]    stages_offloadSet4_state_grown;
  wire                stages_offloadSet4_message_valid;
  wire       [11:0]   stages_offloadSet4_message_instruction;
  wire                stages_offloadSet4_message_isReset;
  wire       [1:0]    stages_offloadGet4_state_speed;
  wire       [4:0]    stages_offloadGet4_state_node;
  wire       [4:0]    stages_offloadGet4_state_root;
  wire                stages_offloadGet4_state_isVirtual;
  wire                stages_offloadGet4_state_isDefect;
  wire       [1:0]    stages_offloadGet4_state_grown;
  wire                stages_offloadGet4_message_valid;
  wire       [11:0]   stages_offloadGet4_message_instruction;
  wire                stages_offloadGet4_message_isReset;
  wire       [1:0]    stages_executeSet_state_speed;
  wire       [4:0]    stages_executeSet_state_node;
  wire       [4:0]    stages_executeSet_state_root;
  wire                stages_executeSet_state_isVirtual;
  wire                stages_executeSet_state_isDefect;
  wire       [1:0]    stages_executeSet_state_grown;
  wire                stages_executeSet_message_valid;
  wire       [11:0]   stages_executeSet_message_instruction;
  wire                stages_executeSet_message_isReset;
  wire                stages_executeSet_isStalled;
  wire       [1:0]    stages_executeGet_state_speed;
  wire       [4:0]    stages_executeGet_state_node;
  wire       [4:0]    stages_executeGet_state_root;
  wire                stages_executeGet_state_isVirtual;
  wire                stages_executeGet_state_isDefect;
  wire       [1:0]    stages_executeGet_state_grown;
  wire                stages_executeGet_message_valid;
  wire       [11:0]   stages_executeGet_message_instruction;
  wire                stages_executeGet_message_isReset;
  wire                stages_executeGet_isStalled;
  wire       [1:0]    stages_executeSet2_state_speed;
  wire       [4:0]    stages_executeSet2_state_node;
  wire       [4:0]    stages_executeSet2_state_root;
  wire                stages_executeSet2_state_isVirtual;
  wire                stages_executeSet2_state_isDefect;
  wire       [1:0]    stages_executeSet2_state_grown;
  wire                stages_executeSet2_isStalled;
  wire                stages_executeSet2_compact_valid;
  wire                stages_executeSet2_compact_isReset;
  wire       [1:0]    stages_executeGet2_state_speed;
  wire       [4:0]    stages_executeGet2_state_node;
  wire       [4:0]    stages_executeGet2_state_root;
  wire                stages_executeGet2_state_isVirtual;
  wire                stages_executeGet2_state_isDefect;
  wire       [1:0]    stages_executeGet2_state_grown;
  wire                stages_executeGet2_isStalled;
  wire                stages_executeGet2_compact_valid;
  wire                stages_executeGet2_compact_isReset;
  wire       [1:0]    stages_executeSet3_state_speed;
  wire       [4:0]    stages_executeSet3_state_node;
  wire       [4:0]    stages_executeSet3_state_root;
  wire                stages_executeSet3_state_isVirtual;
  wire                stages_executeSet3_state_isDefect;
  wire       [1:0]    stages_executeSet3_state_grown;
  wire                stages_executeSet3_isStalled;
  wire                stages_executeSet3_compact_valid;
  wire                stages_executeSet3_compact_isReset;
  wire       [1:0]    stages_executeGet3_state_speed;
  wire       [4:0]    stages_executeGet3_state_node;
  wire       [4:0]    stages_executeGet3_state_root;
  wire                stages_executeGet3_state_isVirtual;
  wire                stages_executeGet3_state_isDefect;
  wire       [1:0]    stages_executeGet3_state_grown;
  wire                stages_executeGet3_isStalled;
  wire                stages_executeGet3_compact_valid;
  wire                stages_executeGet3_compact_isReset;
  wire       [1:0]    stages_updateSet_state_speed;
  wire       [4:0]    stages_updateSet_state_node;
  wire       [4:0]    stages_updateSet_state_root;
  wire                stages_updateSet_state_isVirtual;
  wire                stages_updateSet_state_isDefect;
  wire       [1:0]    stages_updateSet_state_grown;
  wire                stages_updateSet_isStalled;
  wire                stages_updateSet_compact_valid;
  wire                stages_updateSet_compact_isReset;
  wire                stages_updateSet_propagatingPeer_valid;
  wire       [4:0]    stages_updateSet_propagatingPeer_node;
  wire       [4:0]    stages_updateSet_propagatingPeer_root;
  wire       [1:0]    stages_updateGet_state_speed;
  wire       [4:0]    stages_updateGet_state_node;
  wire       [4:0]    stages_updateGet_state_root;
  wire                stages_updateGet_state_isVirtual;
  wire                stages_updateGet_state_isDefect;
  wire       [1:0]    stages_updateGet_state_grown;
  wire                stages_updateGet_isStalled;
  wire                stages_updateGet_compact_valid;
  wire                stages_updateGet_compact_isReset;
  wire                stages_updateGet_propagatingPeer_valid;
  wire       [4:0]    stages_updateGet_propagatingPeer_node;
  wire       [4:0]    stages_updateGet_propagatingPeer_root;
  wire       [1:0]    stages_updateSet2_state_speed;
  wire       [4:0]    stages_updateSet2_state_node;
  wire       [4:0]    stages_updateSet2_state_root;
  wire                stages_updateSet2_state_isVirtual;
  wire                stages_updateSet2_state_isDefect;
  wire       [1:0]    stages_updateSet2_state_grown;
  wire                stages_updateSet2_isStalled;
  wire                stages_updateSet2_compact_valid;
  wire                stages_updateSet2_compact_isReset;
  wire                stages_updateSet2_propagatingPeer_valid;
  wire       [4:0]    stages_updateSet2_propagatingPeer_node;
  wire       [4:0]    stages_updateSet2_propagatingPeer_root;
  wire       [1:0]    stages_updateGet2_state_speed;
  wire       [4:0]    stages_updateGet2_state_node;
  wire       [4:0]    stages_updateGet2_state_root;
  wire                stages_updateGet2_state_isVirtual;
  wire                stages_updateGet2_state_isDefect;
  wire       [1:0]    stages_updateGet2_state_grown;
  wire                stages_updateGet2_isStalled;
  wire                stages_updateGet2_compact_valid;
  wire                stages_updateGet2_compact_isReset;
  wire                stages_updateGet2_propagatingPeer_valid;
  wire       [4:0]    stages_updateGet2_propagatingPeer_node;
  wire       [4:0]    stages_updateGet2_propagatingPeer_root;
  wire       [1:0]    stages_updateSet3_state_speed;
  wire       [4:0]    stages_updateSet3_state_node;
  wire       [4:0]    stages_updateSet3_state_root;
  wire                stages_updateSet3_state_isVirtual;
  wire                stages_updateSet3_state_isDefect;
  wire       [1:0]    stages_updateSet3_state_grown;
  wire       [1:0]    stages_updateSet3_shadow_speed;
  wire       [4:0]    stages_updateSet3_shadow_node;
  wire       [4:0]    stages_updateSet3_shadow_root;
  wire                stages_updateSet3_compact_valid;
  wire                stages_updateSet3_compact_isReset;
  wire       [1:0]    stages_updateGet3_state_speed;
  wire       [4:0]    stages_updateGet3_state_node;
  wire       [4:0]    stages_updateGet3_state_root;
  wire                stages_updateGet3_state_isVirtual;
  wire                stages_updateGet3_state_isDefect;
  wire       [1:0]    stages_updateGet3_state_grown;
  wire       [1:0]    stages_updateGet3_shadow_speed;
  wire       [4:0]    stages_updateGet3_shadow_node;
  wire       [4:0]    stages_updateGet3_shadow_root;
  wire                stages_updateGet3_compact_valid;
  wire                stages_updateGet3_compact_isReset;
  reg        [1:0]    register_speed;
  reg        [4:0]    register_node;
  reg        [4:0]    register_root;
  reg                 register_isVirtual;
  reg                 register_isDefect;
  reg        [1:0]    register_grown;
  wire       [1:0]    fetchState_speed;
  wire       [4:0]    fetchState_node;
  wire       [4:0]    fetchState_root;
  wire                fetchState_isVirtual;
  wire                fetchState_isDefect;
  wire       [1:0]    fetchState_grown;
  wire                message_valid;
  wire       [11:0]   message_instruction;
  wire                message_isReset;

  VertexTightCounter_1 offload3Area_tightCounter (
    .io_tights_0   (io_edgeInputs_0_offloadGet2_isTightExFusion), //i
    .io_isUnique   (offload3Area_tightCounter_io_isUnique      ), //o
    .io_isIsolated (offload3Area_tightCounter_io_isIsolated    )  //o
  );
  OffloadStalled_3 executeArea_offloadStalled (
    .io_isStalled (executeArea_offloadStalled_io_isStalled)  //o
  );
  VertexPostExecuteState execute2Area_vertexPostExecuteState (
    .io_before_speed        (stages_executeGet_state_speed[1:0]                     ), //i
    .io_before_node         (stages_executeGet_state_node[4:0]                      ), //i
    .io_before_root         (stages_executeGet_state_root[4:0]                      ), //i
    .io_before_isVirtual    (stages_executeGet_state_isVirtual                      ), //i
    .io_before_isDefect     (stages_executeGet_state_isDefect                       ), //i
    .io_before_grown        (stages_executeGet_state_grown[1:0]                     ), //i
    .io_message_valid       (stages_executeGet_message_valid                        ), //i
    .io_message_instruction (stages_executeGet_message_instruction[11:0]            ), //i
    .io_message_isReset     (stages_executeGet_message_isReset                      ), //i
    .io_isStalled           (stages_executeGet_isStalled                            ), //i
    .io_after_speed         (execute2Area_vertexPostExecuteState_io_after_speed[1:0]), //o
    .io_after_node          (execute2Area_vertexPostExecuteState_io_after_node[4:0] ), //o
    .io_after_root          (execute2Area_vertexPostExecuteState_io_after_root[4:0] ), //o
    .io_after_isVirtual     (execute2Area_vertexPostExecuteState_io_after_isVirtual ), //o
    .io_after_isDefect      (execute2Area_vertexPostExecuteState_io_after_isDefect  ), //o
    .io_after_grown         (execute2Area_vertexPostExecuteState_io_after_grown[1:0]), //o
    .clk                    (clk                                                    ), //i
    .reset                  (reset                                                  )  //i
  );
  VertexPropagatingPeer_1 updateArea_vertexPropagatingPeer (
    .io_grown         (stages_executeGet3_state_grown[1:0]               ), //i
    .io_edgeIsTight_0 (io_edgeInputs_0_executeGet3_isTight               ), //i
    .io_peerSpeed_0   (_zz_io_peerSpeed_0[1:0]                           ), //i
    .io_peerNode_0    (_zz_io_peerNode_0[4:0]                            ), //i
    .io_peerRoot_0    (_zz_io_peerRoot_0[4:0]                            ), //i
    .io_peer_valid    (updateArea_vertexPropagatingPeer_io_peer_valid    ), //o
    .io_peer_node     (updateArea_vertexPropagatingPeer_io_peer_node[4:0]), //o
    .io_peer_root     (updateArea_vertexPropagatingPeer_io_peer_root[4:0])  //o
  );
  VertexPostUpdateState_3 update2Area_vertexPostUpdateState (
    .io_before_speed     (stages_updateGet_state_speed[1:0]                    ), //i
    .io_before_node      (stages_updateGet_state_node[4:0]                     ), //i
    .io_before_root      (stages_updateGet_state_root[4:0]                     ), //i
    .io_before_isVirtual (stages_updateGet_state_isVirtual                     ), //i
    .io_before_isDefect  (stages_updateGet_state_isDefect                      ), //i
    .io_before_grown     (stages_updateGet_state_grown[1:0]                    ), //i
    .io_propagator_valid (stages_updateGet_propagatingPeer_valid               ), //i
    .io_propagator_node  (stages_updateGet_propagatingPeer_node[4:0]           ), //i
    .io_propagator_root  (stages_updateGet_propagatingPeer_root[4:0]           ), //i
    .io_after_speed      (update2Area_vertexPostUpdateState_io_after_speed[1:0]), //o
    .io_after_node       (update2Area_vertexPostUpdateState_io_after_node[4:0] ), //o
    .io_after_root       (update2Area_vertexPostUpdateState_io_after_root[4:0] ), //o
    .io_after_isVirtual  (update2Area_vertexPostUpdateState_io_after_isVirtual ), //o
    .io_after_isDefect   (update2Area_vertexPostUpdateState_io_after_isDefect  ), //o
    .io_after_grown      (update2Area_vertexPostUpdateState_io_after_grown[1:0])  //o
  );
  VertexShadow_3 update3Area_vertexShadow (
    .io_isVirtual        (stages_updateGet2_state_isVirtual            ), //i
    .io_node             (stages_updateGet2_state_node[4:0]            ), //i
    .io_root             (stages_updateGet2_state_root[4:0]            ), //i
    .io_speed            (stages_updateGet2_state_speed[1:0]           ), //i
    .io_grown            (stages_updateGet2_state_grown[1:0]           ), //i
    .io_isStalled        (stages_updateGet2_isStalled                  ), //i
    .io_propagator_valid (stages_updateGet2_propagatingPeer_valid      ), //i
    .io_propagator_node  (stages_updateGet2_propagatingPeer_node[4:0]  ), //i
    .io_propagator_root  (stages_updateGet2_propagatingPeer_root[4:0]  ), //i
    .io_shadow_speed     (update3Area_vertexShadow_io_shadow_speed[1:0]), //o
    .io_shadow_node      (update3Area_vertexShadow_io_shadow_node[4:0] ), //o
    .io_shadow_root      (update3Area_vertexShadow_io_shadow_root[4:0] )  //o
  );
  VertexResponse_3 vertexResponse_4 (
    .io_state_speed        (stages_updateGet3_state_speed[1:0]         ), //i
    .io_state_node         (stages_updateGet3_state_node[4:0]          ), //i
    .io_state_root         (stages_updateGet3_state_root[4:0]          ), //i
    .io_state_isVirtual    (stages_updateGet3_state_isVirtual          ), //i
    .io_state_isDefect     (stages_updateGet3_state_isDefect           ), //i
    .io_state_grown        (stages_updateGet3_state_grown[1:0]         ), //i
    .io_maxGrowable_length (vertexResponse_4_io_maxGrowable_length[1:0])  //o
  );
  assign io_stageOutputs_offloadGet_state_speed = stages_offloadGet_state_speed;
  assign io_stageOutputs_offloadGet_state_node = stages_offloadGet_state_node;
  assign io_stageOutputs_offloadGet_state_root = stages_offloadGet_state_root;
  assign io_stageOutputs_offloadGet_state_isVirtual = stages_offloadGet_state_isVirtual;
  assign io_stageOutputs_offloadGet_state_isDefect = stages_offloadGet_state_isDefect;
  assign io_stageOutputs_offloadGet_state_grown = stages_offloadGet_state_grown;
  assign io_stageOutputs_offloadGet_message_valid = stages_offloadGet_message_valid;
  assign io_stageOutputs_offloadGet_message_instruction = stages_offloadGet_message_instruction;
  assign io_stageOutputs_offloadGet_message_isReset = stages_offloadGet_message_isReset;
  assign io_stageOutputs_offloadGet2_state_speed = stages_offloadGet2_state_speed;
  assign io_stageOutputs_offloadGet2_state_node = stages_offloadGet2_state_node;
  assign io_stageOutputs_offloadGet2_state_root = stages_offloadGet2_state_root;
  assign io_stageOutputs_offloadGet2_state_isVirtual = stages_offloadGet2_state_isVirtual;
  assign io_stageOutputs_offloadGet2_state_isDefect = stages_offloadGet2_state_isDefect;
  assign io_stageOutputs_offloadGet2_state_grown = stages_offloadGet2_state_grown;
  assign io_stageOutputs_offloadGet2_message_valid = stages_offloadGet2_message_valid;
  assign io_stageOutputs_offloadGet2_message_instruction = stages_offloadGet2_message_instruction;
  assign io_stageOutputs_offloadGet2_message_isReset = stages_offloadGet2_message_isReset;
  assign io_stageOutputs_offloadGet3_state_speed = stages_offloadGet3_state_speed;
  assign io_stageOutputs_offloadGet3_state_node = stages_offloadGet3_state_node;
  assign io_stageOutputs_offloadGet3_state_root = stages_offloadGet3_state_root;
  assign io_stageOutputs_offloadGet3_state_isVirtual = stages_offloadGet3_state_isVirtual;
  assign io_stageOutputs_offloadGet3_state_isDefect = stages_offloadGet3_state_isDefect;
  assign io_stageOutputs_offloadGet3_state_grown = stages_offloadGet3_state_grown;
  assign io_stageOutputs_offloadGet3_message_valid = stages_offloadGet3_message_valid;
  assign io_stageOutputs_offloadGet3_message_instruction = stages_offloadGet3_message_instruction;
  assign io_stageOutputs_offloadGet3_message_isReset = stages_offloadGet3_message_isReset;
  assign io_stageOutputs_offloadGet3_isUniqueTight = stages_offloadGet3_isUniqueTight;
  assign io_stageOutputs_offloadGet3_isIsolated = stages_offloadGet3_isIsolated;
  assign io_stageOutputs_offloadGet4_state_speed = stages_offloadGet4_state_speed;
  assign io_stageOutputs_offloadGet4_state_node = stages_offloadGet4_state_node;
  assign io_stageOutputs_offloadGet4_state_root = stages_offloadGet4_state_root;
  assign io_stageOutputs_offloadGet4_state_isVirtual = stages_offloadGet4_state_isVirtual;
  assign io_stageOutputs_offloadGet4_state_isDefect = stages_offloadGet4_state_isDefect;
  assign io_stageOutputs_offloadGet4_state_grown = stages_offloadGet4_state_grown;
  assign io_stageOutputs_offloadGet4_message_valid = stages_offloadGet4_message_valid;
  assign io_stageOutputs_offloadGet4_message_instruction = stages_offloadGet4_message_instruction;
  assign io_stageOutputs_offloadGet4_message_isReset = stages_offloadGet4_message_isReset;
  assign io_stageOutputs_executeGet_state_speed = stages_executeGet_state_speed;
  assign io_stageOutputs_executeGet_state_node = stages_executeGet_state_node;
  assign io_stageOutputs_executeGet_state_root = stages_executeGet_state_root;
  assign io_stageOutputs_executeGet_state_isVirtual = stages_executeGet_state_isVirtual;
  assign io_stageOutputs_executeGet_state_isDefect = stages_executeGet_state_isDefect;
  assign io_stageOutputs_executeGet_state_grown = stages_executeGet_state_grown;
  assign io_stageOutputs_executeGet_message_valid = stages_executeGet_message_valid;
  assign io_stageOutputs_executeGet_message_instruction = stages_executeGet_message_instruction;
  assign io_stageOutputs_executeGet_message_isReset = stages_executeGet_message_isReset;
  assign io_stageOutputs_executeGet_isStalled = stages_executeGet_isStalled;
  assign io_stageOutputs_executeGet2_state_speed = stages_executeGet2_state_speed;
  assign io_stageOutputs_executeGet2_state_node = stages_executeGet2_state_node;
  assign io_stageOutputs_executeGet2_state_root = stages_executeGet2_state_root;
  assign io_stageOutputs_executeGet2_state_isVirtual = stages_executeGet2_state_isVirtual;
  assign io_stageOutputs_executeGet2_state_isDefect = stages_executeGet2_state_isDefect;
  assign io_stageOutputs_executeGet2_state_grown = stages_executeGet2_state_grown;
  assign io_stageOutputs_executeGet2_isStalled = stages_executeGet2_isStalled;
  assign io_stageOutputs_executeGet2_compact_valid = stages_executeGet2_compact_valid;
  assign io_stageOutputs_executeGet2_compact_isReset = stages_executeGet2_compact_isReset;
  assign io_stageOutputs_executeGet3_state_speed = stages_executeGet3_state_speed;
  assign io_stageOutputs_executeGet3_state_node = stages_executeGet3_state_node;
  assign io_stageOutputs_executeGet3_state_root = stages_executeGet3_state_root;
  assign io_stageOutputs_executeGet3_state_isVirtual = stages_executeGet3_state_isVirtual;
  assign io_stageOutputs_executeGet3_state_isDefect = stages_executeGet3_state_isDefect;
  assign io_stageOutputs_executeGet3_state_grown = stages_executeGet3_state_grown;
  assign io_stageOutputs_executeGet3_isStalled = stages_executeGet3_isStalled;
  assign io_stageOutputs_executeGet3_compact_valid = stages_executeGet3_compact_valid;
  assign io_stageOutputs_executeGet3_compact_isReset = stages_executeGet3_compact_isReset;
  assign io_stageOutputs_updateGet_state_speed = stages_updateGet_state_speed;
  assign io_stageOutputs_updateGet_state_node = stages_updateGet_state_node;
  assign io_stageOutputs_updateGet_state_root = stages_updateGet_state_root;
  assign io_stageOutputs_updateGet_state_isVirtual = stages_updateGet_state_isVirtual;
  assign io_stageOutputs_updateGet_state_isDefect = stages_updateGet_state_isDefect;
  assign io_stageOutputs_updateGet_state_grown = stages_updateGet_state_grown;
  assign io_stageOutputs_updateGet_isStalled = stages_updateGet_isStalled;
  assign io_stageOutputs_updateGet_compact_valid = stages_updateGet_compact_valid;
  assign io_stageOutputs_updateGet_compact_isReset = stages_updateGet_compact_isReset;
  assign io_stageOutputs_updateGet_propagatingPeer_valid = stages_updateGet_propagatingPeer_valid;
  assign io_stageOutputs_updateGet_propagatingPeer_node = stages_updateGet_propagatingPeer_node;
  assign io_stageOutputs_updateGet_propagatingPeer_root = stages_updateGet_propagatingPeer_root;
  assign io_stageOutputs_updateGet2_state_speed = stages_updateGet2_state_speed;
  assign io_stageOutputs_updateGet2_state_node = stages_updateGet2_state_node;
  assign io_stageOutputs_updateGet2_state_root = stages_updateGet2_state_root;
  assign io_stageOutputs_updateGet2_state_isVirtual = stages_updateGet2_state_isVirtual;
  assign io_stageOutputs_updateGet2_state_isDefect = stages_updateGet2_state_isDefect;
  assign io_stageOutputs_updateGet2_state_grown = stages_updateGet2_state_grown;
  assign io_stageOutputs_updateGet2_isStalled = stages_updateGet2_isStalled;
  assign io_stageOutputs_updateGet2_compact_valid = stages_updateGet2_compact_valid;
  assign io_stageOutputs_updateGet2_compact_isReset = stages_updateGet2_compact_isReset;
  assign io_stageOutputs_updateGet2_propagatingPeer_valid = stages_updateGet2_propagatingPeer_valid;
  assign io_stageOutputs_updateGet2_propagatingPeer_node = stages_updateGet2_propagatingPeer_node;
  assign io_stageOutputs_updateGet2_propagatingPeer_root = stages_updateGet2_propagatingPeer_root;
  assign io_stageOutputs_updateGet3_state_speed = stages_updateGet3_state_speed;
  assign io_stageOutputs_updateGet3_state_node = stages_updateGet3_state_node;
  assign io_stageOutputs_updateGet3_state_root = stages_updateGet3_state_root;
  assign io_stageOutputs_updateGet3_state_isVirtual = stages_updateGet3_state_isVirtual;
  assign io_stageOutputs_updateGet3_state_isDefect = stages_updateGet3_state_isDefect;
  assign io_stageOutputs_updateGet3_state_grown = stages_updateGet3_state_grown;
  assign io_stageOutputs_updateGet3_shadow_speed = stages_updateGet3_shadow_speed;
  assign io_stageOutputs_updateGet3_shadow_node = stages_updateGet3_shadow_node;
  assign io_stageOutputs_updateGet3_shadow_root = stages_updateGet3_shadow_root;
  assign io_stageOutputs_updateGet3_compact_valid = stages_updateGet3_compact_valid;
  assign io_stageOutputs_updateGet3_compact_isReset = stages_updateGet3_compact_isReset;
  assign fetchState_speed = register_speed;
  assign fetchState_node = register_node;
  assign fetchState_root = register_root;
  assign fetchState_isVirtual = register_isVirtual;
  assign fetchState_isDefect = register_isDefect;
  assign fetchState_grown = register_grown;
  assign message_valid = io_message_valid;
  assign message_instruction = io_message_instruction;
  assign message_isReset = io_message_isReset;
  assign stages_offloadSet_message_valid = message_valid;
  assign stages_offloadSet_message_instruction = message_instruction;
  assign stages_offloadSet_message_isReset = message_isReset;
  assign stages_offloadSet_state_speed = (message_isReset ? 2'b00 : fetchState_speed);
  assign stages_offloadSet_state_node = (message_isReset ? 5'h1f : fetchState_node);
  assign stages_offloadSet_state_root = (message_isReset ? 5'h1f : fetchState_root);
  assign stages_offloadSet_state_isVirtual = (message_isReset ? 1'b1 : fetchState_isVirtual);
  assign stages_offloadSet_state_isDefect = (message_isReset ? 1'b0 : fetchState_isDefect);
  assign stages_offloadSet_state_grown = (message_isReset ? 2'b00 : fetchState_grown);
  assign stages_offloadSet2_state_speed = stages_offloadGet_state_speed;
  assign stages_offloadSet2_state_node = stages_offloadGet_state_node;
  assign stages_offloadSet2_state_root = stages_offloadGet_state_root;
  assign stages_offloadSet2_state_isVirtual = stages_offloadGet_state_isVirtual;
  assign stages_offloadSet2_state_isDefect = stages_offloadGet_state_isDefect;
  assign stages_offloadSet2_state_grown = stages_offloadGet_state_grown;
  assign stages_offloadSet2_message_valid = stages_offloadGet_message_valid;
  assign stages_offloadSet2_message_instruction = stages_offloadGet_message_instruction;
  assign stages_offloadSet2_message_isReset = stages_offloadGet_message_isReset;
  assign stages_offloadSet3_state_speed = stages_offloadGet2_state_speed;
  assign stages_offloadSet3_state_node = stages_offloadGet2_state_node;
  assign stages_offloadSet3_state_root = stages_offloadGet2_state_root;
  assign stages_offloadSet3_state_isVirtual = stages_offloadGet2_state_isVirtual;
  assign stages_offloadSet3_state_isDefect = stages_offloadGet2_state_isDefect;
  assign stages_offloadSet3_state_grown = stages_offloadGet2_state_grown;
  assign stages_offloadSet3_message_valid = stages_offloadGet2_message_valid;
  assign stages_offloadSet3_message_instruction = stages_offloadGet2_message_instruction;
  assign stages_offloadSet3_message_isReset = stages_offloadGet2_message_isReset;
  assign stages_offloadSet3_isUniqueTight = offload3Area_tightCounter_io_isUnique;
  assign stages_offloadSet3_isIsolated = offload3Area_tightCounter_io_isIsolated;
  assign stages_offloadSet4_state_speed = stages_offloadGet3_state_speed;
  assign stages_offloadSet4_state_node = stages_offloadGet3_state_node;
  assign stages_offloadSet4_state_root = stages_offloadGet3_state_root;
  assign stages_offloadSet4_state_isVirtual = stages_offloadGet3_state_isVirtual;
  assign stages_offloadSet4_state_isDefect = stages_offloadGet3_state_isDefect;
  assign stages_offloadSet4_state_grown = stages_offloadGet3_state_grown;
  assign stages_offloadSet4_message_valid = stages_offloadGet3_message_valid;
  assign stages_offloadSet4_message_instruction = stages_offloadGet3_message_instruction;
  assign stages_offloadSet4_message_isReset = stages_offloadGet3_message_isReset;
  assign stages_executeSet_state_speed = stages_offloadGet4_state_speed;
  assign stages_executeSet_state_node = stages_offloadGet4_state_node;
  assign stages_executeSet_state_root = stages_offloadGet4_state_root;
  assign stages_executeSet_state_isVirtual = stages_offloadGet4_state_isVirtual;
  assign stages_executeSet_state_isDefect = stages_offloadGet4_state_isDefect;
  assign stages_executeSet_state_grown = stages_offloadGet4_state_grown;
  assign stages_executeSet_message_valid = stages_offloadGet4_message_valid;
  assign stages_executeSet_message_instruction = stages_offloadGet4_message_instruction;
  assign stages_executeSet_message_isReset = stages_offloadGet4_message_isReset;
  assign stages_executeSet_isStalled = executeArea_offloadStalled_io_isStalled;
  assign stages_executeSet2_isStalled = stages_executeGet_isStalled;
  assign stages_executeSet2_compact_valid = stages_executeGet_message_valid;
  assign stages_executeSet2_compact_isReset = stages_executeGet_message_isReset;
  assign stages_executeSet2_state_speed = execute2Area_vertexPostExecuteState_io_after_speed;
  assign stages_executeSet2_state_node = execute2Area_vertexPostExecuteState_io_after_node;
  assign stages_executeSet2_state_root = execute2Area_vertexPostExecuteState_io_after_root;
  assign stages_executeSet2_state_isVirtual = execute2Area_vertexPostExecuteState_io_after_isVirtual;
  assign stages_executeSet2_state_isDefect = execute2Area_vertexPostExecuteState_io_after_isDefect;
  assign stages_executeSet2_state_grown = execute2Area_vertexPostExecuteState_io_after_grown;
  assign stages_executeSet3_state_speed = stages_executeGet2_state_speed;
  assign stages_executeSet3_state_node = stages_executeGet2_state_node;
  assign stages_executeSet3_state_root = stages_executeGet2_state_root;
  assign stages_executeSet3_state_isVirtual = stages_executeGet2_state_isVirtual;
  assign stages_executeSet3_state_isDefect = stages_executeGet2_state_isDefect;
  assign stages_executeSet3_state_grown = stages_executeGet2_state_grown;
  assign stages_executeSet3_isStalled = stages_executeGet2_isStalled;
  assign stages_executeSet3_compact_valid = stages_executeGet2_compact_valid;
  assign stages_executeSet3_compact_isReset = stages_executeGet2_compact_isReset;
  assign stages_updateSet_state_speed = stages_executeGet3_state_speed;
  assign stages_updateSet_state_node = stages_executeGet3_state_node;
  assign stages_updateSet_state_root = stages_executeGet3_state_root;
  assign stages_updateSet_state_isVirtual = stages_executeGet3_state_isVirtual;
  assign stages_updateSet_state_isDefect = stages_executeGet3_state_isDefect;
  assign stages_updateSet_state_grown = stages_executeGet3_state_grown;
  assign stages_updateSet_isStalled = stages_executeGet3_isStalled;
  assign stages_updateSet_compact_valid = stages_executeGet3_compact_valid;
  assign stages_updateSet_compact_isReset = stages_executeGet3_compact_isReset;
  assign stages_updateSet_propagatingPeer_valid = updateArea_vertexPropagatingPeer_io_peer_valid;
  assign stages_updateSet_propagatingPeer_node = updateArea_vertexPropagatingPeer_io_peer_node;
  assign stages_updateSet_propagatingPeer_root = updateArea_vertexPropagatingPeer_io_peer_root;
  assign stages_updateSet2_compact_valid = stages_updateGet_compact_valid;
  assign stages_updateSet2_compact_isReset = stages_updateGet_compact_isReset;
  assign stages_updateSet2_isStalled = stages_updateGet_isStalled;
  assign stages_updateSet2_propagatingPeer_valid = stages_updateGet_propagatingPeer_valid;
  assign stages_updateSet2_propagatingPeer_node = stages_updateGet_propagatingPeer_node;
  assign stages_updateSet2_propagatingPeer_root = stages_updateGet_propagatingPeer_root;
  assign stages_updateSet2_state_speed = update2Area_vertexPostUpdateState_io_after_speed;
  assign stages_updateSet2_state_node = update2Area_vertexPostUpdateState_io_after_node;
  assign stages_updateSet2_state_root = update2Area_vertexPostUpdateState_io_after_root;
  assign stages_updateSet2_state_isVirtual = update2Area_vertexPostUpdateState_io_after_isVirtual;
  assign stages_updateSet2_state_isDefect = update2Area_vertexPostUpdateState_io_after_isDefect;
  assign stages_updateSet2_state_grown = update2Area_vertexPostUpdateState_io_after_grown;
  assign stages_updateSet3_state_speed = stages_updateGet2_state_speed;
  assign stages_updateSet3_state_node = stages_updateGet2_state_node;
  assign stages_updateSet3_state_root = stages_updateGet2_state_root;
  assign stages_updateSet3_state_isVirtual = stages_updateGet2_state_isVirtual;
  assign stages_updateSet3_state_isDefect = stages_updateGet2_state_isDefect;
  assign stages_updateSet3_state_grown = stages_updateGet2_state_grown;
  assign stages_updateSet3_compact_valid = stages_updateGet2_compact_valid;
  assign stages_updateSet3_compact_isReset = stages_updateGet2_compact_isReset;
  assign stages_updateSet3_shadow_speed = update3Area_vertexShadow_io_shadow_speed;
  assign stages_updateSet3_shadow_node = update3Area_vertexShadow_io_shadow_node;
  assign stages_updateSet3_shadow_root = update3Area_vertexShadow_io_shadow_root;
  assign io_maxGrowable_length = vertexResponse_4_io_maxGrowable_length;
  assign stages_executeGet3_state_speed = stages_executeSet3_state_speed;
  assign stages_executeGet3_state_node = stages_executeSet3_state_node;
  assign stages_executeGet3_state_root = stages_executeSet3_state_root;
  assign stages_executeGet3_state_isVirtual = stages_executeSet3_state_isVirtual;
  assign stages_executeGet3_state_isDefect = stages_executeSet3_state_isDefect;
  assign stages_executeGet3_state_grown = stages_executeSet3_state_grown;
  assign stages_executeGet3_isStalled = stages_executeSet3_isStalled;
  assign stages_executeGet3_compact_valid = stages_executeSet3_compact_valid;
  assign stages_executeGet3_compact_isReset = stages_executeSet3_compact_isReset;
  assign stages_updateGet_state_speed = stages_updateSet_state_speed;
  assign stages_updateGet_state_node = stages_updateSet_state_node;
  assign stages_updateGet_state_root = stages_updateSet_state_root;
  assign stages_updateGet_state_isVirtual = stages_updateSet_state_isVirtual;
  assign stages_updateGet_state_isDefect = stages_updateSet_state_isDefect;
  assign stages_updateGet_state_grown = stages_updateSet_state_grown;
  assign stages_updateGet_isStalled = stages_updateSet_isStalled;
  assign stages_updateGet_compact_valid = stages_updateSet_compact_valid;
  assign stages_updateGet_compact_isReset = stages_updateSet_compact_isReset;
  assign stages_updateGet_propagatingPeer_valid = stages_updateSet_propagatingPeer_valid;
  assign stages_updateGet_propagatingPeer_node = stages_updateSet_propagatingPeer_node;
  assign stages_updateGet_propagatingPeer_root = stages_updateSet_propagatingPeer_root;
  assign stages_offloadGet_state_speed = stages_offloadSet_state_speed;
  assign stages_offloadGet_state_node = stages_offloadSet_state_node;
  assign stages_offloadGet_state_root = stages_offloadSet_state_root;
  assign stages_offloadGet_state_isVirtual = stages_offloadSet_state_isVirtual;
  assign stages_offloadGet_state_isDefect = stages_offloadSet_state_isDefect;
  assign stages_offloadGet_state_grown = stages_offloadSet_state_grown;
  assign stages_offloadGet_message_valid = stages_offloadSet_message_valid;
  assign stages_offloadGet_message_instruction = stages_offloadSet_message_instruction;
  assign stages_offloadGet_message_isReset = stages_offloadSet_message_isReset;
  assign stages_offloadGet4_state_speed = stages_offloadSet4_state_speed;
  assign stages_offloadGet4_state_node = stages_offloadSet4_state_node;
  assign stages_offloadGet4_state_root = stages_offloadSet4_state_root;
  assign stages_offloadGet4_state_isVirtual = stages_offloadSet4_state_isVirtual;
  assign stages_offloadGet4_state_isDefect = stages_offloadSet4_state_isDefect;
  assign stages_offloadGet4_state_grown = stages_offloadSet4_state_grown;
  assign stages_offloadGet4_message_valid = stages_offloadSet4_message_valid;
  assign stages_offloadGet4_message_instruction = stages_offloadSet4_message_instruction;
  assign stages_offloadGet4_message_isReset = stages_offloadSet4_message_isReset;
  assign stages_updateGet3_state_speed = stages_updateSet3_state_speed;
  assign stages_updateGet3_state_node = stages_updateSet3_state_node;
  assign stages_updateGet3_state_root = stages_updateSet3_state_root;
  assign stages_updateGet3_state_isVirtual = stages_updateSet3_state_isVirtual;
  assign stages_updateGet3_state_isDefect = stages_updateSet3_state_isDefect;
  assign stages_updateGet3_state_grown = stages_updateSet3_state_grown;
  assign stages_updateGet3_shadow_speed = stages_updateSet3_shadow_speed;
  assign stages_updateGet3_shadow_node = stages_updateSet3_shadow_node;
  assign stages_updateGet3_shadow_root = stages_updateSet3_shadow_root;
  assign stages_updateGet3_compact_valid = stages_updateSet3_compact_valid;
  assign stages_updateGet3_compact_isReset = stages_updateSet3_compact_isReset;
  assign stages_executeGet_state_speed = stages_executeSet_state_speed;
  assign stages_executeGet_state_node = stages_executeSet_state_node;
  assign stages_executeGet_state_root = stages_executeSet_state_root;
  assign stages_executeGet_state_isVirtual = stages_executeSet_state_isVirtual;
  assign stages_executeGet_state_isDefect = stages_executeSet_state_isDefect;
  assign stages_executeGet_state_grown = stages_executeSet_state_grown;
  assign stages_executeGet_message_valid = stages_executeSet_message_valid;
  assign stages_executeGet_message_instruction = stages_executeSet_message_instruction;
  assign stages_executeGet_message_isReset = stages_executeSet_message_isReset;
  assign stages_executeGet_isStalled = stages_executeSet_isStalled;
  assign stages_executeGet2_state_speed = stages_executeSet2_state_speed;
  assign stages_executeGet2_state_node = stages_executeSet2_state_node;
  assign stages_executeGet2_state_root = stages_executeSet2_state_root;
  assign stages_executeGet2_state_isVirtual = stages_executeSet2_state_isVirtual;
  assign stages_executeGet2_state_isDefect = stages_executeSet2_state_isDefect;
  assign stages_executeGet2_state_grown = stages_executeSet2_state_grown;
  assign stages_executeGet2_isStalled = stages_executeSet2_isStalled;
  assign stages_executeGet2_compact_valid = stages_executeSet2_compact_valid;
  assign stages_executeGet2_compact_isReset = stages_executeSet2_compact_isReset;
  assign stages_offloadGet3_state_speed = stages_offloadSet3_state_speed;
  assign stages_offloadGet3_state_node = stages_offloadSet3_state_node;
  assign stages_offloadGet3_state_root = stages_offloadSet3_state_root;
  assign stages_offloadGet3_state_isVirtual = stages_offloadSet3_state_isVirtual;
  assign stages_offloadGet3_state_isDefect = stages_offloadSet3_state_isDefect;
  assign stages_offloadGet3_state_grown = stages_offloadSet3_state_grown;
  assign stages_offloadGet3_message_valid = stages_offloadSet3_message_valid;
  assign stages_offloadGet3_message_instruction = stages_offloadSet3_message_instruction;
  assign stages_offloadGet3_message_isReset = stages_offloadSet3_message_isReset;
  assign stages_offloadGet3_isUniqueTight = stages_offloadSet3_isUniqueTight;
  assign stages_offloadGet3_isIsolated = stages_offloadSet3_isIsolated;
  assign stages_updateGet2_state_speed = stages_updateSet2_state_speed;
  assign stages_updateGet2_state_node = stages_updateSet2_state_node;
  assign stages_updateGet2_state_root = stages_updateSet2_state_root;
  assign stages_updateGet2_state_isVirtual = stages_updateSet2_state_isVirtual;
  assign stages_updateGet2_state_isDefect = stages_updateSet2_state_isDefect;
  assign stages_updateGet2_state_grown = stages_updateSet2_state_grown;
  assign stages_updateGet2_isStalled = stages_updateSet2_isStalled;
  assign stages_updateGet2_compact_valid = stages_updateSet2_compact_valid;
  assign stages_updateGet2_compact_isReset = stages_updateSet2_compact_isReset;
  assign stages_updateGet2_propagatingPeer_valid = stages_updateSet2_propagatingPeer_valid;
  assign stages_updateGet2_propagatingPeer_node = stages_updateSet2_propagatingPeer_node;
  assign stages_updateGet2_propagatingPeer_root = stages_updateSet2_propagatingPeer_root;
  assign stages_offloadGet2_state_speed = stages_offloadSet2_state_speed;
  assign stages_offloadGet2_state_node = stages_offloadSet2_state_node;
  assign stages_offloadGet2_state_root = stages_offloadSet2_state_root;
  assign stages_offloadGet2_state_isVirtual = stages_offloadSet2_state_isVirtual;
  assign stages_offloadGet2_state_isDefect = stages_offloadSet2_state_isDefect;
  assign stages_offloadGet2_state_grown = stages_offloadSet2_state_grown;
  assign stages_offloadGet2_message_valid = stages_offloadSet2_message_valid;
  assign stages_offloadGet2_message_instruction = stages_offloadSet2_message_instruction;
  assign stages_offloadGet2_message_isReset = stages_offloadSet2_message_isReset;
  always @(posedge clk or posedge reset) begin
    if(reset) begin
      register_speed <= 2'b00;
      register_node <= 5'h1f;
      register_root <= 5'h1f;
      register_isVirtual <= 1'b1;
      register_isDefect <= 1'b0;
      register_grown <= 2'b00;
    end else begin
      if(stages_updateGet3_compact_valid) begin
        register_speed <= stages_updateGet3_state_speed;
        register_node <= stages_updateGet3_state_node;
        register_root <= stages_updateGet3_state_root;
        register_isVirtual <= stages_updateGet3_state_isVirtual;
        register_isDefect <= stages_updateGet3_state_isDefect;
        register_grown <= stages_updateGet3_state_grown;
      end
    end
  end


endmodule

module Vertex_2 (
  input               io_message_valid,
  input      [11:0]   io_message_instruction,
  input               io_message_isReset,
  output     [1:0]    io_stageOutputs_offloadGet_state_speed,
  output     [4:0]    io_stageOutputs_offloadGet_state_node,
  output     [4:0]    io_stageOutputs_offloadGet_state_root,
  output              io_stageOutputs_offloadGet_state_isVirtual,
  output              io_stageOutputs_offloadGet_state_isDefect,
  output     [1:0]    io_stageOutputs_offloadGet_state_grown,
  output              io_stageOutputs_offloadGet_message_valid,
  output     [11:0]   io_stageOutputs_offloadGet_message_instruction,
  output              io_stageOutputs_offloadGet_message_isReset,
  output     [1:0]    io_stageOutputs_offloadGet2_state_speed,
  output     [4:0]    io_stageOutputs_offloadGet2_state_node,
  output     [4:0]    io_stageOutputs_offloadGet2_state_root,
  output              io_stageOutputs_offloadGet2_state_isVirtual,
  output              io_stageOutputs_offloadGet2_state_isDefect,
  output     [1:0]    io_stageOutputs_offloadGet2_state_grown,
  output              io_stageOutputs_offloadGet2_message_valid,
  output     [11:0]   io_stageOutputs_offloadGet2_message_instruction,
  output              io_stageOutputs_offloadGet2_message_isReset,
  output     [1:0]    io_stageOutputs_offloadGet3_state_speed,
  output     [4:0]    io_stageOutputs_offloadGet3_state_node,
  output     [4:0]    io_stageOutputs_offloadGet3_state_root,
  output              io_stageOutputs_offloadGet3_state_isVirtual,
  output              io_stageOutputs_offloadGet3_state_isDefect,
  output     [1:0]    io_stageOutputs_offloadGet3_state_grown,
  output              io_stageOutputs_offloadGet3_message_valid,
  output     [11:0]   io_stageOutputs_offloadGet3_message_instruction,
  output              io_stageOutputs_offloadGet3_message_isReset,
  output              io_stageOutputs_offloadGet3_isUniqueTight,
  output              io_stageOutputs_offloadGet3_isIsolated,
  output     [1:0]    io_stageOutputs_offloadGet4_state_speed,
  output     [4:0]    io_stageOutputs_offloadGet4_state_node,
  output     [4:0]    io_stageOutputs_offloadGet4_state_root,
  output              io_stageOutputs_offloadGet4_state_isVirtual,
  output              io_stageOutputs_offloadGet4_state_isDefect,
  output     [1:0]    io_stageOutputs_offloadGet4_state_grown,
  output              io_stageOutputs_offloadGet4_message_valid,
  output     [11:0]   io_stageOutputs_offloadGet4_message_instruction,
  output              io_stageOutputs_offloadGet4_message_isReset,
  output     [1:0]    io_stageOutputs_executeGet_state_speed,
  output     [4:0]    io_stageOutputs_executeGet_state_node,
  output     [4:0]    io_stageOutputs_executeGet_state_root,
  output              io_stageOutputs_executeGet_state_isVirtual,
  output              io_stageOutputs_executeGet_state_isDefect,
  output     [1:0]    io_stageOutputs_executeGet_state_grown,
  output              io_stageOutputs_executeGet_message_valid,
  output     [11:0]   io_stageOutputs_executeGet_message_instruction,
  output              io_stageOutputs_executeGet_message_isReset,
  output              io_stageOutputs_executeGet_isStalled,
  output     [1:0]    io_stageOutputs_executeGet2_state_speed,
  output     [4:0]    io_stageOutputs_executeGet2_state_node,
  output     [4:0]    io_stageOutputs_executeGet2_state_root,
  output              io_stageOutputs_executeGet2_state_isVirtual,
  output              io_stageOutputs_executeGet2_state_isDefect,
  output     [1:0]    io_stageOutputs_executeGet2_state_grown,
  output              io_stageOutputs_executeGet2_isStalled,
  output              io_stageOutputs_executeGet2_compact_valid,
  output              io_stageOutputs_executeGet2_compact_isReset,
  output     [1:0]    io_stageOutputs_executeGet3_state_speed,
  output     [4:0]    io_stageOutputs_executeGet3_state_node,
  output     [4:0]    io_stageOutputs_executeGet3_state_root,
  output              io_stageOutputs_executeGet3_state_isVirtual,
  output              io_stageOutputs_executeGet3_state_isDefect,
  output     [1:0]    io_stageOutputs_executeGet3_state_grown,
  output              io_stageOutputs_executeGet3_isStalled,
  output              io_stageOutputs_executeGet3_compact_valid,
  output              io_stageOutputs_executeGet3_compact_isReset,
  output     [1:0]    io_stageOutputs_updateGet_state_speed,
  output     [4:0]    io_stageOutputs_updateGet_state_node,
  output     [4:0]    io_stageOutputs_updateGet_state_root,
  output              io_stageOutputs_updateGet_state_isVirtual,
  output              io_stageOutputs_updateGet_state_isDefect,
  output     [1:0]    io_stageOutputs_updateGet_state_grown,
  output              io_stageOutputs_updateGet_isStalled,
  output              io_stageOutputs_updateGet_compact_valid,
  output              io_stageOutputs_updateGet_compact_isReset,
  output              io_stageOutputs_updateGet_propagatingPeer_valid,
  output     [4:0]    io_stageOutputs_updateGet_propagatingPeer_node,
  output     [4:0]    io_stageOutputs_updateGet_propagatingPeer_root,
  output     [1:0]    io_stageOutputs_updateGet2_state_speed,
  output     [4:0]    io_stageOutputs_updateGet2_state_node,
  output     [4:0]    io_stageOutputs_updateGet2_state_root,
  output              io_stageOutputs_updateGet2_state_isVirtual,
  output              io_stageOutputs_updateGet2_state_isDefect,
  output     [1:0]    io_stageOutputs_updateGet2_state_grown,
  output              io_stageOutputs_updateGet2_isStalled,
  output              io_stageOutputs_updateGet2_compact_valid,
  output              io_stageOutputs_updateGet2_compact_isReset,
  output              io_stageOutputs_updateGet2_propagatingPeer_valid,
  output     [4:0]    io_stageOutputs_updateGet2_propagatingPeer_node,
  output     [4:0]    io_stageOutputs_updateGet2_propagatingPeer_root,
  output     [1:0]    io_stageOutputs_updateGet3_state_speed,
  output     [4:0]    io_stageOutputs_updateGet3_state_node,
  output     [4:0]    io_stageOutputs_updateGet3_state_root,
  output              io_stageOutputs_updateGet3_state_isVirtual,
  output              io_stageOutputs_updateGet3_state_isDefect,
  output     [1:0]    io_stageOutputs_updateGet3_state_grown,
  output     [1:0]    io_stageOutputs_updateGet3_shadow_speed,
  output     [4:0]    io_stageOutputs_updateGet3_shadow_node,
  output     [4:0]    io_stageOutputs_updateGet3_shadow_root,
  output              io_stageOutputs_updateGet3_compact_valid,
  output              io_stageOutputs_updateGet3_compact_isReset,
  input      [1:0]    io_edgeInputs_0_offloadGet_state_weight,
  input               io_edgeInputs_0_offloadGet_compact_valid,
  input               io_edgeInputs_0_offloadGet_compact_isReset,
  input      [1:0]    io_edgeInputs_0_offloadGet2_state_weight,
  input               io_edgeInputs_0_offloadGet2_isTight,
  input               io_edgeInputs_0_offloadGet2_isTightExFusion,
  input               io_edgeInputs_0_offloadGet2_compact_valid,
  input               io_edgeInputs_0_offloadGet2_compact_isReset,
  input      [1:0]    io_edgeInputs_0_offloadGet3_state_weight,
  input               io_edgeInputs_0_offloadGet3_isTight,
  input               io_edgeInputs_0_offloadGet3_compact_valid,
  input               io_edgeInputs_0_offloadGet3_compact_isReset,
  input      [1:0]    io_edgeInputs_0_offloadGet4_state_weight,
  input               io_edgeInputs_0_offloadGet4_compact_valid,
  input               io_edgeInputs_0_offloadGet4_compact_isReset,
  input      [1:0]    io_edgeInputs_0_executeGet_state_weight,
  input               io_edgeInputs_0_executeGet_compact_valid,
  input               io_edgeInputs_0_executeGet_compact_isReset,
  input      [1:0]    io_edgeInputs_0_executeGet2_state_weight,
  input               io_edgeInputs_0_executeGet2_compact_valid,
  input               io_edgeInputs_0_executeGet2_compact_isReset,
  input      [1:0]    io_edgeInputs_0_executeGet3_state_weight,
  input               io_edgeInputs_0_executeGet3_isTight,
  input               io_edgeInputs_0_executeGet3_compact_valid,
  input               io_edgeInputs_0_executeGet3_compact_isReset,
  input      [1:0]    io_edgeInputs_0_updateGet_state_weight,
  input      [1:0]    io_edgeInputs_0_updateGet_remaining,
  input               io_edgeInputs_0_updateGet_compact_valid,
  input               io_edgeInputs_0_updateGet_compact_isReset,
  input      [1:0]    io_edgeInputs_0_updateGet2_state_weight,
  input      [1:0]    io_edgeInputs_0_updateGet2_remaining,
  input               io_edgeInputs_0_updateGet2_compact_valid,
  input               io_edgeInputs_0_updateGet2_compact_isReset,
  input      [1:0]    io_edgeInputs_0_updateGet3_state_weight,
  input      [1:0]    io_edgeInputs_0_updateGet3_remaining,
  input               io_edgeInputs_0_updateGet3_compact_valid,
  input               io_edgeInputs_0_updateGet3_compact_isReset,
  input      [1:0]    _zz_io_peerSpeed_0,
  input      [4:0]    _zz_io_peerNode_0,
  input      [4:0]    _zz_io_peerRoot_0,
  output     [1:0]    io_maxGrowable_length,
  input               clk,
  input               reset
);

  wire                offload3Area_tightCounter_io_isUnique;
  wire                offload3Area_tightCounter_io_isIsolated;
  wire                executeArea_offloadStalled_io_isStalled;
  wire       [1:0]    execute2Area_vertexPostExecuteState_io_after_speed;
  wire       [4:0]    execute2Area_vertexPostExecuteState_io_after_node;
  wire       [4:0]    execute2Area_vertexPostExecuteState_io_after_root;
  wire                execute2Area_vertexPostExecuteState_io_after_isVirtual;
  wire                execute2Area_vertexPostExecuteState_io_after_isDefect;
  wire       [1:0]    execute2Area_vertexPostExecuteState_io_after_grown;
  wire                updateArea_vertexPropagatingPeer_io_peer_valid;
  wire       [4:0]    updateArea_vertexPropagatingPeer_io_peer_node;
  wire       [4:0]    updateArea_vertexPropagatingPeer_io_peer_root;
  wire       [1:0]    update2Area_vertexPostUpdateState_io_after_speed;
  wire       [4:0]    update2Area_vertexPostUpdateState_io_after_node;
  wire       [4:0]    update2Area_vertexPostUpdateState_io_after_root;
  wire                update2Area_vertexPostUpdateState_io_after_isVirtual;
  wire                update2Area_vertexPostUpdateState_io_after_isDefect;
  wire       [1:0]    update2Area_vertexPostUpdateState_io_after_grown;
  wire       [1:0]    update3Area_vertexShadow_io_shadow_speed;
  wire       [4:0]    update3Area_vertexShadow_io_shadow_node;
  wire       [4:0]    update3Area_vertexShadow_io_shadow_root;
  wire       [1:0]    vertexResponse_4_io_maxGrowable_length;
  wire       [1:0]    stages_offloadSet_state_speed;
  wire       [4:0]    stages_offloadSet_state_node;
  wire       [4:0]    stages_offloadSet_state_root;
  wire                stages_offloadSet_state_isVirtual;
  wire                stages_offloadSet_state_isDefect;
  wire       [1:0]    stages_offloadSet_state_grown;
  wire                stages_offloadSet_message_valid;
  wire       [11:0]   stages_offloadSet_message_instruction;
  wire                stages_offloadSet_message_isReset;
  wire       [1:0]    stages_offloadGet_state_speed;
  wire       [4:0]    stages_offloadGet_state_node;
  wire       [4:0]    stages_offloadGet_state_root;
  wire                stages_offloadGet_state_isVirtual;
  wire                stages_offloadGet_state_isDefect;
  wire       [1:0]    stages_offloadGet_state_grown;
  wire                stages_offloadGet_message_valid;
  wire       [11:0]   stages_offloadGet_message_instruction;
  wire                stages_offloadGet_message_isReset;
  wire       [1:0]    stages_offloadSet2_state_speed;
  wire       [4:0]    stages_offloadSet2_state_node;
  wire       [4:0]    stages_offloadSet2_state_root;
  wire                stages_offloadSet2_state_isVirtual;
  wire                stages_offloadSet2_state_isDefect;
  wire       [1:0]    stages_offloadSet2_state_grown;
  wire                stages_offloadSet2_message_valid;
  wire       [11:0]   stages_offloadSet2_message_instruction;
  wire                stages_offloadSet2_message_isReset;
  wire       [1:0]    stages_offloadGet2_state_speed;
  wire       [4:0]    stages_offloadGet2_state_node;
  wire       [4:0]    stages_offloadGet2_state_root;
  wire                stages_offloadGet2_state_isVirtual;
  wire                stages_offloadGet2_state_isDefect;
  wire       [1:0]    stages_offloadGet2_state_grown;
  wire                stages_offloadGet2_message_valid;
  wire       [11:0]   stages_offloadGet2_message_instruction;
  wire                stages_offloadGet2_message_isReset;
  wire       [1:0]    stages_offloadSet3_state_speed;
  wire       [4:0]    stages_offloadSet3_state_node;
  wire       [4:0]    stages_offloadSet3_state_root;
  wire                stages_offloadSet3_state_isVirtual;
  wire                stages_offloadSet3_state_isDefect;
  wire       [1:0]    stages_offloadSet3_state_grown;
  wire                stages_offloadSet3_message_valid;
  wire       [11:0]   stages_offloadSet3_message_instruction;
  wire                stages_offloadSet3_message_isReset;
  wire                stages_offloadSet3_isUniqueTight;
  wire                stages_offloadSet3_isIsolated;
  wire       [1:0]    stages_offloadGet3_state_speed;
  wire       [4:0]    stages_offloadGet3_state_node;
  wire       [4:0]    stages_offloadGet3_state_root;
  wire                stages_offloadGet3_state_isVirtual;
  wire                stages_offloadGet3_state_isDefect;
  wire       [1:0]    stages_offloadGet3_state_grown;
  wire                stages_offloadGet3_message_valid;
  wire       [11:0]   stages_offloadGet3_message_instruction;
  wire                stages_offloadGet3_message_isReset;
  wire                stages_offloadGet3_isUniqueTight;
  wire                stages_offloadGet3_isIsolated;
  wire       [1:0]    stages_offloadSet4_state_speed;
  wire       [4:0]    stages_offloadSet4_state_node;
  wire       [4:0]    stages_offloadSet4_state_root;
  wire                stages_offloadSet4_state_isVirtual;
  wire                stages_offloadSet4_state_isDefect;
  wire       [1:0]    stages_offloadSet4_state_grown;
  wire                stages_offloadSet4_message_valid;
  wire       [11:0]   stages_offloadSet4_message_instruction;
  wire                stages_offloadSet4_message_isReset;
  wire       [1:0]    stages_offloadGet4_state_speed;
  wire       [4:0]    stages_offloadGet4_state_node;
  wire       [4:0]    stages_offloadGet4_state_root;
  wire                stages_offloadGet4_state_isVirtual;
  wire                stages_offloadGet4_state_isDefect;
  wire       [1:0]    stages_offloadGet4_state_grown;
  wire                stages_offloadGet4_message_valid;
  wire       [11:0]   stages_offloadGet4_message_instruction;
  wire                stages_offloadGet4_message_isReset;
  wire       [1:0]    stages_executeSet_state_speed;
  wire       [4:0]    stages_executeSet_state_node;
  wire       [4:0]    stages_executeSet_state_root;
  wire                stages_executeSet_state_isVirtual;
  wire                stages_executeSet_state_isDefect;
  wire       [1:0]    stages_executeSet_state_grown;
  wire                stages_executeSet_message_valid;
  wire       [11:0]   stages_executeSet_message_instruction;
  wire                stages_executeSet_message_isReset;
  wire                stages_executeSet_isStalled;
  wire       [1:0]    stages_executeGet_state_speed;
  wire       [4:0]    stages_executeGet_state_node;
  wire       [4:0]    stages_executeGet_state_root;
  wire                stages_executeGet_state_isVirtual;
  wire                stages_executeGet_state_isDefect;
  wire       [1:0]    stages_executeGet_state_grown;
  wire                stages_executeGet_message_valid;
  wire       [11:0]   stages_executeGet_message_instruction;
  wire                stages_executeGet_message_isReset;
  wire                stages_executeGet_isStalled;
  wire       [1:0]    stages_executeSet2_state_speed;
  wire       [4:0]    stages_executeSet2_state_node;
  wire       [4:0]    stages_executeSet2_state_root;
  wire                stages_executeSet2_state_isVirtual;
  wire                stages_executeSet2_state_isDefect;
  wire       [1:0]    stages_executeSet2_state_grown;
  wire                stages_executeSet2_isStalled;
  wire                stages_executeSet2_compact_valid;
  wire                stages_executeSet2_compact_isReset;
  wire       [1:0]    stages_executeGet2_state_speed;
  wire       [4:0]    stages_executeGet2_state_node;
  wire       [4:0]    stages_executeGet2_state_root;
  wire                stages_executeGet2_state_isVirtual;
  wire                stages_executeGet2_state_isDefect;
  wire       [1:0]    stages_executeGet2_state_grown;
  wire                stages_executeGet2_isStalled;
  wire                stages_executeGet2_compact_valid;
  wire                stages_executeGet2_compact_isReset;
  wire       [1:0]    stages_executeSet3_state_speed;
  wire       [4:0]    stages_executeSet3_state_node;
  wire       [4:0]    stages_executeSet3_state_root;
  wire                stages_executeSet3_state_isVirtual;
  wire                stages_executeSet3_state_isDefect;
  wire       [1:0]    stages_executeSet3_state_grown;
  wire                stages_executeSet3_isStalled;
  wire                stages_executeSet3_compact_valid;
  wire                stages_executeSet3_compact_isReset;
  wire       [1:0]    stages_executeGet3_state_speed;
  wire       [4:0]    stages_executeGet3_state_node;
  wire       [4:0]    stages_executeGet3_state_root;
  wire                stages_executeGet3_state_isVirtual;
  wire                stages_executeGet3_state_isDefect;
  wire       [1:0]    stages_executeGet3_state_grown;
  wire                stages_executeGet3_isStalled;
  wire                stages_executeGet3_compact_valid;
  wire                stages_executeGet3_compact_isReset;
  wire       [1:0]    stages_updateSet_state_speed;
  wire       [4:0]    stages_updateSet_state_node;
  wire       [4:0]    stages_updateSet_state_root;
  wire                stages_updateSet_state_isVirtual;
  wire                stages_updateSet_state_isDefect;
  wire       [1:0]    stages_updateSet_state_grown;
  wire                stages_updateSet_isStalled;
  wire                stages_updateSet_compact_valid;
  wire                stages_updateSet_compact_isReset;
  wire                stages_updateSet_propagatingPeer_valid;
  wire       [4:0]    stages_updateSet_propagatingPeer_node;
  wire       [4:0]    stages_updateSet_propagatingPeer_root;
  wire       [1:0]    stages_updateGet_state_speed;
  wire       [4:0]    stages_updateGet_state_node;
  wire       [4:0]    stages_updateGet_state_root;
  wire                stages_updateGet_state_isVirtual;
  wire                stages_updateGet_state_isDefect;
  wire       [1:0]    stages_updateGet_state_grown;
  wire                stages_updateGet_isStalled;
  wire                stages_updateGet_compact_valid;
  wire                stages_updateGet_compact_isReset;
  wire                stages_updateGet_propagatingPeer_valid;
  wire       [4:0]    stages_updateGet_propagatingPeer_node;
  wire       [4:0]    stages_updateGet_propagatingPeer_root;
  wire       [1:0]    stages_updateSet2_state_speed;
  wire       [4:0]    stages_updateSet2_state_node;
  wire       [4:0]    stages_updateSet2_state_root;
  wire                stages_updateSet2_state_isVirtual;
  wire                stages_updateSet2_state_isDefect;
  wire       [1:0]    stages_updateSet2_state_grown;
  wire                stages_updateSet2_isStalled;
  wire                stages_updateSet2_compact_valid;
  wire                stages_updateSet2_compact_isReset;
  wire                stages_updateSet2_propagatingPeer_valid;
  wire       [4:0]    stages_updateSet2_propagatingPeer_node;
  wire       [4:0]    stages_updateSet2_propagatingPeer_root;
  wire       [1:0]    stages_updateGet2_state_speed;
  wire       [4:0]    stages_updateGet2_state_node;
  wire       [4:0]    stages_updateGet2_state_root;
  wire                stages_updateGet2_state_isVirtual;
  wire                stages_updateGet2_state_isDefect;
  wire       [1:0]    stages_updateGet2_state_grown;
  wire                stages_updateGet2_isStalled;
  wire                stages_updateGet2_compact_valid;
  wire                stages_updateGet2_compact_isReset;
  wire                stages_updateGet2_propagatingPeer_valid;
  wire       [4:0]    stages_updateGet2_propagatingPeer_node;
  wire       [4:0]    stages_updateGet2_propagatingPeer_root;
  wire       [1:0]    stages_updateSet3_state_speed;
  wire       [4:0]    stages_updateSet3_state_node;
  wire       [4:0]    stages_updateSet3_state_root;
  wire                stages_updateSet3_state_isVirtual;
  wire                stages_updateSet3_state_isDefect;
  wire       [1:0]    stages_updateSet3_state_grown;
  wire       [1:0]    stages_updateSet3_shadow_speed;
  wire       [4:0]    stages_updateSet3_shadow_node;
  wire       [4:0]    stages_updateSet3_shadow_root;
  wire                stages_updateSet3_compact_valid;
  wire                stages_updateSet3_compact_isReset;
  wire       [1:0]    stages_updateGet3_state_speed;
  wire       [4:0]    stages_updateGet3_state_node;
  wire       [4:0]    stages_updateGet3_state_root;
  wire                stages_updateGet3_state_isVirtual;
  wire                stages_updateGet3_state_isDefect;
  wire       [1:0]    stages_updateGet3_state_grown;
  wire       [1:0]    stages_updateGet3_shadow_speed;
  wire       [4:0]    stages_updateGet3_shadow_node;
  wire       [4:0]    stages_updateGet3_shadow_root;
  wire                stages_updateGet3_compact_valid;
  wire                stages_updateGet3_compact_isReset;
  reg        [1:0]    register_speed;
  reg        [4:0]    register_node;
  reg        [4:0]    register_root;
  reg                 register_isVirtual;
  reg                 register_isDefect;
  reg        [1:0]    register_grown;
  wire       [1:0]    fetchState_speed;
  wire       [4:0]    fetchState_node;
  wire       [4:0]    fetchState_root;
  wire                fetchState_isVirtual;
  wire                fetchState_isDefect;
  wire       [1:0]    fetchState_grown;
  wire                message_valid;
  wire       [11:0]   message_instruction;
  wire                message_isReset;

  VertexTightCounter_1 offload3Area_tightCounter (
    .io_tights_0   (io_edgeInputs_0_offloadGet2_isTightExFusion), //i
    .io_isUnique   (offload3Area_tightCounter_io_isUnique      ), //o
    .io_isIsolated (offload3Area_tightCounter_io_isIsolated    )  //o
  );
  OffloadStalled_3 executeArea_offloadStalled (
    .io_isStalled (executeArea_offloadStalled_io_isStalled)  //o
  );
  VertexPostExecuteState_1 execute2Area_vertexPostExecuteState (
    .io_before_speed        (stages_executeGet_state_speed[1:0]                     ), //i
    .io_before_node         (stages_executeGet_state_node[4:0]                      ), //i
    .io_before_root         (stages_executeGet_state_root[4:0]                      ), //i
    .io_before_isVirtual    (stages_executeGet_state_isVirtual                      ), //i
    .io_before_isDefect     (stages_executeGet_state_isDefect                       ), //i
    .io_before_grown        (stages_executeGet_state_grown[1:0]                     ), //i
    .io_message_valid       (stages_executeGet_message_valid                        ), //i
    .io_message_instruction (stages_executeGet_message_instruction[11:0]            ), //i
    .io_message_isReset     (stages_executeGet_message_isReset                      ), //i
    .io_isStalled           (stages_executeGet_isStalled                            ), //i
    .io_after_speed         (execute2Area_vertexPostExecuteState_io_after_speed[1:0]), //o
    .io_after_node          (execute2Area_vertexPostExecuteState_io_after_node[4:0] ), //o
    .io_after_root          (execute2Area_vertexPostExecuteState_io_after_root[4:0] ), //o
    .io_after_isVirtual     (execute2Area_vertexPostExecuteState_io_after_isVirtual ), //o
    .io_after_isDefect      (execute2Area_vertexPostExecuteState_io_after_isDefect  ), //o
    .io_after_grown         (execute2Area_vertexPostExecuteState_io_after_grown[1:0]), //o
    .clk                    (clk                                                    ), //i
    .reset                  (reset                                                  )  //i
  );
  VertexPropagatingPeer_1 updateArea_vertexPropagatingPeer (
    .io_grown         (stages_executeGet3_state_grown[1:0]               ), //i
    .io_edgeIsTight_0 (io_edgeInputs_0_executeGet3_isTight               ), //i
    .io_peerSpeed_0   (_zz_io_peerSpeed_0[1:0]                           ), //i
    .io_peerNode_0    (_zz_io_peerNode_0[4:0]                            ), //i
    .io_peerRoot_0    (_zz_io_peerRoot_0[4:0]                            ), //i
    .io_peer_valid    (updateArea_vertexPropagatingPeer_io_peer_valid    ), //o
    .io_peer_node     (updateArea_vertexPropagatingPeer_io_peer_node[4:0]), //o
    .io_peer_root     (updateArea_vertexPropagatingPeer_io_peer_root[4:0])  //o
  );
  VertexPostUpdateState_3 update2Area_vertexPostUpdateState (
    .io_before_speed     (stages_updateGet_state_speed[1:0]                    ), //i
    .io_before_node      (stages_updateGet_state_node[4:0]                     ), //i
    .io_before_root      (stages_updateGet_state_root[4:0]                     ), //i
    .io_before_isVirtual (stages_updateGet_state_isVirtual                     ), //i
    .io_before_isDefect  (stages_updateGet_state_isDefect                      ), //i
    .io_before_grown     (stages_updateGet_state_grown[1:0]                    ), //i
    .io_propagator_valid (stages_updateGet_propagatingPeer_valid               ), //i
    .io_propagator_node  (stages_updateGet_propagatingPeer_node[4:0]           ), //i
    .io_propagator_root  (stages_updateGet_propagatingPeer_root[4:0]           ), //i
    .io_after_speed      (update2Area_vertexPostUpdateState_io_after_speed[1:0]), //o
    .io_after_node       (update2Area_vertexPostUpdateState_io_after_node[4:0] ), //o
    .io_after_root       (update2Area_vertexPostUpdateState_io_after_root[4:0] ), //o
    .io_after_isVirtual  (update2Area_vertexPostUpdateState_io_after_isVirtual ), //o
    .io_after_isDefect   (update2Area_vertexPostUpdateState_io_after_isDefect  ), //o
    .io_after_grown      (update2Area_vertexPostUpdateState_io_after_grown[1:0])  //o
  );
  VertexShadow_3 update3Area_vertexShadow (
    .io_isVirtual        (stages_updateGet2_state_isVirtual            ), //i
    .io_node             (stages_updateGet2_state_node[4:0]            ), //i
    .io_root             (stages_updateGet2_state_root[4:0]            ), //i
    .io_speed            (stages_updateGet2_state_speed[1:0]           ), //i
    .io_grown            (stages_updateGet2_state_grown[1:0]           ), //i
    .io_isStalled        (stages_updateGet2_isStalled                  ), //i
    .io_propagator_valid (stages_updateGet2_propagatingPeer_valid      ), //i
    .io_propagator_node  (stages_updateGet2_propagatingPeer_node[4:0]  ), //i
    .io_propagator_root  (stages_updateGet2_propagatingPeer_root[4:0]  ), //i
    .io_shadow_speed     (update3Area_vertexShadow_io_shadow_speed[1:0]), //o
    .io_shadow_node      (update3Area_vertexShadow_io_shadow_node[4:0] ), //o
    .io_shadow_root      (update3Area_vertexShadow_io_shadow_root[4:0] )  //o
  );
  VertexResponse_3 vertexResponse_4 (
    .io_state_speed        (stages_updateGet3_state_speed[1:0]         ), //i
    .io_state_node         (stages_updateGet3_state_node[4:0]          ), //i
    .io_state_root         (stages_updateGet3_state_root[4:0]          ), //i
    .io_state_isVirtual    (stages_updateGet3_state_isVirtual          ), //i
    .io_state_isDefect     (stages_updateGet3_state_isDefect           ), //i
    .io_state_grown        (stages_updateGet3_state_grown[1:0]         ), //i
    .io_maxGrowable_length (vertexResponse_4_io_maxGrowable_length[1:0])  //o
  );
  assign io_stageOutputs_offloadGet_state_speed = stages_offloadGet_state_speed;
  assign io_stageOutputs_offloadGet_state_node = stages_offloadGet_state_node;
  assign io_stageOutputs_offloadGet_state_root = stages_offloadGet_state_root;
  assign io_stageOutputs_offloadGet_state_isVirtual = stages_offloadGet_state_isVirtual;
  assign io_stageOutputs_offloadGet_state_isDefect = stages_offloadGet_state_isDefect;
  assign io_stageOutputs_offloadGet_state_grown = stages_offloadGet_state_grown;
  assign io_stageOutputs_offloadGet_message_valid = stages_offloadGet_message_valid;
  assign io_stageOutputs_offloadGet_message_instruction = stages_offloadGet_message_instruction;
  assign io_stageOutputs_offloadGet_message_isReset = stages_offloadGet_message_isReset;
  assign io_stageOutputs_offloadGet2_state_speed = stages_offloadGet2_state_speed;
  assign io_stageOutputs_offloadGet2_state_node = stages_offloadGet2_state_node;
  assign io_stageOutputs_offloadGet2_state_root = stages_offloadGet2_state_root;
  assign io_stageOutputs_offloadGet2_state_isVirtual = stages_offloadGet2_state_isVirtual;
  assign io_stageOutputs_offloadGet2_state_isDefect = stages_offloadGet2_state_isDefect;
  assign io_stageOutputs_offloadGet2_state_grown = stages_offloadGet2_state_grown;
  assign io_stageOutputs_offloadGet2_message_valid = stages_offloadGet2_message_valid;
  assign io_stageOutputs_offloadGet2_message_instruction = stages_offloadGet2_message_instruction;
  assign io_stageOutputs_offloadGet2_message_isReset = stages_offloadGet2_message_isReset;
  assign io_stageOutputs_offloadGet3_state_speed = stages_offloadGet3_state_speed;
  assign io_stageOutputs_offloadGet3_state_node = stages_offloadGet3_state_node;
  assign io_stageOutputs_offloadGet3_state_root = stages_offloadGet3_state_root;
  assign io_stageOutputs_offloadGet3_state_isVirtual = stages_offloadGet3_state_isVirtual;
  assign io_stageOutputs_offloadGet3_state_isDefect = stages_offloadGet3_state_isDefect;
  assign io_stageOutputs_offloadGet3_state_grown = stages_offloadGet3_state_grown;
  assign io_stageOutputs_offloadGet3_message_valid = stages_offloadGet3_message_valid;
  assign io_stageOutputs_offloadGet3_message_instruction = stages_offloadGet3_message_instruction;
  assign io_stageOutputs_offloadGet3_message_isReset = stages_offloadGet3_message_isReset;
  assign io_stageOutputs_offloadGet3_isUniqueTight = stages_offloadGet3_isUniqueTight;
  assign io_stageOutputs_offloadGet3_isIsolated = stages_offloadGet3_isIsolated;
  assign io_stageOutputs_offloadGet4_state_speed = stages_offloadGet4_state_speed;
  assign io_stageOutputs_offloadGet4_state_node = stages_offloadGet4_state_node;
  assign io_stageOutputs_offloadGet4_state_root = stages_offloadGet4_state_root;
  assign io_stageOutputs_offloadGet4_state_isVirtual = stages_offloadGet4_state_isVirtual;
  assign io_stageOutputs_offloadGet4_state_isDefect = stages_offloadGet4_state_isDefect;
  assign io_stageOutputs_offloadGet4_state_grown = stages_offloadGet4_state_grown;
  assign io_stageOutputs_offloadGet4_message_valid = stages_offloadGet4_message_valid;
  assign io_stageOutputs_offloadGet4_message_instruction = stages_offloadGet4_message_instruction;
  assign io_stageOutputs_offloadGet4_message_isReset = stages_offloadGet4_message_isReset;
  assign io_stageOutputs_executeGet_state_speed = stages_executeGet_state_speed;
  assign io_stageOutputs_executeGet_state_node = stages_executeGet_state_node;
  assign io_stageOutputs_executeGet_state_root = stages_executeGet_state_root;
  assign io_stageOutputs_executeGet_state_isVirtual = stages_executeGet_state_isVirtual;
  assign io_stageOutputs_executeGet_state_isDefect = stages_executeGet_state_isDefect;
  assign io_stageOutputs_executeGet_state_grown = stages_executeGet_state_grown;
  assign io_stageOutputs_executeGet_message_valid = stages_executeGet_message_valid;
  assign io_stageOutputs_executeGet_message_instruction = stages_executeGet_message_instruction;
  assign io_stageOutputs_executeGet_message_isReset = stages_executeGet_message_isReset;
  assign io_stageOutputs_executeGet_isStalled = stages_executeGet_isStalled;
  assign io_stageOutputs_executeGet2_state_speed = stages_executeGet2_state_speed;
  assign io_stageOutputs_executeGet2_state_node = stages_executeGet2_state_node;
  assign io_stageOutputs_executeGet2_state_root = stages_executeGet2_state_root;
  assign io_stageOutputs_executeGet2_state_isVirtual = stages_executeGet2_state_isVirtual;
  assign io_stageOutputs_executeGet2_state_isDefect = stages_executeGet2_state_isDefect;
  assign io_stageOutputs_executeGet2_state_grown = stages_executeGet2_state_grown;
  assign io_stageOutputs_executeGet2_isStalled = stages_executeGet2_isStalled;
  assign io_stageOutputs_executeGet2_compact_valid = stages_executeGet2_compact_valid;
  assign io_stageOutputs_executeGet2_compact_isReset = stages_executeGet2_compact_isReset;
  assign io_stageOutputs_executeGet3_state_speed = stages_executeGet3_state_speed;
  assign io_stageOutputs_executeGet3_state_node = stages_executeGet3_state_node;
  assign io_stageOutputs_executeGet3_state_root = stages_executeGet3_state_root;
  assign io_stageOutputs_executeGet3_state_isVirtual = stages_executeGet3_state_isVirtual;
  assign io_stageOutputs_executeGet3_state_isDefect = stages_executeGet3_state_isDefect;
  assign io_stageOutputs_executeGet3_state_grown = stages_executeGet3_state_grown;
  assign io_stageOutputs_executeGet3_isStalled = stages_executeGet3_isStalled;
  assign io_stageOutputs_executeGet3_compact_valid = stages_executeGet3_compact_valid;
  assign io_stageOutputs_executeGet3_compact_isReset = stages_executeGet3_compact_isReset;
  assign io_stageOutputs_updateGet_state_speed = stages_updateGet_state_speed;
  assign io_stageOutputs_updateGet_state_node = stages_updateGet_state_node;
  assign io_stageOutputs_updateGet_state_root = stages_updateGet_state_root;
  assign io_stageOutputs_updateGet_state_isVirtual = stages_updateGet_state_isVirtual;
  assign io_stageOutputs_updateGet_state_isDefect = stages_updateGet_state_isDefect;
  assign io_stageOutputs_updateGet_state_grown = stages_updateGet_state_grown;
  assign io_stageOutputs_updateGet_isStalled = stages_updateGet_isStalled;
  assign io_stageOutputs_updateGet_compact_valid = stages_updateGet_compact_valid;
  assign io_stageOutputs_updateGet_compact_isReset = stages_updateGet_compact_isReset;
  assign io_stageOutputs_updateGet_propagatingPeer_valid = stages_updateGet_propagatingPeer_valid;
  assign io_stageOutputs_updateGet_propagatingPeer_node = stages_updateGet_propagatingPeer_node;
  assign io_stageOutputs_updateGet_propagatingPeer_root = stages_updateGet_propagatingPeer_root;
  assign io_stageOutputs_updateGet2_state_speed = stages_updateGet2_state_speed;
  assign io_stageOutputs_updateGet2_state_node = stages_updateGet2_state_node;
  assign io_stageOutputs_updateGet2_state_root = stages_updateGet2_state_root;
  assign io_stageOutputs_updateGet2_state_isVirtual = stages_updateGet2_state_isVirtual;
  assign io_stageOutputs_updateGet2_state_isDefect = stages_updateGet2_state_isDefect;
  assign io_stageOutputs_updateGet2_state_grown = stages_updateGet2_state_grown;
  assign io_stageOutputs_updateGet2_isStalled = stages_updateGet2_isStalled;
  assign io_stageOutputs_updateGet2_compact_valid = stages_updateGet2_compact_valid;
  assign io_stageOutputs_updateGet2_compact_isReset = stages_updateGet2_compact_isReset;
  assign io_stageOutputs_updateGet2_propagatingPeer_valid = stages_updateGet2_propagatingPeer_valid;
  assign io_stageOutputs_updateGet2_propagatingPeer_node = stages_updateGet2_propagatingPeer_node;
  assign io_stageOutputs_updateGet2_propagatingPeer_root = stages_updateGet2_propagatingPeer_root;
  assign io_stageOutputs_updateGet3_state_speed = stages_updateGet3_state_speed;
  assign io_stageOutputs_updateGet3_state_node = stages_updateGet3_state_node;
  assign io_stageOutputs_updateGet3_state_root = stages_updateGet3_state_root;
  assign io_stageOutputs_updateGet3_state_isVirtual = stages_updateGet3_state_isVirtual;
  assign io_stageOutputs_updateGet3_state_isDefect = stages_updateGet3_state_isDefect;
  assign io_stageOutputs_updateGet3_state_grown = stages_updateGet3_state_grown;
  assign io_stageOutputs_updateGet3_shadow_speed = stages_updateGet3_shadow_speed;
  assign io_stageOutputs_updateGet3_shadow_node = stages_updateGet3_shadow_node;
  assign io_stageOutputs_updateGet3_shadow_root = stages_updateGet3_shadow_root;
  assign io_stageOutputs_updateGet3_compact_valid = stages_updateGet3_compact_valid;
  assign io_stageOutputs_updateGet3_compact_isReset = stages_updateGet3_compact_isReset;
  assign fetchState_speed = register_speed;
  assign fetchState_node = register_node;
  assign fetchState_root = register_root;
  assign fetchState_isVirtual = register_isVirtual;
  assign fetchState_isDefect = register_isDefect;
  assign fetchState_grown = register_grown;
  assign message_valid = io_message_valid;
  assign message_instruction = io_message_instruction;
  assign message_isReset = io_message_isReset;
  assign stages_offloadSet_message_valid = message_valid;
  assign stages_offloadSet_message_instruction = message_instruction;
  assign stages_offloadSet_message_isReset = message_isReset;
  assign stages_offloadSet_state_speed = (message_isReset ? 2'b00 : fetchState_speed);
  assign stages_offloadSet_state_node = (message_isReset ? 5'h1f : fetchState_node);
  assign stages_offloadSet_state_root = (message_isReset ? 5'h1f : fetchState_root);
  assign stages_offloadSet_state_isVirtual = (message_isReset ? 1'b1 : fetchState_isVirtual);
  assign stages_offloadSet_state_isDefect = (message_isReset ? 1'b0 : fetchState_isDefect);
  assign stages_offloadSet_state_grown = (message_isReset ? 2'b00 : fetchState_grown);
  assign stages_offloadSet2_state_speed = stages_offloadGet_state_speed;
  assign stages_offloadSet2_state_node = stages_offloadGet_state_node;
  assign stages_offloadSet2_state_root = stages_offloadGet_state_root;
  assign stages_offloadSet2_state_isVirtual = stages_offloadGet_state_isVirtual;
  assign stages_offloadSet2_state_isDefect = stages_offloadGet_state_isDefect;
  assign stages_offloadSet2_state_grown = stages_offloadGet_state_grown;
  assign stages_offloadSet2_message_valid = stages_offloadGet_message_valid;
  assign stages_offloadSet2_message_instruction = stages_offloadGet_message_instruction;
  assign stages_offloadSet2_message_isReset = stages_offloadGet_message_isReset;
  assign stages_offloadSet3_state_speed = stages_offloadGet2_state_speed;
  assign stages_offloadSet3_state_node = stages_offloadGet2_state_node;
  assign stages_offloadSet3_state_root = stages_offloadGet2_state_root;
  assign stages_offloadSet3_state_isVirtual = stages_offloadGet2_state_isVirtual;
  assign stages_offloadSet3_state_isDefect = stages_offloadGet2_state_isDefect;
  assign stages_offloadSet3_state_grown = stages_offloadGet2_state_grown;
  assign stages_offloadSet3_message_valid = stages_offloadGet2_message_valid;
  assign stages_offloadSet3_message_instruction = stages_offloadGet2_message_instruction;
  assign stages_offloadSet3_message_isReset = stages_offloadGet2_message_isReset;
  assign stages_offloadSet3_isUniqueTight = offload3Area_tightCounter_io_isUnique;
  assign stages_offloadSet3_isIsolated = offload3Area_tightCounter_io_isIsolated;
  assign stages_offloadSet4_state_speed = stages_offloadGet3_state_speed;
  assign stages_offloadSet4_state_node = stages_offloadGet3_state_node;
  assign stages_offloadSet4_state_root = stages_offloadGet3_state_root;
  assign stages_offloadSet4_state_isVirtual = stages_offloadGet3_state_isVirtual;
  assign stages_offloadSet4_state_isDefect = stages_offloadGet3_state_isDefect;
  assign stages_offloadSet4_state_grown = stages_offloadGet3_state_grown;
  assign stages_offloadSet4_message_valid = stages_offloadGet3_message_valid;
  assign stages_offloadSet4_message_instruction = stages_offloadGet3_message_instruction;
  assign stages_offloadSet4_message_isReset = stages_offloadGet3_message_isReset;
  assign stages_executeSet_state_speed = stages_offloadGet4_state_speed;
  assign stages_executeSet_state_node = stages_offloadGet4_state_node;
  assign stages_executeSet_state_root = stages_offloadGet4_state_root;
  assign stages_executeSet_state_isVirtual = stages_offloadGet4_state_isVirtual;
  assign stages_executeSet_state_isDefect = stages_offloadGet4_state_isDefect;
  assign stages_executeSet_state_grown = stages_offloadGet4_state_grown;
  assign stages_executeSet_message_valid = stages_offloadGet4_message_valid;
  assign stages_executeSet_message_instruction = stages_offloadGet4_message_instruction;
  assign stages_executeSet_message_isReset = stages_offloadGet4_message_isReset;
  assign stages_executeSet_isStalled = executeArea_offloadStalled_io_isStalled;
  assign stages_executeSet2_isStalled = stages_executeGet_isStalled;
  assign stages_executeSet2_compact_valid = stages_executeGet_message_valid;
  assign stages_executeSet2_compact_isReset = stages_executeGet_message_isReset;
  assign stages_executeSet2_state_speed = execute2Area_vertexPostExecuteState_io_after_speed;
  assign stages_executeSet2_state_node = execute2Area_vertexPostExecuteState_io_after_node;
  assign stages_executeSet2_state_root = execute2Area_vertexPostExecuteState_io_after_root;
  assign stages_executeSet2_state_isVirtual = execute2Area_vertexPostExecuteState_io_after_isVirtual;
  assign stages_executeSet2_state_isDefect = execute2Area_vertexPostExecuteState_io_after_isDefect;
  assign stages_executeSet2_state_grown = execute2Area_vertexPostExecuteState_io_after_grown;
  assign stages_executeSet3_state_speed = stages_executeGet2_state_speed;
  assign stages_executeSet3_state_node = stages_executeGet2_state_node;
  assign stages_executeSet3_state_root = stages_executeGet2_state_root;
  assign stages_executeSet3_state_isVirtual = stages_executeGet2_state_isVirtual;
  assign stages_executeSet3_state_isDefect = stages_executeGet2_state_isDefect;
  assign stages_executeSet3_state_grown = stages_executeGet2_state_grown;
  assign stages_executeSet3_isStalled = stages_executeGet2_isStalled;
  assign stages_executeSet3_compact_valid = stages_executeGet2_compact_valid;
  assign stages_executeSet3_compact_isReset = stages_executeGet2_compact_isReset;
  assign stages_updateSet_state_speed = stages_executeGet3_state_speed;
  assign stages_updateSet_state_node = stages_executeGet3_state_node;
  assign stages_updateSet_state_root = stages_executeGet3_state_root;
  assign stages_updateSet_state_isVirtual = stages_executeGet3_state_isVirtual;
  assign stages_updateSet_state_isDefect = stages_executeGet3_state_isDefect;
  assign stages_updateSet_state_grown = stages_executeGet3_state_grown;
  assign stages_updateSet_isStalled = stages_executeGet3_isStalled;
  assign stages_updateSet_compact_valid = stages_executeGet3_compact_valid;
  assign stages_updateSet_compact_isReset = stages_executeGet3_compact_isReset;
  assign stages_updateSet_propagatingPeer_valid = updateArea_vertexPropagatingPeer_io_peer_valid;
  assign stages_updateSet_propagatingPeer_node = updateArea_vertexPropagatingPeer_io_peer_node;
  assign stages_updateSet_propagatingPeer_root = updateArea_vertexPropagatingPeer_io_peer_root;
  assign stages_updateSet2_compact_valid = stages_updateGet_compact_valid;
  assign stages_updateSet2_compact_isReset = stages_updateGet_compact_isReset;
  assign stages_updateSet2_isStalled = stages_updateGet_isStalled;
  assign stages_updateSet2_propagatingPeer_valid = stages_updateGet_propagatingPeer_valid;
  assign stages_updateSet2_propagatingPeer_node = stages_updateGet_propagatingPeer_node;
  assign stages_updateSet2_propagatingPeer_root = stages_updateGet_propagatingPeer_root;
  assign stages_updateSet2_state_speed = update2Area_vertexPostUpdateState_io_after_speed;
  assign stages_updateSet2_state_node = update2Area_vertexPostUpdateState_io_after_node;
  assign stages_updateSet2_state_root = update2Area_vertexPostUpdateState_io_after_root;
  assign stages_updateSet2_state_isVirtual = update2Area_vertexPostUpdateState_io_after_isVirtual;
  assign stages_updateSet2_state_isDefect = update2Area_vertexPostUpdateState_io_after_isDefect;
  assign stages_updateSet2_state_grown = update2Area_vertexPostUpdateState_io_after_grown;
  assign stages_updateSet3_state_speed = stages_updateGet2_state_speed;
  assign stages_updateSet3_state_node = stages_updateGet2_state_node;
  assign stages_updateSet3_state_root = stages_updateGet2_state_root;
  assign stages_updateSet3_state_isVirtual = stages_updateGet2_state_isVirtual;
  assign stages_updateSet3_state_isDefect = stages_updateGet2_state_isDefect;
  assign stages_updateSet3_state_grown = stages_updateGet2_state_grown;
  assign stages_updateSet3_compact_valid = stages_updateGet2_compact_valid;
  assign stages_updateSet3_compact_isReset = stages_updateGet2_compact_isReset;
  assign stages_updateSet3_shadow_speed = update3Area_vertexShadow_io_shadow_speed;
  assign stages_updateSet3_shadow_node = update3Area_vertexShadow_io_shadow_node;
  assign stages_updateSet3_shadow_root = update3Area_vertexShadow_io_shadow_root;
  assign io_maxGrowable_length = vertexResponse_4_io_maxGrowable_length;
  assign stages_executeGet3_state_speed = stages_executeSet3_state_speed;
  assign stages_executeGet3_state_node = stages_executeSet3_state_node;
  assign stages_executeGet3_state_root = stages_executeSet3_state_root;
  assign stages_executeGet3_state_isVirtual = stages_executeSet3_state_isVirtual;
  assign stages_executeGet3_state_isDefect = stages_executeSet3_state_isDefect;
  assign stages_executeGet3_state_grown = stages_executeSet3_state_grown;
  assign stages_executeGet3_isStalled = stages_executeSet3_isStalled;
  assign stages_executeGet3_compact_valid = stages_executeSet3_compact_valid;
  assign stages_executeGet3_compact_isReset = stages_executeSet3_compact_isReset;
  assign stages_updateGet_state_speed = stages_updateSet_state_speed;
  assign stages_updateGet_state_node = stages_updateSet_state_node;
  assign stages_updateGet_state_root = stages_updateSet_state_root;
  assign stages_updateGet_state_isVirtual = stages_updateSet_state_isVirtual;
  assign stages_updateGet_state_isDefect = stages_updateSet_state_isDefect;
  assign stages_updateGet_state_grown = stages_updateSet_state_grown;
  assign stages_updateGet_isStalled = stages_updateSet_isStalled;
  assign stages_updateGet_compact_valid = stages_updateSet_compact_valid;
  assign stages_updateGet_compact_isReset = stages_updateSet_compact_isReset;
  assign stages_updateGet_propagatingPeer_valid = stages_updateSet_propagatingPeer_valid;
  assign stages_updateGet_propagatingPeer_node = stages_updateSet_propagatingPeer_node;
  assign stages_updateGet_propagatingPeer_root = stages_updateSet_propagatingPeer_root;
  assign stages_offloadGet_state_speed = stages_offloadSet_state_speed;
  assign stages_offloadGet_state_node = stages_offloadSet_state_node;
  assign stages_offloadGet_state_root = stages_offloadSet_state_root;
  assign stages_offloadGet_state_isVirtual = stages_offloadSet_state_isVirtual;
  assign stages_offloadGet_state_isDefect = stages_offloadSet_state_isDefect;
  assign stages_offloadGet_state_grown = stages_offloadSet_state_grown;
  assign stages_offloadGet_message_valid = stages_offloadSet_message_valid;
  assign stages_offloadGet_message_instruction = stages_offloadSet_message_instruction;
  assign stages_offloadGet_message_isReset = stages_offloadSet_message_isReset;
  assign stages_offloadGet4_state_speed = stages_offloadSet4_state_speed;
  assign stages_offloadGet4_state_node = stages_offloadSet4_state_node;
  assign stages_offloadGet4_state_root = stages_offloadSet4_state_root;
  assign stages_offloadGet4_state_isVirtual = stages_offloadSet4_state_isVirtual;
  assign stages_offloadGet4_state_isDefect = stages_offloadSet4_state_isDefect;
  assign stages_offloadGet4_state_grown = stages_offloadSet4_state_grown;
  assign stages_offloadGet4_message_valid = stages_offloadSet4_message_valid;
  assign stages_offloadGet4_message_instruction = stages_offloadSet4_message_instruction;
  assign stages_offloadGet4_message_isReset = stages_offloadSet4_message_isReset;
  assign stages_updateGet3_state_speed = stages_updateSet3_state_speed;
  assign stages_updateGet3_state_node = stages_updateSet3_state_node;
  assign stages_updateGet3_state_root = stages_updateSet3_state_root;
  assign stages_updateGet3_state_isVirtual = stages_updateSet3_state_isVirtual;
  assign stages_updateGet3_state_isDefect = stages_updateSet3_state_isDefect;
  assign stages_updateGet3_state_grown = stages_updateSet3_state_grown;
  assign stages_updateGet3_shadow_speed = stages_updateSet3_shadow_speed;
  assign stages_updateGet3_shadow_node = stages_updateSet3_shadow_node;
  assign stages_updateGet3_shadow_root = stages_updateSet3_shadow_root;
  assign stages_updateGet3_compact_valid = stages_updateSet3_compact_valid;
  assign stages_updateGet3_compact_isReset = stages_updateSet3_compact_isReset;
  assign stages_executeGet_state_speed = stages_executeSet_state_speed;
  assign stages_executeGet_state_node = stages_executeSet_state_node;
  assign stages_executeGet_state_root = stages_executeSet_state_root;
  assign stages_executeGet_state_isVirtual = stages_executeSet_state_isVirtual;
  assign stages_executeGet_state_isDefect = stages_executeSet_state_isDefect;
  assign stages_executeGet_state_grown = stages_executeSet_state_grown;
  assign stages_executeGet_message_valid = stages_executeSet_message_valid;
  assign stages_executeGet_message_instruction = stages_executeSet_message_instruction;
  assign stages_executeGet_message_isReset = stages_executeSet_message_isReset;
  assign stages_executeGet_isStalled = stages_executeSet_isStalled;
  assign stages_executeGet2_state_speed = stages_executeSet2_state_speed;
  assign stages_executeGet2_state_node = stages_executeSet2_state_node;
  assign stages_executeGet2_state_root = stages_executeSet2_state_root;
  assign stages_executeGet2_state_isVirtual = stages_executeSet2_state_isVirtual;
  assign stages_executeGet2_state_isDefect = stages_executeSet2_state_isDefect;
  assign stages_executeGet2_state_grown = stages_executeSet2_state_grown;
  assign stages_executeGet2_isStalled = stages_executeSet2_isStalled;
  assign stages_executeGet2_compact_valid = stages_executeSet2_compact_valid;
  assign stages_executeGet2_compact_isReset = stages_executeSet2_compact_isReset;
  assign stages_offloadGet3_state_speed = stages_offloadSet3_state_speed;
  assign stages_offloadGet3_state_node = stages_offloadSet3_state_node;
  assign stages_offloadGet3_state_root = stages_offloadSet3_state_root;
  assign stages_offloadGet3_state_isVirtual = stages_offloadSet3_state_isVirtual;
  assign stages_offloadGet3_state_isDefect = stages_offloadSet3_state_isDefect;
  assign stages_offloadGet3_state_grown = stages_offloadSet3_state_grown;
  assign stages_offloadGet3_message_valid = stages_offloadSet3_message_valid;
  assign stages_offloadGet3_message_instruction = stages_offloadSet3_message_instruction;
  assign stages_offloadGet3_message_isReset = stages_offloadSet3_message_isReset;
  assign stages_offloadGet3_isUniqueTight = stages_offloadSet3_isUniqueTight;
  assign stages_offloadGet3_isIsolated = stages_offloadSet3_isIsolated;
  assign stages_updateGet2_state_speed = stages_updateSet2_state_speed;
  assign stages_updateGet2_state_node = stages_updateSet2_state_node;
  assign stages_updateGet2_state_root = stages_updateSet2_state_root;
  assign stages_updateGet2_state_isVirtual = stages_updateSet2_state_isVirtual;
  assign stages_updateGet2_state_isDefect = stages_updateSet2_state_isDefect;
  assign stages_updateGet2_state_grown = stages_updateSet2_state_grown;
  assign stages_updateGet2_isStalled = stages_updateSet2_isStalled;
  assign stages_updateGet2_compact_valid = stages_updateSet2_compact_valid;
  assign stages_updateGet2_compact_isReset = stages_updateSet2_compact_isReset;
  assign stages_updateGet2_propagatingPeer_valid = stages_updateSet2_propagatingPeer_valid;
  assign stages_updateGet2_propagatingPeer_node = stages_updateSet2_propagatingPeer_node;
  assign stages_updateGet2_propagatingPeer_root = stages_updateSet2_propagatingPeer_root;
  assign stages_offloadGet2_state_speed = stages_offloadSet2_state_speed;
  assign stages_offloadGet2_state_node = stages_offloadSet2_state_node;
  assign stages_offloadGet2_state_root = stages_offloadSet2_state_root;
  assign stages_offloadGet2_state_isVirtual = stages_offloadSet2_state_isVirtual;
  assign stages_offloadGet2_state_isDefect = stages_offloadSet2_state_isDefect;
  assign stages_offloadGet2_state_grown = stages_offloadSet2_state_grown;
  assign stages_offloadGet2_message_valid = stages_offloadSet2_message_valid;
  assign stages_offloadGet2_message_instruction = stages_offloadSet2_message_instruction;
  assign stages_offloadGet2_message_isReset = stages_offloadSet2_message_isReset;
  always @(posedge clk or posedge reset) begin
    if(reset) begin
      register_speed <= 2'b00;
      register_node <= 5'h1f;
      register_root <= 5'h1f;
      register_isVirtual <= 1'b1;
      register_isDefect <= 1'b0;
      register_grown <= 2'b00;
    end else begin
      if(stages_updateGet3_compact_valid) begin
        register_speed <= stages_updateGet3_state_speed;
        register_node <= stages_updateGet3_state_node;
        register_root <= stages_updateGet3_state_root;
        register_isVirtual <= stages_updateGet3_state_isVirtual;
        register_isDefect <= stages_updateGet3_state_isDefect;
        register_grown <= stages_updateGet3_state_grown;
      end
    end
  end


endmodule

module Vertex_1 (
  input               io_message_valid,
  input      [11:0]   io_message_instruction,
  input               io_message_isReset,
  output     [1:0]    io_stageOutputs_offloadGet_state_speed,
  output     [4:0]    io_stageOutputs_offloadGet_state_node,
  output     [4:0]    io_stageOutputs_offloadGet_state_root,
  output              io_stageOutputs_offloadGet_state_isVirtual,
  output              io_stageOutputs_offloadGet_state_isDefect,
  output     [1:0]    io_stageOutputs_offloadGet_state_grown,
  output              io_stageOutputs_offloadGet_message_valid,
  output     [11:0]   io_stageOutputs_offloadGet_message_instruction,
  output              io_stageOutputs_offloadGet_message_isReset,
  output     [1:0]    io_stageOutputs_offloadGet2_state_speed,
  output     [4:0]    io_stageOutputs_offloadGet2_state_node,
  output     [4:0]    io_stageOutputs_offloadGet2_state_root,
  output              io_stageOutputs_offloadGet2_state_isVirtual,
  output              io_stageOutputs_offloadGet2_state_isDefect,
  output     [1:0]    io_stageOutputs_offloadGet2_state_grown,
  output              io_stageOutputs_offloadGet2_message_valid,
  output     [11:0]   io_stageOutputs_offloadGet2_message_instruction,
  output              io_stageOutputs_offloadGet2_message_isReset,
  output     [1:0]    io_stageOutputs_offloadGet3_state_speed,
  output     [4:0]    io_stageOutputs_offloadGet3_state_node,
  output     [4:0]    io_stageOutputs_offloadGet3_state_root,
  output              io_stageOutputs_offloadGet3_state_isVirtual,
  output              io_stageOutputs_offloadGet3_state_isDefect,
  output     [1:0]    io_stageOutputs_offloadGet3_state_grown,
  output              io_stageOutputs_offloadGet3_message_valid,
  output     [11:0]   io_stageOutputs_offloadGet3_message_instruction,
  output              io_stageOutputs_offloadGet3_message_isReset,
  output              io_stageOutputs_offloadGet3_isUniqueTight,
  output              io_stageOutputs_offloadGet3_isIsolated,
  output     [1:0]    io_stageOutputs_offloadGet4_state_speed,
  output     [4:0]    io_stageOutputs_offloadGet4_state_node,
  output     [4:0]    io_stageOutputs_offloadGet4_state_root,
  output              io_stageOutputs_offloadGet4_state_isVirtual,
  output              io_stageOutputs_offloadGet4_state_isDefect,
  output     [1:0]    io_stageOutputs_offloadGet4_state_grown,
  output              io_stageOutputs_offloadGet4_message_valid,
  output     [11:0]   io_stageOutputs_offloadGet4_message_instruction,
  output              io_stageOutputs_offloadGet4_message_isReset,
  output     [1:0]    io_stageOutputs_executeGet_state_speed,
  output     [4:0]    io_stageOutputs_executeGet_state_node,
  output     [4:0]    io_stageOutputs_executeGet_state_root,
  output              io_stageOutputs_executeGet_state_isVirtual,
  output              io_stageOutputs_executeGet_state_isDefect,
  output     [1:0]    io_stageOutputs_executeGet_state_grown,
  output              io_stageOutputs_executeGet_message_valid,
  output     [11:0]   io_stageOutputs_executeGet_message_instruction,
  output              io_stageOutputs_executeGet_message_isReset,
  output              io_stageOutputs_executeGet_isStalled,
  output     [1:0]    io_stageOutputs_executeGet2_state_speed,
  output     [4:0]    io_stageOutputs_executeGet2_state_node,
  output     [4:0]    io_stageOutputs_executeGet2_state_root,
  output              io_stageOutputs_executeGet2_state_isVirtual,
  output              io_stageOutputs_executeGet2_state_isDefect,
  output     [1:0]    io_stageOutputs_executeGet2_state_grown,
  output              io_stageOutputs_executeGet2_isStalled,
  output              io_stageOutputs_executeGet2_compact_valid,
  output              io_stageOutputs_executeGet2_compact_isReset,
  output     [1:0]    io_stageOutputs_executeGet3_state_speed,
  output     [4:0]    io_stageOutputs_executeGet3_state_node,
  output     [4:0]    io_stageOutputs_executeGet3_state_root,
  output              io_stageOutputs_executeGet3_state_isVirtual,
  output              io_stageOutputs_executeGet3_state_isDefect,
  output     [1:0]    io_stageOutputs_executeGet3_state_grown,
  output              io_stageOutputs_executeGet3_isStalled,
  output              io_stageOutputs_executeGet3_compact_valid,
  output              io_stageOutputs_executeGet3_compact_isReset,
  output     [1:0]    io_stageOutputs_updateGet_state_speed,
  output     [4:0]    io_stageOutputs_updateGet_state_node,
  output     [4:0]    io_stageOutputs_updateGet_state_root,
  output              io_stageOutputs_updateGet_state_isVirtual,
  output              io_stageOutputs_updateGet_state_isDefect,
  output     [1:0]    io_stageOutputs_updateGet_state_grown,
  output              io_stageOutputs_updateGet_isStalled,
  output              io_stageOutputs_updateGet_compact_valid,
  output              io_stageOutputs_updateGet_compact_isReset,
  output              io_stageOutputs_updateGet_propagatingPeer_valid,
  output     [4:0]    io_stageOutputs_updateGet_propagatingPeer_node,
  output     [4:0]    io_stageOutputs_updateGet_propagatingPeer_root,
  output     [1:0]    io_stageOutputs_updateGet2_state_speed,
  output     [4:0]    io_stageOutputs_updateGet2_state_node,
  output     [4:0]    io_stageOutputs_updateGet2_state_root,
  output              io_stageOutputs_updateGet2_state_isVirtual,
  output              io_stageOutputs_updateGet2_state_isDefect,
  output     [1:0]    io_stageOutputs_updateGet2_state_grown,
  output              io_stageOutputs_updateGet2_isStalled,
  output              io_stageOutputs_updateGet2_compact_valid,
  output              io_stageOutputs_updateGet2_compact_isReset,
  output              io_stageOutputs_updateGet2_propagatingPeer_valid,
  output     [4:0]    io_stageOutputs_updateGet2_propagatingPeer_node,
  output     [4:0]    io_stageOutputs_updateGet2_propagatingPeer_root,
  output     [1:0]    io_stageOutputs_updateGet3_state_speed,
  output     [4:0]    io_stageOutputs_updateGet3_state_node,
  output     [4:0]    io_stageOutputs_updateGet3_state_root,
  output              io_stageOutputs_updateGet3_state_isVirtual,
  output              io_stageOutputs_updateGet3_state_isDefect,
  output     [1:0]    io_stageOutputs_updateGet3_state_grown,
  output     [1:0]    io_stageOutputs_updateGet3_shadow_speed,
  output     [4:0]    io_stageOutputs_updateGet3_shadow_node,
  output     [4:0]    io_stageOutputs_updateGet3_shadow_root,
  output              io_stageOutputs_updateGet3_compact_valid,
  output              io_stageOutputs_updateGet3_compact_isReset,
  input      [1:0]    io_edgeInputs_0_offloadGet_state_weight,
  input               io_edgeInputs_0_offloadGet_compact_valid,
  input               io_edgeInputs_0_offloadGet_compact_isReset,
  input      [1:0]    io_edgeInputs_0_offloadGet2_state_weight,
  input               io_edgeInputs_0_offloadGet2_isTight,
  input               io_edgeInputs_0_offloadGet2_isTightExFusion,
  input               io_edgeInputs_0_offloadGet2_compact_valid,
  input               io_edgeInputs_0_offloadGet2_compact_isReset,
  input      [1:0]    io_edgeInputs_0_offloadGet3_state_weight,
  input               io_edgeInputs_0_offloadGet3_isTight,
  input               io_edgeInputs_0_offloadGet3_compact_valid,
  input               io_edgeInputs_0_offloadGet3_compact_isReset,
  input      [1:0]    io_edgeInputs_0_offloadGet4_state_weight,
  input               io_edgeInputs_0_offloadGet4_compact_valid,
  input               io_edgeInputs_0_offloadGet4_compact_isReset,
  input      [1:0]    io_edgeInputs_0_executeGet_state_weight,
  input               io_edgeInputs_0_executeGet_compact_valid,
  input               io_edgeInputs_0_executeGet_compact_isReset,
  input      [1:0]    io_edgeInputs_0_executeGet2_state_weight,
  input               io_edgeInputs_0_executeGet2_compact_valid,
  input               io_edgeInputs_0_executeGet2_compact_isReset,
  input      [1:0]    io_edgeInputs_0_executeGet3_state_weight,
  input               io_edgeInputs_0_executeGet3_isTight,
  input               io_edgeInputs_0_executeGet3_compact_valid,
  input               io_edgeInputs_0_executeGet3_compact_isReset,
  input      [1:0]    io_edgeInputs_0_updateGet_state_weight,
  input      [1:0]    io_edgeInputs_0_updateGet_remaining,
  input               io_edgeInputs_0_updateGet_compact_valid,
  input               io_edgeInputs_0_updateGet_compact_isReset,
  input      [1:0]    io_edgeInputs_0_updateGet2_state_weight,
  input      [1:0]    io_edgeInputs_0_updateGet2_remaining,
  input               io_edgeInputs_0_updateGet2_compact_valid,
  input               io_edgeInputs_0_updateGet2_compact_isReset,
  input      [1:0]    io_edgeInputs_0_updateGet3_state_weight,
  input      [1:0]    io_edgeInputs_0_updateGet3_remaining,
  input               io_edgeInputs_0_updateGet3_compact_valid,
  input               io_edgeInputs_0_updateGet3_compact_isReset,
  input      [1:0]    io_edgeInputs_1_offloadGet_state_weight,
  input               io_edgeInputs_1_offloadGet_compact_valid,
  input               io_edgeInputs_1_offloadGet_compact_isReset,
  input      [1:0]    io_edgeInputs_1_offloadGet2_state_weight,
  input               io_edgeInputs_1_offloadGet2_isTight,
  input               io_edgeInputs_1_offloadGet2_isTightExFusion,
  input               io_edgeInputs_1_offloadGet2_compact_valid,
  input               io_edgeInputs_1_offloadGet2_compact_isReset,
  input      [1:0]    io_edgeInputs_1_offloadGet3_state_weight,
  input               io_edgeInputs_1_offloadGet3_isTight,
  input               io_edgeInputs_1_offloadGet3_compact_valid,
  input               io_edgeInputs_1_offloadGet3_compact_isReset,
  input      [1:0]    io_edgeInputs_1_offloadGet4_state_weight,
  input               io_edgeInputs_1_offloadGet4_compact_valid,
  input               io_edgeInputs_1_offloadGet4_compact_isReset,
  input      [1:0]    io_edgeInputs_1_executeGet_state_weight,
  input               io_edgeInputs_1_executeGet_compact_valid,
  input               io_edgeInputs_1_executeGet_compact_isReset,
  input      [1:0]    io_edgeInputs_1_executeGet2_state_weight,
  input               io_edgeInputs_1_executeGet2_compact_valid,
  input               io_edgeInputs_1_executeGet2_compact_isReset,
  input      [1:0]    io_edgeInputs_1_executeGet3_state_weight,
  input               io_edgeInputs_1_executeGet3_isTight,
  input               io_edgeInputs_1_executeGet3_compact_valid,
  input               io_edgeInputs_1_executeGet3_compact_isReset,
  input      [1:0]    io_edgeInputs_1_updateGet_state_weight,
  input      [1:0]    io_edgeInputs_1_updateGet_remaining,
  input               io_edgeInputs_1_updateGet_compact_valid,
  input               io_edgeInputs_1_updateGet_compact_isReset,
  input      [1:0]    io_edgeInputs_1_updateGet2_state_weight,
  input      [1:0]    io_edgeInputs_1_updateGet2_remaining,
  input               io_edgeInputs_1_updateGet2_compact_valid,
  input               io_edgeInputs_1_updateGet2_compact_isReset,
  input      [1:0]    io_edgeInputs_1_updateGet3_state_weight,
  input      [1:0]    io_edgeInputs_1_updateGet3_remaining,
  input               io_edgeInputs_1_updateGet3_compact_valid,
  input               io_edgeInputs_1_updateGet3_compact_isReset,
  input      [1:0]    _zz_io_peerSpeed_0,
  input      [4:0]    _zz_io_peerNode_0,
  input      [4:0]    _zz_io_peerRoot_0,
  input      [1:0]    _zz_io_peerSpeed_1,
  input      [4:0]    _zz_io_peerNode_1,
  input      [4:0]    _zz_io_peerRoot_1,
  output     [1:0]    io_maxGrowable_length,
  input               clk,
  input               reset
);

  wire                offload3Area_tightCounter_io_isUnique;
  wire                offload3Area_tightCounter_io_isIsolated;
  wire                executeArea_offloadStalled_io_isStalled;
  wire       [1:0]    execute2Area_vertexPostExecuteState_io_after_speed;
  wire       [4:0]    execute2Area_vertexPostExecuteState_io_after_node;
  wire       [4:0]    execute2Area_vertexPostExecuteState_io_after_root;
  wire                execute2Area_vertexPostExecuteState_io_after_isVirtual;
  wire                execute2Area_vertexPostExecuteState_io_after_isDefect;
  wire       [1:0]    execute2Area_vertexPostExecuteState_io_after_grown;
  wire                updateArea_vertexPropagatingPeer_io_peer_valid;
  wire       [4:0]    updateArea_vertexPropagatingPeer_io_peer_node;
  wire       [4:0]    updateArea_vertexPropagatingPeer_io_peer_root;
  wire       [1:0]    update2Area_vertexPostUpdateState_io_after_speed;
  wire       [4:0]    update2Area_vertexPostUpdateState_io_after_node;
  wire       [4:0]    update2Area_vertexPostUpdateState_io_after_root;
  wire                update2Area_vertexPostUpdateState_io_after_isVirtual;
  wire                update2Area_vertexPostUpdateState_io_after_isDefect;
  wire       [1:0]    update2Area_vertexPostUpdateState_io_after_grown;
  wire       [1:0]    update3Area_vertexShadow_io_shadow_speed;
  wire       [4:0]    update3Area_vertexShadow_io_shadow_node;
  wire       [4:0]    update3Area_vertexShadow_io_shadow_root;
  wire       [1:0]    vertexResponse_4_io_maxGrowable_length;
  wire       [1:0]    stages_offloadSet_state_speed;
  wire       [4:0]    stages_offloadSet_state_node;
  wire       [4:0]    stages_offloadSet_state_root;
  wire                stages_offloadSet_state_isVirtual;
  wire                stages_offloadSet_state_isDefect;
  wire       [1:0]    stages_offloadSet_state_grown;
  wire                stages_offloadSet_message_valid;
  wire       [11:0]   stages_offloadSet_message_instruction;
  wire                stages_offloadSet_message_isReset;
  wire       [1:0]    stages_offloadGet_state_speed;
  wire       [4:0]    stages_offloadGet_state_node;
  wire       [4:0]    stages_offloadGet_state_root;
  wire                stages_offloadGet_state_isVirtual;
  wire                stages_offloadGet_state_isDefect;
  wire       [1:0]    stages_offloadGet_state_grown;
  wire                stages_offloadGet_message_valid;
  wire       [11:0]   stages_offloadGet_message_instruction;
  wire                stages_offloadGet_message_isReset;
  wire       [1:0]    stages_offloadSet2_state_speed;
  wire       [4:0]    stages_offloadSet2_state_node;
  wire       [4:0]    stages_offloadSet2_state_root;
  wire                stages_offloadSet2_state_isVirtual;
  wire                stages_offloadSet2_state_isDefect;
  wire       [1:0]    stages_offloadSet2_state_grown;
  wire                stages_offloadSet2_message_valid;
  wire       [11:0]   stages_offloadSet2_message_instruction;
  wire                stages_offloadSet2_message_isReset;
  wire       [1:0]    stages_offloadGet2_state_speed;
  wire       [4:0]    stages_offloadGet2_state_node;
  wire       [4:0]    stages_offloadGet2_state_root;
  wire                stages_offloadGet2_state_isVirtual;
  wire                stages_offloadGet2_state_isDefect;
  wire       [1:0]    stages_offloadGet2_state_grown;
  wire                stages_offloadGet2_message_valid;
  wire       [11:0]   stages_offloadGet2_message_instruction;
  wire                stages_offloadGet2_message_isReset;
  wire       [1:0]    stages_offloadSet3_state_speed;
  wire       [4:0]    stages_offloadSet3_state_node;
  wire       [4:0]    stages_offloadSet3_state_root;
  wire                stages_offloadSet3_state_isVirtual;
  wire                stages_offloadSet3_state_isDefect;
  wire       [1:0]    stages_offloadSet3_state_grown;
  wire                stages_offloadSet3_message_valid;
  wire       [11:0]   stages_offloadSet3_message_instruction;
  wire                stages_offloadSet3_message_isReset;
  wire                stages_offloadSet3_isUniqueTight;
  wire                stages_offloadSet3_isIsolated;
  wire       [1:0]    stages_offloadGet3_state_speed;
  wire       [4:0]    stages_offloadGet3_state_node;
  wire       [4:0]    stages_offloadGet3_state_root;
  wire                stages_offloadGet3_state_isVirtual;
  wire                stages_offloadGet3_state_isDefect;
  wire       [1:0]    stages_offloadGet3_state_grown;
  wire                stages_offloadGet3_message_valid;
  wire       [11:0]   stages_offloadGet3_message_instruction;
  wire                stages_offloadGet3_message_isReset;
  wire                stages_offloadGet3_isUniqueTight;
  wire                stages_offloadGet3_isIsolated;
  wire       [1:0]    stages_offloadSet4_state_speed;
  wire       [4:0]    stages_offloadSet4_state_node;
  wire       [4:0]    stages_offloadSet4_state_root;
  wire                stages_offloadSet4_state_isVirtual;
  wire                stages_offloadSet4_state_isDefect;
  wire       [1:0]    stages_offloadSet4_state_grown;
  wire                stages_offloadSet4_message_valid;
  wire       [11:0]   stages_offloadSet4_message_instruction;
  wire                stages_offloadSet4_message_isReset;
  wire       [1:0]    stages_offloadGet4_state_speed;
  wire       [4:0]    stages_offloadGet4_state_node;
  wire       [4:0]    stages_offloadGet4_state_root;
  wire                stages_offloadGet4_state_isVirtual;
  wire                stages_offloadGet4_state_isDefect;
  wire       [1:0]    stages_offloadGet4_state_grown;
  wire                stages_offloadGet4_message_valid;
  wire       [11:0]   stages_offloadGet4_message_instruction;
  wire                stages_offloadGet4_message_isReset;
  wire       [1:0]    stages_executeSet_state_speed;
  wire       [4:0]    stages_executeSet_state_node;
  wire       [4:0]    stages_executeSet_state_root;
  wire                stages_executeSet_state_isVirtual;
  wire                stages_executeSet_state_isDefect;
  wire       [1:0]    stages_executeSet_state_grown;
  wire                stages_executeSet_message_valid;
  wire       [11:0]   stages_executeSet_message_instruction;
  wire                stages_executeSet_message_isReset;
  wire                stages_executeSet_isStalled;
  wire       [1:0]    stages_executeGet_state_speed;
  wire       [4:0]    stages_executeGet_state_node;
  wire       [4:0]    stages_executeGet_state_root;
  wire                stages_executeGet_state_isVirtual;
  wire                stages_executeGet_state_isDefect;
  wire       [1:0]    stages_executeGet_state_grown;
  wire                stages_executeGet_message_valid;
  wire       [11:0]   stages_executeGet_message_instruction;
  wire                stages_executeGet_message_isReset;
  wire                stages_executeGet_isStalled;
  wire       [1:0]    stages_executeSet2_state_speed;
  wire       [4:0]    stages_executeSet2_state_node;
  wire       [4:0]    stages_executeSet2_state_root;
  wire                stages_executeSet2_state_isVirtual;
  wire                stages_executeSet2_state_isDefect;
  wire       [1:0]    stages_executeSet2_state_grown;
  wire                stages_executeSet2_isStalled;
  wire                stages_executeSet2_compact_valid;
  wire                stages_executeSet2_compact_isReset;
  wire       [1:0]    stages_executeGet2_state_speed;
  wire       [4:0]    stages_executeGet2_state_node;
  wire       [4:0]    stages_executeGet2_state_root;
  wire                stages_executeGet2_state_isVirtual;
  wire                stages_executeGet2_state_isDefect;
  wire       [1:0]    stages_executeGet2_state_grown;
  wire                stages_executeGet2_isStalled;
  wire                stages_executeGet2_compact_valid;
  wire                stages_executeGet2_compact_isReset;
  wire       [1:0]    stages_executeSet3_state_speed;
  wire       [4:0]    stages_executeSet3_state_node;
  wire       [4:0]    stages_executeSet3_state_root;
  wire                stages_executeSet3_state_isVirtual;
  wire                stages_executeSet3_state_isDefect;
  wire       [1:0]    stages_executeSet3_state_grown;
  wire                stages_executeSet3_isStalled;
  wire                stages_executeSet3_compact_valid;
  wire                stages_executeSet3_compact_isReset;
  wire       [1:0]    stages_executeGet3_state_speed;
  wire       [4:0]    stages_executeGet3_state_node;
  wire       [4:0]    stages_executeGet3_state_root;
  wire                stages_executeGet3_state_isVirtual;
  wire                stages_executeGet3_state_isDefect;
  wire       [1:0]    stages_executeGet3_state_grown;
  wire                stages_executeGet3_isStalled;
  wire                stages_executeGet3_compact_valid;
  wire                stages_executeGet3_compact_isReset;
  wire       [1:0]    stages_updateSet_state_speed;
  wire       [4:0]    stages_updateSet_state_node;
  wire       [4:0]    stages_updateSet_state_root;
  wire                stages_updateSet_state_isVirtual;
  wire                stages_updateSet_state_isDefect;
  wire       [1:0]    stages_updateSet_state_grown;
  wire                stages_updateSet_isStalled;
  wire                stages_updateSet_compact_valid;
  wire                stages_updateSet_compact_isReset;
  wire                stages_updateSet_propagatingPeer_valid;
  wire       [4:0]    stages_updateSet_propagatingPeer_node;
  wire       [4:0]    stages_updateSet_propagatingPeer_root;
  wire       [1:0]    stages_updateGet_state_speed;
  wire       [4:0]    stages_updateGet_state_node;
  wire       [4:0]    stages_updateGet_state_root;
  wire                stages_updateGet_state_isVirtual;
  wire                stages_updateGet_state_isDefect;
  wire       [1:0]    stages_updateGet_state_grown;
  wire                stages_updateGet_isStalled;
  wire                stages_updateGet_compact_valid;
  wire                stages_updateGet_compact_isReset;
  wire                stages_updateGet_propagatingPeer_valid;
  wire       [4:0]    stages_updateGet_propagatingPeer_node;
  wire       [4:0]    stages_updateGet_propagatingPeer_root;
  wire       [1:0]    stages_updateSet2_state_speed;
  wire       [4:0]    stages_updateSet2_state_node;
  wire       [4:0]    stages_updateSet2_state_root;
  wire                stages_updateSet2_state_isVirtual;
  wire                stages_updateSet2_state_isDefect;
  wire       [1:0]    stages_updateSet2_state_grown;
  wire                stages_updateSet2_isStalled;
  wire                stages_updateSet2_compact_valid;
  wire                stages_updateSet2_compact_isReset;
  wire                stages_updateSet2_propagatingPeer_valid;
  wire       [4:0]    stages_updateSet2_propagatingPeer_node;
  wire       [4:0]    stages_updateSet2_propagatingPeer_root;
  wire       [1:0]    stages_updateGet2_state_speed;
  wire       [4:0]    stages_updateGet2_state_node;
  wire       [4:0]    stages_updateGet2_state_root;
  wire                stages_updateGet2_state_isVirtual;
  wire                stages_updateGet2_state_isDefect;
  wire       [1:0]    stages_updateGet2_state_grown;
  wire                stages_updateGet2_isStalled;
  wire                stages_updateGet2_compact_valid;
  wire                stages_updateGet2_compact_isReset;
  wire                stages_updateGet2_propagatingPeer_valid;
  wire       [4:0]    stages_updateGet2_propagatingPeer_node;
  wire       [4:0]    stages_updateGet2_propagatingPeer_root;
  wire       [1:0]    stages_updateSet3_state_speed;
  wire       [4:0]    stages_updateSet3_state_node;
  wire       [4:0]    stages_updateSet3_state_root;
  wire                stages_updateSet3_state_isVirtual;
  wire                stages_updateSet3_state_isDefect;
  wire       [1:0]    stages_updateSet3_state_grown;
  wire       [1:0]    stages_updateSet3_shadow_speed;
  wire       [4:0]    stages_updateSet3_shadow_node;
  wire       [4:0]    stages_updateSet3_shadow_root;
  wire                stages_updateSet3_compact_valid;
  wire                stages_updateSet3_compact_isReset;
  wire       [1:0]    stages_updateGet3_state_speed;
  wire       [4:0]    stages_updateGet3_state_node;
  wire       [4:0]    stages_updateGet3_state_root;
  wire                stages_updateGet3_state_isVirtual;
  wire                stages_updateGet3_state_isDefect;
  wire       [1:0]    stages_updateGet3_state_grown;
  wire       [1:0]    stages_updateGet3_shadow_speed;
  wire       [4:0]    stages_updateGet3_shadow_node;
  wire       [4:0]    stages_updateGet3_shadow_root;
  wire                stages_updateGet3_compact_valid;
  wire                stages_updateGet3_compact_isReset;
  reg        [1:0]    register_speed;
  reg        [4:0]    register_node;
  reg        [4:0]    register_root;
  reg                 register_isVirtual;
  reg                 register_isDefect;
  reg        [1:0]    register_grown;
  wire       [1:0]    fetchState_speed;
  wire       [4:0]    fetchState_node;
  wire       [4:0]    fetchState_root;
  wire                fetchState_isVirtual;
  wire                fetchState_isDefect;
  wire       [1:0]    fetchState_grown;
  wire                message_valid;
  wire       [11:0]   message_instruction;
  wire                message_isReset;

  VertexTightCounter_3 offload3Area_tightCounter (
    .io_tights_0   (io_edgeInputs_0_offloadGet2_isTightExFusion), //i
    .io_tights_1   (io_edgeInputs_1_offloadGet2_isTightExFusion), //i
    .io_isUnique   (offload3Area_tightCounter_io_isUnique      ), //o
    .io_isIsolated (offload3Area_tightCounter_io_isIsolated    )  //o
  );
  OffloadStalled_3 executeArea_offloadStalled (
    .io_isStalled (executeArea_offloadStalled_io_isStalled)  //o
  );
  VertexPostExecuteState_2 execute2Area_vertexPostExecuteState (
    .io_before_speed        (stages_executeGet_state_speed[1:0]                     ), //i
    .io_before_node         (stages_executeGet_state_node[4:0]                      ), //i
    .io_before_root         (stages_executeGet_state_root[4:0]                      ), //i
    .io_before_isVirtual    (stages_executeGet_state_isVirtual                      ), //i
    .io_before_isDefect     (stages_executeGet_state_isDefect                       ), //i
    .io_before_grown        (stages_executeGet_state_grown[1:0]                     ), //i
    .io_message_valid       (stages_executeGet_message_valid                        ), //i
    .io_message_instruction (stages_executeGet_message_instruction[11:0]            ), //i
    .io_message_isReset     (stages_executeGet_message_isReset                      ), //i
    .io_isStalled           (stages_executeGet_isStalled                            ), //i
    .io_after_speed         (execute2Area_vertexPostExecuteState_io_after_speed[1:0]), //o
    .io_after_node          (execute2Area_vertexPostExecuteState_io_after_node[4:0] ), //o
    .io_after_root          (execute2Area_vertexPostExecuteState_io_after_root[4:0] ), //o
    .io_after_isVirtual     (execute2Area_vertexPostExecuteState_io_after_isVirtual ), //o
    .io_after_isDefect      (execute2Area_vertexPostExecuteState_io_after_isDefect  ), //o
    .io_after_grown         (execute2Area_vertexPostExecuteState_io_after_grown[1:0]), //o
    .clk                    (clk                                                    ), //i
    .reset                  (reset                                                  )  //i
  );
  VertexPropagatingPeer_3 updateArea_vertexPropagatingPeer (
    .io_grown         (stages_executeGet3_state_grown[1:0]               ), //i
    .io_edgeIsTight_0 (io_edgeInputs_0_executeGet3_isTight               ), //i
    .io_edgeIsTight_1 (io_edgeInputs_1_executeGet3_isTight               ), //i
    .io_peerSpeed_0   (_zz_io_peerSpeed_0[1:0]                           ), //i
    .io_peerSpeed_1   (_zz_io_peerSpeed_1[1:0]                           ), //i
    .io_peerNode_0    (_zz_io_peerNode_0[4:0]                            ), //i
    .io_peerNode_1    (_zz_io_peerNode_1[4:0]                            ), //i
    .io_peerRoot_0    (_zz_io_peerRoot_0[4:0]                            ), //i
    .io_peerRoot_1    (_zz_io_peerRoot_1[4:0]                            ), //i
    .io_peer_valid    (updateArea_vertexPropagatingPeer_io_peer_valid    ), //o
    .io_peer_node     (updateArea_vertexPropagatingPeer_io_peer_node[4:0]), //o
    .io_peer_root     (updateArea_vertexPropagatingPeer_io_peer_root[4:0])  //o
  );
  VertexPostUpdateState_3 update2Area_vertexPostUpdateState (
    .io_before_speed     (stages_updateGet_state_speed[1:0]                    ), //i
    .io_before_node      (stages_updateGet_state_node[4:0]                     ), //i
    .io_before_root      (stages_updateGet_state_root[4:0]                     ), //i
    .io_before_isVirtual (stages_updateGet_state_isVirtual                     ), //i
    .io_before_isDefect  (stages_updateGet_state_isDefect                      ), //i
    .io_before_grown     (stages_updateGet_state_grown[1:0]                    ), //i
    .io_propagator_valid (stages_updateGet_propagatingPeer_valid               ), //i
    .io_propagator_node  (stages_updateGet_propagatingPeer_node[4:0]           ), //i
    .io_propagator_root  (stages_updateGet_propagatingPeer_root[4:0]           ), //i
    .io_after_speed      (update2Area_vertexPostUpdateState_io_after_speed[1:0]), //o
    .io_after_node       (update2Area_vertexPostUpdateState_io_after_node[4:0] ), //o
    .io_after_root       (update2Area_vertexPostUpdateState_io_after_root[4:0] ), //o
    .io_after_isVirtual  (update2Area_vertexPostUpdateState_io_after_isVirtual ), //o
    .io_after_isDefect   (update2Area_vertexPostUpdateState_io_after_isDefect  ), //o
    .io_after_grown      (update2Area_vertexPostUpdateState_io_after_grown[1:0])  //o
  );
  VertexShadow_3 update3Area_vertexShadow (
    .io_isVirtual        (stages_updateGet2_state_isVirtual            ), //i
    .io_node             (stages_updateGet2_state_node[4:0]            ), //i
    .io_root             (stages_updateGet2_state_root[4:0]            ), //i
    .io_speed            (stages_updateGet2_state_speed[1:0]           ), //i
    .io_grown            (stages_updateGet2_state_grown[1:0]           ), //i
    .io_isStalled        (stages_updateGet2_isStalled                  ), //i
    .io_propagator_valid (stages_updateGet2_propagatingPeer_valid      ), //i
    .io_propagator_node  (stages_updateGet2_propagatingPeer_node[4:0]  ), //i
    .io_propagator_root  (stages_updateGet2_propagatingPeer_root[4:0]  ), //i
    .io_shadow_speed     (update3Area_vertexShadow_io_shadow_speed[1:0]), //o
    .io_shadow_node      (update3Area_vertexShadow_io_shadow_node[4:0] ), //o
    .io_shadow_root      (update3Area_vertexShadow_io_shadow_root[4:0] )  //o
  );
  VertexResponse_3 vertexResponse_4 (
    .io_state_speed        (stages_updateGet3_state_speed[1:0]         ), //i
    .io_state_node         (stages_updateGet3_state_node[4:0]          ), //i
    .io_state_root         (stages_updateGet3_state_root[4:0]          ), //i
    .io_state_isVirtual    (stages_updateGet3_state_isVirtual          ), //i
    .io_state_isDefect     (stages_updateGet3_state_isDefect           ), //i
    .io_state_grown        (stages_updateGet3_state_grown[1:0]         ), //i
    .io_maxGrowable_length (vertexResponse_4_io_maxGrowable_length[1:0])  //o
  );
  assign io_stageOutputs_offloadGet_state_speed = stages_offloadGet_state_speed;
  assign io_stageOutputs_offloadGet_state_node = stages_offloadGet_state_node;
  assign io_stageOutputs_offloadGet_state_root = stages_offloadGet_state_root;
  assign io_stageOutputs_offloadGet_state_isVirtual = stages_offloadGet_state_isVirtual;
  assign io_stageOutputs_offloadGet_state_isDefect = stages_offloadGet_state_isDefect;
  assign io_stageOutputs_offloadGet_state_grown = stages_offloadGet_state_grown;
  assign io_stageOutputs_offloadGet_message_valid = stages_offloadGet_message_valid;
  assign io_stageOutputs_offloadGet_message_instruction = stages_offloadGet_message_instruction;
  assign io_stageOutputs_offloadGet_message_isReset = stages_offloadGet_message_isReset;
  assign io_stageOutputs_offloadGet2_state_speed = stages_offloadGet2_state_speed;
  assign io_stageOutputs_offloadGet2_state_node = stages_offloadGet2_state_node;
  assign io_stageOutputs_offloadGet2_state_root = stages_offloadGet2_state_root;
  assign io_stageOutputs_offloadGet2_state_isVirtual = stages_offloadGet2_state_isVirtual;
  assign io_stageOutputs_offloadGet2_state_isDefect = stages_offloadGet2_state_isDefect;
  assign io_stageOutputs_offloadGet2_state_grown = stages_offloadGet2_state_grown;
  assign io_stageOutputs_offloadGet2_message_valid = stages_offloadGet2_message_valid;
  assign io_stageOutputs_offloadGet2_message_instruction = stages_offloadGet2_message_instruction;
  assign io_stageOutputs_offloadGet2_message_isReset = stages_offloadGet2_message_isReset;
  assign io_stageOutputs_offloadGet3_state_speed = stages_offloadGet3_state_speed;
  assign io_stageOutputs_offloadGet3_state_node = stages_offloadGet3_state_node;
  assign io_stageOutputs_offloadGet3_state_root = stages_offloadGet3_state_root;
  assign io_stageOutputs_offloadGet3_state_isVirtual = stages_offloadGet3_state_isVirtual;
  assign io_stageOutputs_offloadGet3_state_isDefect = stages_offloadGet3_state_isDefect;
  assign io_stageOutputs_offloadGet3_state_grown = stages_offloadGet3_state_grown;
  assign io_stageOutputs_offloadGet3_message_valid = stages_offloadGet3_message_valid;
  assign io_stageOutputs_offloadGet3_message_instruction = stages_offloadGet3_message_instruction;
  assign io_stageOutputs_offloadGet3_message_isReset = stages_offloadGet3_message_isReset;
  assign io_stageOutputs_offloadGet3_isUniqueTight = stages_offloadGet3_isUniqueTight;
  assign io_stageOutputs_offloadGet3_isIsolated = stages_offloadGet3_isIsolated;
  assign io_stageOutputs_offloadGet4_state_speed = stages_offloadGet4_state_speed;
  assign io_stageOutputs_offloadGet4_state_node = stages_offloadGet4_state_node;
  assign io_stageOutputs_offloadGet4_state_root = stages_offloadGet4_state_root;
  assign io_stageOutputs_offloadGet4_state_isVirtual = stages_offloadGet4_state_isVirtual;
  assign io_stageOutputs_offloadGet4_state_isDefect = stages_offloadGet4_state_isDefect;
  assign io_stageOutputs_offloadGet4_state_grown = stages_offloadGet4_state_grown;
  assign io_stageOutputs_offloadGet4_message_valid = stages_offloadGet4_message_valid;
  assign io_stageOutputs_offloadGet4_message_instruction = stages_offloadGet4_message_instruction;
  assign io_stageOutputs_offloadGet4_message_isReset = stages_offloadGet4_message_isReset;
  assign io_stageOutputs_executeGet_state_speed = stages_executeGet_state_speed;
  assign io_stageOutputs_executeGet_state_node = stages_executeGet_state_node;
  assign io_stageOutputs_executeGet_state_root = stages_executeGet_state_root;
  assign io_stageOutputs_executeGet_state_isVirtual = stages_executeGet_state_isVirtual;
  assign io_stageOutputs_executeGet_state_isDefect = stages_executeGet_state_isDefect;
  assign io_stageOutputs_executeGet_state_grown = stages_executeGet_state_grown;
  assign io_stageOutputs_executeGet_message_valid = stages_executeGet_message_valid;
  assign io_stageOutputs_executeGet_message_instruction = stages_executeGet_message_instruction;
  assign io_stageOutputs_executeGet_message_isReset = stages_executeGet_message_isReset;
  assign io_stageOutputs_executeGet_isStalled = stages_executeGet_isStalled;
  assign io_stageOutputs_executeGet2_state_speed = stages_executeGet2_state_speed;
  assign io_stageOutputs_executeGet2_state_node = stages_executeGet2_state_node;
  assign io_stageOutputs_executeGet2_state_root = stages_executeGet2_state_root;
  assign io_stageOutputs_executeGet2_state_isVirtual = stages_executeGet2_state_isVirtual;
  assign io_stageOutputs_executeGet2_state_isDefect = stages_executeGet2_state_isDefect;
  assign io_stageOutputs_executeGet2_state_grown = stages_executeGet2_state_grown;
  assign io_stageOutputs_executeGet2_isStalled = stages_executeGet2_isStalled;
  assign io_stageOutputs_executeGet2_compact_valid = stages_executeGet2_compact_valid;
  assign io_stageOutputs_executeGet2_compact_isReset = stages_executeGet2_compact_isReset;
  assign io_stageOutputs_executeGet3_state_speed = stages_executeGet3_state_speed;
  assign io_stageOutputs_executeGet3_state_node = stages_executeGet3_state_node;
  assign io_stageOutputs_executeGet3_state_root = stages_executeGet3_state_root;
  assign io_stageOutputs_executeGet3_state_isVirtual = stages_executeGet3_state_isVirtual;
  assign io_stageOutputs_executeGet3_state_isDefect = stages_executeGet3_state_isDefect;
  assign io_stageOutputs_executeGet3_state_grown = stages_executeGet3_state_grown;
  assign io_stageOutputs_executeGet3_isStalled = stages_executeGet3_isStalled;
  assign io_stageOutputs_executeGet3_compact_valid = stages_executeGet3_compact_valid;
  assign io_stageOutputs_executeGet3_compact_isReset = stages_executeGet3_compact_isReset;
  assign io_stageOutputs_updateGet_state_speed = stages_updateGet_state_speed;
  assign io_stageOutputs_updateGet_state_node = stages_updateGet_state_node;
  assign io_stageOutputs_updateGet_state_root = stages_updateGet_state_root;
  assign io_stageOutputs_updateGet_state_isVirtual = stages_updateGet_state_isVirtual;
  assign io_stageOutputs_updateGet_state_isDefect = stages_updateGet_state_isDefect;
  assign io_stageOutputs_updateGet_state_grown = stages_updateGet_state_grown;
  assign io_stageOutputs_updateGet_isStalled = stages_updateGet_isStalled;
  assign io_stageOutputs_updateGet_compact_valid = stages_updateGet_compact_valid;
  assign io_stageOutputs_updateGet_compact_isReset = stages_updateGet_compact_isReset;
  assign io_stageOutputs_updateGet_propagatingPeer_valid = stages_updateGet_propagatingPeer_valid;
  assign io_stageOutputs_updateGet_propagatingPeer_node = stages_updateGet_propagatingPeer_node;
  assign io_stageOutputs_updateGet_propagatingPeer_root = stages_updateGet_propagatingPeer_root;
  assign io_stageOutputs_updateGet2_state_speed = stages_updateGet2_state_speed;
  assign io_stageOutputs_updateGet2_state_node = stages_updateGet2_state_node;
  assign io_stageOutputs_updateGet2_state_root = stages_updateGet2_state_root;
  assign io_stageOutputs_updateGet2_state_isVirtual = stages_updateGet2_state_isVirtual;
  assign io_stageOutputs_updateGet2_state_isDefect = stages_updateGet2_state_isDefect;
  assign io_stageOutputs_updateGet2_state_grown = stages_updateGet2_state_grown;
  assign io_stageOutputs_updateGet2_isStalled = stages_updateGet2_isStalled;
  assign io_stageOutputs_updateGet2_compact_valid = stages_updateGet2_compact_valid;
  assign io_stageOutputs_updateGet2_compact_isReset = stages_updateGet2_compact_isReset;
  assign io_stageOutputs_updateGet2_propagatingPeer_valid = stages_updateGet2_propagatingPeer_valid;
  assign io_stageOutputs_updateGet2_propagatingPeer_node = stages_updateGet2_propagatingPeer_node;
  assign io_stageOutputs_updateGet2_propagatingPeer_root = stages_updateGet2_propagatingPeer_root;
  assign io_stageOutputs_updateGet3_state_speed = stages_updateGet3_state_speed;
  assign io_stageOutputs_updateGet3_state_node = stages_updateGet3_state_node;
  assign io_stageOutputs_updateGet3_state_root = stages_updateGet3_state_root;
  assign io_stageOutputs_updateGet3_state_isVirtual = stages_updateGet3_state_isVirtual;
  assign io_stageOutputs_updateGet3_state_isDefect = stages_updateGet3_state_isDefect;
  assign io_stageOutputs_updateGet3_state_grown = stages_updateGet3_state_grown;
  assign io_stageOutputs_updateGet3_shadow_speed = stages_updateGet3_shadow_speed;
  assign io_stageOutputs_updateGet3_shadow_node = stages_updateGet3_shadow_node;
  assign io_stageOutputs_updateGet3_shadow_root = stages_updateGet3_shadow_root;
  assign io_stageOutputs_updateGet3_compact_valid = stages_updateGet3_compact_valid;
  assign io_stageOutputs_updateGet3_compact_isReset = stages_updateGet3_compact_isReset;
  assign fetchState_speed = register_speed;
  assign fetchState_node = register_node;
  assign fetchState_root = register_root;
  assign fetchState_isVirtual = register_isVirtual;
  assign fetchState_isDefect = register_isDefect;
  assign fetchState_grown = register_grown;
  assign message_valid = io_message_valid;
  assign message_instruction = io_message_instruction;
  assign message_isReset = io_message_isReset;
  assign stages_offloadSet_message_valid = message_valid;
  assign stages_offloadSet_message_instruction = message_instruction;
  assign stages_offloadSet_message_isReset = message_isReset;
  assign stages_offloadSet_state_speed = (message_isReset ? 2'b00 : fetchState_speed);
  assign stages_offloadSet_state_node = (message_isReset ? 5'h1f : fetchState_node);
  assign stages_offloadSet_state_root = (message_isReset ? 5'h1f : fetchState_root);
  assign stages_offloadSet_state_isVirtual = (message_isReset ? 1'b0 : fetchState_isVirtual);
  assign stages_offloadSet_state_isDefect = (message_isReset ? 1'b0 : fetchState_isDefect);
  assign stages_offloadSet_state_grown = (message_isReset ? 2'b00 : fetchState_grown);
  assign stages_offloadSet2_state_speed = stages_offloadGet_state_speed;
  assign stages_offloadSet2_state_node = stages_offloadGet_state_node;
  assign stages_offloadSet2_state_root = stages_offloadGet_state_root;
  assign stages_offloadSet2_state_isVirtual = stages_offloadGet_state_isVirtual;
  assign stages_offloadSet2_state_isDefect = stages_offloadGet_state_isDefect;
  assign stages_offloadSet2_state_grown = stages_offloadGet_state_grown;
  assign stages_offloadSet2_message_valid = stages_offloadGet_message_valid;
  assign stages_offloadSet2_message_instruction = stages_offloadGet_message_instruction;
  assign stages_offloadSet2_message_isReset = stages_offloadGet_message_isReset;
  assign stages_offloadSet3_state_speed = stages_offloadGet2_state_speed;
  assign stages_offloadSet3_state_node = stages_offloadGet2_state_node;
  assign stages_offloadSet3_state_root = stages_offloadGet2_state_root;
  assign stages_offloadSet3_state_isVirtual = stages_offloadGet2_state_isVirtual;
  assign stages_offloadSet3_state_isDefect = stages_offloadGet2_state_isDefect;
  assign stages_offloadSet3_state_grown = stages_offloadGet2_state_grown;
  assign stages_offloadSet3_message_valid = stages_offloadGet2_message_valid;
  assign stages_offloadSet3_message_instruction = stages_offloadGet2_message_instruction;
  assign stages_offloadSet3_message_isReset = stages_offloadGet2_message_isReset;
  assign stages_offloadSet3_isUniqueTight = offload3Area_tightCounter_io_isUnique;
  assign stages_offloadSet3_isIsolated = offload3Area_tightCounter_io_isIsolated;
  assign stages_offloadSet4_state_speed = stages_offloadGet3_state_speed;
  assign stages_offloadSet4_state_node = stages_offloadGet3_state_node;
  assign stages_offloadSet4_state_root = stages_offloadGet3_state_root;
  assign stages_offloadSet4_state_isVirtual = stages_offloadGet3_state_isVirtual;
  assign stages_offloadSet4_state_isDefect = stages_offloadGet3_state_isDefect;
  assign stages_offloadSet4_state_grown = stages_offloadGet3_state_grown;
  assign stages_offloadSet4_message_valid = stages_offloadGet3_message_valid;
  assign stages_offloadSet4_message_instruction = stages_offloadGet3_message_instruction;
  assign stages_offloadSet4_message_isReset = stages_offloadGet3_message_isReset;
  assign stages_executeSet_state_speed = stages_offloadGet4_state_speed;
  assign stages_executeSet_state_node = stages_offloadGet4_state_node;
  assign stages_executeSet_state_root = stages_offloadGet4_state_root;
  assign stages_executeSet_state_isVirtual = stages_offloadGet4_state_isVirtual;
  assign stages_executeSet_state_isDefect = stages_offloadGet4_state_isDefect;
  assign stages_executeSet_state_grown = stages_offloadGet4_state_grown;
  assign stages_executeSet_message_valid = stages_offloadGet4_message_valid;
  assign stages_executeSet_message_instruction = stages_offloadGet4_message_instruction;
  assign stages_executeSet_message_isReset = stages_offloadGet4_message_isReset;
  assign stages_executeSet_isStalled = executeArea_offloadStalled_io_isStalled;
  assign stages_executeSet2_isStalled = stages_executeGet_isStalled;
  assign stages_executeSet2_compact_valid = stages_executeGet_message_valid;
  assign stages_executeSet2_compact_isReset = stages_executeGet_message_isReset;
  assign stages_executeSet2_state_speed = execute2Area_vertexPostExecuteState_io_after_speed;
  assign stages_executeSet2_state_node = execute2Area_vertexPostExecuteState_io_after_node;
  assign stages_executeSet2_state_root = execute2Area_vertexPostExecuteState_io_after_root;
  assign stages_executeSet2_state_isVirtual = execute2Area_vertexPostExecuteState_io_after_isVirtual;
  assign stages_executeSet2_state_isDefect = execute2Area_vertexPostExecuteState_io_after_isDefect;
  assign stages_executeSet2_state_grown = execute2Area_vertexPostExecuteState_io_after_grown;
  assign stages_executeSet3_state_speed = stages_executeGet2_state_speed;
  assign stages_executeSet3_state_node = stages_executeGet2_state_node;
  assign stages_executeSet3_state_root = stages_executeGet2_state_root;
  assign stages_executeSet3_state_isVirtual = stages_executeGet2_state_isVirtual;
  assign stages_executeSet3_state_isDefect = stages_executeGet2_state_isDefect;
  assign stages_executeSet3_state_grown = stages_executeGet2_state_grown;
  assign stages_executeSet3_isStalled = stages_executeGet2_isStalled;
  assign stages_executeSet3_compact_valid = stages_executeGet2_compact_valid;
  assign stages_executeSet3_compact_isReset = stages_executeGet2_compact_isReset;
  assign stages_updateSet_state_speed = stages_executeGet3_state_speed;
  assign stages_updateSet_state_node = stages_executeGet3_state_node;
  assign stages_updateSet_state_root = stages_executeGet3_state_root;
  assign stages_updateSet_state_isVirtual = stages_executeGet3_state_isVirtual;
  assign stages_updateSet_state_isDefect = stages_executeGet3_state_isDefect;
  assign stages_updateSet_state_grown = stages_executeGet3_state_grown;
  assign stages_updateSet_isStalled = stages_executeGet3_isStalled;
  assign stages_updateSet_compact_valid = stages_executeGet3_compact_valid;
  assign stages_updateSet_compact_isReset = stages_executeGet3_compact_isReset;
  assign stages_updateSet_propagatingPeer_valid = updateArea_vertexPropagatingPeer_io_peer_valid;
  assign stages_updateSet_propagatingPeer_node = updateArea_vertexPropagatingPeer_io_peer_node;
  assign stages_updateSet_propagatingPeer_root = updateArea_vertexPropagatingPeer_io_peer_root;
  assign stages_updateSet2_compact_valid = stages_updateGet_compact_valid;
  assign stages_updateSet2_compact_isReset = stages_updateGet_compact_isReset;
  assign stages_updateSet2_isStalled = stages_updateGet_isStalled;
  assign stages_updateSet2_propagatingPeer_valid = stages_updateGet_propagatingPeer_valid;
  assign stages_updateSet2_propagatingPeer_node = stages_updateGet_propagatingPeer_node;
  assign stages_updateSet2_propagatingPeer_root = stages_updateGet_propagatingPeer_root;
  assign stages_updateSet2_state_speed = update2Area_vertexPostUpdateState_io_after_speed;
  assign stages_updateSet2_state_node = update2Area_vertexPostUpdateState_io_after_node;
  assign stages_updateSet2_state_root = update2Area_vertexPostUpdateState_io_after_root;
  assign stages_updateSet2_state_isVirtual = update2Area_vertexPostUpdateState_io_after_isVirtual;
  assign stages_updateSet2_state_isDefect = update2Area_vertexPostUpdateState_io_after_isDefect;
  assign stages_updateSet2_state_grown = update2Area_vertexPostUpdateState_io_after_grown;
  assign stages_updateSet3_state_speed = stages_updateGet2_state_speed;
  assign stages_updateSet3_state_node = stages_updateGet2_state_node;
  assign stages_updateSet3_state_root = stages_updateGet2_state_root;
  assign stages_updateSet3_state_isVirtual = stages_updateGet2_state_isVirtual;
  assign stages_updateSet3_state_isDefect = stages_updateGet2_state_isDefect;
  assign stages_updateSet3_state_grown = stages_updateGet2_state_grown;
  assign stages_updateSet3_compact_valid = stages_updateGet2_compact_valid;
  assign stages_updateSet3_compact_isReset = stages_updateGet2_compact_isReset;
  assign stages_updateSet3_shadow_speed = update3Area_vertexShadow_io_shadow_speed;
  assign stages_updateSet3_shadow_node = update3Area_vertexShadow_io_shadow_node;
  assign stages_updateSet3_shadow_root = update3Area_vertexShadow_io_shadow_root;
  assign io_maxGrowable_length = vertexResponse_4_io_maxGrowable_length;
  assign stages_executeGet3_state_speed = stages_executeSet3_state_speed;
  assign stages_executeGet3_state_node = stages_executeSet3_state_node;
  assign stages_executeGet3_state_root = stages_executeSet3_state_root;
  assign stages_executeGet3_state_isVirtual = stages_executeSet3_state_isVirtual;
  assign stages_executeGet3_state_isDefect = stages_executeSet3_state_isDefect;
  assign stages_executeGet3_state_grown = stages_executeSet3_state_grown;
  assign stages_executeGet3_isStalled = stages_executeSet3_isStalled;
  assign stages_executeGet3_compact_valid = stages_executeSet3_compact_valid;
  assign stages_executeGet3_compact_isReset = stages_executeSet3_compact_isReset;
  assign stages_updateGet_state_speed = stages_updateSet_state_speed;
  assign stages_updateGet_state_node = stages_updateSet_state_node;
  assign stages_updateGet_state_root = stages_updateSet_state_root;
  assign stages_updateGet_state_isVirtual = stages_updateSet_state_isVirtual;
  assign stages_updateGet_state_isDefect = stages_updateSet_state_isDefect;
  assign stages_updateGet_state_grown = stages_updateSet_state_grown;
  assign stages_updateGet_isStalled = stages_updateSet_isStalled;
  assign stages_updateGet_compact_valid = stages_updateSet_compact_valid;
  assign stages_updateGet_compact_isReset = stages_updateSet_compact_isReset;
  assign stages_updateGet_propagatingPeer_valid = stages_updateSet_propagatingPeer_valid;
  assign stages_updateGet_propagatingPeer_node = stages_updateSet_propagatingPeer_node;
  assign stages_updateGet_propagatingPeer_root = stages_updateSet_propagatingPeer_root;
  assign stages_offloadGet_state_speed = stages_offloadSet_state_speed;
  assign stages_offloadGet_state_node = stages_offloadSet_state_node;
  assign stages_offloadGet_state_root = stages_offloadSet_state_root;
  assign stages_offloadGet_state_isVirtual = stages_offloadSet_state_isVirtual;
  assign stages_offloadGet_state_isDefect = stages_offloadSet_state_isDefect;
  assign stages_offloadGet_state_grown = stages_offloadSet_state_grown;
  assign stages_offloadGet_message_valid = stages_offloadSet_message_valid;
  assign stages_offloadGet_message_instruction = stages_offloadSet_message_instruction;
  assign stages_offloadGet_message_isReset = stages_offloadSet_message_isReset;
  assign stages_offloadGet4_state_speed = stages_offloadSet4_state_speed;
  assign stages_offloadGet4_state_node = stages_offloadSet4_state_node;
  assign stages_offloadGet4_state_root = stages_offloadSet4_state_root;
  assign stages_offloadGet4_state_isVirtual = stages_offloadSet4_state_isVirtual;
  assign stages_offloadGet4_state_isDefect = stages_offloadSet4_state_isDefect;
  assign stages_offloadGet4_state_grown = stages_offloadSet4_state_grown;
  assign stages_offloadGet4_message_valid = stages_offloadSet4_message_valid;
  assign stages_offloadGet4_message_instruction = stages_offloadSet4_message_instruction;
  assign stages_offloadGet4_message_isReset = stages_offloadSet4_message_isReset;
  assign stages_updateGet3_state_speed = stages_updateSet3_state_speed;
  assign stages_updateGet3_state_node = stages_updateSet3_state_node;
  assign stages_updateGet3_state_root = stages_updateSet3_state_root;
  assign stages_updateGet3_state_isVirtual = stages_updateSet3_state_isVirtual;
  assign stages_updateGet3_state_isDefect = stages_updateSet3_state_isDefect;
  assign stages_updateGet3_state_grown = stages_updateSet3_state_grown;
  assign stages_updateGet3_shadow_speed = stages_updateSet3_shadow_speed;
  assign stages_updateGet3_shadow_node = stages_updateSet3_shadow_node;
  assign stages_updateGet3_shadow_root = stages_updateSet3_shadow_root;
  assign stages_updateGet3_compact_valid = stages_updateSet3_compact_valid;
  assign stages_updateGet3_compact_isReset = stages_updateSet3_compact_isReset;
  assign stages_executeGet_state_speed = stages_executeSet_state_speed;
  assign stages_executeGet_state_node = stages_executeSet_state_node;
  assign stages_executeGet_state_root = stages_executeSet_state_root;
  assign stages_executeGet_state_isVirtual = stages_executeSet_state_isVirtual;
  assign stages_executeGet_state_isDefect = stages_executeSet_state_isDefect;
  assign stages_executeGet_state_grown = stages_executeSet_state_grown;
  assign stages_executeGet_message_valid = stages_executeSet_message_valid;
  assign stages_executeGet_message_instruction = stages_executeSet_message_instruction;
  assign stages_executeGet_message_isReset = stages_executeSet_message_isReset;
  assign stages_executeGet_isStalled = stages_executeSet_isStalled;
  assign stages_executeGet2_state_speed = stages_executeSet2_state_speed;
  assign stages_executeGet2_state_node = stages_executeSet2_state_node;
  assign stages_executeGet2_state_root = stages_executeSet2_state_root;
  assign stages_executeGet2_state_isVirtual = stages_executeSet2_state_isVirtual;
  assign stages_executeGet2_state_isDefect = stages_executeSet2_state_isDefect;
  assign stages_executeGet2_state_grown = stages_executeSet2_state_grown;
  assign stages_executeGet2_isStalled = stages_executeSet2_isStalled;
  assign stages_executeGet2_compact_valid = stages_executeSet2_compact_valid;
  assign stages_executeGet2_compact_isReset = stages_executeSet2_compact_isReset;
  assign stages_offloadGet3_state_speed = stages_offloadSet3_state_speed;
  assign stages_offloadGet3_state_node = stages_offloadSet3_state_node;
  assign stages_offloadGet3_state_root = stages_offloadSet3_state_root;
  assign stages_offloadGet3_state_isVirtual = stages_offloadSet3_state_isVirtual;
  assign stages_offloadGet3_state_isDefect = stages_offloadSet3_state_isDefect;
  assign stages_offloadGet3_state_grown = stages_offloadSet3_state_grown;
  assign stages_offloadGet3_message_valid = stages_offloadSet3_message_valid;
  assign stages_offloadGet3_message_instruction = stages_offloadSet3_message_instruction;
  assign stages_offloadGet3_message_isReset = stages_offloadSet3_message_isReset;
  assign stages_offloadGet3_isUniqueTight = stages_offloadSet3_isUniqueTight;
  assign stages_offloadGet3_isIsolated = stages_offloadSet3_isIsolated;
  assign stages_updateGet2_state_speed = stages_updateSet2_state_speed;
  assign stages_updateGet2_state_node = stages_updateSet2_state_node;
  assign stages_updateGet2_state_root = stages_updateSet2_state_root;
  assign stages_updateGet2_state_isVirtual = stages_updateSet2_state_isVirtual;
  assign stages_updateGet2_state_isDefect = stages_updateSet2_state_isDefect;
  assign stages_updateGet2_state_grown = stages_updateSet2_state_grown;
  assign stages_updateGet2_isStalled = stages_updateSet2_isStalled;
  assign stages_updateGet2_compact_valid = stages_updateSet2_compact_valid;
  assign stages_updateGet2_compact_isReset = stages_updateSet2_compact_isReset;
  assign stages_updateGet2_propagatingPeer_valid = stages_updateSet2_propagatingPeer_valid;
  assign stages_updateGet2_propagatingPeer_node = stages_updateSet2_propagatingPeer_node;
  assign stages_updateGet2_propagatingPeer_root = stages_updateSet2_propagatingPeer_root;
  assign stages_offloadGet2_state_speed = stages_offloadSet2_state_speed;
  assign stages_offloadGet2_state_node = stages_offloadSet2_state_node;
  assign stages_offloadGet2_state_root = stages_offloadSet2_state_root;
  assign stages_offloadGet2_state_isVirtual = stages_offloadSet2_state_isVirtual;
  assign stages_offloadGet2_state_isDefect = stages_offloadSet2_state_isDefect;
  assign stages_offloadGet2_state_grown = stages_offloadSet2_state_grown;
  assign stages_offloadGet2_message_valid = stages_offloadSet2_message_valid;
  assign stages_offloadGet2_message_instruction = stages_offloadSet2_message_instruction;
  assign stages_offloadGet2_message_isReset = stages_offloadSet2_message_isReset;
  always @(posedge clk or posedge reset) begin
    if(reset) begin
      register_speed <= 2'b00;
      register_node <= 5'h1f;
      register_root <= 5'h1f;
      register_isVirtual <= 1'b0;
      register_isDefect <= 1'b0;
      register_grown <= 2'b00;
    end else begin
      if(stages_updateGet3_compact_valid) begin
        register_speed <= stages_updateGet3_state_speed;
        register_node <= stages_updateGet3_state_node;
        register_root <= stages_updateGet3_state_root;
        register_isVirtual <= stages_updateGet3_state_isVirtual;
        register_isDefect <= stages_updateGet3_state_isDefect;
        register_grown <= stages_updateGet3_state_grown;
      end
    end
  end


endmodule

module Vertex (
  input               io_message_valid,
  input      [11:0]   io_message_instruction,
  input               io_message_isReset,
  output     [1:0]    io_stageOutputs_offloadGet_state_speed,
  output     [4:0]    io_stageOutputs_offloadGet_state_node,
  output     [4:0]    io_stageOutputs_offloadGet_state_root,
  output              io_stageOutputs_offloadGet_state_isVirtual,
  output              io_stageOutputs_offloadGet_state_isDefect,
  output     [1:0]    io_stageOutputs_offloadGet_state_grown,
  output              io_stageOutputs_offloadGet_message_valid,
  output     [11:0]   io_stageOutputs_offloadGet_message_instruction,
  output              io_stageOutputs_offloadGet_message_isReset,
  output     [1:0]    io_stageOutputs_offloadGet2_state_speed,
  output     [4:0]    io_stageOutputs_offloadGet2_state_node,
  output     [4:0]    io_stageOutputs_offloadGet2_state_root,
  output              io_stageOutputs_offloadGet2_state_isVirtual,
  output              io_stageOutputs_offloadGet2_state_isDefect,
  output     [1:0]    io_stageOutputs_offloadGet2_state_grown,
  output              io_stageOutputs_offloadGet2_message_valid,
  output     [11:0]   io_stageOutputs_offloadGet2_message_instruction,
  output              io_stageOutputs_offloadGet2_message_isReset,
  output     [1:0]    io_stageOutputs_offloadGet3_state_speed,
  output     [4:0]    io_stageOutputs_offloadGet3_state_node,
  output     [4:0]    io_stageOutputs_offloadGet3_state_root,
  output              io_stageOutputs_offloadGet3_state_isVirtual,
  output              io_stageOutputs_offloadGet3_state_isDefect,
  output     [1:0]    io_stageOutputs_offloadGet3_state_grown,
  output              io_stageOutputs_offloadGet3_message_valid,
  output     [11:0]   io_stageOutputs_offloadGet3_message_instruction,
  output              io_stageOutputs_offloadGet3_message_isReset,
  output              io_stageOutputs_offloadGet3_isUniqueTight,
  output              io_stageOutputs_offloadGet3_isIsolated,
  output     [1:0]    io_stageOutputs_offloadGet4_state_speed,
  output     [4:0]    io_stageOutputs_offloadGet4_state_node,
  output     [4:0]    io_stageOutputs_offloadGet4_state_root,
  output              io_stageOutputs_offloadGet4_state_isVirtual,
  output              io_stageOutputs_offloadGet4_state_isDefect,
  output     [1:0]    io_stageOutputs_offloadGet4_state_grown,
  output              io_stageOutputs_offloadGet4_message_valid,
  output     [11:0]   io_stageOutputs_offloadGet4_message_instruction,
  output              io_stageOutputs_offloadGet4_message_isReset,
  output     [1:0]    io_stageOutputs_executeGet_state_speed,
  output     [4:0]    io_stageOutputs_executeGet_state_node,
  output     [4:0]    io_stageOutputs_executeGet_state_root,
  output              io_stageOutputs_executeGet_state_isVirtual,
  output              io_stageOutputs_executeGet_state_isDefect,
  output     [1:0]    io_stageOutputs_executeGet_state_grown,
  output              io_stageOutputs_executeGet_message_valid,
  output     [11:0]   io_stageOutputs_executeGet_message_instruction,
  output              io_stageOutputs_executeGet_message_isReset,
  output              io_stageOutputs_executeGet_isStalled,
  output     [1:0]    io_stageOutputs_executeGet2_state_speed,
  output     [4:0]    io_stageOutputs_executeGet2_state_node,
  output     [4:0]    io_stageOutputs_executeGet2_state_root,
  output              io_stageOutputs_executeGet2_state_isVirtual,
  output              io_stageOutputs_executeGet2_state_isDefect,
  output     [1:0]    io_stageOutputs_executeGet2_state_grown,
  output              io_stageOutputs_executeGet2_isStalled,
  output              io_stageOutputs_executeGet2_compact_valid,
  output              io_stageOutputs_executeGet2_compact_isReset,
  output     [1:0]    io_stageOutputs_executeGet3_state_speed,
  output     [4:0]    io_stageOutputs_executeGet3_state_node,
  output     [4:0]    io_stageOutputs_executeGet3_state_root,
  output              io_stageOutputs_executeGet3_state_isVirtual,
  output              io_stageOutputs_executeGet3_state_isDefect,
  output     [1:0]    io_stageOutputs_executeGet3_state_grown,
  output              io_stageOutputs_executeGet3_isStalled,
  output              io_stageOutputs_executeGet3_compact_valid,
  output              io_stageOutputs_executeGet3_compact_isReset,
  output     [1:0]    io_stageOutputs_updateGet_state_speed,
  output     [4:0]    io_stageOutputs_updateGet_state_node,
  output     [4:0]    io_stageOutputs_updateGet_state_root,
  output              io_stageOutputs_updateGet_state_isVirtual,
  output              io_stageOutputs_updateGet_state_isDefect,
  output     [1:0]    io_stageOutputs_updateGet_state_grown,
  output              io_stageOutputs_updateGet_isStalled,
  output              io_stageOutputs_updateGet_compact_valid,
  output              io_stageOutputs_updateGet_compact_isReset,
  output              io_stageOutputs_updateGet_propagatingPeer_valid,
  output     [4:0]    io_stageOutputs_updateGet_propagatingPeer_node,
  output     [4:0]    io_stageOutputs_updateGet_propagatingPeer_root,
  output     [1:0]    io_stageOutputs_updateGet2_state_speed,
  output     [4:0]    io_stageOutputs_updateGet2_state_node,
  output     [4:0]    io_stageOutputs_updateGet2_state_root,
  output              io_stageOutputs_updateGet2_state_isVirtual,
  output              io_stageOutputs_updateGet2_state_isDefect,
  output     [1:0]    io_stageOutputs_updateGet2_state_grown,
  output              io_stageOutputs_updateGet2_isStalled,
  output              io_stageOutputs_updateGet2_compact_valid,
  output              io_stageOutputs_updateGet2_compact_isReset,
  output              io_stageOutputs_updateGet2_propagatingPeer_valid,
  output     [4:0]    io_stageOutputs_updateGet2_propagatingPeer_node,
  output     [4:0]    io_stageOutputs_updateGet2_propagatingPeer_root,
  output     [1:0]    io_stageOutputs_updateGet3_state_speed,
  output     [4:0]    io_stageOutputs_updateGet3_state_node,
  output     [4:0]    io_stageOutputs_updateGet3_state_root,
  output              io_stageOutputs_updateGet3_state_isVirtual,
  output              io_stageOutputs_updateGet3_state_isDefect,
  output     [1:0]    io_stageOutputs_updateGet3_state_grown,
  output     [1:0]    io_stageOutputs_updateGet3_shadow_speed,
  output     [4:0]    io_stageOutputs_updateGet3_shadow_node,
  output     [4:0]    io_stageOutputs_updateGet3_shadow_root,
  output              io_stageOutputs_updateGet3_compact_valid,
  output              io_stageOutputs_updateGet3_compact_isReset,
  input      [1:0]    io_edgeInputs_0_offloadGet_state_weight,
  input               io_edgeInputs_0_offloadGet_compact_valid,
  input               io_edgeInputs_0_offloadGet_compact_isReset,
  input      [1:0]    io_edgeInputs_0_offloadGet2_state_weight,
  input               io_edgeInputs_0_offloadGet2_isTight,
  input               io_edgeInputs_0_offloadGet2_isTightExFusion,
  input               io_edgeInputs_0_offloadGet2_compact_valid,
  input               io_edgeInputs_0_offloadGet2_compact_isReset,
  input      [1:0]    io_edgeInputs_0_offloadGet3_state_weight,
  input               io_edgeInputs_0_offloadGet3_isTight,
  input               io_edgeInputs_0_offloadGet3_compact_valid,
  input               io_edgeInputs_0_offloadGet3_compact_isReset,
  input      [1:0]    io_edgeInputs_0_offloadGet4_state_weight,
  input               io_edgeInputs_0_offloadGet4_compact_valid,
  input               io_edgeInputs_0_offloadGet4_compact_isReset,
  input      [1:0]    io_edgeInputs_0_executeGet_state_weight,
  input               io_edgeInputs_0_executeGet_compact_valid,
  input               io_edgeInputs_0_executeGet_compact_isReset,
  input      [1:0]    io_edgeInputs_0_executeGet2_state_weight,
  input               io_edgeInputs_0_executeGet2_compact_valid,
  input               io_edgeInputs_0_executeGet2_compact_isReset,
  input      [1:0]    io_edgeInputs_0_executeGet3_state_weight,
  input               io_edgeInputs_0_executeGet3_isTight,
  input               io_edgeInputs_0_executeGet3_compact_valid,
  input               io_edgeInputs_0_executeGet3_compact_isReset,
  input      [1:0]    io_edgeInputs_0_updateGet_state_weight,
  input      [1:0]    io_edgeInputs_0_updateGet_remaining,
  input               io_edgeInputs_0_updateGet_compact_valid,
  input               io_edgeInputs_0_updateGet_compact_isReset,
  input      [1:0]    io_edgeInputs_0_updateGet2_state_weight,
  input      [1:0]    io_edgeInputs_0_updateGet2_remaining,
  input               io_edgeInputs_0_updateGet2_compact_valid,
  input               io_edgeInputs_0_updateGet2_compact_isReset,
  input      [1:0]    io_edgeInputs_0_updateGet3_state_weight,
  input      [1:0]    io_edgeInputs_0_updateGet3_remaining,
  input               io_edgeInputs_0_updateGet3_compact_valid,
  input               io_edgeInputs_0_updateGet3_compact_isReset,
  input      [1:0]    io_edgeInputs_1_offloadGet_state_weight,
  input               io_edgeInputs_1_offloadGet_compact_valid,
  input               io_edgeInputs_1_offloadGet_compact_isReset,
  input      [1:0]    io_edgeInputs_1_offloadGet2_state_weight,
  input               io_edgeInputs_1_offloadGet2_isTight,
  input               io_edgeInputs_1_offloadGet2_isTightExFusion,
  input               io_edgeInputs_1_offloadGet2_compact_valid,
  input               io_edgeInputs_1_offloadGet2_compact_isReset,
  input      [1:0]    io_edgeInputs_1_offloadGet3_state_weight,
  input               io_edgeInputs_1_offloadGet3_isTight,
  input               io_edgeInputs_1_offloadGet3_compact_valid,
  input               io_edgeInputs_1_offloadGet3_compact_isReset,
  input      [1:0]    io_edgeInputs_1_offloadGet4_state_weight,
  input               io_edgeInputs_1_offloadGet4_compact_valid,
  input               io_edgeInputs_1_offloadGet4_compact_isReset,
  input      [1:0]    io_edgeInputs_1_executeGet_state_weight,
  input               io_edgeInputs_1_executeGet_compact_valid,
  input               io_edgeInputs_1_executeGet_compact_isReset,
  input      [1:0]    io_edgeInputs_1_executeGet2_state_weight,
  input               io_edgeInputs_1_executeGet2_compact_valid,
  input               io_edgeInputs_1_executeGet2_compact_isReset,
  input      [1:0]    io_edgeInputs_1_executeGet3_state_weight,
  input               io_edgeInputs_1_executeGet3_isTight,
  input               io_edgeInputs_1_executeGet3_compact_valid,
  input               io_edgeInputs_1_executeGet3_compact_isReset,
  input      [1:0]    io_edgeInputs_1_updateGet_state_weight,
  input      [1:0]    io_edgeInputs_1_updateGet_remaining,
  input               io_edgeInputs_1_updateGet_compact_valid,
  input               io_edgeInputs_1_updateGet_compact_isReset,
  input      [1:0]    io_edgeInputs_1_updateGet2_state_weight,
  input      [1:0]    io_edgeInputs_1_updateGet2_remaining,
  input               io_edgeInputs_1_updateGet2_compact_valid,
  input               io_edgeInputs_1_updateGet2_compact_isReset,
  input      [1:0]    io_edgeInputs_1_updateGet3_state_weight,
  input      [1:0]    io_edgeInputs_1_updateGet3_remaining,
  input               io_edgeInputs_1_updateGet3_compact_valid,
  input               io_edgeInputs_1_updateGet3_compact_isReset,
  input      [1:0]    _zz_io_peerSpeed_0,
  input      [4:0]    _zz_io_peerNode_0,
  input      [4:0]    _zz_io_peerRoot_0,
  input      [1:0]    _zz_io_peerSpeed_1,
  input      [4:0]    _zz_io_peerNode_1,
  input      [4:0]    _zz_io_peerRoot_1,
  output     [1:0]    io_maxGrowable_length,
  input               clk,
  input               reset
);

  wire                offload3Area_tightCounter_io_isUnique;
  wire                offload3Area_tightCounter_io_isIsolated;
  wire                executeArea_offloadStalled_io_isStalled;
  wire       [1:0]    execute2Area_vertexPostExecuteState_io_after_speed;
  wire       [4:0]    execute2Area_vertexPostExecuteState_io_after_node;
  wire       [4:0]    execute2Area_vertexPostExecuteState_io_after_root;
  wire                execute2Area_vertexPostExecuteState_io_after_isVirtual;
  wire                execute2Area_vertexPostExecuteState_io_after_isDefect;
  wire       [1:0]    execute2Area_vertexPostExecuteState_io_after_grown;
  wire                updateArea_vertexPropagatingPeer_io_peer_valid;
  wire       [4:0]    updateArea_vertexPropagatingPeer_io_peer_node;
  wire       [4:0]    updateArea_vertexPropagatingPeer_io_peer_root;
  wire       [1:0]    update2Area_vertexPostUpdateState_io_after_speed;
  wire       [4:0]    update2Area_vertexPostUpdateState_io_after_node;
  wire       [4:0]    update2Area_vertexPostUpdateState_io_after_root;
  wire                update2Area_vertexPostUpdateState_io_after_isVirtual;
  wire                update2Area_vertexPostUpdateState_io_after_isDefect;
  wire       [1:0]    update2Area_vertexPostUpdateState_io_after_grown;
  wire       [1:0]    update3Area_vertexShadow_io_shadow_speed;
  wire       [4:0]    update3Area_vertexShadow_io_shadow_node;
  wire       [4:0]    update3Area_vertexShadow_io_shadow_root;
  wire       [1:0]    vertexResponse_4_io_maxGrowable_length;
  wire       [1:0]    stages_offloadSet_state_speed;
  wire       [4:0]    stages_offloadSet_state_node;
  wire       [4:0]    stages_offloadSet_state_root;
  wire                stages_offloadSet_state_isVirtual;
  wire                stages_offloadSet_state_isDefect;
  wire       [1:0]    stages_offloadSet_state_grown;
  wire                stages_offloadSet_message_valid;
  wire       [11:0]   stages_offloadSet_message_instruction;
  wire                stages_offloadSet_message_isReset;
  wire       [1:0]    stages_offloadGet_state_speed;
  wire       [4:0]    stages_offloadGet_state_node;
  wire       [4:0]    stages_offloadGet_state_root;
  wire                stages_offloadGet_state_isVirtual;
  wire                stages_offloadGet_state_isDefect;
  wire       [1:0]    stages_offloadGet_state_grown;
  wire                stages_offloadGet_message_valid;
  wire       [11:0]   stages_offloadGet_message_instruction;
  wire                stages_offloadGet_message_isReset;
  wire       [1:0]    stages_offloadSet2_state_speed;
  wire       [4:0]    stages_offloadSet2_state_node;
  wire       [4:0]    stages_offloadSet2_state_root;
  wire                stages_offloadSet2_state_isVirtual;
  wire                stages_offloadSet2_state_isDefect;
  wire       [1:0]    stages_offloadSet2_state_grown;
  wire                stages_offloadSet2_message_valid;
  wire       [11:0]   stages_offloadSet2_message_instruction;
  wire                stages_offloadSet2_message_isReset;
  wire       [1:0]    stages_offloadGet2_state_speed;
  wire       [4:0]    stages_offloadGet2_state_node;
  wire       [4:0]    stages_offloadGet2_state_root;
  wire                stages_offloadGet2_state_isVirtual;
  wire                stages_offloadGet2_state_isDefect;
  wire       [1:0]    stages_offloadGet2_state_grown;
  wire                stages_offloadGet2_message_valid;
  wire       [11:0]   stages_offloadGet2_message_instruction;
  wire                stages_offloadGet2_message_isReset;
  wire       [1:0]    stages_offloadSet3_state_speed;
  wire       [4:0]    stages_offloadSet3_state_node;
  wire       [4:0]    stages_offloadSet3_state_root;
  wire                stages_offloadSet3_state_isVirtual;
  wire                stages_offloadSet3_state_isDefect;
  wire       [1:0]    stages_offloadSet3_state_grown;
  wire                stages_offloadSet3_message_valid;
  wire       [11:0]   stages_offloadSet3_message_instruction;
  wire                stages_offloadSet3_message_isReset;
  wire                stages_offloadSet3_isUniqueTight;
  wire                stages_offloadSet3_isIsolated;
  wire       [1:0]    stages_offloadGet3_state_speed;
  wire       [4:0]    stages_offloadGet3_state_node;
  wire       [4:0]    stages_offloadGet3_state_root;
  wire                stages_offloadGet3_state_isVirtual;
  wire                stages_offloadGet3_state_isDefect;
  wire       [1:0]    stages_offloadGet3_state_grown;
  wire                stages_offloadGet3_message_valid;
  wire       [11:0]   stages_offloadGet3_message_instruction;
  wire                stages_offloadGet3_message_isReset;
  wire                stages_offloadGet3_isUniqueTight;
  wire                stages_offloadGet3_isIsolated;
  wire       [1:0]    stages_offloadSet4_state_speed;
  wire       [4:0]    stages_offloadSet4_state_node;
  wire       [4:0]    stages_offloadSet4_state_root;
  wire                stages_offloadSet4_state_isVirtual;
  wire                stages_offloadSet4_state_isDefect;
  wire       [1:0]    stages_offloadSet4_state_grown;
  wire                stages_offloadSet4_message_valid;
  wire       [11:0]   stages_offloadSet4_message_instruction;
  wire                stages_offloadSet4_message_isReset;
  wire       [1:0]    stages_offloadGet4_state_speed;
  wire       [4:0]    stages_offloadGet4_state_node;
  wire       [4:0]    stages_offloadGet4_state_root;
  wire                stages_offloadGet4_state_isVirtual;
  wire                stages_offloadGet4_state_isDefect;
  wire       [1:0]    stages_offloadGet4_state_grown;
  wire                stages_offloadGet4_message_valid;
  wire       [11:0]   stages_offloadGet4_message_instruction;
  wire                stages_offloadGet4_message_isReset;
  wire       [1:0]    stages_executeSet_state_speed;
  wire       [4:0]    stages_executeSet_state_node;
  wire       [4:0]    stages_executeSet_state_root;
  wire                stages_executeSet_state_isVirtual;
  wire                stages_executeSet_state_isDefect;
  wire       [1:0]    stages_executeSet_state_grown;
  wire                stages_executeSet_message_valid;
  wire       [11:0]   stages_executeSet_message_instruction;
  wire                stages_executeSet_message_isReset;
  wire                stages_executeSet_isStalled;
  wire       [1:0]    stages_executeGet_state_speed;
  wire       [4:0]    stages_executeGet_state_node;
  wire       [4:0]    stages_executeGet_state_root;
  wire                stages_executeGet_state_isVirtual;
  wire                stages_executeGet_state_isDefect;
  wire       [1:0]    stages_executeGet_state_grown;
  wire                stages_executeGet_message_valid;
  wire       [11:0]   stages_executeGet_message_instruction;
  wire                stages_executeGet_message_isReset;
  wire                stages_executeGet_isStalled;
  wire       [1:0]    stages_executeSet2_state_speed;
  wire       [4:0]    stages_executeSet2_state_node;
  wire       [4:0]    stages_executeSet2_state_root;
  wire                stages_executeSet2_state_isVirtual;
  wire                stages_executeSet2_state_isDefect;
  wire       [1:0]    stages_executeSet2_state_grown;
  wire                stages_executeSet2_isStalled;
  wire                stages_executeSet2_compact_valid;
  wire                stages_executeSet2_compact_isReset;
  wire       [1:0]    stages_executeGet2_state_speed;
  wire       [4:0]    stages_executeGet2_state_node;
  wire       [4:0]    stages_executeGet2_state_root;
  wire                stages_executeGet2_state_isVirtual;
  wire                stages_executeGet2_state_isDefect;
  wire       [1:0]    stages_executeGet2_state_grown;
  wire                stages_executeGet2_isStalled;
  wire                stages_executeGet2_compact_valid;
  wire                stages_executeGet2_compact_isReset;
  wire       [1:0]    stages_executeSet3_state_speed;
  wire       [4:0]    stages_executeSet3_state_node;
  wire       [4:0]    stages_executeSet3_state_root;
  wire                stages_executeSet3_state_isVirtual;
  wire                stages_executeSet3_state_isDefect;
  wire       [1:0]    stages_executeSet3_state_grown;
  wire                stages_executeSet3_isStalled;
  wire                stages_executeSet3_compact_valid;
  wire                stages_executeSet3_compact_isReset;
  wire       [1:0]    stages_executeGet3_state_speed;
  wire       [4:0]    stages_executeGet3_state_node;
  wire       [4:0]    stages_executeGet3_state_root;
  wire                stages_executeGet3_state_isVirtual;
  wire                stages_executeGet3_state_isDefect;
  wire       [1:0]    stages_executeGet3_state_grown;
  wire                stages_executeGet3_isStalled;
  wire                stages_executeGet3_compact_valid;
  wire                stages_executeGet3_compact_isReset;
  wire       [1:0]    stages_updateSet_state_speed;
  wire       [4:0]    stages_updateSet_state_node;
  wire       [4:0]    stages_updateSet_state_root;
  wire                stages_updateSet_state_isVirtual;
  wire                stages_updateSet_state_isDefect;
  wire       [1:0]    stages_updateSet_state_grown;
  wire                stages_updateSet_isStalled;
  wire                stages_updateSet_compact_valid;
  wire                stages_updateSet_compact_isReset;
  wire                stages_updateSet_propagatingPeer_valid;
  wire       [4:0]    stages_updateSet_propagatingPeer_node;
  wire       [4:0]    stages_updateSet_propagatingPeer_root;
  wire       [1:0]    stages_updateGet_state_speed;
  wire       [4:0]    stages_updateGet_state_node;
  wire       [4:0]    stages_updateGet_state_root;
  wire                stages_updateGet_state_isVirtual;
  wire                stages_updateGet_state_isDefect;
  wire       [1:0]    stages_updateGet_state_grown;
  wire                stages_updateGet_isStalled;
  wire                stages_updateGet_compact_valid;
  wire                stages_updateGet_compact_isReset;
  wire                stages_updateGet_propagatingPeer_valid;
  wire       [4:0]    stages_updateGet_propagatingPeer_node;
  wire       [4:0]    stages_updateGet_propagatingPeer_root;
  wire       [1:0]    stages_updateSet2_state_speed;
  wire       [4:0]    stages_updateSet2_state_node;
  wire       [4:0]    stages_updateSet2_state_root;
  wire                stages_updateSet2_state_isVirtual;
  wire                stages_updateSet2_state_isDefect;
  wire       [1:0]    stages_updateSet2_state_grown;
  wire                stages_updateSet2_isStalled;
  wire                stages_updateSet2_compact_valid;
  wire                stages_updateSet2_compact_isReset;
  wire                stages_updateSet2_propagatingPeer_valid;
  wire       [4:0]    stages_updateSet2_propagatingPeer_node;
  wire       [4:0]    stages_updateSet2_propagatingPeer_root;
  wire       [1:0]    stages_updateGet2_state_speed;
  wire       [4:0]    stages_updateGet2_state_node;
  wire       [4:0]    stages_updateGet2_state_root;
  wire                stages_updateGet2_state_isVirtual;
  wire                stages_updateGet2_state_isDefect;
  wire       [1:0]    stages_updateGet2_state_grown;
  wire                stages_updateGet2_isStalled;
  wire                stages_updateGet2_compact_valid;
  wire                stages_updateGet2_compact_isReset;
  wire                stages_updateGet2_propagatingPeer_valid;
  wire       [4:0]    stages_updateGet2_propagatingPeer_node;
  wire       [4:0]    stages_updateGet2_propagatingPeer_root;
  wire       [1:0]    stages_updateSet3_state_speed;
  wire       [4:0]    stages_updateSet3_state_node;
  wire       [4:0]    stages_updateSet3_state_root;
  wire                stages_updateSet3_state_isVirtual;
  wire                stages_updateSet3_state_isDefect;
  wire       [1:0]    stages_updateSet3_state_grown;
  wire       [1:0]    stages_updateSet3_shadow_speed;
  wire       [4:0]    stages_updateSet3_shadow_node;
  wire       [4:0]    stages_updateSet3_shadow_root;
  wire                stages_updateSet3_compact_valid;
  wire                stages_updateSet3_compact_isReset;
  wire       [1:0]    stages_updateGet3_state_speed;
  wire       [4:0]    stages_updateGet3_state_node;
  wire       [4:0]    stages_updateGet3_state_root;
  wire                stages_updateGet3_state_isVirtual;
  wire                stages_updateGet3_state_isDefect;
  wire       [1:0]    stages_updateGet3_state_grown;
  wire       [1:0]    stages_updateGet3_shadow_speed;
  wire       [4:0]    stages_updateGet3_shadow_node;
  wire       [4:0]    stages_updateGet3_shadow_root;
  wire                stages_updateGet3_compact_valid;
  wire                stages_updateGet3_compact_isReset;
  reg        [1:0]    register_speed;
  reg        [4:0]    register_node;
  reg        [4:0]    register_root;
  reg                 register_isVirtual;
  reg                 register_isDefect;
  reg        [1:0]    register_grown;
  wire       [1:0]    fetchState_speed;
  wire       [4:0]    fetchState_node;
  wire       [4:0]    fetchState_root;
  wire                fetchState_isVirtual;
  wire                fetchState_isDefect;
  wire       [1:0]    fetchState_grown;
  wire                message_valid;
  wire       [11:0]   message_instruction;
  wire                message_isReset;

  VertexTightCounter_3 offload3Area_tightCounter (
    .io_tights_0   (io_edgeInputs_0_offloadGet2_isTightExFusion), //i
    .io_tights_1   (io_edgeInputs_1_offloadGet2_isTightExFusion), //i
    .io_isUnique   (offload3Area_tightCounter_io_isUnique      ), //o
    .io_isIsolated (offload3Area_tightCounter_io_isIsolated    )  //o
  );
  OffloadStalled_3 executeArea_offloadStalled (
    .io_isStalled (executeArea_offloadStalled_io_isStalled)  //o
  );
  VertexPostExecuteState_3 execute2Area_vertexPostExecuteState (
    .io_before_speed        (stages_executeGet_state_speed[1:0]                     ), //i
    .io_before_node         (stages_executeGet_state_node[4:0]                      ), //i
    .io_before_root         (stages_executeGet_state_root[4:0]                      ), //i
    .io_before_isVirtual    (stages_executeGet_state_isVirtual                      ), //i
    .io_before_isDefect     (stages_executeGet_state_isDefect                       ), //i
    .io_before_grown        (stages_executeGet_state_grown[1:0]                     ), //i
    .io_message_valid       (stages_executeGet_message_valid                        ), //i
    .io_message_instruction (stages_executeGet_message_instruction[11:0]            ), //i
    .io_message_isReset     (stages_executeGet_message_isReset                      ), //i
    .io_isStalled           (stages_executeGet_isStalled                            ), //i
    .io_after_speed         (execute2Area_vertexPostExecuteState_io_after_speed[1:0]), //o
    .io_after_node          (execute2Area_vertexPostExecuteState_io_after_node[4:0] ), //o
    .io_after_root          (execute2Area_vertexPostExecuteState_io_after_root[4:0] ), //o
    .io_after_isVirtual     (execute2Area_vertexPostExecuteState_io_after_isVirtual ), //o
    .io_after_isDefect      (execute2Area_vertexPostExecuteState_io_after_isDefect  ), //o
    .io_after_grown         (execute2Area_vertexPostExecuteState_io_after_grown[1:0]), //o
    .clk                    (clk                                                    ), //i
    .reset                  (reset                                                  )  //i
  );
  VertexPropagatingPeer_3 updateArea_vertexPropagatingPeer (
    .io_grown         (stages_executeGet3_state_grown[1:0]               ), //i
    .io_edgeIsTight_0 (io_edgeInputs_0_executeGet3_isTight               ), //i
    .io_edgeIsTight_1 (io_edgeInputs_1_executeGet3_isTight               ), //i
    .io_peerSpeed_0   (_zz_io_peerSpeed_0[1:0]                           ), //i
    .io_peerSpeed_1   (_zz_io_peerSpeed_1[1:0]                           ), //i
    .io_peerNode_0    (_zz_io_peerNode_0[4:0]                            ), //i
    .io_peerNode_1    (_zz_io_peerNode_1[4:0]                            ), //i
    .io_peerRoot_0    (_zz_io_peerRoot_0[4:0]                            ), //i
    .io_peerRoot_1    (_zz_io_peerRoot_1[4:0]                            ), //i
    .io_peer_valid    (updateArea_vertexPropagatingPeer_io_peer_valid    ), //o
    .io_peer_node     (updateArea_vertexPropagatingPeer_io_peer_node[4:0]), //o
    .io_peer_root     (updateArea_vertexPropagatingPeer_io_peer_root[4:0])  //o
  );
  VertexPostUpdateState_3 update2Area_vertexPostUpdateState (
    .io_before_speed     (stages_updateGet_state_speed[1:0]                    ), //i
    .io_before_node      (stages_updateGet_state_node[4:0]                     ), //i
    .io_before_root      (stages_updateGet_state_root[4:0]                     ), //i
    .io_before_isVirtual (stages_updateGet_state_isVirtual                     ), //i
    .io_before_isDefect  (stages_updateGet_state_isDefect                      ), //i
    .io_before_grown     (stages_updateGet_state_grown[1:0]                    ), //i
    .io_propagator_valid (stages_updateGet_propagatingPeer_valid               ), //i
    .io_propagator_node  (stages_updateGet_propagatingPeer_node[4:0]           ), //i
    .io_propagator_root  (stages_updateGet_propagatingPeer_root[4:0]           ), //i
    .io_after_speed      (update2Area_vertexPostUpdateState_io_after_speed[1:0]), //o
    .io_after_node       (update2Area_vertexPostUpdateState_io_after_node[4:0] ), //o
    .io_after_root       (update2Area_vertexPostUpdateState_io_after_root[4:0] ), //o
    .io_after_isVirtual  (update2Area_vertexPostUpdateState_io_after_isVirtual ), //o
    .io_after_isDefect   (update2Area_vertexPostUpdateState_io_after_isDefect  ), //o
    .io_after_grown      (update2Area_vertexPostUpdateState_io_after_grown[1:0])  //o
  );
  VertexShadow_3 update3Area_vertexShadow (
    .io_isVirtual        (stages_updateGet2_state_isVirtual            ), //i
    .io_node             (stages_updateGet2_state_node[4:0]            ), //i
    .io_root             (stages_updateGet2_state_root[4:0]            ), //i
    .io_speed            (stages_updateGet2_state_speed[1:0]           ), //i
    .io_grown            (stages_updateGet2_state_grown[1:0]           ), //i
    .io_isStalled        (stages_updateGet2_isStalled                  ), //i
    .io_propagator_valid (stages_updateGet2_propagatingPeer_valid      ), //i
    .io_propagator_node  (stages_updateGet2_propagatingPeer_node[4:0]  ), //i
    .io_propagator_root  (stages_updateGet2_propagatingPeer_root[4:0]  ), //i
    .io_shadow_speed     (update3Area_vertexShadow_io_shadow_speed[1:0]), //o
    .io_shadow_node      (update3Area_vertexShadow_io_shadow_node[4:0] ), //o
    .io_shadow_root      (update3Area_vertexShadow_io_shadow_root[4:0] )  //o
  );
  VertexResponse_3 vertexResponse_4 (
    .io_state_speed        (stages_updateGet3_state_speed[1:0]         ), //i
    .io_state_node         (stages_updateGet3_state_node[4:0]          ), //i
    .io_state_root         (stages_updateGet3_state_root[4:0]          ), //i
    .io_state_isVirtual    (stages_updateGet3_state_isVirtual          ), //i
    .io_state_isDefect     (stages_updateGet3_state_isDefect           ), //i
    .io_state_grown        (stages_updateGet3_state_grown[1:0]         ), //i
    .io_maxGrowable_length (vertexResponse_4_io_maxGrowable_length[1:0])  //o
  );
  assign io_stageOutputs_offloadGet_state_speed = stages_offloadGet_state_speed;
  assign io_stageOutputs_offloadGet_state_node = stages_offloadGet_state_node;
  assign io_stageOutputs_offloadGet_state_root = stages_offloadGet_state_root;
  assign io_stageOutputs_offloadGet_state_isVirtual = stages_offloadGet_state_isVirtual;
  assign io_stageOutputs_offloadGet_state_isDefect = stages_offloadGet_state_isDefect;
  assign io_stageOutputs_offloadGet_state_grown = stages_offloadGet_state_grown;
  assign io_stageOutputs_offloadGet_message_valid = stages_offloadGet_message_valid;
  assign io_stageOutputs_offloadGet_message_instruction = stages_offloadGet_message_instruction;
  assign io_stageOutputs_offloadGet_message_isReset = stages_offloadGet_message_isReset;
  assign io_stageOutputs_offloadGet2_state_speed = stages_offloadGet2_state_speed;
  assign io_stageOutputs_offloadGet2_state_node = stages_offloadGet2_state_node;
  assign io_stageOutputs_offloadGet2_state_root = stages_offloadGet2_state_root;
  assign io_stageOutputs_offloadGet2_state_isVirtual = stages_offloadGet2_state_isVirtual;
  assign io_stageOutputs_offloadGet2_state_isDefect = stages_offloadGet2_state_isDefect;
  assign io_stageOutputs_offloadGet2_state_grown = stages_offloadGet2_state_grown;
  assign io_stageOutputs_offloadGet2_message_valid = stages_offloadGet2_message_valid;
  assign io_stageOutputs_offloadGet2_message_instruction = stages_offloadGet2_message_instruction;
  assign io_stageOutputs_offloadGet2_message_isReset = stages_offloadGet2_message_isReset;
  assign io_stageOutputs_offloadGet3_state_speed = stages_offloadGet3_state_speed;
  assign io_stageOutputs_offloadGet3_state_node = stages_offloadGet3_state_node;
  assign io_stageOutputs_offloadGet3_state_root = stages_offloadGet3_state_root;
  assign io_stageOutputs_offloadGet3_state_isVirtual = stages_offloadGet3_state_isVirtual;
  assign io_stageOutputs_offloadGet3_state_isDefect = stages_offloadGet3_state_isDefect;
  assign io_stageOutputs_offloadGet3_state_grown = stages_offloadGet3_state_grown;
  assign io_stageOutputs_offloadGet3_message_valid = stages_offloadGet3_message_valid;
  assign io_stageOutputs_offloadGet3_message_instruction = stages_offloadGet3_message_instruction;
  assign io_stageOutputs_offloadGet3_message_isReset = stages_offloadGet3_message_isReset;
  assign io_stageOutputs_offloadGet3_isUniqueTight = stages_offloadGet3_isUniqueTight;
  assign io_stageOutputs_offloadGet3_isIsolated = stages_offloadGet3_isIsolated;
  assign io_stageOutputs_offloadGet4_state_speed = stages_offloadGet4_state_speed;
  assign io_stageOutputs_offloadGet4_state_node = stages_offloadGet4_state_node;
  assign io_stageOutputs_offloadGet4_state_root = stages_offloadGet4_state_root;
  assign io_stageOutputs_offloadGet4_state_isVirtual = stages_offloadGet4_state_isVirtual;
  assign io_stageOutputs_offloadGet4_state_isDefect = stages_offloadGet4_state_isDefect;
  assign io_stageOutputs_offloadGet4_state_grown = stages_offloadGet4_state_grown;
  assign io_stageOutputs_offloadGet4_message_valid = stages_offloadGet4_message_valid;
  assign io_stageOutputs_offloadGet4_message_instruction = stages_offloadGet4_message_instruction;
  assign io_stageOutputs_offloadGet4_message_isReset = stages_offloadGet4_message_isReset;
  assign io_stageOutputs_executeGet_state_speed = stages_executeGet_state_speed;
  assign io_stageOutputs_executeGet_state_node = stages_executeGet_state_node;
  assign io_stageOutputs_executeGet_state_root = stages_executeGet_state_root;
  assign io_stageOutputs_executeGet_state_isVirtual = stages_executeGet_state_isVirtual;
  assign io_stageOutputs_executeGet_state_isDefect = stages_executeGet_state_isDefect;
  assign io_stageOutputs_executeGet_state_grown = stages_executeGet_state_grown;
  assign io_stageOutputs_executeGet_message_valid = stages_executeGet_message_valid;
  assign io_stageOutputs_executeGet_message_instruction = stages_executeGet_message_instruction;
  assign io_stageOutputs_executeGet_message_isReset = stages_executeGet_message_isReset;
  assign io_stageOutputs_executeGet_isStalled = stages_executeGet_isStalled;
  assign io_stageOutputs_executeGet2_state_speed = stages_executeGet2_state_speed;
  assign io_stageOutputs_executeGet2_state_node = stages_executeGet2_state_node;
  assign io_stageOutputs_executeGet2_state_root = stages_executeGet2_state_root;
  assign io_stageOutputs_executeGet2_state_isVirtual = stages_executeGet2_state_isVirtual;
  assign io_stageOutputs_executeGet2_state_isDefect = stages_executeGet2_state_isDefect;
  assign io_stageOutputs_executeGet2_state_grown = stages_executeGet2_state_grown;
  assign io_stageOutputs_executeGet2_isStalled = stages_executeGet2_isStalled;
  assign io_stageOutputs_executeGet2_compact_valid = stages_executeGet2_compact_valid;
  assign io_stageOutputs_executeGet2_compact_isReset = stages_executeGet2_compact_isReset;
  assign io_stageOutputs_executeGet3_state_speed = stages_executeGet3_state_speed;
  assign io_stageOutputs_executeGet3_state_node = stages_executeGet3_state_node;
  assign io_stageOutputs_executeGet3_state_root = stages_executeGet3_state_root;
  assign io_stageOutputs_executeGet3_state_isVirtual = stages_executeGet3_state_isVirtual;
  assign io_stageOutputs_executeGet3_state_isDefect = stages_executeGet3_state_isDefect;
  assign io_stageOutputs_executeGet3_state_grown = stages_executeGet3_state_grown;
  assign io_stageOutputs_executeGet3_isStalled = stages_executeGet3_isStalled;
  assign io_stageOutputs_executeGet3_compact_valid = stages_executeGet3_compact_valid;
  assign io_stageOutputs_executeGet3_compact_isReset = stages_executeGet3_compact_isReset;
  assign io_stageOutputs_updateGet_state_speed = stages_updateGet_state_speed;
  assign io_stageOutputs_updateGet_state_node = stages_updateGet_state_node;
  assign io_stageOutputs_updateGet_state_root = stages_updateGet_state_root;
  assign io_stageOutputs_updateGet_state_isVirtual = stages_updateGet_state_isVirtual;
  assign io_stageOutputs_updateGet_state_isDefect = stages_updateGet_state_isDefect;
  assign io_stageOutputs_updateGet_state_grown = stages_updateGet_state_grown;
  assign io_stageOutputs_updateGet_isStalled = stages_updateGet_isStalled;
  assign io_stageOutputs_updateGet_compact_valid = stages_updateGet_compact_valid;
  assign io_stageOutputs_updateGet_compact_isReset = stages_updateGet_compact_isReset;
  assign io_stageOutputs_updateGet_propagatingPeer_valid = stages_updateGet_propagatingPeer_valid;
  assign io_stageOutputs_updateGet_propagatingPeer_node = stages_updateGet_propagatingPeer_node;
  assign io_stageOutputs_updateGet_propagatingPeer_root = stages_updateGet_propagatingPeer_root;
  assign io_stageOutputs_updateGet2_state_speed = stages_updateGet2_state_speed;
  assign io_stageOutputs_updateGet2_state_node = stages_updateGet2_state_node;
  assign io_stageOutputs_updateGet2_state_root = stages_updateGet2_state_root;
  assign io_stageOutputs_updateGet2_state_isVirtual = stages_updateGet2_state_isVirtual;
  assign io_stageOutputs_updateGet2_state_isDefect = stages_updateGet2_state_isDefect;
  assign io_stageOutputs_updateGet2_state_grown = stages_updateGet2_state_grown;
  assign io_stageOutputs_updateGet2_isStalled = stages_updateGet2_isStalled;
  assign io_stageOutputs_updateGet2_compact_valid = stages_updateGet2_compact_valid;
  assign io_stageOutputs_updateGet2_compact_isReset = stages_updateGet2_compact_isReset;
  assign io_stageOutputs_updateGet2_propagatingPeer_valid = stages_updateGet2_propagatingPeer_valid;
  assign io_stageOutputs_updateGet2_propagatingPeer_node = stages_updateGet2_propagatingPeer_node;
  assign io_stageOutputs_updateGet2_propagatingPeer_root = stages_updateGet2_propagatingPeer_root;
  assign io_stageOutputs_updateGet3_state_speed = stages_updateGet3_state_speed;
  assign io_stageOutputs_updateGet3_state_node = stages_updateGet3_state_node;
  assign io_stageOutputs_updateGet3_state_root = stages_updateGet3_state_root;
  assign io_stageOutputs_updateGet3_state_isVirtual = stages_updateGet3_state_isVirtual;
  assign io_stageOutputs_updateGet3_state_isDefect = stages_updateGet3_state_isDefect;
  assign io_stageOutputs_updateGet3_state_grown = stages_updateGet3_state_grown;
  assign io_stageOutputs_updateGet3_shadow_speed = stages_updateGet3_shadow_speed;
  assign io_stageOutputs_updateGet3_shadow_node = stages_updateGet3_shadow_node;
  assign io_stageOutputs_updateGet3_shadow_root = stages_updateGet3_shadow_root;
  assign io_stageOutputs_updateGet3_compact_valid = stages_updateGet3_compact_valid;
  assign io_stageOutputs_updateGet3_compact_isReset = stages_updateGet3_compact_isReset;
  assign fetchState_speed = register_speed;
  assign fetchState_node = register_node;
  assign fetchState_root = register_root;
  assign fetchState_isVirtual = register_isVirtual;
  assign fetchState_isDefect = register_isDefect;
  assign fetchState_grown = register_grown;
  assign message_valid = io_message_valid;
  assign message_instruction = io_message_instruction;
  assign message_isReset = io_message_isReset;
  assign stages_offloadSet_message_valid = message_valid;
  assign stages_offloadSet_message_instruction = message_instruction;
  assign stages_offloadSet_message_isReset = message_isReset;
  assign stages_offloadSet_state_speed = (message_isReset ? 2'b00 : fetchState_speed);
  assign stages_offloadSet_state_node = (message_isReset ? 5'h1f : fetchState_node);
  assign stages_offloadSet_state_root = (message_isReset ? 5'h1f : fetchState_root);
  assign stages_offloadSet_state_isVirtual = (message_isReset ? 1'b0 : fetchState_isVirtual);
  assign stages_offloadSet_state_isDefect = (message_isReset ? 1'b0 : fetchState_isDefect);
  assign stages_offloadSet_state_grown = (message_isReset ? 2'b00 : fetchState_grown);
  assign stages_offloadSet2_state_speed = stages_offloadGet_state_speed;
  assign stages_offloadSet2_state_node = stages_offloadGet_state_node;
  assign stages_offloadSet2_state_root = stages_offloadGet_state_root;
  assign stages_offloadSet2_state_isVirtual = stages_offloadGet_state_isVirtual;
  assign stages_offloadSet2_state_isDefect = stages_offloadGet_state_isDefect;
  assign stages_offloadSet2_state_grown = stages_offloadGet_state_grown;
  assign stages_offloadSet2_message_valid = stages_offloadGet_message_valid;
  assign stages_offloadSet2_message_instruction = stages_offloadGet_message_instruction;
  assign stages_offloadSet2_message_isReset = stages_offloadGet_message_isReset;
  assign stages_offloadSet3_state_speed = stages_offloadGet2_state_speed;
  assign stages_offloadSet3_state_node = stages_offloadGet2_state_node;
  assign stages_offloadSet3_state_root = stages_offloadGet2_state_root;
  assign stages_offloadSet3_state_isVirtual = stages_offloadGet2_state_isVirtual;
  assign stages_offloadSet3_state_isDefect = stages_offloadGet2_state_isDefect;
  assign stages_offloadSet3_state_grown = stages_offloadGet2_state_grown;
  assign stages_offloadSet3_message_valid = stages_offloadGet2_message_valid;
  assign stages_offloadSet3_message_instruction = stages_offloadGet2_message_instruction;
  assign stages_offloadSet3_message_isReset = stages_offloadGet2_message_isReset;
  assign stages_offloadSet3_isUniqueTight = offload3Area_tightCounter_io_isUnique;
  assign stages_offloadSet3_isIsolated = offload3Area_tightCounter_io_isIsolated;
  assign stages_offloadSet4_state_speed = stages_offloadGet3_state_speed;
  assign stages_offloadSet4_state_node = stages_offloadGet3_state_node;
  assign stages_offloadSet4_state_root = stages_offloadGet3_state_root;
  assign stages_offloadSet4_state_isVirtual = stages_offloadGet3_state_isVirtual;
  assign stages_offloadSet4_state_isDefect = stages_offloadGet3_state_isDefect;
  assign stages_offloadSet4_state_grown = stages_offloadGet3_state_grown;
  assign stages_offloadSet4_message_valid = stages_offloadGet3_message_valid;
  assign stages_offloadSet4_message_instruction = stages_offloadGet3_message_instruction;
  assign stages_offloadSet4_message_isReset = stages_offloadGet3_message_isReset;
  assign stages_executeSet_state_speed = stages_offloadGet4_state_speed;
  assign stages_executeSet_state_node = stages_offloadGet4_state_node;
  assign stages_executeSet_state_root = stages_offloadGet4_state_root;
  assign stages_executeSet_state_isVirtual = stages_offloadGet4_state_isVirtual;
  assign stages_executeSet_state_isDefect = stages_offloadGet4_state_isDefect;
  assign stages_executeSet_state_grown = stages_offloadGet4_state_grown;
  assign stages_executeSet_message_valid = stages_offloadGet4_message_valid;
  assign stages_executeSet_message_instruction = stages_offloadGet4_message_instruction;
  assign stages_executeSet_message_isReset = stages_offloadGet4_message_isReset;
  assign stages_executeSet_isStalled = executeArea_offloadStalled_io_isStalled;
  assign stages_executeSet2_isStalled = stages_executeGet_isStalled;
  assign stages_executeSet2_compact_valid = stages_executeGet_message_valid;
  assign stages_executeSet2_compact_isReset = stages_executeGet_message_isReset;
  assign stages_executeSet2_state_speed = execute2Area_vertexPostExecuteState_io_after_speed;
  assign stages_executeSet2_state_node = execute2Area_vertexPostExecuteState_io_after_node;
  assign stages_executeSet2_state_root = execute2Area_vertexPostExecuteState_io_after_root;
  assign stages_executeSet2_state_isVirtual = execute2Area_vertexPostExecuteState_io_after_isVirtual;
  assign stages_executeSet2_state_isDefect = execute2Area_vertexPostExecuteState_io_after_isDefect;
  assign stages_executeSet2_state_grown = execute2Area_vertexPostExecuteState_io_after_grown;
  assign stages_executeSet3_state_speed = stages_executeGet2_state_speed;
  assign stages_executeSet3_state_node = stages_executeGet2_state_node;
  assign stages_executeSet3_state_root = stages_executeGet2_state_root;
  assign stages_executeSet3_state_isVirtual = stages_executeGet2_state_isVirtual;
  assign stages_executeSet3_state_isDefect = stages_executeGet2_state_isDefect;
  assign stages_executeSet3_state_grown = stages_executeGet2_state_grown;
  assign stages_executeSet3_isStalled = stages_executeGet2_isStalled;
  assign stages_executeSet3_compact_valid = stages_executeGet2_compact_valid;
  assign stages_executeSet3_compact_isReset = stages_executeGet2_compact_isReset;
  assign stages_updateSet_state_speed = stages_executeGet3_state_speed;
  assign stages_updateSet_state_node = stages_executeGet3_state_node;
  assign stages_updateSet_state_root = stages_executeGet3_state_root;
  assign stages_updateSet_state_isVirtual = stages_executeGet3_state_isVirtual;
  assign stages_updateSet_state_isDefect = stages_executeGet3_state_isDefect;
  assign stages_updateSet_state_grown = stages_executeGet3_state_grown;
  assign stages_updateSet_isStalled = stages_executeGet3_isStalled;
  assign stages_updateSet_compact_valid = stages_executeGet3_compact_valid;
  assign stages_updateSet_compact_isReset = stages_executeGet3_compact_isReset;
  assign stages_updateSet_propagatingPeer_valid = updateArea_vertexPropagatingPeer_io_peer_valid;
  assign stages_updateSet_propagatingPeer_node = updateArea_vertexPropagatingPeer_io_peer_node;
  assign stages_updateSet_propagatingPeer_root = updateArea_vertexPropagatingPeer_io_peer_root;
  assign stages_updateSet2_compact_valid = stages_updateGet_compact_valid;
  assign stages_updateSet2_compact_isReset = stages_updateGet_compact_isReset;
  assign stages_updateSet2_isStalled = stages_updateGet_isStalled;
  assign stages_updateSet2_propagatingPeer_valid = stages_updateGet_propagatingPeer_valid;
  assign stages_updateSet2_propagatingPeer_node = stages_updateGet_propagatingPeer_node;
  assign stages_updateSet2_propagatingPeer_root = stages_updateGet_propagatingPeer_root;
  assign stages_updateSet2_state_speed = update2Area_vertexPostUpdateState_io_after_speed;
  assign stages_updateSet2_state_node = update2Area_vertexPostUpdateState_io_after_node;
  assign stages_updateSet2_state_root = update2Area_vertexPostUpdateState_io_after_root;
  assign stages_updateSet2_state_isVirtual = update2Area_vertexPostUpdateState_io_after_isVirtual;
  assign stages_updateSet2_state_isDefect = update2Area_vertexPostUpdateState_io_after_isDefect;
  assign stages_updateSet2_state_grown = update2Area_vertexPostUpdateState_io_after_grown;
  assign stages_updateSet3_state_speed = stages_updateGet2_state_speed;
  assign stages_updateSet3_state_node = stages_updateGet2_state_node;
  assign stages_updateSet3_state_root = stages_updateGet2_state_root;
  assign stages_updateSet3_state_isVirtual = stages_updateGet2_state_isVirtual;
  assign stages_updateSet3_state_isDefect = stages_updateGet2_state_isDefect;
  assign stages_updateSet3_state_grown = stages_updateGet2_state_grown;
  assign stages_updateSet3_compact_valid = stages_updateGet2_compact_valid;
  assign stages_updateSet3_compact_isReset = stages_updateGet2_compact_isReset;
  assign stages_updateSet3_shadow_speed = update3Area_vertexShadow_io_shadow_speed;
  assign stages_updateSet3_shadow_node = update3Area_vertexShadow_io_shadow_node;
  assign stages_updateSet3_shadow_root = update3Area_vertexShadow_io_shadow_root;
  assign io_maxGrowable_length = vertexResponse_4_io_maxGrowable_length;
  assign stages_executeGet3_state_speed = stages_executeSet3_state_speed;
  assign stages_executeGet3_state_node = stages_executeSet3_state_node;
  assign stages_executeGet3_state_root = stages_executeSet3_state_root;
  assign stages_executeGet3_state_isVirtual = stages_executeSet3_state_isVirtual;
  assign stages_executeGet3_state_isDefect = stages_executeSet3_state_isDefect;
  assign stages_executeGet3_state_grown = stages_executeSet3_state_grown;
  assign stages_executeGet3_isStalled = stages_executeSet3_isStalled;
  assign stages_executeGet3_compact_valid = stages_executeSet3_compact_valid;
  assign stages_executeGet3_compact_isReset = stages_executeSet3_compact_isReset;
  assign stages_updateGet_state_speed = stages_updateSet_state_speed;
  assign stages_updateGet_state_node = stages_updateSet_state_node;
  assign stages_updateGet_state_root = stages_updateSet_state_root;
  assign stages_updateGet_state_isVirtual = stages_updateSet_state_isVirtual;
  assign stages_updateGet_state_isDefect = stages_updateSet_state_isDefect;
  assign stages_updateGet_state_grown = stages_updateSet_state_grown;
  assign stages_updateGet_isStalled = stages_updateSet_isStalled;
  assign stages_updateGet_compact_valid = stages_updateSet_compact_valid;
  assign stages_updateGet_compact_isReset = stages_updateSet_compact_isReset;
  assign stages_updateGet_propagatingPeer_valid = stages_updateSet_propagatingPeer_valid;
  assign stages_updateGet_propagatingPeer_node = stages_updateSet_propagatingPeer_node;
  assign stages_updateGet_propagatingPeer_root = stages_updateSet_propagatingPeer_root;
  assign stages_offloadGet_state_speed = stages_offloadSet_state_speed;
  assign stages_offloadGet_state_node = stages_offloadSet_state_node;
  assign stages_offloadGet_state_root = stages_offloadSet_state_root;
  assign stages_offloadGet_state_isVirtual = stages_offloadSet_state_isVirtual;
  assign stages_offloadGet_state_isDefect = stages_offloadSet_state_isDefect;
  assign stages_offloadGet_state_grown = stages_offloadSet_state_grown;
  assign stages_offloadGet_message_valid = stages_offloadSet_message_valid;
  assign stages_offloadGet_message_instruction = stages_offloadSet_message_instruction;
  assign stages_offloadGet_message_isReset = stages_offloadSet_message_isReset;
  assign stages_offloadGet4_state_speed = stages_offloadSet4_state_speed;
  assign stages_offloadGet4_state_node = stages_offloadSet4_state_node;
  assign stages_offloadGet4_state_root = stages_offloadSet4_state_root;
  assign stages_offloadGet4_state_isVirtual = stages_offloadSet4_state_isVirtual;
  assign stages_offloadGet4_state_isDefect = stages_offloadSet4_state_isDefect;
  assign stages_offloadGet4_state_grown = stages_offloadSet4_state_grown;
  assign stages_offloadGet4_message_valid = stages_offloadSet4_message_valid;
  assign stages_offloadGet4_message_instruction = stages_offloadSet4_message_instruction;
  assign stages_offloadGet4_message_isReset = stages_offloadSet4_message_isReset;
  assign stages_updateGet3_state_speed = stages_updateSet3_state_speed;
  assign stages_updateGet3_state_node = stages_updateSet3_state_node;
  assign stages_updateGet3_state_root = stages_updateSet3_state_root;
  assign stages_updateGet3_state_isVirtual = stages_updateSet3_state_isVirtual;
  assign stages_updateGet3_state_isDefect = stages_updateSet3_state_isDefect;
  assign stages_updateGet3_state_grown = stages_updateSet3_state_grown;
  assign stages_updateGet3_shadow_speed = stages_updateSet3_shadow_speed;
  assign stages_updateGet3_shadow_node = stages_updateSet3_shadow_node;
  assign stages_updateGet3_shadow_root = stages_updateSet3_shadow_root;
  assign stages_updateGet3_compact_valid = stages_updateSet3_compact_valid;
  assign stages_updateGet3_compact_isReset = stages_updateSet3_compact_isReset;
  assign stages_executeGet_state_speed = stages_executeSet_state_speed;
  assign stages_executeGet_state_node = stages_executeSet_state_node;
  assign stages_executeGet_state_root = stages_executeSet_state_root;
  assign stages_executeGet_state_isVirtual = stages_executeSet_state_isVirtual;
  assign stages_executeGet_state_isDefect = stages_executeSet_state_isDefect;
  assign stages_executeGet_state_grown = stages_executeSet_state_grown;
  assign stages_executeGet_message_valid = stages_executeSet_message_valid;
  assign stages_executeGet_message_instruction = stages_executeSet_message_instruction;
  assign stages_executeGet_message_isReset = stages_executeSet_message_isReset;
  assign stages_executeGet_isStalled = stages_executeSet_isStalled;
  assign stages_executeGet2_state_speed = stages_executeSet2_state_speed;
  assign stages_executeGet2_state_node = stages_executeSet2_state_node;
  assign stages_executeGet2_state_root = stages_executeSet2_state_root;
  assign stages_executeGet2_state_isVirtual = stages_executeSet2_state_isVirtual;
  assign stages_executeGet2_state_isDefect = stages_executeSet2_state_isDefect;
  assign stages_executeGet2_state_grown = stages_executeSet2_state_grown;
  assign stages_executeGet2_isStalled = stages_executeSet2_isStalled;
  assign stages_executeGet2_compact_valid = stages_executeSet2_compact_valid;
  assign stages_executeGet2_compact_isReset = stages_executeSet2_compact_isReset;
  assign stages_offloadGet3_state_speed = stages_offloadSet3_state_speed;
  assign stages_offloadGet3_state_node = stages_offloadSet3_state_node;
  assign stages_offloadGet3_state_root = stages_offloadSet3_state_root;
  assign stages_offloadGet3_state_isVirtual = stages_offloadSet3_state_isVirtual;
  assign stages_offloadGet3_state_isDefect = stages_offloadSet3_state_isDefect;
  assign stages_offloadGet3_state_grown = stages_offloadSet3_state_grown;
  assign stages_offloadGet3_message_valid = stages_offloadSet3_message_valid;
  assign stages_offloadGet3_message_instruction = stages_offloadSet3_message_instruction;
  assign stages_offloadGet3_message_isReset = stages_offloadSet3_message_isReset;
  assign stages_offloadGet3_isUniqueTight = stages_offloadSet3_isUniqueTight;
  assign stages_offloadGet3_isIsolated = stages_offloadSet3_isIsolated;
  assign stages_updateGet2_state_speed = stages_updateSet2_state_speed;
  assign stages_updateGet2_state_node = stages_updateSet2_state_node;
  assign stages_updateGet2_state_root = stages_updateSet2_state_root;
  assign stages_updateGet2_state_isVirtual = stages_updateSet2_state_isVirtual;
  assign stages_updateGet2_state_isDefect = stages_updateSet2_state_isDefect;
  assign stages_updateGet2_state_grown = stages_updateSet2_state_grown;
  assign stages_updateGet2_isStalled = stages_updateSet2_isStalled;
  assign stages_updateGet2_compact_valid = stages_updateSet2_compact_valid;
  assign stages_updateGet2_compact_isReset = stages_updateSet2_compact_isReset;
  assign stages_updateGet2_propagatingPeer_valid = stages_updateSet2_propagatingPeer_valid;
  assign stages_updateGet2_propagatingPeer_node = stages_updateSet2_propagatingPeer_node;
  assign stages_updateGet2_propagatingPeer_root = stages_updateSet2_propagatingPeer_root;
  assign stages_offloadGet2_state_speed = stages_offloadSet2_state_speed;
  assign stages_offloadGet2_state_node = stages_offloadSet2_state_node;
  assign stages_offloadGet2_state_root = stages_offloadSet2_state_root;
  assign stages_offloadGet2_state_isVirtual = stages_offloadSet2_state_isVirtual;
  assign stages_offloadGet2_state_isDefect = stages_offloadSet2_state_isDefect;
  assign stages_offloadGet2_state_grown = stages_offloadSet2_state_grown;
  assign stages_offloadGet2_message_valid = stages_offloadSet2_message_valid;
  assign stages_offloadGet2_message_instruction = stages_offloadSet2_message_instruction;
  assign stages_offloadGet2_message_isReset = stages_offloadSet2_message_isReset;
  always @(posedge clk or posedge reset) begin
    if(reset) begin
      register_speed <= 2'b00;
      register_node <= 5'h1f;
      register_root <= 5'h1f;
      register_isVirtual <= 1'b0;
      register_isDefect <= 1'b0;
      register_grown <= 2'b00;
    end else begin
      if(stages_updateGet3_compact_valid) begin
        register_speed <= stages_updateGet3_state_speed;
        register_node <= stages_updateGet3_state_node;
        register_root <= stages_updateGet3_state_root;
        register_isVirtual <= stages_updateGet3_state_isVirtual;
        register_isDefect <= stages_updateGet3_state_isDefect;
        register_grown <= stages_updateGet3_state_grown;
      end
    end
  end


endmodule

//EdgeResponse replaced by EdgeResponse_2

//EdgeRemaining replaced by EdgeRemaining_2

//EdgeIsTight_1 replaced by EdgeIsTight_4

//EdgeIsTight replaced by EdgeIsTight_4

//EdgeResponse_1 replaced by EdgeResponse_2

//EdgeRemaining_1 replaced by EdgeRemaining_2

//EdgeIsTight_3 replaced by EdgeIsTight_4

//EdgeIsTight_2 replaced by EdgeIsTight_4

module EdgeResponse_2 (
  input      [1:0]    io_leftShadow_speed,
  input      [4:0]    io_leftShadow_node,
  input      [4:0]    io_leftShadow_root,
  input      [1:0]    io_rightShadow_speed,
  input      [4:0]    io_rightShadow_node,
  input      [4:0]    io_rightShadow_root,
  input               io_leftIsVirtual,
  input               io_rightIsVirtual,
  input      [4:0]    io_leftVertex,
  input      [4:0]    io_rightVertex,
  input      [1:0]    io_remaining,
  output reg [1:0]    io_maxGrowable_length,
  output     [4:0]    io_conflict_node1,
  output     [4:0]    io_conflict_node2,
  output     [4:0]    io_conflict_touch1,
  output     [4:0]    io_conflict_touch2,
  output     [4:0]    io_conflict_vertex1,
  output     [4:0]    io_conflict_vertex2,
  output reg          io_conflict_valid
);

  wire                when_EdgeResponse_l48;
  wire                when_EdgeResponse_l44;
  wire                when_EdgeResponse_l43;
  wire                when_EdgeResponse_l45;

  assign when_EdgeResponse_l48 = ((io_leftShadow_speed == 2'b01) && (io_rightShadow_speed == 2'b01));
  assign when_EdgeResponse_l44 = ((when_EdgeResponse_l48 || ((io_leftShadow_speed == 2'b01) && (io_rightShadow_speed == 2'b00))) || ((io_leftShadow_speed == 2'b00) && (io_rightShadow_speed == 2'b01)));
  always @(*) begin
    io_maxGrowable_length = 2'b11;
    if(when_EdgeResponse_l43) begin
      if(when_EdgeResponse_l44) begin
        if(when_EdgeResponse_l48) begin
          io_maxGrowable_length = (io_remaining >>> 1);
        end else begin
          io_maxGrowable_length = io_remaining;
        end
      end
    end
  end

  always @(*) begin
    io_conflict_valid = 1'b0;
    if(when_EdgeResponse_l43) begin
      if(when_EdgeResponse_l44) begin
        if(when_EdgeResponse_l45) begin
          io_conflict_valid = 1'b1;
        end
      end
    end
  end

  assign io_conflict_node1 = io_leftShadow_node;
  assign io_conflict_node2 = io_rightShadow_node;
  assign io_conflict_touch1 = io_leftShadow_root;
  assign io_conflict_touch2 = io_rightShadow_root;
  assign io_conflict_vertex1 = io_leftVertex;
  assign io_conflict_vertex2 = io_rightVertex;
  assign when_EdgeResponse_l43 = (io_leftShadow_node != io_rightShadow_node);
  assign when_EdgeResponse_l45 = (((io_remaining == 2'b00) && (! ((io_leftShadow_node == 5'h1f) && (! io_leftIsVirtual)))) && (! ((io_rightShadow_node == 5'h1f) && (! io_rightIsVirtual))));

endmodule

module EdgeRemaining_2 (
  input      [1:0]    io_leftGrown,
  input      [1:0]    io_rightGrown,
  input      [1:0]    io_weight,
  output reg [1:0]    io_remaining
);

  wire       [2:0]    _zz__zz_io_remaining;
  wire       [1:0]    _zz__zz_io_remaining_1;
  wire       [2:0]    _zz__zz_io_remaining_2;
  wire       [1:0]    _zz__zz_io_remaining_3;
  wire       [2:0]    _zz_when_EdgeRemaining_l39;
  wire       [1:0]    _zz_io_remaining_1;
  wire       [2:0]    _zz_io_remaining;
  wire                when_EdgeRemaining_l39;

  assign _zz__zz_io_remaining_1 = io_leftGrown;
  assign _zz__zz_io_remaining = {1'd0, _zz__zz_io_remaining_1};
  assign _zz__zz_io_remaining_3 = io_rightGrown;
  assign _zz__zz_io_remaining_2 = {1'd0, _zz__zz_io_remaining_3};
  assign _zz_when_EdgeRemaining_l39 = {1'd0, io_weight};
  assign _zz_io_remaining_1 = _zz_io_remaining[1:0];
  assign _zz_io_remaining = (_zz__zz_io_remaining + _zz__zz_io_remaining_2);
  always @(*) begin
    io_remaining = 2'b00;
    if(when_EdgeRemaining_l39) begin
      io_remaining = (io_weight - _zz_io_remaining_1);
    end
  end

  assign when_EdgeRemaining_l39 = ((! (1'b0 || 1'b0)) && (_zz_io_remaining <= _zz_when_EdgeRemaining_l39));

endmodule

//EdgeIsTight_5 replaced by EdgeIsTight_4

module EdgeIsTight_4 (
  input      [1:0]    io_leftGrown,
  input      [1:0]    io_rightGrown,
  input      [1:0]    io_weight,
  output              io_isTight
);

  wire       [2:0]    _zz_io_isTight;
  wire       [2:0]    _zz_io_isTight_1;
  wire       [2:0]    _zz_io_isTight_2;
  wire       [1:0]    _zz_io_isTight_3;
  wire       [2:0]    _zz_io_isTight_4;
  wire       [1:0]    _zz_io_isTight_5;

  assign _zz_io_isTight = {1'd0, io_weight};
  assign _zz_io_isTight_1 = (_zz_io_isTight_2 + _zz_io_isTight_4);
  assign _zz_io_isTight_3 = io_leftGrown;
  assign _zz_io_isTight_2 = {1'd0, _zz_io_isTight_3};
  assign _zz_io_isTight_5 = io_rightGrown;
  assign _zz_io_isTight_4 = {1'd0, _zz_io_isTight_5};
  assign io_isTight = ((_zz_io_isTight <= _zz_io_isTight_1) || (1'b0 || 1'b0));

endmodule

//VertexResponse replaced by VertexResponse_3

//VertexShadow replaced by VertexShadow_3

//VertexPostUpdateState replaced by VertexPostUpdateState_3

//VertexPropagatingPeer replaced by VertexPropagatingPeer_1

module VertexPostExecuteState (
  input      [1:0]    io_before_speed,
  input      [4:0]    io_before_node,
  input      [4:0]    io_before_root,
  input               io_before_isVirtual,
  input               io_before_isDefect,
  input      [1:0]    io_before_grown,
  input               io_message_valid,
  input      [11:0]   io_message_instruction,
  input               io_message_isReset,
  input               io_isStalled,
  output     [1:0]    io_after_speed,
  output     [4:0]    io_after_node,
  output     [4:0]    io_after_root,
  output              io_after_isVirtual,
  output              io_after_isDefect,
  output     [1:0]    io_after_grown,
  input               clk,
  input               reset
);

  wire                common_io_isVertexEqField1;
  wire       [1:0]    common_io_after_speed;
  wire       [4:0]    common_io_after_node;
  wire       [4:0]    common_io_after_root;
  wire                common_io_after_isVirtual;
  wire                common_io_after_isDefect;
  wire       [1:0]    common_io_after_grown;

  VertexPostExecuteStateCommon_3 common (
    .io_before_speed        (io_before_speed[1:0]        ), //i
    .io_before_node         (io_before_node[4:0]         ), //i
    .io_before_root         (io_before_root[4:0]         ), //i
    .io_before_isVirtual    (io_before_isVirtual         ), //i
    .io_before_isDefect     (io_before_isDefect          ), //i
    .io_before_grown        (io_before_grown[1:0]        ), //i
    .io_message_valid       (io_message_valid            ), //i
    .io_message_instruction (io_message_instruction[11:0]), //i
    .io_message_isReset     (io_message_isReset          ), //i
    .io_isVertexEqField1    (common_io_isVertexEqField1  ), //i
    .io_isLayerIdEqField1   (1'b0                        ), //i
    .io_isStalled           (io_isStalled                ), //i
    .io_after_speed         (common_io_after_speed[1:0]  ), //o
    .io_after_node          (common_io_after_node[4:0]   ), //o
    .io_after_root          (common_io_after_root[4:0]   ), //o
    .io_after_isVirtual     (common_io_after_isVirtual   ), //o
    .io_after_isDefect      (common_io_after_isDefect    ), //o
    .io_after_grown         (common_io_after_grown[1:0]  ), //o
    .clk                    (clk                         ), //i
    .reset                  (reset                       )  //i
  );
  assign common_io_isVertexEqField1 = (io_message_instruction[11 : 7] == 5'h03);
  assign io_after_speed = common_io_after_speed;
  assign io_after_node = common_io_after_node;
  assign io_after_root = common_io_after_root;
  assign io_after_isVirtual = common_io_after_isVirtual;
  assign io_after_isDefect = common_io_after_isDefect;
  assign io_after_grown = common_io_after_grown;

endmodule

//OffloadStalled replaced by OffloadStalled_3

//VertexTightCounter replaced by VertexTightCounter_1

//VertexResponse_1 replaced by VertexResponse_3

//VertexShadow_1 replaced by VertexShadow_3

//VertexPostUpdateState_1 replaced by VertexPostUpdateState_3

module VertexPropagatingPeer_1 (
  input      [1:0]    io_grown,
  input               io_edgeIsTight_0,
  input      [1:0]    io_peerSpeed_0,
  input      [4:0]    io_peerNode_0,
  input      [4:0]    io_peerRoot_0,
  output              io_peer_valid,
  output     [4:0]    io_peer_node,
  output     [4:0]    io_peer_root
);


  assign io_peer_valid = ((io_grown == 2'b00) && (io_edgeIsTight_0 && (io_peerSpeed_0 == 2'b01)));
  assign io_peer_node = io_peerNode_0;
  assign io_peer_root = io_peerRoot_0;

endmodule

module VertexPostExecuteState_1 (
  input      [1:0]    io_before_speed,
  input      [4:0]    io_before_node,
  input      [4:0]    io_before_root,
  input               io_before_isVirtual,
  input               io_before_isDefect,
  input      [1:0]    io_before_grown,
  input               io_message_valid,
  input      [11:0]   io_message_instruction,
  input               io_message_isReset,
  input               io_isStalled,
  output     [1:0]    io_after_speed,
  output     [4:0]    io_after_node,
  output     [4:0]    io_after_root,
  output              io_after_isVirtual,
  output              io_after_isDefect,
  output     [1:0]    io_after_grown,
  input               clk,
  input               reset
);

  wire                common_io_isVertexEqField1;
  wire       [1:0]    common_io_after_speed;
  wire       [4:0]    common_io_after_node;
  wire       [4:0]    common_io_after_root;
  wire                common_io_after_isVirtual;
  wire                common_io_after_isDefect;
  wire       [1:0]    common_io_after_grown;

  VertexPostExecuteStateCommon_3 common (
    .io_before_speed        (io_before_speed[1:0]        ), //i
    .io_before_node         (io_before_node[4:0]         ), //i
    .io_before_root         (io_before_root[4:0]         ), //i
    .io_before_isVirtual    (io_before_isVirtual         ), //i
    .io_before_isDefect     (io_before_isDefect          ), //i
    .io_before_grown        (io_before_grown[1:0]        ), //i
    .io_message_valid       (io_message_valid            ), //i
    .io_message_instruction (io_message_instruction[11:0]), //i
    .io_message_isReset     (io_message_isReset          ), //i
    .io_isVertexEqField1    (common_io_isVertexEqField1  ), //i
    .io_isLayerIdEqField1   (1'b0                        ), //i
    .io_isStalled           (io_isStalled                ), //i
    .io_after_speed         (common_io_after_speed[1:0]  ), //o
    .io_after_node          (common_io_after_node[4:0]   ), //o
    .io_after_root          (common_io_after_root[4:0]   ), //o
    .io_after_isVirtual     (common_io_after_isVirtual   ), //o
    .io_after_isDefect      (common_io_after_isDefect    ), //o
    .io_after_grown         (common_io_after_grown[1:0]  ), //o
    .clk                    (clk                         ), //i
    .reset                  (reset                       )  //i
  );
  assign common_io_isVertexEqField1 = (io_message_instruction[11 : 7] == 5'h02);
  assign io_after_speed = common_io_after_speed;
  assign io_after_node = common_io_after_node;
  assign io_after_root = common_io_after_root;
  assign io_after_isVirtual = common_io_after_isVirtual;
  assign io_after_isDefect = common_io_after_isDefect;
  assign io_after_grown = common_io_after_grown;

endmodule

//OffloadStalled_1 replaced by OffloadStalled_3

module VertexTightCounter_1 (
  input               io_tights_0,
  output              io_isUnique,
  output              io_isIsolated
);


  assign io_isUnique = (io_tights_0 && 1'b1);
  assign io_isIsolated = (! io_tights_0);

endmodule

//VertexResponse_2 replaced by VertexResponse_3

//VertexShadow_2 replaced by VertexShadow_3

//VertexPostUpdateState_2 replaced by VertexPostUpdateState_3

//VertexPropagatingPeer_2 replaced by VertexPropagatingPeer_3

module VertexPostExecuteState_2 (
  input      [1:0]    io_before_speed,
  input      [4:0]    io_before_node,
  input      [4:0]    io_before_root,
  input               io_before_isVirtual,
  input               io_before_isDefect,
  input      [1:0]    io_before_grown,
  input               io_message_valid,
  input      [11:0]   io_message_instruction,
  input               io_message_isReset,
  input               io_isStalled,
  output     [1:0]    io_after_speed,
  output     [4:0]    io_after_node,
  output     [4:0]    io_after_root,
  output              io_after_isVirtual,
  output              io_after_isDefect,
  output     [1:0]    io_after_grown,
  input               clk,
  input               reset
);

  wire                common_io_isVertexEqField1;
  wire       [1:0]    common_io_after_speed;
  wire       [4:0]    common_io_after_node;
  wire       [4:0]    common_io_after_root;
  wire                common_io_after_isVirtual;
  wire                common_io_after_isDefect;
  wire       [1:0]    common_io_after_grown;

  VertexPostExecuteStateCommon_3 common (
    .io_before_speed        (io_before_speed[1:0]        ), //i
    .io_before_node         (io_before_node[4:0]         ), //i
    .io_before_root         (io_before_root[4:0]         ), //i
    .io_before_isVirtual    (io_before_isVirtual         ), //i
    .io_before_isDefect     (io_before_isDefect          ), //i
    .io_before_grown        (io_before_grown[1:0]        ), //i
    .io_message_valid       (io_message_valid            ), //i
    .io_message_instruction (io_message_instruction[11:0]), //i
    .io_message_isReset     (io_message_isReset          ), //i
    .io_isVertexEqField1    (common_io_isVertexEqField1  ), //i
    .io_isLayerIdEqField1   (1'b0                        ), //i
    .io_isStalled           (io_isStalled                ), //i
    .io_after_speed         (common_io_after_speed[1:0]  ), //o
    .io_after_node          (common_io_after_node[4:0]   ), //o
    .io_after_root          (common_io_after_root[4:0]   ), //o
    .io_after_isVirtual     (common_io_after_isVirtual   ), //o
    .io_after_isDefect      (common_io_after_isDefect    ), //o
    .io_after_grown         (common_io_after_grown[1:0]  ), //o
    .clk                    (clk                         ), //i
    .reset                  (reset                       )  //i
  );
  assign common_io_isVertexEqField1 = (io_message_instruction[11 : 7] == 5'h01);
  assign io_after_speed = common_io_after_speed;
  assign io_after_node = common_io_after_node;
  assign io_after_root = common_io_after_root;
  assign io_after_isVirtual = common_io_after_isVirtual;
  assign io_after_isDefect = common_io_after_isDefect;
  assign io_after_grown = common_io_after_grown;

endmodule

//OffloadStalled_2 replaced by OffloadStalled_3

//VertexTightCounter_2 replaced by VertexTightCounter_3

module VertexResponse_3 (
  input      [1:0]    io_state_speed,
  input      [4:0]    io_state_node,
  input      [4:0]    io_state_root,
  input               io_state_isVirtual,
  input               io_state_isDefect,
  input      [1:0]    io_state_grown,
  output reg [1:0]    io_maxGrowable_length
);

  wire                when_VertexResponse_l20;

  always @(*) begin
    io_maxGrowable_length = 2'b11;
    if(when_VertexResponse_l20) begin
      io_maxGrowable_length = io_state_grown;
    end
  end

  assign when_VertexResponse_l20 = (io_state_speed == 2'b10);

endmodule

module VertexShadow_3 (
  input               io_isVirtual,
  input      [4:0]    io_node,
  input      [4:0]    io_root,
  input      [1:0]    io_speed,
  input      [1:0]    io_grown,
  input               io_isStalled,
  input               io_propagator_valid,
  input      [4:0]    io_propagator_node,
  input      [4:0]    io_propagator_root,
  output reg [1:0]    io_shadow_speed,
  output reg [4:0]    io_shadow_node,
  output reg [4:0]    io_shadow_root
);

  wire                when_VertexShadow_l36;

  always @(*) begin
    io_shadow_speed = io_speed;
    if(when_VertexShadow_l36) begin
      if(io_propagator_valid) begin
        io_shadow_speed = 2'b01;
      end
    end
    if(io_isStalled) begin
      io_shadow_speed = 2'b00;
    end
  end

  always @(*) begin
    io_shadow_node = io_node;
    if(when_VertexShadow_l36) begin
      if(io_propagator_valid) begin
        io_shadow_node = io_propagator_node;
      end
    end
  end

  always @(*) begin
    io_shadow_root = io_root;
    if(when_VertexShadow_l36) begin
      if(io_propagator_valid) begin
        io_shadow_root = io_propagator_root;
      end
    end
  end

  assign when_VertexShadow_l36 = ((io_speed == 2'b10) && (io_grown == 2'b00));

endmodule

module VertexPostUpdateState_3 (
  input      [1:0]    io_before_speed,
  input      [4:0]    io_before_node,
  input      [4:0]    io_before_root,
  input               io_before_isVirtual,
  input               io_before_isDefect,
  input      [1:0]    io_before_grown,
  input               io_propagator_valid,
  input      [4:0]    io_propagator_node,
  input      [4:0]    io_propagator_root,
  output reg [1:0]    io_after_speed,
  output reg [4:0]    io_after_node,
  output reg [4:0]    io_after_root,
  output              io_after_isVirtual,
  output              io_after_isDefect,
  output     [1:0]    io_after_grown
);

  wire                when_VertexPostUpdateState_l22;

  always @(*) begin
    io_after_speed = io_before_speed;
    if(when_VertexPostUpdateState_l22) begin
      if(io_propagator_valid) begin
        io_after_speed = 2'b01;
      end else begin
        io_after_speed = 2'b00;
      end
    end
  end

  always @(*) begin
    io_after_node = io_before_node;
    if(when_VertexPostUpdateState_l22) begin
      if(io_propagator_valid) begin
        io_after_node = io_propagator_node;
      end else begin
        io_after_node = 5'h1f;
      end
    end
  end

  always @(*) begin
    io_after_root = io_before_root;
    if(when_VertexPostUpdateState_l22) begin
      if(io_propagator_valid) begin
        io_after_root = io_propagator_root;
      end else begin
        io_after_root = 5'h1f;
      end
    end
  end

  assign io_after_isVirtual = io_before_isVirtual;
  assign io_after_isDefect = io_before_isDefect;
  assign io_after_grown = io_before_grown;
  assign when_VertexPostUpdateState_l22 = (((! io_before_isDefect) && (! io_before_isVirtual)) && (io_before_grown == 2'b00));

endmodule

module VertexPropagatingPeer_3 (
  input      [1:0]    io_grown,
  input               io_edgeIsTight_0,
  input               io_edgeIsTight_1,
  input      [1:0]    io_peerSpeed_0,
  input      [1:0]    io_peerSpeed_1,
  input      [4:0]    io_peerNode_0,
  input      [4:0]    io_peerNode_1,
  input      [4:0]    io_peerRoot_0,
  input      [4:0]    io_peerRoot_1,
  output              io_peer_valid,
  output     [4:0]    io_peer_node,
  output     [4:0]    io_peer_root
);

  wire                _zz_io_peer_valid;

  assign _zz_io_peer_valid = (io_edgeIsTight_0 && (io_peerSpeed_0 == 2'b01));
  assign io_peer_valid = ((io_grown == 2'b00) && (_zz_io_peer_valid ? _zz_io_peer_valid : (io_edgeIsTight_1 && (io_peerSpeed_1 == 2'b01))));
  assign io_peer_node = (_zz_io_peer_valid ? io_peerNode_0 : io_peerNode_1);
  assign io_peer_root = (_zz_io_peer_valid ? io_peerRoot_0 : io_peerRoot_1);

endmodule

module VertexPostExecuteState_3 (
  input      [1:0]    io_before_speed,
  input      [4:0]    io_before_node,
  input      [4:0]    io_before_root,
  input               io_before_isVirtual,
  input               io_before_isDefect,
  input      [1:0]    io_before_grown,
  input               io_message_valid,
  input      [11:0]   io_message_instruction,
  input               io_message_isReset,
  input               io_isStalled,
  output     [1:0]    io_after_speed,
  output     [4:0]    io_after_node,
  output     [4:0]    io_after_root,
  output              io_after_isVirtual,
  output              io_after_isDefect,
  output     [1:0]    io_after_grown,
  input               clk,
  input               reset
);

  wire                common_io_isVertexEqField1;
  wire       [1:0]    common_io_after_speed;
  wire       [4:0]    common_io_after_node;
  wire       [4:0]    common_io_after_root;
  wire                common_io_after_isVirtual;
  wire                common_io_after_isDefect;
  wire       [1:0]    common_io_after_grown;

  VertexPostExecuteStateCommon_3 common (
    .io_before_speed        (io_before_speed[1:0]        ), //i
    .io_before_node         (io_before_node[4:0]         ), //i
    .io_before_root         (io_before_root[4:0]         ), //i
    .io_before_isVirtual    (io_before_isVirtual         ), //i
    .io_before_isDefect     (io_before_isDefect          ), //i
    .io_before_grown        (io_before_grown[1:0]        ), //i
    .io_message_valid       (io_message_valid            ), //i
    .io_message_instruction (io_message_instruction[11:0]), //i
    .io_message_isReset     (io_message_isReset          ), //i
    .io_isVertexEqField1    (common_io_isVertexEqField1  ), //i
    .io_isLayerIdEqField1   (1'b0                        ), //i
    .io_isStalled           (io_isStalled                ), //i
    .io_after_speed         (common_io_after_speed[1:0]  ), //o
    .io_after_node          (common_io_after_node[4:0]   ), //o
    .io_after_root          (common_io_after_root[4:0]   ), //o
    .io_after_isVirtual     (common_io_after_isVirtual   ), //o
    .io_after_isDefect      (common_io_after_isDefect    ), //o
    .io_after_grown         (common_io_after_grown[1:0]  ), //o
    .clk                    (clk                         ), //i
    .reset                  (reset                       )  //i
  );
  assign common_io_isVertexEqField1 = (io_message_instruction[11 : 7] == 5'h00);
  assign io_after_speed = common_io_after_speed;
  assign io_after_node = common_io_after_node;
  assign io_after_root = common_io_after_root;
  assign io_after_isVirtual = common_io_after_isVirtual;
  assign io_after_isDefect = common_io_after_isDefect;
  assign io_after_grown = common_io_after_grown;

endmodule

module OffloadStalled_3 (
  output              io_isStalled
);


  assign io_isStalled = 1'b0;

endmodule

module VertexTightCounter_3 (
  input               io_tights_0,
  input               io_tights_1,
  output              io_isUnique,
  output              io_isIsolated
);

  wire                _zz_io_isUnique;

  assign _zz_io_isUnique = (io_tights_0 || io_tights_1);
  assign io_isUnique = (_zz_io_isUnique && ((1'b1 && 1'b1) && (! (io_tights_0 && io_tights_1))));
  assign io_isIsolated = (! _zz_io_isUnique);

endmodule

//VertexPostExecuteStateCommon replaced by VertexPostExecuteStateCommon_3

//VertexPostExecuteStateCommon_1 replaced by VertexPostExecuteStateCommon_3

//VertexPostExecuteStateCommon_2 replaced by VertexPostExecuteStateCommon_3

module VertexPostExecuteStateCommon_3 (
  input      [1:0]    io_before_speed,
  input      [4:0]    io_before_node,
  input      [4:0]    io_before_root,
  input               io_before_isVirtual,
  input               io_before_isDefect,
  input      [1:0]    io_before_grown,
  input               io_message_valid,
  input      [11:0]   io_message_instruction,
  input               io_message_isReset,
  input               io_isVertexEqField1,
  input               io_isLayerIdEqField1,
  input               io_isStalled,
  output reg [1:0]    io_after_speed,
  output reg [4:0]    io_after_node,
  output reg [4:0]    io_after_root,
  output              io_after_isVirtual,
  output reg          io_after_isDefect,
  output reg [1:0]    io_after_grown,
  input               clk,
  input               reset
);

  wire                when_VertexPostExecuteState_l27;
  wire                when_VertexPostExecuteState_l28;
  wire                when_VertexPostExecuteState_l32;
  wire                when_VertexPostExecuteState_l33;
  wire                when_VertexPostExecuteState_l38;
  wire                when_VertexPostExecuteState_l39;
  wire       [1:0]    switch_VertexPostExecuteState_l40;
  wire                when_VertexPostExecuteState_l51;

  always @(*) begin
    io_after_speed = io_before_speed;
    if(io_message_valid) begin
      if(when_VertexPostExecuteState_l27) begin
        if(when_VertexPostExecuteState_l28) begin
          io_after_speed = io_message_instruction[6 : 5];
        end
      end
      if(when_VertexPostExecuteState_l32) begin
        if(when_VertexPostExecuteState_l33) begin
          io_after_speed = 2'b01;
        end
      end
      if(when_VertexPostExecuteState_l51) begin
        if(io_isVertexEqField1) begin
          io_after_speed = 2'b01;
        end
      end
    end
  end

  always @(*) begin
    io_after_node = io_before_node;
    if(io_message_valid) begin
      if(when_VertexPostExecuteState_l32) begin
        if(when_VertexPostExecuteState_l33) begin
          io_after_node = io_message_instruction[6 : 2];
        end
      end
      if(when_VertexPostExecuteState_l51) begin
        if(io_isVertexEqField1) begin
          io_after_node = io_message_instruction[6 : 2];
        end
      end
    end
  end

  always @(*) begin
    io_after_root = io_before_root;
    if(io_message_valid) begin
      if(when_VertexPostExecuteState_l51) begin
        if(io_isVertexEqField1) begin
          io_after_root = io_message_instruction[6 : 2];
        end
      end
    end
  end

  assign io_after_isVirtual = io_before_isVirtual;
  always @(*) begin
    io_after_isDefect = io_before_isDefect;
    if(io_message_valid) begin
      if(when_VertexPostExecuteState_l51) begin
        if(io_isVertexEqField1) begin
          io_after_isDefect = 1'b1;
        end
      end
    end
  end

  always @(*) begin
    io_after_grown = io_before_grown;
    if(io_message_valid) begin
      if(when_VertexPostExecuteState_l38) begin
        if(when_VertexPostExecuteState_l39) begin
          case(switch_VertexPostExecuteState_l40)
            2'b01 : begin
              io_after_grown = (io_before_grown + io_message_instruction[7 : 6]);
            end
            2'b10 : begin
              io_after_grown = (io_before_grown - io_message_instruction[7 : 6]);
            end
            default : begin
            end
          endcase
        end
      end
    end
  end

  assign when_VertexPostExecuteState_l27 = ((io_message_instruction[1 : 0] == 2'b00) && (io_message_instruction[2] == 1'b0));
  assign when_VertexPostExecuteState_l28 = (io_before_node == io_message_instruction[11 : 7]);
  assign when_VertexPostExecuteState_l32 = (io_message_instruction[1 : 0] == 2'b01);
  assign when_VertexPostExecuteState_l33 = ((io_before_node == io_message_instruction[11 : 7]) || (io_before_root == io_message_instruction[11 : 7]));
  assign when_VertexPostExecuteState_l38 = (((io_message_instruction[1 : 0] == 2'b00) && (io_message_instruction[2] == 1'b1)) && (io_message_instruction[5 : 3] == 3'b110));
  assign when_VertexPostExecuteState_l39 = (! io_isStalled);
  assign switch_VertexPostExecuteState_l40 = io_before_speed;
  assign when_VertexPostExecuteState_l51 = (io_message_instruction[1 : 0] == 2'b10);
  always @(posedge clk or posedge reset) begin
    if(reset) begin
    end else begin
      if(io_message_valid) begin
        if(when_VertexPostExecuteState_l51) begin
          if(io_isVertexEqField1) begin
            `ifndef SYNTHESIS
              `ifdef FORMAL
                assert((io_before_node == 5'h1f)); // VertexPostExecuteState.scala:L55
              `else
                if(!(io_before_node == 5'h1f)) begin
                  $display("ERROR Cannot set a vertex to defect when it's already occupied"); // VertexPostExecuteState.scala:L55
                end
              `endif
            `endif
          end
        end
      end
    end
  end


endmodule
