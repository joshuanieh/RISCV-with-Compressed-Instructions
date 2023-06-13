module IFID(
    clk,
    rst_n,
    Stall,
    Flush,
    instr_i,
    PC_i,
    instr_o,
    PC_o,
);
    input             Stall, Flush, clk, rst_n;
    input      [31:0] PC_i;
    input      [31:0] instr_i;
    output reg [31:0] instr_o, PC_o;

    always @(posedge clk) begin
        if (!rst_n | Flush) begin
            instr_o <= {27'b0, 5'b10011};  // NOP instruction
            PC_o    <= 32'b0;
        end
        else if (Stall) begin
            instr_o <= instr_o;
            PC_o    <= PC_o;
        end
        else begin
            instr_o <= instr_i;
            PC_o    <= PC_i;
        end
    end
endmodule

module IDEX( 
    clk,                  // clk, PC (used for WriteBack of JAL and JALR)
    rst_n,
    compress_i, //meaning the it's compressed instruction at PC_i
    Stall,
    Flush,
    PC_i,
    Jalr_i,
    Jal_i,
    Branch_i,
    ALUOp_i,              // EX  : ALUOp, ALUSrc
    ALUSrc_i,
    MemRead_i,            // MEM : MemRead, MemWrite
    MemWrite_i,
    RegWrite_i,           // WB  : MemtoReg, RegWrite
    MemtoReg_i,
    RS1data_i,            // data and addr for RS1, RS2 and RD
    RS2data_i,
    RS1addr_i,
    RS2addr_i,
    RDaddr_i,
    funct_i,              // input of ALU control : instr[30, 14:12]
    imm_i,

    PC_o,
    Jalr_o,
    Jal_o,
    Branch_o,
    ALUOp_o,
    ALUSrc_o,
    MemRead_o,
    MemWrite_o,
    RegWrite_o,
    MemtoReg_o,
    RS1data_o,
    RS2data_o,
    RS1addr_o,
    RS2addr_o,
    RDaddr_o,
    funct_o,
    imm_o,
    compress_o
);
    input             clk, rst_n, compress_i, Stall, Flush, Jalr_i, Jal_i, Branch_i, ALUSrc_i, RegWrite_i, MemtoReg_i, MemRead_i, MemWrite_i;
    input      [1:0]  ALUOp_i;
    input      [31:0] RS1data_i, RS2data_i, PC_i, imm_i;
    input      [3:0]  funct_i;
    input      [4:0]  RS1addr_i, RS2addr_i, RDaddr_i;
    output reg [1:0]  ALUOp_o;
    output reg        Jalr_o, Jal_o, Branch_o, ALUSrc_o, RegWrite_o, MemtoReg_o, MemRead_o, MemWrite_o, compress_o;
    output reg [31:0] RS1data_o, RS2data_o, PC_o, imm_o;
    output reg [3:0]  funct_o;
    output reg [4:0]  RS1addr_o, RS2addr_o, RDaddr_o;

    always @(posedge clk) begin
        if (!rst_n | Flush) begin
            compress_o <= 0;
            Jalr_o     <= 0;
            Jal_o      <= 0;
            Branch_o   <= 0;
            RegWrite_o <= 0;
            MemtoReg_o <= 0;
            MemRead_o  <= 0;
            MemWrite_o <= 0;
            ALUOp_o    <= 0;
            ALUSrc_o   <= 0;
            PC_o       <= 32'b0;
            RDaddr_o   <= 0;
        end 
        else if (Stall) begin
            compress_o <= compress_o;
            Jalr_o     <= Jalr_o;
            Jal_o      <= Jal_o;
            Branch_o   <= Branch_o;
            RegWrite_o <= RegWrite_o;
            MemtoReg_o <= MemtoReg_o;
            MemRead_o  <= MemRead_o;
            MemWrite_o <= MemWrite_o;
            ALUOp_o    <= ALUOp_o;
            ALUSrc_o   <= ALUSrc_o;
            RS1data_o  <= RS1data_o;
            RS2data_o  <= RS2data_o;
            funct_o    <= funct_o;
            RS1addr_o  <= RS1addr_o;
            RS2addr_o  <= RS2addr_o;
            RDaddr_o   <= RDaddr_o;
            PC_o       <= PC_o;
            imm_o      <= imm_o;
        end
        else begin
            compress_o <= compress_i;
            Jalr_o     <= Jalr_i;
            Jal_o      <= Jal_i;
            Branch_o   <= Branch_i;
            RegWrite_o <= RegWrite_i;
            MemtoReg_o <= MemtoReg_i;
            MemRead_o  <= MemRead_i;
            MemWrite_o <= MemWrite_i;
            ALUOp_o    <= ALUOp_i;
            ALUSrc_o   <= ALUSrc_i;
            RS1data_o  <= RS1data_i;
            RS2data_o  <= RS2data_i;
            funct_o    <= funct_i;
            RS1addr_o  <= RS1addr_i;
            RS2addr_o  <= RS2addr_i;
            RDaddr_o   <= RDaddr_i;
            PC_o       <= PC_i;
            imm_o      <= imm_i;
        end

    end
endmodule

module EXMEM(
    clk,
    rst_n,
    Stall,
    PC_i,
    Jalr_i,
    Jal_i,
    RegWrite_i,
    MemtoReg_i,
    MemRead_i,
    MemWrite_i,
    ALUResult_i,
    RS2data_i,
    RDaddr_i,
    PC_o,
    Jalr_o,
    Jal_o,
    RegWrite_o,
    MemtoReg_o,
    MemRead_o,
    MemWrite_o,
    ALUResult_o,
    RS2data_o,
    RDaddr_o
);
    input             clk, rst_n, Stall, Jalr_i, Jal_i, RegWrite_i, MemtoReg_i, MemRead_i, MemWrite_i;
    input      [31:0] PC_i, ALUResult_i, RS2data_i;
    input      [4:0]  RDaddr_i;
    output reg        Jalr_o, Jal_o, RegWrite_o, MemtoReg_o, MemRead_o, MemWrite_o;
    output reg [31:0] PC_o, ALUResult_o, RS2data_o;
    output reg [4:0]  RDaddr_o;

    always @(posedge clk) begin
        if (!rst_n) begin
            Jalr_o      <= 0; 
            Jal_o       <= 0;
            RegWrite_o  <= 0;
            MemtoReg_o  <= 0;
            MemRead_o   <= 0;
            MemWrite_o  <= 0;
            RDaddr_o    <= 0;
        end
        else if (Stall) begin
            Jalr_o      <= Jalr_o; 
            Jal_o       <= Jal_o;
            RegWrite_o  <= RegWrite_o;
            MemtoReg_o  <= MemtoReg_o;
            MemRead_o   <= MemRead_o;
            MemWrite_o  <= MemWrite_o;
            ALUResult_o <= ALUResult_o;
            RS2data_o   <= RS2data_o;
            RDaddr_o    <= RDaddr_o;
            PC_o        <= PC_o;
        end
        else begin
            Jalr_o      <= Jalr_i; 
            Jal_o       <= Jal_i;
            RegWrite_o  <= RegWrite_i;
            MemtoReg_o  <= MemtoReg_i;
            MemRead_o   <= MemRead_i;
            MemWrite_o  <= MemWrite_i;
            ALUResult_o <= ALUResult_i;
            RS2data_o   <= RS2data_i;
            RDaddr_o    <= RDaddr_i;
            PC_o        <= PC_i;
        end
    end
endmodule

module MEMWB(
    clk,
    rst_n,
    Stall,
    PC_i,
    Jalr_i,
    Jal_i,
    RegWrite_i,
    MemtoReg_i,
    ALUResult_i,
    MemData_i,
    RDaddr_i,
    PC_o,
    Jalr_o,
    Jal_o,
    RegWrite_o,
    MemtoReg_o,
    ALUResult_o,
    MemData_o,
    RDaddr_o
);
    input             clk, rst_n, Stall, Jalr_i, Jal_i, RegWrite_i, MemtoReg_i;
    input      [31:0] PC_i, ALUResult_i, MemData_i;
    input      [4:0]  RDaddr_i;
    output reg        Jalr_o, Jal_o, RegWrite_o, MemtoReg_o;
    output reg [31:0] PC_o, ALUResult_o, MemData_o;
    output reg [4:0]  RDaddr_o;

    always @(posedge clk) begin
        if (!rst_n) begin
            Jalr_o      <= 0;
            Jal_o       <= 0;
            RegWrite_o  <= 0;
            MemtoReg_o  <= 0;
            RDaddr_o    <= 0;
        end
        else if (Stall) begin
            Jalr_o      <= Jalr_o;
            Jal_o       <= Jal_o;
            RegWrite_o  <= RegWrite_o;
            MemtoReg_o  <= MemtoReg_o;
            ALUResult_o <= ALUResult_o;
            MemData_o   <= MemData_o;
            RDaddr_o    <= RDaddr_o;
            PC_o        <= PC_o;
        end
        else begin
            Jalr_o      <= Jalr_i;
            Jal_o       <= Jal_i;
            RegWrite_o  <= RegWrite_i;
            MemtoReg_o  <= MemtoReg_i;
            ALUResult_o <= ALUResult_i;
            MemData_o   <= MemData_i;
            RDaddr_o    <= RDaddr_i;
            PC_o        <= PC_i;
        end
    end
endmodule