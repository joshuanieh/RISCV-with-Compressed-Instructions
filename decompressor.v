module decompressor (
    instr_i,
    decompress_i,
    instr_o
);
    input  [31:0] instr_i;
    input         decompress_i;
    output [31:0] instr_o;

    reg    [31:0] decompressed_instr;
    wire          is_lw, is_sw, is_addi, is_jal, is_srli, is_srai, is_andi, is_j, is_beqz, is_bnez, is_slli, is_jr, is_mv, is_jalr, is_add;

    assign instr_o = (decompress_i == 1'b1) ? decompressed_instr : instr_i;

    assign is_lw = ((instr_i[1:0] == 2'b00) & (instr_i[15] == 1'b0));                                                        //3, is_lw
    assign is_sw = ((instr_i[1:0] == 2'b00) & (instr_i[15] == 1'b1));                                                        //3, is_sw
    assign is_addi = ((instr_i[1:0] == 2'b01) & (instr_i[15] == 1'b0) & (instr_i[13] == 1'b0));                              //4, is_addi
    assign is_jal = ((instr_i[1:0] == 2'b01) & (instr_i[15] == 1'b0) & (instr_i[13] == 1'b1));                               //4, is_jal
    assign is_srli = ((instr_i[1:0] == 2'b01) & (instr_i[15:13] == 3'b100) & (instr_i[11:10] == 2'b00));                     //7, is_srli
    assign is_srai = ((instr_i[1:0] == 2'b01) & (instr_i[15:13] == 3'b100) & (instr_i[10] == 1'b1));                         //6, is_srai
    assign is_andi = ((instr_i[1:0] == 2'b01) & (instr_i[15:13] == 3'b100) & (instr_i[11] == 1'b1));                         //6, is_andi
    assign is_j = ((instr_i[1:0] == 2'b01) & (instr_i[15:13] == 3'b101));                                                    //5, is_j
    assign is_beqz = ((instr_i[1:0] == 2'b01) & (instr_i[14:13] == 2'b10));                                                  //4, is_beqz
    assign is_bnez = ((instr_i[1:0] == 2'b01) & (instr_i[14:13] == 2'b11));                                                  //4, is_bnez
    assign is_slli = ((instr_i[1:0] == 2'b10) & (instr_i[15] == 1'b0));                                                      //3, is_slli
    assign is_jr = ((instr_i[1:0] == 2'b10) & (instr_i[15] == 1'b1) & (instr_i[12] == 1'b0) & (instr_i[6:2] == 5'd0));       //9, is_jr
    assign is_mv = ((instr_i[1:0] == 2'b10) & (instr_i[15] == 1'b1) & (instr_i[12] == 1'b0) & (instr_i[6:2] != 5'd0));       //9, is_mv
    assign is_jalr = ((instr_i[1:0] == 2'b10) & (instr_i[15] == 1'b1) & (instr_i[12] == 1'b1) & (instr_i[6:2] == 5'd0));     //9, is_jalr
    assign is_add = ((instr_i[1:0] == 2'b10) & (instr_i[15] == 1'b1) & (instr_i[12] == 1'b1) & (instr_i[6:2] != 5'd0));      //9, is_add


    always @(*) begin
        if (is_jr | is_mv | is_jalr | is_add) begin
            if (is_jr | is_mv) begin
                if (is_jr) begin //jr
                    //JALR: IMM[11:0]        rs1 000 rd          1100111 //Byte address
                    //C.JR: 100 0 rs1 00000 10
                    decompressed_instr = {12'd0, instr_i[11:7], 3'd0, 5'd0, 7'b1100111};
                end
                else begin //mv
                    //ADD:  0000000      rs2 rs1 000 rd          0110011
                    //C.MV: 100 0 rd rs2 10
                    decompressed_instr = {7'd0, instr_i[6:2], 5'd0, 3'd0, instr_i[11:7], 7'b0110011};
                end
            end
            else begin
                if (is_jalr) begin //jalr
                    //JALR: IMM[11:0]        rs1 000 rd          1100111 //Byte address
                    //C.JR: 100 1 rs1 00000 10
                    decompressed_instr = {12'd0, instr_i[11:7], 3'd0, 5'd1, 7'b1100111};
                end
                else begin //add
                    //ADD:  0000000      rs2 rs1 000 rd          0110011
                    //C.ADD: 100 1 rs1/rd rs2 10
                    decompressed_instr = {7'd0, instr_i[6:2], instr_i[11:7], 3'd0, instr_i[11:7], 7'b0110011};
                end
            end
        end
        else if (is_srli | is_srai | is_andi) begin
            if (is_srli) begin //srli
                //SRLI: 0000000      sha rs1 101 rd          0010011
                //C.SRLI: 100 0 00 rs1'/rd' shamt 01
                decompressed_instr = {7'd0, instr_i[6:2], 2'b01, instr_i[9:7], 3'b101, 2'b01, instr_i[9:7], 7'b0010011};
            end
            else if (is_srai) begin //srai
                //SRAI: 0100000      sha rs1 101 rd          0010011
                //C.SRAI: 100 0 01 rs1'/rd' shamt 01
                decompressed_instr = {7'b0100000, instr_i[6:2], 2'b01, instr_i[9:7], 3'b101, 2'b01, instr_i[9:7], 7'b0010011};
            end
            else begin //andi
                //ANDI: IMM[11:0]        rs1 111 rd          0010011
                //C.ANDI: 100 imm[5] 10 rs1'/rd' imm[4:0] 01
                decompressed_instr = {{7{instr_i[12]}}, instr_i[6:2], 2'b01, instr_i[9:7], 3'b111, 2'b01, instr_i[9:7], 7'b0010011};
            end
        end
        else begin
            if (is_lw | is_sw | is_addi | is_jal) begin
                if (is_lw | is_sw) begin
                    if (is_lw) begin //lw
                        //LW:   IMM[11:0]        rs1 010 rd          0000011
                        //C.LW: 010 uimm[5:3] rs1' uimm[2|6] rd' 00
                        decompressed_instr = {5'd0, instr_i[5], instr_i[12:10], instr_i[6], 2'd0, 2'b01, instr_i[9:7], 3'b010, 2'b01, instr_i[4:2], 7'b0000011};
                    end
                    else begin //sw
                        //SW:   IMM[11:5]    rs2 rs1 010 IMM[4:0]    0100011
                        //C.SW: 110 uimm[5:3] rs1' uimm[2|6] rs2' 00
                        decompressed_instr = {5'd0, instr_i[5], instr_i[12], 2'b01, instr_i[4:2], 2'b01, instr_i[9:7], 3'b010, instr_i[11:10], instr_i[6], 2'd0, 7'b0100011};
                    end
                end
                else begin
                    if (is_addi) begin //addi
                        //ADDI: IMM[11:0]        rs1 000 rd          0010011
                        //C.ADDI: 000 imm[5] rs1/rd imm[4:0] 01
                        decompressed_instr = {{7{instr_i[12]}}, instr_i[6:2], instr_i[11:7], 3'b000, instr_i[11:7], 7'b0010011};
                    end
                    else begin //jal
                        //JAL:  IMM[20,10:1,11,19:12]    rd          1101111 //Halfword address //Not handled by ALU, PC + imm is outside of ALU
                        //C.JAL: 001 imm[11|4|9:8|10|6|7|3:1|5] 01
                        decompressed_instr = {instr_i[12], instr_i[8], instr_i[10:9], instr_i[6], instr_i[7], instr_i[2], instr_i[11], instr_i[5:3], instr_i[12], {8{instr_i[12]}}, 5'd1, 7'b1101111};
                    end
                end
            end
            else begin
                if (is_slli | is_bnez) begin
                    if (is_slli) begin //slli
                        //SLLI: 0000000      sha rs1 001 rd          0010011
                        //C.SLLI: 000 0 rs1/rd shamt 10
                        decompressed_instr = {7'd0, instr_i[6:2], instr_i[11:7], 3'b001, instr_i[11:7], 7'b0010011};
                    end
                    else begin //bnez
                        //BNE:  IMM[12,10:5] rs2 rs1 001 IMM[4:1,11] 1100011 //Halfword address //Partially handled by ALU, PC + imm is outside of ALU
                        //C.BNEZ: 111 imm[8|4:3] rs1' imm[7:6|2:1|5] 01
                        decompressed_instr = {instr_i[12], {3{instr_i[12]}}, instr_i[6:5], instr_i[2], 5'd0, 2'b01, instr_i[9:7], 3'b001, instr_i[11:10], instr_i[4:3], instr_i[12], 7'b1100011};
                    end
                end
                else begin
                    if (is_beqz) begin //beqz
                        //BEQ:  IMM[12,10:5] rs2 rs1 000 IMM[4:1,11] 1100011 //Halfword address //Partially handled by ALU, PC + imm is outside of ALU
                        //C.BEQZ: 110 imm[8|4:3] rs1' imm[7:6|2:1|5] 01
                        decompressed_instr = {instr_i[12], {3{instr_i[12]}}, instr_i[6:5], instr_i[2], 5'd0, 2'b01, instr_i[9:7], 3'b000, instr_i[11:10], instr_i[4:3], instr_i[12], 7'b1100011};
                    end
                    else begin //j
                        //JAL:  IMM[20,10:1,11,19:12]    rd          1101111 //Halfword address //Not handled by ALU, PC + imm is outside of ALU
                        //C.JAL: 101 imm[11|4|9:8|10|6|7|3:1|5] 01
                        decompressed_instr = {instr_i[12], instr_i[8], instr_i[10:9], instr_i[6], instr_i[7], instr_i[2], instr_i[11], instr_i[5:3], instr_i[12], {8{instr_i[12]}}, 5'd0, 7'b1101111};
                    end
                end
            end
        end
    end
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