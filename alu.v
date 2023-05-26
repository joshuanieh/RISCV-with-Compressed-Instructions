/*
Module: alu
Author: Chia-Jen Nieh
Description:
    Reading ALUCtrl_i and output corresponding results. 
    When ALUCrtl_i == 4'd0. it handles ADD, ADDI, LW, SW and JALR.
    When ALUCrtl_i == 4'd1. it handles SUB.
    When ALUCrtl_i == 4'd2. it handles AND and ANDI.
    When ALUCrtl_i == 4'd3. it handles OR and ORI.
    When ALUCrtl_i == 4'd4. it handles SLT and SLTI.
    When ALUCrtl_i == 4'd5. it handles XOR, XORI, BEQ.
    When ALUCrtl_i == 4'd6. it handles SLLI.
    When ALUCrtl_i == 4'd7. it handles SRLI.
    When ALUCrtl_i == 4'd8. it handles SRAI.
    When ALUCrtl_i == 4'd9. it handles BNE.
*/
module alu (
    ALUCtrl_i,
    data1_i,
    data2_i,
    zero_o,
    data_o
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

    `define ADD 4'd0
    `define SUB 4'd1
    `define AND 4'd2
    `define OR  4'd3
    `define SLT 4'd4
    `define XOR 4'd5
    `define SLL 4'd6
    `define SRL 4'd7
    `define SRA 4'd8
    `define BNE 4'd9

    input      [31:0] data1_i, data2_i;
    input      [3:0]  ALUCtrl_i;
    output reg        zero_o;
    output reg [31:0] data_o;

    reg [31:0] add_result, sub_result, and_result, or_result, xor_result, sll_result, srl_result, sra_result;

    always @(*) begin
        add_result = data1_i + data2_i;
        sub_result = data1_i - data2_i;
        and_result = data1_i & data2_i;
        or_result  = data1_i | data2_i;
        xor_result = data1_i ^ data2_i;
        sll_result = data1_i << data2_i[4:0];
        srl_result = data1_i >> data2_i[4:0];
        sra_result = data1_i >>> data2_i[4:0];
    end

    always @(*) begin
        case (ALUCtrl_i)
            `ADD: begin
                data_o = add_result;
                zero_o = 1'b0;
            end
            `SUB: begin
                data_o = sub_result;
                zero_o = 1'b0;
            end
            `AND: begin
                data_o = and_result;
                zero_o = 1'b0;
            end
            `OR: begin
                data_o = or_result;
                zero_o = 1'b0;
            end
            `SLT: begin
                data_o = {31'd0, sub_result[31]};
                zero_o = 1'b0;
            end
            `XOR: begin
                data_o = xor_result;
                zero_o = (xor_result == 32'd0) ? 1'b1 : 1'b0; //For BEQ
            end
            `SLL: begin
                data_o = sll_result;
                zero_o = 1'b0;
            end
            `SRL: begin
                data_o = srl_result;
                zero_o = 1'b0;
            end
            `SRA: begin
                data_o = sra_result;
                zero_o = 1'b0;
            end
            default: begin //BNE
                data_o = 32'd0;
                zero_o = (xor_result == 32'd0) ? 1'b0 : 1'b1; //For BNE
            end
        endcase
    end

endmodule