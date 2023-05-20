/*
Module: alu
Author: Chia-Jen Nieh
Description:
    Reading ALUCtrl_i and output corresponding results. 
    When ALUCtrl_i == 3'd0. it handles ADD, LW, SW and JALR.
    When ALUCtrl_i == 3'd1. it handles SUB and BEQ.
    When ALUCtrl_i == 3'd2. it handles AND.
    When ALUCtrl_i == 3'd3. it handles OR.
    When ALUCtrl_i == 3'd4. it handles SLT.
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
    //LW:   IMM[11:0]        rs1 010 rd          0000011
    //SW:   IMM[11:5]    rs2 rs1 010 IMM[4:0]    0100011
    //JALR: IMM[11:0]        rs1 000 rd          1100111 //Byte address

    //SUB:  0100000      rs2 rs1 000 rd          0110011
    //BEQ:  IMM[12,10:5] rs2 rs1 000 IMM[4:1,11] 1100011 //Halfword address //Partially handled by ALU

    //AND:  0000000      rs2 rs1 111 rd          0110011

    //OR:   0000000      rs2 rs1 110 rd          0110011

    //SLT:  0000000      rs2 rs1 010 rd          0110011
    
    //JAL:  IMM[20,10:1,11,19:12]    rd          1101111 //Halfword address //Not handled by ALU
    `define ADD 3'd0
    `define SUB 3'd1
    `define AND 3'd2
    `define OR  3'd3
    `define SLT 3'd4

    input      [31:0] data1_i, data2_i;
    input      [2:0]  ALUCtrl_i;
    output reg        zero_o;
    output reg [31:0] data_o;

    reg [31:0] add_result, sub_result, and_result, or_result;

    always @(*) begin
        add_result = data1_i + data2_i;
        sub_result = data1_i - data2_i;
        and_result = data1_i & data2_i;
        or_result  = data1_i | data2_i;
    end

    always @(*) begin
        case (ALUCtrl_i)
            `ADD: begin
                data_o = add_result;
                zero_o = 1'b0;
            end
            `SUB: begin
                data_o = sub_result;
                zero_o = (sub_result == 32'd0) ? 1'b1 : 1'b0;
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
            default: begin
                data_o = 32'd0;
                zero_o = 1'b0;
            end
        endcase
    end

endmodule