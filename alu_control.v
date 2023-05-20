/*
Module: alu_control
Author: Chia-Jen Nieh
Description:
    Use the sixth bit of Funct7, Funct3 and ALUOp to determine the output ALUCtrl.
    ALUOp are two bits. 2'd0 represents 0110011, 2'd1 represents 1100011, 2'd2 represents others.
    The sixth bit in Funct7 is only used to distinguish add and sub.
    The ALUCtrl output follows my convention:
        When ALUCrtl_i == 3'd0. it handles ADD, LW, SW and JALR.
        When ALUCrtl_i == 3'd1. it handles SUB and BEQ.
        When ALUCrtl_i == 3'd2. it handles AND.
        When ALUCrtl_i == 3'd3. it handles OR.
        When ALUCrtl_i == 3'd4. it handles SLT.
*/
module alu_control (
    Funct7_i,
    Funct3_i,
    ALUOp_i,
    ALUCtrl_o
);
    //ISA to be handled
    //ADD:  0000000      rs2 rs1 000 rd          0110011
    //LW:   IMM[11:0]        rs1 010 rd          0000011
    //SW:   IMM[11:5]    rs2 rs1 010 IMM[4:0]    0100011
    //JALR: IMM[11:0]        rs1 000 rd          1100111 //Byte address

    //SUB:  0100000      rs2 rs1 000 rd          0110011
    //BEQ:  IMM[12,10:5] rs2 rs1 000 IMM[4:1,11] 1100011 //Halfword address //Partially handled by ALU

    //AND:  0000000      rs2 rs1 111 rd          0110011

    //OR:   0000000      rs2 rs1 110 rd          0110011

    //SLT:  0000000      rs2 rs1 010 rd          0110011
    
    //JAL:  IMM[20,10:1,11,19:12]    rd          1101111 //Halfword address //Not handled by ALU

    // When ALUCrtl_i == 3'd0. it handles ADD, LW, SW and JALR.
    // When ALUCrtl_i == 3'd1. it handles SUB and BEQ.
    // When ALUCrtl_i == 3'd2. it handles AND.
    // When ALUCrtl_i == 3'd3. it handles OR.
    // When ALUCrtl_i == 3'd4. it handles SLT.

    //Control module can't distinguish ADD, SUB, AND, OR and SLT.
    input        Funct7_i; //The sixth bit in Funct7, used only to distinguish add and sub
    input  [2:0] Funct3_i;
    input  [1:0] ALUOp_i; //2'd0 represents 0110011, 2'd1 represents 1100011, 2'd2 represents others
    output [2:0] ALUCtrl_o;

    // wire isADD, isLW, isSW, isJALR;
    wire isSUB, isBEQ;
    wire isAND;
    wire isOR;
    wire isSLT;

    // assign isADD  = (Funct7_i == 1'b0) & (Funct3_i == 3'b000) & (ALUOp_i == 7'b0110011);
    // assign isLW   = (Funct3_i == 3'b010) & (ALUOp_i == 7'b0000011);
    // assign isSW   = (Funct3_i == 3'b010) & (ALUOp_i == 7'b0100011);
    // assign isJALR = (Funct3_i == 3'b000) & (ALUOp_i == 7'b1100111);
    assign isSUB = (Funct7_i == 1'b1) & (Funct3_i == 3'b000) & (ALUOp_i == 2'd0);
    assign isBEQ = ALUOp_i == 2'd1; //If ALUOp is 2'd1, must be beq
    assign isAND = Funct3_i == 3'b111; //If Funct3 = 111, must be and
    assign isOR  = Funct3_i == 3'b110; //If Funct3 = 110, must be or
    assign isSLT = (Funct3_i == 3'b010) & (ALUOp_i == 2'd0); //If Funct3 = 010, it may be load, store or slt, use ALUOp to distinguish

    assign ALUCtrl_o = isAND ? 3'd2 :
                       isOR  ? 3'd3 :
                       isSLT ? 3'd4 :
                       (isSUB || isBEQ) ? 3'd1 : 3'd0;
endmodule