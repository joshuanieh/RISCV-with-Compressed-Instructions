/*
Module: immgen
Author: Chia-Jen Nieh
Description:
    Reading opcode from instruction and determine imm.
*/
module immgen (
    instruction_i,
    immgen_o
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
    input      [31:0] instruction_i;
    output reg [31:0] immgen_o;

    always @(*) begin
        if (instruction_i[6:0] == 7'b1101111) begin
            immgen_o = {{12{instruction_i[31]}}, instruction_i[19:12], instruction_i[20], instruction_i[30:21], 1'b0};
        end
        else begin
            if (instruction_i[6:0] == 7'b1100011) begin
                immgen_o = {{20{instruction_i[31]}}, instruction_i[7], instruction_i[30:25], instruction_i[11:8], 1'b0};
            end
            else begin
               if (instruction_i[6:0] == 7'b0100011) begin
                    immgen_o = {{21{instruction_i[31]}}, instruction_i[30:25], instruction_i[11:7]};
                end
                else begin
                    immgen_o = {{21{instruction_i[31]}}, instruction_i[30:20]};
                end
            end
        end
    end
endmodule