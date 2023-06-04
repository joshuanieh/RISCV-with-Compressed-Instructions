module decompressor (
    instr_i,
    decompress_i,
    instr_o
);
    input  [31:0] instr_i;
    input         decompress_i;
    output [31:0] instr_o;

    reg    [31:0] decompressed_instr;
    wire          is_lw, is_sw, is_addi. is_jal, is_srli, is_srai, is_andi, is_j, is_beqz, is_bnez, is_slli, is_jr, is_mv, is_jalr, is_add;

    assign instr_o = (decompress_i == 1'b1) ? decompressed_instr : instr_i;

    assign is_lw = ((instr_i[1:0] == 2'b00) & (instr_i[15] == 1'b0));
    assign is_sw = ((instr_i[1:0] == 2'b00) & (instr_i[15] == 1'b1));
    assign is_addi = ((instr_i[1:0] == 2'b01) & (instr_i[15] == 1'b0) & (instr_i[13] == 1'b0));
    assign is_jal = ((instr_i[1:0] == 2'b01) & (instr_i[15] == 1'b0) & (instr_i[13] == 1'b1));
    assign is_srli = ((instr_i[1:0] == 2'b01) & (instr_i[15:13] == 3'b100) & (instr_i[11:10] == 2'b00));
    assign is_srai = ((instr_i[1:0] == 2'b01) & (instr_i[15:13] == 3'b100) & (instr_i[10] == 1'b1));
    assign is_andi = ((instr_i[1:0] == 2'b01) & (instr_i[15:13] == 3'b100) & (instr_i[11] == 1'b1));
    assign is_j = ((instr_i[1:0] == 2'b01) & (instr_i[15:13] == 3'b101));
    assign is_beqz = ((instr_i[1:0] == 2'b01) & (instr_i[14:13] == 2'b10));
    assign is_bnez = ((instr_i[1:0] == 2'b01) & (instr_i[14:13] == 2'b11));
    assign is_slli = ((instr_i[1:0] == 2'b10) & (instr_i[15] == 1'b0));
    assign is_jr = ((instr_i[1:0] == 2'b10) & (instr_i[15] == 1'b1) & (instr_i[12] == 1'b0) & (instr_i[6:2] == 5'd0));
    assign is_mv = ((instr_i[1:0] == 2'b10) & (instr_i[15] == 1'b1) & (instr_i[12] == 1'b0) & (instr_i[6:2] != 5'd0));
    assign is_jalr = ((instr_i[1:0] == 2'b10) & (instr_i[15] == 1'b1) & (instr_i[12] == 1'b1) & (instr_i[6:2] == 5'd0));
    assign is_add = ((instr_i[1:0] == 2'b10) & (instr_i[15] == 1'b1) & (instr_i[12] == 1'b1) & (instr_i[6:2] != 5'd0));


//TODO: decompress to 32 bit version
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

endmodule