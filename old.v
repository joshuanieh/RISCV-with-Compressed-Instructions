/*
Module: CHIP
Author: Chia-Jen Nieh
Description:
    It's a single cycle CPU. Remember to add an adder for Jalr when pipelining
*/
`include "alu_control.v"
`include "alu.v"
`include "control.v"
`include "immgen.v"
`include "register_file.v"
`include "Pipeline_Registers.v"
`include "Forwarding_Unit.v"
`include "Hazard_Detection_Unit.v"

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
    wire   [31:0] instruction_w, PC_r_IFID, PC_r_IDEX, PC_r_IDEX_plus4, PC_r_EXMEM_plus4, PC_r_MEMWB_plus4, RS1_data_IDEX;
    wire   [31:0] RS2_data_IDEX, RS2_data_EXMEM, immgen_result_IDEX, alu_result_EXMEM, alu_result_MEMWB, mem_data_MEMWB;
    wire   [1:0]  ALUOp, ALUOp_IDEX, ForwardA, ForwardB;
    wire   [3:0]  ALUCtrl, ALUCtrl_in;
    wire   [31:0] RS1_data, RS2_data, immgen_result, mem_data, instruction_r;
    wire   [31:0] mux1, mux2, mux3, mux4, mux5, mux6, mux7, mux8, alu_result;
    wire          zero, stall_mem, branch_or_jal, branch_or_jump, stall, stall_load_use, Flush_IFID, Flush_IDEX;
    wire          Jalr, Jal, Branch, MemtoReg, MemWrite, MemRead, ALUSrc, RegWrite;
    wire          Jalr_IDEX, Jal_IDEX, Branch_IDEX, ALUSrc_IDEX, MemRead_IDEX, MemWrite_IDEX, MemtoReg_IDEX, RegWrite_IDEX;
    wire          Jalr_EXMEM, Jal_EXMEM, MemRead_EXMEM, MemWrite_EXMEM, MemtoReg_EXMEM, RegWrite_EXMEM;
    wire          Jalr_MEMWB, Jal_MEMWB, MemtoReg_MEMWB, RegWrite_MEMWB;

//output logic
    assign ICACHE_ren = 1'b1;
    assign ICACHE_wen = 1'b0;
    assign ICACHE_addr = PC_r[31:2];
    assign ICACHE_wdata = 32'd0;
    assign DCACHE_ren = MemRead_EXMEM;
    assign DCACHE_wen = MemWrite_EXMEM;
    assign DCACHE_addr = alu_result_EXMEM[31:2];
    assign DCACHE_wdata = {RS2_data_EXMEM[7:0], RS2_data_EXMEM[15:8], RS2_data_EXMEM[23:16], RS2_data_EXMEM[31:24]};
    assign PC = PC_r;

//internal wire
    assign mem_data = {DCACHE_rdata[7:0], DCACHE_rdata[15:8], DCACHE_rdata[23:16], DCACHE_rdata[31:24]};
    assign instruction_w = {ICACHE_rdata[7:0], ICACHE_rdata[15:8], ICACHE_rdata[23:16], ICACHE_rdata[31:24]};
    assign mux1 = ((Jal_MEMWB | Jalr_MEMWB) == 1'b0) ? mux5 : PC_r_MEMWB_plus4;
    assign mux2 = (ALUSrc_IDEX == 1'b0) ? mux7 : immgen_result_IDEX;
    assign mux3 = (!branch_or_jal) ? PC_r + 4 : PC_r_IDEX + immgen_result_IDEX;
    assign mux4 = (Jalr_IDEX == 1'b0) ? mux3 : alu_result;
    assign mux5 = (MemtoReg_MEMWB == 1'b0) ? alu_result_MEMWB : mem_data_MEMWB;
    assign stall_mem = ICACHE_stall | DCACHE_stall; // stall due to memory access
    assign stall = stall_mem | stall_load_use;      // stall due to memory access and load use data hazard 
    assign PC_r_IDEX_plus4 = PC_r_IDEX + 4;
    assign mux6 = (ForwardA[1])? mux8 : (ForwardA[0])? mux1 : RS1_data_IDEX; // Forwarding
    assign mux7 = (ForwardB[1])? mux8 : (ForwardB[0])? mux1 : RS2_data_IDEX; 
    assign mux8 = (Jal_EXMEM | Jalr_EXMEM) ? PC_r_EXMEM_plus4 : alu_result_EXMEM;
    assign branch_or_jal = (zero & Branch_IDEX) | Jal_IDEX;
    assign branch_or_jump = branch_or_jal | Jalr_IDEX;

//module intantiation
    always @(posedge clk) begin
        if(rst_n == 1'b0) begin
            PC_r <= 32'd0;
        end
        else if (stall) begin
            PC_r <= PC_r;
        end
        else begin
            PC_r <= mux4;
        end
    end

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
        .Opcode_i(instruction_r[6:0]),
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
        .instruction_i(instruction_r),
        .immgen_o(immgen_result)
    );

    register_file register_file (
        .clk_i(clk),
        .rst_n_i(rst_n),
        .RegWrite_i(RegWrite_MEMWB),
        .RD_address_i(RDaddr_MEMWB),
        .RD_data_i(mux1),
        .RS1_address_i(instruction_r[19:15]),
        .RS2_address_i(instruction_r[24:20]),
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
        .RDaddr_i(RDaddr_IDEX),
        .RS1addr_i(instruction_r[19:15]),
        .RS2addr_i(instruction_r[24:20]),
        .BranchOrJump_i(branch_or_jump),
        .Stall_load_use_o(stall_load_use),
        .Flush_IFID_o(Flush_IFID),
        .Flush_IDEX_o(Flush_IDEX)
    );

    IFID IFID (
        .clk(clk),
        .rst_n(rst_n),
        .Stall(stall),
        .Flush(Flush_IFID & (~stall_mem)),
        .instr_i(instruction_w),
        .PC_i(PC_r),
        .instr_o(instruction_r),
        .PC_o(PC_r_IFID)
    );

    IDEX IDEX (
        .clk(clk),                  // clk, PC (used for WriteBack of JAL and JALR)
        .rst_n(rst_n),
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
        .RS1addr_i(instruction_r[19:15]),
        .RS2addr_i(instruction_r[24:20]),
        .RDaddr_i(instruction_r[11:7]),
        .funct_i({instruction_r[30], instruction_r[14:12]}),              // input of ALU control : instr[30, 14:12]
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
        .imm_o(immgen_result_IDEX)
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
        .RS2data_i(RS2_data_IDEX),
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