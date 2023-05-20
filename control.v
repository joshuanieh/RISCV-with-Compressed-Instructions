/*
Module: control
Author: Chia-Jen Nieh
Description:
    Reading opcode from instruction[6:0] and determine control signals.
*/
module control (
    Opcode_i,
    Jalr_o,
    Jal_o,
    Branch_o,
    MemtoReg_o,
    ALUOp_o,
    MemWrite_o,
    ALUSrc_o,
    RegWrite_o
);
    input  [6:0] Opcode_i;
    output       Jalr_o, Jal_o, Branch_o;
    output       MemtoReg_o, MemWrite_o;
    output       ALUSrc_o, RegWrite_o;
    output [1:0] ALUOp_o;
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

    //If operation is JALR, JALR = 1
    //                else, JALR = 0
    assign Jalr_o = (Opcode_i == 7'b1100111) ? 1 : 0;

    //If operation is JAL, JAL = 1
    //                else, JAL = 0
    assign Jal_o = (Opcode_i == 7'b1101111) ? 1 : 0;

    //If operation is BEQ, Branch = 1
    //                else, Branch = 0
    assign Branch_o = (Opcode_i == 7'b1100011) ? 1 : 0;

    //If operation is LW, MemtoReg = 1
    //                else, MemtoReg = 0
    assign MemtoReg_o = (Opcode_i == 7'b0000011) ? 1 : 0;

    //If operation is SW, MemWrite = 1
    //                else, MemWrite = 0
    assign MemWrite_o = (Opcode_i == 7'b0100011) ? 1 : 0;

    //If operation is ADD or LW or JALR or SUB or AND or OR or SLT or JAL, RegWrite = 1
    //                SW or BEQ, RegWrite = 0
    assign RegWrite_o = ((Opcode_i == 7'b0100011) | (Opcode_i == 7'b1100011)) ? 0 : 1;

    //If operation is ADD or SUB or BEQ or AND or OR or SLT, ALUSrc = 0
    //                LW or SW or JALR, ALUSrc = 1
    assign ALUSrc_o = ((Opcode_i == 7'b0110011) | (Opcode_i == 7'b1100011)) ? 0 : 1;

    //ALUOp are two bits. 2'd0 represents 0110011, 2'd1 represents 1100011, 2'd2 represents others.
    assign ALUOp_o = (Opcode_i == 7'b0110011) ? 2'd0 :
                     (Opcode_i == 7'b1100011) ? 2'd1 : 2'd2;
endmodule