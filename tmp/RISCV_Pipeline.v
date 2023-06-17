`include "alu_control.v"
`include "alu.v"
`include "control.v"
`include "immgen.v"
`include "register_file.v"
`include "Pipeline_Registers.v"
`include "Forwarding_Unit.v"
`include "Hazard_Detection_Unit.v"
`include "decompressor.v"
`include "PC_predictor.v"

module RISCV_Pipeline (
		// control interface
		clk, 
		rst_n,
//----------I cache interface-------		
		ICACHE_ren,
		ICACHE_wen,
		ICACHE_addr,
		ICACHE_wdata,
		ICACHE_stall,
		ICACHE_rdata,
//----------D cache interface-------
		DCACHE_ren,
		DCACHE_wen,
		DCACHE_addr,
		DCACHE_wdata,
		DCACHE_stall,
		DCACHE_rdata,
//--------------PC-----------------
		PC
	);

//Input/Output
    input         clk, rst_n ;
    
    output        ICACHE_ren;
    output        ICACHE_wen;
    output [29:0] ICACHE_addr;
    output [31:0] ICACHE_wdata;
    input         ICACHE_stall;
    input  [31:0] ICACHE_rdata;

    output        DCACHE_ren;
    output        DCACHE_wen;
    output [29:0] DCACHE_addr;
    output [31:0] DCACHE_wdata;
    input         DCACHE_stall;
    input  [31:0] DCACHE_rdata;

    output [31:0] PC;
    
//Wire/reg    
    reg    [31:0] PC_r;
    wire   [4:0]  RS1addr_IDEX, RS2addr_IDEX, RDaddr_IDEX, RDaddr_EXMEM, RDaddr_MEMWB;
    wire   [31:0] instruction_w, PC_r_IFID, PC_r_IDEX, PC_r_IDEX_plus4, PC_r_EXMEM_plus4, PC_r_MEMWB_plus4, RS1_data_IDEX, PC_r_plus2;
    wire   [31:0] RS2_data_IDEX, RS2_data_EXMEM, immgen_result_IDEX, alu_result_EXMEM, alu_result_MEMWB, mem_data_MEMWB;
    wire   [1:0]  ALUOp, ALUOp_IDEX, ForwardA, ForwardB;//, ForwardC, ForwardD;
    wire   [3:0]  ALUCtrl, ALUCtrl_in;
    wire   [31:0] RS1_data, RS2_data, immgen_result, mem_data, decompressed_instruction, mux9, mux10, instruction_IFID;//, RS1_data_forward, RS2_data_forward;
    wire   [31:0] mux1, mux2, mux3, mux4, mux5, mux6, mux7, mux8, alu_result, PC_predict, PC_add_imm;
    wire          zero, stall_mem, branch_or_jump, stall, stall_load_use, Flush_IFID, Flush_IDEX, Stall_jal;
    wire          Jalr, Jal, Branch, MemtoReg, MemWrite, MemRead, ALUSrc, RegWrite;
    wire          Jalr_IDEX, Jal_IDEX, Branch_IDEX, ALUSrc_IDEX, MemRead_IDEX, MemWrite_IDEX, MemtoReg_IDEX, RegWrite_IDEX;
    wire          Jalr_EXMEM, Jal_EXMEM, MemRead_EXMEM, MemWrite_EXMEM, MemtoReg_EXMEM, RegWrite_EXMEM;
    wire          Jalr_MEMWB, Jal_MEMWB, MemtoReg_MEMWB, RegWrite_MEMWB;
    reg    [15:0] compression_buffer_r, compression_buffer_w; //For compression extention
    reg    [1:0]  state_r, state_w; //For compression extention
    reg    [31:0] true_instruction;
    wire          is_compress, is_jal;
    wire          compress_IDEX;
    wire          predict_wrong;

//state
    parameter COMPLETE = 2'd0;   //Perfect border
    parameter INCOMPLETE = 2'd1; //Middle
    parameter PREPARE = 2'd2;    //For J type and B type, fall at middle

//output logic
   // assign ICACHE_ren = 1'b1;
    assign ICACHE_ren = !branch_or_jump;
    assign ICACHE_wen = 1'b0;
    assign ICACHE_addr = (state_r == PREPARE) ? PC_r[31:2] : PC_r_plus2[31:2];
    assign ICACHE_wdata = 32'd0;
    assign DCACHE_ren = MemRead_EXMEM;
    assign DCACHE_wen = MemWrite_EXMEM;
    assign DCACHE_addr = alu_result_EXMEM[31:2];
    assign DCACHE_wdata = {RS2_data_EXMEM[7:0], RS2_data_EXMEM[15:8], RS2_data_EXMEM[23:16], RS2_data_EXMEM[31:24]};
    assign PC = PC_r;
// always@* $monitorh(PC);

//internal wire
    assign mem_data = {DCACHE_rdata[7:0], DCACHE_rdata[15:8], DCACHE_rdata[23:16], DCACHE_rdata[31:24]};
    assign instruction_w = {ICACHE_rdata[7:0], ICACHE_rdata[15:8], ICACHE_rdata[23:16], ICACHE_rdata[31:24]};
    assign mux1 = ((Jal_MEMWB | Jalr_MEMWB) == 1'b0) ? mux5 : PC_r_MEMWB_plus4;
    assign mux2 = (ALUSrc_IDEX == 1'b0) ? mux7 : immgen_result_IDEX;
    assign mux3 = (Jalr_IDEX) ? alu_result : PC_add_imm;
    assign mux4 = (branch_or_jump) ? mux3 : mux10; 
    assign mux5 = (MemtoReg_MEMWB == 1'b0) ? alu_result_MEMWB : mem_data_MEMWB;
    assign branch_or_jump = predict_wrong | Jalr_IDEX;
    assign predict_wrong = Branch_IDEX & zero;
    assign stall_mem = (ICACHE_stall & ~ branch_or_jump) | DCACHE_stall; // stall due to memory access
    assign stall = stall_mem | stall_load_use | Stall_jal;      // stall due to memory access and load use data hazard 
    assign PC_r_IDEX_plus4 = (compress_IDEX == 1'b1) ? PC_r_IDEX + 2 : PC_r_IDEX + 4;
    assign mux6 = (ForwardA[1])? mux8 : (ForwardA[0])? mux1 : RS1_data_IDEX; // Forwarding
    assign mux7 = (ForwardB[1])? mux8 : (ForwardB[0])? mux1 : RS2_data_IDEX; 
    assign mux8 = (Jal_EXMEM | Jalr_EXMEM) ? PC_r_EXMEM_plus4 : alu_result_EXMEM;
    assign is_compress = (instruction_IFID[1:0] != 2'b11);
    assign mux9 = (true_instruction[1:0] == 2'b11) ? PC_r + 4 : PC_r + 2;
    assign PC_r_plus2 = PC_r + 2;
    assign mux10 = (is_jal)? PC_predict : mux9;
    assign is_jal = (true_instruction[6:0] == 7'b1101111) | ((true_instruction[14:13] == 2'b01) & (true_instruction[1:0] == 2'b01));
    assign PC_add_imm = PC_r_IDEX + immgen_result_IDEX;

    always @(*) begin
        case (state_r)
            COMPLETE: begin
                if (branch_or_jump | is_jal) begin
                    if (mux4[1] == 1'b1) begin
                        state_w = PREPARE;
                    end
                    else begin
                        state_w = COMPLETE;
                    end
                    compression_buffer_w = 16'd0;
                end
                else if (instruction_w[1:0] == 2'b11) begin
                    state_w = COMPLETE;
                    compression_buffer_w = 16'd0;
                end
                else begin
                    state_w = INCOMPLETE;
                    compression_buffer_w = instruction_w[31:16];
                end
            end
            INCOMPLETE: begin
                if (branch_or_jump | is_jal) begin
                    if (mux4[1] == 1'b1) begin
                        state_w = PREPARE;
                    end
                    else begin
                        state_w = COMPLETE;
                    end
                    compression_buffer_w = 16'd0;
                end
                else if (compression_buffer_r[1:0] == 2'b11) begin
                    state_w = INCOMPLETE;
                    compression_buffer_w = instruction_w[31:16];
                end
                else begin
                    state_w = COMPLETE;
                    compression_buffer_w = 16'd0;
                end
            end
            PREPARE: begin
                state_w = INCOMPLETE;
                compression_buffer_w = instruction_w[31:16];
            end
            default: begin
                state_w = COMPLETE;
                compression_buffer_w = 16'd0;
            end
        endcase
    end

    always @(posedge clk) begin
        if(rst_n == 1'b0) begin
            state_r <= COMPLETE;
            compression_buffer_r <= 16'd0;
        end
        else if (stall) begin
            state_r <= state_r;
            compression_buffer_r <= compression_buffer_r;
        end
        else begin
            state_r <= state_w;
            compression_buffer_r <= compression_buffer_w;
        end
    end

    always @(*) begin
        case (state_r)
            COMPLETE: begin
                true_instruction = instruction_w;
            end
            INCOMPLETE: begin
                true_instruction = {instruction_w[15:0], compression_buffer_r};
            end
            PREPARE: begin
               true_instruction = 32'b000000000000_00000_000_00000_0010011; //addi r0, r0, 0
            end
            default: begin
               true_instruction = 32'b000000000000_00000_000_00000_0010011; //addi r0, r0, 0
            end
        endcase
    end

    always @(posedge clk) begin
        if(rst_n == 1'b0) begin
            PC_r <= 32'd0;
        end
        else if (stall | state_r == PREPARE) begin
            PC_r <= PC_r;
        end
        else begin
            PC_r <= mux4;
        end
    end

//module intantiation
    decompressor decompressor (
        .instr_i(instruction_IFID),
        .decompress_i(is_compress),
        .instr_o(decompressed_instruction)
    );

    alu_control alu_control (
        .Funct7_i(ALUCtrl_in[3]),
        .Funct3_i(ALUCtrl_in[2:0]),
        .ALUOp_i(ALUOp_IDEX),
        .ALUCtrl_o(ALUCtrl)
    );

    alu alu (
        .ALUCtrl_i(ALUCtrl),
        .data1_i(mux6),
        .data2_i(mux2),
        .zero_o(zero),
        .data_o(alu_result)
    );

    control control (
        .Opcode_i(decompressed_instruction[6:0]),
        .Jalr_o(Jalr),
        .Jal_o(Jal),
        .Branch_o(Branch),
        .MemtoReg_o(MemtoReg),
        .ALUOp_o(ALUOp),
        .MemWrite_o(MemWrite),
        .MemRead_o(MemRead),
        .ALUSrc_o(ALUSrc),
        .RegWrite_o(RegWrite)
    );

    immgen immgen (
        .instruction_i(decompressed_instruction),
        .immgen_o(immgen_result)
    );

    register_file register_file (
        .clk_i(clk),
        .rst_n_i(rst_n),
        .RegWrite_i(RegWrite_MEMWB),
        .RD_address_i(RDaddr_MEMWB),
        .RD_data_i(mux1),
        .RS1_address_i(decompressed_instruction[19:15]),
        .RS2_address_i(decompressed_instruction[24:20]),
        .RS1_data_o(RS1_data),
        .RS2_data_o(RS2_data)
    );

    Forwarding_Unit Forwarding_Unit (
        .RS1addr_i(RS1addr_IDEX),
        .RS2addr_i(RS2addr_IDEX),
        .RDaddr_EXMEM_i(RDaddr_EXMEM),
        .RegWrite_EXMEM_i(RegWrite_EXMEM),
        .RDaddr_MEMWB_i(RDaddr_MEMWB),
        .RegWrite_MEMWB_i(RegWrite_MEMWB),
        .ForwardA_o(ForwardA),
        .ForwardB_o(ForwardB)
    );

    Hazard_Detection_Unit Hazard_Detection_Unit (
        .MemRead_i(MemRead_IDEX),
        .Jalr_ID_i(Jalr),
        .RDaddr_i(RDaddr_IDEX),
        .RS1addr_i(decompressed_instruction[19:15]),
        .RS2addr_i(decompressed_instruction[24:20]),
        .Branch_ID_i(Branch),
        .Predict_wrong_i(branch_or_jump),
        .Jal_IF_i(is_jal),
        .Jal_EX_i(Jal_IDEX),
        .Stall_load_use_o(stall_load_use),
        .Stall_jal_o(Stall_jal),
        .Flush_IFID_o(Flush_IFID),
        .Flush_IDEX_o(Flush_IDEX)
    );


    PC_predictor PC_predictor (
        .PC(PC_r),
        .instr(true_instruction),
        .PC_predict(PC_predict)
    );

    IFID IFID (
        .clk(clk),
        .rst_n(rst_n),
        .Stall(stall_mem | stall_load_use),
        .Flush(Flush_IFID & (~(stall_mem | stall_load_use))),
        .instr_i(true_instruction),
        .PC_i(PC_r),
        .instr_o(instruction_IFID),
        .PC_o(PC_r_IFID)
    );

    IDEX IDEX (
        .clk(clk),                  // clk, PC (used for WriteBack of JAL and JALR)
        .rst_n(rst_n),
        .compress_i(is_compress),
        .Stall(stall_mem),
        .Flush(Flush_IDEX & (~stall_mem)),
        .PC_i(PC_r_IFID),
        .Jalr_i(Jalr),
        .Jal_i(Jal),
        .Branch_i(Branch),
        .ALUOp_i(ALUOp),              // EX  : ALUOp, ALUSrc
        .ALUSrc_i(ALUSrc),
        .MemRead_i(MemRead),            // MEM : MemRead, MemWrite
        .MemWrite_i(MemWrite),
        .RegWrite_i(RegWrite),           // WB  : MemtoReg, RegWrite
        .MemtoReg_i(MemtoReg),
        .RS1data_i(RS1_data),            // data and addr for RS1, RS2 and RD
        .RS2data_i(RS2_data),
        .RS1addr_i(decompressed_instruction[19:15]),
        .RS2addr_i(decompressed_instruction[24:20]),
        .RDaddr_i(decompressed_instruction[11:7]),
        .funct_i({decompressed_instruction[30], decompressed_instruction[14:12]}),              // input of ALU control : instr[30, 14:12]
        .imm_i(immgen_result),

        .PC_o(PC_r_IDEX),
        .Jalr_o(Jalr_IDEX),
        .Jal_o(Jal_IDEX),
        .Branch_o(Branch_IDEX),
        .ALUOp_o(ALUOp_IDEX),
        .ALUSrc_o(ALUSrc_IDEX),
        .MemRead_o(MemRead_IDEX),
        .MemWrite_o(MemWrite_IDEX),
        .RegWrite_o(RegWrite_IDEX),
        .MemtoReg_o(MemtoReg_IDEX),
        .RS1data_o(RS1_data_IDEX),
        .RS2data_o(RS2_data_IDEX),
        .RS1addr_o(RS1addr_IDEX),
        .RS2addr_o(RS2addr_IDEX),
        .RDaddr_o(RDaddr_IDEX),
        .funct_o(ALUCtrl_in),
        .imm_o(immgen_result_IDEX),
        .compress_o(compress_IDEX)
    );

    EXMEM EXMEM (
        .clk(clk),
        .rst_n(rst_n),
        .Stall(stall_mem),
        .PC_i(PC_r_IDEX_plus4),
        .Jalr_i(Jalr_IDEX),
        .Jal_i(Jal_IDEX),
        .RegWrite_i(RegWrite_IDEX),
        .MemtoReg_i(MemtoReg_IDEX),
        .MemRead_i(MemRead_IDEX),
        .MemWrite_i(MemWrite_IDEX),
        .ALUResult_i(alu_result),
        .RS2data_i(mux7),
        .RDaddr_i(RDaddr_IDEX),

        .PC_o(PC_r_EXMEM_plus4),
        .Jalr_o(Jalr_EXMEM),
        .Jal_o(Jal_EXMEM),
        .RegWrite_o(RegWrite_EXMEM),
        .MemtoReg_o(MemtoReg_EXMEM),
        .MemRead_o(MemRead_EXMEM),
        .MemWrite_o(MemWrite_EXMEM),
        .ALUResult_o(alu_result_EXMEM),
        .RS2data_o(RS2_data_EXMEM),
        .RDaddr_o(RDaddr_EXMEM)
    );

    MEMWB MEMWB (
        .clk(clk),
        .rst_n(rst_n),
        .Stall(stall_mem),
        .PC_i(PC_r_EXMEM_plus4),
        .Jalr_i(Jalr_EXMEM),
        .Jal_i(Jal_EXMEM),
        .RegWrite_i(RegWrite_EXMEM),
        .MemtoReg_i(MemtoReg_EXMEM),
        .ALUResult_i(alu_result_EXMEM),
        .MemData_i(mem_data),
        .RDaddr_i(RDaddr_EXMEM),

        .PC_o(PC_r_MEMWB_plus4),
        .Jalr_o(Jalr_MEMWB),
        .Jal_o(Jal_MEMWB),
        .RegWrite_o(RegWrite_MEMWB),
        .MemtoReg_o(MemtoReg_MEMWB),
        .ALUResult_o(alu_result_MEMWB),
        .MemData_o(mem_data_MEMWB),
        .RDaddr_o(RDaddr_MEMWB)
    );

endmodule
