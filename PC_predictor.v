module PC_predictor (
    PC,
    instr,        // compute PC + imm for both JAL and BRANCH
    PC_predict
);

    input  [31:0] PC, instr;
    output signed [31:0] PC_predict;

    wire is_compress;
    reg [31:0] imm;

    assign is_compress = (instr[1] == 1'b0);
    assign PC_predict = $signed(PC) + $signed(imm);

    always @(*) begin
        if (is_compress) begin
            if (instr[14]) imm = {{24{instr[12]}}, instr[6:5], instr[2], instr[11:10], instr[4], instr[3], 1'b0};
            else imm = {{21{instr[12]}}, instr[8], instr[10:9], instr[6], instr[7], instr[2], instr[11], instr[5:3], 1'b0};
        end
        else begin
            if (instr[2]) imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
            else imm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
        end
    end
    

endmodule

//BEQ:  IMM[12,10:5] rs2 rs1 000 IMM[4:1,11] 1100011
//BNE:  IMM[12,10:5] rs2 rs1 001 IMM[4:1,11] 1100011
//JAL:  IMM[20,10:1,11,19:12]    rd          1101111

//C.BEQZ: 110 imm[8|4:3] rs1' imm[7:6|2:1|5] 01
//C.BNEZ: 111 imm[8|4:3] rs1' imm[7:6|2:1|5] 01
//C.JAL:  001 imm[11|4|9:8|10|6|7|3:1|5]     01
//C.J:    101 imm[11|4|9:8|10|6|7|3:1|5]     01