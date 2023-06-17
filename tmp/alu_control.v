/*
Module: alu_control
Author: Chia-Jen Nieh
Description:
    Use the sixth bit of Funct7, Funct3 and ALUOp to determine the output ALUCtrl.
    ALUOp are two bits. 2'd0 represents 0110011, 2'd1 represents 1100011, 2'd2 represents others.
    The sixth bit in Funct7 is only used to distinguish add and sub.
    The ALUCtrl output follows my convention:
        When ALUCrtl_o == 4'd0. it handles ADD, ADDI, LW, SW and JALR.
        When ALUCrtl_o == 4'd1. it handles SUB.
        When ALUCrtl_o == 4'd2. it handles AND and ANDI.
        When ALUCrtl_o == 4'd3. it handles OR and ORI.
        When ALUCrtl_o == 4'd4. it handles SLT and SLTI.
        When ALUCrtl_o == 4'd5. it handles XOR, XORI, BEQ.
        When ALUCrtl_o == 4'd6. it handles SLLI.
        When ALUCrtl_o == 4'd7. it handles SRLI.
        When ALUCrtl_o == 4'd8. it handles SRAI.
        When ALUCrtl_o == 4'd9. it handles BNE.
*/
module alu_control (
    Funct7_i,
    Funct3_i,
    ALUOp_i,
    ALUCtrl_o
);
    //ISA to be handled
    //ADD:  0000000      rs2 rs1 000 rd          0110011
    //ADDI: IMM[11:0]        rs1 000 rd          0010011
    //LW:   IMM[11:0]        rs1 010 rd          0000011
    //SW:   IMM[11:5]    rs2 rs1 010 IMM[4:0]    0100011
    //JALR: IMM[11:0]        rs1 000 rd          1100111 //Byte address

    //SUB:  0100000      rs2 rs1 000 rd          0110011

    //AND:  0000000      rs2 rs1 111 rd          0110011
    //ANDI: IMM[11:0]        rs1 111 rd          0010011

    //OR:   0000000      rs2 rs1 110 rd          0110011
    //ORI:  IMM[11:0]        rs1 110 rd          0010011

    //XOR:  0000000      rs2 rs1 100 rd          0110011
    //XORI: IMM[11:0]        rs1 100 rd          0010011
    //BEQ:  IMM[12,10:5] rs2 rs1 000 IMM[4:1,11] 1100011 //Halfword address //Partially handled by ALU, PC + imm is outside of ALU
    
    //BNE:  IMM[12,10:5] rs2 rs1 001 IMM[4:1,11] 1100011 //Halfword address //Partially handled by ALU, PC + imm is outside of ALU
    
    //SLLI: 0000000      sha rs1 001 rd          0010011

    //SRLI: 0000000      sha rs1 101 rd          0010011

    //SRAI: 0100000      sha rs1 101 rd          0010011
    
    //SLT:  0000000      rs2 rs1 010 rd          0110011
    //SLTI: IMM[11:0]        rs1 010 rd          0010011

    //JAL:  IMM[20,10:1,11,19:12]    rd          1101111 //Halfword address //Not handled by ALU, PC + imm is outside of ALU

    // When ALUCrtl_o == 4'd0. it handles ADD, ADDI, LW, SW and JALR.
    // When ALUCrtl_o == 4'd1. it handles SUB.
    // When ALUCrtl_o == 4'd2. it handles AND and ANDI.
    // When ALUCrtl_o == 4'd3. it handles OR and ORI.
    // When ALUCrtl_o == 4'd4. it handles SLT and SLTI.
    // When ALUCrtl_o == 4'd5. it handles XOR, XORI, BEQ.
    // When ALUCrtl_o == 4'd6. it handles SLLI.
    // When ALUCrtl_o == 4'd7. it handles SRLI.
    // When ALUCrtl_o == 4'd8. it handles SRAI.
    // When ALUCrtl_o == 4'd9. it handles BNE.

    //Control module can't distinguish ADD, SUB, AND, OR, XOR and SLT.
    //Control module can't distinguish ADDI, ANDI, ORI, XORI, SLLI, SRLI, SRAI and SLTI.
    //Control module can't distinguish BEQ and BNE.
    //Control module can distinguish LW, SW, JALR and SLT.
    input        Funct7_i; //The sixth bit in Funct7, used to distinguish add and sub, SRLI and SRAI
    input  [2:0] Funct3_i;
    input  [1:0] ALUOp_i; //2'd0 represents 0110011 (R), 2'd1 represents 0010011 (I), 2'd2 represents 1100011 (B), 2'd3 represents others
    output [3:0] ALUCtrl_o;

    // wire isADD, isLW, isSW, isJALR;
    wire isSUB = (Funct7_i == 1'b1) & (Funct3_i == 3'b000) & (ALUOp_i == 2'd0); //Funct7 is to distinguish add and sub
    wire isBEQ = (Funct3_i[0] == 1'b0) & (ALUOp_i == 2'd2); //If ALUOp is 2'd2, use Funct3[0] to decide beq
    wire isAND = (Funct3_i == 3'b111); //If Funct3 = 111, must be and
    wire isOR = (Funct3_i == 3'b110); //If Funct3 = 110, must be or
    wire isSLT = (Funct3_i == 3'b010) & ((ALUOp_i == 2'd0) || (ALUOp_i == 2'd1)); //If Funct3 = 010, it may be load, store or slt, slti, use ALUOp to distinguish
    wire isXOR = (Funct3_i == 3'b100); //If Funct3 = 100, must be xor
    wire isSLL = (Funct3_i == 3'b001) & (ALUOp_i == 2'd1); //If Funct3 = 001, it may be sll or bne, use ALUOp to distinguish;;
    wire isSRL = (Funct7_i == 1'b0) & (Funct3_i == 3'b101); //If Funct3 = 101, it may be srl or sra, use ALUOp to distinguish
    wire isSRA = (Funct7_i == 1'b1) & (Funct3_i == 3'b101); //If Funct3 = 101, it may be srl or sra, use ALUOp to distinguish
    wire isBNE = (Funct3_i[0] == 1'b1) & (ALUOp_i == 2'd2); //If ALUOp is 2'd2, use Funct3[0] to decide bne

    assign ALUCtrl_o = (isXOR || isBEQ) ? 4'd5 : 
                       isAND ? 4'd2 :
                       isOR  ? 4'd3 :
                       isSLT ? 4'd4 :
                       isSUB ? 4'd1 :
                       isSLL ? 4'd6 :
                       isSRL ? 4'd7 :
                       isSRA ? 4'd8 :
                       isBNE ? 4'd9 : 4'd0; //Should arrange based on delay
endmodule

//Todo: change to parallel mux and inspect functionality