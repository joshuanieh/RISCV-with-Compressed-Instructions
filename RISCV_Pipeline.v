/*
Module: CHIP
Author: Chia-Jen Nieh
Description:
    It's a single cycle CPU. Remeber to add an adder for Jalr when pipelining
*/
`include "alu_control.v"
`include "alu.v"
`include "control.v"
`include "immgen.v"
`include "register_file.v"

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
    wire   [31:0] instruction;
    wire   [1:0]  ALUOp;
    wire   [2:0]  ALUCtrl;
    wire   [31:0] RS1_data, RS2_data, immgen_result, mux2;
    wire          zero;
    wire   [31:0] mux3, mux4;
    wire   [31:0] alu_result;
    wire          Jalr, Jal, Branch, MemtoReg, MemWrite, MemRead, ALUSrc, RegWrite;
    wire   [31:0] mem_data, mux5;
    wire   [31:0] mux1;

//output logic
    assign ICACHE_ren = 1'b1;
    assign ICACHE_wen = 1'b0;
    assign ICACHE_addr = PC_r[31:2];
    assign ICACHE_wdata = 32'd0;
    assign DCACHE_ren = MemRead;
    assign DCACHE_wen = MemWrite;
    assign DCACHE_addr = alu_result;
    assign DCACHE_wdata = {RS2_data[7:0], RS2_data[15:8], RS2_data[23:16], RS2_data[31:24]};
    assign PC = PC_r;

//internal wire
    assign mem_data = {DCACHE_rdata[7:0], DCACHE_rdata[15:8], DCACHE_rdata[23:16], DCACHE_rdata[31:24]};
    assign instruction = {ICACHE_rdata[7:0], ICACHE_rdata[15:8], ICACHE_rdata[23:16], ICACHE_rdata[31:24]};
    assign mux1 = ((Jal | Jalr) == 1'b0) ? mux5 : PC_r + 4;
    assign mux2 = (ALUSrc == 1'b0) ? RS2_data : immgen_result;
    assign mux3 = (((zero & Branch) | Jal) == 1'b0) ? PC_r + 4 : PC_r + immgen_result;
    assign mux4 = (Jalr == 1'b0) ? mux3 : alu_result;
    assign mux5 = (MemtoReg == 1'b0) ? alu_result : mem_data;

//module intantiation
    always @(posedge clk) begin
        if(rst_n == 1'b0) begin
            PC_r <= 32'd0;
        end
        else begin
            PC_r <= mux4;
        end
    end

    alu_control alu_control (
        .Funct7_i(instruction[30]),
        .Funct3_i(instruction[14:12]),
        .ALUOp_i(ALUOp),
        .ALUCtrl_o(ALUCtrl)
    );

    alu alu (
        .ALUCtrl_i(ALUCtrl),
        .data1_i(RS1_data),
        .data2_i(mux2),
        .zero_o(zero),
        .data_o(alu_result)
    );

    control control (
        .Opcode_i(instruction[6:0]),
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
        .instruction_i(instruction),
        .immgen_o(immgen_result)
    );

    register_file register_file (
        .clk_i(clk),
        .rst_n_i(rst_n),
        .RegWrite_i(RegWrite),
        .RD_address_i(instruction[11:7]),
        .RD_data_i(mux1),
        .RS1_address_i(instruction[19:15]),
        .RS2_address_i(instruction[24:20]),
        .RS1_data_o(RS1_data),
        .RS2_data_o(RS2_data)
    );

endmodule